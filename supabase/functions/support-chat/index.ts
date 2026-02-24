/**
 * support-chat — In-app support chat with WA alert to wife.
 *
 * Actions:
 *   send    { thread_id, message }  — Store user message in DB, send WA alert to wife
 *   init    {}                      — Get or create support thread for current user
 *
 * Messages stay in DB. Admin manages replies in-app via admin chat screen.
 * Wife gets a short WA alert so she knows to check the admin panel.
 *
 * Env vars:
 *   BEAUTYPI_WA_URL    — e.g. http://100.93.1.103:3200
 *   BEAUTYPI_WA_TOKEN  — Bearer token for WA API
 *   SUPPORT_ALERT_PHONE — Wife's WhatsApp number for alerts (523221215551)
 */

import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
  "Access-Control-Allow-Methods": "POST, OPTIONS",
};

const BEAUTYPI_WA_URL = Deno.env.get("BEAUTYPI_WA_URL") || "http://100.93.1.103:3200";
const BEAUTYPI_WA_TOKEN = Deno.env.get("BEAUTYPI_WA_TOKEN") || "bc-wa-api-2026";
const SUPPORT_ALERT_PHONE = Deno.env.get("SUPPORT_ALERT_PHONE") || "523221215551";

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

  const authHeader = req.headers.get("authorization") || "";
  const supabaseUrl = Deno.env.get("SUPABASE_URL")!;
  const serviceKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!;
  const anonKey = Deno.env.get("SUPABASE_ANON_KEY")!;

  // Auth
  const userClient = createClient(supabaseUrl, anonKey, {
    global: { headers: { Authorization: authHeader } },
  });
  const { data: { user }, error: authError } = await userClient.auth.getUser();
  if (authError || !user) {
    return json({ error: "Not authenticated" }, 401);
  }

  const db = createClient(supabaseUrl, serviceKey);
  const { action, ...params } = await req.json();

  // ─── INIT: get or create support thread ───────────────────
  if (action === "init") {
    // Find existing support thread
    const { data: existing } = await db
      .from("chat_threads")
      .select("*")
      .eq("user_id", user.id)
      .eq("contact_type", "support")
      .limit(1)
      .single();

    if (existing) {
      return json({ thread: existing });
    }

    // Create new support thread
    const { data: thread, error: createErr } = await db
      .from("chat_threads")
      .insert({
        user_id: user.id,
        contact_type: "support",
        contact_id: "support",
        pinned: false,
      })
      .select()
      .single();

    if (createErr) {
      return json({ error: createErr.message }, 500);
    }

    // Create WA bridge (for alert routing)
    await db.from("wa_chat_bridges").insert({
      thread_id: thread.id,
      wa_phone: SUPPORT_ALERT_PHONE,
    });

    // Insert welcome message
    await db.from("chat_messages").insert({
      thread_id: thread.id,
      sender_type: "support",
      content_type: "text",
      text_content: "Hola! Soy el equipo de soporte de BeautyCita. Como te puedo ayudar?",
    });

    // Update thread last message
    await db
      .from("chat_threads")
      .update({
        last_message_text: "Hola! Soy el equipo de soporte de BeautyCita. Como te puedo ayudar?",
        last_message_at: new Date().toISOString(),
      })
      .eq("id", thread.id);

    return json({ thread });
  }

  // ─── SEND: forward message to WhatsApp ────────────────────
  if (action === "send") {
    const { thread_id, message } = params;
    if (!thread_id || !message) {
      return json({ error: "thread_id and message required" }, 400);
    }

    // Verify thread belongs to user and is support type
    const { data: thread } = await db
      .from("chat_threads")
      .select("*")
      .eq("id", thread_id)
      .eq("user_id", user.id)
      .eq("contact_type", "support")
      .single();

    if (!thread) {
      return json({ error: "Support thread not found" }, 404);
    }

    // Rate limit: max 5 messages per minute
    const oneMinAgo = new Date(Date.now() - 60_000).toISOString();
    const { count } = await db
      .from("chat_messages")
      .select("*", { count: "exact", head: true })
      .eq("thread_id", thread_id)
      .eq("sender_type", "user")
      .gte("created_at", oneMinAgo);

    if ((count ?? 0) >= 5) {
      return json({ error: "Espera un momento antes de enviar otro mensaje." }, 429);
    }

    // Insert user message into chat
    const { data: msg, error: msgErr } = await db
      .from("chat_messages")
      .insert({
        thread_id,
        sender_type: "user",
        sender_id: user.id,
        content_type: "text",
        text_content: message,
      })
      .select()
      .single();

    if (msgErr) {
      return json({ error: msgErr.message }, 500);
    }

    // Update thread
    await db
      .from("chat_threads")
      .update({
        last_message_text: message,
        last_message_at: new Date().toISOString(),
      })
      .eq("id", thread_id);

    // Get user display name
    const { data: profile } = await db
      .from("profiles")
      .select("display_name, username")
      .eq("id", user.id)
      .single();

    const userName = profile?.display_name || profile?.username || "Usuario";
    const shortId = thread_id.substring(0, 8);

    // Send WA alert to wife (short notification, not full message)
    const preview = message.length > 80 ? message.substring(0, 80) + "..." : message;
    const alertMsg = `*Soporte BeautyCita*\nNuevo mensaje de ${userName}:\n"${preview}"\n\nResponde en la app > Admin > Chat`;
    try {
      await fetch(`${BEAUTYPI_WA_URL}/api/wa/send`, {
        method: "POST",
        headers: {
          "Content-Type": "application/json",
          Authorization: `Bearer ${BEAUTYPI_WA_TOKEN}`,
        },
        body: JSON.stringify({ phone: SUPPORT_ALERT_PHONE, message: alertMsg }),
      });
    } catch (e) {
      console.error(`[SUPPORT] WA alert failed: ${e}`);
      // Don't fail — message is in DB, alert is just a notification
    }

    return json({ sent: true, message: msg });
  }

  return json({ error: `Unknown action: ${action}` }, 400);
});
