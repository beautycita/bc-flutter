// =============================================================================
// feed-public — BeautyCita Inspiration Feed (public API)
// =============================================================================
// GET /feed-public?page=0&limit=20&category=hair
// Returns paginated feed items ranked by hybrid algorithm.
// Auth is OPTIONAL — anonymous users see feed without is_saved status.
// =============================================================================

import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers":
    "authorization, x-client-info, apikey, content-type",
};

function json(body: unknown, status = 200) {
  return new Response(JSON.stringify(body), {
    status,
    headers: {
      ...corsHeaders,
      "Content-Type": "application/json",
      "Cache-Control": "public, max-age=60",
    },
  });
}

// ---------------------------------------------------------------------------
// Types
// ---------------------------------------------------------------------------

interface FeedItem {
  id: string;
  type: "photo" | "showcase";
  business_id: string;
  business_name: string;
  business_photo_url: string | null;
  business_slug: string | null;
  staff_name: string | null;
  before_url: string | null;
  after_url: string | null;
  caption: string | null;
  service_category: string | null;
  product_tags: ProductTag[];
  save_count: number;
  is_saved: boolean;
  created_at: string;
  _score?: number;
}

interface ProductTag {
  product_id: string;
  name: string;
  brand: string | null;
  price: number;
  photo_url: string | null;
  in_stock: boolean;
}

// ---------------------------------------------------------------------------
// Ranking helpers
// ---------------------------------------------------------------------------

function freshnessBoot(createdAt: string): number {
  const ageMs = Date.now() - new Date(createdAt).getTime();
  const ageHours = ageMs / 3_600_000;

  if (ageHours < 72) return 1.5;

  const ageDays = ageHours / 24;
  if (ageDays <= 7) {
    // Linear decay from 1.5 at 3 days to 1.0 at 7 days
    return 1.5 - 0.5 * ((ageDays - 3) / 4);
  }

  return 1.0;
}

function qualityMultiplier(hasBeforeAfter: boolean, hasProductTags: boolean): number {
  if (hasBeforeAfter) return 1.2;
  if (hasProductTags) return 1.1;
  return 1.0;
}

function haversineKm(lat1: number, lng1: number, lat2: number, lng2: number): number {
  const R = 6371; // Earth radius in km
  const dLat = (lat2 - lat1) * Math.PI / 180;
  const dLng = (lng2 - lng1) * Math.PI / 180;
  const a = Math.sin(dLat / 2) ** 2 +
    Math.cos(lat1 * Math.PI / 180) * Math.cos(lat2 * Math.PI / 180) *
    Math.sin(dLng / 2) ** 2;
  return R * 2 * Math.atan2(Math.sqrt(a), Math.sqrt(1 - a));
}

function localBoost(distKm: number | null): number {
  if (distKm === null) return 1.0;    // no location — neutral
  if (distKm <= 5) return 1.4;         // within 5km — strong boost
  if (distKm <= 15) return 1.2;        // within 15km — moderate boost
  if (distKm <= 50) return 1.1;        // within 50km — slight boost
  return 1.0;                           // global — neutral
}

function scoreItem(
  item: FeedItem,
  saveCount: number,
  viewCount: number,
  distKm: number | null,
): number {
  const freshness = freshnessBoot(item.created_at);
  const quality = qualityMultiplier(
    item.before_url !== null && item.after_url !== null && item.type === "photo",
    item.product_tags.length > 0,
  );
  const proximity = localBoost(distKm);
  return freshness * (1 + saveCount * 0.1 + viewCount * 0.01) * quality * proximity;
}

// ---------------------------------------------------------------------------
// Main handler
// ---------------------------------------------------------------------------

