# Admin Salones & Pipeline Screens — Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Replace the current salon management screen with two purpose-built admin screens: an intelligent Salones search with full admin control, and a Pipeline lead control center with multi-channel outreach tracking and data export.

**Architecture:** Supabase RPC functions handle intelligent search (pg_trgm fuzzy matching + city alias resolution). Flutter screens use Riverpod providers. Export service generates CSV/Excel/JSON/PDF/vCard files locally, shared via share_plus. Pipeline absorbs message_salons_screen functionality.

**Tech Stack:** Flutter + Riverpod, Supabase PostgreSQL (pg_trgm), Dart packages: csv, syncfusion_flutter_xlsio, pdf, share_plus (existing)

**Design Spec:** `docs/plans/2026-02-28-admin-salones-pipeline-design.md`

---

## Task 1: Database Migration — pg_trgm, City Aliases, Outreach Log Update

**Files:**
- Create: `supabase/migrations/20260228000000_admin_search_infrastructure.sql`

**Step 1: Write the migration SQL**

```sql
-- =============================================================================
-- Admin search infrastructure: pg_trgm, city aliases, outreach log channels
-- =============================================================================

-- 1. Enable pg_trgm for fuzzy text search
CREATE EXTENSION IF NOT EXISTS pg_trgm;

-- 2. City aliases table for intelligent search
CREATE TABLE IF NOT EXISTS public.city_aliases (
  alias   text PRIMARY KEY,
  city    text NOT NULL,
  state   text,
  country text NOT NULL DEFAULT 'MX'
);

COMMENT ON TABLE public.city_aliases IS 'Maps informal city names/abbreviations to canonical city+state+country for admin search.';

-- Seed with common aliases
INSERT INTO public.city_aliases (alias, city, state, country) VALUES
  -- Mexico
  ('gdl', 'Guadalajara', 'Jalisco', 'MX'),
  ('guada', 'Guadalajara', 'Jalisco', 'MX'),
  ('guadalajara', 'Guadalajara', 'Jalisco', 'MX'),
  ('cdmx', 'Ciudad de Mexico', 'Ciudad de Mexico', 'MX'),
  ('df', 'Ciudad de Mexico', 'Ciudad de Mexico', 'MX'),
  ('mexico city', 'Ciudad de Mexico', 'Ciudad de Mexico', 'MX'),
  ('cabo', 'Cabo San Lucas', 'Baja California Sur', 'MX'),
  ('san lucas', 'Cabo San Lucas', 'Baja California Sur', 'MX'),
  ('los cabos', 'Cabo San Lucas', 'Baja California Sur', 'MX'),
  ('pvr', 'Puerto Vallarta', 'Jalisco', 'MX'),
  ('vallarta', 'Puerto Vallarta', 'Jalisco', 'MX'),
  ('mty', 'Monterrey', 'Nuevo Leon', 'MX'),
  ('monterrey', 'Monterrey', 'Nuevo Leon', 'MX'),
  ('tj', 'Tijuana', 'Baja California', 'MX'),
  ('tijuana', 'Tijuana', 'Baja California', 'MX'),
  ('cancun', 'Cancun', 'Quintana Roo', 'MX'),
  ('merida', 'Merida', 'Yucatan', 'MX'),
  ('puebla', 'Puebla', 'Puebla', 'MX'),
  ('queretaro', 'Queretaro', 'Queretaro', 'MX'),
  ('qro', 'Queretaro', 'Queretaro', 'MX'),
  ('leon', 'Leon', 'Guanajuato', 'MX'),
  ('slp', 'San Luis Potosi', 'San Luis Potosi', 'MX'),
  ('playa', 'Playa del Carmen', 'Quintana Roo', 'MX'),
  ('playa del carmen', 'Playa del Carmen', 'Quintana Roo', 'MX'),
  -- USA
  ('htown', 'Houston', 'Texas', 'US'),
  ('hou', 'Houston', 'Texas', 'US'),
  ('houston', 'Houston', 'Texas', 'US'),
  ('htx', 'Houston', 'Texas', 'US'),
  ('dallas', 'Dallas', 'Texas', 'US'),
  ('dfw', 'Dallas', 'Texas', 'US'),
  ('sa', 'San Antonio', 'Texas', 'US'),
  ('san antonio', 'San Antonio', 'Texas', 'US'),
  ('satx', 'San Antonio', 'Texas', 'US'),
  ('austin', 'Austin', 'Texas', 'US'),
  ('atx', 'Austin', 'Texas', 'US'),
  ('la', 'Los Angeles', 'California', 'US'),
  ('los angeles', 'Los Angeles', 'California', 'US'),
  ('nyc', 'New York', 'New York', 'US'),
  ('new york', 'New York', 'New York', 'US'),
  ('chi', 'Chicago', 'Illinois', 'US'),
  ('chicago', 'Chicago', 'Illinois', 'US'),
  ('miami', 'Miami', 'Florida', 'US'),
  ('phx', 'Phoenix', 'Arizona', 'US'),
  ('phoenix', 'Phoenix', 'Arizona', 'US'),
  ('vegas', 'Las Vegas', 'Nevada', 'US'),
  ('lv', 'Las Vegas', 'Nevada', 'US'),
  ('las vegas', 'Las Vegas', 'Nevada', 'US'),
  ('denver', 'Denver', 'Colorado', 'US'),
  ('seattle', 'Seattle', 'Washington', 'US'),
  ('portland', 'Portland', 'Oregon', 'US'),
  ('atlanta', 'Atlanta', 'Georgia', 'US'),
  ('atl', 'Atlanta', 'Georgia', 'US')
ON CONFLICT (alias) DO NOTHING;

-- 3. Add trigram indexes for fuzzy search on businesses
CREATE INDEX IF NOT EXISTS idx_businesses_name_trgm
  ON public.businesses USING gin (name gin_trgm_ops);
CREATE INDEX IF NOT EXISTS idx_businesses_phone_btree
  ON public.businesses (phone);
CREATE INDEX IF NOT EXISTS idx_businesses_city_btree
  ON public.businesses (city);
CREATE INDEX IF NOT EXISTS idx_businesses_state_btree
  ON public.businesses (state);

-- 4. Add trigram indexes for fuzzy search on discovered_salons
CREATE INDEX IF NOT EXISTS idx_discovered_salons_name_trgm
  ON public.discovered_salons USING gin (business_name gin_trgm_ops);
CREATE INDEX IF NOT EXISTS idx_discovered_salons_phone_btree
  ON public.discovered_salons (phone);
CREATE INDEX IF NOT EXISTS idx_discovered_salons_city_btree
  ON public.discovered_salons (location_city);
CREATE INDEX IF NOT EXISTS idx_discovered_salons_status_btree
  ON public.discovered_salons (status);

-- 5. Expand outreach log channel constraint to support manual channels
-- Drop old constraint and add expanded one
ALTER TABLE public.salon_outreach_log
  DROP CONSTRAINT IF EXISTS salon_outreach_log_channel_check;
ALTER TABLE public.salon_outreach_log
  ADD CONSTRAINT salon_outreach_log_channel_check
  CHECK (channel IN (
    'whatsapp', 'sms', 'email',
    'phone_call', 'in_person', 'radio_ad',
    'social_media_ad', 'flyer', 'referral', 'other'
  ));

-- Add notes column for manual outreach entries
ALTER TABLE public.salon_outreach_log
  ADD COLUMN IF NOT EXISTS notes text;

-- Add outcome column to track result of outreach
ALTER TABLE public.salon_outreach_log
  ADD COLUMN IF NOT EXISTS outcome text;

-- RLS: allow admin/superadmin to read/write outreach log
ALTER TABLE public.city_aliases ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Admins can read city aliases"
  ON public.city_aliases FOR SELECT
  USING (true);  -- aliases are public reference data
```

