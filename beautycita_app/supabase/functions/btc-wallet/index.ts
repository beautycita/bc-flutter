// =============================================================================
// btc-wallet — BTC wallet operations with TOTP 2FA
// Uses raw fetch to PostgREST + GoTrue (no heavy supabase-js import)
// =============================================================================

import {
  generateTotpSecret,
  encryptSecret,
  decryptSecret,
  verifyTotpCode,
  buildOtpAuthUri,
} from "../_shared/totp.ts";

const SUPABASE_URL = Deno.env.get("SUPABASE_URL") ?? "";
const SERVICE_KEY = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY") ?? "";
const BTCPAY_URL = Deno.env.get("BTCPAY_URL") ?? "https://beautycita.com/btcpay";
const BTCPAY_API_KEY = Deno.env.get("BTCPAY_API_KEY") ?? "";
const BTCPAY_STORE_ID = Deno.env.get("BTCPAY_STORE_ID") ?? "";

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
};

function json(body: unknown, status = 200) {
  return new Response(JSON.stringify(body), {
    status,
    headers: { ...corsHeaders, "Content-Type": "application/json" },
  });
}

// --- Raw PostgREST helpers ---

const REST_URL = `${SUPABASE_URL}/rest/v1`;

async function dbSelect(table: string, query: string): Promise<unknown[]> {
  const r = await fetch(`${REST_URL}/${table}?${query}`, {
    headers: {
      apikey: SERVICE_KEY,
      Authorization: `Bearer ${SERVICE_KEY}`,
      "Content-Type": "application/json",
    },
  });
  if (!r.ok) throw new Error(`DB select ${table}: ${r.status} ${await r.text()}`);
  return r.json();
}

async function dbInsert(table: string, data: Record<string, unknown>): Promise<unknown[]> {
  const r = await fetch(`${REST_URL}/${table}`, {
    method: "POST",
    headers: {
      apikey: SERVICE_KEY,
      Authorization: `Bearer ${SERVICE_KEY}`,
      "Content-Type": "application/json",
      Prefer: "return=representation",
    },
    body: JSON.stringify(data),
  });
  if (!r.ok) throw new Error(`DB insert ${table}: ${r.status} ${await r.text()}`);
  return r.json();
}

async function dbUpsert(table: string, data: Record<string, unknown>, onConflict: string): Promise<void> {
  const r = await fetch(`${REST_URL}/${table}?on_conflict=${onConflict}`, {
    method: "POST",
    headers: {
      apikey: SERVICE_KEY,
      Authorization: `Bearer ${SERVICE_KEY}`,
      "Content-Type": "application/json",
      Prefer: "resolution=merge-duplicates",
    },
    body: JSON.stringify(data),
  });
  if (!r.ok) throw new Error(`DB upsert ${table}: ${r.status} ${await r.text()}`);
}

async function dbUpdate(table: string, query: string, data: Record<string, unknown>): Promise<void> {
  const r = await fetch(`${REST_URL}/${table}?${query}`, {
    method: "PATCH",
    headers: {
      apikey: SERVICE_KEY,
      Authorization: `Bearer ${SERVICE_KEY}`,
      "Content-Type": "application/json",
    },
    body: JSON.stringify(data),
  });
  if (!r.ok) throw new Error(`DB update ${table}: ${r.status} ${await r.text()}`);
}

// --- GoTrue auth helper ---

async function getUser(authHeader: string): Promise<{ id: string; email: string } | null> {
  const r = await fetch(`${SUPABASE_URL}/auth/v1/user`, {
    headers: {
      apikey: SERVICE_KEY,
      Authorization: authHeader,
    },
  });
  if (!r.ok) return null;
  const u = await r.json();
  return u?.id ? { id: u.id, email: u.email ?? "" } : null;
}

// --- BTCPay helpers ---

async function btcpayPost(path: string, body?: unknown): Promise<unknown> {
  const r = await fetch(`${BTCPAY_URL}${path}`, {
    method: "POST",
    headers: { Authorization: `token ${BTCPAY_API_KEY}`, "Content-Type": "application/json" },
    body: body ? JSON.stringify(body) : undefined,
  });
  if (!r.ok) throw new Error(`BTCPay ${r.status}: ${await r.text()}`);
  return r.json();
}

