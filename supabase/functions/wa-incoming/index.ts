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

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type, x-webhook-secret",
  "Access-Control-Allow-Methods": "POST, OPTIONS",
};

const WEBHOOK_SECRET = Deno.env.get("WA_WEBHOOK_SECRET") ?? "";

function json(body: Record<string, unknown>, status = 200) {
  return new Response(JSON.stringify(body), {
    status,
    headers: { ...corsHeaders, "Content-Type": "application/json" },
  });
}

Deno.serve(async (req) => {
  if (req.method === "OPTIONS") {
    return new Response(null, { status: 204, headers: corsHeaders });
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

    if (!thread_prefix || !message) {
      return json({ error: "thread_prefix and message required" }, 400);
    }

    // Find the thread by ID prefix (first 8 chars of UUID)
    const { data: threads, error: findErr } = await db
      .from("chat_threads")
      .select("id, user_id, contact_type")
      .eq("contact_type", "support")
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
        sender_type: "support",
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
