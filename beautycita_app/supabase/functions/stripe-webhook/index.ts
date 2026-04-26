// =============================================================================
// stripe-webhook — Handle Stripe webhook events for BeautyCita
// =============================================================================
// Handles:
// - account.updated: When Stripe Connect Express account completes onboarding
// - payment_intent.succeeded: When a payment is confirmed
// - payment_intent.payment_failed: When a payment fails
// - payment_intent.canceled: When an OXXO payment expires (cleans up pending bookings)
// - checkout.session.completed: For booking payments
// - charge.refunded: When a refund is processed
// =============================================================================

import { serve } from "https://deno.land/std@0.177.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";
import Stripe from "https://esm.sh/stripe@14.21.0?target=deno";
import { requireFeature } from "../_shared/check-toggle.ts";
import { corsHeaders } from "../_shared/cors.ts";

const STRIPE_SECRET_KEY = Deno.env.get("STRIPE_SECRET_KEY") ?? "";
const STRIPE_WEBHOOK_SECRET = Deno.env.get("STRIPE_WEBHOOK_SECRET") ?? "";
const SUPABASE_URL = Deno.env.get("SUPABASE_URL") ?? "";
const SUPABASE_SERVICE_ROLE_KEY = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY") ?? "";

const stripe = new Stripe(STRIPE_SECRET_KEY, {
  apiVersion: "2023-10-16",
  httpClient: Stripe.createFetchHttpClient(),
});

