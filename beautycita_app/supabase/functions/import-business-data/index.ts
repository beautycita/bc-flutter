// import-business-data — universal smart importer for client lists
// from any salon-SaaS export (Fresha / Booksy / Vagaro / Square / Acuity /
// GlossGenius / Schedulicity / Mangomint / arbitrary CSV / JSON / XML).
//
// Auto-detects file format from content signature, parses to records, then
// scores each header against a multilingual semantic dictionary to map
// onto BeautyCita's business_clients schema. Source-specific signatures
// (e.g. Square's 'Reference ID', GlossGenius's 'Banned' column) are used
// only as a friendly "Detectado: Fresha" badge — they don't gate parsing.
//
// Two actions:
//   preview → parse + map + return first 10 mapped rows + counts + issues
//   commit  → write to business_clients (phone-based dedup), record audit
//
// Authz: caller must own the target business.

import { serve } from "https://deno.land/std@0.224.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2.39.7";

const SUPABASE_URL = Deno.env.get("SUPABASE_URL")!;
const SUPABASE_SERVICE_ROLE_KEY = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!;
const SUPABASE_ANON_KEY = Deno.env.get("SUPABASE_ANON_KEY")!;

const ALLOWED_ORIGINS = [
  "https://beautycita.com",
  "https://debug.beautycita.com",
  "http://localhost:3000",
];

function corsHeaders(req: Request): Record<string, string> {
  const o = req.headers.get("Origin") ?? "";
  return {
    "Access-Control-Allow-Origin": ALLOWED_ORIGINS.includes(o) ? o : ALLOWED_ORIGINS[0],
    "Access-Control-Allow-Methods": "POST, OPTIONS",
    "Access-Control-Allow-Headers": "authorization, content-type, x-client-info, apikey",
  };
}

function json(body: unknown, status = 200, req?: Request): Response {
  return new Response(JSON.stringify(body), {
    status,
    headers: { ...(req ? corsHeaders(req) : {}), "Content-Type": "application/json" },
  });
}

// ─── Semantic field dictionary ──────────────────────────────────────────────
// Synonyms per BC field. Multilingual (EN + ES). Lowercase, normalized.
// Match strategy: exact, contains, then Levenshtein-1 fuzzy.
const FIELD_SYNONYMS: Record<string, string[]> = {
  first_name: [
    "first name", "firstname", "first", "given name", "givenname",
    "nombre", "primer nombre", "name first", "fname",
  ],
  last_name: [
    "last name", "lastname", "last", "surname", "family name", "familyname",
    "apellido", "apellidos", "name last", "lname", "second name",
  ],
  full_name: [
    "name", "full name", "fullname", "client name", "customer name",
    "contact name", "nombre completo", "cliente",
  ],
  email: [
    "email", "e-mail", "mail", "email address", "correo",
    "correo electronico", "correo electrónico",
  ],
  phone: [
    "phone", "phone number", "mobile", "mobile phone", "cell", "cellphone",
    "cell phone", "telefono", "teléfono", "celular", "tel", "movil", "móvil",
    "mobil", "whatsapp",
  ],
  birthday: [
    "birthday", "birth date", "birthdate", "date of birth", "dob", "born",
    "fecha de nacimiento", "fecha nacimiento", "cumpleanos", "cumpleaños",
    "nacimiento",
  ],
  gender: ["gender", "sex", "genero", "género"],
  address: [
    "address", "street address", "street", "addr", "direccion", "dirección",
    "calle",
  ],
  city: ["city", "ciudad", "town", "address-city"],
  state: ["state", "province", "estado", "provincia", "address-state"],
  zip: [
    "zip", "zip code", "postal code", "postal", "postcode", "post code",
    "codigo postal", "código postal", "cp", "address-postcode",
    "address-postal-code",
  ],
  country: ["country", "pais", "país", "address-country"],
  notes: [
    "notes", "note", "client notes", "customer notes", "comments", "comment",
    "notas", "comentarios", "observaciones",
  ],
  tags: [
    "tags", "tag", "labels", "label", "groups", "group names", "etiquetas",
  ],
};

