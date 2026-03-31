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

serve(async (req) => {
  const url = new URL(req.url);
  const supabase = createClient(SUPABASE_URL, SUPABASE_SERVICE_ROLE_KEY);

  // CORS
  const corsHeaders = {
    "Access-Control-Allow-Origin": "*",
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

      const { data: staff } = await supabase
        .from("staff")
        .select("id, first_name, last_name, business_id, upload_pin, businesses(name)")
        .eq("upload_qr_token", token)
        .eq("is_active", true)
        .maybeSingle();

      if (!staff || staff.upload_pin !== pin) {
        return json({ error: "PIN incorrecto" }, 401, corsHeaders);
      }

      // Return staff info + pending photos
      const { data: pending } = await supabase
        .from("portfolio_photos")
        .select("id, before_url, after_url, service_name, client_name, is_complete, publish_to_feed, created_at")
        .eq("staff_id", staff.id)
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

    // ── Upload photo ──
    if (action === "upload") {
      const staffId = body.staff_id;
      const photoId = body.photo_id; // null for new, existing ID to add after
      const imageBase64 = body.image; // base64 encoded
      const isBefore = body.is_before ?? true;
      const serviceName = body.service_name;
      const clientName = body.client_name;

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

      // Decode and upload image
      const bytes = Uint8Array.from(atob(imageBase64), (c) => c.charCodeAt(0));
      const filename = `${staffId}/${Date.now()}_${isBefore ? "before" : "after"}.jpg`;

      const { error: uploadError } = await supabase.storage
        .from("staff-media")
        .upload(filename, bytes, {
          contentType: "image/jpeg",
          upsert: true,
        });

      if (uploadError) {
        console.error("[PORTFOLIO-UPLOAD] Upload error:", uploadError.message);
        return json({ error: "Upload failed" }, 500, corsHeaders);
      }

      const imageUrl = supabase.storage.from("staff-media").getPublicUrl(filename).data.publicUrl;

      if (photoId) {
        // Adding after photo to existing pair
        const updates: Record<string, unknown> = isBefore
          ? { before_url: imageUrl }
          : { after_url: imageUrl, is_complete: true, completed_at: new Date().toISOString() };

        if (serviceName) updates.service_name = serviceName;
        if (clientName) updates.client_name = clientName;

        await supabase
          .from("portfolio_photos")
          .update(updates)
          .eq("id", photoId);

        return json({ photo_id: photoId, url: imageUrl, is_complete: !isBefore }, 200, corsHeaders);
      } else {
        // New photo pair
        const { data: photo } = await supabase
          .from("portfolio_photos")
          .insert({
            staff_id: staffId,
            business_id: staff.business_id,
            before_url: isBefore ? imageUrl : null,
            after_url: isBefore ? null : imageUrl,
            service_name: serviceName,
            client_name: clientName,
            is_complete: !isBefore,
            completed_at: isBefore ? null : new Date().toISOString(),
          })
          .select("id")
          .single();

        return json({
          photo_id: photo?.id,
          url: imageUrl,
          is_complete: !isBefore,
        }, 200, corsHeaders);
      }
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
