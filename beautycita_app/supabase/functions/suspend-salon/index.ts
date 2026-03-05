// =============================================================================
// suspend-salon — Manage salon suspension and hold status
// =============================================================================
// Actions:
//   suspend    - Set is_active=false, notify all clients with pending/confirmed
//                future bookings. Bookings are NOT cancelled — client decides.
//   reactivate - Set is_active=true, return success.
//   hold       - Set on_hold=true (disappears from search, no notifications).
//   unhold     - Set on_hold=false.
//
// Requires admin auth (profile role = 'admin').
// =============================================================================

import { serve } from "https://deno.land/std@0.177.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers":
    "authorization, x-client-info, apikey, content-type",
};

const SUPABASE_URL = Deno.env.get("SUPABASE_URL") ?? "";
const SUPABASE_SERVICE_ROLE_KEY =
  Deno.env.get("SUPABASE_SERVICE_ROLE_KEY") ?? "";

type Action = "suspend" | "reactivate" | "hold" | "unhold";

interface SuspendSalonRequest {
  business_id: string;
  action: Action;
}

serve(async (req) => {
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders });
  }

  try {
    const supabase = createClient(SUPABASE_URL, SUPABASE_SERVICE_ROLE_KEY);

    // ── Auth check ─────────────────────────────────────────────────────
    const authHeader = req.headers.get("authorization") ?? "";
    const token = authHeader.replace("Bearer ", "");
    const {
      data: { user },
      error: authError,
    } = await supabase.auth.getUser(token);

    if (authError || !user) {
      return json({ error: "Unauthorized" }, 401);
    }

    // ── Admin check ────────────────────────────────────────────────────
    const { data: profile, error: profileError } = await supabase
      .from("profiles")
      .select("role")
      .eq("id", user.id)
      .single();

    if (profileError || !profile || profile.role !== "admin") {
      return json({ error: "Forbidden: admin access required" }, 403);
    }

    // ── Parse request ──────────────────────────────────────────────────
    const body: SuspendSalonRequest = await req.json();
    const { business_id, action } = body;

    if (!business_id) {
      return json({ error: "business_id is required" }, 400);
    }

    const validActions: Action[] = ["suspend", "reactivate", "hold", "unhold"];
    if (!action || !validActions.includes(action)) {
      return json(
        { error: `Invalid action. Must be one of: ${validActions.join(", ")}` },
        400
      );
    }

    // ── Verify business exists ─────────────────────────────────────────
    const { data: business, error: bizError } = await supabase
      .from("businesses")
      .select("id, name, is_active, on_hold")
      .eq("id", business_id)
      .single();

    if (bizError || !business) {
      return json({ error: "Business not found" }, 404);
    }

    console.log(
      `[SUSPEND-SALON] Admin ${user.id} executing '${action}' on business ${business.id} (${business.name})`
    );

    // ── Execute action ─────────────────────────────────────────────────
    switch (action) {
      case "suspend":
        return await handleSuspend(supabase, business);

      case "reactivate":
        return await handleReactivate(supabase, business);

      case "hold":
        return await handleHold(supabase, business);

      case "unhold":
        return await handleUnhold(supabase, business);

      default:
        return json({ error: "Unknown action" }, 400);
    }
  } catch (err) {
    console.error("[SUSPEND-SALON] Error:", (err as Error).message);
    return json({ error: (err as Error).message }, 500);
  }
});