function normalize(s: string): string {
  return s
    .toLowerCase()
    .trim()
    .normalize("NFD")
    .replace(/[̀-ͯ]/g, "") // strip accents
    .replace(/[_-]+/g, " ")
    .replace(/\s+/g, " ");
}

function levenshtein(a: string, b: string): number {
  if (a === b) return 0;
  const m = a.length, n = b.length;
  if (m === 0) return n;
  if (n === 0) return m;
  const dp: number[] = new Array(n + 1);
  for (let j = 0; j <= n; j++) dp[j] = j;
  for (let i = 1; i <= m; i++) {
    let prev = dp[0];
    dp[0] = i;
    for (let j = 1; j <= n; j++) {
      const tmp = dp[j];
      dp[j] = a[i - 1] === b[j - 1]
        ? prev
        : 1 + Math.min(prev, dp[j], dp[j - 1]);
      prev = tmp;
    }
  }
  return dp[n];
}

/** Score a header against all known fields. Returns {field, score} or null. */
function scoreHeader(header: string): { field: string; score: number } | null {
  const norm = normalize(header);
  if (!norm) return null;

  let best: { field: string; score: number } | null = null;

  for (const [field, synonyms] of Object.entries(FIELD_SYNONYMS)) {
    for (const syn of synonyms) {
      if (norm === syn) {
        // Exact match — best possible
        if (!best || best.score < 100) best = { field, score: 100 };
      } else if (norm.includes(syn) || syn.includes(norm)) {
        const s = 80 - Math.abs(norm.length - syn.length);
        if (!best || s > best.score) best = { field, score: s };
      } else {
        const dist = levenshtein(norm, syn);
        if (dist <= 1 && Math.max(norm.length, syn.length) >= 4) {
          const s = 60;
          if (!best || s > best.score) best = { field, score: s };
        }
      }
    }
  }

  return best && best.score >= 50 ? best : null;
}

/** Build a header → bc_field map from a row of headers. */
function mapHeaders(headers: string[]): Record<string, string> {
  const map: Record<string, string> = {};
  const claimed = new Set<string>();

  // First pass: exact matches win regardless of order
  const scored = headers.map((h) => ({ header: h, match: scoreHeader(h) }));
  scored.sort((a, b) => (b.match?.score ?? 0) - (a.match?.score ?? 0));

  for (const { header, match } of scored) {
    if (!match) continue;
    if (claimed.has(match.field)) continue;
    map[header] = match.field;
    claimed.add(match.field);
  }
  return map;
}

// ─── Format detection + parsing ─────────────────────────────────────────────

type Format = "csv" | "json" | "xml" | "tsv";

function detectFormat(text: string, fileName?: string): Format {
  const sample = text.slice(0, 4096).trim();
  if (sample.startsWith("{") || sample.startsWith("[")) return "json";
  if (sample.startsWith("<?xml") || sample.startsWith("<")) return "xml";
  // Tab-separated if first line has tabs and no commas
  const firstLine = sample.split(/\r?\n/)[0] ?? "";
  if (firstLine.includes("\t") && !firstLine.includes(",")) return "tsv";
  // Filename hint as tiebreaker
  if (fileName?.toLowerCase().endsWith(".json")) return "json";
  if (fileName?.toLowerCase().endsWith(".xml")) return "xml";
  if (fileName?.toLowerCase().endsWith(".tsv")) return "tsv";
  return "csv";
}

function parseDelimited(text: string, delimiter: string): Record<string, string>[] {
  const lines = text.replace(/^﻿/, "").split(/\r?\n/);
  if (lines.length === 0) return [];

  const splitLine = (line: string): string[] => {
    const fields: string[] = [];
    let cur = "";
    let inQuotes = false;
    for (let i = 0; i < line.length; i++) {
      const ch = line[i];
      if (inQuotes) {
        if (ch === '"') {
          if (line[i + 1] === '"') { cur += '"'; i++; }
          else { inQuotes = false; }
        } else cur += ch;
      } else {
        if (ch === '"') inQuotes = true;
        else if (ch === delimiter) { fields.push(cur); cur = ""; }
        else cur += ch;
      }
    }
    fields.push(cur);
    return fields;
  };

  const headers = splitLine(lines[0]).map((h) => h.trim());
  const out: Record<string, string>[] = [];
  for (let i = 1; i < lines.length; i++) {
    if (!lines[i].trim()) continue;
    const cells = splitLine(lines[i]);
    const row: Record<string, string> = {};
    for (let j = 0; j < headers.length; j++) {
      row[headers[j]] = (cells[j] ?? "").trim();
    }
    out.push(row);
  }
  return out;
}

