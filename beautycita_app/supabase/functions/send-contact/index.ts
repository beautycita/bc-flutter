import { serve } from "https://deno.land/std@0.168.0/http/server.ts";

const WA_API_URL = "http://100.93.1.103:3200";
const WA_API_TOKEN = "Y1gSKe4QCwX5FRkj8ZZi0ONp3Lld_S6oP00nJ7n2KL0";
const GROUP_ID = "120363426514543930@g.us";

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Methods": "POST, OPTIONS",
  "Access-Control-Allow-Headers": "Content-Type",
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

    const groupMessage = `[beautycita.com]\n${displayName}:\n${cleaned.substring(0, 500)}`;

    const waRes = await fetch(`${WA_API_URL}/api/wa/send-group`, {
      method: "POST",
      headers: {
        "Content-Type": "application/json",
        "Authorization": `Bearer ${WA_API_TOKEN}`,
      },
      body: JSON.stringify({
        groupId: GROUP_ID,
        message: groupMessage,
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