**Step 2: Deploy migration to production**

```bash
# Copy migration to server
rsync -avz supabase/migrations/20260228000000_admin_search_infrastructure.sql \
  www-bc:/var/www/beautycita.com/bc-flutter/supabase-docker/volumes/db/migrations/

# Run migration via psql
ssh www-bc "docker exec -i supabase-db psql -U supabase_admin -d postgres" \
  < supabase/migrations/20260228000000_admin_search_infrastructure.sql
```

Expected: All statements succeed. Verify with:
```bash
ssh www-bc "docker exec supabase-db psql -U supabase_admin -d postgres -c \"SELECT count(*) FROM city_aliases;\""
```
Expected: ~50 rows

**Step 3: Commit**

```bash
git add supabase/migrations/20260228000000_admin_search_infrastructure.sql
git commit -m "feat: add pg_trgm, city aliases, outreach log expansion for admin search"
```

---

## Task 2: Database RPC — `search_salons` Function

**Files:**
- Create: `supabase/migrations/20260228000001_search_salons_rpc.sql`

**Step 1: Write the RPC function**

```sql
-- =============================================================================
-- search_salons: Intelligent fuzzy search across registered businesses
-- =============================================================================
-- Tokenizes query, resolves city aliases, matches against name/phone/city/state/address
-- Returns ranked results: exact > prefix > contains > fuzzy
-- =============================================================================

CREATE OR REPLACE FUNCTION public.search_salons(
  query text,
  result_limit int DEFAULT 50,
  result_offset int DEFAULT 0
)
RETURNS TABLE (
  id uuid,
  name text,
  phone text,
  whatsapp text,
  address text,
  city text,
  state text,
  country text,
  photo_url text,
  tier int,
  is_active boolean,
  average_rating numeric,
  total_reviews int,
  owner_id uuid,
  created_at timestamptz,
  relevance float
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  tokens text[];
  token text;
  resolved_city text;
  resolved_state text;
  phone_digits text;
  city_filter text;
  state_filter text;
  phone_filter text;
  name_tokens text[];
BEGIN
  -- Tokenize input
  tokens := string_to_array(lower(trim(query)), ' ');

  -- Separate tokens into categories
  name_tokens := ARRAY[]::text[];
  city_filter := NULL;
  state_filter := NULL;
  phone_filter := NULL;

  FOREACH token IN ARRAY tokens LOOP
    -- Skip empty tokens
    IF token = '' THEN CONTINUE; END IF;

    -- Check if token is a city alias
    SELECT ca.city, ca.state INTO resolved_city, resolved_state
    FROM city_aliases ca
    WHERE ca.alias = token;

    IF resolved_city IS NOT NULL THEN
      city_filter := resolved_city;
      state_filter := resolved_state;
      CONTINUE;
    END IF;

    -- Check if token looks like a phone number (digits only or starts with digits)
    phone_digits := regexp_replace(token, '[^0-9]', '', 'g');
    IF length(phone_digits) >= 3 AND length(phone_digits) = length(token) THEN
      phone_filter := phone_digits;
      CONTINUE;
    END IF;

    -- Otherwise treat as name/text search token
    name_tokens := array_append(name_tokens, token);
  END LOOP;

  RETURN QUERY
  SELECT
    b.id,
    b.name,
    b.phone,
    b.whatsapp,
    b.address,
    b.city,
    b.state,
    b.country,
    b.photo_url,
    b.tier,
    b.is_active,
    b.average_rating,
    b.total_reviews,
    b.owner_id,
    b.created_at,
    -- Relevance scoring
    (
      CASE WHEN city_filter IS NOT NULL AND lower(b.city) = lower(city_filter) THEN 10.0 ELSE 0.0 END
      + CASE WHEN state_filter IS NOT NULL AND lower(b.state) = lower(state_filter) THEN 5.0 ELSE 0.0 END
      + CASE WHEN phone_filter IS NOT NULL AND (
          replace(replace(replace(b.phone, ' ', ''), '-', ''), '+', '') LIKE '%' || phone_filter || '%'
          OR replace(replace(replace(b.whatsapp, ' ', ''), '-', ''), '+', '') LIKE '%' || phone_filter || '%'
        ) THEN 15.0 ELSE 0.0 END
      + CASE WHEN array_length(name_tokens, 1) > 0 THEN
          (SELECT COALESCE(sum(
            CASE
              WHEN lower(b.name) = nt THEN 20.0
              WHEN lower(b.name) LIKE nt || '%' THEN 10.0
              WHEN lower(b.name) LIKE '%' || nt || '%' THEN 5.0
              WHEN similarity(lower(b.name), nt) > 0.1 THEN similarity(lower(b.name), nt) * 8.0
              ELSE 0.0
            END
          ), 0) FROM unnest(name_tokens) AS nt)
        ELSE 0.0 END
      + CASE WHEN array_length(name_tokens, 1) > 0 THEN
          (SELECT COALESCE(sum(
            CASE
              WHEN lower(b.address) LIKE '%' || nt || '%' THEN 3.0
              ELSE 0.0
            END
          ), 0) FROM unnest(name_tokens) AS nt)
        ELSE 0.0 END
    )::float AS relevance
  FROM businesses b
  WHERE
    -- City filter (from alias resolution)
    (city_filter IS NULL OR lower(b.city) = lower(city_filter))
    -- State filter
    AND (state_filter IS NULL OR lower(b.state) = lower(state_filter))
    -- Phone filter (prefix or contains match)
    AND (phone_filter IS NULL OR (
      replace(replace(replace(COALESCE(b.phone,''), ' ', ''), '-', ''), '+', '') LIKE '%' || phone_filter || '%'
      OR replace(replace(replace(COALESCE(b.whatsapp,''), ' ', ''), '-', ''), '+', '') LIKE '%' || phone_filter || '%'
    ))
    -- Name/text tokens (all must match somewhere)
    AND (array_length(name_tokens, 1) IS NULL OR (
      SELECT bool_and(
        lower(b.name) LIKE '%' || nt || '%'
        OR lower(COALESCE(b.address, '')) LIKE '%' || nt || '%'
        OR lower(b.city) LIKE '%' || nt || '%'
        OR lower(b.state) LIKE '%' || nt || '%'
        OR similarity(lower(b.name), nt) > 0.2
      )
      FROM unnest(name_tokens) AS nt
    ))
  ORDER BY relevance DESC, b.name ASC
  LIMIT result_limit
  OFFSET result_offset;
END;
$$;

-- Grant access
GRANT EXECUTE ON FUNCTION public.search_salons(text, int, int) TO authenticated;
```

