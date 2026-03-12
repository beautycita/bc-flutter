// outreach-contact/index.ts
// Outreach command center: send messages, log calls, record audio, transcribe.
// Actions:
//   send_wa           — send WhatsApp message to discovered salon (with optional template)
//   send_email        — log email outreach (delivery pending Infobip integration)
//   send_sms          — log SMS outreach (delivery pending Infobip integration)
//   log_call          — log a phone/WA call with outcome
//   upload_recording  — upload call recording to Supabase Storage
//   transcribe        — transcribe a recording via OpenAI Whisper
//   get_history       — fetch outreach history for a salon
//   get_templates     — fetch active outreach templates

import { serve } from "https://deno.land/std@0.168.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

const SUPABASE_URL = Deno.env.get("SUPABASE_URL") ?? "";
const SUPABASE_SERVICE_KEY = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY") ?? "";
const SUPABASE_ANON_KEY = Deno.env.get("SUPABASE_ANON_KEY") ?? "";

const WA_API_URL = Deno.env.get("BEAUTYPI_WA_URL") ?? "";
const WA_API_TOKEN = Deno.env.get("BEAUTYPI_WA_TOKEN") ?? "";

const OPENAI_API_KEY = Deno.env.get("OPENAI_API_KEY") ?? "";

// ── Valid call outcomes ──

const VALID_OUTCOMES = [
  "interested",
  "not_interested",
  "callback",
  "no_answer",
  "wrong_number",
  "voicemail",
] as const;

// ── Template variable substitution ──

function substituteVars(
  template: string,
  salon: Record<string, unknown>,
  rpName: string,
  rpPhone: string,
): string {
  return template
    .replace(/\{salon_name\}/g, String(salon.business_name ?? ""))
    .replace(/\{city\}/g, String(salon.location_city ?? ""))
    .replace(/\{rating\}/g, String(salon.rating_average ?? ""))
    .replace(/\{review_count\}/g, String(salon.rating_count ?? "0"))
    .replace(/\{rp_name\}/g, rpName)
    .replace(/\{rp_phone\}/g, rpPhone)
    .replace(/\{interest_count\}/g, String(salon.interest_count ?? "0"))
    .replace(/\{booking_system\}/g, String(salon.booking_system ?? "ninguno"));
}

// ── Auth: verify admin/superadmin ──

async function verifyAdmin(
  token: string,
  serviceClient: ReturnType<typeof createClient>,
): Promise<{ user: { id: string }; error?: Response }> {
  const userClient = createClient(SUPABASE_URL, SUPABASE_ANON_KEY, {
    global: { headers: { Authorization: `Bearer ${token}` } },
  });
  const {
    data: { user },
    error: authError,
  } = await userClient.auth.getUser();

  if (authError || !user) {
    return { user: null as any, error: jsonResponse({ error: "Unauthorized" }, 401) };
  }

  const { data: profile } = await serviceClient
    .from("profiles")
    .select("role")
    .eq("id", user.id)
    .single();

  if (!profile || !["admin", "superadmin"].includes(profile.role)) {
    return { user: null as any, error: jsonResponse({ error: "Admin access required" }, 403) };
  }

  return { user: { id: user.id } };
}

// ── Fetch salon by ID ──

async function fetchSalon(
  serviceClient: ReturnType<typeof createClient>,
  id: string,
): Promise<{ salon: Record<string, any> | null; error?: Response }> {
  const { data: salon, error } = await serviceClient
    .from("discovered_salons")
    .select("*")
    .eq("id", id)
    .single();

  if (error || !salon) {
    return { salon: null, error: jsonResponse({ error: "Salon not found" }, 404) };
  }
  return { salon };
}

// ── Resolve message from template or direct text ──

async function resolveMessage(
  serviceClient: ReturnType<typeof createClient>,
  message: string | undefined,
  templateId: string | undefined,
  salon: Record<string, any>,
  rpName: string,
  rpPhone: string,
): Promise<{ text: string; templateId?: string } | null> {
  if (templateId) {
    const { data: template } = await serviceClient
      .from("outreach_templates")
      .select("id, body_template")
      .eq("id", templateId)
      .single();

    if (!template) return null;

    const text = substituteVars(template.body_template, salon, rpName, rpPhone);
    return { text, templateId: template.id };
  }
  if (message) {
    return { text: String(message) };
  }
  return null;
}

