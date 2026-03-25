/**
 * Redis cache helper for edge functions.
 * Uses HTTP proxy to Redis via a lightweight API on the host.
 *
 * NEVER cache: bookings, availability, payments, auth, user-specific data
 * CACHE: feed, salon search, categories, config, discovered salons
 */

// Redis HTTP proxy — runs on the host, edge functions reach it via Docker gateway
const REDIS_HTTP = Deno.env.get("REDIS_HTTP_URL") || "http://172.17.0.1:6381";

/**
 * Get a cached value. Returns null on miss or Redis unavailable.
 */
export async function cacheGet(key: string): Promise<string | null> {
  try {
    const res = await fetch(`${REDIS_HTTP}/get/${encodeURIComponent(key)}`, {
      signal: AbortSignal.timeout(1000),
    });
    if (!res.ok) return null;
    const data = await res.json();
    return data.value ?? null;
  } catch {
    return null;
  }
}

/**
 * Set a cached value with TTL in seconds.
 */
export async function cacheSet(key: string, value: string, ttlSeconds: number): Promise<void> {
  try {
    await fetch(`${REDIS_HTTP}/set`, {
      method: "POST",
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify({ key, value, ttl: ttlSeconds }),
      signal: AbortSignal.timeout(1000),
    });
  } catch {
    // Cache write failure is non-critical
  }
}

/**
 * Delete a cached key (for invalidation).
 */
export async function cacheDel(key: string): Promise<void> {
  try {
    await fetch(`${REDIS_HTTP}/del/${encodeURIComponent(key)}`, {
      method: "DELETE",
      signal: AbortSignal.timeout(1000),
    });
  } catch {
    // Ignore
  }
}

/**
 * Cache-through helper: returns cached value or calls fetcher and caches result.
 */
export async function cacheThrough<T>(
  key: string,
  ttlSeconds: number,
  fetcher: () => Promise<T>,
): Promise<T> {
  const cached = await cacheGet(key);
  if (cached) return JSON.parse(cached) as T;

  const fresh = await fetcher();
  await cacheSet(key, JSON.stringify(fresh), ttlSeconds);
  return fresh;
}
