// =============================================================================
// Centralized Refund Processor — Saldo + Debt + Tax Reversal
// =============================================================================
// Policy: ALL refunds credit buyer saldo. NEVER refund to card.
// Seller gets debt. Tax withholdings are reversed.
// BC keeps 3% processing fee.
// =============================================================================

import { SupabaseClient } from "https://esm.sh/@supabase/supabase-js@2";

const DEFAULT_PROCESSING_FEE_RATE = 0.03;

export interface RefundParams {
  supabase: SupabaseClient;
  buyerId: string;
  businessId: string;
  grossAmount: number;
  appointmentId?: string;
  orderId?: string;
  /** Original order payment method. Non-Stripe methods (saldo/cash) skip commission reversal ledger. */
  paymentMethod?: string | null;
  reason: string;
  idempotencyKey: string;
  /**
   * Skip the 3% processing-fee deduction. Use when BC's commission was already
   * collected at original payment time (Stripe Connect application_fee) and the
   * caller is passing in the post-commission amount. Otherwise BC double-takes.
   * Default false (deduct fee — appropriate for product/dispute refunds).
   */
  skipProcessingFee?: boolean;
}

async function readProcessingFeeRate(supabase: SupabaseClient): Promise<number> {
  const { data } = await supabase
    .from("app_config")
    .select("value")
    .eq("key", "commission_keep_on_product_refund")
    .maybeSingle();
  const parsed = Number(data?.value);
  return Number.isFinite(parsed) && parsed >= 0 && parsed <= 1
    ? parsed
    : DEFAULT_PROCESSING_FEE_RATE;
}

export interface RefundResult {
  saldoCredit: number;
  debtCreated: number;
  processingFee: number;
  taxReversed: { isr: number; iva: number };
}

export async function processRefund(params: RefundParams): Promise<RefundResult> {
  const {
    supabase, buyerId, businessId, grossAmount,
    appointmentId, orderId, paymentMethod, reason, idempotencyKey,
    skipProcessingFee,
  } = params;

  const feeRate = skipProcessingFee ? 0 : await readProcessingFeeRate(supabase);
  const processingFee = Math.round(grossAmount * feeRate * 100) / 100;
  const saldoCredit = Math.round((grossAmount - processingFee) * 100) / 100;

  // 1. Credit buyer saldo
  const { error: saldoErr } = await supabase.rpc("increment_saldo", {
    p_user_id: buyerId,
    p_amount: saldoCredit,
    p_reason: reason,
    p_idempotency_key: idempotencyKey,
  });

  if (saldoErr) {
    throw new Error(`Saldo credit failed: ${saldoErr.message}`);
  }

  // 2. Create seller debt
  const { error: debtErr } = await supabase
    .from("salon_debts")
    .insert({
      business_id: businessId,
      original_amount: saldoCredit,
      remaining_amount: saldoCredit,
      reason,
      source: orderId ? "product_refund" : "booking_refund",
      appointment_id: appointmentId ?? null,
      order_id: orderId ?? null,
    });

  if (debtErr) {
    console.error(`[REFUND] Debt creation failed for ${businessId}: ${debtErr.message}`);
    // Non-fatal: buyer got their saldo, debt tracking is secondary
  }

  // 3. Reverse tax withholdings (appointments only — products don't have tax withholdings yet)
  let taxReversed = { isr: 0, iva: 0 };
  if (appointmentId) {
    // Look up original withholding
    const { data: original } = await supabase
      .from("tax_withholdings")
      .select("id, isr_withheld, iva_withheld")
      .eq("appointment_id", appointmentId)
      .eq("status", "recorded")
      .maybeSingle();

    if (original) {
      // Call the SQL helper to insert reversal + mark original as reversed
      const { error: taxErr } = await supabase.rpc("reverse_tax_withholding", {
        p_appointment_id: appointmentId,
        p_reason: reason,
      });

      if (taxErr) {
        console.error(`[REFUND] Tax reversal failed for appt ${appointmentId}: ${taxErr.message}`);
      } else {
        taxReversed = {
          isr: Number(original.isr_withheld) || 0,
          iva: Number(original.iva_withheld) || 0,
        };
        console.log(`[REFUND] Tax reversed: ISR $${taxReversed.isr}, IVA $${taxReversed.iva}`);
      }
    }
  }

  // 4. For product orders paid via Stripe: record commission reversal (keep 3%, return 7%).
  //    Saldo/cash orders never moved money through Stripe — no commission to reverse.
  const stripeFundedOrder = orderId && paymentMethod !== "saldo" &&
    paymentMethod !== "cash" && paymentMethod !== "cash_direct" &&
    paymentMethod !== "cash_walk_in";
  if (stripeFundedOrder) {
    const commissionReturn = Math.round((grossAmount * (0.10 - feeRate)) * 100) / 100;
    if (commissionReturn > 0) {
      await supabase.from("commission_records").insert({
        business_id: businessId,
        order_id: orderId,
        amount: -commissionReturn,
        rate: Math.round((0.10 - feeRate) * 10000) / 10000,
        source: "product_sale_reversal",
        period_month: new Date().getMonth() + 1,
        period_year: new Date().getFullYear(),
        status: "collected",
      }).then(null, (e: Error) =>
        console.error(`[REFUND] Commission reversal record failed: ${e.message}`)
      );
    }
  }

  console.log(
    `[REFUND] ${reason}: buyer ${buyerId} credited $${saldoCredit} saldo, ` +
    `seller ${businessId} debt $${saldoCredit}, BC fee $${processingFee}`
  );

  return { saldoCredit, debtCreated: saldoCredit, processingFee, taxReversed };
}