serve(async (req) => {
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders(req, "stripe-signature") });
  }

  try {
    const signature = req.headers.get("stripe-signature");
    if (!signature) {
      return new Response(JSON.stringify({ error: "Missing stripe-signature header" }), {
        status: 400,
        headers: { ...corsHeaders(req, "stripe-signature"), "Content-Type": "application/json" },
      });
    }

    const body = await req.text();

    let event: Stripe.Event;
    try {
      event = stripe.webhooks.constructEvent(body, signature, STRIPE_WEBHOOK_SECRET);
    } catch (err) {
      console.error("Webhook signature verification failed:", (err as Error).message);
      return new Response(JSON.stringify({ error: "Invalid signature" }), {
        status: 400,
        headers: { ...corsHeaders(req, "stripe-signature"), "Content-Type": "application/json" },
      });
    }

    const blocked = await requireFeature("enable_stripe_payments");
    if (blocked) return blocked;

    const supabase = createClient(SUPABASE_URL, SUPABASE_SERVICE_ROLE_KEY);

    // ── Idempotency guard ──────────────────────────────────────────────
    // Stripe retries on 5xx (exponential backoff, up to 3 days). Without
    // this, a retry re-runs calculate_payout_with_debt and double-decrements
    // salon_debts FIFO; debt_payments duplicates; chargeback debt rows
    // duplicate. INSERT-then-409 = canonical idempotency for webhooks.
    {
      const { error: dedupErr } = await supabase
        .from("stripe_webhook_events")
        .insert({ event_id: event.id, event_type: event.type });
      if (dedupErr) {
        // Postgres unique_violation = already processed — return 200 so Stripe stops retrying.
        // deno-lint-ignore no-explicit-any
        if ((dedupErr as any).code === "23505") {
          console.log(`[STRIPE-WEBHOOK] Duplicate event ${event.id} (${event.type}) — skipping`);
          return new Response(JSON.stringify({ received: true, duplicate: true }), {
            status: 200,
            headers: { ...corsHeaders(req, "stripe-signature"), "Content-Type": "application/json" },
          });
        }
        // Any other error: log but continue. Don't block payment processing on a logging failure.
        console.error(`[STRIPE-WEBHOOK] dedup insert error (continuing):`, dedupErr);
      }
    }

    console.log(`[STRIPE-WEBHOOK] Processing event: ${event.type}`);

    switch (event.type) {
      // =======================================================================
      // Stripe Connect Express - Account Updates
      // =======================================================================
      case "account.updated": {
        const account = event.data.object as Stripe.Account;

        // Check if onboarding is complete
        const chargesEnabled = account.charges_enabled;
        const payoutsEnabled = account.payouts_enabled;
        const detailsSubmitted = account.details_submitted;

        if (chargesEnabled && payoutsEnabled && detailsSubmitted) {
          console.log(`[STRIPE-WEBHOOK] Account ${account.id} onboarding complete`);

          // Find and update the business (pull beneficiary_name to compare against Stripe)
          const { data: business, error: findError } = await supabase
            .from("businesses")
            .select("id, name, beneficiary_name")
            .eq("stripe_account_id", account.id)
            .single();

          if (findError || !business) {
            console.error(`[STRIPE-WEBHOOK] Business not found for account ${account.id}`);
            break;
          }

          // Compare Stripe's verified account holder name against our beneficiary_name.
          // Mismatch opens a payout hold and an audit entry; Stripe onboarding still proceeds
          // (we don't block flag updates), but future bookings will be blocked by the hold.
          const stripeName = extractStripeAccountName(account);
          const ourName = business.beneficiary_name ?? "";
          if (stripeName && ourName && !namesMatch(stripeName, ourName)) {
            console.warn(
              `[STRIPE-WEBHOOK] Name drift — Stripe='${stripeName}' BC='${ourName}' for ${business.id}`
            );
            await supabase.from("payout_holds").insert({
              business_id: business.id,
              reason: "identity_mismatch",
              old_value: ourName,
              new_value: stripeName,
            });
            await supabase.from("audit_log").insert({
              admin_id: "00000000-0000-0000-0000-000000000000",
              action: "stripe_name_drift_detected",
              target_type: "business",
              target_id: business.id,
              details: {
                stripe_account_id: account.id,
                stripe_name: stripeName,
                our_beneficiary_name: ourName,
              },
            });
          }

          // Mark onboarding as complete
          const { error: updateError } = await supabase
            .from("businesses")
            .update({
              onboarding_complete: true,
              stripe_charges_enabled: true,
              stripe_payouts_enabled: true,
              stripe_details_submitted: true,
              updated_at: new Date().toISOString(),
            })
            .eq("id", business.id);

          if (updateError) {
            console.error(`[STRIPE-WEBHOOK] Failed to update business: ${updateError.message}`);
          } else {
            console.log(`[STRIPE-WEBHOOK] Business ${business.name} marked as onboarding complete`);

            // Send notification to business owner
            await notifyBusinessOnboarded(supabase, business.id, business.name);
          }
        } else {
          // Onboarding not yet complete - update individual flags
          const { data: business } = await supabase
            .from("businesses")
            .select("id")
            .eq("stripe_account_id", account.id)
            .single();

          if (business) {
            await supabase
              .from("businesses")
              .update({
                stripe_charges_enabled: chargesEnabled,
                stripe_payouts_enabled: payoutsEnabled,
                stripe_details_submitted: detailsSubmitted,
                updated_at: new Date().toISOString(),
              })
              .eq("id", business.id);
          }
        }
        break;
      }

      // =======================================================================
      // Payment Intents - Booking Payments
      // =======================================================================
      case "payment_intent.succeeded": {
        const paymentIntent = event.data.object as Stripe.PaymentIntent;
        const metadata = paymentIntent.metadata ?? {};

        // --- Validate business_id ownership against Stripe connected account ---
        if (metadata.business_id) {
          const stripeAccountId = typeof paymentIntent.on_behalf_of === "string"
            ? paymentIntent.on_behalf_of
            : (paymentIntent as any).transfer_data?.destination ?? null;

          if (stripeAccountId) {
            const { data: ownerBiz } = await supabase
              .from("businesses")
              .select("id")
              .eq("id", metadata.business_id)
              .eq("stripe_account_id", stripeAccountId)
              .maybeSingle();

            if (!ownerBiz) {
              console.error(
                `[STRIPE-WEBHOOK] business_id ${metadata.business_id} does not match Stripe account ${stripeAccountId} — skipping`
              );
              break;
            }
          }
        }

        // --- Gift card payments ---
        if (metadata.type === "gift_card") {
          const { data: existingCard } = await supabase
            .from("gift_cards")
            .select("id")
            .eq("code", metadata.gift_card_code)
            .maybeSingle();

          if (existingCard) {
            console.log(`[STRIPE-WEBHOOK] Gift card ${metadata.gift_card_code} already exists, skipping`);
          } else {
            const gcAmount = parseFloat(metadata.gift_card_amount ?? "0");
            const { error: gcError } = await supabase.from("gift_cards").insert({
              business_id: metadata.business_id,
              code: metadata.gift_card_code,
              amount: gcAmount,
              remaining_amount: gcAmount,
              buyer_name: metadata.buyer_name || null,
              recipient_name: metadata.recipient_name || null,
              message: metadata.message || null,
              expires_at: metadata.expires_at || null,
              is_active: true,
            });

            if (gcError) {
              console.error(`[STRIPE-WEBHOOK] Failed to create gift card: ${gcError.message}`);
            } else {
              console.log(`[STRIPE-WEBHOOK] Gift card created: ${metadata.gift_card_code} ($${gcAmount})`);
            }

            // Record commission
            const commission = (paymentIntent.application_fee_amount ?? 0) / 100;
            if (commission > 0) {
              await supabase.from("commission_records").insert({
                business_id: metadata.business_id,
                amount: commission,
                rate: 0.03,
                source: "gift_card",
                period_month: new Date().getMonth() + 1,
                period_year: new Date().getFullYear(),
                status: "collected",
              }).catch((e: Error) => console.error(`[STRIPE-WEBHOOK] Gift card commission error: ${e.message}`));
            }
          }
          break;
        }

        // --- Salon tax debt payment (Pagar ahora flow) ---
        if (metadata.payment_type === "salon_tax_debt") {
          const businessId = metadata.business_id;
          const amountMxn = paymentIntent.amount / 100;

          if (!businessId) {
            console.log(`[STRIPE-WEBHOOK] salon_tax_debt without business_id, skipping`);
            break;
          }

          // Idempotency: dedup via debt_payments stripe_payment_intent_id.
          const { data: existingPayment } = await supabase
            .from("debt_payments")
            .select("id")
            .eq("stripe_payment_intent_id", paymentIntent.id)
            .maybeSingle();
          if (existingPayment) {
            console.log(`[STRIPE-WEBHOOK] tax debt payment already applied for PI ${paymentIntent.id}`);
            break;
          }

          // FIFO apply across open tax_obligation rows.
          const { data: openDebts } = await supabase
            .from("salon_debts")
            .select("id, remaining_amount")
            .eq("business_id", businessId)
            .eq("debt_type", "tax_obligation")
            .gt("remaining_amount", 0)
            .order("created_at", { ascending: true });

          let remaining = amountMxn;
          for (const row of openDebts ?? []) {
            if (remaining <= 0) break;
            const apply = Math.min(remaining, Number(row.remaining_amount));
            const newRemaining = Number(row.remaining_amount) - apply;
            await supabase.from("salon_debts").update({
              remaining_amount: newRemaining,
              cleared_at: newRemaining === 0 ? new Date().toISOString() : null,
            }).eq("id", row.id);
            await supabase.from("debt_payments").insert({
              debt_id: row.id,
              business_id: businessId,
              amount: apply,
              source: "stripe_pagar_ahora",
              stripe_payment_intent_id: paymentIntent.id,
            }).catch((e: any) => console.error(`[STRIPE-WEBHOOK] debt_payments insert: ${e.message}`));
            remaining -= apply;
          }
          console.log(`[STRIPE-WEBHOOK] Applied $${amountMxn - remaining} MXN to tax debt for biz ${businessId}; PI ${paymentIntent.id}`);
          // The salon_debts AFTER UPDATE trigger calls compute_cash_eligibility,
          // which lifts the cash_blocked_at flag if all tax debt is now zero.
          break;
        }

        // --- Product order payments (marketplace) ---
        if (metadata.payment_type === "product") {
          // Idempotency: skip if order already exists for this payment intent
          const { data: existingOrder } = await supabase
            .from("orders")
            .select("id")
            .eq("stripe_payment_intent_id", paymentIntent.id)
            .maybeSingle();

          if (existingOrder) {
            console.log(`[STRIPE-WEBHOOK] Order already exists for PI ${paymentIntent.id}, skipping`);
          } else {
            const { error: orderError } = await supabase.from("orders").insert({
              buyer_id: metadata.user_id,
              business_id: metadata.business_id,
              product_id: metadata.product_id,
              product_name: metadata.product_name,
              quantity: parseInt(metadata.quantity ?? "1"),
              total_amount: paymentIntent.amount / 100,
              commission_amount: (paymentIntent.application_fee_amount ?? 0) / 100,
              stripe_payment_intent_id: paymentIntent.id,
              status: "paid",
              shipping_address: (() => { try { return JSON.parse(metadata.shipping_address ?? "null"); } catch { return null; } })(),
            });

            if (orderError) {
              console.error(`[STRIPE-WEBHOOK] Failed to create order: ${orderError.message}`);
            } else {
              console.log(`[STRIPE-WEBHOOK] Product order created for PI ${paymentIntent.id}`);
            }
          }
          break;
        }

        // --- Booking payments ---
        const bookingId = metadata.booking_id;

        if (!bookingId) {
          console.log(`[STRIPE-WEBHOOK] payment_intent.succeeded without booking_id metadata`);
          break;
        }

        console.log(`[STRIPE-WEBHOOK] Payment succeeded for booking ${bookingId}`);

        // Check if the booking is still valid (not cancelled, not expired)
        const { data: booking } = await supabase
          .from("appointments")
          .select("id, status, user_id, price, starts_at")
          .eq("id", bookingId)
          .maybeSingle();

        if (!booking || booking.status === "cancelled_customer" || booking.status === "cancelled_business") {
          // Booking was cancelled while OXXO payment was pending — credit saldo
          const userId = booking?.user_id || metadata.user_id;
          const amount = paymentIntent.amount / 100;
          console.log(`[STRIPE-WEBHOOK] Booking ${bookingId} cancelled — crediting $${amount} to saldo for user ${userId}`);

          if (userId) {
            await supabase.rpc("increment_saldo", {
              p_user_id: userId,
              p_amount: amount,
              p_reason: "stripe_refund_cancelled_booking",
              // Stripe event IDs are globally unique — safe idempotency key
              p_idempotency_key: `stripe:${event.id}`,
            });
            // TODO: Send notification to user about saldo credit
          }
          break;
        }

        // Check if appointment time has passed (OXXO paid too late)
        const apptTime = new Date(booking.starts_at);
        if (apptTime < new Date()) {
          const userId = booking.user_id || metadata.user_id;
          const amount = paymentIntent.amount / 100;
          console.log(`[STRIPE-WEBHOOK] Booking ${bookingId} time passed — crediting $${amount} to saldo for user ${userId}`);

          // Cancel the expired booking
          await supabase.from("appointments").update({
            status: "cancelled_customer",
            payment_status: "refunded_to_saldo",
            updated_at: new Date().toISOString(),
          }).eq("id", bookingId);

          if (userId) {
            await supabase.rpc("increment_saldo", {
              p_user_id: userId,
              p_amount: amount,
              p_reason: "stripe_refund_expired_booking",
              p_idempotency_key: `stripe:${event.id}`,
            });
          }
          break;
        }

        // Booking is valid — proceed with normal payment confirmation
        const hasTaxWithholding = paymentIntent.metadata?.tax_withholding === "true";
        const taxFields = hasTaxWithholding ? {
          isr_withheld: parseFloat(paymentIntent.metadata.isr_withheld ?? "0"),
          iva_withheld: parseFloat(paymentIntent.metadata.iva_withheld ?? "0"),
          tax_base: parseFloat(paymentIntent.metadata.tax_base ?? "0"),
          provider_net: parseFloat(paymentIntent.metadata.provider_net ?? "0"),
        } : {};

        // Update booking: mark as paid and confirmed (only if not cancelled since check)
        const { error: updateError } = await supabase
          .from("appointments")
          .update({
            status: "confirmed",
            payment_status: "paid",
            payment_intent_id: paymentIntent.id,
            paid_at: new Date().toISOString(),
            updated_at: new Date().toISOString(),
            ...taxFields,
          })
          .eq("id", bookingId)
          .not("status", "in", "(cancelled_customer,cancelled_business)");

        if (updateError) {
          console.error(`[STRIPE-WEBHOOK] Failed to update booking payment: ${updateError.message}`);
        } else {
          // Idempotency: skip payment record if one already exists for this PI + status
          const { data: existingPayment } = await supabase
            .from("payments")
            .select("id")
            .eq("stripe_payment_id", paymentIntent.id)
            .eq("status", "succeeded")
            .maybeSingle();

          if (existingPayment) {
            console.log(`[STRIPE-WEBHOOK] Payment record already exists for PI ${paymentIntent.id}, skipping`);
          } else {
            await supabase.from("payments").insert({
              appointment_id: bookingId,
              user_id: paymentIntent.metadata?.user_id ?? null,
              stripe_payment_id: paymentIntent.id,
              amount: paymentIntent.amount / 100,
              currency: paymentIntent.currency,
              payment_method: paymentIntent.payment_method_types?.[0] ?? "card",
              status: "completed",
              created_at: new Date().toISOString(),
            });
          }

          // Record tax withholding in ledger
          if (hasTaxWithholding) {
            // Idempotency: skip if tax withholding already recorded for this appointment
            const { data: existingTax } = await supabase
              .from("tax_withholdings")
              .select("id")
              .eq("appointment_id", bookingId)
              .maybeSingle();

            if (existingTax) {
              console.log(`[STRIPE-WEBHOOK] Tax withholding already exists for booking ${bookingId}, skipping`);
            } else {
              const now = new Date();
              await supabase.from("tax_withholdings").insert({
                appointment_id: bookingId,
                business_id: paymentIntent.metadata.business_id,
                payment_intent_id: paymentIntent.id,
                payment_type: "stripe",
                jurisdiction: paymentIntent.metadata.tax_jurisdiction ?? "MX",
                gross_amount: parseFloat(paymentIntent.metadata.full_price ?? "0"),
                tax_base: parseFloat(paymentIntent.metadata.tax_base ?? "0"),
                iva_portion: parseFloat(paymentIntent.metadata.iva_portion ?? "0"),
                platform_fee: parseFloat(paymentIntent.metadata.platform_fee_amount ?? "0"),
                isr_rate: parseFloat(paymentIntent.metadata.isr_rate ?? "0"),
                iva_rate: parseFloat(paymentIntent.metadata.iva_rate ?? "0"),
                isr_withheld: parseFloat(paymentIntent.metadata.isr_withheld ?? "0"),
                iva_withheld: parseFloat(paymentIntent.metadata.iva_withheld ?? "0"),
                provider_net: parseFloat(paymentIntent.metadata.provider_net ?? "0"),
                provider_rfc: paymentIntent.metadata.provider_rfc || null,
                provider_tax_residency: paymentIntent.metadata.provider_tax_residency ?? "MX",
                period_year: now.getFullYear(),
                period_month: now.getMonth() + 1,
              });
              console.log(`[STRIPE-WEBHOOK] Tax withholding recorded for booking ${bookingId}`);
            }
          }

          // --- Record commission + debt collection ---
          const businessId = paymentIntent.metadata?.business_id;
          if (businessId) {
            const grossAmount = paymentIntent.amount / 100;
            const commission = (paymentIntent.application_fee_amount ?? 0) / 100;
            const ivaWithheld = parseFloat(paymentIntent.metadata?.iva_withheld ?? "0");
            const isrWithheld = parseFloat(paymentIntent.metadata?.isr_withheld ?? "0");
            const isProduct = paymentIntent.metadata?.type === "product";

            // Record commission for EVERY payment (3% services, 10% products)
            // Uses upsert with onConflict to prevent duplicate commission records
            try {
              if (commission > 0) {
                const commSource = isProduct ? "product_sale" : "appointment";
                const { error: commError } = await supabase.from("commission_records").upsert({
                  business_id: businessId,
                  appointment_id: isProduct ? null : bookingId,
                  order_id: isProduct ? bookingId : null,
                  amount: commission,
                  rate: isProduct ? 0.10 : 0.03,
                  source: commSource,
                  period_month: new Date().getMonth() + 1,
                  period_year: new Date().getFullYear(),
                  status: "collected",
                }, { onConflict: "appointment_id,source" });
                if (commError) {
                  console.error(`[STRIPE-WEBHOOK] Commission upsert error:`, commError);
                } else {
                  console.log(`[STRIPE-WEBHOOK] Commission recorded: $${commission} (${isProduct ? "product 10%" : "service 3%"}) for ${businessId}`);
                }
              }
            } catch (commErr) {
              console.error(`[STRIPE-WEBHOOK] Commission record error (non-fatal):`, commErr);
            }

            // Debt collection: deduct up to 50% of service fee if salon has debt
            try {

              const { data: debtResult } = await supabase.rpc("calculate_payout_with_debt", {
                p_business_id: businessId,
                p_gross_amount: grossAmount,
                p_commission: commission,
                p_iva_withheld: ivaWithheld,
                p_isr_withheld: isrWithheld,
              });

              if (debtResult && debtResult.length > 0 && debtResult[0].debt_collected > 0) {
                const collected = debtResult[0].debt_collected;
                const remaining = debtResult[0].remaining_debt;
                console.log(`[STRIPE-WEBHOOK] Debt collected: $${collected} from ${businessId}. Remaining: $${remaining}`);

                // Log the debt payment
                await supabase.from("debt_payments").insert({
                  debt_id: null, // FIFO already applied in the RPC
                  business_id: businessId,
                  appointment_id: bookingId,
                  amount_deducted: collected,
                  payout_amount: debtResult[0].salon_payout,
                  original_payout: grossAmount - commission - ivaWithheld - isrWithheld,
                });

                // Record commission for the collected debt amount
                await supabase.from("commission_records").insert({
                  business_id: businessId,
                  appointment_id: bookingId,
                  amount: collected,
                  rate: 0,
                  source: "debt_collection",
                  period_month: new Date().getMonth() + 1,
                  period_year: new Date().getFullYear(),
                  status: "collected",
                });
              }
            } catch (debtErr) {
              // Distinguish payout-hold from unexpected errors.
              const msg = debtErr instanceof Error ? debtErr.message : String(debtErr);
              if (msg.includes("PAYOUT_HOLD_ACTIVE")) {
                console.warn(`[STRIPE-WEBHOOK] Skipped debt collection — business ${businessId} on payout hold`);
                await supabase.from("audit_log").insert({
                  admin_id: "00000000-0000-0000-0000-000000000000",
                  action: "payout_hold_blocked_debt_collection",
                  target_type: "business",
                  target_id: businessId,
                  details: {
                    booking_id: bookingId,
                    gross_amount: grossAmount,
                    commission: commission,
                    iva_withheld: ivaWithheld,
                    isr_withheld: isrWithheld,
                    note: "Debt collection skipped due to active payout hold. Stripe destination transfer may have still occurred if PaymentIntent was created before hold was opened.",
                  },
                });
              } else {
                console.error(`[STRIPE-WEBHOOK] Debt collection error (non-fatal):`, debtErr);
              }
            }
          }

          // Send emails (non-blocking — don't fail the webhook)
          await sendBookingEmails(supabase, bookingId, paymentIntent);

          // Stamp CFDI (non-blocking — fire and forget)
          supabase.functions.invoke("cfdi-stamp", {
            body: { appointment_id: bookingId },
          }).catch((err: unknown) => {
            console.error(`[STRIPE-WEBHOOK] CFDI stamp failed (non-fatal):`, err);
          });
        }
        break;
      }

      case "payment_intent.payment_failed": {
        const paymentIntent = event.data.object as Stripe.PaymentIntent;
        const bookingId = paymentIntent.metadata?.booking_id;

        if (!bookingId) break;

        console.log(`[STRIPE-WEBHOOK] Payment failed for booking ${bookingId}`);

        await supabase
          .from("appointments")
          .update({
            status: "cancelled_customer",
            payment_status: "failed",
            updated_at: new Date().toISOString(),
          })
          .eq("id", bookingId);
        break;
      }

      // =======================================================================
      // OXXO Expiration — Cancel pending bookings when payment expires
      // =======================================================================
      case "payment_intent.canceled": {
        const paymentIntent = event.data.object as Stripe.PaymentIntent;
        const bookingId = paymentIntent.metadata?.booking_id;

        if (!bookingId) {
          console.log(`[STRIPE-WEBHOOK] payment_intent.canceled without booking_id`);
          break;
        }

        console.log(`[STRIPE-WEBHOOK] Payment canceled (expired) for booking ${bookingId}`);

        // Only cancel if the booking is still pending — don't touch confirmed/completed
        const { data: appt } = await supabase
          .from("appointments")
          .select("id, status, payment_status")
          .eq("id", bookingId)
          .maybeSingle();

        if (!appt) {
          console.log(`[STRIPE-WEBHOOK] Booking ${bookingId} not found, skipping`);
          break;
        }

        if (appt.status !== "pending" && appt.payment_status !== "pending") {
          console.log(`[STRIPE-WEBHOOK] Booking ${bookingId} is ${appt.status}/${appt.payment_status}, not pending — skipping`);
          break;
        }

        const { error: cancelError } = await supabase
          .from("appointments")
          .update({
            status: "cancelled_customer",
            payment_status: "expired",
            updated_at: new Date().toISOString(),
          })
          .eq("id", bookingId)
          .eq("status", "pending");

        if (cancelError) {
          console.error(`[STRIPE-WEBHOOK] Failed to cancel expired booking ${bookingId}: ${cancelError.message}`);
        } else {
          console.log(`[STRIPE-WEBHOOK] Booking ${bookingId} cancelled due to expired OXXO payment`);
        }
        break;
      }

      // =======================================================================
      // Checkout Sessions - For complete booking + payment flow
      // =======================================================================
      case "checkout.session.completed": {
        const session = event.data.object as Stripe.Checkout.Session;
        const bookingId = session.metadata?.booking_id;

        if (!bookingId) {
          console.log(`[STRIPE-WEBHOOK] checkout.session.completed without booking_id`);
          break;
        }

        console.log(`[STRIPE-WEBHOOK] Checkout completed for booking ${bookingId}`);

        await supabase
          .from("appointments")
          .update({
            payment_status: "paid",
            stripe_checkout_session_id: session.id,
            paid_at: new Date().toISOString(),
            status: "confirmed",
            confirmed_at: new Date().toISOString(),
            updated_at: new Date().toISOString(),
          })
          .eq("id", bookingId);

        // Record payment (checkout sessions use payment_intent under the hood)
        const sessionPI = session.payment_intent as string | null;
        if (sessionPI) {
          const { data: existingPay } = await supabase
            .from("payments")
            .select("id")
            .eq("stripe_payment_id", sessionPI)
            .maybeSingle();

          if (!existingPay) {
            await supabase.from("payments").insert({
              appointment_id: bookingId,
              user_id: session.metadata?.user_id ?? null,
              stripe_payment_id: sessionPI,
              amount: (session.amount_total ?? 0) / 100,
              currency: session.currency ?? "mxn",
              payment_method: "card",
              status: "completed",
              created_at: new Date().toISOString(),
            });
          }
        }

        // Send emails + CFDI (non-blocking)
        sendBookingEmails(supabase, bookingId, null as any).catch(() => {});
        supabase.functions.invoke("cfdi-stamp", {
          body: { appointment_id: bookingId },
        }).catch(() => {});

        break;
      }

      // =======================================================================
      // Refunds (external: chargebacks or manual Stripe dashboard refunds)
      // =======================================================================
      // Under our architecture, we NEVER call stripe.refunds.create().
      // This event only fires on chargebacks or manual Stripe dashboard actions.
      // Buyer already got card refund from Stripe — do NOT credit saldo (double refund).
      // Create seller debt + reverse tax withholdings only.
      // =======================================================================
      case "charge.refunded": {
        const charge = event.data.object as Stripe.Charge;
        const paymentIntentId = charge.payment_intent as string;

        if (!paymentIntentId) break;

        const refundAmount = (charge.amount_refunded ?? 0) / 100;
        console.log(`[STRIPE-WEBHOOK] External refund $${refundAmount} for PI ${paymentIntentId}`);

        // Try appointment first
        const { data: booking } = await supabase
          .from("appointments")
          .select("id, user_id, business_id, price, payment_status")
          .eq("payment_intent_id", paymentIntentId)
          .maybeSingle();

        if (booking) {
          if (booking.payment_status === "refunded_to_saldo" || booking.payment_status === "refunded") {
            console.log(`[STRIPE-WEBHOOK] Booking ${booking.id} already refunded, skipping`);
            break;
          }

          // Mark appointment as refunded
          await supabase.from("appointments").update({
            payment_status: "refunded",
            refund_amount: refundAmount,
            refunded_at: new Date().toISOString(),
            updated_at: new Date().toISOString(),
          }).eq("id", booking.id);

          // Create seller debt (buyer already got card refund from Stripe)
          if (refundAmount > 0 && booking.business_id) {
            await supabase.from("salon_debts").insert({
              business_id: booking.business_id,
              original_amount: refundAmount,
              remaining_amount: refundAmount,
              reason: "chargeback/external refund",
              source: "chargeback",
              appointment_id: booking.id,
            }).then(null, (e: Error) =>
              console.error(`[STRIPE-WEBHOOK] Debt creation failed: ${e.message}`)
            );
          }

          // Reverse tax withholdings
          await supabase.rpc("reverse_tax_withholding", {
            p_appointment_id: booking.id,
            p_reason: "chargeback",
          }).then(null, (e: Error) =>
            console.error(`[STRIPE-WEBHOOK] Tax reversal failed: ${e.message}`)
          );

          // Reverse BC's commission. On a chargeback Stripe reverses the
          // ENTIRE charge including application_fee_amount — BC actually
          // loses the commission too, but the original commission_records
          // row still claims it as collected. Insert an offsetting entry so
          // ledgers match reality. Unique(appointment_id, source) makes this
          // safe to retry (the dedup table also catches retries).
          if (booking.business_id) {
            const { data: origCommission } = await supabase
              .from("commission_records")
              .select("amount, rate")
              .eq("appointment_id", booking.id)
              .eq("source", "appointment")
              .maybeSingle();
            if (origCommission && Number(origCommission.amount) > 0) {
              await supabase.from("commission_records").insert({
                business_id: booking.business_id,
                appointment_id: booking.id,
                amount: -Number(origCommission.amount),
                rate: origCommission.rate,
                source: "chargeback_reversal",
                period_month: new Date().getMonth() + 1,
                period_year: new Date().getFullYear(),
                status: "collected",
              }).then(null, (e: Error) =>
                console.error(`[STRIPE-WEBHOOK] Commission reversal failed: ${e.message}`)
              );
            }
          }

          // Record in payments table
          const { data: existingRefund } = await supabase
            .from("payments")
            .select("id")
            .eq("stripe_payment_intent_id", paymentIntentId)
            .eq("status", "refunded")
            .maybeSingle();

          if (!existingRefund) {
            await supabase.from("payments").insert({
              appointment_id: booking.id,
              user_id: booking.user_id,
              stripe_payment_id: paymentIntentId,
              amount: -refundAmount,
              currency: charge.currency,
              payment_method: "card",
              status: "refunded",
              created_at: new Date().toISOString(),
            });
          }
        }

        // Product order fallback
        if (!booking) {
          const { data: order } = await supabase
            .from("orders")
            .select("id, buyer_id, business_id, product_name, status, total_amount")
            .eq("stripe_payment_intent_id", paymentIntentId)
            .maybeSingle();

          if (order && order.status !== "refunded") {
            await supabase.from("orders").update({
              status: "refunded",
              refunded_at: new Date().toISOString(),
            }).eq("id", order.id);

            // Create seller debt
            if (refundAmount > 0 && order.business_id) {
              await supabase.from("salon_debts").insert({
                business_id: order.business_id,
                original_amount: refundAmount,
                remaining_amount: refundAmount,
                reason: "chargeback/external refund",
                source: "chargeback",
                order_id: order.id,
              }).then(null, (e: Error) =>
                console.error(`[STRIPE-WEBHOOK] Order debt creation failed: ${e.message}`)
              );
            }

            // Reverse BC's product commission (parity with appointment branch above).
            // Stripe reverses the application_fee on chargeback — record the offset
            // so commission_records reflects reality.
            if (order.business_id) {
              const { data: origProductCommission } = await supabase
                .from("commission_records")
                .select("amount, rate")
                .eq("order_id", order.id)
                .eq("source", "product_sale")
                .maybeSingle();
              if (origProductCommission && Number(origProductCommission.amount) > 0) {
                await supabase.from("commission_records").insert({
                  business_id: order.business_id,
                  order_id: order.id,
                  amount: -Number(origProductCommission.amount),
                  rate: origProductCommission.rate,
                  source: "chargeback_reversal",
                  period_month: new Date().getMonth() + 1,
                  period_year: new Date().getFullYear(),
                  status: "collected",
                }).then(null, (e: Error) =>
                  console.error(`[STRIPE-WEBHOOK] Order commission reversal failed: ${e.message}`)
                );
              }
            }

            console.log(`[STRIPE-WEBHOOK] Product order ${order.id} refunded externally, debt created`);

            // Notify buyer + seller (parity with order-followup auto-refund notifications)
            const shortId = order.id.slice(0, 8).toUpperCase();
            const productName = order.product_name ?? "producto";
            try {
              await fetch(`${Deno.env.get("SUPABASE_URL")}/functions/v1/send-push-notification`, {
                method: "POST",
                headers: {
                  Authorization: `Bearer ${Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")}`,
                  "Content-Type": "application/json",
                },
                body: JSON.stringify({
                  user_id: order.buyer_id,
                  notification_type: "new_booking",
                  custom_title: "Pedido reembolsado",
                  custom_body: `Tu pedido de ${productName} fue reembolsado. El monto regresara a tu tarjeta.`,
                  data: { type: "order_refunded_external", order_id: order.id },
                }),
              });
            } catch (e) {
              console.error(`[STRIPE-WEBHOOK] Buyer push failed: ${(e as Error).message}`);
            }

            const { data: biz } = await supabase
              .from("businesses")
              .select("owner_id")
              .eq("id", order.business_id)
              .maybeSingle();
            if (biz?.owner_id) {
              try {
                await fetch(`${Deno.env.get("SUPABASE_URL")}/functions/v1/send-push-notification`, {
                  method: "POST",
                  headers: {
                    Authorization: `Bearer ${Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")}`,
                    "Content-Type": "application/json",
                  },
                  body: JSON.stringify({
                    user_id: biz.owner_id,
                    notification_type: "new_booking",
                    custom_title: "Pedido reembolsado manualmente",
                    custom_body: `El pedido #${shortId} de ${productName} fue reembolsado externamente. Se registro adeudo por $${refundAmount}.`,
                    data: { type: "order_refunded_external", order_id: order.id },
                  }),
                });
              } catch (e) {
                console.error(`[STRIPE-WEBHOOK] Seller push failed: ${(e as Error).message}`);
              }
            }
          }
        }
        break;
      }

      default:
        console.log(`[STRIPE-WEBHOOK] Unhandled event type: ${event.type}`);
    }

    return new Response(JSON.stringify({ received: true }), {
      status: 200,
      headers: { ...corsHeaders(req, "stripe-signature"), "Content-Type": "application/json" },
    });

  } catch (err) {
    console.error("[STRIPE-WEBHOOK] Error:", err);
    return new Response(JSON.stringify({ error: "An internal error occurred" }), {
      status: 500,
      headers: { ...corsHeaders(req, "stripe-signature"), "Content-Type": "application/json" },
    });
  }
});

