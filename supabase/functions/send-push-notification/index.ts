/**
 * Send Push Notification Edge Function
 * Sends FCM push notifications for booking events
 *
 * Called by database triggers or other edge functions when:
 * - A new booking is created (notify provider)
 * - A booking is confirmed (notify client)
 * - A booking is cancelled (notify affected party)
 * - A reminder is due (notify client)
 */

import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

const SUPABASE_URL = Deno.env.get("SUPABASE_URL")!;
const SUPABASE_SERVICE_KEY = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!;
const FCM_SERVER_KEY = Deno.env.get("FCM_SERVER_KEY")!;

const supabase = createClient(SUPABASE_URL, SUPABASE_SERVICE_KEY);

interface PushRequest {
  booking_id?: string;
  user_id?: string;
  business_id?: string;
  notification_type: "new_booking" | "booking_confirmed" | "booking_cancelled" | "booking_reminder";
  custom_title?: string;
  custom_body?: string;
  data?: Record<string, string>;
}

interface NotificationContent {
  title: string;
  body: string;
  data: Record<string, string>;
}

const NOTIFICATION_TEMPLATES: Record<string, (ctx: any) => NotificationContent> = {
  new_booking: (ctx) => ({
    title: "Nueva Reserva",
    body: `${ctx.client_name} reservó ${ctx.service_name} para ${ctx.formatted_time}`,
    data: {
      route: "/provider/bookings",
      booking_id: ctx.booking_id,
      type: "new_booking",
    },
  }),
  booking_confirmed: (ctx) => ({
    title: "Reserva Confirmada",
    body: `Tu cita en ${ctx.business_name} ha sido confirmada para ${ctx.formatted_time}`,
    data: {
      route: "/bookings",
      booking_id: ctx.booking_id,
      type: "booking_confirmed",
    },
  }),
  booking_cancelled: (ctx) => ({
    title: "Reserva Cancelada",
    body: ctx.is_provider
      ? `${ctx.client_name} canceló su cita de ${ctx.service_name}`
      : `Tu cita en ${ctx.business_name} ha sido cancelada`,
    data: {
      route: ctx.is_provider ? "/provider/bookings" : "/bookings",
      booking_id: ctx.booking_id,
      type: "booking_cancelled",
    },
  }),
  booking_reminder: (ctx) => ({
    title: "Recordatorio de Cita",
    body: `Tu cita en ${ctx.business_name} es ${ctx.time_until}`,
    data: {
      route: "/bookings",
      booking_id: ctx.booking_id,
      type: "booking_reminder",
    },
  }),
};

async function sendFcmNotification(
  fcmToken: string,
  notification: NotificationContent
): Promise<boolean> {
  try {
    const response = await fetch("https://fcm.googleapis.com/fcm/send", {
      method: "POST",
      headers: {
        "Content-Type": "application/json",
        Authorization: `key=${FCM_SERVER_KEY}`,
      },
      body: JSON.stringify({
        to: fcmToken,
        notification: {
          title: notification.title,
          body: notification.body,
          sound: "default",
          badge: "1",
        },
        data: notification.data,
        priority: "high",
        content_available: true,
      }),
    });

    if (!response.ok) {
      console.error("[FCM] Send failed:", await response.text());
      return false;
    }

    const result = await response.json();
    console.log("[FCM] Send result:", result);
    return result.success === 1;
  } catch (error) {
    console.error("[FCM] Error:", error);
    return false;
  }
}

async function getBookingContext(bookingId: string): Promise<any> {
  const { data: booking, error } = await supabase
    .from("bookings")
    .select(`
      id,
      start_time,
      status,
      client:profiles!bookings_client_id_fkey(id, full_name, fcm_token),
      business:businesses!bookings_business_id_fkey(id, name, fcm_token),
      service:services!bookings_service_id_fkey(name)
    `)
    .eq("id", bookingId)
    .single();

  if (error || !booking) {
    console.error("[FCM] Booking lookup failed:", error);
    return null;
  }

  const startTime = new Date(booking.start_time);
  const formattedTime = startTime.toLocaleString("es-MX", {
    weekday: "short",
    month: "short",
    day: "numeric",
    hour: "numeric",
    minute: "2-digit",
  });

  return {
    booking_id: booking.id,
    client_id: booking.client?.id,
    client_name: booking.client?.full_name || "Cliente",
    client_fcm_token: booking.client?.fcm_token,
    business_id: booking.business?.id,
    business_name: booking.business?.name || "Salón",
    business_fcm_token: booking.business?.fcm_token,
    service_name: booking.service?.name || "servicio",
    formatted_time: formattedTime,
    start_time: startTime,
  };
}

