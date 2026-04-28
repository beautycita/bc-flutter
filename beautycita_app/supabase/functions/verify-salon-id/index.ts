// =============================================================================
// verify-salon-id — Validate salon owner's photo ID via Google Cloud Vision
// =============================================================================
// 1. Downloads front + back ID images from salon-ids bucket
// 2. Calls Vision API for document detection, OCR, crop analysis
// 3. Fuzzy-matches extracted name against beneficiary_name
// 4. Updates businesses.id_verification_status + banking_complete
// =============================================================================

import { serve } from "https://deno.land/std@0.177.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";
import { checkRateLimit } from "../_shared/rate-limit.ts";

const ALLOWED_ORIGINS = [
  "https://beautycita.com",
  "https://www.beautycita.com",
  "https://debug.beautycita.com",
];

function corsOrigin(req: Request): string {
  const o = req.headers.get("origin") ?? "";
  return ALLOWED_ORIGINS.includes(o) ? o : ALLOWED_ORIGINS[0];
}

const corsHeaders = (req: Request) => ({
  "Access-Control-Allow-Origin": corsOrigin(req),
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
});

const SUPABASE_URL = Deno.env.get("SUPABASE_URL") ?? "";
const SUPABASE_SERVICE_ROLE_KEY = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY") ?? "";
const GCLOUD_VISION_KEY = JSON.parse(Deno.env.get("GCLOUD_VISION_KEY") ?? "{}");

let _req: Request;

// ── CLABE bank lookup ───────────────────────────────────────────────────────
const CLABE_BANKS: Record<string, string> = {
  "002": "BANAMEX", "006": "BANCOMEXT", "009": "BANOBRAS",
  "012": "BBVA", "014": "SANTANDER", "019": "BANJERCITO",
  "021": "HSBC", "030": "BAJIO", "032": "IXE",
  "036": "INBURSA", "037": "INTERACCIONES", "042": "MIFEL",
  "044": "SCOTIABANK", "058": "BANREGIO", "059": "INVEX",
  "060": "BANSI", "062": "AFIRME", "072": "BANORTE",
  "102": "ACCENDO", "106": "BANK OF AMERICA", "108": "MUFG",
  "110": "JP MORGAN", "112": "BMONEX", "113": "VE POR MAS",
  "127": "AZTECA", "128": "AUTOFIN", "130": "COMPARTAMOS",
  "136": "INTERCAM", "137": "BANCOPPEL", "138": "ABC CAPITAL",
  "140": "CONSUBANCO", "141": "VOLKSWAGEN", "143": "CIBANCO",
  "145": "BBASE", "147": "BANKAOOL", "148": "PAGATODO",
  "150": "INMOBILIARIO", "155": "ICBC", "156": "SABADELL",
  "166": "BANSEFI", "168": "HIPOTECARIA FEDERAL",
  "600": "MONEXCB", "601": "GBM", "602": "MASARI",
  "605": "VALUE", "606": "ESTRUCTURADORES", "608": "VECTOR",
  "613": "MULTIVA CBOLSA", "616": "FINAMEX", "617": "VALMEX",
  "618": "UNICA", "619": "MAPFRE", "620": "PROFUTURO",
  "621": "ACTINVER", "622": "OACTIN", "623": "SKANDIA",
  "626": "CBDEUTSCHE", "627": "ZURICH", "628": "ZURICHVI",
  "629": "SU CASITA", "630": "CB INTERCAM", "631": "CI BOLSA",
  "632": "BULLTICK CB", "634": "FINCOMUN", "636": "HDI SEGUROS",
  "637": "ORDER", "638": "NU MEXICO", "640": "CB JPMORGAN",
  "642": "REFORMA", "646": "STP", "648": "EVERCORE",
  "649": "SKANDIA", "651": "SEGMTY", "652": "ASEA",
  "653": "KUSPIT", "655": "SOFIEXPRESS", "656": "UNAGRA",
  "659": "OPCIONES EMPRESARIALES", "670": "LIBERTAD",
  "674": "CAJA TELEFONISTAS", "677": "CAJA POPULAR MEXICANA",
  "680": "CRISTOBAL COLON", "683": "CAJA MORELIA VALLADOLID",
  "684": "TRANSFER", "685": "FONDO PAVON", "686": "NU",
  "689": "FOMPED", "699": "FONDEADORA", "703": "CUENCA",
  "706": "ARCUS", "710": "NVIO", "722": "MERCADO PAGO",
  "723": "SPIN BY OXXO", "812": "BITAL", "846": "BICENTENARIO",
  "901": "CLS", "902": "INDEVAL",
};

