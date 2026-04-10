// =============================================================================
// Shared CORS utility — dynamic origin matching for edge functions
// =============================================================================

const ALLOWED_ORIGINS = [
  "https://beautycita.com",
  "https://www.beautycita.com",
  "https://debug.beautycita.com",
];

/**
 * Returns the request's origin if it matches beautycita.com (or a subdomain),
 * otherwise falls back to the primary origin.
 * Uses URL parsing instead of string matching to prevent origin spoofing
 * (e.g. "https://evil-beautycita.com" would pass a string includes check).
 */
export function corsOrigin(req: Request): string {
  const o = req.headers.get("origin") ?? "";
  try {
    const hostname = new URL(o).hostname;
    if (hostname === "beautycita.com" || hostname.endsWith(".beautycita.com")) return o;
  } catch { /* malformed origin — fall through to default */ }
  return ALLOWED_ORIGINS[0];
}

/**
 * Returns CORS headers appropriate for the given request.
 * Pass additional header names in `extraHeaders` if needed
 * (e.g. "stripe-signature").
 */
export function corsHeaders(req: Request, extraHeaders?: string): Record<string, string> {
  const allowHeaders = [
    "authorization",
    "x-client-info",
    "apikey",
    "content-type",
  ];
  if (extraHeaders) {
    allowHeaders.push(extraHeaders);
  }
  return {
    "Access-Control-Allow-Origin": corsOrigin(req),
    "Access-Control-Allow-Headers": allowHeaders.join(", "),
    "Access-Control-Allow-Methods": "POST, GET, OPTIONS",
  };
}

/**
 * Convenience: if the request is OPTIONS, return a preflight response.
 * Returns null for non-OPTIONS requests so the caller can continue.
 */
export function handleCorsPreflightIfOptions(req: Request, extraHeaders?: string): Response | null {
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders(req, extraHeaders) });
  }
  return null;
}
