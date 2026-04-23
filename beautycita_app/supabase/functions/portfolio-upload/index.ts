// =============================================================================
// portfolio-upload — PIN-protected photo upload for staff stylists
// =============================================================================
// Accessed via QR code: beautycita.com/api/functions/v1/portfolio-upload
// Staff scans QR → enters 4-digit PIN → sees pending before/afters
// → can add before, after, or start new pair
// No app login required — PIN auth only.
// =============================================================================

import { serve } from "https://deno.land/std@0.177.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

const SUPABASE_URL = Deno.env.get("SUPABASE_URL") ?? "";
const SUPABASE_SERVICE_ROLE_KEY = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY") ?? "";

const ALLOWED_ORIGINS = [
  "https://beautycita.com",
  "https://www.beautycita.com",
  "https://debug.beautycita.com",
];

function corsOrigin(req: Request): string {
  const o = req.headers.get("origin") ?? "";
  return ALLOWED_ORIGINS.includes(o) ? o : ALLOWED_ORIGINS[0];
}

// ── PIN brute-force tracking (in-memory, resets on cold start) ──
const pinAttempts = new Map<string, { failures: number; lockedUntil: number }>();
const MAX_PIN_FAILURES = 5;
const LOCKOUT_MS = 15 * 60 * 1000; // 15 minutes

// ── Valid media signatures ──
const JPEG_MAGIC = [0xFF, 0xD8, 0xFF];
const PNG_MAGIC = [0x89, 0x50, 0x4E, 0x47];
// MP4 / MOV / QuickTime containers all start with 4-byte size then "ftyp"
const MP4_FTYP_MAGIC = [0x66, 0x74, 0x79, 0x70]; // "ftyp" at offset 4
// WebM / Matroska
const WEBM_MAGIC = [0x1A, 0x45, 0xDF, 0xA3];
const MAX_IMAGE_BYTES = 10 * 1024 * 1024;   // 10 MB
const MAX_VIDEO_BYTES = 500 * 1024 * 1024;  // 500 MB (we compress bucket-side later)

