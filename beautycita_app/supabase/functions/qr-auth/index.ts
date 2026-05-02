import { serve } from "https://deno.land/std@0.177.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";
import { corsHeaders, handleCorsPreflightIfOptions } from "../_shared/cors.ts";

function generateCode(length = 8): string {
  const chars = "ABCDEFGHJKLMNPQRSTUVWXYZabcdefghjkmnpqrstuvwxyz23456789";
  const arr = new Uint8Array(length);
  crypto.getRandomValues(arr);
  return Array.from(arr, (b) => chars[b % chars.length]).join("");
}

// ── Rate limiting ─────────────────────────────────────────────────────────
const rateLimitMap = new Map<string, { count: number; resetAt: number }>();

function checkRateLimit(key: string, limit: number, windowMs: number): boolean {
  const now = Date.now();
  const entry = rateLimitMap.get(key);
  if (!entry || now > entry.resetAt) {
    rateLimitMap.set(key, { count: 1, resetAt: now + windowMs });
    return true;
  }
  if (entry.count >= limit) return false;
  entry.count++;
  return true;
}

function getClientIp(req: Request): string {
  return req.headers.get("x-forwarded-for")?.split(",")[0]?.trim() ?? "unknown";
}

/// Decode the `session_id` claim out of a Supabase access_token JWT without
/// verifying the signature (we minted it server-side a moment ago, the
/// signature was already validated by Supabase Auth). Returns null if the
/// token shape is unexpected.
function decodeJwtSessionId(jwt: string): string | null {
  try {
    const parts = jwt.split(".");
    if (parts.length !== 3) return null;
    const padded = parts[1].replace(/-/g, "+").replace(/_/g, "/");
    const pad = padded.length % 4 === 0 ? "" : "=".repeat(4 - (padded.length % 4));
    const json = atob(padded + pad);
    const claims = JSON.parse(json);
    const sid = claims?.session_id;
    return typeof sid === "string" && sid.length > 0 ? sid : null;
  } catch (_) {
    return null;
  }
}