Deno.serve(async (req: Request) => {
  if (req.method === "OPTIONS") {
    return new Response(null, {
      headers: {
        ...corsHeaders,
        "Access-Control-Allow-Methods": "GET",
      },
    });
  }

  if (req.method !== "GET") {
    return json({ error: "Method not allowed" }, 405);
  }

  try {
    const supabase = createClient(
      Deno.env.get("SUPABASE_URL") ?? "",
      Deno.env.get("SUPABASE_SERVICE_ROLE_KEY") ?? "",
    );

    // Feature toggle check
    const { data: toggleData } = await supabase
      .from("app_config")
      .select("value")
      .eq("key", "enable_feed")
      .single();
    if (toggleData?.value !== "true") {
      return json({ error: "This feature is currently disabled" }, 403);
    }

    // --- Parse query params ---
    const url = new URL(req.url);
    const page = Math.max(0, parseInt(url.searchParams.get("page") ?? "0", 10) || 0);
    const limit = Math.min(50, Math.max(1, parseInt(url.searchParams.get("limit") ?? "20", 10) || 20));
    const category = url.searchParams.get("category") ?? null;
    const userLat = parseFloat(url.searchParams.get("lat") ?? "") || null;
    const userLng = parseFloat(url.searchParams.get("lng") ?? "") || null;

    // --- Optional auth: resolve user for is_saved ---
    let userId: string | null = null;
    const authHeader = req.headers.get("authorization") ?? "";
    const token = authHeader.replace("Bearer ", "");
    if (token) {
      const { data: { user }, error: authError } = await supabase.auth.getUser(token);
      if (!authError && user) {
        userId = user.id;
      }
    }

    // --- Parallel queries: portfolio_photos + product_showcases ---
    let photosQuery = supabase
      .from("portfolio_photos")
      .select("id, business_id, staff_id, before_url, after_url, caption, service_category, product_tags, created_at, businesses!inner(id, name, photo_url, slug, lat, lng), staff(id, first_name)")
      .eq("is_visible", true);

    if (category) {
      photosQuery = photosQuery.eq("service_category", category);
    }

    const showcasesQuery = supabase
      .from("product_showcases")
      .select("id, business_id, product_id, caption, created_at, businesses!inner(id, name, photo_url, slug, lat, lng), products!inner(id, name, brand, price, photo_url, category, in_stock)");

    const [photosResult, showcasesResult] = await Promise.all([
      photosQuery,
      showcasesQuery,
    ]);

    if (photosResult.error) {
      console.error("portfolio_photos query error:", photosResult.error.message);
    }
    if (showcasesResult.error) {
      console.error("product_showcases query error:", showcasesResult.error.message);
    }

    // deno-lint-ignore no-explicit-any
    const photos: any[] = photosResult.data ?? [];
    // deno-lint-ignore no-explicit-any
    const showcases: any[] = showcasesResult.data ?? [];

    // --- Collect all content IDs for engagement aggregation ---
    const photoIds = photos.map((p) => p.id);
    const showcaseIds = showcases.map((s) => s.id);
    const allIds = [...photoIds, ...showcaseIds];

    // --- Engagement counts (saves + views) ---
    let saveCounts = new Map<string, number>();
    let viewCounts = new Map<string, number>();

    if (allIds.length > 0) {
      const [savesResult, viewsResult] = await Promise.all([
        supabase
          .from("feed_engagement")
          .select("content_id")
          .in("content_id", allIds)
          .eq("action", "save"),
        supabase
          .from("feed_engagement")
          .select("content_id")
          .in("content_id", allIds)
          .eq("action", "view"),
      ]);

      // Count saves per content_id
      for (const row of savesResult.data ?? []) {
        saveCounts.set(row.content_id, (saveCounts.get(row.content_id) ?? 0) + 1);
      }
      // Count views per content_id
      for (const row of viewsResult.data ?? []) {
        viewCounts.set(row.content_id, (viewCounts.get(row.content_id) ?? 0) + 1);
      }
    }

    // --- User's saved items (if authenticated) ---
    let userSaves = new Set<string>();
    if (userId && allIds.length > 0) {
      const { data: savedData } = await supabase
        .from("feed_saves")
        .select("content_id")
        .eq("user_id", userId)
        .in("content_id", allIds);

      for (const row of savedData ?? []) {
        userSaves.add(row.content_id);
      }
    }

    // --- Resolve product tags for photos (jsonb contains product_ids) ---
    // Collect all product IDs referenced in photo product_tags
    const productIdsFromPhotos = new Set<string>();
    for (const p of photos) {
      const tags = p.product_tags;
      if (Array.isArray(tags)) {
        for (const tag of tags) {
          if (typeof tag === "string") {
            productIdsFromPhotos.add(tag);
          } else if (tag?.product_id) {
            productIdsFromPhotos.add(tag.product_id);
          }
        }
      }
    }

    // Also add showcase product IDs
    for (const s of showcases) {
      if (s.product_id) productIdsFromPhotos.add(s.product_id);
    }

    // Fetch all referenced products in one query
    // deno-lint-ignore no-explicit-any
    let productsMap = new Map<string, any>();
    const productIdsList = [...productIdsFromPhotos];
    if (productIdsList.length > 0) {
      const { data: productsData } = await supabase
        .from("products")
        .select("id, name, brand, price, photo_url, in_stock")
        .in("id", productIdsList);

      for (const prod of productsData ?? []) {
        productsMap.set(prod.id, prod);
      }
    }

    // --- Build unified feed items ---
    const feedItems: FeedItem[] = [];

    // Portfolio photos
    for (const p of photos) {
      // deno-lint-ignore no-explicit-any
      const biz = p.businesses as any;
      // deno-lint-ignore no-explicit-any
      const staffRec = p.staff as any;

      // Resolve product tags
      const resolvedTags: ProductTag[] = [];
      if (Array.isArray(p.product_tags)) {
        for (const tag of p.product_tags) {
          const pid = typeof tag === "string" ? tag : tag?.product_id;
          if (pid) {
            const prod = productsMap.get(pid);
            if (prod) {
              resolvedTags.push({
                product_id: prod.id,
                name: prod.name,
                brand: prod.brand,
                price: prod.price,
                photo_url: prod.photo_url,
                in_stock: prod.in_stock,
              });
            }
          }
        }
      }

      feedItems.push({
        id: p.id,
        type: "photo",
        business_id: p.business_id,
        business_name: biz?.name ?? "",
        business_photo_url: biz?.photo_url ?? null,
        business_slug: biz?.slug ?? null,
        staff_name: staffRec?.first_name ?? null,
        before_url: p.before_url ?? null,
        after_url: p.after_url ?? null,
        caption: p.caption ?? null,
        service_category: p.service_category ?? null,
        product_tags: resolvedTags,
        save_count: saveCounts.get(p.id) ?? 0,
        is_saved: userSaves.has(p.id),
        created_at: p.created_at,
      });
    }

    // Product showcases
    for (const s of showcases) {
      // deno-lint-ignore no-explicit-any
      const biz = s.businesses as any;
      // deno-lint-ignore no-explicit-any
      const prod = s.products as any;

      const showcaseTag: ProductTag = {
        product_id: prod?.id ?? s.product_id,
        name: prod?.name ?? "",
        brand: prod?.brand ?? null,
        price: prod?.price ?? 0,
        photo_url: prod?.photo_url ?? null,
        in_stock: prod?.in_stock ?? false,
      };

      feedItems.push({
        id: s.id,
        type: "showcase",
        business_id: s.business_id,
        business_name: biz?.name ?? "",
        business_photo_url: biz?.photo_url ?? null,
        business_slug: biz?.slug ?? null,
        staff_name: null,
        before_url: null,
        after_url: prod?.photo_url ?? null,
        caption: s.caption ?? null,
        service_category: null,
        product_tags: [showcaseTag],
        save_count: saveCounts.get(s.id) ?? 0,
        is_saved: userSaves.has(s.id),
        created_at: s.created_at,
      });
    }

    // --- Build business location map for local boost ---
    const bizLocMap = new Map<string, { lat: number; lng: number }>();
    for (const p of photos) {
      const biz = p.businesses as any;
      if (biz?.lat && biz?.lng) bizLocMap.set(p.business_id, { lat: biz.lat, lng: biz.lng });
    }
    for (const s of showcases) {
      const biz = s.businesses as any;
      if (biz?.lat && biz?.lng) bizLocMap.set(s.business_id, { lat: biz.lat, lng: biz.lng });
    }

    // --- Score and sort (global-first with local boost) ---
    const scored = feedItems.map((item) => {
      const sc = saveCounts.get(item.id) ?? 0;
      const vc = viewCounts.get(item.id) ?? 0;
      let distKm: number | null = null;
      if (userLat && userLng) {
        const loc = bizLocMap.get(item.business_id);
        if (loc) distKm = haversineKm(userLat, userLng, loc.lat, loc.lng);
      }
      item._score = scoreItem(item, sc, vc, distKm);
      return item;
    });

    scored.sort((a, b) => (b._score ?? 0) - (a._score ?? 0));

    // --- Paginate ---
    const start = page * limit;
    const paged = scored.slice(start, start + limit);

    // Strip internal _score from response
    const response = paged.map(({ _score, ...rest }) => rest);

    return json({
      page,
      limit,
      total: scored.length,
      items: response,
    });
  } catch (err) {
    console.error("feed-public error:", err);
    return json({ error: "An internal error occurred" }, 500);
  }
});