// ---------------------------------------------------------------------------
// Helper: Extract the account holder name Stripe has on file.
// For individual accounts: first_name + last_name.
// For company accounts: company.name.
// Returns null if neither is populated.
// ---------------------------------------------------------------------------
function extractStripeAccountName(account: Stripe.Account): string | null {
  if (account.business_type === "individual" && account.individual) {
    const first = account.individual.first_name ?? "";
    const last = account.individual.last_name ?? "";
    const combined = `${first} ${last}`.trim();
    return combined.length > 0 ? combined : null;
  }
  if (account.business_type === "company" && account.company) {
    const name = account.company.name ?? "";
    return name.trim().length > 0 ? name.trim() : null;
  }
  // Fallback: try both structures regardless of business_type
  const fallback =
    [account.individual?.first_name, account.individual?.last_name].filter(Boolean).join(" ") ||
    account.company?.name ||
    "";
  return fallback.trim().length > 0 ? fallback.trim() : null;
}

// ---------------------------------------------------------------------------
// Helper: Fuzzy name match. RFC-matching is exact; names need tolerance for
// legal suffixes, accent differences, word order.
// Returns true when normalized names are identical OR Levenshtein distance
// is ≤ 2 on strings of length ≥ 5.
// ---------------------------------------------------------------------------
function namesMatch(a: string, b: string): boolean {
  const normalize = (s: string) =>
    s
      .toUpperCase()
      .normalize("NFD")
      .replace(/[\u0300-\u036f]/g, "") // strip accents
      .replace(/\b(S\.A\.?|DE C\.V\.?|SA|CV|SRL|S DE RL)\b/g, "") // strip corporate suffixes
      .replace(/[^A-Z0-9 ]/g, " ")
      .split(/\s+/)
      .filter((w) => w.length > 0)
      .sort()
      .join(" ");

  const na = normalize(a);
  const nb = normalize(b);
  if (na === nb) return true;
  if (na.length < 5 || nb.length < 5) return false;

  // Levenshtein distance
  const m = na.length;
  const n = nb.length;
  if (Math.abs(m - n) > 2) return false;
  const dp: number[][] = Array.from({ length: m + 1 }, () => new Array(n + 1).fill(0));
  for (let i = 0; i <= m; i++) dp[i][0] = i;
  for (let j = 0; j <= n; j++) dp[0][j] = j;
  for (let i = 1; i <= m; i++) {
    for (let j = 1; j <= n; j++) {
      dp[i][j] = Math.min(
        dp[i - 1][j] + 1,
        dp[i][j - 1] + 1,
        dp[i - 1][j - 1] + (na[i - 1] === nb[j - 1] ? 0 : 1)
      );
    }
  }
  return dp[m][n] <= 2;
}

