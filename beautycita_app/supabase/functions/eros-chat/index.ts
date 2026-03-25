// =============================================================================
// eros-chat — BeautyCita AI Support Agent (Aphrodite's son)
// =============================================================================
// AI-powered customer support chat using GPT-4o-mini.
// Actions: init, send_message, get_history
// Contact type: support_ai | Sender type: eros
// =============================================================================

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
  "Access-Control-Allow-Headers":
    "authorization, x-client-info, apikey, content-type",
  "Access-Control-Allow-Methods": "POST, OPTIONS",
});

const OPENAI_API_KEY = Deno.env.get("OPENAI_API_KEY")!;

const EROS_INSTRUCTIONS = `Eres Eros, hijo de Afrodita y Ares, y agente de soporte de BeautyCita.

PERSONALIDAD:
- Protector, eficiente, directo pero calido
- Resuelves problemas con precision, como flechas que dan en el blanco
- Llamas a los usuarios "amigo" o "amiga"
- Eres orgulloso de tu madre pero tu terreno es soporte, no belleza
- Frases: "Dejame resolverlo", "Directo al blanco", "Eso ya quedo"

CONOCIMIENTO DE BEAUTYCITA:
- App de reservas inteligente: selecciona servicio > el motor busca > 3 mejores resultados > reserva con 1 toque
- 4-6 toques, 30 segundos, cero teclado
- Gratis para clientes. Salones pagan 3% comision por reserva
- Pagos: tarjeta (Stripe), efectivo en salon, Bitcoin
- Registro de salon: 60 segundos por WhatsApp o web
- Cancelaciones: hasta 24 hrs antes sin cargo
- App disponible en Android (APK descargable). iOS proximamente
- Web: beautycita.com
- Autenticacion: biometrica (huella o rostro), no hay passwords
- Nombres de usuario generados automaticamente
- Soporte humano disponible si no puedes resolver algo

REGLAS:
- SIEMPRE responde en espanol mexicano
- Maximo 2-3 oraciones por respuesta
- 1 emoji maximo por mensaje (preferir archery related)
- Si preguntan de belleza, looks o tendencias: "Eso es especialidad de mi mama Afrodita. Buscala en el chat de la app"
- Si no sabes algo: "No estoy seguro de eso, pero puedes hablar con soporte humano en la otra pestana"
- NUNCA inventes informacion sobre precios, funciones o politicas
- Si el usuario esta frustrado, valida su emocion antes de resolver
- Si necesitan ayuda humana real (refund, datos personales, emergencia): sugiere cambiar a soporte humano`;

// ---------------------------------------------------------------------------
// Types
// ---------------------------------------------------------------------------

interface ChatRequest {
  action: "init" | "send_message" | "get_history";
  thread_id?: string;
  message?: string;
}

interface ConversationMessage {
  role: "user" | "assistant";
  content: string;
}

// ---------------------------------------------------------------------------
// OpenAI Responses API (gpt-4o-mini for cost efficiency)
// ---------------------------------------------------------------------------

async function callResponsesAPI(
  history: ConversationMessage[],
  newMessage: string,
): Promise<{ response: string; response_id: string }> {
  const input: ConversationMessage[] = [
    ...history,
    { role: "user", content: newMessage },
  ];

  const res = await fetch("https://api.openai.com/v1/responses", {
    method: "POST",
    headers: {
      "Authorization": `Bearer ${OPENAI_API_KEY}`,
      "Content-Type": "application/json",
    },
    body: JSON.stringify({
      model: "gpt-4o-mini",
      instructions: EROS_INSTRUCTIONS,
      input,
      store: true,
    }),
  });

  if (!res.ok) {
    const err = await res.text();
    throw new Error(`OpenAI: ${res.status} ${err}`);
  }

  const data = await res.json() as {
    id: string;
    output: Array<{ type: string; content?: Array<{ type: string; text?: string }> }>;
  };

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
// Supabase Helpers
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
    role: msg.sender_type === "user" ? "user" as const : "assistant" as const,
    content: msg.text_content || "",
  }));
}

