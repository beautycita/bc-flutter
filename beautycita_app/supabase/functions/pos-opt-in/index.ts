// =============================================================================
// pos-opt-in — Activate POS for a business with seller-agreement capture
// =============================================================================
// Replaces direct biz.update({pos_enabled:true}) from the web client. Verifies
// caller owns the business, requires a terms_version in the body, and writes
// the pos_agreements row + businesses.pos_enabled=true together. The unique
// constraint on (business_id, agreement_type, agreement_version) means a
// retry after a partial failure is safe (idempotent).
// =============================================================================

import { serve } from "https://deno.land/std@0.177.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";
import { corsHeaders as dynamicCors } from "../_shared/cors.ts";

const SUPABASE_URL = Deno.env.get("SUPABASE_URL") ?? "";
const SUPABASE_SERVICE_ROLE_KEY = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY") ?? "";

const AGREEMENT_TYPE = "pos_seller";

let _req: Request;

function json(data: unknown, status = 200) {
  return new Response(JSON.stringify(data), {
    status,
    headers: { ...dynamicCors(_req), "Content-Type": "application/json" },
  });
}

serve(async (req) => {
  _req = req;
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: dynamicCors(req) });
  }

  try {
    const supabase = createClient(SUPABASE_URL, SUPABASE_SERVICE_ROLE_KEY);
    const authHeader = req.headers.get("authorization") ?? "";
    const token = authHeader.replace("Bearer ", "");
    const { data: { user }, error: authError } = await supabase.auth.getUser(token);
    if (authError || !user) return json({ error: "Unauthorized" }, 401);

    const body = await req.json().catch(() => ({}));
    const businessId = body.business_id as string | undefined;
    const termsVersion = body.terms_version as string | undefined;

    if (!businessId) return json({ error: "business_id required" }, 400);
    if (!termsVersion) {
      return json({ error: "terms_version required", code: "TERMS_VERSION_MISSING" }, 412);
    }

    const { data: biz, error: bizErr } = await supabase
      .from("businesses")
      .select("id, owner_id, pos_enabled")
      .eq("id", businessId)
      .maybeSingle();
    if (bizErr || !biz) return json({ error: "Business not found" }, 404);
    if (biz.owner_id !== user.id) return json({ error: "Forbidden" }, 403);

    if (biz.pos_enabled) {
      return json({ success: true, already_enabled: true });
    }

    const { error: agreementErr } = await supabase
      .from("pos_agreements")
      .insert({
        business_id: businessId,
        agreement_type: AGREEMENT_TYPE,
        agreement_version: termsVersion,
      });

    if (agreementErr && agreementErr.code !== "23505") {
      console.error("[pos-opt-in] agreement insert failed:", agreementErr);
      return json({ error: "Failed to record agreement" }, 500);
    }

    const { error: enableErr } = await supabase
      .from("businesses")
      .update({ pos_enabled: true })
      .eq("id", businessId);
    if (enableErr) {
      console.error("[pos-opt-in] pos_enabled flip failed:", enableErr);
      return json({ error: "Failed to enable POS" }, 500);
    }

    return json({ success: true, terms_version: termsVersion });
  } catch (e) {
    console.error("[pos-opt-in] unhandled:", e);
    return json({ error: "Internal error" }, 500);
  }
});
