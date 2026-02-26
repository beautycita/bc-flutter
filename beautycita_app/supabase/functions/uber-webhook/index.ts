// uber-webhook edge function
// Receives webhook events from Uber (ride status, receipts, account linking).
// Verifies X-Uber-Signature HMAC SHA256, processes event, returns 200.

import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

const supabaseUrl = Deno.env.get("SUPABASE_URL")!;
const serviceKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!;
// Uber signs webhooks with the signing key configured in their console.
// For sandbox this is the client secret; for production it may differ.
const UBER_WEBHOOK_SIGNING_KEY = Deno.env.get("UBER_WEBHOOK_SIGNING_KEY") ?? "";
const UBER_CLIENT_SECRET = Deno.env.get("UBER_CLIENT_SECRET") ?? "";
const SIGNING_KEYS = [UBER_WEBHOOK_SIGNING_KEY, UBER_CLIENT_SECRET].filter(Boolean);

// ---------------------------------------------------------------------------
// HMAC signature verification
// ---------------------------------------------------------------------------

async function verifySignature(
  body: string,
  signature: string,
): Promise<boolean> {
  if (!signature || SIGNING_KEYS.length === 0) return false;

  const encoder = new TextEncoder();

  // Try each signing key (supports both sandbox and production)
  for (const secret of SIGNING_KEYS) {
    const key = await crypto.subtle.importKey(
      "raw",
      encoder.encode(secret),
      { name: "HMAC", hash: "SHA-256" },
      false,
      ["sign"],
    );

    const sig = await crypto.subtle.sign("HMAC", key, encoder.encode(body));
    const hex = Array.from(new Uint8Array(sig))
      .map((b) => b.toString(16).padStart(2, "0"))
      .join("");

    if (hex === signature.toLowerCase()) return true;
  }

  return false;
}

// ---------------------------------------------------------------------------
// Main handler
// ---------------------------------------------------------------------------

Deno.serve(async (req: Request) => {
  // Uber only sends POST
  if (req.method === "OPTIONS") {
    return new Response(null, {
      headers: {
        "Access-Control-Allow-Origin": "*",
        "Access-Control-Allow-Methods": "POST",
        "Access-Control-Allow-Headers": "*",
      },
    });
  }

  if (req.method !== "POST") {
    return new Response("", { status: 405 });
  }

  const rawBody = await req.text();
  const uberSignature = req.headers.get("x-uber-signature") ?? "";
  const environment = req.headers.get("x-environment") ?? "unknown";

  console.log(`[uber-webhook] Received event (env=${environment})`);

  // Verify HMAC signature
  if (SIGNING_KEYS.length > 0) {
    const valid = await verifySignature(rawBody, uberSignature);
    if (!valid) {
      console.error("[uber-webhook] Invalid signature — rejecting");
      return new Response("", { status: 401 });
    }
  } else {
    console.warn("[uber-webhook] No signing key set — skipping signature verification");
  }

  let event: {
    event_id: string;
    event_time: number;
    event_type: string;
    meta: Record<string, string>;
    resource_href?: string;
  };

  try {
    event = JSON.parse(rawBody);
  } catch {
    console.error("[uber-webhook] Failed to parse body");
    return new Response("", { status: 400 });
  }

  console.log(
    `[uber-webhook] event_type=${event.event_type} event_id=${event.event_id} meta=${JSON.stringify(event.meta)}`,
  );

  const supabase = createClient(supabaseUrl, serviceKey);

  // Store the raw event for debugging/audit
  await supabase.from("uber_webhook_events").insert({
    event_id: event.event_id,
    event_type: event.event_type,
    event_time: new Date(event.event_time * 1000).toISOString(),
    environment,
    meta: event.meta,
    resource_href: event.resource_href ?? null,
    raw_body: rawBody,
  }).then(({ error }) => {
    if (error) console.error("[uber-webhook] Failed to store event:", error.message);
  });

  // Process by event type
  switch (event.event_type) {
    case "requests.status_changed": {
      const { resource_id, status, user_id } = event.meta;
      console.log(
        `[uber-webhook] Ride ${resource_id} → ${status} (user=${user_id})`,
      );

      // Update ride status in our table
      if (resource_id && status) {
        const { error } = await supabase
          .from("uber_scheduled_rides")
          .update({ status, updated_at: new Date().toISOString() })
          .eq("uber_request_id", resource_id);

        if (error) {
          console.error("[uber-webhook] Failed to update ride:", error.message);
        }
      }
      break;
    }

    case "requests.receipt_ready": {
      const { resource_id } = event.meta;
      console.log(`[uber-webhook] Receipt ready for ride ${resource_id}`);
      // Could fetch receipt via resource_href and store it
      break;
    }

    default:
      console.log(`[uber-webhook] Unhandled event type: ${event.event_type}`);
  }

  // Uber expects 200 with empty body
  return new Response("", { status: 200 });
});