// ── Suspend ──────────────────────────────────────────────────────────────────
// Set is_active = false, find all future pending/confirmed bookings,
// notify each client. Do NOT cancel bookings.
async function handleSuspend(
  supabase: ReturnType<typeof createClient>,
  business: { id: string; name: string }
) {
  // 1. Set business inactive
  const { error: updateError } = await supabase
    .from("businesses")
    .update({ is_active: false })
    .eq("id", business.id);

  if (updateError) {
    console.error("[SUSPEND-SALON] Failed to deactivate:", updateError);
    return json(
      { error: "Failed to deactivate business: " + updateError.message },
      500
    );
  }

  // 2. Find all future pending/confirmed appointments
  const { data: appointments, error: apptError } = await supabase
    .from("appointments")
    .select("id, user_id, starts_at, service_name")
    .eq("business_id", business.id)
    .in("status", ["pending", "confirmed"])
    .gte("starts_at", new Date().toISOString());

  if (apptError) {
    console.error("[SUSPEND-SALON] Failed to query appointments:", apptError);
    // Business is already deactivated — continue but report the issue
    return json({
      success: true,
      warning: "Business deactivated but failed to query appointments for notifications",
      affected_bookings: 0,
    });
  }

  const affectedBookings = appointments?.length ?? 0;
  console.log(
    `[SUSPEND-SALON] Found ${affectedBookings} affected bookings for ${business.name}`
  );

  // 3. Insert notification for each affected client
  if (appointments && appointments.length > 0) {
    const notifications = appointments.map((appt) => {
      const apptDate = new Date(appt.starts_at);
      const formattedDate = apptDate.toLocaleDateString("es-MX", {
        weekday: "long",
        year: "numeric",
        month: "long",
        day: "numeric",
        hour: "2-digit",
        minute: "2-digit",
      });

      return {
        user_id: appt.user_id,
        title: "Salon suspendido",
        body: `El salon ${business.name} ha sido suspendido. Tu cita del ${formattedDate} ya no tiene protecciones de BeautyCita. Un reembolso completo esta disponible.`,
        channel: "in_app",
        is_read: false,
        metadata: {
          type: "salon_suspended",
          booking_id: appt.id,
          business_id: business.id,
          business_name: business.name,
          service_name: appt.service_name,
          starts_at: appt.starts_at,
        },
      };
    });

    const { error: notifError } = await supabase
      .from("notifications")
      .insert(notifications);

    if (notifError) {
      console.error(
        "[SUSPEND-SALON] Failed to insert notifications:",
        notifError
      );
      return json({
        success: true,
        warning: "Business deactivated but failed to send some notifications",
        affected_bookings: affectedBookings,
      });
    }

    console.log(
      `[SUSPEND-SALON] Sent ${notifications.length} notifications`
    );
  }

  return json({
    success: true,
    affected_bookings: affectedBookings,
  });
}

// ── Reactivate ───────────────────────────────────────────────────────────────
async function handleReactivate(
  supabase: ReturnType<typeof createClient>,
  business: { id: string; name: string }
) {
  const { error } = await supabase
    .from("businesses")
    .update({ is_active: true })
    .eq("id", business.id);

  if (error) {
    console.error("[SUSPEND-SALON] Failed to reactivate:", error);
    return json(
      { error: "Failed to reactivate business: " + error.message },
      500
    );
  }

  console.log(`[SUSPEND-SALON] Reactivated ${business.name}`);
  return json({ success: true });
}

// ── Hold ─────────────────────────────────────────────────────────────────────
// Lighter action: disappears from search, no notifications sent.
async function handleHold(
  supabase: ReturnType<typeof createClient>,
  business: { id: string; name: string }
) {
  const { error } = await supabase
    .from("businesses")
    .update({ on_hold: true })
    .eq("id", business.id);

  if (error) {
    console.error("[SUSPEND-SALON] Failed to set hold:", error);
    return json(
      { error: "Failed to put business on hold: " + error.message },
      500
    );
  }

  console.log(`[SUSPEND-SALON] Put ${business.name} on hold`);
  return json({ success: true });
}

// ── Unhold ───────────────────────────────────────────────────────────────────
async function handleUnhold(
  supabase: ReturnType<typeof createClient>,
  business: { id: string; name: string }
) {
  const { error } = await supabase
    .from("businesses")
    .update({ on_hold: false })
    .eq("id", business.id);

  if (error) {
    console.error("[SUSPEND-SALON] Failed to unhold:", error);
    return json(
      { error: "Failed to remove business hold: " + error.message },
      500
    );
  }

  console.log(`[SUSPEND-SALON] Removed hold on ${business.name}`);
  return json({ success: true });
}

// ── Helper ───────────────────────────────────────────────────────────────────
function json(body: unknown, status = 200) {
  return new Response(JSON.stringify(body), {
    status,
    headers: { ...corsHeaders, "Content-Type": "application/json" },
  });
}
