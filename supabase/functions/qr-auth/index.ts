import { serve } from "https://deno.land/std@0.177.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers":
    "authorization, x-client-info, apikey, content-type",
};

function json(data: unknown, status = 200) {
  return new Response(JSON.stringify(data), {
    status,
    headers: { ...corsHeaders, "Content-Type": "application/json" },
  });
}

function generateCode(length = 8): string {
  const chars = "ABCDEFGHJKLMNPQRSTUVWXYZabcdefghjkmnpqrstuvwxyz23456789";
  const arr = new Uint8Array(length);
  crypto.getRandomValues(arr);
  return Array.from(arr, (b) => chars[b % chars.length]).join("");
}

serve(async (req) => {
  if (req.method === "OPTIONS") {
    return new Response(null, { headers: corsHeaders });
  }

  try {
    const supabaseUrl = Deno.env.get("SUPABASE_URL") ?? "";
    const serviceRoleKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY") ?? "";
    const supabase = createClient(supabaseUrl, serviceRoleKey);

    const body = await req.json();
    const { action } = body;

    // ===== CREATE =====
    if (action === "create") {
      // Generate unique code (retry on collision)
      let code = "";
      for (let i = 0; i < 5; i++) {
        code = generateCode();
        const { data: existing } = await supabase
          .from("qr_auth_sessions")
          .select("id")
          .eq("code", code)
          .eq("status", "pending")
          .maybeSingle();
        if (!existing) break;
      }

      const { data, error } = await supabase
        .from("qr_auth_sessions")
        .insert({ code })
        .select("id, code")
        .single();

      if (error) throw error;

      return json({ session_id: data.id, code: data.code });
    }

    // ===== AUTHORIZE =====
    if (action === "authorize") {
      const { code } = body;
      if (!code) return json({ error: "code is required" }, 400);

      // Validate APK user's JWT
      const authHeader = req.headers.get("Authorization") ?? "";
      const token = authHeader.replace("Bearer ", "");
      if (!token) return json({ error: "Authorization required" }, 401);

      const {
        data: { user },
        error: authError,
      } = await supabase.auth.getUser(token);
      if (authError || !user) return json({ error: "Invalid token" }, 401);

      // Find pending session
      const { data: session, error: sessError } = await supabase
        .from("qr_auth_sessions")
        .select("id, status, expires_at")
        .eq("code", code)
        .eq("status", "pending")
        .gt("expires_at", new Date().toISOString())
        .maybeSingle();

      if (sessError) throw sessError;
      if (!session) return json({ error: "Code not found or expired" }, 404);

      // Ensure user has an email (anonymous users don't)
      let email = user.email;
      if (!email) {
        email = `${user.id}@qr.beautycita.app`;
        const { error: updateErr } =
          await supabase.auth.admin.updateUserById(user.id, {
            email,
            email_confirm: true,
          });
        if (updateErr) {
          console.error("Failed to assign email:", updateErr);
          return json({ error: "Failed to prepare auth" }, 500);
        }
      }

      // Generate magic link OTP
      const { data: linkData, error: linkError } =
        await supabase.auth.admin.generateLink({
          type: "magiclink",
          email,
        });

      if (linkError) {
        console.error("generateLink error:", linkError);
        return json({ error: "Failed to generate auth link" }, 500);
      }

      const emailOtp =
        linkData?.properties?.email_otp ?? "";

      if (!emailOtp) {
        console.error("No email_otp in generateLink response");
        return json({ error: "Auth generation failed" }, 500);
      }

      // Update session as authorized
      const { error: upError } = await supabase
        .from("qr_auth_sessions")
        .update({
          status: "authorized",
          user_id: user.id,
          email,
          email_otp: emailOtp,
          authorized_at: new Date().toISOString(),
        })
        .eq("id", session.id);

      if (upError) throw upError;

      return json({ success: true });
    }

    // ===== VERIFY =====
    if (action === "verify") {
      const { session_id } = body;
      if (!session_id) return json({ error: "session_id is required" }, 400);

      const { data: session, error: sessError } = await supabase
        .from("qr_auth_sessions")
        .select("id, status, email, email_otp, expires_at")
        .eq("id", session_id)
        .eq("status", "authorized")
        .maybeSingle();

      if (sessError) throw sessError;
      if (!session) return json({ error: "Session not authorized" }, 404);

      // Check expiry
      if (new Date(session.expires_at) < new Date()) {
        await supabase
          .from("qr_auth_sessions")
          .update({ status: "expired" })
          .eq("id", session.id);
        return json({ error: "Session expired" }, 410);
      }

      // Mark consumed
      await supabase
        .from("qr_auth_sessions")
        .update({
          status: "consumed",
          consumed_at: new Date().toISOString(),
        })
        .eq("id", session.id);

      return json({
        email: session.email,
        email_otp: session.email_otp,
      });
    }

    // ===== CLEANUP =====
    if (action === "cleanup") {
      await supabase.rpc("cleanup_expired_qr_sessions");
      return json({ success: true });
    }

    return json({ error: "Unknown action" }, 400);
  } catch (err) {
    console.error("qr-auth error:", err);
    return json({ error: err.message }, 500);
  }
});