**Step 2: Deploy and test**

```bash
rsync -avz supabase/migrations/20260228000001_search_salons_rpc.sql \
  www-bc:/var/www/beautycita.com/bc-flutter/supabase-docker/volumes/db/migrations/
ssh www-bc "docker exec -i supabase-db psql -U supabase_admin -d postgres" \
  < supabase/migrations/20260228000001_search_salons_rpc.sql
```

Test:
```bash
ssh www-bc "docker exec supabase-db psql -U supabase_admin -d postgres -c \
  \"SELECT name, city, phone, relevance FROM search_salons('houston') LIMIT 5;\""
```

**Step 3: Commit**

```bash
git add supabase/migrations/20260228000001_search_salons_rpc.sql
git commit -m "feat: add search_salons RPC with fuzzy matching and city aliases"
```

---

## Task 3: Database RPC — `search_discovered_salons` Function

**Files:**
- Create: `supabase/migrations/20260228000002_search_discovered_salons_rpc.sql`

**Step 1: Write the RPC function**

```sql
-- =============================================================================
-- search_discovered_salons: Intelligent fuzzy search + filters for pipeline
-- =============================================================================

CREATE OR REPLACE FUNCTION public.search_discovered_salons(
  query text DEFAULT '',
  status_filter text[] DEFAULT NULL,
  city_filter_param text DEFAULT NULL,
  has_whatsapp boolean DEFAULT NULL,
  has_interest boolean DEFAULT NULL,
  source_filter text DEFAULT NULL,
  result_limit int DEFAULT 50,
  result_offset int DEFAULT 0
)
RETURNS TABLE (
  id uuid,
  business_name text,
  phone text,
  whatsapp text,
  location_address text,
  location_city text,
  location_state text,
  country text,
  feature_image_url text,
  rating_average numeric,
  rating_count int,
  categories text,
  source text,
  status text,
  interest_count int,
  outreach_count int,
  last_outreach_at timestamptz,
  outreach_channel text,
  whatsapp_verified boolean,
  created_at timestamptz,
  relevance float
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  tokens text[];
  token text;
  resolved_city text;
  resolved_state text;
  phone_digits text;
  alias_city text;
  alias_state text;
  phone_match text;
  name_tokens text[];
BEGIN
  -- Tokenize
  tokens := string_to_array(lower(trim(COALESCE(query, ''))), ' ');
  name_tokens := ARRAY[]::text[];
  alias_city := NULL;
  alias_state := NULL;
  phone_match := NULL;

  IF query IS NOT NULL AND trim(query) != '' THEN
    FOREACH token IN ARRAY tokens LOOP
      IF token = '' THEN CONTINUE; END IF;

      SELECT ca.city, ca.state INTO resolved_city, resolved_state
      FROM city_aliases ca WHERE ca.alias = token;

      IF resolved_city IS NOT NULL THEN
        alias_city := resolved_city;
        alias_state := resolved_state;
        CONTINUE;
      END IF;

      phone_digits := regexp_replace(token, '[^0-9]', '', 'g');
      IF length(phone_digits) >= 3 AND length(phone_digits) = length(token) THEN
        phone_match := phone_digits;
        CONTINUE;
      END IF;

      name_tokens := array_append(name_tokens, token);
    END LOOP;
  END IF;

  RETURN QUERY
  SELECT
    d.id,
    d.business_name,
    d.phone,
    d.whatsapp,
    d.location_address,
    d.location_city,
    d.location_state,
    d.country,
    d.feature_image_url,
    d.rating_average,
    d.rating_count,
    d.categories,
    d.source,
    d.status,
    d.interest_count,
    d.outreach_count,
    d.last_outreach_at,
    d.outreach_channel,
    d.whatsapp_verified,
    d.created_at,
    (
      CASE WHEN alias_city IS NOT NULL AND lower(d.location_city) = lower(alias_city) THEN 10.0 ELSE 0.0 END
      + CASE WHEN phone_match IS NOT NULL AND (
          replace(replace(replace(COALESCE(d.phone,''), ' ', ''), '-', ''), '+', '') LIKE '%' || phone_match || '%'
        ) THEN 15.0 ELSE 0.0 END
      + CASE WHEN array_length(name_tokens, 1) > 0 THEN
          (SELECT COALESCE(sum(
            CASE
              WHEN lower(d.business_name) LIKE '%' || nt || '%' THEN 5.0
              WHEN similarity(lower(d.business_name), nt) > 0.2 THEN similarity(lower(d.business_name), nt) * 8.0
              ELSE 0.0
            END
          ), 0) FROM unnest(name_tokens) AS nt)
        ELSE 0.0 END
    )::float AS relevance
  FROM discovered_salons d
  WHERE
    -- Explicit filters
    (status_filter IS NULL OR d.status = ANY(status_filter))
    AND (city_filter_param IS NULL OR lower(d.location_city) = lower(city_filter_param))
    AND (has_whatsapp IS NULL OR (has_whatsapp = true AND d.whatsapp_verified = true) OR has_whatsapp = false)
    AND (has_interest IS NULL OR (has_interest = true AND d.interest_count > 0) OR has_interest = false)
    AND (source_filter IS NULL OR d.source = source_filter)
    -- Search query filters
    AND (alias_city IS NULL OR lower(d.location_city) = lower(alias_city))
    AND (phone_match IS NULL OR
      replace(replace(replace(COALESCE(d.phone,''), ' ', ''), '-', ''), '+', '') LIKE '%' || phone_match || '%')
    AND (array_length(name_tokens, 1) IS NULL OR (
      SELECT bool_and(
        lower(d.business_name) LIKE '%' || nt || '%'
        OR lower(COALESCE(d.location_address, '')) LIKE '%' || nt || '%'
        OR lower(d.location_city) LIKE '%' || nt || '%'
        OR lower(d.location_state) LIKE '%' || nt || '%'
        OR similarity(lower(d.business_name), nt) > 0.2
      )
      FROM unnest(name_tokens) AS nt
    ))
  ORDER BY relevance DESC, d.interest_count DESC, d.business_name ASC
  LIMIT result_limit
  OFFSET result_offset;
END;
$$;

GRANT EXECUTE ON FUNCTION public.search_discovered_salons(text, text[], text, boolean, boolean, text, int, int)
  TO authenticated;
```

