import { createClient } from "https://esm.sh/@supabase/supabase-js@2";
import { corsHeaders, handleCorsPreflightIfOptions } from "../_shared/cors.ts";
import { checkRateLimit } from "../_shared/rate-limit.ts";


Deno.serve(async (req) => {
  const _pre = handleCorsPreflightIfOptions(req);
  if (_pre) return _pre;
  if (req.method !== "POST") {
    return new Response(JSON.stringify({ error: "Method not allowed" }), {
      status: 405,
      headers: { ...corsHeaders(req), "Content-Type": "application/json" },
    });
  }

  const authHeader = req.headers.get("authorization") || "";
  const supabaseUrl = Deno.env.get("SUPABASE_URL")!;
  const serviceKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!;
  const anonKey = Deno.env.get("SUPABASE_ANON_KEY")!;

  // Authenticate the caller — the JWT must belong to the new auth user
  const userClient = createClient(supabaseUrl, anonKey, {
    global: { headers: { Authorization: authHeader } },
  });
  const { data: { user }, error: authError } = await userClient.auth.getUser();
  if (authError || !user) {
    return new Response(JSON.stringify({ error: "Not authenticated" }), {
      status: 401,
      headers: { ...corsHeaders(req), "Content-Type": "application/json" },
    });
  }

  if (!checkRateLimit(`migr:${user.id}`, 3, 60_000)) {
    return new Response(JSON.stringify({ error: "Too many requests" }), {
      status: 429,
      headers: { ...corsHeaders(req), "Content-Type": "application/json" },
    });
  }

  const { old_user_id } = await req.json();
  if (!old_user_id || old_user_id === user.id) {
    // Nothing to migrate — either missing arg or IDs already match
    return new Response(JSON.stringify({ ok: true, migrated: false }), {
      headers: { ...corsHeaders(req), "Content-Type": "application/json" },
    });
  }

  // Use service role only after caller is authenticated.
  const db = createClient(supabaseUrl, serviceKey);

  // Verify the old profile actually exists before touching anything
  const { data: oldProfile } = await db
    .from("profiles")
    .select("id, device_id, username")
    .eq("id", old_user_id)
    .single();

  if (!oldProfile) {
    // Old profile already gone or never existed — nothing to do
    return new Response(JSON.stringify({ ok: true, migrated: false }), {
      headers: { ...corsHeaders(req), "Content-Type": "application/json" },
    });
  }

  // SECURITY: Verify the caller owns the old profile by matching device_id or username.
  // Prevents random UUID guessing attacks.
  const { data: callerProfile } = await db
    .from("profiles")
    .select("device_id, username")
    .eq("id", user.id)
    .single();

  const deviceMatch = oldProfile.device_id && callerProfile?.device_id &&
    oldProfile.device_id === callerProfile.device_id;
  const usernameMatch = oldProfile.username && callerProfile?.username &&
    oldProfile.username === callerProfile.username;

  if (!deviceMatch && !usernameMatch) {
    console.warn(`[migrate-profile] Blocked: caller ${user.id} does not match old profile ${old_user_id}`);
    return new Response(JSON.stringify({ error: "Profile ownership verification failed" }), {
      status: 403,
      headers: { ...corsHeaders(req), "Content-Type": "application/json" },
    });
  }

  // SECURITY: Only allow migration of anonymous stub profiles.
  // If the old auth user has a real email (not a generated @qr.beautycita.app),
  // it's a real account and cannot be claimed by another user.
  const { data: oldAuthUser } = await db.auth.admin.getUserById(old_user_id);
  if (oldAuthUser?.user?.email &&
      !oldAuthUser.user.email.endsWith("@qr.beautycita.app") &&
      oldAuthUser.user.email_confirmed_at) {
    console.warn(`[migrate-profile] Blocked: old_user_id ${old_user_id} has confirmed email`);
    return new Response(JSON.stringify({ error: "Cannot migrate a confirmed account" }), {
      status: 403,
      headers: { ...corsHeaders(req), "Content-Type": "application/json" },
    });
  }

  // Also block if old profile has a phone (real user, not stub)
  const { data: oldProfileFull } = await db
    .from("profiles")
    .select("phone")
    .eq("id", old_user_id)
    .single();
  if (oldProfileFull?.phone) {
    console.warn(`[migrate-profile] Blocked: old_user_id ${old_user_id} has phone`);
    return new Response(JSON.stringify({ error: "Cannot migrate a profile with phone" }), {
      status: 403,
      headers: { ...corsHeaders(req), "Content-Type": "application/json" },
    });
  }

  // Delete the auto-created profile for the new auth user (if the DB
  // trigger created a stub row with a generated username we don't want)
  await db.from("profiles").delete().eq("id", user.id);

  // Remap the existing profile to the new auth ID
  const { error: updateErr } = await db
    .from("profiles")
    .update({ id: user.id })
    .eq("id", old_user_id);

  if (updateErr) {
    console.error("[migrate-profile] Update failed:", updateErr);
    return new Response(JSON.stringify({ error: "Migration failed" }), {
      status: 500,
      headers: { ...corsHeaders(req), "Content-Type": "application/json" },
    });
  }

  // Migrate all related tables from old_user_id to new user.id
  const tables = [
    { table: "appointments", column: "user_id" },
    { table: "favorites", column: "user_id" },
    { table: "reviews", column: "user_id" },
    { table: "chat_threads", column: "user_id" },
    { table: "payment_methods", column: "user_id" },
    { table: "gift_cards", column: "buyer_id" },
  ];

  for (const { table, column } of tables) {
    const { error: migErr } = await db
      .from(table)
      .update({ [column]: user.id })
      .eq(column, old_user_id);
    if (migErr) {
      console.warn(`[migrate-profile] Failed to migrate ${table}: ${migErr.message}`);
    }
  }

  console.log(`[migrate-profile] Migrated profile + related data ${old_user_id} -> ${user.id}`);
  return new Response(JSON.stringify({ ok: true, migrated: true }), {
    headers: { ...corsHeaders(req), "Content-Type": "application/json" },
  });
});
