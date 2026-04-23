// =============================================================================
// register-business — Register a new service provider business
// =============================================================================
// Creates a business profile for the authenticated user and upgrades them
// to the 'stylist' role. Also creates their default staff entry.
// =============================================================================

import { serve } from "https://deno.land/std@0.177.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";
import { checkRateLimit } from "../_shared/rate-limit.ts";

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
});

const SUPABASE_URL = Deno.env.get("SUPABASE_URL") ?? "";
const SUPABASE_SERVICE_ROLE_KEY = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY") ?? "";

interface RegisterBusinessRequest {
  name: string;
  phone?: string;
  whatsapp?: string;
  rfc?: string;
  address?: string;
  city?: string;
  state?: string;
  lat?: number;
  lng?: number;
  service_categories?: string[];
  owner_name?: string; // If different from profile name
  discovered_salon_id?: string; // Link to discovered_salons record
  photo_url?: string; // Business photo (e.g. from discovered salon)
}

// SAT RFC: 12 chars (persona moral) or 13 chars (persona fisica).
// 3-4 uppercase letters + 6 digits (YYMMDD) + 3 alphanumeric homoclave.
const RFC_REGEX = /^[A-ZÑ&]{3,4}\d{6}[A-Z\d]{3}$/;

let _req: Request;