**Step 2: Deploy and test**

```bash
rsync -avz supabase/migrations/20260228000002_search_discovered_salons_rpc.sql \
  www-bc:/var/www/beautycita.com/bc-flutter/supabase-docker/volumes/db/migrations/
ssh www-bc "docker exec -i supabase-db psql -U supabase_admin -d postgres" \
  < supabase/migrations/20260228000002_search_discovered_salons_rpc.sql
```

**Step 3: Commit**

```bash
git add supabase/migrations/20260228000002_search_discovered_salons_rpc.sql
git commit -m "feat: add search_discovered_salons RPC with filters for pipeline"
```

---

## Task 4: Add Flutter Export Packages

**Files:**
- Modify: `pubspec.yaml`

**Step 1: Add dependencies**

Add these packages to `pubspec.yaml` under `dependencies:`:

```yaml
csv: ^6.0.0
syncfusion_flutter_xlsio: ^27.2.5
pdf: ^3.11.2
```

Note: vCard generation will be done manually (simple text format, no package needed). `share_plus` and `path_provider` already exist.

**Step 2: Run pub get**

```bash
cd /home/bc/futureBeauty/beautycita_app
/home/bc/flutter/bin/flutter pub get
```

Expected: Dependencies resolve successfully.

**Step 3: Commit**

```bash
git add pubspec.yaml pubspec.lock
git commit -m "feat: add csv, xlsio, pdf packages for admin export system"
```

---

## Task 5: Export Service

**Files:**
- Create: `lib/services/export_service.dart`

**Step 1: Implement the export service**

This service handles all 5 export formats for any list of `Map<String, dynamic>` data. It:
- Takes a list of records + column definitions + export format
- Generates the file in the appropriate format
- Returns the file path for sharing via share_plus

