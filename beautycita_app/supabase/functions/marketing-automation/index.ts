// =============================================================================
// marketing-automation — Scheduled execution engine for automated messages
// =============================================================================
// Runs on a schedule (pg_cron every 15 minutes). Reads `automated_messages`
// where `is_active = true`, finds matching users/appointments per trigger type,
// sends via appropriate channel, and logs to `automated_message_log`.
//
// Trigger types implemented:
//   - review_request:    24h after completed appointment (if no review exists)
//   - no_show_followup:  2h after no-show appointment
//
// Also processes the WA retry queue (#32).
//
// Auth: CRON_SECRET or service-role key (same pattern as booking-reminder).
// =============================================================================

import { createClient } from "https://esm.sh/@supabase/supabase-js@2";
import { resolveNotificationText } from "../_shared/notification_templates.ts";
import { sendWhatsAppWithRetry, processWaRetryQueue } from "../_shared/wa_queue.ts";
import { corsHeaders, handleCorsPreflightIfOptions } from "../_shared/cors.ts";

const SUPABASE_URL = Deno.env.get("SUPABASE_URL") ?? "";
const SUPABASE_SERVICE_KEY = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY") ?? "";


function json(body: unknown, status = 200, req?: Request) {
  return new Response(JSON.stringify(body), {
    status,
    headers: { ...corsHeaders(req!), "Content-Type": "application/json" },
  });
}

// ── Trigger handlers ────────────────────────────────────────────────────────

interface AutomatedMessage {
  id: string;
  business_id: string;
  trigger_type: string;
  delay_hours: number;
  channel: string;
  message_template: string;
}

interface TriggerResult {
  trigger_type: string;
  sent: number;
  skipped: number;
  failed: number;
}

/**
 * review_request: Find completed appointments where:
 * - completed_at is older than delay_hours (default 24h)
 * - no review exists for that appointment
 * - no automated_message_log entry exists for this trigger + appointment
 */
async function processReviewRequests(
  supabase: ReturnType<typeof createClient>,
  messages: AutomatedMessage[]
): Promise<TriggerResult> {
  const result: TriggerResult = { trigger_type: "review_request", sent: 0, skipped: 0, failed: 0 };

  for (const msg of messages) {
    const cutoff = new Date(Date.now() - msg.delay_hours * 60 * 60 * 1000);

    // Find completed appointments for this business that are old enough
    const { data: appointments, error: apptErr } = await supabase
      .from("appointments")
      .select("id, user_id, service_name, business_id, completed_at")
      .eq("business_id", msg.business_id)
      .eq("status", "completed")
      .lte("completed_at", cutoff.toISOString())
      .limit(50);

    if (apptErr || !appointments || appointments.length === 0) {
      continue;
    }

    for (const appt of appointments) {
      // Check if review already exists for this appointment
      const { count: reviewCount } = await supabase
        .from("reviews")
        .select("id", { count: "exact", head: true })
        .eq("appointment_id", appt.id);

      if ((reviewCount ?? 0) > 0) {
        result.skipped++;
        continue;
      }

      // Check if we already sent a review request for this appointment
      const { count: logCount } = await supabase
        .from("automated_message_log")
        .select("id", { count: "exact", head: true })
        .eq("appointment_id", appt.id)
        .eq("trigger_type", "review_request");

      if ((logCount ?? 0) > 0) {
        result.skipped++;
        continue;
      }

      // Get user profile for sending
      const { data: profile } = await supabase
        .from("profiles")
        .select("phone, fcm_token, full_name")
        .eq("id", appt.user_id)
        .single();

      if (!profile) {
        result.skipped++;
        continue;
      }

      // Get business name
      const { data: business } = await supabase
        .from("businesses")
        .select("name")
        .eq("id", msg.business_id)
        .single();

      const businessName = business?.name ?? "tu salon";
      const userName = profile.full_name ?? "Cliente";
      const deepLink = `https://beautycita.com/review/${appt.id}`;

      // Build message from template with variable substitution
      const variables: Record<string, string> = {
        USER_NAME: userName,
        SALON_NAME: businessName,
        SERVICE_NAME: appt.service_name ?? "servicio",
        REVIEW_LINK: deepLink,
      };

      // Use DB template if available, otherwise use the automated_messages template
      const fallbackText = msg.message_template
        .replace(/\{\{USER_NAME\}\}/g, userName)
        .replace(/\{\{SALON_NAME\}\}/g, businessName)
        .replace(/\{\{SERVICE_NAME\}\}/g, appt.service_name ?? "servicio")
        .replace(/\{\{REVIEW_LINK\}\}/g, deepLink);

      const messageText = await resolveNotificationText(
        supabase,
        "review_request",
        msg.channel,
        "customer",
        variables,
        fallbackText
      );

      // Send via appropriate channel
      const sendResult = await sendViaChannel(
        supabase,
        msg.channel,
        profile,
        messageText,
        appt.user_id,
        { trigger: "review_request", appointment_id: appt.id }
      );

      // Log the send attempt
      await supabase.from("automated_message_log").insert({
        automated_message_id: msg.id,
        business_id: msg.business_id,
        user_id: appt.user_id,
        trigger_type: "review_request",
        channel: msg.channel,
        status: sendResult ? "sent" : "failed",
        appointment_id: appt.id,
      });

      if (sendResult) {
        result.sent++;
      } else {
        result.failed++;
      }
    }
  }

  return result;
}

