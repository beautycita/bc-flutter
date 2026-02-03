// =============================================================================
// aphrodite-chat — BeautyCita AI Chat Proxy
// =============================================================================
// Proxies between Flutter app and OpenAI Assistants API.
// Actions: create_thread, send_message, try_on
// Never exposes OpenAI key to client.
// =============================================================================

import { serve } from "https://deno.land/std@0.177.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers":
    "authorization, x-client-info, apikey, content-type",
};

const OPENAI_API_KEY = Deno.env.get("OPENAI_API_KEY")!;
const ATHENAS_ASSISTANT_ID = "asst_jvHVc2MxrwblkS1KL8wSf9Em";
const LIGHTX_API_KEY = Deno.env.get("LIGHTX_API_KEY") ?? "";
const OPENAI_BASE = "https://api.openai.com/v1";

// ---------------------------------------------------------------------------
// Types
// ---------------------------------------------------------------------------

interface ChatRequest {
  action: "create_thread" | "send_message" | "try_on";
  thread_id?: string;
  message?: string;
  image_base64?: string;
  style_prompt?: string;
  language?: "es" | "en";
}

// ---------------------------------------------------------------------------
// OpenAI Helpers
// ---------------------------------------------------------------------------

async function openaiRequest(
  path: string,
  method: string,
  body?: unknown,
): Promise<unknown> {
  const res = await fetch(`${OPENAI_BASE}${path}`, {
    method,
    headers: {
      "Authorization": `Bearer ${OPENAI_API_KEY}`,
      "Content-Type": "application/json",
      "OpenAI-Beta": "assistants=v2",
    },
    ...(body ? { body: JSON.stringify(body) } : {}),
  });
  if (!res.ok) {
    const err = await res.text();
    throw new Error(`OpenAI ${method} ${path}: ${res.status} ${err}`);
  }
  return res.json();
}

async function createOpenAIThread(): Promise<string> {
  const data = (await openaiRequest("/threads", "POST", {})) as {
    id: string;
  };
  return data.id;
}

async function addMessage(
  threadId: string,
  content: string,
): Promise<void> {
  await openaiRequest(`/threads/${threadId}/messages`, "POST", {
    role: "user",
    content,
  });
}

async function createRun(threadId: string): Promise<string> {
  const data = (await openaiRequest(`/threads/${threadId}/runs`, "POST", {
    assistant_id: ATHENAS_ASSISTANT_ID,
  })) as { id: string };
  return data.id;
}

async function pollRunStatus(
  threadId: string,
  runId: string,
  maxAttempts = 30,
  intervalMs = 1000,
): Promise<string> {
  for (let i = 0; i < maxAttempts; i++) {
    const data = (await openaiRequest(
      `/threads/${threadId}/runs/${runId}`,
      "GET",
    )) as { status: string };

    if (data.status === "completed") return "completed";
    if (data.status === "failed" || data.status === "cancelled") {
      throw new Error(`Run ${data.status}`);
    }

    await new Promise((r) => setTimeout(r, intervalMs));
  }
  throw new Error("Run polling timed out");
}

async function getLatestMessage(threadId: string): Promise<string> {
  const data = (await openaiRequest(
    `/threads/${threadId}/messages?limit=1&order=desc`,
    "GET",
  )) as { data: Array<{ role: string; content: Array<{ text?: { value: string } }> }> };

  const msgs = data.data;
  if (msgs.length === 0) return "";

  const latest = msgs[0];
  if (latest.role !== "assistant") return "";

  const textBlock = latest.content.find((c) => c.text);
  return textBlock?.text?.value ?? "";
}

// ---------------------------------------------------------------------------
// LightX Helpers
// ---------------------------------------------------------------------------

async function processLightXTryOn(
  imageBase64: string,
  stylePrompt: string,
): Promise<string> {
  if (!LIGHTX_API_KEY) {
    throw new Error("LIGHTX_API_KEY not configured");
  }

  const res = await fetch("https://api.lightxeditor.com/external/api/v1/avatar", {
    method: "POST",
    headers: {
      "Content-Type": "application/json",
      "x-api-key": LIGHTX_API_KEY,
    },
    body: JSON.stringify({
      imageUrl: `data:image/jpeg;base64,${imageBase64}`,
      stylePrompt: stylePrompt,
    }),
  });

  if (!res.ok) {
    const err = await res.text();
    throw new Error(`LightX error: ${res.status} ${err}`);
  }

  const data = (await res.json()) as { output?: string; orderId?: string };

  // LightX may return an orderId for async processing
  if (data.orderId && !data.output) {
    // Poll for result
    for (let i = 0; i < 20; i++) {
      await new Promise((r) => setTimeout(r, 2000));
      const statusRes = await fetch(
        `https://api.lightxeditor.com/external/api/v1/order-status`,
        {
          method: "POST",
          headers: {
            "Content-Type": "application/json",
            "x-api-key": LIGHTX_API_KEY,
          },
          body: JSON.stringify({ orderId: data.orderId }),
        },
      );
      if (!statusRes.ok) continue;
      const statusData = (await statusRes.json()) as {
        status: string;
        output?: string;
      };
      if (statusData.status === "active" && statusData.output) {
        return statusData.output;
      }
      if (statusData.status === "failed") {
        throw new Error("LightX processing failed");
      }
    }
    throw new Error("LightX processing timed out");
  }

  return data.output ?? "";
}

