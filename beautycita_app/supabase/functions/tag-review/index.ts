// tag-review edge function
// Triggered after a review is inserted. Extracts keywords, computes sentiment,
// detects quality signals, and inserts a review_tags row with a composite
// snippet_quality_score for fast retrieval by curate-results.

import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

const supabaseUrl = Deno.env.get("SUPABASE_URL")!;
const serviceKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!;

// ---------------------------------------------------------------------------
// Keyword dictionaries per service category (Spanish beauty terms)
// ---------------------------------------------------------------------------

const CATEGORY_KEYWORDS: Record<string, string[]> = {
  unas: [
    "uñas", "manicure", "pedicure", "gel", "acrílico", "acrilico", "esmalte",
    "nail", "relleno", "retiro", "francés", "frances", "dip", "parafina",
    "cutícula", "cuticula", "lima", "brillo",
  ],
  cabello: [
    "cabello", "pelo", "corte", "tinte", "color", "mechas", "balayage",
    "ombre", "raíz", "raiz", "keratina", "alisado", "blowout", "planchado",
    "ondas", "recogido", "trenzas", "extensiones", "secado",
  ],
  pestanas: [
    "pestañas", "pestanas", "lashes", "extensiones", "volumen", "clásicas",
    "clasicas", "híbridas", "hibridas", "lifting", "relleno", "mega",
  ],
  cejas: [
    "cejas", "microblading", "micropigmentación", "micropigmentacion",
    "laminado", "henna", "diseño", "diseno",
  ],
  maquillaje: [
    "maquillaje", "makeup", "base", "contorno", "labios", "ojos", "novia",
    "evento", "editorial", "prueba",
  ],
  facial: [
    "facial", "limpieza", "hidratación", "hidratacion", "piel", "acné",
    "acne", "poros", "mascarilla", "exfoliación", "exfoliacion", "hidrafacial",
  ],
  corporal: [
    "masaje", "relajante", "descontracturante", "piedras", "reflexología",
    "reflexologia", "drenaje", "cuerpo", "espalda", "prenatal",
  ],
  depilacion: [
    "depilación", "depilacion", "cera", "láser", "laser", "hilo", "sugaring",
    "bikini", "axilas", "piernas",
  ],
  barberia: [
    "barba", "barbería", "barberia", "afeitado", "rasurado", "navaja",
  ],
};

// Positive sentiment words (Spanish)
const POSITIVE_WORDS = [
  "excelente", "increíble", "increible", "perfecta", "perfecto", "maravillosa",
  "maravilloso", "hermosa", "hermoso", "encanta", "encantó", "encanto", "amo",
  "feliz", "contenta", "contento", "recomiendo", "mejor", "genial", "divina",
  "divino", "impecable", "profesional", "espectacular", "brutal", "wow",
  "fantástica", "fantastica", "ideal", "preciosa", "precioso", "quedaron",
  "quedo", "quedó", "salvó", "salvo", "super", "súper",
];

// Outcome indicators
const OUTCOME_PHRASES = [
  "me quedaron", "me quedo", "me quedó", "quedaron perfecta",
  "quedaron increíble", "el resultado", "se ve", "se ven", "lucen",
  "luce", "duran", "dura", "aguantan", "no se despegan",
];

// Staff mention patterns
const STAFF_PATTERNS = [
  /\b(la|el|con)\s+[A-ZÁÉÍÓÚÑ][a-záéíóúñ]{2,}\b/,
  /\b(estilista|especialista|chica|chico|señora|joven|doctor|doctora)\b/i,
];

