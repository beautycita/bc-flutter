// =============================================================================
// btcpay-invoice — Create BTCPay invoice for Bitcoin payments
// =============================================================================
// Creates a BTCPay Server invoice for booking a service with Bitcoin.
// BC keeps the BTC, provider receives MXN via BTCPay's built-in conversion.
// =============================================================================

import { serve } from "https://deno.land/std@0.177.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";
import { calculateWithholding, type TaxWithholding } from "../_shared/tax_mx.ts";
import { requireFeature } from "../_shared/check-toggle.ts";

const corsHeaders = {
  "Access-Control-Allow-Origin": "https://beautycita.com",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
  "Access-Control-Allow-Methods": "POST, OPTIONS",
};

const BTCPAY_URL = Deno.env.get("BTCPAY_URL") ?? "https://beautycita.com/btcpay";
const BTCPAY_STORE_ID = Deno.env.get("BTCPAY_STORE_ID") ?? "";
const BTCPAY_API_KEY = Deno.env.get("BTCPAY_API_KEY") ?? "";
const SUPABASE_URL = Deno.env.get("SUPABASE_URL") ?? "";
const SUPABASE_SERVICE_ROLE_KEY = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY") ?? "";

// BeautyCita platform fee: 3%
const PLATFORM_FEE_PERCENT = 0.03;

interface InvoiceRequest {
  service_id: string;
  staff_id?: string;
  scheduled_at: string;
  payment_type?: "full" | "deposit_only";
}