serve(async (req) => {
  const _pre = handleCorsPreflightIfOptions(req);
  if (_pre) return _pre;

  function json(data: unknown, status = 200) {
    return new Response(JSON.stringify(data), {
      status,
      headers: { ...corsHeaders(req), "Content-Type": "application/json" },
    });
  }

  try {
    const supabaseUrl = Deno.env.get("SUPABASE_URL") ?? "";
    const serviceRoleKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY") ?? "";
    const supabase = createClient(supabaseUrl, serviceRoleKey);

    const body = await req.json();
    const { action } = body;

    // ===== CREATE =====
    if (action === "create") {
      // Rate limit: 10 per hour per IP.
      const ip = getClientIp(req);
      if (!checkRateLimit(`qr_create_${ip}`, 10, 3600000)) return json({ error: "Too many QR sessions. Try again later." }, 429);

      // Additional per-user cap if the caller is authenticated (prevents
      // IP-hopping abuse once a user is known). 1 create per minute per user.
      const authHdr = req.headers.get("Authorization") ?? "";
      if (authHdr) {
        const userToken = authHdr.replace("Bearer ", "");
        try {
          const { data: { user: authedUser } } = await supabase.auth.getUser(userToken);
          if (authedUser && !checkRateLimit(`qr_create_user_${authedUser.id}`, 1, 60000)) {
            return json({ error: "Too many QR sessions. Wait a moment." }, 429);
          }
        } catch (_) { /* token invalid — fall through to IP-only rate limit */ }
      }
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

      // Capture auth.sessions.id from this caller's access_token so a
      // future revoke from the mobile device manager can authoritatively
      // delete the row. Without this, register_session-created rows had
      // auth_session_id=NULL and the revoke RPC's `DELETE FROM
      // auth.sessions` was skipped — meaning the web tab stayed signed
      // in even after the user revoked it.
      const callerAuthSessionId = decodeJwtSessionId(token);

      // Match on (user_id, auth_session_id) so distinct browsers each get
      // their own row instead of all collapsing onto a single record.
      let existing: { id: string } | null = null;
      if (callerAuthSessionId) {
        const r = await supabase
          .from("qr_auth_sessions")
          .select("id")
          .eq("user_id", user.id)
          .eq("auth_session_id", callerAuthSessionId)
          .eq("status", "consumed")
          .limit(1)
          .maybeSingle();
        existing = r.data;
      }
      // Legacy fallback: if we couldn't match by auth_session_id (caller
      // didn't send a session-shaped token, or the row was created before
      // we started capturing), update the most recent consumed row to
      // backfill the auth_session_id and refresh the timestamp.
      if (!existing) {
        const r = await supabase
          .from("qr_auth_sessions")
          .select("id, auth_session_id")
          .eq("user_id", user.id)
          .eq("status", "consumed")
          .is("auth_session_id", null)
          .order("consumed_at", { ascending: false })
          .limit(1)
          .maybeSingle();
        existing = r.data;
      }

      if (existing) {
        await supabase
          .from("qr_auth_sessions")
          .update({
            consumed_at: new Date().toISOString(),
            ...(callerAuthSessionId ? { auth_session_id: callerAuthSessionId } : {}),
          })
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
          auth_session_id: callerAuthSessionId,
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

      // Rate limit: 5 per minute per user
      if (!checkRateLimit(`qr_auth_${user.id}`, 5, 60000)) return json({ error: "Too many attempts. Wait a moment." }, 429);

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

      // Realtime kick — emit on the per-session channel the web client
      // subscribes to at QR display time. The web also polls every 3s,
      // but the broadcast removes the 0-3s wait and avoids cases where
      // the poll tick lands after the user has switched tabs.
      try {
        const ch = supabase.channel(`qr_auth_${session.id}`);
        await new Promise<void>((resolve) => {
          ch.subscribe((status: string) => {
            if (status === "SUBSCRIBED") {
              ch.send({
                type: "broadcast",
                event: "session_authorized",
                payload: { session_id: session.id },
              });
              resolve();
            }
          });
        });
        await new Promise((r) => setTimeout(r, 300));
        supabase.removeChannel(ch);
      } catch (_) {
        // Broadcast is best-effort; the 3s poll is still the safety net.
      }

      return json({ success: true });
    }

    // ===== VERIFY =====
    if (action === "verify") {
      const { session_id, verify_token } = body;
      if (!session_id) return json({ error: "session_id is required" }, 400);
      if (!verify_token) return json({ error: "verify_token is required" }, 400);

      // Rate limit: 5 per minute per session_id
      if (!checkRateLimit(`qr_verify_${session_id}`, 5, 60000)) return json({ error: "Too many verify attempts." }, 429);

      // Atomic compare-and-swap: flip 'authorized' → 'consuming' so a racing
      // caller (broadcast handler + 3s poll handler firing within the same
      // tick) can't both reach gotrue.verifyOtp. The OTP from generateLink
      // is single-use; if both callers got past the SELECT-then-update
      // pattern, one would succeed and the other would 403 otp_expired —
      // surfacing as "QR sign-in works some times and fails others."
      const { data: claimed, error: claimError } = await supabase
        .from("qr_auth_sessions")
        .update({ status: "consuming" })
        .eq("id", session_id)
        .eq("status", "authorized")
        .select("id, email, email_otp, expires_at, verify_token")
        .maybeSingle();

      if (claimError) throw claimError;
      if (!claimed) {
        // Either never authorized, already consumed, or another caller won
        // the race. Surface a stable 409 the client can ignore as benign.
        return json({ error: "Session not in verifiable state" }, 409);
      }

      // Verify the caller holds the verify_token (only the web client that
      // created this session knows the token — prevents session_id guessing).
      // Done after the CAS so a guessing attacker still can't drain OTPs.
      if (!claimed.verify_token || claimed.verify_token !== verify_token) {
        // Roll the row back so the legitimate caller can still complete.
        await supabase
          .from("qr_auth_sessions")
          .update({ status: "authorized" })
          .eq("id", claimed.id);
        return json({ error: "Invalid verify token" }, 403);
      }

      // Check expiry
      if (new Date(claimed.expires_at) < new Date()) {
        await supabase
          .from("qr_auth_sessions")
          .update({ status: "expired" })
          .eq("id", claimed.id);
        return json({ error: "Session expired" }, 410);
      }

      // Verify OTP server-side. Must run after the CAS above so racing
      // callers can't both reach gotrue with the single-use OTP.
      const { data: verifyData, error: verifyError } =
        await supabase.auth.verifyOtp({
          email: claimed.email,
          token: claimed.email_otp,
          type: "magiclink",
        });

      if (verifyError || !verifyData?.session) {
        // Roll back so the user can retry without regenerating the QR.
        await supabase
          .from("qr_auth_sessions")
          .update({ status: "authorized" })
          .eq("id", claimed.id);
        console.error("verifyOtp failed:", verifyError);
        return json({ error: "OTP verification failed" }, 500);
      }

      // Capture the canonical auth.sessions.id from the access_token's
      // session_id claim so a future revoke can authoritatively kill it.
      const authSessionId = decodeJwtSessionId(verifyData.session.access_token);

      // Mark consumed, store the auth_session_id, clear OTP / verify_token
      await supabase
        .from("qr_auth_sessions")
        .update({
          status: "consumed",
          consumed_at: new Date().toISOString(),
          email_otp: null,
          verify_token: null,
          auth_session_id: authSessionId,
        })
        .eq("id", claimed.id);

      return json({
        access_token: verifyData.session.access_token,
        refresh_token: verifyData.session.refresh_token,
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

      // Active sessions = anything the user has authorized that hasn't
      // been revoked yet. Includes both 'consumed' (web finished verify
      // and minted tokens) and 'authorized' (web hasn't called verify
      // yet — usually transient sub-second state, but we list it so
      // the user can revoke a half-completed link from the phone if
      // the web step never finishes).
      const { data: sessions, error: sessError } = await supabase
        .from("qr_auth_sessions")
        .select("id, status, authorized_at, consumed_at, created_at")
        .eq("user_id", user.id)
        .in("status", ["consumed", "authorized"])
        .order("authorized_at", { ascending: false });

      if (sessError) throw sessError;

      return json({
        sessions: (sessions ?? []).map((s: any) => ({
          id: s.id,
          status: s.status,
          linked_at: s.consumed_at || s.authorized_at || s.created_at,
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

      // Authoritative revoke: deletes the captured auth.sessions row, which
      // cascades to auth.refresh_tokens — the web client can no longer mint
      // new access tokens. The RPC also enforces ownership against auth.uid()
      // and flips qr_auth_sessions.status to 'revoked'.
      //
      // We use a userClient here (not the service-role supabase) so that
      // auth.uid() resolves to the caller inside the SECURITY DEFINER fn.
      const userClient = createClient(supabaseUrl, Deno.env.get("SUPABASE_ANON_KEY") ?? "", {
        global: { headers: { Authorization: `Bearer ${token}` } },
      });
      const { data: rpcData, error: rpcError } = await userClient.rpc(
        "revoke_auth_session",
        { p_qr_session_id: session_id },
      );
      if (rpcError) {
        console.error("revoke_auth_session RPC failed:", rpcError);
        return json({ error: "Revoke failed" }, 500);
      }
      const ok = (rpcData as { ok?: boolean } | null)?.ok === true;
      if (!ok) {
        const reason = (rpcData as { reason?: string } | null)?.reason ?? "unknown";
        return json({ error: `Revoke failed: ${reason}` }, 404);
      }

      // Realtime kick: broadcast on a stable user-scoped channel so the
      // web client (subscribed at boot) gets immediate sign-out without
      // needing to know the per-session channel name. The DB row is the
      // source of truth; the broadcast is best-effort instant-feedback.
      try {
        const ch = supabase.channel(`auth_revoke:${user.id}`);
        await new Promise<void>((resolve) => {
          ch.subscribe((status: string) => {
            if (status === "SUBSCRIBED") {
              ch.send({
                type: "broadcast",
                event: "session_revoked",
                payload: {
                  qr_session_id: session_id,
                  auth_session_id: (rpcData as { auth_session_id?: string } | null)?.auth_session_id ?? null,
                },
              });
              resolve();
            }
          });
        });
        await new Promise((r) => setTimeout(r, 300));
        supabase.removeChannel(ch);
      } catch (_) {
        // Broadcast is best-effort; DB cascade is the source of truth.
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