function getTimeUntil(date: Date): string {
  const now = new Date();
  const diffMs = date.getTime() - now.getTime();
  const diffHours = Math.round(diffMs / (1000 * 60 * 60));

  if (diffHours <= 1) return "en menos de 1 hora";
  if (diffHours < 24) return `en ${diffHours} horas`;
  const diffDays = Math.round(diffHours / 24);
  return diffDays === 1 ? "mañana" : `en ${diffDays} días`;
}

Deno.serve(async (req) => {
  // CORS preflight
  if (req.method === "OPTIONS") {
    return new Response(null, {
      headers: {
        "Access-Control-Allow-Origin": "*",
        "Access-Control-Allow-Methods": "POST, OPTIONS",
        "Access-Control-Allow-Headers": "Content-Type, Authorization",
      },
    });
  }

  if (req.method !== "POST") {
    return new Response(JSON.stringify({ error: "Method not allowed" }), {
      status: 405,
      headers: { "Content-Type": "application/json" },
    });
  }

  try {
    const body: PushRequest = await req.json();
    const { booking_id, user_id, business_id, notification_type, custom_title, custom_body, data } = body;

    if (!notification_type) {
      return new Response(
        JSON.stringify({ error: "notification_type is required" }),
        { status: 400, headers: { "Content-Type": "application/json" } }
      );
    }

    let fcmToken: string | null = null;
    let notificationContent: NotificationContent;

    // Custom notification (direct to user or business)
    if (custom_title && custom_body) {
      // Get token for direct notification
      if (user_id) {
        const { data: profile } = await supabase
          .from("profiles")
          .select("fcm_token")
          .eq("id", user_id)
          .single();
        fcmToken = profile?.fcm_token;
      } else if (business_id) {
        const { data: business } = await supabase
          .from("businesses")
          .select("fcm_token")
          .eq("id", business_id)
          .single();
        fcmToken = business?.fcm_token;
      }

      notificationContent = {
        title: custom_title,
        body: custom_body,
        data: data || {},
      };
    }
    // Template-based notification (requires booking_id)
    else if (booking_id) {
      const ctx = await getBookingContext(booking_id);
      if (!ctx) {
        return new Response(
          JSON.stringify({ error: "Booking not found" }),
          { status: 404, headers: { "Content-Type": "application/json" } }
        );
      }

      // Determine recipient based on notification type
      switch (notification_type) {
        case "new_booking":
          fcmToken = ctx.business_fcm_token;
          break;
        case "booking_confirmed":
        case "booking_reminder":
          fcmToken = ctx.client_fcm_token;
          ctx.time_until = getTimeUntil(ctx.start_time);
          break;
        case "booking_cancelled":
          // Notify the other party (if client cancelled, notify business; vice versa)
          ctx.is_provider = !!business_id;
          fcmToken = ctx.is_provider ? ctx.business_fcm_token : ctx.client_fcm_token;
          break;
      }

      const template = NOTIFICATION_TEMPLATES[notification_type];
      if (!template) {
        return new Response(
          JSON.stringify({ error: "Unknown notification type" }),
          { status: 400, headers: { "Content-Type": "application/json" } }
        );
      }

      notificationContent = template(ctx);
    } else {
      return new Response(
        JSON.stringify({ error: "booking_id or custom content required" }),
        { status: 400, headers: { "Content-Type": "application/json" } }
      );
    }

    if (!fcmToken) {
      console.log("[FCM] No FCM token for recipient, skipping notification");
      return new Response(
        JSON.stringify({ success: false, reason: "no_fcm_token" }),
        { status: 200, headers: { "Content-Type": "application/json" } }
      );
    }

    const sent = await sendFcmNotification(fcmToken, notificationContent);

    return new Response(
      JSON.stringify({
        success: sent,
        notification_type,
        title: notificationContent.title,
      }),
      {
        status: 200,
        headers: {
          "Content-Type": "application/json",
          "Access-Control-Allow-Origin": "*",
        },
      }
    );
  } catch (error) {
    console.error("[FCM] Handler error:", error);
    return new Response(
      JSON.stringify({ error: "Internal server error" }),
      { status: 500, headers: { "Content-Type": "application/json" } }
    );
  }
});
