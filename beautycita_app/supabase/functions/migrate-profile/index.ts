import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
  "Access-Control-Allow-Methods": "POST, OPTIONS",
};

Deno.serve(async (req) => {
  if (req.method === "OPTIONS") {
    return new Response(null, { status: 204, headers: corsHeaders });
  }
  if (req.method !== "POST") {
    return new Response(JSON.stringify({ error: "Method not allowed" }), {
      status: 405,
      headers: { ...corsHeaders, "Content-Type": "application/json" },
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
      headers: { ...corsHeaders, "Content-Type": "application/json" },
    });
  }

  const { old_user_id } = await req.json();
  if (!old_user_id || old_user_id === user.id) {
    // Nothing to migrate — either missing arg or IDs already match
    return new Response(JSON.stringify({ ok: true, migrated: false }), {
      headers: { ...corsHeaders, "Content-Type": "application/json" },
    });
  }

  // Use service role only after caller is authenticated — avoids any
  // client-side forgery; ownership is implicit because the caller holds
  // the JWT for user.id (the new auth ID we are migrating to).
  const db = createClient(supabaseUrl, serviceKey);

  // Verify the old profile actually exists before touching anything
  const { data: oldProfile } = await db
    .from("profiles")
    .select("id")
    .eq("id", old_user_id)
    .single();

  if (!oldProfile) {
    // Old profile already gone or never existed — nothing to do
    return new Response(JSON.stringify({ ok: true, migrated: false }), {
      headers: { ...corsHeaders, "Content-Type": "application/json" },
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
    return new Response(JSON.stringify({ error: updateErr.message }), {
      status: 500,
      headers: { ...corsHeaders, "Content-Type": "application/json" },
    });
  }

  console.log(`[migrate-profile] Migrated profile ${old_user_id} -> ${user.id}`);
  return new Response(JSON.stringify({ ok: true, migrated: true }), {
    headers: { ...corsHeaders, "Content-Type": "application/json" },
  });
});
