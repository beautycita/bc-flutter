// =============================================================================
// qr-walkin-assign — Salon owner assigns stylist + time to a pending walk-in
// =============================================================================
// Design: /home/bc/futureBeauty/docs/plans/2026-04-23-salon-qr-90day.md §5.2
// Flow:
//   1. Authenticate as salon owner
//   2. Validate pending row (owned by their business, not expired, not confirmed)
//   3. Resolve or create BC profile for the registrant's phone (phantom auth)
//   4. Create appointments row with payment_method='external_free'
//   5. Update pending -> confirmed + appointment_id
//   6. Notify client (WA queue) + stylist (push)
//   7. NO tax_withholdings / commission_records / salon_debts
// =============================================================================

import { createClient } from "https://esm.sh/@supabase/supabase-js@2";
import { corsHeaders, handleCorsPreflightIfOptions } from "../_shared/cors.ts";
import { requireFeature } from "../_shared/check-toggle.ts";
import { checkRateLimit } from "../_shared/rate-limit.ts";

const SUPABASE_URL = Deno.env.get("SUPABASE_URL") ?? "";
const SUPABASE_SERVICE_ROLE_KEY = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY") ?? "";
const SUPABASE_ANON_KEY = Deno.env.get("SUPABASE_ANON_KEY") ?? "";

let _req: Request;
function json(body: unknown, status = 200): Response {
  return new Response(JSON.stringify(body), {
    status,
    headers: { ...corsHeaders(_req), "Content-Type": "application/json" },
  });
}

