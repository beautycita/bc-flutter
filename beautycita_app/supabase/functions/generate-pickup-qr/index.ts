// =============================================================================
// generate-pickup-qr — Mint a fresh pickup QR token for an awaiting_pickup order
// =============================================================================
// Caller: order's buyer_id (authenticated). Rate limited 5/h/buyer.
// Returns a one-time cleartext token; only the SHA-256 hash is persisted.
// If the buyer regenerates, the prior token is revoked.
// =============================================================================

import { serve } from "https://deno.land/std@0.177.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";
import { corsHeaders, handleCorsPreflightIfOptions } from "../_shared/cors.ts";

const SUPABASE_URL = Deno.env.get("SUPABASE_URL") ?? "";
const SUPABASE_ANON_KEY = Deno.env.get("SUPABASE_ANON_KEY") ?? "";
const SUPABASE_SERVICE_ROLE_KEY = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY") ?? "";

const QR_EXPIRY_DAYS = 7;
const RATE_LIMIT_PER_HOUR = 5;
const rateLimitBuckets = new Map<string, { count: number; resetAt: number }>();

function rateLimit(buyerId: string): boolean {
  const now = Date.now();
  const bucket = rateLimitBuckets.get(buyerId);
  if (!bucket || now > bucket.resetAt) {
    rateLimitBuckets.set(buyerId, { count: 1, resetAt: now + 3600_000 });
    return true;
  }
  if (bucket.count >= RATE_LIMIT_PER_HOUR) return false;
  bucket.count++;
  return true;
}

function randomToken(): string {
  const buf = new Uint8Array(32);
  crypto.getRandomValues(buf);
  return btoa(String.fromCharCode(...buf))
    .replaceAll("+", "-").replaceAll("/", "_").replaceAll("=", "");
}

async function sha256Hex(s: string): Promise<string> {
  const buf = new TextEncoder().encode(s);
  const hash = await crypto.subtle.digest("SHA-256", buf);
  return Array.from(new Uint8Array(hash))
    .map((b) => b.toString(16).padStart(2, "0"))
    .join("");
}

serve(async (req) => {
  const cors = handleCorsPreflightIfOptions(req);
  if (cors) return cors;
  const json = (b: unknown, s = 200) =>
    new Response(JSON.stringify(b), {
      status: s,
      headers: { ...corsHeaders(req), "Content-Type": "application/json" },
    });

  try {
    const auth = req.headers.get("Authorization") ?? "";
    const token = auth.replace("Bearer ", "");
    if (!token) return json({ error: "Unauthorized" }, 401);

    const userClient = createClient(SUPABASE_URL, SUPABASE_ANON_KEY, {
      global: { headers: { Authorization: `Bearer ${token}` } },
    });
    const { data: { user }, error: authErr } = await userClient.auth.getUser();
    if (authErr || !user) return json({ error: "Unauthorized" }, 401);

    if (!rateLimit(user.id)) {
      return json({ error: "Rate limit exceeded (5/hour)" }, 429);
    }

    const body = await req.json();
    const orderId = body.order_id as string | undefined;
    if (!orderId) return json({ error: "order_id required" }, 400);

    const svc = createClient(SUPABASE_URL, SUPABASE_SERVICE_ROLE_KEY);
    const { data: order } = await svc
      .from("orders")
      .select("id, buyer_id, status, fulfillment_method")
      .eq("id", orderId)
      .single();
    if (!order) return json({ error: "Order not found" }, 404);
    if (order.buyer_id !== user.id) return json({ error: "Forbidden" }, 403);
    if (order.fulfillment_method !== "pickup") {
      return json({ error: "Order is not a pickup order" }, 409);
    }
    if (order.status !== "awaiting_pickup") {
      return json({ error: `Order status is ${order.status}, not awaiting_pickup` }, 409);
    }

    const cleartext = randomToken();
    const hash = await sha256Hex(cleartext);
    const now = new Date();
    const expiresAt = new Date(now.getTime() + QR_EXPIRY_DAYS * 86400_000);

    // Revoke any prior unrevoked token + set new one in a single UPDATE.
    const { error: updErr } = await svc
      .from("orders")
      .update({
        pickup_qr_token_hash: hash,
        pickup_qr_expires_at: expiresAt.toISOString(),
        pickup_qr_issued_at: now.toISOString(),
        pickup_qr_revoked_at: null,
      })
      .eq("id", orderId)
      .eq("status", "awaiting_pickup");

    if (updErr) {
      return json({ error: `Failed to mint QR: ${updErr.message}` }, 500);
    }

    return json({
      token: cleartext,
      expires_at: expiresAt.toISOString(),
      order_id: orderId,
    });
  } catch (e) {
    console.error("[generate-pickup-qr]", e);
    return json({ error: String(e).slice(0, 200) }, 500);
  }
});
