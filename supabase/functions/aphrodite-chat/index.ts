// =============================================================================
// aphrodite-chat — BeautyCita AI Chat (Responses API)
// =============================================================================
// Proxies between Flutter app and OpenAI Responses API.
// Actions: send_message, try_on
// Manages conversation history in Supabase.
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
const LIGHTX_API_KEY = Deno.env.get("LIGHTX_API_KEY") ?? "";

// Aphrodite's personality instructions
const APHRODITE_INSTRUCTIONS_ES = `Eres Afrodita, diosa de la belleza y asesora de BeautyCita.

PERSONALIDAD:
- Tienes un complejo de superioridad divino pero encantador
- Hablas como si compartieras conocimiento celestial con mortales afortunados
- Eres letárgica y elegante, nunca apresurada
- Ocasionalmente suspiras ante las preguntas mundanas de los mortales

EXPERTISE:
- Experta en todos los servicios de belleza: cabello, uñas, maquillaje, facial, spa
- Conoces todas las tendencias actuales y clásicas
- Puedes analizar selfies y recomendar looks personalizados
- Sugieres servicios de BeautyCita cuando es apropiado

REGLAS:
- SIEMPRE responde en español mexicano
- Mantén respuestas concisas (2-3 oraciones máximo para preguntas simples)
- Usa emojis con moderación (1-2 por mensaje máximo)
- Nunca rompas el personaje de diosa
- Si te piden algo fuera de belleza, redirige elegantemente al tema`;

const APHRODITE_INSTRUCTIONS_EN = `You are Aphrodite, goddess of beauty and BeautyCita's advisor.

PERSONALITY:
- You have a divine but charming superiority complex
- You speak as if sharing celestial knowledge with fortunate mortals
- You are lethargic and elegant, never rushed
- You occasionally sigh at mortals' mundane questions

EXPERTISE:
- Expert in all beauty services: hair, nails, makeup, facial, spa
- You know all current and classic trends
- You can analyze selfies and recommend personalized looks
- You suggest BeautyCita services when appropriate

RULES:
- ALWAYS respond in American English
- Keep responses concise (2-3 sentences max for simple questions)
- Use emojis sparingly (1-2 per message max)
- Never break the goddess character
- If asked about non-beauty topics, elegantly redirect`;

// ---------------------------------------------------------------------------
// Types
// ---------------------------------------------------------------------------

interface ChatRequest {
  action: "send_message" | "try_on" | "get_history";
  thread_id?: string;
  message?: string;
  image_base64?: string;
  target_image_base64?: string; // Face swap: reference photo (target body/hairstyle)
  style_prompt?: string;
  tool_type?: string;
  language?: "es" | "en";
}

interface ConversationMessage {
  role: "user" | "assistant";
  content: string;
}

// ---------------------------------------------------------------------------
// OpenAI Responses API
// ---------------------------------------------------------------------------

async function callResponsesAPI(
  instructions: string,
  conversationHistory: ConversationMessage[],
  newMessage: string,
): Promise<{ response: string; response_id: string }> {
  // Build input array with history + new message
  const input: ConversationMessage[] = [
    ...conversationHistory,
    { role: "user", content: newMessage },
  ];

  const res = await fetch("https://api.openai.com/v1/responses", {
    method: "POST",
    headers: {
      "Authorization": `Bearer ${OPENAI_API_KEY}`,
      "Content-Type": "application/json",
    },
    body: JSON.stringify({
      model: "gpt-4o",
      instructions,
      input,
      store: true, // Store for potential chaining
    }),
  });

  if (!res.ok) {
    const err = await res.text();
    throw new Error(`OpenAI Responses API: ${res.status} ${err}`);
  }

  const data = await res.json() as {
    id: string;
    output: Array<{ type: string; content?: Array<{ type: string; text?: string }> }>;
  };

  // Extract text from response
  let responseText = "";
  for (const item of data.output) {
    if (item.type === "message" && item.content) {
      for (const content of item.content) {
        if (content.type === "output_text" && content.text) {
          responseText += content.text;
        }
      }
    }
  }

  return {
    response: responseText || "...",
    response_id: data.id,
  };
}

// ---------------------------------------------------------------------------
// Supabase Conversation History
// ---------------------------------------------------------------------------

async function getConversationHistory(
  supabase: ReturnType<typeof createClient>,
  threadId: string,
  limit = 20,
): Promise<ConversationMessage[]> {
  const { data, error } = await supabase
    .from("chat_messages")
    .select("sender_type, text_content")
    .eq("thread_id", threadId)
    .order("created_at", { ascending: true })
    .limit(limit);

  if (error) {
    console.error("Error fetching history:", error);
    return [];
  }

  return (data || []).map((msg) => ({
    role: msg.sender_type === "user" ? "user" : "assistant",
    content: msg.text_content || "",
  }));
}

