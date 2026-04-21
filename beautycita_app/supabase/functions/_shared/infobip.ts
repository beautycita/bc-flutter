// =============================================================================
// _shared/infobip.ts — Infobip WhatsApp client (sandbox-aware)
// =============================================================================
// Send free-form WhatsApp text messages via Infobip.
//
// Sandbox vs prod
// ---------------
// Sandbox uses Infobip's shared sender (e.g. 447860088970). Recipients must
// first send the keyword to the sandbox number from their WhatsApp before any
// outbound delivery succeeds. This is enforced via INFOBIP_PHONE_WHITELIST —
// a comma-separated list of E.164 numbers (without +) that we attempt to
// route via Infobip. Anything not in the whitelist returns { sent: false,
// reason: "not_whitelisted" } so the caller can fall back to the prior path
// (WA-on-bpi → SMS).
//
// Day-1 cutover when prod sender is live: set INFOBIP_PHONE_WHITELIST to "*"
// (or any single character — see isWhitelisted) to route everyone.
//
// Env vars
// --------
// INFOBIP_BASE_URL          e.g. https://555w6z.api.infobip.com (no trailing /)
// INFOBIP_API_KEY           the App-key value (header becomes "App {key}")
// INFOBIP_WHATSAPP_FROM     E.164 sender without + (e.g. 447860088970)
// INFOBIP_PHONE_WHITELIST   comma-separated allow-list. "*" = allow all.
//
// If any required env var is missing, isInfobipConfigured() returns false and
// callers should skip Infobip and use their existing channel.
// =============================================================================

const BASE_URL = Deno.env.get("INFOBIP_BASE_URL") ?? "";
const API_KEY = Deno.env.get("INFOBIP_API_KEY") ?? "";
const FROM = Deno.env.get("INFOBIP_WHATSAPP_FROM") ?? "";
const WHITELIST = Deno.env.get("INFOBIP_PHONE_WHITELIST") ?? "";

export function isInfobipConfigured(): boolean {
  return Boolean(BASE_URL && API_KEY && FROM);
}

/** True when the destination phone is allowed to receive Infobip messages. */
export function isWhitelisted(phoneE164NoPlus: string): boolean {
  if (!WHITELIST) return false;
  if (WHITELIST.trim() === "*") return true;
  const cleanPhone = phoneE164NoPlus.replace(/[^\d]/g, "");
  return WHITELIST.split(",")
    .map((p) => p.trim().replace(/[^\d]/g, ""))
    .filter(Boolean)
    .includes(cleanPhone);
}

export interface InfobipResult {
  sent: boolean;
  channel: "infobip-wa";
  /** Set when sent=false. One of: not_configured | not_whitelisted | http_error | network_error */
  reason?: string;
  /** Infobip messageId on success */
  messageId?: string;
  /** HTTP status when reason=http_error */
  status?: number;
  /** Truncated error body when reason=http_error or network_error */
  detail?: string;
}

/**
 * Send a free-form WhatsApp text via Infobip.
 *
 * Returns { sent: false } if (a) Infobip env not configured, (b) phone not in
 * the whitelist, or (c) the API call fails. The caller should fall back to
 * the existing channel in those cases.
 *
 * For sandbox mode, the destination MUST have previously sent the keyword
 * (e.g. "BEAUTYCITA COM") to the sandbox sender or Infobip will reject with
 * a 400 — we treat that as http_error and the caller falls back.
 */
export async function sendInfobipWhatsApp(
  phoneE164NoPlus: string,
  text: string,
): Promise<InfobipResult> {
  if (!isInfobipConfigured()) {
    return { sent: false, channel: "infobip-wa", reason: "not_configured" };
  }
  const cleanPhone = phoneE164NoPlus.replace(/[^\d]/g, "");
  if (!isWhitelisted(cleanPhone)) {
    return { sent: false, channel: "infobip-wa", reason: "not_whitelisted" };
  }

  try {
    const resp = await fetch(`${BASE_URL}/whatsapp/1/message/text`, {
      method: "POST",
      headers: {
        Authorization: `App ${API_KEY}`,
        "Content-Type": "application/json",
        Accept: "application/json",
      },
      body: JSON.stringify({
        from: FROM,
        to: cleanPhone,
        content: { text },
      }),
    });

    if (!resp.ok) {
      const errBody = await resp.text();
      console.error(
        `[INFOBIP] WA send failed status=${resp.status} body=${errBody.slice(0, 200)}`,
      );
      return {
        sent: false,
        channel: "infobip-wa",
        reason: "http_error",
        status: resp.status,
        detail: errBody.slice(0, 200),
      };
    }
    const data = await resp.json();
    return {
      sent: true,
      channel: "infobip-wa",
      messageId: data?.messageId,
    };
  } catch (e) {
    console.error(`[INFOBIP] WA send network error:`, e);
    return {
      sent: false,
      channel: "infobip-wa",
      reason: "network_error",
      detail: (e as Error).message?.slice(0, 200),
    };
  }
}
