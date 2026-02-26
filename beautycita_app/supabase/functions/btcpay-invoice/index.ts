// =============================================================================
// btcpay-invoice — Create BTCPay invoice for Bitcoin payments
// =============================================================================
// Creates a BTCPay Server invoice for booking a service with Bitcoin.
// BC keeps the BTC, provider receives MXN via BTCPay's built-in conversion.
// =============================================================================

import { serve } from "https://deno.land/std@0.177.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
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
          onboarding_complete
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

    // Platform fee (3% of the charge amount)
    const platformFee = Math.round(chargeAmount * PLATFORM_FEE_PERCENT * 100) / 100;

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
          metadata: {
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
          },
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

    console.log(`[BTCPAY] Created invoice ${invoice.id}`);
    console.log(`  Amount: $${chargeAmount} MXN`);
    console.log(`  Platform fee: $${platformFee} MXN`);
    console.log(`  Provider receives: $${chargeAmount - platformFee} MXN (after conversion)`);

    return json({
      invoice_id: invoice.id,
      checkout_link: invoice.checkoutLink,
      amount: chargeAmount,
      deposit_amount: depositAmount,
      platform_fee: platformFee,
      provider_receives: chargeAmount - platformFee,
      currency: "MXN",
      expires_at: invoice.expirationTime,
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
    console.error("[BTCPAY] Error:", (err as Error).message);
    return json({ error: (err as Error).message }, 500);
  }
});

function json(body: unknown, status = 200) {
  return new Response(JSON.stringify(body), {
    status,
    headers: { ...corsHeaders, "Content-Type": "application/json" },
  });
}
