// portfolio-public edge function
// Public API endpoint that returns all portfolio data for a given salon slug.
// Used by static HTML portfolio themes to hydrate the page client-side.
// No auth required — only returns data for portfolios where portfolio_public = true.

import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

const supabaseUrl = Deno.env.get("SUPABASE_URL")!;
const serviceKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!;

function json(body: unknown, status = 200, cacheSeconds = 300) {
  return new Response(JSON.stringify(body), {
    status,
    headers: {
      "Content-Type": "application/json",
      "Access-Control-Allow-Origin": "*",
      "Access-Control-Allow-Headers":
        "authorization, content-type, x-client-info, apikey",
      "Cache-Control": status === 200
        ? `public, max-age=${cacheSeconds}, s-maxage=${cacheSeconds}`
        : "no-store",
    },
  });
}

Deno.serve(async (req: Request) => {
  if (req.method === "OPTIONS") {
    return new Response(null, {
      headers: {
        "Access-Control-Allow-Origin": "*",
        "Access-Control-Allow-Methods": "GET",
        "Access-Control-Allow-Headers":
          "authorization, content-type, x-client-info, apikey",
      },
    });
  }

  if (req.method !== "GET") {
    return json({ error: "Method not allowed" }, 405);
  }

  const url = new URL(req.url);
  const slug = url.searchParams.get("slug");

  if (!slug) {
    return json({ error: "slug parameter required" }, 400);
  }

  const supabase = createClient(supabaseUrl, serviceKey);

  try {
    // 1. Fetch the business by slug — must be public
    const { data: biz, error: bizError } = await supabase
      .from("businesses")
      .select(`
        id, name, portfolio_tagline, portfolio_bio, photo_url,
        phone, whatsapp, address, city, state,
        website, instagram_handle, facebook_url,
        hours, lat, lng, average_rating, total_reviews,
        portfolio_theme
      `)
      .eq("portfolio_slug", slug)
      .eq("portfolio_public", true)
      .eq("is_active", true)
      .maybeSingle();

    if (bizError) {
      console.error("Business lookup error:", bizError);
      return json({ error: "Internal error" }, 500);
    }

    if (!biz) {
      return json({ error: "Portfolio not found or not public" }, 404, 0);
    }

    const businessId = biz.id;

    // 2. Parallel queries for team, photos, services, reviews
    const [teamRes, photosRes, servicesRes, reviewsRes] = await Promise.all([
      // Team members
      supabase
        .from("staff")
        .select("id, first_name, last_name, avatar_url, bio, specialties, average_rating, total_reviews, is_active, sort_order")
        .eq("business_id", businessId)
        .eq("is_active", true)
        .order("sort_order"),

      // Visible portfolio photos
      supabase
        .from("portfolio_photos")
        .select("id, staff_id, before_url, after_url, photo_type, service_category, caption, product_tags, created_at")
        .eq("business_id", businessId)
        .eq("is_visible", true)
        .order("sort_order"),

      // Active services
      supabase
        .from("services")
        .select("id, name, price, duration_minutes, category, subcategory")
        .eq("business_id", businessId)
        .eq("is_active", true)
        .order("category")
        .order("name"),

      // Visible reviews (last 50, most recent first)
      supabase
        .from("reviews")
        .select("id, rating, comment, staff_id, service_type, created_at, user_id")
        .eq("business_id", businessId)
        .eq("is_visible", true)
        .order("created_at", { ascending: false })
        .limit(50),
    ]);

    if (teamRes.error) console.error("Team query error:", teamRes.error);
    if (photosRes.error) console.error("Photos query error:", photosRes.error);
    if (servicesRes.error) console.error("Services query error:", servicesRes.error);
    if (reviewsRes.error) console.error("Reviews query error:", reviewsRes.error);

    const team = teamRes.data ?? [];
    const photos = photosRes.data ?? [];
    const services = servicesRes.data ?? [];
    const rawReviews = reviewsRes.data ?? [];

    // 3. Compute per-staff stats: photo count + avg services/week
    const staffIds = team.map((s: Record<string, unknown>) => s.id as string);

    let staffAppointmentCounts: Record<string, number> = {};
    if (staffIds.length > 0) {
      // Count completed appointments in the last 4 weeks per staff member
      const fourWeeksAgo = new Date();
      fourWeeksAgo.setDate(fourWeeksAgo.getDate() - 28);

      const { data: apptCounts } = await supabase
        .rpc("count_staff_appointments", {
          p_business_id: businessId,
          p_since: fourWeeksAgo.toISOString(),
        })
        .select();

      // If the RPC doesn't exist, fall back to a direct query
      if (!apptCounts) {
        const { data: appts } = await supabase
          .from("appointments")
          .select("staff_id")
          .eq("business_id", businessId)
          .eq("status", "completed")
          .gte("starts_at", fourWeeksAgo.toISOString())
          .in("staff_id", staffIds);

        if (appts) {
          for (const a of appts) {
            const sid = a.staff_id as string;
            staffAppointmentCounts[sid] = (staffAppointmentCounts[sid] || 0) + 1;
          }
        }
      } else {
        for (const row of apptCounts as Array<{ staff_id: string; count: number }>) {
          staffAppointmentCounts[row.staff_id] = row.count;
        }
      }
    }

    // Photo count per staff
    const staffPhotoCounts: Record<string, number> = {};
    for (const p of photos) {
      const sid = p.staff_id as string | null;
      if (sid) {
        staffPhotoCounts[sid] = (staffPhotoCounts[sid] || 0) + 1;
      }
    }

    // Enrich team with stats
    const enrichedTeam = team.map((s: Record<string, unknown>) => {
      const sid = s.id as string;
      const totalAppts = staffAppointmentCounts[sid] || 0;
      return {
        id: s.id,
        first_name: s.first_name,
        last_name: s.last_name,
        avatar_url: s.avatar_url,
        bio: s.bio,
        specialties: s.specialties,
        average_rating: s.average_rating,
        total_reviews: s.total_reviews,
        avg_services_week: totalAppts > 0 ? Math.round((totalAppts / 4) * 10) / 10 : null,
        photo_count: staffPhotoCounts[sid] || 0,
      };
    });

    // 4. Fetch reviewer display names (usernames from profiles)
    const reviewerIds = [...new Set(rawReviews.map((r: Record<string, unknown>) => r.user_id as string))];
    let reviewerNames: Record<string, string> = {};

    if (reviewerIds.length > 0) {
      const { data: profiles } = await supabase
        .from("profiles")
        .select("id, username")
        .in("id", reviewerIds);

      if (profiles) {
        for (const p of profiles) {
          reviewerNames[p.id as string] = p.username as string;
        }
      }
    }

    const reviews = rawReviews.map((r: Record<string, unknown>) => ({
      id: r.id,
      rating: r.rating,
      comment: r.comment,
      client_name: reviewerNames[r.user_id as string] || "Cliente",
      staff_id: r.staff_id,
      service_type: r.service_type,
      created_at: r.created_at,
    }));

    // 5. Build response
    return json({
      salon: {
        name: biz.name,
        tagline: biz.portfolio_tagline,
        bio: biz.portfolio_bio,
        photo_url: biz.photo_url,
        phone: biz.phone,
        whatsapp: biz.whatsapp,
        address: biz.address,
        city: biz.city,
        state: biz.state,
        website: biz.website,
        instagram_handle: biz.instagram_handle,
        facebook_url: biz.facebook_url,
        hours: biz.hours,
        lat: biz.lat,
        lng: biz.lng,
        average_rating: biz.average_rating,
        total_reviews: biz.total_reviews,
      },
      theme: biz.portfolio_theme,
      team: enrichedTeam,
      photos,
      services,
      reviews,
    });
  } catch (err) {
    console.error("portfolio-public error:", err);
    return json({ error: "Internal error" }, 500);
  }
});
