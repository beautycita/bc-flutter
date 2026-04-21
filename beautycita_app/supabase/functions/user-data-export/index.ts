// =============================================================================
// user-data-export — LFPDPPP "Acceso" right: bundle a user's PII into JSON
// =============================================================================
// Triggered by arco-request when user files an Access (Acceso) request.
// Produces a JSON document with everything we hold for that user, uploads
// to a signed-URL Storage path, and emails the user the link.
//
// Time-limited URL (24h) so a leaked email doesn't permanently leak data.
// =============================================================================

import { serve } from "https://deno.land/std@0.177.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";
import { corsHeaders } from "../_shared/cors.ts";

const SUPABASE_URL = Deno.env.get("SUPABASE_URL")!;
const SERVICE_KEY = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!;

interface ExportRequest {
  arco_request_id?: string;
  user_id: string;
}

let _req: Request;
function json(body: unknown, status = 200) {
  return new Response(JSON.stringify(body), {
    status,
    headers: { ...corsHeaders(_req), "Content-Type": "application/json" },
  });
}

serve(async (req) => {
  _req = req;
  if (req.method === "OPTIONS") return new Response("ok", { headers: corsHeaders(req) });
  if (req.method !== "POST") return json({ error: "Method not allowed" }, 405);

  // Service-role auth required (called by arco-request internally OR by
  // an admin manually for one-off exports).
  const authHeader = req.headers.get("authorization") ?? "";
  if (!authHeader.includes(SERVICE_KEY)) {
    return json({ error: "Service auth required" }, 401);
  }

  let body: ExportRequest;
  try {
    body = await req.json();
  } catch {
    return json({ error: "Invalid JSON" }, 400);
  }

  const userId = body.user_id;
  if (!userId) return json({ error: "user_id required" }, 400);

  const supabase = createClient(SUPABASE_URL, SERVICE_KEY);

  // ── Bundle every table that holds the user's PII ─────────────────────
  // Keep this list maintained as schema evolves. Anything PII-bearing
  // referencing user.id MUST be exported here.
  const userQueries: Array<[string, () => Promise<{ data: unknown; error: unknown }>]> = [
    ["profile",          () => supabase.from("profiles").select("*").eq("id", userId).maybeSingle()],
    ["appointments",     () => supabase.from("appointments").select("*").eq("user_id", userId)],
    ["payments",         () => supabase.from("payments").select("*").eq("user_id", userId)],
    ["orders",           () => supabase.from("orders").select("*").eq("buyer_id", userId)],
    ["disputes",         () => supabase.from("disputes").select("*").eq("user_id", userId)],
    ["reviews",          () => supabase.from("reviews").select("*").eq("user_id", userId)],
    ["chat_threads",     () => supabase.from("chat_threads").select("*").eq("user_id", userId)],
    ["saldo_ledger",     () => supabase.from("saldo_ledger").select("*").eq("user_id", userId)],
    ["loyalty_transactions", () => supabase.from("loyalty_transactions").select("*").eq("user_id", userId)],
    ["gift_cards_redeemed",  () => supabase.from("gift_cards").select("*").eq("redeemed_by", userId)],
    ["favorites",        () => supabase.from("favorites").select("*").eq("user_id", userId)],
    ["feed_engagement",  () => supabase.from("feed_engagement").select("*").eq("user_id", userId)],
    ["feed_saves",       () => supabase.from("feed_saves").select("*").eq("user_id", userId)],
    ["uber_scheduled_rides", () => supabase.from("uber_scheduled_rides").select("*").eq("user_id", userId)],
    ["user_media",       () => supabase.from("user_media").select("*").eq("user_id", userId)],
    ["notifications",    () => supabase.from("notifications").select("*").eq("user_id", userId)],
    ["webauthn_credentials", () => supabase.from("webauthn_credentials").select("id, credential_id, created_at, last_used_at").eq("user_id", userId)],  // exclude raw public_key
    ["user_behavior_summaries", () => supabase.from("user_behavior_summaries").select("*").eq("user_id", userId)],
    ["user_trait_scores",      () => supabase.from("user_trait_scores").select("*").eq("user_id", userId)],
    ["user_transport_preferences", () => supabase.from("user_transport_preferences").select("*").eq("user_id", userId)],
    ["user_booking_patterns",  () => supabase.from("user_booking_patterns").select("*").eq("user_id", userId)],
    ["user_salon_invites",     () => supabase.from("user_salon_invites").select("*").eq("user_id", userId)],
    ["chat_messages_sent",     () => supabase.from("chat_messages").select("*").eq("sender_id", userId)],
    ["arco_requests",          () => supabase.from("arco_requests").select("*").eq("user_id", userId)],
  ];

  const bundle: Record<string, unknown> = {
    export_metadata: {
      generated_at: new Date().toISOString(),
      user_id: userId,
      arco_request_id: body.arco_request_id ?? null,
      legal_basis: "LFPDPPP Art. 22-25 (Acceso)",
      privacy_policy_url: "https://beautycita.com/privacidad",
      controller: "BeautyCita S.A. de C.V.",
      contact: "soporte@beautycita.com",
    },
  };

  for (const [key, fn] of userQueries) {
    try {
      const { data, error } = await fn();
      if (error) {
        console.warn(`[DATA-EXPORT] ${key}: ${(error as { message?: string }).message ?? error}`);
        bundle[key] = { error: (error as { message?: string }).message ?? "fetch failed" };
      } else {
        bundle[key] = data;
      }
    } catch (e) {
      bundle[key] = { error: (e as Error).message };
    }
  }

  // Auth.users email (separate from public.profiles)
  try {
    const { data: authUser } = await supabase.auth.admin.getUserById(userId);
    if (authUser?.user) {
      bundle["auth_user"] = {
        email: authUser.user.email,
        phone: authUser.user.phone,
        created_at: authUser.user.created_at,
        last_sign_in_at: authUser.user.last_sign_in_at,
        // Intentionally exclude internal Supabase fields
      };
    }
  } catch (e) {
    bundle["auth_user"] = { error: (e as Error).message };
  }

  // ── Upload bundle to private Storage with signed URL ────────────────
  const exportJson = JSON.stringify(bundle, null, 2);
  const filename = `${userId}/${Date.now()}-export.json`;

  const { error: uploadErr } = await supabase.storage
    .from("user-exports")
    .upload(filename, new Blob([exportJson], { type: "application/json" }), {
      contentType: "application/json",
      upsert: false,
    });

  if (uploadErr) {
    console.error("[DATA-EXPORT] Upload error:", uploadErr);
    return json({ error: "Failed to upload export bundle", details: uploadErr.message }, 500);
  }

  // 24h signed URL — short-lived to limit risk if the email recipient is compromised
  const { data: signed, error: signErr } = await supabase.storage
    .from("user-exports")
    .createSignedUrl(filename, 86_400);

  if (signErr || !signed?.signedUrl) {
    console.error("[DATA-EXPORT] Sign URL error:", signErr);
    return json({ error: "Failed to generate signed URL" }, 500);
  }

  // ── Email user the link + update arco_requests row ──────────────────
  const { data: profile } = await supabase
    .from("profiles")
    .select("full_name, username")
    .eq("id", userId)
    .maybeSingle();
  const { data: authUserForEmail } = await supabase.auth.admin.getUserById(userId);
  const recipientEmail = authUserForEmail?.user?.email;

  if (recipientEmail) {
    try {
      await supabase.functions.invoke("send-email", {
        body: {
          to: recipientEmail,
          subject: "Tu exportación de datos BeautyCita está lista",
          text:
            `Hola ${profile?.full_name ?? profile?.username ?? ""},\n\n` +
            `Tu solicitud de acceso a datos personales (LFPDPPP Art. 22) está lista.\n\n` +
            `Descarga (válido por 24 horas):\n${signed.signedUrl}\n\n` +
            `Este enlace expira el ${new Date(Date.now() + 86_400_000).toLocaleString("es-MX")}.\n\n` +
            `Si no solicitaste esta exportación, contacta soporte@beautycita.com inmediatamente.\n\n` +
            `BeautyCita S.A. de C.V.`,
        },
      });
    } catch (e) {
      console.error("[DATA-EXPORT] Email failed:", e);
    }
  }

  // Mark ARCO request as completed (if originated from one)
  if (body.arco_request_id) {
    await supabase
      .from("arco_requests")
      .update({
        status: "completed",
        responded_at: new Date().toISOString(),
        resolved_at: new Date().toISOString(),
      })
      .eq("id", body.arco_request_id);
  }

  return json({
    success: true,
    storage_path: filename,
    expires_at: new Date(Date.now() + 86_400_000).toISOString(),
    table_count: userQueries.length,
  });
});
