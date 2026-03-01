// =============================================================================
// btcpay-webhook — Handle BTCPay webhook events
// =============================================================================
// Processes BTCPay Server webhook events for invoice status changes.
// Updates appointment payment status on settlement.
// =============================================================================

import { serve } from "https://deno.land/std@0.177.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";
import { createHmac } from "https://deno.land/std@0.177.0/crypto/mod.ts";

const BTCPAY_WEBHOOK_SECRET = Deno.env.get("BTCPAY_WEBHOOK_SECRET") ?? "";
const SUPABASE_URL = Deno.env.get("SUPABASE_URL") ?? "";
const SUPABASE_SERVICE_ROLE_KEY = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY") ?? "";

interface BTCPayWebhookEvent {
  deliveryId: string;
  webhookId: string;
  originalDeliveryId: string;
  isRedelivery: boolean;
  type: string;
  timestamp: number;
  storeId: string;
  invoiceId: string;
  metadata?: {
    orderId?: string;
    service_id?: string;
    business_id?: string;
    user_id?: string;
    staff_id?: string;
    scheduled_at?: string;
    payment_type?: string;
    platform_fee?: string;
  };
  // For InvoiceSettled events
  payment?: {
    value: string;
    paymentMethod: string;
    destination: string;
  };
}

serve(async (req) => {
  // BTCPay sends POST requests
  if (req.method !== "POST") {
    return new Response("Method not allowed", { status: 405 });
  }

  try {
    // Verify webhook signature
    const signature = req.headers.get("BTCPay-Sig");
    const body = await req.text();

    if (!BTCPAY_WEBHOOK_SECRET) {
      console.error("[BTCPAY-WEBHOOK] BTCPAY_WEBHOOK_SECRET not configured — rejecting");
      return new Response("Webhook secret not configured", { status: 500 });
    }
    if (!signature) {
      console.error("[BTCPAY-WEBHOOK] Missing BTCPay-Sig header");
      return new Response("Missing signature", { status: 401 });
    }
    const expectedSig = `sha256=${await computeHmac(BTCPAY_WEBHOOK_SECRET, body)}`;
    if (signature !== expectedSig) {
      console.error("[BTCPAY-WEBHOOK] Invalid signature");
      return new Response("Invalid signature", { status: 401 });
    }

    const event: BTCPayWebhookEvent = JSON.parse(body);
    console.log(`[BTCPAY-WEBHOOK] Received ${event.type} for invoice ${event.invoiceId}`);

    const supabase = createClient(SUPABASE_URL, SUPABASE_SERVICE_ROLE_KEY);

    // Handle different event types
    switch (event.type) {
      case "InvoiceSettled":
        // Payment confirmed
        await handleInvoiceSettled(supabase, event);
        break;

      case "InvoiceExpired":
        // Invoice expired without payment
        await handleInvoiceExpired(supabase, event);
        break;

      case "InvoiceInvalid":
        // Payment failed or invalid
        await handleInvoiceInvalid(supabase, event);
        break;

      case "InvoiceProcessing":
        // Payment received, waiting for confirmations
        await handleInvoiceProcessing(supabase, event);
        break;

      default:
        console.log(`[BTCPAY-WEBHOOK] Ignoring event type: ${event.type}`);
    }

    return new Response(JSON.stringify({ received: true }), {
      status: 200,
      headers: { "Content-Type": "application/json" },
    });

  } catch (err) {
    console.error("[BTCPAY-WEBHOOK] Error:", (err as Error).message);
    return new Response(JSON.stringify({ error: (err as Error).message }), {
      status: 500,
      headers: { "Content-Type": "application/json" },
    });
  }
});