function parseJson(text: string): Record<string, string>[] {
  const parsed = JSON.parse(text);
  // Accept either a top-level array of objects, or {clients:[...]} / {data:[...]}
  let arr: unknown = parsed;
  if (!Array.isArray(arr) && typeof arr === "object" && arr !== null) {
    for (const key of ["clients", "customers", "data", "records", "items", "results"]) {
      const v = (arr as Record<string, unknown>)[key];
      if (Array.isArray(v)) { arr = v; break; }
    }
  }
  if (!Array.isArray(arr)) return [];
  return (arr as unknown[]).map((row) => {
    if (typeof row !== "object" || row === null) return {};
    const out: Record<string, string> = {};
    for (const [k, v] of Object.entries(row as Record<string, unknown>)) {
      out[k] = v == null ? "" : String(v);
    }
    return out;
  });
}

/** Lightweight XML → records. Treats first repeated element as the row container. */
function parseXml(text: string): Record<string, string>[] {
  const matches = text.match(/<([A-Za-z][\w-]*)\b[^>]*>[\s\S]*?<\/\1>/g);
  if (!matches) return [];
  // Group by root element name; pick the most repeated
  const counts: Record<string, number> = {};
  for (const m of matches) {
    const name = m.match(/^<([A-Za-z][\w-]*)/)?.[1] ?? "";
    counts[name] = (counts[name] ?? 0) + 1;
  }
  const rowName = Object.entries(counts).sort((a, b) => b[1] - a[1])[0]?.[0];
  if (!rowName) return [];
  const rowRe = new RegExp(`<${rowName}\\b[^>]*>([\\s\\S]*?)<\\/${rowName}>`, "g");
  const fieldRe = /<([A-Za-z][\w-]*)\b[^>]*>([\s\S]*?)<\/\1>/g;
  const out: Record<string, string>[] = [];
  let rm: RegExpExecArray | null;
  while ((rm = rowRe.exec(text)) != null) {
    const inner = rm[1];
    const row: Record<string, string> = {};
    let fm: RegExpExecArray | null;
    while ((fm = fieldRe.exec(inner)) != null) {
      row[fm[1]] = fm[2].trim().replace(/<!\[CDATA\[(.*?)\]\]>/s, "$1");
    }
    if (Object.keys(row).length > 0) out.push(row);
  }
  return out;
}

function parseAny(text: string, fileName?: string): { format: Format; records: Record<string, string>[] } {
  const format = detectFormat(text, fileName);
  let records: Record<string, string>[] = [];
  switch (format) {
    case "json": records = parseJson(text); break;
    case "xml":  records = parseXml(text); break;
    case "tsv":  records = parseDelimited(text, "\t"); break;
    default:     records = parseDelimited(text, ","); break;
  }
  return { format, records };
}

// ─── Source fingerprint (UI badge only, never gates parsing) ────────────────
function fingerprintSource(headers: string[]): string {
  const norm = headers.map(normalize);
  const has = (s: string) => norm.includes(s);
  if (has("banned") && has("name") && has("phone")) return "GlossGenius";
  if (has("date last seen") || has("middle name")) return "Schedulicity";
  if (has("reference id") && has("phone number")) return "Square";
  if (has("mobile phone") && has("client notes")) return "Fresha";
  if (has("days since last appointment")) return "Acuity";
  if (norm.some((h) => h.startsWith("address "))) return "Square";
  return "Genérico";
}

// ─── Row → BC client transform ──────────────────────────────────────────────
interface MappedClient {
  full_name: string;
  email: string | null;
  phone: string | null;
  birthday: string | null;
  notes: string | null;
  raw_row_index: number;
  issue?: string;
}