serve(async (req) => {
  const url = new URL(req.url);
  const supabase = createClient(SUPABASE_URL, SUPABASE_SERVICE_ROLE_KEY);

  // CORS
  const corsHeaders = {
    "Access-Control-Allow-Origin": corsOrigin(req),
    "Access-Control-Allow-Headers": "content-type",
    "Access-Control-Allow-Methods": "GET, POST, OPTIONS",
  };

  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders });
  }

  try {
    const body = req.method === "POST" ? await req.json() : {};
    const action = body.action ?? url.searchParams.get("action") ?? "verify";
    const token = body.token ?? url.searchParams.get("token") ?? "";
    const pin = body.pin ?? "";

    // ── Verify PIN ──
    if (action === "verify") {
      if (!token || !pin) {
        return json({ error: "Token and PIN required" }, 400, corsHeaders);
      }

      // Rate-limit: check lockout
      const attempt = pinAttempts.get(token);
      if (attempt && attempt.lockedUntil > Date.now()) {
        console.warn(`[PORTFOLIO-UPLOAD] Token locked out: ${token}`);
        await new Promise(r => setTimeout(r, 1000));
        return json({ error: "Demasiados intentos. Espera 15 minutos." }, 429, corsHeaders);
      }

      // 1-second delay on every PIN check (prevents rapid enumeration)
      await new Promise(r => setTimeout(r, 1000));

      const { data: staff } = await supabase
        .from("staff")
        .select("id, first_name, last_name, business_id, upload_pin, businesses(name)")
        .eq("upload_qr_token", token)
        .eq("is_active", true)
        .maybeSingle();

      if (!staff || staff.upload_pin !== pin) {
        // Track failed attempt
        const current = pinAttempts.get(token) ?? { failures: 0, lockedUntil: 0 };
        current.failures += 1;
        if (current.failures >= MAX_PIN_FAILURES) {
          current.lockedUntil = Date.now() + LOCKOUT_MS;
          console.warn(`[PORTFOLIO-UPLOAD] Token locked after ${MAX_PIN_FAILURES} failures: ${token}`);
        }
        pinAttempts.set(token, current);
        console.warn(`[PORTFOLIO-UPLOAD] Failed PIN attempt ${current.failures} for token: ${token}`);
        return json({ error: "PIN incorrecto" }, 401, corsHeaders);
      }

      // Successful verification — clear any tracked failures
      pinAttempts.delete(token);

      // Return staff info + pending photos.
      // Exclude rows hidden by the stylist — they stay in the salon portfolio
      // (salon owns the work), but are not shown in the stylist's gallery.
      const { data: pending } = await supabase
        .from("portfolio_photos")
        .select("id, before_url, after_url, service_name, client_name, is_complete, publish_to_feed, overlays, created_at")
        .eq("staff_id", staff.id)
        .eq("hidden_from_staff_view", false)
        .order("created_at", { ascending: false })
        .limit(20);

      return json({
        staff_id: staff.id,
        staff_name: `${staff.first_name} ${staff.last_name ?? ""}`.trim(),
        business_id: staff.business_id,
        salon_name: (staff as any).businesses?.name ?? "",
        photos: pending ?? [],
      }, 200, corsHeaders);
    }

    // ── Upload photo or video ──
    if (action === "upload") {
      const staffId = body.staff_id;
      const photoId = body.photo_id; // null for new, existing ID to add after
      const imageBase64 = body.image; // base64 encoded
      const isBefore = body.is_before ?? true;
      const serviceName = body.service_name;
      const clientName = body.client_name;
      // Optional hint from the client — "after_only" creates a complete
      // pair with just an after image (client refused before).
      const afterOnly = body.after_only === true;
      // Optional brand overlays — array of {sticker_id, x, y, scale, rotation}.
      // Rendered at display time; never burned into the media.
      const overlays: Array<Record<string, unknown>> = Array.isArray(body.overlays)
        ? (body.overlays as Array<Record<string, unknown>>)
            .filter(o => typeof o?.sticker_id === "string")
            .map(o => ({
              sticker_id: String(o.sticker_id),
              x: Math.max(0, Math.min(1, Number(o.x) || 0.5)),
              y: Math.max(0, Math.min(1, Number(o.y) || 0.5)),
              scale: Math.max(0.1, Math.min(1.5, Number(o.scale) || 0.3)),
              rotation: Math.max(-180, Math.min(180, Number(o.rotation) || 0)),
            }))
            .slice(0, 5)
        : [];

      if (!staffId || !imageBase64) {
        return json({ error: "staff_id and image required" }, 400, corsHeaders);
      }

      // Verify staff exists
      const { data: staff } = await supabase
        .from("staff")
        .select("id, business_id")
        .eq("id", staffId)
        .single();

      if (!staff) return json({ error: "Staff not found" }, 404, corsHeaders);

      // Decode and detect media type by magic bytes
      const bytes = Uint8Array.from(atob(imageBase64), (c) => c.charCodeAt(0));
      const isJpeg = bytes.length >= 3 && bytes[0] === JPEG_MAGIC[0] && bytes[1] === JPEG_MAGIC[1] && bytes[2] === JPEG_MAGIC[2];
      const isPng = bytes.length >= 4 && bytes[0] === PNG_MAGIC[0] && bytes[1] === PNG_MAGIC[1] && bytes[2] === PNG_MAGIC[2] && bytes[3] === PNG_MAGIC[3];
      const isMp4 = bytes.length >= 8 && bytes[4] === MP4_FTYP_MAGIC[0] && bytes[5] === MP4_FTYP_MAGIC[1] && bytes[6] === MP4_FTYP_MAGIC[2] && bytes[7] === MP4_FTYP_MAGIC[3];
      const isWebm = bytes.length >= 4 && bytes[0] === WEBM_MAGIC[0] && bytes[1] === WEBM_MAGIC[1] && bytes[2] === WEBM_MAGIC[2] && bytes[3] === WEBM_MAGIC[3];
      const isVideo = isMp4 || isWebm;
      const isImage = isJpeg || isPng;

      if (!isImage && !isVideo) {
        return json({ error: "Formato no valido (JPEG, PNG, MP4, WebM)" }, 400, corsHeaders);
      }

      const cap = isVideo ? MAX_VIDEO_BYTES : MAX_IMAGE_BYTES;
      if (bytes.length > cap) {
        const mb = Math.floor(cap / 1024 / 1024);
        return json({
          error: isVideo
            ? `Video demasiado grande (max ${mb}MB). Recorta en tu telefono antes de subir.`
            : `Imagen demasiado grande (max ${mb}MB)`,
        }, 400, corsHeaders);
      }

      // Videos can only attach as "after" (no before-video concept in the
      // brand spec). If is_before=true with a video, treat it as after.
      const effectiveIsBefore = isVideo ? false : isBefore;

      let ext: string;
      let contentType: string;
      if (isJpeg) { ext = "jpg"; contentType = "image/jpeg"; }
      else if (isPng) { ext = "png"; contentType = "image/png"; }
      else if (isMp4) { ext = "mp4"; contentType = "video/mp4"; }
      else { ext = "webm"; contentType = "video/webm"; }

      const kind = isVideo ? "video" : (effectiveIsBefore ? "before" : "after");
      const filename = `${staffId}/${Date.now()}_${kind}.${ext}`;

      const { error: uploadError } = await supabase.storage
        .from("staff-media")
        .upload(filename, bytes, {
          contentType: contentType,
          upsert: true,
        });

      if (uploadError) {
        console.error("[PORTFOLIO-UPLOAD] Upload error:", uploadError.message);
        return json({ error: "Upload failed" }, 500, corsHeaders);
      }

      const imageUrl = supabase.storage.from("staff-media").getPublicUrl(filename).data.publicUrl;

      if (photoId) {
        // Adding after media to existing pair
        const updates: Record<string, unknown> = effectiveIsBefore
          ? { before_url: imageUrl }
          : { after_url: imageUrl, is_complete: true, completed_at: new Date().toISOString() };

        if (serviceName) updates.service_name = serviceName;
        if (clientName) updates.client_name = clientName;
        if (overlays.length > 0) updates.overlays = overlays;

        await supabase
          .from("portfolio_photos")
          .update(updates)
          .eq("id", photoId);

        return json({ photo_id: photoId, url: imageUrl, is_complete: !effectiveIsBefore }, 200, corsHeaders);
      } else {
        // New pair. after_only + image OR any video creates a complete row
        // with just the after slot filled — no "before" will be added.
        const completeImmediately = isVideo || afterOnly || !effectiveIsBefore;
        const { data: photo } = await supabase
          .from("portfolio_photos")
          .insert({
            staff_id: staffId,
            business_id: staff.business_id,
            before_url: effectiveIsBefore ? imageUrl : null,
            after_url: effectiveIsBefore ? null : imageUrl,
            service_name: serviceName,
            client_name: clientName,
            is_complete: completeImmediately,
            completed_at: completeImmediately ? new Date().toISOString() : null,
            overlays: overlays,
          })
          .select("id")
          .single();

        return json({
          photo_id: photo?.id,
          url: imageUrl,
          is_complete: completeImmediately,
          is_video: isVideo,
        }, 200, corsHeaders);
      }
    }

    // ── Update overlays on an existing photo (re-position / change sticker) ──
    if (action === "set_overlays") {
      const photoId = body.photo_id;
      if (!photoId) return json({ error: "photo_id required" }, 400, corsHeaders);
      const incoming: Array<Record<string, unknown>> = Array.isArray(body.overlays)
        ? (body.overlays as Array<Record<string, unknown>>)
            .filter(o => typeof o?.sticker_id === "string")
            .map(o => ({
              sticker_id: String(o.sticker_id),
              x: Math.max(0, Math.min(1, Number(o.x) || 0.5)),
              y: Math.max(0, Math.min(1, Number(o.y) || 0.5)),
              scale: Math.max(0.1, Math.min(1.5, Number(o.scale) || 0.3)),
              rotation: Math.max(-180, Math.min(180, Number(o.rotation) || 0)),
            }))
            .slice(0, 5)
        : [];

      await supabase
        .from("portfolio_photos")
        .update({ overlays: incoming })
        .eq("id", photoId);

      return json({ photo_id: photoId, overlays: incoming }, 200, corsHeaders);
    }

    // ── Hide from stylist gallery (keeps it in salon portfolio) ──
    if (action === "hide") {
      const photoId = body.photo_id;
      if (!photoId) return json({ error: "photo_id required" }, 400, corsHeaders);

      await supabase
        .from("portfolio_photos")
        .update({ hidden_from_staff_view: true })
        .eq("id", photoId);

      return json({ photo_id: photoId, hidden: true }, 200, corsHeaders);
    }

    // ── Toggle feed publish ──
    if (action === "toggle_feed") {
      const photoId = body.photo_id;
      const publish = body.publish ?? false;

      if (!photoId) return json({ error: "photo_id required" }, 400, corsHeaders);

      await supabase
        .from("portfolio_photos")
        .update({ publish_to_feed: publish })
        .eq("id", photoId);

      return json({ photo_id: photoId, publish_to_feed: publish }, 200, corsHeaders);
    }

    return json({ error: "Unknown action" }, 400, corsHeaders);

  } catch (err) {
    console.error("[PORTFOLIO-UPLOAD] Error:", (err as Error).message);
    return json({ error: (err as Error).message }, 500, corsHeaders);
  }
});

function json(body: unknown, status = 200, headers: Record<string, string> = {}) {
  return new Response(JSON.stringify(body), {
    status,
    headers: { "Content-Type": "application/json", ...headers },
  });
}
