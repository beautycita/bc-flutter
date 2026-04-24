// =============================================================================
// tiktok-feed-ingest — Admin-only endpoint that pulls TikTok oEmbed metadata
// for a URL and upserts into public.tiktok_feed_items.
// =============================================================================
// Why an edge fn: TikTok's official oEmbed endpoint is public but requires a
// server-side fetch (CORS restrictions from the web client). Scraping without
// an account isn't reliable in 2026 (ms_token / bot-detection). This keeps
// the pipeline honest: admins curate URLs, server resolves metadata, feed
// renders via official embed iframes.
//
// Request (admin or service_role):
//   POST /functions/v1/tiktok-feed-ingest
//   { "url": "https://www.tiktok.com/@user/video/7385…", "category": "maquillaje",
//     "curator_note": "optional", "creator_region": "optional ISO-2 override" }
//
// Response 200: { upserted: true, video_id, creator_handle, caption, thumb_url }
// =============================================================================

import { createClient } from "https://esm.sh/@supabase/supabase-js@2";
import { corsHeaders, handleCorsPreflightIfOptions } from "../_shared/cors.ts";

const SUPABASE_URL = Deno.env.get("SUPABASE_URL") ?? "";
const SUPABASE_SERVICE_ROLE_KEY = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY") ?? "";

type OEmbed = {
  title?: string;
  author_url?: string;
  author_name?: string;
  author_unique_id?: string;
  embed_product_id?: string;
  thumbnail_url?: string;
  thumbnail_width?: number;
  thumbnail_height?: number;
};

