// =============================================================================
// delete-account — LFPDPPP "Cancelación" right execution
// =============================================================================
// ADMIN-INVOKED ONLY. Self-serve account deletion is too risky given:
//   - Saldo balances must be reconciled (refund to bank? burn? — needs decision)
//   - Outstanding bookings / payouts / debts must be settled
//   - Reviews and feed engagement: anonymize vs delete?
//
// Workflow:
//   1. User files arco-request type='cancellation'
//   2. Admin reviews in admin panel; verifies pre-conditions
//   3. Admin invokes this function with arco_request_id
//   4. Function checks blockers, performs deletion (or refuses with reason)
//   5. ARCO request marked completed/denied
// =============================================================================

import { serve } from "https://deno.land/std@0.177.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";
import { corsHeaders } from "../_shared/cors.ts";
import { checkRateLimit } from "../_shared/rate-limit.ts";

const SUPABASE_URL = Deno.env.get("SUPABASE_URL")!;
const SERVICE_KEY = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!;

let _req: Request;
function json(body: unknown, status = 200) {
  return new Response(JSON.stringify(body), {
    status,
    headers: { ...corsHeaders(_req), "Content-Type": "application/json" },
  });
}

interface DeleteRequest {
  arco_request_id: string;
  override_blockers?: boolean;  // superadmin-only escape hatch
}

serve(async (req) => {
  _req = req;
  if (req.method === "OPTIONS") return new Response("ok", { headers: corsHeaders(req) });
  if (req.method !== "POST") return json({ error: "Method not allowed" }, 405);

  const supabase = createClient(SUPABASE_URL, SERVICE_KEY);

  // Admin auth
  const authHeader = req.headers.get("authorization") ?? "";
  const token = authHeader.replace("Bearer ", "");
  if (!token) return json({ error: "Authorization required" }, 401);

  const { data: { user: caller }, error: authErr } = await supabase.auth.getUser(token);
  if (authErr || !caller) return json({ error: "Invalid token" }, 401);

  // Destructive endpoint — strict per-admin throttle
  if (!checkRateLimit(`del:${caller.id}`, 3, 3600_000)) {
    return json({ error: "Rate limit: max 3 deletions per hour" }, 429);
  }

  const { data: callerProfile } = await supabase
    .from("profiles")
    .select("role")
    .eq("id", caller.id)
    .maybeSingle();

  const callerRole = callerProfile?.role;
  if (callerRole !== "admin" && callerRole !== "superadmin") {
    return json({ error: "Admin required" }, 403);
  }

  let body: DeleteRequest;
  try {
    body = await req.json();
  } catch {
    return json({ error: "Invalid JSON" }, 400);
  }

  if (!body.arco_request_id) {
    return json({ error: "arco_request_id required" }, 400);
  }

  // Fetch the ARCO request
  const { data: arco, error: arcoErr } = await supabase
    .from("arco_requests")
    .select("id, user_id, request_type, status")
    .eq("id", body.arco_request_id)
    .maybeSingle();

  if (arcoErr || !arco) return json({ error: "ARCO request not found" }, 404);
  if (arco.request_type !== "cancellation") {
    return json({ error: "ARCO request is not a cancellation type" }, 400);
  }
  if (arco.status === "completed") {
    return json({ error: "Already completed", already_processed: true }, 200);
  }

  const targetUserId = arco.user_id;

  // ── Pre-deletion blockers ───────────────────────────────────────────
  const blockers: string[] = [];

  // 1. Outstanding bookings (future, paid)
  const { count: pendingBookings } = await supabase
    .from("appointments")
    .select("id", { count: "exact", head: true })
    .eq("user_id", targetUserId)
    .gte("starts_at", new Date().toISOString())
    .in("status", ["confirmed", "pending"]);
  if ((pendingBookings ?? 0) > 0) {
    blockers.push(`${pendingBookings} pending/confirmed future booking(s)`);
  }

  // 2. Saldo balance > 0 (per platform policy: saldo NOT withdrawable;
  //    deletion would forfeit. Surface this to admin.)
  const { data: saldoBalance } = await supabase
    .rpc("get_user_saldo_balance", { p_user_id: targetUserId })
    .maybeSingle();
  // RPC may not exist on all installations — fall back to ledger query.
  let balance = 0;
  if (saldoBalance && typeof saldoBalance === "object" && "balance" in saldoBalance) {
    balance = (saldoBalance as { balance: number }).balance;
  } else {
    const { data: ledger } = await supabase
      .from("saldo_ledger")
      .select("amount")
      .eq("user_id", targetUserId);
    if (ledger) {
      balance = ledger.reduce((sum, r) => sum + Number(r.amount), 0);
    }
  }
  if (balance > 0.01) {
    blockers.push(`Saldo balance $${balance.toFixed(2)} MXN — non-withdrawable per policy; admin must decide`);
  }

  // 3. Salon ownership — owner accounts can't be deleted while business active
  const { count: ownedBusinesses } = await supabase
    .from("businesses")
    .select("id", { count: "exact", head: true })
    .eq("owner_id", targetUserId)
    .eq("is_active", true);
  if ((ownedBusinesses ?? 0) > 0) {
    blockers.push(`${ownedBusinesses} active business(es) owned — must transfer or deactivate first`);
  }

  // 4. Unresolved disputes
  const { count: openDisputes } = await supabase
    .from("disputes")
    .select("id", { count: "exact", head: true })
    .eq("user_id", targetUserId)
    .in("status", ["open", "responding"]);
  if ((openDisputes ?? 0) > 0) {
    blockers.push(`${openDisputes} unresolved dispute(s)`);
  }

  // Block unless superadmin overrides explicitly
  if (blockers.length > 0 && !body.override_blockers) {
    return json({
      error: "Pre-deletion blockers present",
      blockers,
      hint: "Resolve blockers OR retry with override_blockers=true (superadmin only)",
    }, 409);
  }

  if (blockers.length > 0 && callerRole !== "superadmin") {
    return json({
      error: "Override requires superadmin role",
      blockers,
    }, 403);
  }

  // ── Execute deletion via auth.admin (cascades public.* via FKs) ────
  // profiles.id REFERENCES auth.users.id ON DELETE CASCADE → deleting auth
  // user removes profile + everything FK-cascaded from it.
  const { error: deleteErr } = await supabase.auth.admin.deleteUser(targetUserId);

  if (deleteErr) {
    console.error(`[DELETE-ACCOUNT] auth.admin.deleteUser failed: ${deleteErr.message}`);
    return json({ error: "Deletion failed", details: deleteErr.message }, 500);
  }

  // Mark ARCO request resolved
  await supabase
    .from("arco_requests")
    .update({
      status: "completed",
      responded_at: new Date().toISOString(),
      resolved_at: new Date().toISOString(),
      resolved_by: caller.id,
      response_notes: `Account deleted by ${callerRole} ${caller.email ?? caller.id}. ` +
        `Overridden blockers: ${blockers.join("; ") || "none"}.`,
    })
    .eq("id", body.arco_request_id);

  // Audit log entry (cannot reference deleted user_id, so include in details only)
  await supabase.from("audit_log").insert({
    admin_id: caller.id,
    action: "account_deleted",
    target_type: "user",
    target_id: targetUserId,
    details: {
      arco_request_id: body.arco_request_id,
      blockers_overridden: blockers,
      saldo_forfeited: balance,
      legal_basis: "LFPDPPP Art. 25 (Cancelación)",
    },
  });

  return json({
    success: true,
    deleted_user_id: targetUserId,
    arco_request_id: body.arco_request_id,
    blockers_overridden: blockers,
    saldo_forfeited: balance,
  });
});