async function btcpayGet(path: string): Promise<unknown> {
  const r = await fetch(`${BTCPAY_URL}${path}`, {
    method: "GET",
    headers: { Authorization: `token ${BTCPAY_API_KEY}` },
  });
  if (!r.ok) throw new Error(`BTCPay ${r.status}: ${await r.text()}`);
  return r.json();
}

// --- TOTP verification helper ---

async function requireTotp(userId: string, code: string): Promise<{ ok: boolean; error?: string }> {
  if (!code || code.length !== 6) return { ok: false, error: "Codigo 2FA requerido (6 digitos)" };

  const rows = await dbSelect("user_totp_secrets", `user_id=eq.${userId}&select=secret_enc,iv,is_verified`);
  const totp = (rows as Record<string, unknown>[])[0];
  if (!totp || !totp.is_verified) return { ok: false, error: "2FA no configurado" };

  const secret = await decryptSecret(totp.secret_enc as string, totp.iv as string);
  const valid = await verifyTotpCode(secret, code);
  return valid ? { ok: true } : { ok: false, error: "Codigo 2FA incorrecto" };
}

// --- Action handlers ---

async function handleTotpSetup(userId: string, email: string) {
  const rows = await dbSelect("user_totp_secrets", `user_id=eq.${userId}&select=is_verified`);
  if ((rows as Record<string, unknown>[])[0]?.is_verified) {
    return json({ error: "2FA ya esta configurado" }, 400);
  }

  const secret = generateTotpSecret();
  const { encrypted, iv } = await encryptSecret(secret);
  const otpauthUri = buildOtpAuthUri(secret, email || userId);

  await dbUpsert("user_totp_secrets", {
    user_id: userId, secret_enc: encrypted, iv,
    is_verified: false, created_at: new Date().toISOString(), verified_at: null,
  }, "user_id");

  return json({ otpauth_uri: otpauthUri, secret });
}

async function handleTotpVerify(userId: string, code: string) {
  if (!code || code.length !== 6) return json({ error: "Ingresa un codigo de 6 digitos" }, 400);

  const rows = await dbSelect("user_totp_secrets", `user_id=eq.${userId}&select=secret_enc,iv,is_verified`);
  const totp = (rows as Record<string, unknown>[])[0];
  if (!totp) return json({ error: "Inicia la configuracion 2FA primero" }, 400);
  if (totp.is_verified) return json({ error: "2FA ya esta verificado" }, 400);

  const secret = await decryptSecret(totp.secret_enc as string, totp.iv as string);
  const valid = await verifyTotpCode(secret, code);
  if (!valid) return json({ error: "Codigo incorrecto — intenta de nuevo" }, 400);

  await dbUpdate("user_totp_secrets", `user_id=eq.${userId}`, {
    is_verified: true, verified_at: new Date().toISOString(),
  });

  return json({ success: true });
}

async function handleTotpStatus(userId: string) {
  const rows = await dbSelect("user_totp_secrets", `user_id=eq.${userId}&select=is_verified`);
  const totp = (rows as Record<string, unknown>[])[0];
  return json({ enabled: totp?.is_verified === true });
}

async function handleGenerateAddress(userId: string, code: string) {
  const check = await requireTotp(userId, code);
  if (!check.ok) return json({ error: check.error }, 401);

  if (!BTCPAY_API_KEY || !BTCPAY_STORE_ID) return json({ error: "BTCPay no configurado" }, 500);

  const addrData = (await btcpayGet(
    `/api/v1/stores/${BTCPAY_STORE_ID}/payment-methods/onchain/BTC/wallet/address`
  )) as { address: string };

  if (!addrData?.address) return json({ error: "No se pudo generar la direccion" }, 500);

  await dbUpdate("btc_addresses", `user_id=eq.${userId}&is_current=eq.true`, { is_current: false });

  await dbInsert("btc_addresses", {
    user_id: userId, address: addrData.address,
    label: `Deposito ${new Date().toLocaleDateString("es-MX")}`, is_current: true,
  });

  return json({ address: addrData.address });
}

