// =============================================================================
// order-followup — Scheduled follow-up for unfulfilled marketplace orders
// =============================================================================
// Invoked daily by cron (or manually). Handles escalation tiers:
//   Day 3:  Push notification to salon — gentle reminder
//   Day 7:  Push + email to salon — urgent warning
//   Day 14: Saldo refund to buyer + debt to seller, notify both
// =============================================================================

import { createClient } from "https://esm.sh/@supabase/supabase-js@2";
import { requireFeature } from "../_shared/check-toggle.ts";
import { processRefund } from "../_shared/refund.ts";

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
  "Access-Control-Allow-Headers":
    "authorization, x-client-info, apikey, content-type",
});

const SUPABASE_URL = Deno.env.get("SUPABASE_URL") ?? "";
const SUPABASE_SERVICE_ROLE_KEY = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY") ?? "";

let _req: Request;

function json(body: unknown, status = 200) {
  return new Response(JSON.stringify(body), {
    status,
    headers: { ...corsHeaders(_req), "Content-Type": "application/json" },
  });
}

// ---------------------------------------------------------------------------
// Types
// ---------------------------------------------------------------------------

interface Order {
  id: string;
  buyer_id: string;
  business_id: string;
  product_name: string | null;
  total_amount: number;
  payment_method: string | null;
  stripe_payment_intent_id: string | null;
  created_at: string;
  status: string;
  businesses: {
    id: string;
    owner_id: string;
    name: string;
    email: string | null;
  } | null;
}

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

function daysSince(isoDate: string): number {
  const ms = Date.now() - new Date(isoDate).getTime();
  return Math.floor(ms / 86_400_000);
}

/** Send push notification via the send-push-notification edge function. */
async function sendPush(
  userId: string,
  title: string,
  body: string,
  data?: Record<string, string>,
): Promise<void> {
  try {
    const resp = await fetch(`${SUPABASE_URL}/functions/v1/send-push-notification`, {
      method: "POST",
      headers: {
        Authorization: `Bearer ${SUPABASE_SERVICE_ROLE_KEY}`,
        "Content-Type": "application/json",
      },
      body: JSON.stringify({
        user_id: userId,
        notification_type: "new_booking", // required field; content overridden by custom_*
        custom_title: title,
        custom_body: body,
        data: data ?? {},
      }),
    });
    if (!resp.ok) {
      console.error(`[ORDER-FOLLOWUP] Push failed for ${userId}: ${await resp.text()}`);
    }
  } catch (err) {
    console.error(`[ORDER-FOLLOWUP] Push error for ${userId}:`, err);
  }
}

/** Send email via the send-email edge function (template-based). */
async function sendEscalationEmail(
  to: string,
  subject: string,
  variables: Record<string, string>,
): Promise<void> {
  try {
    // Uses the "order-escalation" template. If the template does not yet exist
    // in send-email/index.ts, add it there with placeholders:
    //   {{ORDER_ID}}, {{PRODUCT_NAME}}, {{DAYS}}, {{BUSINESS_NAME}}
    const resp = await fetch(`${SUPABASE_URL}/functions/v1/send-email`, {
      method: "POST",
      headers: {
        Authorization: `Bearer ${SUPABASE_SERVICE_ROLE_KEY}`,
        "Content-Type": "application/json",
      },
      body: JSON.stringify({
        template: "order-escalation",
        to,
        subject,
        variables,
      }),
    });
    if (!resp.ok) {
      console.error(`[ORDER-FOLLOWUP] Email failed to ${to}: ${await resp.text()}`);
    }
  } catch (err) {
    console.error(`[ORDER-FOLLOWUP] Email error to ${to}:`, err);
  }
}

// ---------------------------------------------------------------------------
// Main handler
// ---------------------------------------------------------------------------

