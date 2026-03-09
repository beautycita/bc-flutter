import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

/**
 * Check if a feature toggle is enabled in app_config.
 * Returns true if enabled, false if disabled or not found.
 */
export async function isFeatureEnabled(key: string): Promise<boolean> {
  const supabase = createClient(
    Deno.env.get("SUPABASE_URL")!,
    Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!
  );
  const { data } = await supabase
    .from("app_config")
    .select("value")
    .eq("key", key)
    .eq("data_type", "bool")
    .single();
  return data?.value === "true";
}

/**
 * Guard: returns a 503 Response if the feature is disabled, or null if enabled.
 * Usage:
 *   const blocked = await requireFeature('enable_stripe_payments');
 *   if (blocked) return blocked;
 */
export async function requireFeature(key: string): Promise<Response | null> {
  if (!(await isFeatureEnabled(key))) {
    return new Response(
      JSON.stringify({ error: "This feature is currently disabled" }),
      { status: 503, headers: { "Content-Type": "application/json" } }
    );
  }
  return null;
}
