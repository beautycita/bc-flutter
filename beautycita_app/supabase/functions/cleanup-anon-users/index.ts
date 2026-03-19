import { serve } from "https://deno.land/std@0.168.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

serve(async (req: Request) => {
  if (req.method === "OPTIONS") {
    return new Response(null, { status: 204 });
  }

  try {
    // Auth: cron secret or service-role key required
    const authHeader = req.headers.get("authorization") ?? "";
    const cronSecret = Deno.env.get("CRON_SECRET") ?? "";
    const serviceKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!;
    const isValidCron = cronSecret && authHeader === `Bearer ${cronSecret}`;
    const isServiceRole = authHeader === `Bearer ${serviceKey}`;
    if (!isValidCron && !isServiceRole) {
      return new Response(JSON.stringify({ error: "Unauthorized" }), {
        status: 401, headers: { "Content-Type": "application/json" },
      });
    }

    const supabase = createClient(
      Deno.env.get("SUPABASE_URL")!,
      serviceKey
    );

    const { data, error } = await supabase.rpc("cleanup_anon_users");

    if (error) {
      console.error("[cleanup-anon-users] RPC error:", error);
      return new Response(
        JSON.stringify({ error: "Cleanup failed" }),
        { status: 500, headers: { "Content-Type": "application/json" } }
      );
    }

    console.log("[cleanup-anon-users] Result:", JSON.stringify(data));
    return new Response(
      JSON.stringify(data),
      { status: 200, headers: { "Content-Type": "application/json" } }
    );
  } catch (e) {
    console.error("[cleanup-anon-users] Error:", e);
    return new Response(
      JSON.stringify({ error: "Internal error" }),
      { status: 500, headers: { "Content-Type": "application/json" } }
    );
  }
});
