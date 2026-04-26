/**
 * wa-incoming — Webhook receiver for incoming WhatsApp messages from beautypi.
 *
 * When BC replies to a support thread on WhatsApp with [BC-{threadId}] prefix,
 * beautypi forwards the message here. This function:
 * 1. Validates the webhook secret
 * 2. Finds the thread by ID prefix
 * 3. Inserts the reply as a 'support' sender_type message
 * 4. Updates thread last_message metadata
 *
 * Supabase realtime delivers the message to the user's app instantly.
 */

import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

const ALLOWED_ORIGINS = [
  "https://beautycita.com",
  "https://www.beautycita.com",
  "https://debug.beautycita.com",
];

function corsOrigin(req: Request): string {
  const o = req.headers.get("origin") ?? "";
  return ALLOWED_ORIGINS.includes(o) ? o : ALLOWED_ORIGINS[0];
}

const corsHeaders = (req: Request) => ({
  "Access-Control-Allow-Origin": corsOrigin(req),
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type, x-webhook-secret",
  "Access-Control-Allow-Methods": "POST, OPTIONS",
});

const WEBHOOK_SECRET = Deno.env.get("WA_WEBHOOK_SECRET") ?? "";

let _req: Request;

function json(body: Record<string, unknown>, status = 200) {
  return new Response(JSON.stringify(body), {
    status,
    headers: { ...corsHeaders(_req), "Content-Type": "application/json" },
  });
}

Deno.serve(async (req) => {
  _req = req;
  if (req.method === "OPTIONS") {
    return new Response(null, { status: 204, headers: corsHeaders(req) });
  }
  if (req.method !== "POST") {
    return json({ error: "Method not allowed" }, 405);
  }

  // Validate webhook secret
  const secret = req.headers.get("x-webhook-secret") || "";
  if (secret !== WEBHOOK_SECRET) {
    return json({ error: "Unauthorized" }, 401);
  }

  const supabaseUrl = Deno.env.get("SUPABASE_URL")!;
  const serviceKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!;
  const db = createClient(supabaseUrl, serviceKey);

  try {
    const { thread_prefix, message, from_phone } = await req.json();

    // ── BAJA opt-out handler (LFPDPPP / CAN-SPAM canonical registry) ──
    // Inbound "BAJA" / "STOP" / "UNSUBSCRIBE" → write to marketing_opt_outs.
    // The sync_marketing_opt_out_denorm trigger fans the opt-out out to
    // discovered_salons.opted_out + profiles.opted_out_marketing automatically.
    const trimmed = (message ?? "").trim().toLowerCase();
    const isOptOut = ["baja", "stop", "unsubscribe", "unsuscribir"].includes(trimmed);
    if (isOptOut && from_phone) {
      const digits = from_phone.replace(/[^\d]/g, "");
      const last10 = digits.slice(-10);

      const { error: optErr } = await db
        .from("marketing_opt_outs")
        .upsert({
          phone: last10,
          source: "wa_baja",
          notes: `inbound BAJA reply from ${from_phone}`,
        }, { onConflict: "phone", ignoreDuplicates: false });

      if (optErr) {
        console.error(`[WA-IN] opt-out registry write failed: ${optErr.message}`);
      }

      // Count how many discovered_salons rows were affected, for logging.
      const { count } = await db
        .from("discovered_salons")
        .select("id", { count: "exact", head: true })
        .or(`phone.ilike.%${last10},whatsapp.ilike.%${last10}`)
        .eq("opted_out", true);

      console.log(`[WA-IN] BAJA from ${from_phone}: opt-out registered, ${count ?? 0} salons affected`);

      return json({
        action: "opt_out",
        opted_out_count: count ?? 0,
        message: "Listo, no recibiras mas mensajes de BeautyCita. Si cambias de opinion, visita beautycita.com",
      });
    }

    if (!thread_prefix || !message) {
      return json({ error: "thread_prefix and message required" }, 400);
    }

    // Find the thread by ID prefix (first 8 chars of UUID)
    const { data: threads, error: findErr } = await db
      .from("chat_threads")
      .select("id, user_id, contact_type")
      .in("contact_type", ["support", "salon"])
      .ilike("id", `${thread_prefix}%`)
      .limit(1);

    if (findErr || !threads || threads.length === 0) {
      console.error(`[WA-IN] Thread not found for prefix: ${thread_prefix}`);
      return json({ error: "Thread not found" }, 404);
    }

    const thread = threads[0];

    // Insert support agent message
    const { error: msgErr } = await db
      .from("chat_messages")
      .insert({
        thread_id: thread.id,
        sender_type: thread.contact_type === "salon" ? "salon" : "support",
        content_type: "text",
        text_content: message,
        metadata: { from_phone, via: "whatsapp" },
      });

    if (msgErr) {
      console.error(`[WA-IN] Insert failed: ${msgErr.message}`);
      return json({ error: msgErr.message }, 500);
    }

    // Update thread last message
    await db
      .from("chat_threads")
      .update({
        last_message_text: message,
        last_message_at: new Date().toISOString(),
      })
      .eq("id", thread.id);

    // Atomically increment unread count
    await db.rpc("increment_unread", { p_thread_id: thread.id });

    console.log(`[WA-IN] Message delivered to thread ${thread.id}`);
    return json({ delivered: true, thread_id: thread.id });
  } catch (e) {
    console.error(`[WA-IN] Error: ${e}`);
    return json({ error: String(e) }, 500);
  }
});
