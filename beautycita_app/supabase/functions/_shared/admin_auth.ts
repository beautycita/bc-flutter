// Shared edge-function helpers for admin-tier auth checks.
// Phase 0 of the admin redesign (decision #18).
//
// Three tiers (matching SQL helpers is_ops_admin / is_admin / is_superadmin):
//   ops_admin    → operations + people read + dispute resolution + outreach
//   admin        → + tier mutations + Dinero + refunds + role-change requests
//   superadmin   → + Motor + Sistema + role-change approvals (with step-up)
//
// All helpers throw a Response on failure so callers can `return` directly:
//
//   const supa = createSupabaseClient(req);
//   const user = await requireAdmin(supa, req);  // throws Response if not admin
//   ...
//
// requireFreshAuth(maxAgeSec=300) is the step-up gate, used by:
//   refund issuance, debt write-off, salon delete,
//   superadmin grant, role-change approval.

import { createClient, SupabaseClient } from "https://esm.sh/@supabase/supabase-js@2";

export type AdminTier = "ops_admin" | "admin" | "superadmin";

const ROLE_RANK: Record<string, number> = {
  ops_admin: 1,
  admin: 2,
  superadmin: 3,
};

function jsonErr(status: number, body: Record<string, unknown>): Response {
  return new Response(JSON.stringify(body), {
    status,
    headers: { "Content-Type": "application/json" },
  });
}

/** Decode the caller's JWT and return its claims. Throws Response on failure. */
function readClaims(req: Request): Record<string, unknown> {
  const auth = req.headers.get("Authorization") ?? "";
  const token = auth.startsWith("Bearer ") ? auth.slice(7) : "";
  if (!token) throw jsonErr(401, { error: "missing_auth" });
  const parts = token.split(".");
  if (parts.length !== 3) throw jsonErr(401, { error: "bad_token" });
  try {
    const payload = parts[1].replace(/-/g, "+").replace(/_/g, "/");
    const padded = payload + "=".repeat((4 - (payload.length % 4)) % 4);
    return JSON.parse(atob(padded));
  } catch {
    throw jsonErr(401, { error: "bad_token" });
  }
}

/** Build a service-role Supabase client (for admin reads). */
export function adminSupabase(): SupabaseClient {
  return createClient(
    Deno.env.get("SUPABASE_URL")!,
    Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!,
  );
}

/** Look up the caller's role (text) from profiles. Throws Response if missing. */
async function callerRole(req: Request): Promise<{ userId: string; role: string }> {
  const claims = readClaims(req);
  const userId = String(claims.sub ?? "");
  if (!userId) throw jsonErr(401, { error: "no_subject" });
  const { data, error } = await adminSupabase()
    .from("profiles")
    .select("role")
    .eq("id", userId)
    .maybeSingle();
  if (error || !data) throw jsonErr(401, { error: "no_profile" });
  return { userId, role: String((data as { role: string }).role) };
}

async function requireTier(req: Request, min: AdminTier): Promise<{ userId: string; role: AdminTier }> {
  const { userId, role } = await callerRole(req);
  const have = ROLE_RANK[role] ?? 0;
  const need = ROLE_RANK[min];
  if (have < need) {
    throw jsonErr(403, { error: "forbidden", required: min, have: role });
  }
  return { userId, role: role as AdminTier };
}

export const requireOpsAdmin = (req: Request) => requireTier(req, "ops_admin");
export const requireAdmin = (req: Request) => requireTier(req, "admin");
export const requireSuperadmin = (req: Request) => requireTier(req, "superadmin");

/**
 * Step-up auth gate. Returns true iff the JWT was issued within maxAgeSec.
 * Use for: refund issuance, debt write-off, salon delete,
 *          superadmin grant, role-change approval.
 *
 * Throws Response (412) when stale; the client should re-prompt for password
 * or biometric, then re-call the same edge fn with a fresh token.
 */
export function requireFreshAuth(req: Request, maxAgeSec = 300): void {
  const claims = readClaims(req);
  const iat = Number(claims.iat ?? 0);
  if (!iat) throw jsonErr(412, { error: "step_up_required", reason: "no_iat" });
  const ageSec = Math.floor(Date.now() / 1000) - iat;
  if (ageSec > maxAgeSec) {
    throw jsonErr(412, {
      error: "step_up_required",
      reason: "token_too_old",
      age_seconds: ageSec,
      max_age_seconds: maxAgeSec,
    });
  }
}