/**
 * no_show_followup: Find no-show appointments where:
 * - updated_at (when marked no-show) is older than delay_hours (default 2h)
 * - no automated_message_log entry exists for this trigger + appointment
 */
async function processNoShowFollowups(
  supabase: ReturnType<typeof createClient>,
  messages: AutomatedMessage[]
): Promise<TriggerResult> {
  const result: TriggerResult = { trigger_type: "no_show_followup", sent: 0, skipped: 0, failed: 0 };

  for (const msg of messages) {
    const cutoff = new Date(Date.now() - msg.delay_hours * 60 * 60 * 1000);

    // Find no-show appointments for this business that are old enough
    const { data: appointments, error: apptErr } = await supabase
      .from("appointments")
      .select("id, user_id, service_name, business_id, updated_at")
      .eq("business_id", msg.business_id)
      .eq("status", "no_show")
      .lte("updated_at", cutoff.toISOString())
      .limit(50);

    if (apptErr || !appointments || appointments.length === 0) {
      continue;
    }

    for (const appt of appointments) {
      // Check if we already sent a follow-up for this appointment
      const { count: logCount } = await supabase
        .from("automated_message_log")
        .select("id", { count: "exact", head: true })
        .eq("appointment_id", appt.id)
        .eq("trigger_type", "no_show_followup");

      if ((logCount ?? 0) > 0) {
        result.skipped++;
        continue;
      }

      // Get user profile
      const { data: profile } = await supabase
        .from("profiles")
        .select("phone, fcm_token, full_name")
        .eq("id", appt.user_id)
        .single();

      if (!profile) {
        result.skipped++;
        continue;
      }

      // Get business name
      const { data: business } = await supabase
        .from("businesses")
        .select("name")
        .eq("id", msg.business_id)
        .single();

      const businessName = business?.name ?? "tu salon";
      const userName = profile.full_name ?? "Cliente";
      const rebookLink = `https://beautycita.com/book/${msg.business_id}`;

      const variables: Record<string, string> = {
        USER_NAME: userName,
        SALON_NAME: businessName,
        SERVICE_NAME: appt.service_name ?? "servicio",
        REBOOK_LINK: rebookLink,
      };

      const fallbackText = msg.message_template
        .replace(/\{\{USER_NAME\}\}/g, userName)
        .replace(/\{\{SALON_NAME\}\}/g, businessName)
        .replace(/\{\{SERVICE_NAME\}\}/g, appt.service_name ?? "servicio")
        .replace(/\{\{REBOOK_LINK\}\}/g, rebookLink);

      const messageText = await resolveNotificationText(
        supabase,
        "no_show_followup",
        msg.channel,
        "customer",
        variables,
        fallbackText
      );

      const sendResult = await sendViaChannel(
        supabase,
        msg.channel,
        profile,
        messageText,
        appt.user_id,
        { trigger: "no_show_followup", appointment_id: appt.id }
      );

      await supabase.from("automated_message_log").insert({
        automated_message_id: msg.id,
        business_id: msg.business_id,
        user_id: appt.user_id,
        trigger_type: "no_show_followup",
        channel: msg.channel,
        status: sendResult ? "sent" : "failed",
        appointment_id: appt.id,
      });

      if (sendResult) {
        result.sent++;
      } else {
        result.failed++;
      }
    }
  }

  return result;
}

// ── Channel dispatch ────────────────────────────────────────────────────────

interface ProfileInfo {
  phone?: string | null;
  fcm_token?: string | null;
  full_name?: string | null;
}

/**
 * Send a message via the specified channel.
 * On WA failure, automatically queues for retry.
 */
