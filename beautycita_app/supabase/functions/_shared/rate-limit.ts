// =============================================================================
// _shared/rate-limit.ts — In-memory token-bucket rate limiter for edge functions
// =============================================================================
// Per-isolate map. Resets when the function isolate restarts (Deno isolates
// recycle every few minutes of inactivity), so the limit is "burst protection
// while warm" — not a hard distributed budget. For platform-wide hard limits
// use Supabase Pooler / Cloudflare WAF / Upstash Redis (already wired for
// Redis in some functions via _shared/redis.ts).
//
// Usage
// -----
//   import { checkRateLimit } from "../_shared/rate-limit.ts";
//   if (!checkRateLimit(`pay:${user.id}`, 5, 60_000)) {
//     return json({ error: "Too many requests" }, 429);
//   }
//
// Naming convention
// -----------------
// First segment of the key is the function/scope so different functions
// don't collide (`pay:${uid}`, `chat:${uid}`, `auth:${uid}`).
// =============================================================================

interface Bucket {
  count: number;
  resetAt: number;
}

const buckets = new Map<string, Bucket>();

/**
 * Returns true if the request may proceed; false if the key is over-limit
 * for the current window.
 *
 * @param key       Unique key per (function, principal). Examples:
 *                  `pay:${user.id}`, `feed:${ip}`, `wa:${phone}`.
 * @param limit     Max requests in the window.
 * @param windowMs  Window length in milliseconds.
 */
export function checkRateLimit(
  key: string,
  limit: number,
  windowMs: number,
): boolean {
  const now = Date.now();
  const entry = buckets.get(key);
  if (!entry || now > entry.resetAt) {
    buckets.set(key, { count: 1, resetAt: now + windowMs });
    return true;
  }
  if (entry.count >= limit) return false;
  entry.count++;
  return true;
}

/**
 * Best-effort principal key for an authenticated request. Falls back to
 * the last 16 chars of the auth header (so anonymous calls still bucketed
 * per JWT/session) and finally to a literal "anon".
 */
export function principalKey(req: Request, userId?: string | null): string {
  if (userId) return userId;
  const auth = req.headers.get("authorization") ?? "";
  if (auth) return `tok:${auth.slice(-16)}`;
  return "anon";
}

/**
 * IP-based key for unauthenticated public endpoints (feed-public, salon-page).
 * Trusts X-Forwarded-For / CF-Connecting-IP — supabase edge runtime sets these
 * when behind kong / cloudflare. Falls back to "ip:unknown".
 */
export function ipKey(req: Request): string {
  const cf = req.headers.get("cf-connecting-ip");
  if (cf) return `ip:${cf}`;
  const xff = req.headers.get("x-forwarded-for");
  if (xff) return `ip:${xff.split(",")[0].trim()}`;
  return "ip:unknown";
}