function normalizePhoneMx(raw: string): string | null {
  if (!raw) return null;
  const digits = raw.replace(/\D/g, "");
  if (digits.length === 0) return null;
  if (digits.length >= 12 && digits.startsWith("521")) return "+" + digits;
  if (digits.length === 12 && digits.startsWith("52")) return "+521" + digits.slice(2);
  if (digits.length === 11 && digits.startsWith("1")) return "+" + digits; // US/CA
  if (digits.length === 10) return "+521" + digits; // assume MX local
  if (digits.length >= 7) return "+" + digits;
  return null;
}

function normalizeBirthday(raw: string): string | null {
  if (!raw) return null;
  const trimmed = raw.trim();
  // ISO YYYY-MM-DD
  let m = trimmed.match(/^(\d{4})[-/.](\d{1,2})[-/.](\d{1,2})$/);
  if (m) {
    const [, y, mo, d] = m;
    return `${y}-${mo.padStart(2, "0")}-${d.padStart(2, "0")}`;
  }
  // DD/MM/YYYY or DD-MM-YYYY (most platforms outside US)
  m = trimmed.match(/^(\d{1,2})[-/.](\d{1,2})[-/.](\d{4})$/);
  if (m) {
    const [, d, mo, y] = m;
    const day = parseInt(d, 10);
    const month = parseInt(mo, 10);
    // If first part > 12, must be DD/MM. If second part > 12, must be MM/DD.
    if (day > 12) return `${y}-${mo.padStart(2, "0")}-${d.padStart(2, "0")}`;
    if (month > 12) return `${y}-${d.padStart(2, "0")}-${mo.padStart(2, "0")}`;
    // Ambiguous — default to DD/MM (international majority)
    return `${y}-${mo.padStart(2, "0")}-${d.padStart(2, "0")}`;
  }
  return null;
}

function buildClient(
  row: Record<string, string>,
  headerMap: Record<string, string>,
  rowIdx: number,
): MappedClient {
  const fields: Record<string, string> = {};
  for (const [hdr, val] of Object.entries(row)) {
    const bcField = headerMap[hdr];
    if (bcField) {
      // First non-empty value wins (in case multiple headers map to the same field)
      if (!fields[bcField] && val) fields[bcField] = val;
    }
  }

  // Build full_name from parts if needed
  let fullName = fields.full_name ?? "";
  if (!fullName) {
    const parts = [fields.first_name, fields.last_name].filter((s) => !!s);
    fullName = parts.join(" ").trim();
  }

  const phone = normalizePhoneMx(fields.phone ?? "");
  const email = (fields.email ?? "").trim().toLowerCase() || null;
  const birthday = normalizeBirthday(fields.birthday ?? "");

  // Combine address parts into notes if present and no other notes
  let notes = fields.notes ?? "";
  const addressParts = [
    fields.address, fields.city, fields.state, fields.zip, fields.country,
  ].filter((s) => !!s);
  if (addressParts.length > 0) {
    const addr = "Direccion: " + addressParts.join(", ");
    notes = notes ? `${notes}\n${addr}` : addr;
  }

  const client: MappedClient = {
    full_name: fullName,
    email,
    phone,
    birthday,
    notes: notes || null,
    raw_row_index: rowIdx,
  };

  if (!fullName && !email && !phone) {
    client.issue = "Fila sin nombre, email ni teléfono — saltada";
  } else if (!phone && !email) {
    client.issue = "Sin teléfono ni email — no se puede deduplicar";
  }

  return client;
}

// ─── Main handler ───────────────────────────────────────────────────────────