serve(async (req) => {
  _req = req;
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders(req) });
  }

  try {
    const supabase = createClient(SUPABASE_URL, SUPABASE_SERVICE_ROLE_KEY);

    // Auth check
    const authHeader = req.headers.get("authorization") ?? "";
    const token = authHeader.replace("Bearer ", "");
    const { data: { user }, error: authError } = await supabase.auth.getUser(token);

    if (authError || !user) {
      return json({ error: "Unauthorized" }, 401);
    }

    if (!checkRateLimit(`reg:${user.id}`, 3, 3600_000)) {
      return json({ error: "Rate limit: max 3 registrations per hour" }, 429);
    }

    const body: RegisterBusinessRequest = await req.json();
    const { name, phone, whatsapp, rfc, address, city, state, lat, lng, service_categories, owner_name, discovered_salon_id, photo_url } = body;

    if (!name || name.trim().length < 2) {
      return json({ error: "Business name is required (minimum 2 characters)" }, 400);
    }

    const normalizedRfc = rfc?.trim().toUpperCase().replace(/\s+/g, "") ?? "";
    if (!normalizedRfc || !RFC_REGEX.test(normalizedRfc)) {
      return json({
        error: "RFC is required and must be a valid SAT RFC (12 or 13 chars).",
        code: "RFC_REQUIRED",
      }, 400);
    }

    // Check if user already has an ACTIVE business. Soft-deleted businesses
    // (is_active=false) should not block re-registration — ex-salons need the
    // onboarding path back in.
    const { data: existingBusiness } = await supabase
      .from("businesses")
      .select("id, name")
      .eq("owner_id", user.id)
      .eq("is_active", true)
      .maybeSingle();

    if (existingBusiness) {
      return json({
        error: "You already have a registered business",
        business_id: existingBusiness.id,
        business_name: existingBusiness.name,
      }, 400);
    }

    // Get user's profile
    const { data: profile } = await supabase
      .from("profiles")
      .select("full_name, avatar_url")
      .eq("id", user.id)
      .single();

    // If discovered_salon_id provided, enrich with its data
    let discoveredSalon: Record<string, unknown> | null = null;
    if (discovered_salon_id) {
      const { data: ds } = await supabase
        .from("discovered_salons")
        .select("*")
        .eq("id", discovered_salon_id)
        .single();
      if (ds) {
        discoveredSalon = ds;
        console.log(`[REGISTER-BIZ] Enriching with discovered salon: ${ds.business_name}`);
      }
    }

    // Start a transaction-like operation
    // 1. Create the business
    const bizInsert: Record<string, unknown> = {
      owner_id: user.id,
      name: name.trim(),
      phone: phone?.trim() || null,
      whatsapp: whatsapp?.trim() || phone?.trim() || null,
      rfc: normalizedRfc,
      address: address?.trim() || null,
      city: city?.trim() || "Guadalajara",
      state: state?.trim() || "Jalisco",
      lat: lat || null,
      lng: lng || null,
      service_categories: service_categories || [],
      is_active: true,
      tier: 1,
      onboarding_step: "services",
    };

    // Enrich from discovered salon if available
    if (discoveredSalon) {
      if (!bizInsert.address && discoveredSalon.location_address) bizInsert.address = discoveredSalon.location_address;
      if (bizInsert.city === "Guadalajara" && discoveredSalon.location_city) bizInsert.city = discoveredSalon.location_city;
      if (!bizInsert.lat && discoveredSalon.latitude) bizInsert.lat = discoveredSalon.latitude;
      if (!bizInsert.lng && discoveredSalon.longitude) bizInsert.lng = discoveredSalon.longitude;
      if (discoveredSalon.feature_image_url) bizInsert.photo_url = discoveredSalon.feature_image_url;
    }
    if (photo_url) bizInsert.photo_url = photo_url;

    const { data: business, error: bizError } = await supabase
      .from("businesses")
      .insert(bizInsert)
      .select()
      .single();

    if (bizError) {
      console.error("[REGISTER-BIZ] Failed to create business:", bizError);
      return json({ error: "Failed to create business: " + bizError.message }, 500);
    }

    console.log(`[REGISTER-BIZ] Created business ${business.id}: ${business.name}`);

    // 2. Create a staff entry for the owner
    const staffName = owner_name?.trim() || profile?.full_name || name.trim();
    const nameParts = staffName.split(" ");

    const { data: staff, error: staffError } = await supabase
      .from("staff")
      .insert({
        business_id: business.id,
        user_id: user.id,
        first_name: nameParts[0] || staffName,
        last_name: nameParts.slice(1).join(" ") || null,
        avatar_url: profile?.avatar_url || null,
        is_active: true,
        accept_online_booking: true,
        sort_order: 0,
        position: "owner",
      })
      .select()
      .single();

    if (staffError) {
      console.error("[REGISTER-BIZ] Failed to create staff:", staffError);
      // Rollback - delete the business
      await supabase.from("businesses").delete().eq("id", business.id);
      return json({ error: "Failed to create staff profile: " + staffError.message }, 500);
    }

    console.log(`[REGISTER-BIZ] Created staff ${staff.id}: ${staff.first_name}`);

    // 3. Update user's profile role to 'stylist' — REQUIRED for portal access
    let roleUpdated = false;
    for (let attempt = 0; attempt < 3; attempt++) {
      const { error: roleError } = await supabase
        .from("profiles")
        .update({ role: "stylist" })
        .eq("id", user.id);

      if (!roleError) {
        roleUpdated = true;
        break;
      }
      console.error(`[REGISTER-BIZ] Role update attempt ${attempt + 1} failed:`, roleError);
      if (attempt < 2) await new Promise((r) => setTimeout(r, 500));
    }
    if (!roleUpdated) {
      console.error("[REGISTER-BIZ] All role update attempts failed — aborting registration");
      // Rollback: delete business and staff
      await supabase.from("staff").delete().eq("business_id", business.id);
      await supabase.from("businesses").delete().eq("id", business.id);
      return json({ error: "Failed to update user role. Please try again." }, 500);
    }

    // 4. Create default weekly schedule
    // Use discovered salon hours if available, otherwise default Mon-Sat 9am-7pm
    let defaultStart = "09:00";
    let defaultEnd = "19:00";
    if (discoveredSalon?.working_hours) {
      // working_hours is a text field, try to extract open/close times (e.g. "9:00-20:00" or "Lun-Sáb 10:00-19:00")
      const hoursMatch = String(discoveredSalon.working_hours).match(/(\d{1,2}:\d{2})\s*[-–]\s*(\d{1,2}:\d{2})/);
      if (hoursMatch) {
        defaultStart = hoursMatch[1].padStart(5, "0");
        defaultEnd = hoursMatch[2].padStart(5, "0");
        console.log(`[REGISTER-BIZ] Using discovered salon hours: ${defaultStart}-${defaultEnd}`);
      }
    }

    const defaultSchedule = [];
    for (let day = 1; day <= 6; day++) { // 1=Monday to 6=Saturday
      defaultSchedule.push({
        staff_id: staff.id,
        day_of_week: day,
        start_time: defaultStart,
        end_time: defaultEnd,
        is_available: true,
      });
    }
    // Sunday off
    defaultSchedule.push({
      staff_id: staff.id,
      day_of_week: 0,
      start_time: defaultStart,
      end_time: defaultEnd,
      is_available: false,
    });

    const { error: scheduleError } = await supabase
      .from("staff_schedules")
      .insert(defaultSchedule);

    if (scheduleError) {
      console.error("[REGISTER-BIZ] Failed to create schedule:", scheduleError);
      // Non-critical, don't rollback
    }

    // 4b. Create default service
    const { error: serviceError } = await supabase
      .from("services")
      .insert({
        business_id: business.id,
        name: "Servicio General",
        duration_minutes: 30,
        price: 0,
        is_active: true,
      });

    if (serviceError) {
      console.error("[REGISTER-BIZ] Failed to create default service:", serviceError);
    }

    // 4c. Mark business as having schedule and services
    const { error: flagsError } = await supabase
      .from("businesses")
      .update({ has_schedule: true, has_services: true })
      .eq("id", business.id);

    if (flagsError) {
      console.error("[REGISTER-BIZ] Failed to set has_schedule/has_services:", flagsError);
    }

    // 5. Link discovered salon if provided (only if not already registered).
    // Use .select() so we can detect when the WHERE filter excluded the row
    // (i.e. a concurrent registrant beat us to it). Without this check, the
    // second registrant silently ends up with an unlinked business while
    // thinking they claimed the listing.
    let discoveredLinkConflict = false;
    if (discovered_salon_id) {
      const { data: linked, error: linkError } = await supabase
        .from("discovered_salons")
        .update({
          status: "registered",
          registered_business_id: business.id,
          registered_at: new Date().toISOString(),
        })
        .eq("id", discovered_salon_id)
        .neq("status", "registered")
        .select("id");

      if (linkError) {
        console.warn("[REGISTER-BIZ] Failed to link discovered salon:", linkError);
      } else if (!linked || linked.length === 0) {
        // Row exists but was already registered by someone else — flag it
        // so the client can show a "claimed by another business" message.
        // We do NOT roll back the business creation; the user still has a
        // valid standalone salon record, just not linked to the discovered listing.
        discoveredLinkConflict = true;
        console.warn(`[REGISTER-BIZ] Discovered salon ${discovered_salon_id} already claimed`);
      } else {
        console.log(`[REGISTER-BIZ] Linked discovered salon ${discovered_salon_id}`);
      }
    }

    return json({
      success: true,
      business: {
        id: business.id,
        name: business.name,
        onboarding_step: business.onboarding_step,
      },
      staff: {
        id: staff.id,
        name: `${staff.first_name} ${staff.last_name || ""}`.trim(),
      },
      discovered_link_conflict: discoveredLinkConflict,
      next_steps: [
        "Add your services with prices",
        "Configure deposit requirements",
        "Set up Stripe to accept payments",
      ],
    });

  } catch (err) {
    console.error("[REGISTER-BIZ] Error:", err);
    return json({ error: "An internal error occurred" }, 500);
  }
});

function json(body: unknown, status = 200) {
  return new Response(JSON.stringify(body), {
    status,
    headers: { ...corsHeaders(_req), "Content-Type": "application/json" },
  });
}
