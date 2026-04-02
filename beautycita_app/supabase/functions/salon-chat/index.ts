/**
 * salon-chat — In-app salon chat with WA forwarding to salon phone.
 *
 * Actions:
 *   init    { business_id }          — Get or create salon chat thread for user+business
 *   send    { thread_id, message }   — Store user message, forward to salon via WA
 *
 * Messages stay in DB. Salon receives a WA notification with the user's message.
 * Salon can reply via WA with [BC-{prefix}] tag and wa-incoming routes it back.
 *
 * Env vars:
 *   BEAUTYPI_WA_URL    — e.g. http://100.93.1.103:3200
 *   BEAUTYPI_WA_TOKEN  — Bearer token for WA API
 */

import { createClient } from "https://esm.sh/@supabase/supabase-js@2";
import { requireFeature } from "../_shared/check-toggle.ts";

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
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
  "Access-Control-Allow-Methods": "POST, OPTIONS",
});

const BEAUTYPI_WA_URL = Deno.env.get("BEAUTYPI_WA_URL") ?? "";
const BEAUTYPI_WA_TOKEN = Deno.env.get("BEAUTYPI_WA_TOKEN") ?? "";

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

  const blocked = await requireFeature("enable_salon_chat");
  if (blocked) return blocked;

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

  // --- INIT: get or create salon chat thread ---
  if (action === "init") {
    const { business_id } = params;
    if (!business_id) {
      return json({ error: "business_id required" }, 400);
    }

    // Lookup business and verify caller is the owner
    const { data: business, error: bizErr } = await db
      .from("businesses")
      .select("id, name, phone, whatsapp, owner_id")
      .eq("id", business_id)
      .single();

    if (bizErr || !business) {
      return json({ error: "Business not found" }, 404);
    }

    if (business.owner_id !== user.id) {
      return json({ error: "Not authorized for this business" }, 403);
    }

    // Find existing salon thread for this user + business
    const { data: existing } = await db
      .from("chat_threads")
      .select("*")
      .eq("user_id", user.id)
      .eq("contact_type", "salon")
      .eq("contact_id", business_id)
      .limit(1)
      .single();

    if (existing) {
      return json({ thread: existing });
    }

    // Create new salon thread
    const { data: thread, error: createErr } = await db
      .from("chat_threads")
      .insert({
        user_id: user.id,
        contact_type: "salon",
        contact_id: business_id,
        contact_name: business.name,
        pinned: false,
      })
      .select()
      .single();

    if (createErr) {
      console.error("[SALON-CHAT] Failed to create thread:", createErr);
      return json({ error: "An internal error occurred" }, 500);
    }

    // Create WA bridge for routing replies back
    const salonPhone = business.whatsapp || business.phone;
    if (salonPhone) {
      await db.from("wa_chat_bridges").insert({
        thread_id: thread.id,
        wa_phone: salonPhone,
      });
    }

    // Insert welcome message
    const welcomeText = `Hola! Iniciaste un chat con ${business.name}. Tu mensaje sera reenviado al salon.`;
    await db.from("chat_messages").insert({
      thread_id: thread.id,
      sender_type: "salon",
      content_type: "text",
      text_content: welcomeText,
    });

    // Update thread last message
    await db
      .from("chat_threads")
      .update({
        last_message_text: welcomeText,
        last_message_at: new Date().toISOString(),
      })
      .eq("id", thread.id);

    return json({ thread });
  }

  // --- SEND: forward message to salon via WhatsApp ---
  if (action === "send") {
    const { thread_id, message } = params;
    if (!thread_id || !message) {
      return json({ error: "thread_id and message required" }, 400);
    }

    // Verify thread belongs to user and is salon type
    const { data: thread } = await db
      .from("chat_threads")
      .select("*")
      .eq("id", thread_id)
      .eq("user_id", user.id)
      .eq("contact_type", "salon")
      .single();

    if (!thread) {
      return json({ error: "Salon thread not found" }, 404);
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

    // Insert user message
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
      console.error("[SALON-CHAT] Failed to send message:", msgErr);
      return json({ error: "An internal error occurred" }, 500);
    }

    // Update thread
    await db
      .from("chat_threads")
      .update({
        last_message_text: message,
        last_message_at: new Date().toISOString(),
      })
      .eq("id", thread_id);

    // Lookup salon phone from wa_chat_bridges
    const { data: bridge } = await db
      .from("wa_chat_bridges")
      .select("wa_phone")
      .eq("thread_id", thread_id)
      .single();

    if (!bridge?.wa_phone) {
      console.error(`[SALON-CHAT] No WA bridge for thread ${thread_id}`);
      return json({ sent: true, message: msg, wa_sent: false });
    }

    // Get user display name
    const { data: profile } = await db
      .from("profiles")
      .select("display_name, username")
      .eq("id", user.id)
      .single();

    const userName = profile?.display_name || profile?.username || "Usuario";
    const shortId = thread_id.substring(0, 8);
    const preview = message.length > 80 ? message.substring(0, 80) + "..." : message;
    const waMsg = `*BeautyCita*\nMensaje de ${userName} (ref: [BC-${shortId}]):\n"${preview}"`;

    try {
      await fetch(`${BEAUTYPI_WA_URL}/api/wa/send`, {
        method: "POST",
        headers: {
          "Content-Type": "application/json",
          Authorization: `Bearer ${BEAUTYPI_WA_TOKEN}`,
        },
        body: JSON.stringify({ phone: bridge.wa_phone, message: waMsg }),
      });
    } catch (e) {
      console.error(`[SALON-CHAT] WA send failed: ${e}`);
      // Don't fail — message is in DB, WA is just a notification
    }

    return json({ sent: true, message: msg });
  }

  return json({ error: `Unknown action: ${action}` }, 400);
});