async function handleGetWallet(userId: string) {
  const [addrRows, balRows, depRows] = await Promise.all([
    dbSelect("btc_addresses", `user_id=eq.${userId}&is_current=eq.true&select=address,created_at&limit=1`),
    dbSelect("btc_user_balance", `user_id=eq.${userId}&select=confirmed_btc,pending_btc`),
    dbSelect("btc_deposits", `user_id=eq.${userId}&select=*&order=detected_at.desc&limit=20`),
  ]);

  const addr = (addrRows as Record<string, unknown>[])[0];
  const bal = (balRows as Record<string, unknown>[])[0];

  return json({
    current_address: addr?.address ?? null,
    address_created_at: addr?.created_at ?? null,
    confirmed_btc: Number(bal?.confirmed_btc ?? 0),
    pending_btc: Number(bal?.pending_btc ?? 0),
    deposits: depRows ?? [],
  });
}

async function handleGetDeposits(userId: string) {
  const rows = await dbSelect("btc_deposits", `user_id=eq.${userId}&select=*&order=detected_at.desc&limit=50`);
  return json({ deposits: rows ?? [] });
}

async function handleSyncDeposits() {
  if (!BTCPAY_API_KEY || !BTCPAY_STORE_ID) return json({ error: "BTCPay not configured" }, 500);
  await pollBtcpayUtxos();
  return json({ synced: true });
}

async function handleWithdraw(userId: string, code: string, destination: string, amountBtc: number, sendAll: boolean) {
  const check = await requireTotp(userId, code);
  if (!check.ok) return json({ error: check.error }, 401);

  if (!destination || !destination.startsWith("bc1")) return json({ error: "Direccion Bitcoin invalida" }, 400);
  if (!amountBtc || amountBtc <= 0) return json({ error: "Monto invalido" }, 400);

  const balRows = await dbSelect("btc_user_balance", `user_id=eq.${userId}&select=confirmed_btc`);
  const confirmedBtc = Number((balRows as Record<string, unknown>[])[0]?.confirmed_btc ?? 0);
  if (amountBtc > confirmedBtc) return json({ error: `Saldo insuficiente. Disponible: ${confirmedBtc} BTC` }, 400);

  if (!BTCPAY_API_KEY || !BTCPAY_STORE_ID) return json({ error: "BTCPay no configurado" }, 500);

  // When sending entire balance, fees must be subtracted from the amount
  const subtractFromAmount = sendAll || amountBtc >= confirmedBtc;

  const txData = (await btcpayPost(
    `/api/v1/stores/${BTCPAY_STORE_ID}/payment-methods/onchain/BTC/wallet/transactions`,
    { destinations: [{ destination, amount: amountBtc, subtractFromAmount }], proceedWithBroadcast: true }
  )) as { transactionHash?: string };

  if (!txData?.transactionHash) return json({ error: "No se pudo crear la transaccion" }, 500);

  await dbInsert("btc_deposits", {
    user_id: userId, address: destination, txid: txData.transactionHash,
    amount_btc: -amountBtc, confirmations: 0, status: "confirmed",
    detected_at: new Date().toISOString(), confirmed_at: new Date().toISOString(),
  });

  return json({ success: true, txid: txData.transactionHash, amount_btc: amountBtc, destination });
}

// --- BTCPay UTXO-based deposit detection ---