```dart
import 'dart:convert';
import 'dart:io';

import 'package:csv/csv.dart';
import 'package:flutter/foundation.dart';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:share_plus/share_plus.dart';
import 'package:syncfusion_flutter_xlsio/xlsio.dart' as xlsio;

enum ExportFormat { csv, excel, json, pdf, vcard }

class ExportColumn {
  final String key;
  final String label;
  const ExportColumn(this.key, this.label);
}

class ExportService {
  static Future<void> export({
    required List<Map<String, dynamic>> data,
    required List<ExportColumn> columns,
    required ExportFormat format,
    required String title,
    String? groupByKey,
  }) async {
    if (data.isEmpty) return;

    final dir = await getTemporaryDirectory();
    final timestamp = DateFormat('yyyyMMdd_HHmmss').format(DateTime.now());
    final safeName = title.replaceAll(RegExp(r'[^\w]'), '_').toLowerCase();

    File file;
    switch (format) {
      case ExportFormat.csv:
        file = await _generateCsv(data, columns, dir, '${safeName}_$timestamp');
      case ExportFormat.excel:
        file = await _generateExcel(data, columns, dir, '${safeName}_$timestamp', title, groupByKey);
      case ExportFormat.json:
        file = await _generateJson(data, columns, dir, '${safeName}_$timestamp');
      case ExportFormat.pdf:
        file = await _generatePdf(data, columns, dir, '${safeName}_$timestamp', title);
      case ExportFormat.vcard:
        file = await _generateVcard(data, dir, '${safeName}_$timestamp');
    }

    await Share.shareXFiles(
      [XFile(file.path)],
      text: '$title - ${data.length} registros',
    );
  }

  static Future<File> _generateCsv(
    List<Map<String, dynamic>> data,
    List<ExportColumn> columns,
    Directory dir,
    String filename,
  ) async {
    final rows = <List<dynamic>>[
      columns.map((c) => c.label).toList(),
      ...data.map((row) => columns.map((c) => row[c.key]?.toString() ?? '').toList()),
    ];
    final csvString = '\uFEFF${const ListToCsvConverter().convert(rows)}';
    final file = File('${dir.path}/$filename.csv');
    await file.writeAsString(csvString);
    return file;
  }

  static Future<File> _generateExcel(
    List<Map<String, dynamic>> data,
    List<ExportColumn> columns,
    Directory dir,
    String filename,
    String title,
    String? groupByKey,
  ) async {
    final workbook = xlsio.Workbook();

    if (groupByKey != null) {
      // Group data into separate sheets
      final groups = <String, List<Map<String, dynamic>>>{};
      for (final row in data) {
        final key = row[groupByKey]?.toString() ?? 'Sin grupo';
        groups.putIfAbsent(key, () => []).add(row);
      }
      workbook.worksheets.clear();
      for (final entry in groups.entries) {
        final sheet = workbook.worksheets.addWithName(
          entry.key.length > 31 ? entry.key.substring(0, 31) : entry.key,
        );
        _fillSheet(sheet, columns, entry.value);
      }
    } else {
      final sheet = workbook.worksheets[0];
      sheet.name = title.length > 31 ? title.substring(0, 31) : title;
      _fillSheet(sheet, columns, data);
    }

    final bytes = workbook.saveAsStream();
    workbook.dispose();
    final file = File('${dir.path}/$filename.xlsx');
    await file.writeAsBytes(bytes);
    return file;
  }

  static void _fillSheet(
    xlsio.Worksheet sheet,
    List<ExportColumn> columns,
    List<Map<String, dynamic>> data,
  ) {
    // Headers
    for (var i = 0; i < columns.length; i++) {
      final cell = sheet.getRangeByIndex(1, i + 1);
      cell.setText(columns[i].label);
      cell.cellStyle.bold = true;
    }
    // Data
    for (var r = 0; r < data.length; r++) {
      for (var c = 0; c < columns.length; c++) {
        final value = data[r][columns[c].key];
        final cell = sheet.getRangeByIndex(r + 2, c + 1);
        if (value is num) {
          cell.setNumber(value.toDouble());
        } else {
          cell.setText(value?.toString() ?? '');
        }
      }
    }
    // Auto-fit columns
    for (var i = 1; i <= columns.length; i++) {
      sheet.autoFitColumn(i);
    }
  }

  static Future<File> _generateJson(
    List<Map<String, dynamic>> data,
    List<ExportColumn> columns,
    Directory dir,
    String filename,
  ) async {
    final filtered = data.map((row) {
      return {for (final c in columns) c.key: row[c.key]};
    }).toList();
    final jsonString = const JsonEncoder.withIndent('  ').convert(filtered);
    final file = File('${dir.path}/$filename.json');
    await file.writeAsString(jsonString);
    return file;
  }

  static Future<File> _generatePdf(
    List<Map<String, dynamic>> data,
    List<ExportColumn> columns,
    Directory dir,
    String filename,
    String title,
  ) async {
    final pdf = pw.Document();
    final now = DateFormat('dd/MM/yyyy HH:mm').format(DateTime.now());

    // Split into pages of 30 rows
    const rowsPerPage = 30;
    for (var page = 0; page * rowsPerPage < data.length; page++) {
      final start = page * rowsPerPage;
      final end = (start + rowsPerPage).clamp(0, data.length);
      final pageData = data.sublist(start, end);

      pdf.addPage(
        pw.Page(
          pageFormat: PdfPageFormat.letter.landscape,
          margin: const pw.EdgeInsets.all(20),
          build: (ctx) => pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Text(title,
                      style: pw.TextStyle(
                          fontSize: 14, fontWeight: pw.FontWeight.bold)),
                  pw.Text(now, style: const pw.TextStyle(fontSize: 9)),
                ],
              ),
              pw.SizedBox(height: 8),
              pw.Text('${data.length} registros',
                  style: const pw.TextStyle(fontSize: 9)),
              pw.SizedBox(height: 8),
              pw.TableHelper.fromTextArray(
                headerStyle: pw.TextStyle(
                    fontSize: 8, fontWeight: pw.FontWeight.bold),
                cellStyle: const pw.TextStyle(fontSize: 7),
                headerDecoration:
                    const pw.BoxDecoration(color: PdfColors.grey200),
                headers: columns.map((c) => c.label).toList(),
                data: pageData
                    .map((row) =>
                        columns.map((c) => row[c.key]?.toString() ?? '').toList())
                    .toList(),
              ),
              pw.Spacer(),
              pw.Align(
                alignment: pw.Alignment.centerRight,
                child: pw.Text(
                  'Pagina ${page + 1} de ${(data.length / rowsPerPage).ceil()}',
                  style: const pw.TextStyle(fontSize: 8),
                ),
              ),
            ],
          ),
        ),
      );
    }

    final bytes = await pdf.save();
    final file = File('${dir.path}/$filename.pdf');
    await file.writeAsBytes(bytes);
    return file;
  }

  static Future<File> _generateVcard(
    List<Map<String, dynamic>> data,
    Directory dir,
    String filename,
  ) async {
    final buffer = StringBuffer();
    for (final row in data) {
      final name = row['name'] ?? row['business_name'] ?? '';
      final phone = row['phone'] ?? '';
      final address = row['address'] ?? row['location_address'] ?? '';
      final city = row['city'] ?? row['location_city'] ?? '';
      final state = row['state'] ?? row['location_state'] ?? '';
      final website = row['website'] ?? '';

      buffer.writeln('BEGIN:VCARD');
      buffer.writeln('VERSION:3.0');
      buffer.writeln('FN:$name');
      buffer.writeln('ORG:$name');
      if (phone.toString().isNotEmpty) buffer.writeln('TEL;TYPE=WORK:$phone');
      if (address.toString().isNotEmpty || city.toString().isNotEmpty) {
        buffer.writeln('ADR;TYPE=WORK:;;$address;$city;$state;;');
      }
      if (website.toString().isNotEmpty) buffer.writeln('URL:$website');
      buffer.writeln('END:VCARD');
      buffer.writeln();
    }
    final file = File('${dir.path}/$filename.vcf');
    await file.writeAsString(buffer.toString());
    return file;
  }
}
```