// ---------------------------------------------------------------------------
// Helper: Send email via send-email edge function
// ---------------------------------------------------------------------------
async function sendEmail(
  template: string,
  to: string,
  subject: string,
  variables: Record<string, string>
): Promise<void> {
  try {
    const resp = await fetch(`${SUPABASE_URL}/functions/v1/send-email`, {
      method: "POST",
      headers: {
        Authorization: `Bearer ${SUPABASE_SERVICE_ROLE_KEY}`,
        "Content-Type": "application/json",
      },
      body: JSON.stringify({ template, to, subject, variables }),
    });
    if (!resp.ok) {
      const err = await resp.text();
      console.error(`[EMAIL] Failed to send ${template} to ${to}: ${err}`);
    } else {
      console.log(`[EMAIL] Sent ${template} to ${to}`);
    }
  } catch (err) {
    console.error(`[EMAIL] Error sending ${template}:`, err);
  }
}

// ---------------------------------------------------------------------------
// Helper: Send welcome + booking receipt emails after payment
// ---------------------------------------------------------------------------
async function sendBookingEmails(
  supabase: ReturnType<typeof createClient>,
  bookingId: string,
  paymentIntent: Stripe.PaymentIntent
) {
  try {
    // Fetch booking details with related data
    const { data: booking } = await supabase
      .from("appointments")
      .select(`
        id, starts_at, ends_at, price, user_id, service_name,
        businesses(name),
        staff(display_name)
      `)
      .eq("id", bookingId)
      .single();

    if (!booking) {
      console.error(`[EMAIL] Booking ${bookingId} not found`);
      return;
    }

    // Get client email & name
    const { data: auth } = await supabase.auth.admin.getUserById(booking.user_id);
    const clientEmail = auth?.user?.email;
    if (!clientEmail) {
      console.log(`[EMAIL] No email for client ${booking.user_id}, skipping`);
      return;
    }

    const clientName = auth?.user?.user_metadata?.full_name
      || auth?.user?.user_metadata?.username
      || clientEmail.split("@")[0];

    // Check if this is the client's first completed booking → send welcome
    const { count } = await supabase
      .from("payments")
      .select("id", { count: "exact", head: true })
      .eq("status", "succeeded")
      .in("appointment_id",
        (await supabase
          .from("appointments")
          .select("id")
          .eq("client_id", booking.user_id)
        ).data?.map((a: { id: string }) => a.id) ?? []
      );

    if (count !== null && count <= 1) {
      await sendEmail("welcome", clientEmail, "Bienvenida a BeautyCita", {
        USER_NAME: clientName,
      });
    }

    // Send booking receipt
    const scheduledDate = new Date(booking.starts_at);
    const dateStr = scheduledDate.toLocaleDateString("es-MX", {
      weekday: "long", year: "numeric", month: "long", day: "numeric",
    });
    const timeStr = scheduledDate.toLocaleTimeString("es-MX", {
      hour: "2-digit", minute: "2-digit",
    });

    const amountMXN = (paymentIntent.amount / 100).toLocaleString("es-MX", {
      style: "currency", currency: "MXN",
    });

    // Determine payment method display name from actual payment method
    let paymentMethodDisplay = "Tarjeta";
    const pmType = paymentIntent.payment_method_types?.[0] ?? "";
    const metaPM = paymentIntent.metadata?.payment_method ?? "";
    if (metaPM === "saldo" || pmType === "saldo") {
      paymentMethodDisplay = "Saldo BeautyCita";
    } else if (metaPM === "oxxo" || pmType === "oxxo") {
      paymentMethodDisplay = "OXXO";
    } else if (metaPM === "card" || pmType === "card") {
      paymentMethodDisplay = "Tarjeta";
    }

    await sendEmail("booking-receipt", clientEmail, "Confirmacion de tu reserva - BeautyCita", {
      BOOKING_ID: bookingId.slice(0, 8).toUpperCase(),
      SALON_NAME: (booking.business as any)?.name ?? "Salon",
      SERVICE_NAME: (booking.service as any)?.name ?? "Servicio",
      STYLIST_NAME: (booking.staff as any)?.display_name ?? "Estilista asignado",
      BOOKING_DATE: dateStr,
      BOOKING_TIME: timeStr,
      DURATION: `${booking.duration_minutes ?? 45} min`,
      TOTAL_AMOUNT: amountMXN,
      PAYMENT_METHOD: paymentMethodDisplay,
    });
  } catch (err) {
    console.error("[EMAIL] Error in sendBookingEmails:", err);
  }
}