async function handleInvoiceSettled(
  supabase: ReturnType<typeof createClient>,
  event: BTCPayWebhookEvent
) {
  console.log(`[BTCPAY-WEBHOOK] Invoice ${event.invoiceId} settled`);

  const metadata = event.metadata;
  if (!metadata?.service_id || !metadata?.user_id || !metadata?.scheduled_at) {
    console.error("[BTCPAY-WEBHOOK] Missing metadata in settled invoice");
    return;
  }

  // Create or update the appointment
  const { data: existingAppointment } = await supabase
    .from("appointments")
    .select("id")
    .eq("btcpay_invoice_id", event.invoiceId)
    .single();

  if (existingAppointment) {
    // Update existing appointment
    const { error } = await supabase
      .from("appointments")
      .update({
        payment_status: "paid",
        payment_method: "bitcoin",
        paid_at: new Date().toISOString(),
      })
      .eq("id", existingAppointment.id);

    if (error) {
      console.error("[BTCPAY-WEBHOOK] Failed to update appointment:", error.message);
    } else {
      console.log(`[BTCPAY-WEBHOOK] Updated appointment ${existingAppointment.id} to paid`);
    }
  } else {
    // Create new appointment
    const { data: newAppointment, error } = await supabase
      .from("appointments")
      .insert({
        user_id: metadata.user_id,
        service_id: metadata.service_id,
        business_id: metadata.business_id,
        staff_id: metadata.staff_id || null,
        scheduled_at: metadata.scheduled_at,
        status: "confirmed",
        payment_status: "paid",
        payment_method: "bitcoin",
        btcpay_invoice_id: event.invoiceId,
        paid_at: new Date().toISOString(),
        platform_fee: metadata.platform_fee ? parseFloat(metadata.platform_fee) : null,
      })
      .select()
      .single();

    if (error) {
      console.error("[BTCPAY-WEBHOOK] Failed to create appointment:", error.message);
    } else {
      console.log(`[BTCPAY-WEBHOOK] Created appointment ${newAppointment?.id} as paid`);
    }
  }
}

async function handleInvoiceExpired(
  supabase: ReturnType<typeof createClient>,
  event: BTCPayWebhookEvent
) {
  console.log(`[BTCPAY-WEBHOOK] Invoice ${event.invoiceId} expired`);

  // Update any pending appointment to expired
  const { error } = await supabase
    .from("appointments")
    .update({
      payment_status: "expired",
      status: "cancelled",
    })
    .eq("btcpay_invoice_id", event.invoiceId)
    .eq("payment_status", "pending");

  if (error) {
    console.error("[BTCPAY-WEBHOOK] Failed to expire appointment:", error.message);
  }
}

async function handleInvoiceInvalid(
  supabase: ReturnType<typeof createClient>,
  event: BTCPayWebhookEvent
) {
  console.log(`[BTCPAY-WEBHOOK] Invoice ${event.invoiceId} invalid`);

  // Update any pending appointment to failed
  const { error } = await supabase
    .from("appointments")
    .update({
      payment_status: "failed",
      status: "cancelled",
    })
    .eq("btcpay_invoice_id", event.invoiceId)
    .eq("payment_status", "pending");

  if (error) {
    console.error("[BTCPAY-WEBHOOK] Failed to mark appointment as failed:", error.message);
  }
}

async function handleInvoiceProcessing(
  supabase: ReturnType<typeof createClient>,
  event: BTCPayWebhookEvent
) {
  console.log(`[BTCPAY-WEBHOOK] Invoice ${event.invoiceId} processing`);

  const metadata = event.metadata;
  if (!metadata?.service_id || !metadata?.user_id || !metadata?.scheduled_at) {
    console.error("[BTCPAY-WEBHOOK] Missing metadata in processing invoice");
    return;
  }

  // Check if appointment already exists
  const { data: existingAppointment } = await supabase
    .from("appointments")
    .select("id")
    .eq("btcpay_invoice_id", event.invoiceId)
    .single();

  if (!existingAppointment) {
    // Create pending appointment while waiting for confirmations
    const { error } = await supabase
      .from("appointments")
      .insert({
        user_id: metadata.user_id,
        service_id: metadata.service_id,
        business_id: metadata.business_id,
        staff_id: metadata.staff_id || null,
        scheduled_at: metadata.scheduled_at,
        status: "pending",
        payment_status: "processing",
        payment_method: "bitcoin",
        btcpay_invoice_id: event.invoiceId,
        platform_fee: metadata.platform_fee ? parseFloat(metadata.platform_fee) : null,
      });

    if (error) {
      console.error("[BTCPAY-WEBHOOK] Failed to create pending appointment:", error.message);
    } else {
      console.log(`[BTCPAY-WEBHOOK] Created pending appointment for invoice ${event.invoiceId}`);
    }
  }
}

async function computeHmac(secret: string, data: string): Promise<string> {
  const encoder = new TextEncoder();
  const key = await crypto.subtle.importKey(
    "raw",
    encoder.encode(secret),
    { name: "HMAC", hash: "SHA-256" },
    false,
    ["sign"]
  );
  const signature = await crypto.subtle.sign("HMAC", key, encoder.encode(data));
  return Array.from(new Uint8Array(signature))
    .map((b) => b.toString(16).padStart(2, "0"))
    .join("");
}