// ── Google Cloud Vision auth ─────────────────────────────────────────────────
function _b64url(s: string): string {
  // JWT requires base64url, not standard base64. The previous code used
  // bare btoa() which leaks `+` `/` `=` and Google has tightened on that.
  return btoa(s).replace(/\+/g, "-").replace(/\//g, "_").replace(/=/g, "");
}

async function getAccessToken(): Promise<string> {
  const now = Math.floor(Date.now() / 1000);
  const header = _b64url(JSON.stringify({ alg: "RS256", typ: "JWT" }));
  // Use the modern `cloud-platform` scope. The deprecated `cloud-vision`
  // scope returns 401 against current Vision API endpoints even when the
  // service account has the Cloud Vision API User role granted.
  const claim = _b64url(JSON.stringify({
    iss: GCLOUD_VISION_KEY.client_email,
    scope: "https://www.googleapis.com/auth/cloud-platform",
    aud: "https://oauth2.googleapis.com/token",
    iat: now,
    exp: now + 3600,
  }));

  const signInput = new TextEncoder().encode(`${header}.${claim}`);

  // Import the private key
  const pemContent = GCLOUD_VISION_KEY.private_key
    .replace(/-----BEGIN PRIVATE KEY-----/, "")
    .replace(/-----END PRIVATE KEY-----/, "")
    .replace(/\n/g, "");
  const keyData = Uint8Array.from(atob(pemContent), (c) => c.charCodeAt(0));

  const key = await crypto.subtle.importKey(
    "pkcs8", keyData,
    { name: "RSASSA-PKCS1-v1_5", hash: "SHA-256" },
    false, ["sign"],
  );

  const signature = await crypto.subtle.sign("RSASSA-PKCS1-v1_5", key, signInput);
  const sig64 = btoa(String.fromCharCode(...new Uint8Array(signature)))
    .replace(/\+/g, "-").replace(/\//g, "_").replace(/=/g, "");
  const jwt = `${header}.${claim}.${sig64}`;

  const resp = await fetch("https://oauth2.googleapis.com/token", {
    method: "POST",
    headers: { "Content-Type": "application/x-www-form-urlencoded" },
    body: `grant_type=urn:ietf:params:oauth:grant-type:jwt-bearer&assertion=${jwt}`,
  });

  const data = await resp.json();
  if (!data.access_token) {
    console.error(`[VERIFY-ID] OAuth token exchange failed: status=${resp.status} body=${JSON.stringify(data).slice(0, 300)}`);
    throw new Error(`OAuth token exchange failed (${resp.status}): ${data.error_description || data.error || "no access_token"}`);
  }
  return data.access_token;
}

// ── Vision API call ──────────────────────────────────────────────────────────
interface VisionResult {
  isDocument: boolean;
  textContent: string;
  confidence: number;
  isCropped: boolean;
}

// btoa(String.fromCharCode(...big-uint8array)) blows the V8 call stack
// (~64k arg limit on Deno, JPEGs are larger than that). Chunk-encode in
// 8KB slices instead — small enough to be safe everywhere, large enough
// to keep the loop count reasonable for a multi-MB image.
function bytesToBase64(bytes: Uint8Array): string {
  const CHUNK = 0x8000; // 32k
  let bin = "";
  for (let i = 0; i < bytes.length; i += CHUNK) {
    bin += String.fromCharCode.apply(
      null,
      bytes.subarray(i, i + CHUNK) as unknown as number[],
    );
  }
  return btoa(bin);
}

async function analyzeImage(imageBytes: Uint8Array, accessToken: string): Promise<VisionResult> {
  const base64 = bytesToBase64(imageBytes);
  console.log(`[VERIFY-ID] image bytes=${imageBytes.length}, base64 len=${base64.length}`);

  const resp = await fetch("https://vision.googleapis.com/v1/images:annotate", {
    method: "POST",
    headers: {
      "Authorization": `Bearer ${accessToken}`,
      "Content-Type": "application/json",
    },
    body: JSON.stringify({
      requests: [{
        image: { content: base64 },
        features: [
          { type: "DOCUMENT_TEXT_DETECTION" },
          { type: "OBJECT_LOCALIZATION", maxResults: 5 },
          { type: "CROP_HINTS" },
        ],
      }],
    }),
  });

  if (!resp.ok) {
    const errBody = await resp.text();
    console.error(`[VERIFY-ID] Vision API ${resp.status}: ${errBody.slice(0, 400)}`);
    throw new Error(`Vision API ${resp.status}: ${errBody.slice(0, 200)}`);
  }
  const data = await resp.json();
  if (data.responses?.[0]?.error) {
    console.error(`[VERIFY-ID] Vision per-request error: ${JSON.stringify(data.responses[0].error).slice(0, 400)}`);
  } else if (!data.responses?.[0]?.fullTextAnnotation && !data.responses?.[0]?.localizedObjectAnnotations) {
    // Empty response — log enough of the body to diagnose without leaking PII
    console.warn(`[VERIFY-ID] Vision returned no annotations. keys=${Object.keys(data.responses?.[0] ?? {}).join(',')} bodyHead=${JSON.stringify(data).slice(0, 300)}`);
  }
  const result = data.responses?.[0] ?? {};

  // OCR text
  const fullText = result.fullTextAnnotation?.text ?? "";
  const ocrConfidence = result.fullTextAnnotation?.pages?.[0]?.confidence ?? 0;

  // Document/ID detection via object localization
  const objects = result.localizedObjectAnnotations ?? [];
  const docLabels = ["document", "id card", "identification", "card", "license"];
  const isDocument = objects.some((o: { name: string }) =>
    docLabels.some((l) => o.name.toLowerCase().includes(l))
  ) || fullText.length > 50; // If OCR found substantial text, it's likely a document

  // Crop hints — check if document fills the frame
  const cropHints = result.cropHintsAnnotation?.cropHints ?? [];
  const isCropped = cropHints.length > 0 &&
    cropHints[0].confidence < 0.5; // Low confidence = image may be poorly framed

  return { isDocument, textContent: fullText, confidence: ocrConfidence, isCropped };
}

// ── Fuzzy name matching ──────────────────────────────────────────────────────
function normalize(s: string): string {
  return s
    .toLowerCase()
    .normalize("NFD").replace(/[\u0300-\u036f]/g, "") // strip accents
    .replace(/[^a-z\s]/g, "") // strip non-alpha
    .replace(/\s+/g, " ")
    .trim();
}

function levenshtein(a: string, b: string): number {
  const m = a.length, n = b.length;
  const d: number[][] = Array.from({ length: m + 1 }, () => Array(n + 1).fill(0));
  for (let i = 0; i <= m; i++) d[i][0] = i;
  for (let j = 0; j <= n; j++) d[0][j] = j;
  for (let i = 1; i <= m; i++) {
    for (let j = 1; j <= n; j++) {
      d[i][j] = Math.min(
        d[i - 1][j] + 1,
        d[i][j - 1] + 1,
        d[i - 1][j - 1] + (a[i - 1] === b[j - 1] ? 0 : 1),
      );
    }
  }
  return d[m][n];
}

function nameMatches(extractedText: string, beneficiaryName: string): boolean {
  const normBeneficiary = normalize(beneficiaryName);
  const normText = normalize(extractedText);

  // Check if all parts of beneficiary name appear in extracted text
  const parts = normBeneficiary.split(" ").filter((p) => p.length > 2);
  const allPartsFound = parts.every((part) => normText.includes(part));
  if (allPartsFound && parts.length >= 2) return true;

  // Fallback: extract lines and fuzzy-match each against beneficiary
  const lines = normText.split("\n").map((l) => l.trim()).filter(Boolean);
  for (const line of lines) {
    if (levenshtein(line, normBeneficiary) <= 3) return true;
    // Also check if line contains the name
    if (line.includes(normBeneficiary)) return true;
  }

  return false;
}

// ── Main handler ─────────────────────────────────────────────────────────────
serve(async (req) => {
  _req = req;
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders(req) });
  }

  // Hoisted so the catch handler can reset stuck-pending state
  const supabase = createClient(SUPABASE_URL, SUPABASE_SERVICE_ROLE_KEY);
  let business_id: string | undefined;

  try {
    // Auth check
    const authHeader = req.headers.get("authorization") ?? "";
    const token = authHeader.replace("Bearer ", "");
    const { data: { user }, error: authError } = await supabase.auth.getUser(token);

    if (authError || !user) {
      return json({ error: "No autenticado" }, 401);
    }

    // Vision API costs money — strict per-user limit
    if (!checkRateLimit(`verify:${user.id}`, 5, 3600_000)) {
      return json({ error: "Rate limit: max 5 verifications per hour" }, 429);
    }

    const body = await req.json();
    business_id = body.business_id;
    const beneficiary_name = body.beneficiary_name;

    if (!business_id || !beneficiary_name) {
      return json({ error: "business_id y beneficiary_name son requeridos" }, 400);
    }

    // Verify ownership
    const { data: biz, error: bizError } = await supabase
      .from("businesses")
      .select("id, owner_id, id_front_url, id_back_url, clabe")
      .eq("id", business_id)
      .single();

    if (bizError || !biz) {
      return json({ error: "Negocio no encontrado" }, 404);
    }
    if (biz.owner_id !== user.id) {
      return json({ error: "No autorizado" }, 403);
    }
    if (!biz.id_front_url || !biz.id_back_url) {
      return json({ error: "Imagenes de identificacion no encontradas" }, 400);
    }
    if (!biz.clabe) {
      return json({ error: "CLABE no registrada" }, 400);
    }

    // Set status to pending
    await supabase.from("businesses").update({
      id_verification_status: "pending",
    }).eq("id", business_id);

    // Download images from private bucket using URLs stored in businesses table
    const { data: frontData, error: frontErr } = await supabase.storage
      .from("salon-ids")
      .download(biz.id_front_url);
    const { data: backData, error: backErr } = await supabase.storage
      .from("salon-ids")
      .download(biz.id_back_url);

    if (frontErr || backErr || !frontData || !backData) {
      await supabase.from("businesses").update({
        id_verification_status: "rejected",
      }).eq("id", business_id);
      return json({
        verified: false,
        rejection_reason: "No se pudieron descargar las imagenes. Sube las fotos de nuevo.",
      });
    }

    // Get Vision API access token
    const accessToken = await getAccessToken();

    // Analyze both images
    const frontBytes = new Uint8Array(await frontData.arrayBuffer());
    const backBytes = new Uint8Array(await backData.arrayBuffer());

    const [frontResult, backResult] = await Promise.all([
      analyzeImage(frontBytes, accessToken),
      analyzeImage(backBytes, accessToken),
    ]);

    console.log(`[VERIFY-ID] Front: doc=${frontResult.isDocument}, conf=${frontResult.confidence}, cropped=${frontResult.isCropped}, text=${frontResult.textContent.length}chars`);
    console.log(`[VERIFY-ID] Back: doc=${backResult.isDocument}, conf=${backResult.confidence}, cropped=${backResult.isCropped}, text=${backResult.textContent.length}chars`);

    // Validation checks
    if (!frontResult.isDocument) {
      await supabase.from("businesses").update({ id_verification_status: "rejected" }).eq("id", business_id);
      return json({
        verified: false,
        rejection_reason: "La imagen del frente no parece ser una identificacion oficial",
      });
    }

    if (frontResult.isCropped) {
      await supabase.from("businesses").update({ id_verification_status: "rejected" }).eq("id", business_id);
      return json({
        verified: false,
        rejection_reason: "La imagen esta cortada — asegurate que se vean las 4 esquinas",
      });
    }

    if (frontResult.confidence < 0.7) {
      await supabase.from("businesses").update({ id_verification_status: "rejected" }).eq("id", business_id);
      return json({
        verified: false,
        rejection_reason: "No se pudo leer el texto — toma la foto con buena iluminacion",
      });
    }

    // Name matching — check front (where the name is on INE)
    const combinedText = frontResult.textContent + "\n" + backResult.textContent;
    if (!nameMatches(combinedText, beneficiary_name)) {
      await supabase.from("businesses").update({ id_verification_status: "rejected" }).eq("id", business_id);
      return json({
        verified: false,
        extracted_name: frontResult.textContent.split("\n").slice(0, 3).join(" "),
        rejection_reason: "El nombre en la identificacion no coincide con el nombre del beneficiario",
      });
    }

    // All checks passed
    await supabase.from("businesses").update({
      id_verification_status: "verified",
      id_verified_at: new Date().toISOString(),
      banking_complete: true,
    }).eq("id", business_id);

    // Detect bank from CLABE
    const bankPrefix = biz.clabe.substring(0, 3);
    const bankName = CLABE_BANKS[bankPrefix] || "Banco desconocido";
    await supabase.from("businesses").update({ bank_name: bankName }).eq("id", business_id);

    console.log(`[VERIFY-ID] Business ${business_id} VERIFIED. Bank: ${bankName}`);

    return json({
      verified: true,
      bank_name: bankName,
      confidence: frontResult.confidence,
    });

  } catch (err) {
    console.error("[VERIFY-ID] Error:", err);
    // Reset stuck-pending state so the salon can retry. Without this,
    // an upstream failure (Vision API timeout, OAuth token fetch, etc.)
    // leaves id_verification_status='pending' forever and the owner
    // has no way to re-trigger verification.
    if (business_id) {
      try {
        await supabase
          .from("businesses")
          .update({ id_verification_status: "rejected" })
          .eq("id", business_id)
          .eq("id_verification_status", "pending");
      } catch (resetErr) {
        console.error("[VERIFY-ID] Failed to reset pending status:", resetErr);
      }
    }
    return json({
      error: "Error interno al verificar identificacion. Intenta de nuevo.",
      retryable: true,
    }, 500);
  }
});

function json(body: unknown, status = 200) {
  return new Response(JSON.stringify(body), {
    status,
    headers: { ...corsHeaders(_req), "Content-Type": "application/json" },
  });
}