Deno.serve(async (req: Request) => {
  if (req.method === "OPTIONS") {
    return new Response(null, {
      headers: {
        "Access-Control-Allow-Origin": "*",
        "Access-Control-Allow-Methods": "POST",
        "Access-Control-Allow-Headers": "authorization, content-type, x-client-info, apikey",
      },
    });
  }

  if (req.method !== "POST") {
    return new Response(JSON.stringify({ error: "Method not allowed" }), {
      status: 405,
      headers: { "Content-Type": "application/json" },
    });
  }

  // Auth check
  const authHeader = req.headers.get("authorization") ?? "";
  const authToken = authHeader.replace("Bearer ", "");
  const supabaseAuth = createClient(supabaseUrl, serviceKey);
  const { data: { user }, error: authError } = await supabaseAuth.auth.getUser(authToken);
  if (authError || !user) {
    return new Response(JSON.stringify({ error: "Unauthorized" }), {
      status: 401,
      headers: { "Content-Type": "application/json" },
    });
  }

  try {
    const body = await req.json();

    // Supports both direct call and webhook payload
    const record = body.record ?? body;
    const reviewId: string = record.id ?? record.review_id;
    const comment: string = record.comment ?? "";
    const serviceType: string | null = record.service_type ?? null;
    const staffId: string | null = record.staff_id ?? null;

    if (!reviewId) {
      return new Response(
        JSON.stringify({ error: "review id required" }),
        { status: 400, headers: { "Content-Type": "application/json" } },
      );
    }

    // Skip if no comment text to analyze
    if (!comment || comment.trim().length === 0) {
      return new Response(
        JSON.stringify({ skipped: true, reason: "no comment text" }),
        { status: 200, headers: { "Content-Type": "application/json" } },
      );
    }

    const text = comment.toLowerCase().trim();
    const words = text.split(/\s+/);
    const wordCount = words.length;

    // --- Keyword extraction ---
    const detectedKeywords: string[] = [];
    for (const [, categoryWords] of Object.entries(CATEGORY_KEYWORDS)) {
      for (const kw of categoryWords) {
        if (text.includes(kw) && !detectedKeywords.includes(kw)) {
          detectedKeywords.push(kw);
        }
      }
    }

    // --- Sentiment score (0.0 to 1.0) ---
    let sentimentHits = 0;
    for (const pw of POSITIVE_WORDS) {
      if (text.includes(pw)) sentimentHits++;
    }
    // Exclamation marks add minor boost
    const exclamations = (comment.match(/!/g) || []).length;
    const sentimentRaw =
      (sentimentHits / Math.max(POSITIVE_WORDS.length * 0.15, 1)) +
      (exclamations * 0.05);
    const sentimentScore = Math.min(1.0, Math.max(0.0, sentimentRaw));

    // --- Outcome detection ---
    const mentionsOutcome = OUTCOME_PHRASES.some((p) => text.includes(p));

    // --- Staff mention detection ---
    let mentionsStaff = false;
    for (const pattern of STAFF_PATTERNS) {
      if (pattern.test(comment)) {
        mentionsStaff = true;
        break;
      }
    }
    // Also check if staff name appears (if we had it; for now pattern-based)

    // --- Snippet quality score (composite, 0.0 to 1.0) ---
    // Components:
    //   wordCount: 20+ = 0.2, 50+ = 0.3, 100+ = 0.4
    //   sentiment: raw score * 0.3
    //   outcome flag: +0.15
    //   staff mention: +0.10
    //   keyword richness: +0.05 per keyword (max 0.15)
    let qualityScore = 0;

    // Word count component
    if (wordCount >= 100) qualityScore += 0.35;
    else if (wordCount >= 50) qualityScore += 0.25;
    else if (wordCount >= 20) qualityScore += 0.15;
    else qualityScore += 0.05;

    // Sentiment component
    qualityScore += sentimentScore * 0.30;

    // Boolean signals
    if (mentionsOutcome) qualityScore += 0.15;
    if (mentionsStaff) qualityScore += 0.10;

    // Keyword richness
    qualityScore += Math.min(0.15, detectedKeywords.length * 0.05);

    qualityScore = Math.min(1.0, Math.max(0.0, qualityScore));

    // --- Insert into review_tags ---
    const supabase = createClient(supabaseUrl, serviceKey);

    const { error } = await supabase
      .from("review_tags")
      .upsert(
        {
          review_id: reviewId,
          service_type: serviceType,
          keywords: detectedKeywords.length > 0 ? detectedKeywords : null,
          sentiment_score: Number(sentimentScore.toFixed(2)),
          snippet_quality_score: Number(qualityScore.toFixed(2)),
          mentions_staff: mentionsStaff,
          mentions_outcome: mentionsOutcome,
          word_count: wordCount,
        },
        { onConflict: "review_id" },
      );

    if (error) {
      console.error("Failed to upsert review_tags:", error);
      return new Response(
        JSON.stringify({ error: error.message }),
        { status: 500, headers: { "Content-Type": "application/json" } },
      );
    }

    return new Response(
      JSON.stringify({
        tagged: true,
        review_id: reviewId,
        word_count: wordCount,
        keywords: detectedKeywords,
        sentiment_score: Number(sentimentScore.toFixed(2)),
        snippet_quality_score: Number(qualityScore.toFixed(2)),
        mentions_staff: mentionsStaff,
        mentions_outcome: mentionsOutcome,
      }),
      { status: 200, headers: { "Content-Type": "application/json" } },
    );
  } catch (err) {
    console.error("tag-review error:", err);
    return new Response(
      JSON.stringify({ error: String(err) }),
      { status: 500, headers: { "Content-Type": "application/json" } },
    );
  }
});