**Step 2: Verify it compiles**

```bash
cd /home/bc/futureBeauty/beautycita_app
/home/bc/flutter/bin/flutter analyze lib/services/export_service.dart
```

**Step 3: Commit**

```bash
git add lib/services/export_service.dart
git commit -m "feat: add ExportService with CSV, Excel, JSON, PDF, vCard generation"
```

---

## Task 6: Admin Salones Screen — Providers

**Files:**
- Modify: `lib/providers/admin_provider.dart`

**Step 1: Add search provider and salon detail providers**

Add to `admin_provider.dart`:

```dart
/// Search salons via RPC — debounced in UI, called with final query
final searchSalonsProvider = FutureProvider.family<List<Map<String, dynamic>>, String>((ref, query) async {
  if (query.trim().length < 2) return [];
  final response = await SupabaseClientService.client.rpc('search_salons', params: {
    'query': query.trim(),
    'result_limit': 50,
    'result_offset': 0,
  });
  return (response as List).cast<Map<String, dynamic>>();
});

/// Full salon detail for admin control panel
final adminSalonDetailProvider = FutureProvider.family<Map<String, dynamic>?, String>((ref, businessId) async {
  final response = await SupabaseClientService.client
      .from('businesses')
      .select('*, profiles!businesses_owner_id_fkey(id, display_name, phone, email)')
      .eq('id', businessId)
      .maybeSingle();
  return response;
});

/// Recent appointments for a salon (admin view)
final adminSalonAppointmentsProvider = FutureProvider.family<List<Map<String, dynamic>>, String>((ref, businessId) async {
  final response = await SupabaseClientService.client
      .from('appointments')
      .select('id, user_id, service_id, date, time, status, payment_status, price, profiles!appointments_user_id_fkey(display_name), services(name)')
      .eq('business_id', businessId)
      .order('date', ascending: false)
      .limit(10);
  return (response as List).cast<Map<String, dynamic>>();
});

/// Open disputes for a salon
final adminSalonDisputesProvider = FutureProvider.family<List<Map<String, dynamic>>, String>((ref, businessId) async {
  final response = await SupabaseClientService.client
      .from('disputes')
      .select('id, status, reason, created_at, resolution, refund_amount')
      .eq('business_id', businessId)
      .inFilter('status', ['open', 'salon_responded', 'escalated'])
      .order('created_at', ascending: false);
  return (response as List).cast<Map<String, dynamic>>();
});

/// Recent reviews for a salon
final adminSalonReviewsProvider = FutureProvider.family<List<Map<String, dynamic>>, String>((ref, businessId) async {
  final response = await SupabaseClientService.client
      .from('reviews')
      .select('id, rating, comment, created_at, profiles!reviews_user_id_fkey(display_name)')
      .eq('business_id', businessId)
      .order('created_at', ascending: false)
      .limit(10);
  return (response as List).cast<Map<String, dynamic>>();
});
```

**Step 2: Verify**

```bash
/home/bc/flutter/bin/flutter analyze lib/providers/admin_provider.dart
```

**Step 3: Commit**

```bash
git add lib/providers/admin_provider.dart
git commit -m "feat: add search_salons and salon detail providers for admin"
```

---

## Task 7: Admin Salones Screen — UI

**Files:**
- Create: `lib/screens/admin/admin_salones_screen.dart`

**Step 1: Build the screen**

This is the main screen with:
- Search bar at top (debounced 300ms)
- Results list with salon cards
- Export button
- Tapping a card pushes to salon detail

The screen is a `ConsumerStatefulWidget`. Search uses a `TextEditingController` + `Timer` for debounce. Results from `searchSalonsProvider`.

Key UI patterns to follow from existing admin screens:
- `GoogleFonts.poppins` for headings, `GoogleFonts.nunito` for body
- `Theme.of(context).colorScheme` for colors
- `AppConstants` for padding/radius values
- Tier badge colors: 1=grey, 2=blue, 3=secondary/rose

The search bar should have:
- Search icon on left
- Clear button when text exists
- Export icon button on right

Each result card shows:
- Active dot (green/red) left edge
- Salon name (poppins w500 14px)
- City, State (nunito 12px, muted)
- Phone number (nunito 12px)
- Tier badge on right
- Rating stars + count (if available)

**File structure:** ~300-400 lines. Full code to be written during implementation following the patterns in `message_salons_screen.dart` and `salon_management_screen.dart`.

**Step 2: Verify**

```bash
/home/bc/flutter/bin/flutter analyze lib/screens/admin/admin_salones_screen.dart
```

**Step 3: Commit**

