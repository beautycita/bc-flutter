import { serve } from "https://deno.land/std@0.177.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

const ALLOWED_ORIGIN = "https://beautycita.com";
const corsHeaders = {
  "Access-Control-Allow-Origin": ALLOWED_ORIGIN,
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

      // Generate a verify_token — only the web client that creates the session
      // receives this token, and it's required to call verify later.
      const verifyToken = generateCode(32);

      const { data, error } = await supabase
        .from("qr_auth_sessions")
        .insert({ code, verify_token: verifyToken })
        .select("id, code")
        .single();

      if (error) throw error;

      return json({ session_id: data.id, code: data.code, verify_token: verifyToken });
    }

    // ===== CHECK =====
    if (action === "check") {
      const { code } = body;
      if (!code) return json({ error: "code is required" }, 400);

      const { data: session, error: sessError } = await supabase
        .from("qr_auth_sessions")
        .select("id, status")
        .eq("code", code)
        .maybeSingle();

      if (sessError) throw sessError;
      if (!session) return json({ authorized: false });

      return json({
        authorized: session.status === "authorized",
        session_id: session.id,
      });
    }

    // ===== REGISTER WEB SESSION =====
    if (action === "register_session") {
      const authHeader = req.headers.get("Authorization") ?? "";
      const token = authHeader.replace("Bearer ", "");
      if (!token) return json({ error: "Authorization required" }, 401);

      const {
        data: { user },
        error: authError,
      } = await supabase.auth.getUser(token);
      if (authError || !user) return json({ error: "Invalid token" }, 401);

      // Check if user already has an active web session
      const { data: existing } = await supabase
        .from("qr_auth_sessions")
        .select("id")
        .eq("user_id", user.id)
        .eq("status", "consumed")
        .limit(1)
        .maybeSingle();

      if (existing) {
        // Refresh the existing session's timestamp
        await supabase
          .from("qr_auth_sessions")
          .update({ consumed_at: new Date().toISOString() })
          .eq("id", existing.id);
        return json({ success: true, session_id: existing.id });
      }

      // Create a new session record for this web login
      const { data, error } = await supabase
        .from("qr_auth_sessions")
        .insert({
          code: generateCode(),
          status: "consumed",
          user_id: user.id,
          email: user.email,
          authorized_at: new Date().toISOString(),
          consumed_at: new Date().toISOString(),
          expires_at: new Date(
            Date.now() + 30 * 24 * 60 * 60 * 1000
          ).toISOString(), // 30 days
        })
        .select("id")
        .single();

      if (error) throw error;
      return json({ success: true, session_id: data.id });
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
      const { session_id, verify_token } = body;
      if (!session_id) return json({ error: "session_id is required" }, 400);
      if (!verify_token) return json({ error: "verify_token is required" }, 400);

      const { data: session, error: sessError } = await supabase
        .from("qr_auth_sessions")
        .select("id, status, email, email_otp, expires_at, verify_token")
        .eq("id", session_id)
        .eq("status", "authorized")
        .maybeSingle();

      if (sessError) throw sessError;
      if (!session) return json({ error: "Session not authorized" }, 404);

      // Verify the caller holds the verify_token (only the web client that
      // created this session knows the token — prevents session_id guessing)
      if (!session.verify_token || session.verify_token !== verify_token) {
        return json({ error: "Invalid verify token" }, 403);
      }

      // Check expiry
      if (new Date(session.expires_at) < new Date()) {
        await supabase
          .from("qr_auth_sessions")
          .update({ status: "expired" })
          .eq("id", session.id);
        return json({ error: "Session expired" }, 410);
      }

      // Mark consumed and clear OTP from DB
      await supabase
        .from("qr_auth_sessions")
        .update({
          status: "consumed",
          consumed_at: new Date().toISOString(),
          email_otp: null,
          verify_token: null,
        })
        .eq("id", session.id);

      return json({
        email: session.email,
        email_otp: session.email_otp,
      });
    }

    // ===== LIST SESSIONS =====
    if (action === "list_sessions") {
      // Validate APK user's JWT
      const authHeader = req.headers.get("Authorization") ?? "";
      const token = authHeader.replace("Bearer ", "");
      if (!token) return json({ error: "Authorization required" }, 401);

      const {
        data: { user },
        error: authError,
      } = await supabase.auth.getUser(token);
      if (authError || !user) return json({ error: "Invalid token" }, 401);

      // Get consumed (active) sessions for this user
      const { data: sessions, error: sessError } = await supabase
        .from("qr_auth_sessions")
        .select("id, authorized_at, consumed_at")
        .eq("user_id", user.id)
        .eq("status", "consumed")
        .order("consumed_at", { ascending: false });

      if (sessError) throw sessError;

      return json({
        sessions: (sessions ?? []).map((s: any) => ({
          id: s.id,
          linked_at: s.consumed_at || s.authorized_at,
        })),
      });
    }

    // ===== REVOKE =====
    if (action === "revoke") {
      const { session_id } = body;
      if (!session_id) return json({ error: "session_id is required" }, 400);

      // Validate APK user's JWT
      const authHeader = req.headers.get("Authorization") ?? "";
      const token = authHeader.replace("Bearer ", "");
      if (!token) return json({ error: "Authorization required" }, 401);

      const {
        data: { user },
        error: authError,
      } = await supabase.auth.getUser(token);
      if (authError || !user) return json({ error: "Invalid token" }, 401);

      // Mark session as revoked (only if owned by this user)
      const { error: upError } = await supabase
        .from("qr_auth_sessions")
        .update({ status: "revoked" })
        .eq("id", session_id)
        .eq("user_id", user.id)
        .eq("status", "consumed");

      if (upError) throw upError;

      // Broadcast revocation so connected web client signs out
      try {
        const ch = supabase.channel(`qr_revoke_${session_id}`);
        await new Promise<void>((resolve) => {
          ch.subscribe((status: string) => {
            if (status === "SUBSCRIBED") {
              ch.send({
                type: "broadcast",
                event: "session_revoked",
                payload: { session_id },
              });
              resolve();
            }
          });
        });
        await new Promise((r) => setTimeout(r, 300));
        supabase.removeChannel(ch);
      } catch (_) {
        // Broadcast is best-effort; DB update is the source of truth
      }

      return json({ success: true });
    }

    // ===== CLEANUP =====
    if (action === "cleanup") {
      await supabase.rpc("cleanup_expired_qr_sessions");
      return json({ success: true });
    }

    return json({ error: "Unknown action" }, 400);
  } catch (err) {
    console.error("qr-auth error:", err);
    return json({ error: "Internal server error" }, 500);
  }
});