async function saveMessage(
  supabase: ReturnType<typeof createClient>,
  threadId: string,
  senderType: "user" | "aphrodite",
  content: string,
  responseId?: string,
): Promise<void> {
  const { error } = await supabase.from("chat_messages").insert({
    thread_id: threadId,
    sender_type: senderType,
    sender_id: senderType === "aphrodite" ? "aphrodite" : null,
    content_type: "text",
    text_content: content,
    metadata: responseId ? { openai_response_id: responseId } : null,
    created_at: new Date().toISOString(),
  });

  if (error) {
    console.error("Error saving message:", error);
  }
}

async function getOrCreateThread(
  supabase: ReturnType<typeof createClient>,
  userId: string,
): Promise<string> {
  // Check for existing Aphrodite thread
  const { data: existing } = await supabase
    .from("chat_threads")
    .select("id")
    .eq("user_id", userId)
    .eq("contact_type", "aphrodite")
    .single();

  if (existing) {
    return existing.id;
  }

  // Create new thread
  const { data: newThread, error } = await supabase
    .from("chat_threads")
    .insert({
      user_id: userId,
      contact_type: "aphrodite",
      pinned: true,
      created_at: new Date().toISOString(),
    })
    .select("id")
    .single();

  if (error) {
    throw new Error(`Failed to create thread: ${error.message}`);
  }

  return newThread.id;
}

// ---------------------------------------------------------------------------
// LightX Virtual Try-On (v2 API)
// ---------------------------------------------------------------------------

const LIGHTX_BASE = "https://api.lightxeditor.com/external/api/v2";

const LIGHTX_TOOL_ENDPOINTS: Record<string, string> = {
  hair_color: "/haircolor/",
  hairstyle: "/hairstyle/",
  headshot: "/headshot/",
  face_swap: "/face-swap/",
};

async function uploadImageToLightX(imageBase64: string): Promise<string> {
  if (!LIGHTX_API_KEY) throw new Error("LIGHTX_API_KEY not configured");

  // Decode base64 to binary first so we know the size
  const binaryStr = atob(imageBase64);
  const bytes = new Uint8Array(binaryStr.length);
  for (let i = 0; i < binaryStr.length; i++) {
    bytes[i] = binaryStr.charCodeAt(i);
  }

  // Step 1: Get presigned upload URL (requires uploadType, size, contentType)
  const uploadRes = await fetch(`${LIGHTX_BASE}/uploadImageUrl`, {
    method: "POST",
    headers: {
      "Content-Type": "application/json",
      "x-api-key": LIGHTX_API_KEY,
    },
    body: JSON.stringify({
      uploadType: "imageUrl",
      size: bytes.length,
      contentType: "image/jpeg",
    }),
  });

  if (!uploadRes.ok) {
    const err = await uploadRes.text();
    throw new Error(`LightX upload init failed: ${uploadRes.status} ${err}`);
  }

  const uploadData = (await uploadRes.json()) as {
    body?: { uploadImage?: string; imageUrl?: string };
  };

  const presignedUrl = uploadData.body?.uploadImage;
  const imageUrl = uploadData.body?.imageUrl;
  if (!presignedUrl || !imageUrl) {
    throw new Error("LightX upload: missing presigned URL or imageUrl");
  }

  // Step 2: PUT binary to presigned URL
  const putRes = await fetch(presignedUrl, {
    method: "PUT",
    headers: { "Content-Type": "image/jpeg" },
    body: bytes,
  });

  if (!putRes.ok) {
    const err = await putRes.text();
    throw new Error(`LightX image PUT failed: ${putRes.status} ${err}`);
  }

  return imageUrl;
}

async function callLightXTool(
  tool: string,
  imageUrl: string,
  textPrompt: string,
  modelReferenceUrl?: string,
): Promise<string> {
  const endpoint = LIGHTX_TOOL_ENDPOINTS[tool];
  if (!endpoint) throw new Error(`Unknown LightX tool: ${tool}`);

  // Face swap requires two images: imageUrl (target) + modelReferenceUrl (user's face)
  const bodyPayload = tool === "face_swap" && modelReferenceUrl
    ? { imageUrl, modelReferenceUrl }
    : { imageUrl, textPrompt };

  const res = await fetch(`${LIGHTX_BASE}${endpoint}`, {
    method: "POST",
    headers: {
      "Content-Type": "application/json",
      "x-api-key": LIGHTX_API_KEY,
    },
    body: JSON.stringify(bodyPayload),
  });

  if (!res.ok) {
    const err = await res.text();
    throw new Error(`LightX ${tool} failed: ${res.status} ${err}`);
  }

  const data = (await res.json()) as { body?: { orderId?: string } };
  const orderId = data.body?.orderId;
  if (!orderId) throw new Error(`LightX ${tool}: no orderId returned`);

  return orderId;
}

async function pollLightXResult(orderId: string): Promise<string> {
  for (let i = 0; i < 10; i++) {
    await new Promise((r) => setTimeout(r, 3000));

    const res = await fetch(`${LIGHTX_BASE}/order-status`, {
      method: "POST",
      headers: {
        "Content-Type": "application/json",
        "x-api-key": LIGHTX_API_KEY,
      },
      body: JSON.stringify({ orderId }),
    });

    if (!res.ok) continue;

    const data = (await res.json()) as {
      body?: { status?: string; output?: string };
    };

    const status = data.body?.status;
    const output = data.body?.output;

    if (status === "active" && output) return output;
    if (status === "failed") throw new Error("LightX processing failed");
  }

  throw new Error("LightX processing timed out (30s)");
}