```bash
git add lib/screens/admin/admin_salones_screen.dart
git commit -m "feat: add admin Salones screen with intelligent search"
```

---

## Task 8: Salon Detail Panel

**Files:**
- Create: `lib/screens/admin/admin_salon_detail_screen.dart`

**Step 1: Build the salon detail screen**

Full-screen push (not bottom sheet — too much content for a sheet on mobile).

Sections:
- **Header:** photo, name, tier selector (SegmentedButton or chips), active toggle, city/state
- **Stats row:** 4 compact stat cards (rating, reviews, appointments, revenue)
- **Contact section:** phone (tap to call), whatsapp (tap to open), address (tap for maps), web/social links
- **Business info:** categories, hours, deposit settings, cancellation policy
- **Owner card:** name, tap to navigate to user detail
- **Recent appointments list:** 10 items, each tappable
- **Open disputes list:** with status badges
- **Recent reviews:** rating stars + text preview
- **Bottom action buttons:** Contact Owner (WA), Edit Info, Suspend

Tier change and active toggle write directly to DB via `SupabaseClientService.client.from('businesses').update(...)`.

**File structure:** ~500-600 lines.

**Step 2: Verify**

```bash
/home/bc/flutter/bin/flutter analyze lib/screens/admin/admin_salon_detail_screen.dart
```

**Step 3: Commit**

```bash
git add lib/screens/admin/admin_salon_detail_screen.dart
git commit -m "feat: add admin salon detail panel with full control"
```

---

## Task 9: Pipeline Screen — Providers

**Files:**
- Modify: `lib/providers/admin_provider.dart`

**Step 1: Add pipeline providers**

```dart
/// Pipeline search via RPC with filters
final searchDiscoveredSalonsProvider = FutureProvider.family<List<Map<String, dynamic>>, Map<String, dynamic>>((ref, params) async {
  final response = await SupabaseClientService.client.rpc('search_discovered_salons', params: {
    'query': params['query'] ?? '',
    'status_filter': params['status_filter'],
    'city_filter_param': params['city_filter'],
    'has_whatsapp': params['has_whatsapp'],
    'has_interest': params['has_interest'],
    'source_filter': params['source_filter'],
    'result_limit': params['result_limit'] ?? 50,
    'result_offset': params['result_offset'] ?? 0,
  });
  return (response as List).cast<Map<String, dynamic>>();
});

/// Pipeline funnel stats
final pipelineFunnelStatsProvider = FutureProvider<Map<String, int>>((ref) async {
  final response = await SupabaseClientService.client
      .from('discovered_salons')
      .select('status');
  final list = (response as List).cast<Map<String, dynamic>>();
  final counts = <String, int>{};
  for (final row in list) {
    final status = row['status'] as String? ?? 'unknown';
    counts[status] = (counts[status] ?? 0) + 1;
  }
  return counts;
});

/// Outreach log for a discovered salon (expanded with notes/outcome)
final pipelineOutreachLogProvider = FutureProvider.family<List<Map<String, dynamic>>, String>((ref, salonId) async {
  final response = await SupabaseClientService.client
      .from('salon_outreach_log')
      .select('*')
      .eq('discovered_salon_id', salonId)
      .order('sent_at', ascending: false)
      .limit(50);
  return (response as List).cast<Map<String, dynamic>>();
});
```

**Step 2: Verify and commit**

```bash
/home/bc/flutter/bin/flutter analyze lib/providers/admin_provider.dart
git add lib/providers/admin_provider.dart
git commit -m "feat: add pipeline search and funnel stats providers"
```

---

## Task 10: Pipeline Screen — UI

**Files:**
- Create: `lib/screens/admin/admin_pipeline_screen.dart`

**Step 1: Build the pipeline screen**

Layout (top to bottom):
1. **Collapsible metrics header** — `AnimatedCrossFade` or `AnimatedContainer`. Collapsed: single Row with 4 stats. Expanded: full funnel breakdown with colored dots + counts per status.
2. **Search bar** — same pattern as Salones screen
3. **Filter chips** — horizontally scrollable `SingleChildScrollView` + `Row` of `FilterChip` widgets. Chips: Status (multi-select), City, Has WhatsApp, Has Interest, Source.
4. **Bulk action bar** — `AnimatedSlide` from bottom when `_selectedIds.isNotEmpty`. Contains: Send Outreach, Change Status, Export, Delete buttons.
5. **Lead list** — `ListView.builder` with lead cards. Long-press enters selection mode. Each card: name, city, source badge, status badge, phone + WA check, interest count, last outreach, checkbox.

State management: `ConsumerStatefulWidget` with local state for:
- `_searchQuery` (String)
- `_statusFilters` (Set<String>)
- `_cityFilter` (String?)
- `_hasWhatsapp` (bool?)
- `_hasInterest` (bool?)
- `_sourceFilter` (String?)
- `_selectedIds` (Set<String>)
- `_selectionMode` (bool)
- `_metricsExpanded` (bool)

**File structure:** ~600-700 lines.

**Step 2: Verify and commit**

```bash
/home/bc/flutter/bin/flutter analyze lib/screens/admin/admin_pipeline_screen.dart
git add lib/screens/admin/admin_pipeline_screen.dart
git commit -m "feat: add admin Pipeline screen with filters, bulk actions, metrics"
```

---

## Task 11: Pipeline Lead Detail Bottom Sheet

**Files:**
- Create: `lib/screens/admin/pipeline_lead_detail_sheet.dart`

**Step 1: Build the lead detail sheet**

Large bottom sheet (`DraggableScrollableSheet` with `minChildSize: 0.5, maxChildSize: 0.95`).

Sections:
- **Header:** name (editable), status selector chips, city/state, source badge, phone/WA (tap to call/message)
- **Salon info:** address, map link, rating, hours, categories, website, social links
- **Outreach timeline:** chronological list from `pipelineOutreachLogProvider`. Each entry: date, channel icon + label, message preview, notes, outcome.
- **Log outreach button:** opens dialog with channel dropdown (all 10 channels), notes field, date picker (defaults to now). Inserts into `salon_outreach_log`.
- **Action buttons:** Send WhatsApp, Send SMS, Send Email, Change Status, Mark Registered, Mark Declined, Delete