serve(async (req) => {
  if (req.method === "OPTIONS") {
    return new Response(null, { headers: corsHeaders(req) });
  }
  if (req.method !== "POST") {
    return json({ error: "POST only" }, 405, req);
  }

  const auth = req.headers.get("Authorization") ?? "";
  const token = auth.startsWith("Bearer ") ? auth.slice(7) : "";
  if (!token) return json({ error: "Unauthorized" }, 401, req);

  const userClient = createClient(SUPABASE_URL, SUPABASE_ANON_KEY, {
    global: { headers: { Authorization: `Bearer ${token}` } },
  });
  const { data: { user }, error: authErr } = await userClient.auth.getUser();
  if (authErr || !user) return json({ error: "Unauthorized" }, 401, req);

  const service = createClient(SUPABASE_URL, SUPABASE_SERVICE_ROLE_KEY);

  let body: Record<string, unknown>;
  try {
    body = await req.json();
  } catch {
    return json({ error: "Invalid JSON body" }, 400, req);
  }

  const action = body.action as string | undefined;
  const businessId = body.business_id as string | undefined;
  const fileName = (body.file_name as string | undefined) ?? "";
  const text = body.text as string | undefined;

  if (!action || !businessId || !text) {
    return json({ error: "action, business_id, text required" }, 400, req);
  }

  // Authz: user must own the business
  const { data: biz } = await service
    .from("businesses")
    .select("id, owner_id")
    .eq("id", businessId)
    .single();
  if (!biz || biz.owner_id !== user.id) {
    return json({ error: "forbidden" }, 403, req);
  }

  // Parse + map (shared by preview + commit)
  const { format, records } = parseAny(text, fileName);
  if (records.length === 0) {
    return json({ error: "No se encontraron filas en el archivo" }, 400, req);
  }
  const headers = Object.keys(records[0]);
  const headerMap = mapHeaders(headers);
  const sourceLabel = fingerprintSource(headers);

  const mapped: MappedClient[] = records.map((r, i) => buildClient(r, headerMap, i));

  if (action === "preview") {
    return json({
      detected_format: format,
      detected_source: sourceLabel,
      total_rows: records.length,
      headers,
      header_map: headerMap,
      preview_rows: mapped.slice(0, 10),
      issues_count: mapped.filter((m) => m.issue).length,
      mappable_count: mapped.filter((m) => !m.issue).length,
    }, 200, req);
  }

  if (action === "commit") {
    let inserted = 0;
    let updated = 0;
    let skipped = 0;
    const errors: { row_idx: number; reason: string }[] = [];

    for (const m of mapped) {
      if (m.issue) { skipped++; errors.push({ row_idx: m.raw_row_index, reason: m.issue }); continue; }

      // Dedup by phone (last 10 digits) within this business
      const phoneTail = m.phone ? m.phone.replace(/\D/g, "").slice(-10) : null;
      let existingId: string | null = null;
      if (phoneTail) {
        const { data: existing } = await service
          .from("business_clients")
          .select("id")
          .eq("business_id", businessId)
          .ilike("phone", `%${phoneTail}`)
          .limit(1)
          .maybeSingle();
        if (existing) existingId = existing.id;
      }
      if (!existingId && m.email) {
        const { data: existing } = await service
          .from("business_clients")
          .select("id")
          .eq("business_id", businessId)
          .ilike("email", m.email)
          .limit(1)
          .maybeSingle();
        if (existing) existingId = existing.id;
      }

      const payload: Record<string, unknown> = {
        business_id: businessId,
        full_name: m.full_name,
        email: m.email,
        phone: m.phone,
        birthday: m.birthday,
        notes: m.notes,
      };

      if (existingId) {
        const { error } = await service
          .from("business_clients")
          .update(payload)
          .eq("id", existingId);
        if (error) { skipped++; errors.push({ row_idx: m.raw_row_index, reason: error.message }); }
        else updated++;
      } else {
        const { error } = await service
          .from("business_clients")
          .insert(payload);
        if (error) { skipped++; errors.push({ row_idx: m.raw_row_index, reason: error.message }); }
        else inserted++;
      }
    }

    // Audit log
    await service.from("business_imports").insert({
      business_id: businessId,
      imported_by: user.id,
      source_hint: sourceLabel,
      detected_format: format,
      entity: "clients",
      file_name: fileName || null,
      total_rows: records.length,
      imported_count: inserted,
      updated_count: updated,
      skipped_count: skipped,
      field_map: headerMap,
      errors: errors.slice(0, 50), // cap
      status: "committed",
    });

    return json({
      detected_format: format,
      detected_source: sourceLabel,
      total_rows: records.length,
      inserted_count: inserted,
      updated_count: updated,
      skipped_count: skipped,
      errors: errors.slice(0, 20),
    }, 200, req);
  }

  return json({ error: `Unknown action: ${action}` }, 400, req);
});
