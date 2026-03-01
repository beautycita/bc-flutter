// =============================================================================
// booking-confirmation — Multi-channel booking receipt sender
// =============================================================================
// Called from Flutter after booking creation.
// Sends receipt via email (if has_email), WhatsApp (if phone exists),
// and always sends a push notification.
// =============================================================================

import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

const SUPABASE_URL = Deno.env.get("SUPABASE_URL") ?? "";
const SUPABASE_SERVICE_KEY = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY") ?? "";
const BEAUTYPI_WA_URL = Deno.env.get("BEAUTYPI_WA_URL") ?? "";
const BEAUTYPI_WA_TOKEN = Deno.env.get("BEAUTYPI_WA_TOKEN") ?? "";

const ALLOWED_ORIGIN = "https://beautycita.com";
const corsHeaders = {
  "Access-Control-Allow-Origin": ALLOWED_ORIGIN,
  "Access-Control-Allow-Headers":
    "authorization, x-client-info, apikey, content-type",
};

interface ConfirmationRequest {
  booking_id: string;
  has_email: boolean;
}

interface BookingDetails {
  id: string;
  user_id: string;
  business_id: string;
  service_name: string;
  starts_at: string;
  ends_at: string;
  price: number | null;
  status: string;
  businesses: {
    name: string;
    address: string | null;
  };
}

function json(body: unknown, status = 200) {
  return new Response(JSON.stringify(body), {
    status,
    headers: { ...corsHeaders, "Content-Type": "application/json" },
  });
}

function formatDateEs(isoDate: string): { date: string; time: string } {
  const d = new Date(isoDate);
  const date = d.toLocaleDateString("es-MX", {
    weekday: "short",
    day: "numeric",
    month: "short",
    year: "numeric",
  });
  const time = d.toLocaleTimeString("es-MX", {
    hour: "numeric",
    minute: "2-digit",
    hour12: true,
  });
  return { date, time };
}

async function sendWhatsAppReceipt(
  phone: string,
  message: string
): Promise<boolean> {
  try {
    const res = await fetch(`${BEAUTYPI_WA_URL}/api/wa/send`, {
      method: "POST",
      headers: {
        "Content-Type": "application/json",
        Authorization: `Bearer ${BEAUTYPI_WA_TOKEN}`,
      },
      body: JSON.stringify({ phone, message }),
    });

    if (!res.ok) {
      console.error(`[WA] Send failed for ${phone}: ${res.status}`);
      return false;
    }

    const data = await res.json();
    return data.sent === true;
  } catch (err) {
    console.error(`[WA] Error sending to ${phone}:`, err);
    return false;
  }
}