serve(async (req) => {
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders });
  }

  // Server-side toggle enforcement
  const blocked = await requireFeature("enable_btc_payments");
  if (blocked) return blocked;

  try {
    if (!BTCPAY_API_KEY || !BTCPAY_STORE_ID) {
      return json({ error: "BTCPay not configured" }, 500);
    }

    const supabase = createClient(SUPABASE_URL, SUPABASE_SERVICE_ROLE_KEY);

    // Auth check
    const authHeader = req.headers.get("authorization") ?? "";
    const token = authHeader.replace("Bearer ", "");
    const { data: { user }, error: authError } = await supabase.auth.getUser(token);

    if (authError || !user) {
      return json({ error: "Unauthorized" }, 401);
    }

    // Feature toggle check
    const { data: toggleData } = await supabase
      .from("app_config")
      .select("value")
      .eq("key", "enable_btc_payments")
      .single();
    if (toggleData?.value !== "true") {
      return json({ error: "This feature is currently disabled" }, 403);
    }

    const body: InvoiceRequest = await req.json();
    const { service_id, staff_id, scheduled_at, payment_type = "full" } = body;

    if (!service_id || !scheduled_at) {
      return json({ error: "service_id and scheduled_at are required" }, 400);
    }

    // Fetch service with business info
    const { data: service, error: serviceError } = await supabase
      .from("services")
      .select(`
        id,
        name,
        price,
        duration_minutes,
        deposit_required,
        deposit_percentage,
        business_id,
        businesses!inner (
          id,
          name,
          onboarding_complete,
          rfc,
          tax_residency
        )
      `)
      .eq("id", service_id)
      .eq("is_active", true)
      .single();

    if (serviceError || !service) {
      return json({ error: "Service not found" }, 404);
    }

    const business = service.businesses as {
      id: string;
      name: string;
      onboarding_complete: boolean;
      rfc: string | null;
      tax_residency: string;
    };

    // Verify business is fully onboarded
    if (!business.onboarding_complete) {
      return json({ error: "This business is not yet accepting online payments" }, 400);
    }

    // Calculate amounts
    const servicePrice = service.price ?? 0;

    if (servicePrice <= 0) {
      return json({ error: "Service price is not configured" }, 400);
    }

    let chargeAmount: number;
    let depositAmount = 0;

    if (service.deposit_required) {
      depositAmount = Math.round(servicePrice * (service.deposit_percentage / 100) * 100) / 100;
      chargeAmount = payment_type === "deposit_only" ? depositAmount : servicePrice;
    } else {
      chargeAmount = servicePrice;
    }

    // Check if tax withholding is enabled
    const { data: taxFlag } = await supabase
      .from("app_config")
      .select("value")
      .eq("key", "tax_withholding_enabled")
      .single();
    const taxWithholdingEnabled = taxFlag?.value === "true";

    // Calculate withholdings (or just platform fee)
    let taxInfo: TaxWithholding | null = null;
    let platformFee: number;

    if (taxWithholdingEnabled) {
      taxInfo = calculateWithholding(
        chargeAmount,
        PLATFORM_FEE_PERCENT,
        business.rfc,
        business.tax_residency ?? "MX",
      );
      platformFee = taxInfo.platformFee;
    } else {
      platformFee = Math.round(chargeAmount * PLATFORM_FEE_PERCENT * 100) / 100;
    }

    // Build invoice metadata
    const invoiceMetadata: Record<string, string> = {
      orderId: `bc-${Date.now()}`,
      service_id,
      service_name: service.name,
      business_id: business.id,
      business_name: business.name,
      staff_id: staff_id ?? "",
      scheduled_at,
      user_id: user.id,
      payment_type,
      platform_fee: platformFee.toString(),
      deposit_amount: depositAmount.toString(),
      full_price: servicePrice.toString(),
    };

    if (taxInfo) {
      invoiceMetadata.tax_withholding = "true";
      invoiceMetadata.tax_base = taxInfo.taxBase.toString();
      invoiceMetadata.iva_portion = taxInfo.ivaPortion.toString();
      invoiceMetadata.isr_rate = taxInfo.isrRate.toString();
      invoiceMetadata.iva_rate = taxInfo.ivaRate.toString();
      invoiceMetadata.isr_withheld = taxInfo.isrWithheld.toString();
      invoiceMetadata.iva_withheld = taxInfo.ivaWithheld.toString();
      invoiceMetadata.provider_net = taxInfo.providerNet.toString();
      invoiceMetadata.provider_rfc = business.rfc ?? "";
      invoiceMetadata.provider_tax_residency = business.tax_residency ?? "MX";
    }

    // Create BTCPay invoice
    const invoiceResponse = await fetch(
      `${BTCPAY_URL}/api/v1/stores/${BTCPAY_STORE_ID}/invoices`,
      {
        method: "POST",
        headers: {
          "Authorization": `token ${BTCPAY_API_KEY}`,
          "Content-Type": "application/json",
        },
        body: JSON.stringify({
          amount: chargeAmount,
          currency: "MXN",
          metadata: invoiceMetadata,
          checkout: {
            speedPolicy: "MediumSpeed",
            expirationMinutes: 30,
            monitoringMinutes: 60,
            paymentTolerance: 0,
            redirectURL: "beautycita://payment-success",
            redirectAutomatically: true,
            defaultLanguage: "es",
          },
          receipt: {
            enabled: true,
            showQR: true,
            showPayments: true,
          },
        }),
      }
    );

    if (!invoiceResponse.ok) {
      const errorData = await invoiceResponse.json().catch(() => ({}));
      console.error("[BTCPAY] Invoice creation failed:", errorData);
      return json({ error: "Failed to create Bitcoin invoice" }, 500);
    }

    const invoice = await invoiceResponse.json();
    const providerReceives = taxInfo ? taxInfo.providerNet : chargeAmount - platformFee;

    console.log(`[BTCPAY] Created invoice ${invoice.id}`);
    console.log(`  Amount: $${chargeAmount} MXN`);
    console.log(`  Platform fee: $${platformFee} MXN`);
    if (taxInfo) {
      console.log(`  ISR withheld: $${taxInfo.isrWithheld} MXN (${taxInfo.isrRate * 100}%)`);
      console.log(`  IVA withheld: $${taxInfo.ivaWithheld} MXN (${taxInfo.ivaRate * 100}%)`);
    }
    console.log(`  Provider receives: $${providerReceives} MXN (after conversion)`);

    return json({
      invoice_id: invoice.id,
      checkout_link: invoice.checkoutLink,
      amount: chargeAmount,
      deposit_amount: depositAmount,
      platform_fee: platformFee,
      provider_receives: providerReceives,
      currency: "MXN",
      expires_at: invoice.expirationTime,
      ...(taxInfo ? {
        tax_withholding: {
          tax_base: taxInfo.taxBase,
          iva_portion: taxInfo.ivaPortion,
          isr_rate: taxInfo.isrRate,
          iva_rate: taxInfo.ivaRate,
          isr_withheld: taxInfo.isrWithheld,
          iva_withheld: taxInfo.ivaWithheld,
        },
      } : {}),
      service: {
        id: service.id,
        name: service.name,
        full_price: servicePrice,
        duration_minutes: service.duration_minutes,
        deposit_required: service.deposit_required,
        deposit_percentage: service.deposit_percentage,
      },
      business: {
        id: business.id,
        name: business.name,
      },
    });

  } catch (err) {
    console.error("[BTCPAY] Error:", err);
    return json({ error: "An internal error occurred" }, 500);
  }
});

function json(body: unknown, status = 200) {
  return new Response(JSON.stringify(body), {
    status,
    headers: { ...corsHeaders, "Content-Type": "application/json" },
  });
}
