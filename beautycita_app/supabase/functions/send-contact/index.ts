import { serve } from "https://deno.land/std@0.168.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

const WA_API_URL = Deno.env.get("BEAUTYPI_WA_URL") ?? "";
const WA_API_TOKEN = Deno.env.get("BEAUTYPI_WA_TOKEN") ?? "";
const BC_PHONE = "523221429800";

const SUPABASE_URL = Deno.env.get("SUPABASE_URL") ?? "";
const SUPABASE_ANON_KEY = Deno.env.get("SUPABASE_ANON_KEY") ?? "";

// In-memory rate limit: max 5 messages per IP per 10 minutes
const rateLimitMap = new Map<string, number[]>();
const RATE_LIMIT_WINDOW_MS = 10 * 60 * 1000;
const RATE_LIMIT_MAX = 5;

const corsHeaders = {
  "Access-Control-Allow-Origin": "https://beautycita.com",
  "Access-Control-Allow-Methods": "POST, OPTIONS",
  "Access-Control-Allow-Headers": "authorization, content-type, apikey",
};

serve(async (req: Request) => {
  if (req.method === "OPTIONS") {
    return new Response(null, { status: 204, headers: corsHeaders });
  }

  if (req.method !== "POST") {
    return new Response(JSON.stringify({ error: "Method not allowed" }), {
      status: 405,
      headers: { ...corsHeaders, "Content-Type": "application/json" },
    });
  }

  try {
    // Auth check: require authenticated user
    const authHeader = req.headers.get("authorization") ?? "";
    const token = authHeader.replace("Bearer ", "");
    const userClient = createClient(SUPABASE_URL, SUPABASE_ANON_KEY, {
      global: { headers: { Authorization: `Bearer ${token}` } },
    });
    const { data: { user }, error: authError } = await userClient.auth.getUser();
    if (authError || !user) {
      return new Response(JSON.stringify({ error: "Unauthorized" }), {
        status: 401,
        headers: { ...corsHeaders, "Content-Type": "application/json" },
      });
    }

    // Rate limit by user ID
    const now = Date.now();
    const userKey = user.id;
    const timestamps = rateLimitMap.get(userKey) ?? [];
    const recent = timestamps.filter((t) => now - t < RATE_LIMIT_WINDOW_MS);
    if (recent.length >= RATE_LIMIT_MAX) {
      return new Response(JSON.stringify({ error: "Rate limit exceeded" }), {
        status: 429,
        headers: { ...corsHeaders, "Content-Type": "application/json" },
      });
    }
    recent.push(now);
    rateLimitMap.set(userKey, recent);

    const { name, message } = await req.json();

    if (!message || typeof message !== "string" || message.trim().length === 0) {
      return new Response(JSON.stringify({ error: "message required" }), {
        status: 400,
        headers: { ...corsHeaders, "Content-Type": "application/json" },
      });
    }

    // Sanitize: strip anything that looks like a phone number or email
    const cleaned = message.trim()
      .replace(/[\+]?\d[\d\s\-\(\)]{7,}/g, "[redacted]")
      .replace(/[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}/g, "[redacted]");

    const displayName = (name && typeof name === "string" && name.trim().length > 0)
      ? name.trim().substring(0, 50)
      : "Visitante";

    const contactMessage = `*[beautycita.com]*\nMensaje de ${displayName}:\n${cleaned.substring(0, 500)}`;

    const waRes = await fetch(`${WA_API_URL}/api/wa/send`, {
      method: "POST",
      headers: {
        "Content-Type": "application/json",
        "Authorization": `Bearer ${WA_API_TOKEN}`,
      },
      body: JSON.stringify({
        phone: BC_PHONE,
        message: contactMessage,
      }),
    });

    const waData = await waRes.json();

    return new Response(JSON.stringify({ sent: waData.sent === true }), {
      status: 200,
      headers: { ...corsHeaders, "Content-Type": "application/json" },
    });
  } catch (e) {
    console.error("[send-contact] Error:", e);
    return new Response(JSON.stringify({ error: "Failed to send" }), {
      status: 500,
      headers: { ...corsHeaders, "Content-Type": "application/json" },
    });
  }
});