Deno.serve(async (req) => {
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders });
  }

  if (req.method !== "POST") {
    return json({ error: "Method not allowed" }, 405);
  }

  // ── Auth: require valid JWT or service-role key ──
  const authHeader = req.headers.get("authorization") ?? "";
  const token = authHeader.replace("Bearer ", "");
  if (!token) {
    return json({ error: "Authorization required" }, 401);
  }

  const supabase = createClient(SUPABASE_URL, SUPABASE_SERVICE_KEY);
  const isServiceRole = token === SUPABASE_SERVICE_KEY;
  let callerId: string | null = null;

  if (!isServiceRole) {
    const { data: { user }, error: authErr } = await supabase.auth.getUser(token);
    if (authErr || !user) {
      return json({ error: "Invalid token" }, 401);
    }
    callerId = user.id;
  }

  try {
    const body: ConfirmationRequest = await req.json();
    const { booking_id, has_email } = body;

    if (!booking_id) {
      return json({ error: "booking_id is required" }, 400);
    }

    // -----------------------------------------------------------------------
    // 1. Fetch booking details with business join
    // -----------------------------------------------------------------------
    const { data: booking, error: bookingErr } = await supabase
      .from("appointments")
      .select(`
        id,
        user_id,
        business_id,
        service_name,
        starts_at,
        ends_at,
        price,
        status,
        businesses!appointments_business_id_fkey (
          name,
          address
        )
      `)
      .eq("id", booking_id)
      .single();

    if (bookingErr || !booking) {
      console.error("[BOOKING-CONFIRM] Booking lookup failed:", bookingErr);
      return json({ error: "Booking not found" }, 404);
    }

    const appt = booking as unknown as BookingDetails;

    // Verify caller owns this booking (skip for service-role internal calls)
    if (callerId && appt.user_id !== callerId) {
      // Also allow business owner
      const { data: biz } = await supabase
        .from("businesses")
        .select("owner_id")
        .eq("id", appt.business_id)
        .single();
      if (!biz || biz.owner_id !== callerId) {
        return json({ error: "Not authorized for this booking" }, 403);
      }
    }
    const salonName = appt.businesses?.name ?? "Salon";
    const salonAddress = appt.businesses?.address ?? "";

    // -----------------------------------------------------------------------
    // 2. Fetch user profile (phone, fcm_token) and auth email
    // -----------------------------------------------------------------------
    const { data: profile } = await supabase
      .from("profiles")
      .select("phone, fcm_token, full_name")
      .eq("id", appt.user_id)
      .single();

    const userPhone = profile?.phone ?? null;
    const userName = profile?.full_name ?? "Cliente";

    // Get email from auth.users
    let userEmail: string | null = null;
    if (has_email) {
      const { data: authUser } = await supabase.auth.admin.getUserById(appt.user_id);
      userEmail = authUser?.user?.email ?? null;
    }

    // Format dates
    const { date: bookingDate, time: bookingTime } = formatDateEs(appt.starts_at);
    const bookingIdShort = appt.id.substring(0, 8).toUpperCase();
    const priceStr = appt.price != null ? appt.price.toFixed(2) : "0.00";

    const results: Record<string, string> = {};

    // -----------------------------------------------------------------------
    // 3. If has_email and email exists: send email receipt
    // -----------------------------------------------------------------------
    if (has_email && userEmail) {
      try {
        // Calculate duration from starts_at and ends_at
        const startMs = new Date(appt.starts_at).getTime();
        const endMs = new Date(appt.ends_at).getTime();
        const durationMin = Math.round((endMs - startMs) / (1000 * 60));
        const durationStr = durationMin >= 60
          ? `${Math.floor(durationMin / 60)}h ${durationMin % 60}min`
          : `${durationMin} min`;

        const emailRes = await fetch(`${SUPABASE_URL}/functions/v1/send-email`, {
          method: "POST",
          headers: {
            Authorization: `Bearer ${SUPABASE_SERVICE_KEY}`,
            "Content-Type": "application/json",
          },
          body: JSON.stringify({
            template: "booking-receipt",
            to: userEmail,
            subject: `Recibo de Reserva #${bookingIdShort} - ${salonName}`,
            variables: {
              USER_NAME: userName,
              BOOKING_ID: bookingIdShort,
              SALON_NAME: salonName,
              SERVICE_NAME: appt.service_name,
              STYLIST_NAME: "", // Not always available
              BOOKING_DATE: bookingDate,
              BOOKING_TIME: bookingTime,
              DURATION: durationStr,
              TOTAL_AMOUNT: `$${priceStr} MXN`,
              PAYMENT_METHOD: "tarjeta",
            },
          }),
        });

        if (emailRes.ok) {
          results.email = "sent";
          console.log(`[BOOKING-CONFIRM] Email sent to ${userEmail}`);
        } else {
          results.email = "failed";
          console.error(`[BOOKING-CONFIRM] Email failed: ${await emailRes.text()}`);
        }
      } catch (emailErr) {
        results.email = "error";
        console.error("[BOOKING-CONFIRM] Email error:", emailErr);
      }
    } else {
      results.email = "skipped";
    }

    // -----------------------------------------------------------------------
    // 4. If phone exists: try WhatsApp receipt via beautypi WA API
    // -----------------------------------------------------------------------
    if (userPhone) {
      const waMessage =
        `*BeautyCita - Recibo*\n` +
        `${appt.service_name} con ${salonName}\n` +
        `${bookingDate} ${bookingTime}\n` +
        `Total: $${priceStr} MXN\n` +
        `Confirmacion: #${bookingIdShort}`;

      const waSent = await sendWhatsAppReceipt(userPhone, waMessage);

      if (waSent) {
        results.whatsapp = "sent";
        console.log(`[BOOKING-CONFIRM] WhatsApp sent to ${userPhone}`);
      } else {
        // WhatsApp failed — don't try SMS in v1, just log and move on
        results.whatsapp = "failed";
        console.log(`[BOOKING-CONFIRM] WhatsApp failed for ${userPhone}, skipping (no SMS in v1)`);
      }
    } else {
      results.whatsapp = "skipped";
    }

    // -----------------------------------------------------------------------
    // 5. Always: send push notification with type booking_confirmed
    // -----------------------------------------------------------------------
    try {
      const pushRes = await fetch(`${SUPABASE_URL}/functions/v1/send-push-notification`, {
        method: "POST",
        headers: {
          Authorization: `Bearer ${SUPABASE_SERVICE_KEY}`,
          "Content-Type": "application/json",
        },
        body: JSON.stringify({
          booking_id: appt.id,
          notification_type: "booking_confirmed",
        }),
      });

      if (pushRes.ok) {
        results.push = "sent";
        console.log(`[BOOKING-CONFIRM] Push notification sent for booking ${appt.id}`);
      } else {
        results.push = "failed";
        console.error(`[BOOKING-CONFIRM] Push failed: ${await pushRes.text()}`);
      }
    } catch (pushErr) {
      results.push = "error";
      console.error("[BOOKING-CONFIRM] Push error:", pushErr);
    }

    console.log(`[BOOKING-CONFIRM] Booking ${bookingIdShort} — results:`, results);

    return json({
      success: true,
      booking_id,
      channels: results,
    });
  } catch (err) {
    console.error("[BOOKING-CONFIRM] Handler error:", (err as Error).message);
    return json({ error: "Internal server error" }, 500);
  }
});
