// =============================================================================
// register-business — Register a new service provider business
// =============================================================================
// Creates a business profile for the authenticated user and upgrades them
// to the 'stylist' role. Also creates their default staff entry.
// =============================================================================

import { serve } from "https://deno.land/std@0.177.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
};

const SUPABASE_URL = Deno.env.get("SUPABASE_URL") ?? "";
const SUPABASE_SERVICE_ROLE_KEY = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY") ?? "";

interface RegisterBusinessRequest {
  name: string;
  phone?: string;
  whatsapp?: string;
  address?: string;
  city?: string;
  state?: string;
  lat?: number;
  lng?: number;
  service_categories?: string[];
  owner_name?: string; // If different from profile name
}

serve(async (req) => {
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders });
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

    const body: RegisterBusinessRequest = await req.json();
    const { name, phone, whatsapp, address, city, state, lat, lng, service_categories, owner_name } = body;

    if (!name || name.trim().length < 2) {
      return json({ error: "Business name is required (minimum 2 characters)" }, 400);
    }

    // Check if user already has a business
    const { data: existingBusiness } = await supabase
      .from("businesses")
      .select("id, name")
      .eq("owner_id", user.id)
      .single();

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

    // Start a transaction-like operation
    // 1. Create the business
    const { data: business, error: bizError } = await supabase
      .from("businesses")
      .insert({
        owner_id: user.id,
        name: name.trim(),
        phone: phone?.trim() || null,
        whatsapp: whatsapp?.trim() || phone?.trim() || null,
        address: address?.trim() || null,
        city: city?.trim() || "Guadalajara",
        state: state?.trim() || "Jalisco",
        lat: lat || null,
        lng: lng || null,
        service_categories: service_categories || [],
        is_active: true,
        tier: 1, // Start at tier 1
        onboarding_step: "services", // Next step after profile is services
      })
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

    // 3. Update user's profile role to 'stylist'
    const { error: roleError } = await supabase
      .from("profiles")
      .update({ role: "stylist" })
      .eq("id", user.id);

    if (roleError) {
      console.error("[REGISTER-BIZ] Failed to update role:", roleError);
      // Don't rollback - the business is created, role update is secondary
    }

    // 4. Create default weekly schedule (Mon-Sat 9am-7pm)
    const defaultSchedule = [];
    for (let day = 1; day <= 6; day++) { // 1=Monday to 6=Saturday
      defaultSchedule.push({
        staff_id: staff.id,
        day_of_week: day,
        start_time: "09:00",
        end_time: "19:00",
        is_available: true,
      });
    }
    // Sunday off
    defaultSchedule.push({
      staff_id: staff.id,
      day_of_week: 0,
      start_time: "09:00",
      end_time: "19:00",
      is_available: false,
    });

    const { error: scheduleError } = await supabase
      .from("staff_schedules")
      .insert(defaultSchedule);

    if (scheduleError) {
      console.error("[REGISTER-BIZ] Failed to create schedule:", scheduleError);
      // Non-critical, don't rollback
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
      next_steps: [
        "Add your services with prices",
        "Configure deposit requirements",
        "Set up Stripe to accept payments",
      ],
    });

  } catch (err) {
    console.error("[REGISTER-BIZ] Error:", (err as Error).message);
    return json({ error: (err as Error).message }, 500);
  }
});

function json(body: unknown, status = 200) {
  return new Response(JSON.stringify(body), {
    status,
    headers: { ...corsHeaders, "Content-Type": "application/json" },
  });
}