Deno.serve(async (req: Request) => {
  _req = req;
  if (req.method === "OPTIONS") {
    return new Response(null, { headers: corsHeaders(req) });
  }

  if (req.method !== "POST") {
    return json({ error: "Method not allowed" }, 405);
  }

  try {
    // Auth: cron secret or service-role key required
    const authHeader = req.headers.get("authorization") ?? "";
    const cronSecret = Deno.env.get("CRON_SECRET") ?? "";
    const isValidCron = cronSecret && authHeader === `Bearer ${cronSecret}`;
    const isServiceRole = authHeader === `Bearer ${SUPABASE_SERVICE_ROLE_KEY}`;
    if (!isValidCron && !isServiceRole) {
      return json({ error: "Unauthorized" }, 401);
    }

    // Feature toggle check
    const blocked = await requireFeature("enable_pos");
    if (blocked) return blocked;

    const supabase = createClient(SUPABASE_URL, SUPABASE_SERVICE_ROLE_KEY);

    // -----------------------------------------------------------------
    // 1. Fetch all paid orders with business info
    // -----------------------------------------------------------------
    const { data: orders, error: queryErr } = await supabase
      .from("orders")
      .select(`
        id,
        buyer_id,
        business_id,
        product_name,
        total_amount,
        payment_method,
        stripe_payment_intent_id,
        created_at,
        status,
        businesses!inner (
          id,
          owner_id,
          name,
          email
        )
      `)
      .eq("status", "paid");

    if (queryErr) {
      console.error("[ORDER-FOLLOWUP] Query error:", queryErr.message);
      return json({ error: queryErr.message }, 500);
    }

    if (!orders || orders.length === 0) {
      console.log("[ORDER-FOLLOWUP] No paid orders pending fulfillment.");
      return json({ day3_notified: 0, day7_escalated: 0, day14_refunded: 0 });
    }

    // -----------------------------------------------------------------
    // 2. Group orders by escalation tier
    // -----------------------------------------------------------------
    const day3Orders: { order: Order; days: number }[] = [];
    const day7Orders: { order: Order; days: number }[] = [];
    const day14Orders: { order: Order; days: number }[] = [];

    for (const raw of orders) {
      const order = raw as unknown as Order;
      const days = daysSince(order.created_at);

      if (days >= 14) {
        day14Orders.push({ order, days });
      } else if (days >= 7) {
        day7Orders.push({ order, days });
      } else if (days >= 3) {
        day3Orders.push({ order, days });
      }
      // < 3 days: no action yet
    }

    console.log(
      `[ORDER-FOLLOWUP] Found ${orders.length} paid orders: ` +
      `day3=${day3Orders.length}, day7=${day7Orders.length}, day14=${day14Orders.length}`,
    );

    // -----------------------------------------------------------------
    // 3. Day 3: Gentle push notification to salon owner
    // -----------------------------------------------------------------
    for (const { order, days } of day3Orders) {
      const ownerId = order.businesses?.owner_id;
      if (!ownerId) continue;

      const shortId = order.id.slice(0, 8).toUpperCase();
      await sendPush(
        ownerId,
        "Pedido pendiente de envio",
        `El pedido #${shortId} lleva ${days} dias sin enviarse`,
        { type: "order_followup", order_id: order.id },
      );
    }

    // -----------------------------------------------------------------
    // 4. Day 7: Push + escalation email to salon owner
    // -----------------------------------------------------------------
    for (const { order, days } of day7Orders) {
      const biz = order.businesses;
      if (!biz) continue;

      const shortId = order.id.slice(0, 8).toUpperCase();
      const productName = order.product_name ?? "producto";

      // Push notification
      if (biz.owner_id) {
        await sendPush(
          biz.owner_id,
          "Urgente: Pedido pendiente de envio",
          `El pedido #${shortId} de ${productName} lleva ${days} dias. Sera reembolsado si no se envia.`,
          { type: "order_escalation", order_id: order.id },
        );
      }

      // Email to business
      if (biz.email) {
        await sendEscalationEmail(
          biz.email,
          "Urgente: Pedido pendiente de envio",
          {
            ORDER_ID: shortId,
            PRODUCT_NAME: productName,
            DAYS: String(days),
            BUSINESS_NAME: biz.name ?? "Negocio",
          },
        );
      }
    }

    // -----------------------------------------------------------------
    // 5. Day 14: Stripe refund + update status + notify buyer
    // -----------------------------------------------------------------
    let refundErrors = 0;

    for (const { order, days } of day14Orders) {
      const shortId = order.id.slice(0, 8).toUpperCase();
      const productName = order.product_name ?? "producto";

      try {
        // 5a. Refund: saldo credit to buyer + debt to seller (never card)
        const result = await processRefund({
          supabase,
          buyerId: order.buyer_id,
          businessId: order.business_id,
          grossAmount: order.total_amount,
          orderId: order.id,
          paymentMethod: order.payment_method,
          reason: `order_timeout_${order.id}`,
          idempotencyKey: `order-refund-${order.id}`,
        });

        console.log(
          `[ORDER-FOLLOWUP] Refund for ${shortId}: saldo $${result.saldoCredit}, ` +
          `debt $${result.debtCreated}, BC fee $${result.processingFee}`
        );

        // 5b. Update order status
        const { error: updateErr } = await supabase
          .from("orders")
          .update({
            status: "refunded",
            refunded_at: new Date().toISOString(),
          })
          .eq("id", order.id);

        if (updateErr) {
          console.error(`[ORDER-FOLLOWUP] Failed to update order ${shortId}:`, updateErr.message);
          refundErrors++;
          continue;
        }

        // 5e. Notify buyer
        await sendPush(
          order.buyer_id,
          "Pedido reembolsado",
          `Tu pedido de ${productName} fue reembolsado porque el vendedor no lo envio a tiempo.`,
          { type: "order_refunded", order_id: order.id },
        );

        // 5f. Notify salon owner too
        const ownerId = order.businesses?.owner_id;
        if (ownerId) {
          await sendPush(
            ownerId,
            "Pedido reembolsado automaticamente",
            `El pedido #${shortId} de ${productName} fue reembolsado tras ${days} dias sin envio.`,
            { type: "order_auto_refunded", order_id: order.id },
          );
        }
      } catch (err) {
        console.error(`[ORDER-FOLLOWUP] Refund failed for order ${shortId}:`, (err as Error).message);
        refundErrors++;
      }
    }

    // -----------------------------------------------------------------
    // 6. Return summary
    // -----------------------------------------------------------------
    const summary = {
      day3_notified: day3Orders.length,
      day7_escalated: day7Orders.length,
      day14_refunded: day14Orders.length - refundErrors,
      day14_errors: refundErrors,
      total_processed: orders.length,
    };

    console.log("[ORDER-FOLLOWUP] Summary:", JSON.stringify(summary));
    return json(summary);
  } catch (err) {
    console.error("[ORDER-FOLLOWUP] Fatal error:", err);
    return json({ error: "An internal error occurred" }, 500);
  }
});