// ---------------------------------------------------------------------------
// Helper: Notify business owner when onboarding completes
// ---------------------------------------------------------------------------
async function notifyBusinessOnboarded(
  supabase: ReturnType<typeof createClient>,
  businessId: string,
  businessName: string
) {
  try {
    // Get business owner
    const { data: business } = await supabase
      .from("businesses")
      .select("owner_id")
      .eq("id", businessId)
      .single();

    if (!business?.owner_id) return;

    // Create notification
    await supabase.from("notifications").insert({
      user_id: business.owner_id,
      type: "onboarding_complete",
      title: "Onboarding completado",
      body: `${businessName} ya puede recibir pagos y reservas en BeautyCita.`,
      data: { business_id: businessId },
      created_at: new Date().toISOString(),
    });

    // Get FCM token and send push notification
    const { data: profile } = await supabase
      .from("profiles")
      .select("fcm_token")
      .eq("id", business.owner_id)
      .single();

    if (profile?.fcm_token) {
      await supabase.functions.invoke("send-push-notification", {
        body: {
          token: profile.fcm_token,
          title: "Onboarding completado",
          body: `${businessName} ya puede recibir pagos y reservas.`,
          data: { type: "onboarding_complete", business_id: businessId },
        },
      });
    }
  } catch (err) {
    console.error("[STRIPE-WEBHOOK] Failed to notify business owner:", err);
  }
}