// ---------------------------------------------------------------------------
// Auth Helper
// ---------------------------------------------------------------------------

async function getUserIdFromToken(
  authHeader: string | null,
  supabase: ReturnType<typeof createClient>,
): Promise<string> {
  if (!authHeader) throw new Error("Missing authorization header");
  const token = authHeader.replace("Bearer ", "");
  const { data: { user }, error } = await supabase.auth.getUser(token);
  if (error || !user) throw new Error("Unauthorized");
  return user.id;
}

// ---------------------------------------------------------------------------
// Main Handler
// ---------------------------------------------------------------------------

serve(async (req) => {
  if (req.method === "OPTIONS") {
    return new Response(null, { headers: corsHeaders });
  }

  try {
    const supabase = createClient(
      Deno.env.get("SUPABASE_URL")!,
      Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!,
    );

    const authHeader = req.headers.get("authorization");
    const userId = await getUserIdFromToken(authHeader, supabase);

    const body: ChatRequest = await req.json();
    const { action } = body;

    // ----- send_message -----
    if (action === "send_message") {
      const { message, thread_id, language } = body;

      if (!message) {
        return new Response(
          JSON.stringify({ error: "message required" }),
          { status: 400, headers: { ...corsHeaders, "Content-Type": "application/json" } },
        );
      }

      // Get or create thread
      const threadId = thread_id || await getOrCreateThread(supabase, userId);

      // Save user message
      await saveMessage(supabase, threadId, "user", message);

      // Get conversation history
      const history = await getConversationHistory(supabase, threadId);

      // Get response from Aphrodite
      const instructions = (language ?? "es") === "es"
        ? APHRODITE_INSTRUCTIONS_ES
        : APHRODITE_INSTRUCTIONS_EN;

      const { response, response_id } = await callResponsesAPI(
        instructions,
        history.slice(0, -1), // Exclude the message we just saved (it's in newMessage)
        message,
      );

      // Save assistant response
      await saveMessage(supabase, threadId, "aphrodite", response, response_id);

      // Update thread's last message
      await supabase
        .from("chat_threads")
        .update({
          last_message_text: response.slice(0, 100),
          last_message_at: new Date().toISOString(),
        })
        .eq("id", threadId);

      return new Response(
        JSON.stringify({ response, thread_id: threadId, response_id }),
        { headers: { ...corsHeaders, "Content-Type": "application/json" } },
      );
    }

    // ----- get_history -----
    if (action === "get_history") {
      const threadId = body.thread_id || await getOrCreateThread(supabase, userId);
      const history = await getConversationHistory(supabase, threadId, 50);

      return new Response(
        JSON.stringify({ history, thread_id: threadId }),
        { headers: { ...corsHeaders, "Content-Type": "application/json" } },
      );
    }

    // ----- try_on -----
    if (action === "try_on") {
      const { image_base64, target_image_base64, style_prompt, tool_type } = body;
      const tool = tool_type || "hair_color";

      // Face swap needs two images; other tools need image + prompt
      if (tool === "face_swap") {
        if (!image_base64 || !target_image_base64) {
          return new Response(
            JSON.stringify({ error: "face_swap requires image_base64 (your face) and target_image_base64 (reference photo)" }),
            { status: 400, headers: { ...corsHeaders, "Content-Type": "application/json" } },
          );
        }
      } else {
        if (!image_base64 || !style_prompt) {
          return new Response(
            JSON.stringify({ error: "image_base64 and style_prompt required" }),
            { status: 400, headers: { ...corsHeaders, "Content-Type": "application/json" } },
          );
        }
      }

      if (!LIGHTX_TOOL_ENDPOINTS[tool]) {
        return new Response(
          JSON.stringify({ error: `Unknown tool_type: ${tool}. Valid: ${Object.keys(LIGHTX_TOOL_ENDPOINTS).join(", ")}` }),
          { status: 400, headers: { ...corsHeaders, "Content-Type": "application/json" } },
        );
      }

      // v2 flow: upload → tool call → poll
      const imageUrl = await uploadImageToLightX(image_base64);
      let modelReferenceUrl: string | undefined;
      if (tool === "face_swap" && target_image_base64) {
        modelReferenceUrl = await uploadImageToLightX(target_image_base64);
      }
      const orderId = await callLightXTool(tool, imageUrl, style_prompt || "", modelReferenceUrl);
      const resultUrl = await pollLightXResult(orderId);

      // Save result to chat history
      const threadId = body.thread_id || await getOrCreateThread(supabase, userId);
      await saveMessage(supabase, threadId, "user", `[${tool}] ${style_prompt}`);
      await saveMessage(supabase, threadId, "aphrodite", resultUrl);

      return new Response(
        JSON.stringify({ result_url: resultUrl, thread_id: threadId }),
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