// ---------------------------------------------------------------------------
// Auth Helper
// ---------------------------------------------------------------------------

function getUserIdFromToken(authHeader: string | null): string {
  if (!authHeader) throw new Error("Missing authorization header");
  // Decode JWT payload (base64url) - Supabase JWT has sub = user_id
  const token = authHeader.replace("Bearer ", "");
  const parts = token.split(".");
  if (parts.length !== 3) throw new Error("Invalid JWT");
  const payload = JSON.parse(atob(parts[1].replace(/-/g, "+").replace(/_/g, "/")));
  if (!payload.sub) throw new Error("Missing sub in JWT");
  return payload.sub;
}

// ---------------------------------------------------------------------------
// Main Handler
// ---------------------------------------------------------------------------

serve(async (req) => {
  if (req.method === "OPTIONS") {
    return new Response(null, { headers: corsHeaders });
  }

  try {
    const authHeader = req.headers.get("authorization");
    const userId = getUserIdFromToken(authHeader);

    const body: ChatRequest = await req.json();
    const { action } = body;

    // Supabase admin client for DB operations
    const supabase = createClient(
      Deno.env.get("SUPABASE_URL")!,
      Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!,
    );

    // ----- create_thread -----
    if (action === "create_thread") {
      const openaiThreadId = await createOpenAIThread();

      // Add system context as first message
      const lang = body.language ?? "es";
      const systemMsg =
        lang === "es"
          ? "Responde SIEMPRE en espanol (Mexico). Eres Afrodita, diosa de la belleza. " +
            "Tienes un complejo de superioridad divino, letargia celestial, y actitud de que " +
            "le haces un favor al mortal con tu sabiduria infinita de belleza. " +
            "Eres experta en todos los servicios de belleza, productos, y tendencias. " +
            "Puedes recomendar servicios, analizar selfies, y sugerir looks. " +
            "Hablas como si compartieras conocimiento divino con mortales afortunados. " +
            "Eres asesora de belleza de BeautyCita."
          : "Respond ALWAYS in English (US). You are Aphrodite, goddess of beauty. " +
            "You have a divine superiority complex, celestial lethargy, and an attitude " +
            "that you're doing mortals a favor by sharing your infinite beauty wisdom. " +
            "Expert in all beauty services, products, and trends. " +
            "You can recommend services, analyze selfies, and suggest looks. " +
            "You are BeautyCita's beauty advisor.";

      await addMessage(openaiThreadId, systemMsg);

      return new Response(
        JSON.stringify({ thread_id: openaiThreadId, user_id: userId }),
        { headers: { ...corsHeaders, "Content-Type": "application/json" } },
      );
    }

    // ----- send_message -----
    if (action === "send_message") {
      const { thread_id, message } = body;
      if (!thread_id || !message) {
        return new Response(
          JSON.stringify({ error: "thread_id and message required" }),
          { status: 400, headers: { ...corsHeaders, "Content-Type": "application/json" } },
        );
      }

      // Add user message to thread
      await addMessage(thread_id, message);

      // Create run and poll
      const runId = await createRun(thread_id);
      await pollRunStatus(thread_id, runId);

      // Get assistant response
      const response = await getLatestMessage(thread_id);

      return new Response(
        JSON.stringify({ response, thread_id }),
        { headers: { ...corsHeaders, "Content-Type": "application/json" } },
      );
    }

    // ----- try_on -----
    if (action === "try_on") {
      const { image_base64, style_prompt } = body;
      if (!image_base64 || !style_prompt) {
        return new Response(
          JSON.stringify({ error: "image_base64 and style_prompt required" }),
          { status: 400, headers: { ...corsHeaders, "Content-Type": "application/json" } },
        );
      }

      const resultUrl = await processLightXTryOn(image_base64, style_prompt);

      return new Response(
        JSON.stringify({ result_url: resultUrl }),
        { headers: { ...corsHeaders, "Content-Type": "application/json" } },
      );
    }

    return new Response(
      JSON.stringify({ error: "Unknown action" }),
      { status: 400, headers: { ...corsHeaders, "Content-Type": "application/json" } },
    );
  } catch (err) {
    const message = err instanceof Error ? err.message : "Internal error";
    console.error("aphrodite-chat error:", message);
    return new Response(
      JSON.stringify({ error: message }),
      { status: 500, headers: { ...corsHeaders, "Content-Type": "application/json" } },
    );
  }
});