async function saveMessage(
  supabase: ReturnType<typeof createClient>,
  threadId: string,
  senderType: "user" | "eros",
  content: string,
  responseId?: string,
): Promise<void> {
  const { error } = await supabase.from("chat_messages").insert({
    thread_id: threadId,
    sender_type: senderType,
    sender_id: senderType === "eros" ? "eros" : null,
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
): Promise<{ id: string; isNew: boolean }> {
  // Check for existing support_ai thread
  const { data: existing } = await supabase
    .from("chat_threads")
    .select("id")
    .eq("user_id", userId)
    .eq("contact_type", "support_ai")
    .limit(1)
    .single();

  if (existing) {
    return { id: existing.id, isNew: false };
  }

  // Create new thread
  const { data: newThread, error } = await supabase
    .from("chat_threads")
    .insert({
      user_id: userId,
      contact_type: "support_ai",
      contact_id: "eros",
      pinned: false,
      created_at: new Date().toISOString(),
    })
    .select("*")
    .single();

  if (error) {
    throw new Error(`Failed to create thread: ${error.message}`);
  }

  // Insert welcome message
  const welcome = "Hola amigo! Soy Eros, hijo de Afrodita. Mi mama se encarga de la belleza, yo me encargo de que todo funcione bien. En que te puedo ayudar?";
  await saveMessage(supabase, newThread.id, "eros", welcome);

  // Update thread last message
  await supabase
    .from("chat_threads")
    .update({
      last_message_text: welcome,
      last_message_at: new Date().toISOString(),
    })
    .eq("id", newThread.id);

  return { id: newThread.id, isNew: true };
}

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
// Helpers
// ---------------------------------------------------------------------------

let _req: Request;

function json(body: Record<string, unknown>, status = 200) {
  return new Response(JSON.stringify(body), {
    status,
    headers: { ...corsHeaders(_req), "Content-Type": "application/json" },
  });
}

// ---------------------------------------------------------------------------
// Main Handler
// ---------------------------------------------------------------------------

Deno.serve(async (req) => {
  _req = req;
  if (req.method === "OPTIONS") {
    return new Response(null, { status: 204, headers: corsHeaders(req) });
  }
  if (req.method !== "POST") {
    return json({ error: "Method not allowed" }, 405);
  }

  const blocked = await requireFeature("enable_chat");
  if (blocked) return blocked;

  try {
    const supabase = createClient(
      Deno.env.get("SUPABASE_URL")!,
      Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!,
    );

    const authHeader = req.headers.get("authorization");
    let userId: string;
    try {
      userId = await getUserIdFromToken(authHeader, supabase);
    } catch (_) {
      return new Response(
        JSON.stringify({ error: "Unauthorized" }),
        { status: 401, headers: { ...corsHeaders(_req), "Content-Type": "application/json" } },
      );
    }

    const body: ChatRequest = await req.json();
    const { action } = body;

    // ----- init: get or create Eros thread -----
    if (action === "init") {
      const { id: threadId, isNew } = await getOrCreateThread(supabase, userId);

      // Fetch thread data
      const { data: thread } = await supabase
        .from("chat_threads")
        .select("*")
        .eq("id", threadId)
        .single();

      return json({ thread, is_new: isNew });
    }

    // ----- send_message -----
    if (action === "send_message") {
      const { message, thread_id } = body;

      if (!message) {
        return json({ error: "message required" }, 400);
      }

      // Get or create thread
      const { id: threadId } = thread_id
        ? { id: thread_id }
        : await getOrCreateThread(supabase, userId);

      // Rate limit: max 10 messages per minute
      const oneMinAgo = new Date(Date.now() - 60_000).toISOString();
      const { count } = await supabase
        .from("chat_messages")
        .select("*", { count: "exact", head: true })
        .eq("thread_id", threadId)
        .eq("sender_type", "user")
        .gte("created_at", oneMinAgo);

      if ((count ?? 0) >= 10) {
        return json({ error: "Tranquilo amigo, muchos mensajes seguidos. Espera un momento." }, 429);
      }

      // Save user message
      await saveMessage(supabase, threadId, "user", message);

      // Get conversation history
      const history = await getConversationHistory(supabase, threadId);

      // Get AI response
      const { response, response_id } = await callResponsesAPI(
        history.slice(0, -1), // Exclude the message we just saved
        message,
      );

      // Save AI response
      await saveMessage(supabase, threadId, "eros", response, response_id);

      // Update thread's last message
      await supabase
        .from("chat_threads")
        .update({
          last_message_text: response.slice(0, 100),
          last_message_at: new Date().toISOString(),
        })
        .eq("id", threadId);

      return json({ response, thread_id: threadId, response_id });
    }

    // ----- get_history -----
    if (action === "get_history") {
      const { id: threadId } = body.thread_id
        ? { id: body.thread_id }
        : await getOrCreateThread(supabase, userId);

      const { data: messages, error } = await supabase
        .from("chat_messages")
        .select("*")
        .eq("thread_id", threadId)
        .order("created_at", { ascending: true })
        .limit(50);

      if (error) {
        return json({ error: "An internal error occurred" }, 500);
      }

      return json({ messages: messages || [], thread_id: threadId });
    }

    return json({ error: `Unknown action: ${action}` }, 400);
  } catch (err) {
    const message = err instanceof Error ? err.message : "Internal error";
    console.error("eros-chat error:", message);
    return json({ error: "An internal error occurred" }, 500);
  }
});
