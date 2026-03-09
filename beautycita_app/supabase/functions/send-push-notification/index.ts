/**
 * Send Push Notification Edge Function
 * Sends FCM push notifications for booking events
 *
 * Uses FCM v1 HTTP API (replaces deprecated legacy API).
 * Requires GOOGLE_SERVICE_ACCOUNT secret (JSON string) in Supabase.
 *
 * Called by other edge functions when:
 * - A new booking is created (notify provider)
 * - A booking is confirmed (notify client)
 * - A booking is cancelled (notify affected party)
 * - A reminder is due (notify client)
 */

import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

const SUPABASE_URL = Deno.env.get("SUPABASE_URL")!;
const SUPABASE_SERVICE_KEY = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!;

const supabase = createClient(SUPABASE_URL, SUPABASE_SERVICE_KEY);

// ── FCM v1 Auth via Service Account ──────────────────────────────────────

interface ServiceAccount {
  project_id: string;
  private_key: string;
  client_email: string;
}

let _cachedToken: { token: string; expires: number } | null = null;

/** Build a JWT signed with the service account key, exchange for OAuth2 token */
async function getFcmAccessToken(): Promise<string> {
  // Return cached token if still valid (with 60s buffer)
  if (_cachedToken && Date.now() < _cachedToken.expires - 60_000) {
    return _cachedToken.token;
  }

  const saJson = Deno.env.get("GOOGLE_SERVICE_ACCOUNT");
  if (!saJson) {
    throw new Error("GOOGLE_SERVICE_ACCOUNT secret not set");
  }

  const sa: ServiceAccount = JSON.parse(saJson);

  // Build JWT header + claims
  const header = { alg: "RS256", typ: "JWT" };
  const now = Math.floor(Date.now() / 1000);
  const claims = {
    iss: sa.client_email,
    scope: "https://www.googleapis.com/auth/firebase.messaging",
    aud: "https://oauth2.googleapis.com/token",
    iat: now,
    exp: now + 3600,
  };

  const enc = (obj: unknown) =>
    btoa(JSON.stringify(obj))
      .replace(/\+/g, "-")
      .replace(/\//g, "_")
      .replace(/=+$/, "");

  const unsignedToken = `${enc(header)}.${enc(claims)}`;

  // Import RSA private key and sign
  const pemBody = sa.private_key
    .replace(/-----BEGIN PRIVATE KEY-----/, "")
    .replace(/-----END PRIVATE KEY-----/, "")
    .replace(/\s/g, "");

  const keyData = Uint8Array.from(atob(pemBody), (c) => c.charCodeAt(0));
  const cryptoKey = await crypto.subtle.importKey(
    "pkcs8",
    keyData,
    { name: "RSASSA-PKCS1-v1_5", hash: "SHA-256" },
    false,
    ["sign"]
  );

  const signature = await crypto.subtle.sign(
    "RSASSA-PKCS1-v1_5",
    cryptoKey,
    new TextEncoder().encode(unsignedToken)
  );

  const sig = btoa(String.fromCharCode(...new Uint8Array(signature)))
    .replace(/\+/g, "-")
    .replace(/\//g, "_")
    .replace(/=+$/, "");

  const jwt = `${unsignedToken}.${sig}`;

  // Exchange JWT for access token
  const tokenRes = await fetch("https://oauth2.googleapis.com/token", {
    method: "POST",
    headers: { "Content-Type": "application/x-www-form-urlencoded" },
    body: `grant_type=urn:ietf:params:oauth:grant-type:jwt-bearer&assertion=${jwt}`,
  });

  if (!tokenRes.ok) {
    const err = await tokenRes.text();
    throw new Error(`OAuth2 token exchange failed: ${err}`);
  }

  const tokenData = await tokenRes.json();
  _cachedToken = {
    token: tokenData.access_token,
    expires: Date.now() + tokenData.expires_in * 1000,
  };

  return _cachedToken.token;
}

// ── Types ────────────────────────────────────────────────────────────────

interface PushRequest {
  booking_id?: string;
  user_id?: string;
  business_id?: string;
  notification_type:
    | "new_booking"
    | "booking_confirmed"
    | "booking_cancelled"
    | "booking_reminder";
  custom_title?: string;
  custom_body?: string;
  data?: Record<string, string>;
}

interface NotificationContent {
  title: string;
  body: string;
  data: Record<string, string>;
}

// ── Templates ────────────────────────────────────────────────────────────

const NOTIFICATION_TEMPLATES: Record<
  string,
  (ctx: any) => NotificationContent
> = {
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

// ── FCM v1 Send ──────────────────────────────────────────────────────────

async function sendFcmNotification(
  fcmToken: string,
  notification: NotificationContent
): Promise<boolean> {
  try {
    const accessToken = await getFcmAccessToken();

    const saJson = Deno.env.get("GOOGLE_SERVICE_ACCOUNT")!;
    const projectId = JSON.parse(saJson).project_id;

    const response = await fetch(
      `https://fcm.googleapis.com/v1/projects/${projectId}/messages:send`,
      {
        method: "POST",
        headers: {
          "Content-Type": "application/json",
          Authorization: `Bearer ${accessToken}`,
        },
        body: JSON.stringify({
          message: {
            token: fcmToken,
            notification: {
              title: notification.title,
              body: notification.body,
            },
            android: {
              priority: "HIGH",
              notification: {
                sound: "beautycita_notify",
                channel_id: "booking_alerts",
              },
            },
            apns: {
              payload: {
                aps: {
                  sound: "default",
                  badge: 1,
                },
              },
            },
            data: notification.data,
          },
        }),
      }
    );

    if (!response.ok) {
      const errText = await response.text();
      console.error("[FCM v1] Send failed:", response.status, errText);

      // If token is invalid/unregistered, clear it from DB
      if (errText.includes("UNREGISTERED") || errText.includes("INVALID_ARGUMENT")) {
        console.log("[FCM v1] Clearing stale token");
        await supabase
          .from("profiles")
          .update({ fcm_token: null })
          .eq("fcm_token", fcmToken);
      }

      return false;
    }

    const result = await response.json();
    console.log("[FCM v1] Sent:", result.name);
    return true;
  } catch (error) {
    console.error("[FCM v1] Error:", error);
    return false;
  }
}

// ── Context helpers ──────────────────────────────────────────────────────

async function getBookingContext(bookingId: string): Promise<any> {
  const { data: booking, error } = await supabase
    .from("appointments")
    .select(
      `
      id,
      starts_at,
      status,
      user_id,
      business_id,
      service_name,
      staff_name
    `
    )
    .eq("id", bookingId)
    .single();

  if (error || !booking) {
    console.error("[FCM] Appointment lookup failed:", error);
    return null;
  }

  const { data: profile } = await supabase
    .from("profiles")
    .select("id, full_name, fcm_token")
    .eq("id", booking.user_id)
    .single();

  const { data: business } = await supabase
    .from("businesses")
    .select("id, name, fcm_token")
    .eq("id", booking.business_id)
    .single();

  const startTime = new Date(booking.starts_at);
  const formattedTime = startTime.toLocaleString("es-MX", {
    weekday: "short",
    month: "short",
    day: "numeric",
    hour: "numeric",
    minute: "2-digit",
  });

  return {
    booking_id: booking.id,
    client_id: profile?.id,
    client_name: profile?.full_name || "Cliente",
    client_fcm_token: profile?.fcm_token,
    business_id: business?.id,
    business_name: business?.name || "Salón",
    business_fcm_token: business?.fcm_token,
    service_name: booking.service_name || "servicio",
    staff_name: booking.staff_name || "",
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

// ── HTTP Handler ─────────────────────────────────────────────────────────

const ALLOWED_ORIGIN = "https://beautycita.com";

const corsHeaders = {
  "Access-Control-Allow-Origin": ALLOWED_ORIGIN,
  "Access-Control-Allow-Methods": "POST, OPTIONS",
  "Access-Control-Allow-Headers":
    "Content-Type, Authorization, x-client-info, apikey",
};

Deno.serve(async (req) => {
  if (req.method === "OPTIONS") {
    return new Response(null, { headers: corsHeaders });
  }

  if (req.method !== "POST") {
    return new Response(JSON.stringify({ error: "Method not allowed" }), {
      status: 405,
      headers: { ...corsHeaders, "Content-Type": "application/json" },
    });
  }

  // ── Auth: require valid JWT or service-role key (for internal calls) ──
  const authHeader = req.headers.get("authorization") ?? "";
  const token = authHeader.replace("Bearer ", "");
  if (!token) {
    return new Response(JSON.stringify({ error: "Authorization required" }), {
      status: 401,
      headers: { ...corsHeaders, "Content-Type": "application/json" },
    });
  }

  const isServiceRole = token === SUPABASE_SERVICE_KEY;
  if (!isServiceRole) {
    const {
      data: { user },
      error: authErr,
    } = await supabase.auth.getUser(token);
    if (authErr || !user) {
      return new Response(JSON.stringify({ error: "Invalid token" }), {
        status: 401,
        headers: { ...corsHeaders, "Content-Type": "application/json" },
      });
    }
  }

  try {
    // Feature toggle check
    const { data: toggleData } = await supabase
      .from("app_config")
      .select("value")
      .eq("key", "enable_push_notifications")
      .single();
    if (toggleData?.value !== "true") {
      return new Response(JSON.stringify({ error: "This feature is currently disabled" }), {
        status: 403,
        headers: { ...corsHeaders, "Content-Type": "application/json" },
      });
    }

    const body: PushRequest = await req.json();
    const {
      booking_id,
      user_id,
      business_id,
      notification_type,
      custom_title,
      custom_body,
      data,
    } = body;

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
          ctx.is_provider = !!business_id;
          fcmToken = ctx.is_provider
            ? ctx.business_fcm_token
            : ctx.client_fcm_token;
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
        headers: { ...corsHeaders, "Content-Type": "application/json" },
      }
    );
  } catch (error) {
    console.error("[FCM] Handler error:", error);
    return new Response(
      JSON.stringify({ error: "Internal server error" }),
      {
        status: 500,
        headers: { ...corsHeaders, "Content-Type": "application/json" },
      }
    );
  }
});