**File structure:** ~400-500 lines.

**Step 2: Verify and commit**

```bash
/home/bc/flutter/bin/flutter analyze lib/screens/admin/pipeline_lead_detail_sheet.dart
git add lib/screens/admin/pipeline_lead_detail_sheet.dart
git commit -m "feat: add pipeline lead detail sheet with outreach timeline"
```

---

## Task 12: Wire Up Admin Shell — Replace Tabs

**Files:**
- Modify: `lib/screens/admin/admin_shell_screen.dart`

**Step 1: Replace tab references**

In `admin_shell_screen.dart`:

1. Change the "Salones" tab (index 5) to point to `AdminSalonesScreen` instead of `SalonManagementScreen`
2. Change the "Mensajes Salones" tab (index 8) to "Pipeline" with icon `Icons.rocket_launch_rounded`, pointing to `AdminPipelineScreen`
3. Update the imports at the top of the file
4. Update the switch statement in the screen routing section (~line 197-241)

**Step 2: Verify**

```bash
/home/bc/flutter/bin/flutter analyze lib/screens/admin/admin_shell_screen.dart
```

**Step 3: Build and test on device**

```bash
cd /home/bc/futureBeauty/beautycita_app
/home/bc/flutter/bin/flutter build apk --debug --target-platform android-arm64
/home/bc/Android/Sdk/platform-tools/adb devices
# Install on BC's phone
/home/bc/Android/Sdk/platform-tools/adb -s <DEVICE_ID> install -r build/app/outputs/flutter-apk/app-debug.apk
```

**Step 4: Commit**

```bash
git add lib/screens/admin/admin_shell_screen.dart
git commit -m "feat: wire Salones and Pipeline screens into admin shell"
```

---

## Task 13: Export Integration — Wire Export Buttons

**Files:**
- Modify: `lib/screens/admin/admin_salones_screen.dart`
- Modify: `lib/screens/admin/admin_pipeline_screen.dart`

**Step 1: Add export dialogs to both screens**

Create a shared export dialog widget (or inline in each screen) that shows:
1. Format selection: CSV, Excel, JSON, PDF, Contactos (vCard)
2. Template selection (different per screen)
3. Group-by option for Excel (by city, by tier, by status)
4. Calls `ExportService.export()` with current filtered data

**Salones export columns:**
```dart
const salonExportColumns = [
  ExportColumn('name', 'Nombre'),
  ExportColumn('phone', 'Telefono'),
  ExportColumn('whatsapp', 'WhatsApp'),
  ExportColumn('city', 'Ciudad'),
  ExportColumn('state', 'Estado'),
  ExportColumn('address', 'Direccion'),
  ExportColumn('tier', 'Tier'),
  ExportColumn('is_active', 'Activo'),
  ExportColumn('average_rating', 'Calificacion'),
  ExportColumn('total_reviews', 'Resenas'),
];
```

**Pipeline export columns:**
```dart
const pipelineExportColumns = [
  ExportColumn('business_name', 'Nombre'),
  ExportColumn('phone', 'Telefono'),
  ExportColumn('whatsapp', 'WhatsApp'),
  ExportColumn('location_city', 'Ciudad'),
  ExportColumn('location_state', 'Estado'),
  ExportColumn('source', 'Fuente'),
  ExportColumn('status', 'Estado Pipeline'),
  ExportColumn('interest_count', 'Interes'),
  ExportColumn('outreach_count', 'Contactos'),
  ExportColumn('last_outreach_at', 'Ultimo Contacto'),
];
```

**Step 2: Verify and commit**

```bash
/home/bc/flutter/bin/flutter analyze lib/screens/admin/admin_salones_screen.dart lib/screens/admin/admin_pipeline_screen.dart
git add lib/screens/admin/admin_salones_screen.dart lib/screens/admin/admin_pipeline_screen.dart
git commit -m "feat: wire export dialogs into Salones and Pipeline screens"
```

---

## Task 14: Final Build, Install, and Verify

**Step 1: Full analysis**

```bash
cd /home/bc/futureBeauty/beautycita_app
/home/bc/flutter/bin/flutter analyze lib/screens/admin/ lib/services/export_service.dart lib/providers/admin_provider.dart
```

**Step 2: Release build**

```bash
/home/bc/flutter/bin/flutter build apk --release --no-tree-shake-icons --target-platform android-arm64
```

**Step 3: Install on phone**

```bash
/home/bc/Android/Sdk/platform-tools/adb devices
/home/bc/Android/Sdk/platform-tools/adb -s <DEVICE_ID> install -r build/app/outputs/flutter-apk/app-release.apk
```

**Step 4: Manual verification checklist**
- [ ] Admin panel → Salones tab loads new search screen
- [ ] Type "houston" → see Houston salons
- [ ] Type "832" → see salons with 832 phone prefix
- [ ] Type "htown 832" → see Houston salons with 832 prefix
- [ ] Tap a salon → detail panel loads with all sections
- [ ] Change tier → saves to DB
- [ ] Toggle active → saves to DB
- [ ] Export → format selection → share sheet works
- [ ] Admin panel → Pipeline tab loads new screen
- [ ] Metrics header shows funnel counts, taps to expand
- [ ] Filter chips filter the list
- [ ] Search bar finds leads
- [ ] Long-press enters selection mode
- [ ] Bulk actions bar appears with selections
- [ ] Tap lead → detail sheet with outreach timeline
- [ ] Log manual outreach → saves to DB
- [ ] Export from Pipeline works

**Step 5: Final commit**

```bash
git add -A
git commit -m "feat: complete admin Salones + Pipeline screens with export system"
```