// Accepts full tiktok URLs and also raw numeric IDs or t.tiktok.com shortlinks.
// Returns a URL ready for oEmbed: the canonical /@user/video/<id> form.
async function normalizeTikTokUrl(raw: string): Promise<string> {
  const s = raw.trim();

  // Numeric-only → bare id isn't useful without a user handle, reject.
  if (/^\d{6,25}$/.test(s)) {
    throw new Error("numeric id alone isn't sufficient — paste the full TikTok URL");
  }

  // Already canonical?
  if (/tiktok\.com\/@[\w.-]+\/video\/\d+/.test(s)) {
    return s.replace(/\?.*$/, "").replace(/#.*$/, "");
  }

  // Short/mobile link (vm.tiktok.com/, www.tiktok.com/t/) — follow one redirect.
  if (/^https?:\/\/(vm|m|www)\.tiktok\.com\/(t\/|v\/)?[\w-]+/.test(s)) {
    const res = await fetch(s, {
      method: "HEAD",
      redirect: "follow",
      headers: { "User-Agent": "Mozilla/5.0 (Macintosh; Intel Mac OS X 14_0) AppleWebKit/537.36" },
    });
    const finalUrl = res.url;
    if (/tiktok\.com\/@[\w.-]+\/video\/\d+/.test(finalUrl)) {
      return finalUrl.replace(/\?.*$/, "").replace(/#.*$/, "");
    }
    throw new Error(`redirect landed at ${finalUrl}, not a TikTok video`);
  }

  throw new Error("unrecognized TikTok URL format");
}

async function fetchOEmbed(url: string): Promise<OEmbed> {
  const oembedUrl = `https://www.tiktok.com/oembed?url=${encodeURIComponent(url)}`;
  const ac = new AbortController();
  const t = setTimeout(() => ac.abort(), 10_000);
  try {
    const res = await fetch(oembedUrl, {
      headers: { Accept: "application/json" },
      signal: ac.signal,
    });
    if (!res.ok) {
      throw new Error(`oembed ${res.status}: ${(await res.text()).slice(0, 200)}`);
    }
    return (await res.json()) as OEmbed;
  } finally {
    clearTimeout(t);
  }
}

function json(body: unknown, status = 200, req?: Request) {
  return new Response(JSON.stringify(body), {
    status,
    headers: {
      ...(req ? corsHeaders(req) : {}),
      "Content-Type": "application/json",
    },
  });
}

const VALID_CATEGORIES = new Set([
  "cabello", "unas", "pestanas", "cejas", "maquillaje",
  "facial", "corporal", "novias", "hombres",
]);

Deno.serve(async (req) => {
  const preflight = handleCorsPreflightIfOptions(req);
  if (preflight) return preflight;

  if (req.method !== "POST") {
    return json({ error: "POST only" }, 405, req);
  }

  // Auth: admin/superadmin or service_role.
  const supabase = createClient(SUPABASE_URL, SUPABASE_SERVICE_ROLE_KEY);
  const authHeader = req.headers.get("authorization") ?? "";
  const token = authHeader.replace(/^Bearer\s+/i, "");
  if (!token) return json({ error: "auth required" }, 401, req);

  const isServiceRole = token === SUPABASE_SERVICE_ROLE_KEY;
  if (!isServiceRole) {
    const { data: { user }, error: authErr } = await supabase.auth.getUser(token);
    if (authErr || !user) return json({ error: "invalid token" }, 401, req);
    const { data: profile } = await supabase
      .from("profiles")
      .select("role")
      .eq("id", user.id)
      .maybeSingle();
    const role = profile?.role;
    if (role !== "admin" && role !== "superadmin") {
      return json({ error: "admin required" }, 403, req);
    }
  }

  let body: Record<string, unknown>;
  try { body = await req.json(); }
  catch { return json({ error: "Invalid JSON" }, 400, req); }

  const urlInput = typeof body.url === "string" ? body.url : "";
  const category = typeof body.category === "string" ? body.category : "";
  const curatorNote = typeof body.curator_note === "string" ? body.curator_note : null;
  const regionOverride = typeof body.creator_region === "string" ? body.creator_region.toUpperCase() : null;

  if (!urlInput || !category) {
    return json({ error: "url and category required" }, 400, req);
  }
  if (!VALID_CATEGORIES.has(category)) {
    return json({
      error: "invalid category",
      valid_categories: Array.from(VALID_CATEGORIES),
    }, 400, req);
  }

  let canonicalUrl: string;
  try {
    canonicalUrl = await normalizeTikTokUrl(urlInput);
  } catch (e) {
    return json({ error: `url normalize failed: ${(e as Error).message}` }, 400, req);
  }

  let oe: OEmbed;
  try {
    oe = await fetchOEmbed(canonicalUrl);
  } catch (e) {
    return json({ error: `oembed failed: ${(e as Error).message}` }, 502, req);
  }

  // oEmbed embed_product_id is the TikTok video ID — authoritative source.
  const videoId = oe.embed_product_id
    ?? canonicalUrl.match(/\/video\/(\d+)/)?.[1];
  if (!videoId) {
    return json({ error: "could not determine video_id from oembed" }, 502, req);
  }

  const creatorHandle = oe.author_unique_id
    ? `@${oe.author_unique_id}`
    : oe.author_url?.match(/@([\w.-]+)/)?.[1]
      ? `@${oe.author_url!.match(/@([\w.-]+)/)![1]}`
      : null;

  // Hashtags from the oEmbed title (TikTok titles include #tags inline).
  const hashtags = Array.from((oe.title ?? "").matchAll(/#([\w]+)/g)).map((m) => m[1].toLowerCase());

  const { data, error } = await supabase
    .from("tiktok_feed_items")
    .upsert({
      video_id: videoId,
      category,
      creator_handle: creatorHandle,
      creator_region: regionOverride,         // oEmbed doesn't expose region; admin can pass it
      caption: oe.title ?? null,
      thumb_url: oe.thumbnail_url ?? null,
      hashtags,
      curator_note: curatorNote,
      is_visible: true,
      last_verified_at: new Date().toISOString(),
    }, { onConflict: "video_id" })
    .select()
    .single();

  if (error) {
    return json({ error: `upsert failed: ${error.message}` }, 500, req);
  }

  return json({
    upserted: true,
    video_id: videoId,
    creator_handle: creatorHandle,
    caption: oe.title,
    thumb_url: oe.thumbnail_url,
    hashtags,
    row: data,
  }, 200, req);
});