async function pollBtcpayUtxos() {
  const [utxos, txs] = await Promise.all([
    btcpayGet(`/api/v1/stores/${BTCPAY_STORE_ID}/payment-methods/onchain/BTC/wallet/utxos`) as Promise<Array<{
      amount: string; outpoint: string; timestamp: number; address: string; confirmations: number;
    }>>,
    btcpayGet(`/api/v1/stores/${BTCPAY_STORE_ID}/payment-methods/onchain/BTC/wallet/transactions`) as Promise<Array<{
      transactionHash: string; amount: string; confirmations: number; status: string; timestamp: number;
    }>>,
  ]);

  if (!Array.isArray(utxos) || utxos.length === 0) return;

  const txMap = new Map<number, { txid: string; confirmations: number }>();
  for (const tx of txs ?? []) {
    if (tx.transactionHash) txMap.set(tx.timestamp, { txid: tx.transactionHash, confirmations: tx.confirmations });
  }

  const knownAddresses = await dbSelect("btc_addresses", "select=user_id,address") as Array<{ user_id: string; address: string }>;
  if (!knownAddresses.length) return;

  const addrToUser = new Map<string, string>();
  for (const a of knownAddresses) addrToUser.set(a.address, a.user_id);

  for (const utxo of utxos) {
    const userId = addrToUser.get(utxo.address);
    if (!userId) continue;

    const amountBtc = parseFloat(utxo.amount);
    if (amountBtc <= 0) continue;

    const txInfo = txMap.get(utxo.timestamp);
    const txid = txInfo?.txid ?? utxo.outpoint?.substring(0, 64) ?? "";
    if (!txid) continue;

    const confirmations = txInfo?.confirmations ?? utxo.confirmations;
    const status = confirmations >= 3 ? "confirmed" : "pending";

    const existing = await dbSelect("btc_deposits", `txid=eq.${txid}&address=eq.${utxo.address}&select=id,confirmations,status`) as Array<Record<string, unknown>>;

    if (existing.length > 0) {
      const row = existing[0];
      const updates: Record<string, unknown> = { confirmations };
      if (status === "confirmed" && row.status === "pending") {
        updates.status = "confirmed";
        updates.confirmed_at = new Date().toISOString();
      }
      await dbUpdate("btc_deposits", `id=eq.${row.id}`, updates);
    } else {
      await dbInsert("btc_deposits", {
        user_id: userId, address: utxo.address, txid, amount_btc: amountBtc,
        confirmations, status,
        detected_at: new Date(utxo.timestamp * 1000).toISOString(),
        confirmed_at: status === "confirmed" ? new Date().toISOString() : null,
      });
    }
  }
}

// --- Main handler ---

Deno.serve(async (req: Request) => {
  const t0 = Date.now();
  console.log(`[btc-wallet] START ${req.method}`);
  if (req.method === "OPTIONS") return new Response(null, { headers: corsHeaders });
  if (req.method !== "POST") return json({ error: "Method not allowed" }, 405);

  const authHeader = req.headers.get("authorization") ?? "";
  console.log(`[btc-wallet] +${Date.now()-t0}ms getUser...`);
  const user = await getUser(authHeader);
  console.log(`[btc-wallet] +${Date.now()-t0}ms getUser done: ${user?.id ?? "null"}`);
  if (!user) return json({ error: "No autorizado" }, 401);

  try {
    const body = await req.json();
    const action = body.action as string;
    console.log(`[btc-wallet] +${Date.now()-t0}ms action=${action}`);

    let result: Response;
    switch (action) {
      case "totp_setup": result = await handleTotpSetup(user.id, user.email); break;
      case "totp_verify": result = await handleTotpVerify(user.id, body.code ?? ""); break;
      case "totp_status": result = await handleTotpStatus(user.id); break;
      case "generate_address": result = await handleGenerateAddress(user.id, body.code ?? ""); break;
      case "get_wallet": result = await handleGetWallet(user.id); break;
      case "get_deposits": result = await handleGetDeposits(user.id); break;
      case "sync_deposits": result = await handleSyncDeposits(); break;
      case "withdraw": result = await handleWithdraw(user.id, body.code ?? "", body.destination ?? "", parseFloat(body.amount_btc) || 0, body.send_all === true); break;
      default: result = json({ error: `Accion desconocida: ${action}` }, 400);
    }
    console.log(`[btc-wallet] +${Date.now()-t0}ms DONE action=${action}`);
    return result;
  } catch (err) {
    console.error(`[btc-wallet] +${Date.now()-t0}ms ERROR:`, err);
    return json({ error: String(err) }, 500);
  }
});