async function sendViaChannel(
  supabase: ReturnType<typeof createClient>,
  channel: string,
  profile: ProfileInfo,
  message: string,
  userId: string,
  metadata: Record<string, unknown> = {}
): Promise<boolean> {
  switch (channel) {
    case "whatsapp": {
      if (!profile.phone) {
        console.log(`[MARKETING] No phone for user ${userId}, skipping WA`);
        return false;
      }
      const { sent } = await sendWhatsAppWithRetry(
        supabase,
        profile.phone,
        message,
        metadata
      );
      return sent;
    }

    case "push": {
      try {
        const pushRes = await fetch(`${SUPABASE_URL}/functions/v1/send-push-notification`, {
          method: "POST",
          headers: {
            Authorization: `Bearer ${SUPABASE_SERVICE_KEY}`,
            "Content-Type": "application/json",
          },
          body: JSON.stringify({
            user_id: userId,
            notification_type: "booking_reminder", // reuse existing type for delivery
            custom_title: "BeautyCita",
            custom_body: message,
            data: {
              type: metadata.trigger as string ?? "marketing",
              ...(metadata.appointment_id ? { appointment_id: metadata.appointment_id as string } : {}),
            },
          }),
        });
        return pushRes.ok;
      } catch (err) {
        console.error(`[MARKETING] Push error for ${userId}:`, err);
        return false;
      }
    }

    case "email": {
      try {
        // Get user email from auth
        const { data: authUser } = await supabase.auth.admin.getUserById(userId);
        const email = authUser?.user?.email;
        if (!email) {
          console.log(`[MARKETING] No email for user ${userId}`);
          return false;
        }

        const emailRes = await fetch(`${SUPABASE_URL}/functions/v1/send-email`, {
          method: "POST",
          headers: {
            Authorization: `Bearer ${SUPABASE_SERVICE_KEY}`,
            "Content-Type": "application/json",
          },
          body: JSON.stringify({
            template: "promotion",
            to: email,
            subject: "BeautyCita",
            variables: {
              USER_NAME: profile.full_name ?? "Cliente",
              CONTENT: message,
            },
          }),
        });
        return emailRes.ok;
      } catch (err) {
        console.error(`[MARKETING] Email error for ${userId}:`, err);
        return false;
      }
    }

    default:
      console.error(`[MARKETING] Unknown channel: ${channel}`);
      return false;
  }
}

// ── HTTP Handler ────────────────────────────────────────────────────────────

Deno.serve(async (req) => {
  const _pre = handleCorsPreflightIfOptions(req);
  if (_pre) return _pre;

  // ── Auth: CRON_SECRET or service-role key ──
  const authHeader = req.headers.get("authorization") ?? "";
  const cronSecret = Deno.env.get("CRON_SECRET") ?? "";
  const isValidCron = cronSecret && authHeader === `Bearer ${cronSecret}`;
  const isServiceRole = authHeader === `Bearer ${SUPABASE_SERVICE_KEY}`;

  if (!isValidCron && !isServiceRole) {
    return json({ error: "Unauthorized" }, 401, req);
  }

  const supabase = createClient(SUPABASE_URL, SUPABASE_SERVICE_KEY);

  try {
    // -----------------------------------------------------------------------
    // 1. Fetch all active automated messages grouped by trigger type
    // -----------------------------------------------------------------------
    const { data: allMessages, error: msgErr } = await supabase
      .from("automated_messages")
      .select("id, business_id, trigger_type, delay_hours, channel, message_template")
      .eq("is_active", true);

    if (msgErr) {
      console.error("[MARKETING] Failed to fetch automated_messages:", msgErr.message);
      return json({ error: msgErr.message }, 500, req);
    }

    const messages = (allMessages ?? []) as AutomatedMessage[];
    const results: TriggerResult[] = [];

    // Group by trigger type
    const byTrigger = new Map<string, AutomatedMessage[]>();
    for (const m of messages) {
      const arr = byTrigger.get(m.trigger_type) ?? [];
      arr.push(m);
      byTrigger.set(m.trigger_type, arr);
    }

    // -----------------------------------------------------------------------
    // 2. Process each trigger type
    // -----------------------------------------------------------------------
    const reviewMessages = byTrigger.get("review_request") ?? [];
    if (reviewMessages.length > 0) {
      const r = await processReviewRequests(supabase, reviewMessages);
      results.push(r);
      console.log(`[MARKETING] review_request: ${r.sent} sent, ${r.skipped} skipped, ${r.failed} failed`);
    }

    const noShowMessages = byTrigger.get("no_show_followup") ?? [];
    if (noShowMessages.length > 0) {
      const r = await processNoShowFollowups(supabase, noShowMessages);
      results.push(r);
      console.log(`[MARKETING] no_show_followup: ${r.sent} sent, ${r.skipped} skipped, ${r.failed} failed`);
    }

    // -----------------------------------------------------------------------
    // 3. Process WA retry queue (#32)
    // -----------------------------------------------------------------------
    const waQueueResult = await processWaRetryQueue(supabase);
    console.log(
      `[MARKETING] WA retry queue: ${waQueueResult.sent} sent, ` +
      `${waQueueResult.failed} failed, ${waQueueResult.remaining} remaining`
    );

    // -----------------------------------------------------------------------
    // 4. Return summary
    // -----------------------------------------------------------------------
    return json({
      success: true,
      triggers: results,
      wa_retry_queue: waQueueResult,
      automated_messages_count: messages.length,
    }, 200, req);
  } catch (err) {
    console.error("[MARKETING] Handler error:", (err as Error).message);
    return json({ error: "Internal server error" }, 500, req);
  }
});