Deno.serve(async (req: Request) => {
  _req = req;
  const preflight = handleCorsPreflightIfOptions(req);
  if (preflight) return preflight;
  if (req.method !== "POST") return json({ error: "Method not allowed" }, 405);

  const blocked = await requireFeature("enable_qr_free_tier");
  if (blocked) return blocked;

  // Auth
  const authHeader = req.headers.get("authorization") ?? "";
  const userClient = createClient(SUPABASE_URL, SUPABASE_ANON_KEY, {
    global: { headers: { Authorization: authHeader } },
  });
  const { data: { user }, error: authErr } = await userClient.auth.getUser();
  if (authErr || !user) return json({ error: "Unauthorized" }, 401);

  if (!checkRateLimit(`qr-assign:${user.id}`, 20, 60_000)) {
    return json({ error: "Too many requests" }, 429);
  }

  let body: Record<string, unknown>;
  try {
    body = await req.json();
  } catch {
    return json({ error: "Invalid JSON" }, 400);
  }

  const { pending_id, staff_id, scheduled_at } = body as Record<string, string | undefined>;
  if (typeof pending_id !== "string" || !pending_id ||
      typeof staff_id !== "string" || !staff_id ||
      typeof scheduled_at !== "string" || !scheduled_at) {
    return json({ error: "Missing pending_id / staff_id / scheduled_at" }, 400);
  }

  const scheduledDate = new Date(scheduled_at);
  if (Number.isNaN(scheduledDate.getTime())) {
    return json({ error: "scheduled_at must be ISO timestamp" }, 400);
  }

  const supabase = createClient(SUPABASE_URL, SUPABASE_SERVICE_ROLE_KEY);

  // Fetch pending
  const { data: pending } = await supabase
    .from("walkin_pending_appointments")
    .select(
      "id, business_id, registration_id, service_id, service_name, status, expires_at, appointment_id",
    )
    .eq("id", pending_id)
    .maybeSingle();

  if (!pending) return json({ error: "Pending not found" }, 404);
  if (pending.status !== "pending_assignment") {
    return json({ error: `Pending is ${pending.status}, not pending_assignment` }, 409);
  }
  if (new Date(pending.expires_at).getTime() < Date.now()) {
    return json({ error: "Pending expired" }, 409);
  }

  // Verify caller owns this business
  const { data: biz } = await supabase
    .from("businesses")
    .select("id, owner_id, name")
    .eq("id", pending.business_id)
    .maybeSingle();
  if (!biz || biz.owner_id !== user.id) {
    return json({ error: "Forbidden" }, 403);
  }

  // Verify staff belongs to this business
  const { data: staff } = await supabase
    .from("staff")
    .select("id, first_name, business_id")
    .eq("id", staff_id)
    .eq("business_id", biz.id)
    .eq("is_active", true)
    .maybeSingle();
  if (!staff) return json({ error: "Staff not found / inactive" }, 400);

  // Fetch registration
  const { data: reg } = await supabase
    .from("salon_walkin_registrations")
    .select("id, phone, full_name")
    .eq("id", pending.registration_id)
    .maybeSingle();
  if (!reg) return json({ error: "Registration missing" }, 500);

  // Service price snapshot
  const { data: svc } = await supabase
    .from("services")
    .select("price, duration_minutes")
    .eq("id", pending.service_id)
    .maybeSingle();
  const price = (svc?.price as number | undefined) ?? 0;
  const durationMin = (svc?.duration_minutes as number | undefined) ?? 60;
  const endsAt = new Date(scheduledDate.getTime() + durationMin * 60_000).toISOString();

  // Resolve or create profile for this phone (phantom auth pattern — see §5.2b)
  let profileId: string | null = null;
  const { data: existingProfile } = await supabase
    .from("profiles")
    .select("id")
    .eq("phone", reg.phone)
    .maybeSingle();

  if (existingProfile) {
    profileId = existingProfile.id as string;
  } else {
    // Create phone-only auth user + profile
    const { data: authRes, error: authCreateErr } = await supabase.auth.admin.createUser({
      phone: reg.phone,
      phone_confirm: true,
    });
    if (authCreateErr || !authRes?.user) {
      console.error("[qr-walkin-assign] auth.admin.createUser failed:", authCreateErr);
      return json({ error: "Could not provision client account" }, 500);
    }
    profileId = authRes.user.id;

    const { error: profInsErr } = await supabase.from("profiles").insert({
      id: profileId,
      phone: reg.phone,
      full_name: reg.full_name,
      role: "customer",
      registration_source: "internal_qr",
    });
    if (profInsErr) {
      console.error("[qr-walkin-assign] profile insert failed:", profInsErr);
      // Rollback auth user
      await supabase.auth.admin.deleteUser(profileId);
      return json({ error: "Could not create profile" }, 500);
    }
  }

  // Create appointment row — external_free, no financial side effects
  const { data: appt, error: apptErr } = await supabase
    .from("appointments")
    .insert({
      user_id: profileId,
      business_id: biz.id,
      service_id: pending.service_id,
      staff_id: staff.id,
      starts_at: scheduledDate.toISOString(),
      ends_at: endsAt,
      status: "confirmed",
      payment_status: "external_collected",
      payment_method: "external_free",
      price,
      service_name: pending.service_name,
      booking_source: "qr_walkin",
    })
    .select("id")
    .single();

  if (apptErr || !appt) {
    console.error("[qr-walkin-assign] appointment insert failed:", apptErr);
    return json({ error: "Could not create appointment" }, 500);
  }

  // Update pending row — guard on status for concurrency
  const { data: updated } = await supabase
    .from("walkin_pending_appointments")
    .update({
      status: "confirmed",
      assigned_staff_id: staff.id,
      scheduled_at: scheduledDate.toISOString(),
      appointment_id: appt.id,
      confirmed_at: new Date().toISOString(),
    })
    .eq("id", pending.id)
    .eq("status", "pending_assignment")
    .select("id");

  if (!updated || updated.length === 0) {
    // Race: another caller finalized it first. Rollback our appointment.
    await supabase.from("appointments").delete().eq("id", appt.id);
    return json({ error: "Pending was finalized by another call; retry." }, 409);
  }

  // Explicit no-op comment: NOT inserting into tax_withholdings / commission_records / salon_debts.
  // external_free is off-platform — see design doc §3 and migration 20260423000000.

  // Notify client via WA queue (phantom profile has no push token)
  const fmtTime = scheduledDate.toLocaleString("es-MX", {
    dateStyle: "medium",
    timeStyle: "short",
    timeZone: "America/Mexico_City",
  });
  await supabase.from("wa_notification_queue").insert({
    phone: reg.phone,
    template: "walkin_confirmed",
    variables: {
      business_name: biz.name,
      service_name: pending.service_name,
      staff_name: staff.first_name,
      scheduled_at: fmtTime,
    },
  });

  // Notify stylist via push (async — don't block response)
  (async () => {
    try {
      // Stylist's user_id via staff.user_id (set via phone auto-link trigger shipped in build 60096)
      const { data: staffRow } = await supabase
        .from("staff")
        .select("user_id")
        .eq("id", staff.id)
        .maybeSingle();
      const stylistUserId = staffRow?.user_id as string | null | undefined;
      if (stylistUserId) {
        await fetch(`${SUPABASE_URL}/functions/v1/send-push-notification`, {
          method: "POST",
          headers: {
            Authorization: `Bearer ${SUPABASE_SERVICE_ROLE_KEY}`,
            "Content-Type": "application/json",
          },
          body: JSON.stringify({
            user_id: stylistUserId,
            notification_type: "new_booking",
            custom_title: "Walk-in asignado",
            custom_body: `${reg.full_name} — ${pending.service_name} a las ${fmtTime}. Al completar, toma la foto antes/despues.`,
            data: { type: "walkin_assigned", appointment_id: appt.id },
          }),
        });
      }
    } catch (e) {
      console.error(`[qr-walkin-assign] Stylist push failed: ${(e as Error).message}`);
    }
  })();

  return json({
    success: true,
    appointment_id: appt.id,
    pending_id: pending.id,
    client_profile_id: profileId,
  });
});
