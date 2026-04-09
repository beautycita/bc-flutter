// =============================================================================
// Shared CORS utility — dynamic origin matching for edge functions
// =============================================================================

const ALLOWED_ORIGINS = [
  "https://beautycita.com",
  "https://www.beautycita.com",
  "https://debug.beautycita.com",
];

/**
 * Returns the request's origin if it's in the allowlist,
 * otherwise falls back to the primary origin.
 */
export function corsOrigin(req: Request): string {
  const origin = req.headers.get("origin") ?? "";
  return ALLOWED_ORIGINS.includes(origin) ? origin : ALLOWED_ORIGINS[0];
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