serve(async (req: Request) => {
  if (req.method === "OPTIONS") {
    return new Response(null, {
      headers: {
        "Access-Control-Allow-Origin": "*",
        "Access-Control-Allow-Methods": "POST, OPTIONS",
        "Access-Control-Allow-Headers": "authorization, content-type, apikey",
      },
    });
  }

  try {
    const { action, ...params } = await req.json();

    const authHeader = req.headers.get("authorization") ?? "";
    const token = authHeader.replace("Bearer ", "");

    const serviceClient = createClient(SUPABASE_URL, SUPABASE_SERVICE_KEY);

    // All actions require admin/superadmin
    const { user, error: authErr } = await verifyAdmin(token, serviceClient);
    if (authErr) return authErr;

    // ───────── SEND_WA: send WhatsApp message ─────────
    if (action === "send_wa") {
      const { discovered_salon_id, message, template_id, rp_name, rp_phone } = params;

      if (!discovered_salon_id) {
        return jsonResponse({ error: "discovered_salon_id required" }, 400);
      }
      if (!rp_name || !rp_phone) {
        return jsonResponse({ error: "rp_name and rp_phone required" }, 400);
      }

      const { salon, error: salonErr } = await fetchSalon(serviceClient, discovered_salon_id);
      if (salonErr) return salonErr;

      // Resolve message (direct or from template)
      const resolved = await resolveMessage(
        serviceClient, message, template_id, salon!, rp_name, rp_phone,
      );
      if (!resolved) {
        return jsonResponse({ error: "message or valid template_id required" }, 400);
      }

      const recipientPhone = String(salon!.whatsapp || salon!.phone || "");
      if (!recipientPhone) {
        return jsonResponse({ error: "Salon has no phone number" }, 400);
      }

      // Check WhatsApp then send
      let sent = false;
      try {
        const checkRes = await fetch(`${WA_API_URL}/api/wa/check`, {
          method: "POST",
          headers: {
            "Content-Type": "application/json",
            Authorization: `Bearer ${WA_API_TOKEN}`,
          },
          body: JSON.stringify({ phone: recipientPhone }),
        });
        const checkData = await checkRes.json();

        if (checkData.onWhatsApp) {
          const sendRes = await fetch(`${WA_API_URL}/api/wa/send`, {
            method: "POST",
            headers: {
              "Content-Type": "application/json",
              Authorization: `Bearer ${WA_API_TOKEN}`,
            },
            body: JSON.stringify({ phone: recipientPhone, message: resolved.text }),
          });
          const sendData = await sendRes.json();
          sent = sendData.sent === true;
        }
      } catch (e) {
        console.error(`[outreach-contact:send_wa] WA send failed: ${e}`);
      }

      // Log to salon_outreach_log
      await serviceClient.from("salon_outreach_log").insert({
        discovered_salon_id,
        channel: "wa_message",
        recipient_phone: recipientPhone,
        message_text: resolved.text,
        template_id: resolved.templateId ?? null,
        rp_user_id: user.id,
        interest_count: salon!.interest_count ?? 0,
      });

      console.log(`[outreach-contact:send_wa] Salon: ${salon!.business_name}, Sent: ${sent}`);
      return jsonResponse({ success: true, sent });
    }

    // ───────── SEND_EMAIL: log email outreach (delivery pending) ─────────
    if (action === "send_email") {
      const {
        discovered_salon_id, subject, message, template_id,
        recipient_email, rp_name, rp_phone,
      } = params;

      if (!discovered_salon_id) {
        return jsonResponse({ error: "discovered_salon_id required" }, 400);
      }
      if (!subject) {
        return jsonResponse({ error: "subject required" }, 400);
      }

      const { salon, error: salonErr } = await fetchSalon(serviceClient, discovered_salon_id);
      if (salonErr) return salonErr;

      // Resolve message
      const resolved = await resolveMessage(
        serviceClient, message, template_id, salon!,
        rp_name ?? "", rp_phone ?? "",
      );
      if (!resolved) {
        return jsonResponse({ error: "message or valid template_id required" }, 400);
      }

      // Log only -- email delivery pending Infobip integration
      await serviceClient.from("salon_outreach_log").insert({
        discovered_salon_id,
        channel: "email",
        message_text: resolved.text,
        subject,
        template_id: resolved.templateId ?? null,
        rp_user_id: user.id,
      });

      console.log(`[outreach-contact:send_email] Salon: ${salon!.business_name} (logged)`);
      return jsonResponse({
        success: true,
        logged: true,
        note: "Email delivery pending Infobip integration",
      });
    }

    // ───────── SEND_SMS: log SMS outreach (delivery pending) ─────────
    if (action === "send_sms") {
      const { discovered_salon_id, message, rp_name } = params;

      if (!discovered_salon_id) {
        return jsonResponse({ error: "discovered_salon_id required" }, 400);
      }
      if (!message) {
        return jsonResponse({ error: "message required" }, 400);
      }

      const { salon, error: salonErr } = await fetchSalon(serviceClient, discovered_salon_id);
      if (salonErr) return salonErr;

      const recipientPhone = String(salon!.phone || salon!.whatsapp || "");

      // Log only -- SMS delivery pending Infobip integration
      await serviceClient.from("salon_outreach_log").insert({
        discovered_salon_id,
        channel: "sms",
        recipient_phone: recipientPhone || null,
        message_text: String(message),
        rp_user_id: user.id,
      });

      console.log(`[outreach-contact:send_sms] Salon: ${salon!.business_name} (logged)`);
      return jsonResponse({
        success: true,
        logged: true,
        note: "SMS delivery pending Infobip integration",
      });
    }

    // ───────── LOG_CALL: record phone or WA call ─────────
    if (action === "log_call") {
      const { discovered_salon_id, channel, notes, outcome, duration_seconds } = params;

      if (!discovered_salon_id) {
        return jsonResponse({ error: "discovered_salon_id required" }, 400);
      }
      if (!channel || !["phone", "wa_call"].includes(channel)) {
        return jsonResponse({ error: "channel must be 'phone' or 'wa_call'" }, 400);
      }
      if (outcome && !VALID_OUTCOMES.includes(outcome)) {
        return jsonResponse(
          { error: `Invalid outcome. Valid: ${VALID_OUTCOMES.join(", ")}` },
          400,
        );
      }

      // Verify salon exists
      const { salon, error: salonErr } = await fetchSalon(serviceClient, discovered_salon_id);
      if (salonErr) return salonErr;

      // Build notes with outcome included
      const fullNotes = [
        outcome ? `outcome: ${outcome}` : null,
        notes ? String(notes) : null,
      ]
        .filter(Boolean)
        .join(" | ");

      const { data: inserted, error: insertError } = await serviceClient
        .from("salon_outreach_log")
        .insert({
          discovered_salon_id,
          channel,
          notes: fullNotes || null,
          rp_user_id: user.id,
          call_duration_seconds: duration_seconds ?? null,
        })
        .select("id")
        .single();

      if (insertError) {
        return jsonResponse({ error: insertError.message }, 500);
      }

      console.log(
        `[outreach-contact:log_call] Salon: ${salon!.business_name}, ` +
        `Channel: ${channel}, Outcome: ${outcome ?? "none"}`,
      );
      return jsonResponse({ success: true, log_id: inserted.id });
    }

    // ───────── UPLOAD_RECORDING: upload call audio to Supabase Storage ─────────
    if (action === "upload_recording") {
      const { discovered_salon_id, log_id, audio_base64, content_type } = params;

      if (!discovered_salon_id || !log_id || !audio_base64) {
        return jsonResponse(
          { error: "discovered_salon_id, log_id, and audio_base64 required" },
          400,
        );
      }

      // Verify log entry exists
      const { data: logEntry, error: logErr } = await serviceClient
        .from("salon_outreach_log")
        .select("id")
        .eq("id", log_id)
        .eq("discovered_salon_id", discovered_salon_id)
        .single();

      if (logErr || !logEntry) {
        return jsonResponse({ error: "Outreach log entry not found" }, 404);
      }

      const mimeType = content_type || "audio/webm";

      // Decode base64 to bytes
      const binaryString = atob(audio_base64);
      const bytes = new Uint8Array(binaryString.length);
      for (let i = 0; i < binaryString.length; i++) {
        bytes[i] = binaryString.charCodeAt(i);
      }

      const filePath = `${discovered_salon_id}/${Date.now()}.webm`;

      const { error: uploadError } = await serviceClient.storage
        .from("outreach-recordings")
        .upload(filePath, bytes, {
          contentType: mimeType,
          upsert: false,
        });

      if (uploadError) {
        console.error(`[outreach-contact:upload_recording] Upload failed: ${uploadError.message}`);
        return jsonResponse({ error: `Upload failed: ${uploadError.message}` }, 500);
      }

      // Get public URL
      const { data: urlData } = serviceClient.storage
        .from("outreach-recordings")
        .getPublicUrl(filePath);

      const recordingUrl = urlData?.publicUrl ?? "";

      // Update the log entry with the recording URL
      const { error: updateError } = await serviceClient
        .from("salon_outreach_log")
        .update({ recording_url: recordingUrl })
        .eq("id", log_id);

      if (updateError) {
        console.error(
          `[outreach-contact:upload_recording] Log update failed: ${updateError.message}`,
        );
      }

      console.log(`[outreach-contact:upload_recording] Log: ${log_id}, URL: ${recordingUrl}`);
      return jsonResponse({ success: true, recording_url: recordingUrl });
    }

    // ───────── TRANSCRIBE: Whisper transcription of call recording ─────────
    if (action === "transcribe") {
      const { log_id } = params;

      if (!log_id) {
        return jsonResponse({ error: "log_id required" }, 400);
      }
      if (!OPENAI_API_KEY) {
        return jsonResponse({ error: "OpenAI API key not configured" }, 500);
      }

      // Fetch log entry to get recording URL
      const { data: logEntry, error: logErr } = await serviceClient
        .from("salon_outreach_log")
        .select("id, recording_url")
        .eq("id", log_id)
        .single();

      if (logErr || !logEntry) {
        return jsonResponse({ error: "Log entry not found" }, 404);
      }
      if (!logEntry.recording_url) {
        return jsonResponse({ error: "No recording attached to this log entry" }, 400);
      }

      // Download the audio file
      const audioRes = await fetch(logEntry.recording_url);
      if (!audioRes.ok) {
        return jsonResponse({ error: "Failed to download recording" }, 500);
      }
      const audioBlob = await audioRes.blob();

      // Determine filename from URL
      const urlPath = new URL(logEntry.recording_url).pathname;
      const filename = urlPath.split("/").pop() ?? "recording.webm";

      // Send to OpenAI Whisper
      const formData = new FormData();
      formData.append("file", audioBlob, filename);
      formData.append("model", "whisper-1");
      formData.append("language", "es");

      const whisperRes = await fetch("https://api.openai.com/v1/audio/transcriptions", {
        method: "POST",
        headers: { Authorization: `Bearer ${OPENAI_API_KEY}` },
        body: formData,
      });

      if (!whisperRes.ok) {
        const errText = await whisperRes.text();
        console.error(`[outreach-contact:transcribe] Whisper error (${whisperRes.status}): ${errText}`);
        return jsonResponse({ error: "Transcription failed" }, 500);
      }

      const whisperData = await whisperRes.json();
      const transcript = whisperData.text ?? "";

      // Save transcript to log entry
      const { error: updateError } = await serviceClient
        .from("salon_outreach_log")
        .update({ transcript })
        .eq("id", log_id);

      if (updateError) {
        console.error(`[outreach-contact:transcribe] Save failed: ${updateError.message}`);
      }

      console.log(`[outreach-contact:transcribe] Log: ${log_id}, Length: ${transcript.length} chars`);
      return jsonResponse({ success: true, transcript });
    }

    // ───────── GET_HISTORY: outreach log for a salon ─────────
    if (action === "get_history") {
      const { discovered_salon_id } = params;

      if (!discovered_salon_id) {
        return jsonResponse({ error: "discovered_salon_id required" }, 400);
      }

      const { data: entries, error: histErr } = await serviceClient
        .from("salon_outreach_log")
        .select("*")
        .eq("discovered_salon_id", discovered_salon_id)
        .order("sent_at", { ascending: false });

      if (histErr) {
        return jsonResponse({ error: histErr.message }, 500);
      }

      // Batch-fetch display names for unique rp_user_ids
      const rpUserIds = [
        ...new Set(
          (entries ?? [])
            .map((e: Record<string, unknown>) => e.rp_user_id)
            .filter(Boolean) as string[],
        ),
      ];

      const nameMap: Record<string, string> = {};
      if (rpUserIds.length > 0) {
        const { data: profiles } = await serviceClient
          .from("profiles")
          .select("id, full_name, username")
          .in("id", rpUserIds);

        for (const p of profiles ?? []) {
          nameMap[p.id] = p.full_name || p.username || "Unknown";
        }
      }

      // Attach rp_display_name to each entry
      const history = (entries ?? []).map((e: Record<string, unknown>) => ({
        ...e,
        rp_display_name: e.rp_user_id
          ? nameMap[String(e.rp_user_id)] ?? "Unknown"
          : null,
      }));

      return jsonResponse({ history });
    }

    // ───────── GET_TEMPLATES: active outreach templates ─────────
    if (action === "get_templates") {
      const { channel } = params;

      let query = serviceClient
        .from("outreach_templates")
        .select("*")
        .eq("is_active", true)
        .order("sort_order", { ascending: true });

      if (channel) {
        query = query.eq("channel", channel);
      }

      const { data: templates, error: tplErr } = await query;

      if (tplErr) {
        return jsonResponse({ error: tplErr.message }, 500);
      }

      return jsonResponse({ templates: templates ?? [] });
    }

    return jsonResponse({ error: `Unknown action: ${action}` }, 400);
  } catch (err) {
    console.error("[outreach-contact] Error:", err);
    return jsonResponse({ error: "An internal error occurred" }, 500);
  }
});

function jsonResponse(body: unknown, status = 200): Response {
  return new Response(JSON.stringify(body), {
    status,
    headers: {
      "Content-Type": "application/json",
      "Access-Control-Allow-Origin": "*",
    },
  });
}
