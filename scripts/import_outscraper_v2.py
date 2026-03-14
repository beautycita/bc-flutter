#!/usr/bin/env python3
"""
Import Outscraper CSV into discovered_salons using PostgreSQL COPY.
Deduplicates against existing records by phone number and google_id.

Strategy: generate clean CSV → SCP to server → docker cp into container → COPY FROM file

Usage:
    python3 import_outscraper_v2.py <csv_file>
"""

import csv
import io
import json
import sys
import subprocess
from pathlib import Path


def normalize_phone(phone: str) -> str:
    if not phone:
        return ""
    return "".join(c for c in phone if c.isdigit())


def format_phone(phone_raw: str) -> str:
    phone = normalize_phone(phone_raw)
    if phone.startswith("52") and len(phone) >= 12:
        return f"+{phone}"
    elif len(phone) == 10:
        return f"+52{phone}"
    return phone_raw


def run_sql(sql: str) -> str:
    cmd = [
        "ssh", "www-bc",
        "docker", "exec", "-i", "supabase-db",
        "psql", "-U", "postgres", "-d", "postgres",
        "-t", "-A",
    ]
    result = subprocess.run(cmd, input=sql, capture_output=True, text=True)
    if result.returncode != 0:
        print(f"SQL error: {result.stderr[:300]}")
    return result.stdout.strip()


def get_existing_phones() -> set:
    raw = run_sql("SELECT phone FROM discovered_salons WHERE phone IS NOT NULL AND phone != '';")
    phones = set()
    for line in raw.split("\n"):
        line = line.strip()
        if line:
            phones.add(normalize_phone(line))
    return phones


def get_existing_google_ids() -> set:
    raw = run_sql("SELECT source_id FROM discovered_salons WHERE source = 'google_maps' AND source_id IS NOT NULL;")
    return {line.strip() for line in raw.split("\n") if line.strip()}


def map_categories(category: str, subtypes: str) -> str:
    text = f"{category} {subtypes}".lower()
    cats = []
    if any(w in text for w in ["peluquer", "cabello", "hair", "corte", "barber"]):
        cats.append("hair")
    if any(w in text for w in ["uña", "nail", "manicur", "pedicur"]):
        cats.append("nails")
    if any(w in text for w in ["spa", "masaje", "massage"]):
        cats.append("spa")
    if any(w in text for w in ["estética", "estetica", "belleza", "beauty", "salon"]):
        cats.append("beauty")
    if any(w in text for w in ["pestaña", "lash", "extensi"]):
        cats.append("lashes")
    if any(w in text for w in ["maquillaje", "makeup"]):
        cats.append("makeup")
    if any(w in text for w in ["barber", "barbería"]):
        cats.append("barber")
    if any(w in text for w in ["depilac", "wax"]):
        cats.append("waxing")
    if not cats:
        cats.append("beauty")
    return "{" + ",".join(cats) + "}"


def main():
    if len(sys.argv) < 2:
        print("Usage: python3 import_outscraper_v2.py <csv_file>")
        sys.exit(1)

    csv_path = Path(sys.argv[1])
    if not csv_path.exists():
        print(f"File not found: {csv_path}")
        sys.exit(1)

    print("Loading existing phones from DB...")
    existing_phones = get_existing_phones()
    print(f"  {len(existing_phones)} existing phone numbers")

    print("Loading existing Google IDs from DB...")
    existing_gids = get_existing_google_ids()
    print(f"  {len(existing_gids)} existing Google IDs")

    print(f"Reading {csv_path}...")
    rows = []
    with open(csv_path, "r", encoding="utf-8") as f:
        reader = csv.DictReader(f)
        for row in reader:
            rows.append(row)
    print(f"  {len(rows)} total rows in CSV")

    # Deduplicate
    new_rows = []
    skipped_phone = 0
    skipped_gid = 0
    skipped_no_phone = 0
    seen_phones = set()

    for row in rows:
        phone = normalize_phone(row.get("phone", ""))
        gid = row.get("google_id", "")

        if not phone:
            skipped_no_phone += 1
            continue
        if phone in existing_phones or phone in seen_phones:
            skipped_phone += 1
            continue
        if gid and gid in existing_gids:
            skipped_gid += 1
            continue

        seen_phones.add(phone)
        new_rows.append(row)

    print(f"\nDedup results:")
    print(f"  New (to insert): {len(new_rows)}")
    print(f"  Skipped (phone exists): {skipped_phone}")
    print(f"  Skipped (google_id exists): {skipped_gid}")
    print(f"  Skipped (no phone): {skipped_no_phone}")

    if not new_rows:
        print("Nothing to insert.")
        return

    # Generate clean CSV for the temp table (all text columns — cast in SQL)
    clean_csv = "/tmp/outscraper_import.csv"
    with open(clean_csv, "w", newline="", encoding="utf-8") as f:
        writer = csv.writer(f)
        for row in new_rows:
            phone_raw = row.get("phone", "")
            phone_formatted = format_phone(phone_raw)
            phone_digits = normalize_phone(phone_raw)

            category = row.get("category", "")
            subtypes = row.get("subtypes", "")
            cats_pg = map_categories(category, subtypes)
            # specialties is text[] — format as PG array literal
            spec_parts = [s.strip() for s in f"{category}, {subtypes}".split(",") if s.strip()] if subtypes else ([category] if category else ["beauty"])
            specialties = "{" + ",".join(f'"{s}"' for s in spec_parts) + "}"

            hours = row.get("working_hours", "")
            if hours:
                try:
                    parsed = json.loads(hours)
                    hours = json.dumps(parsed, ensure_ascii=False)
                except (json.JSONDecodeError, TypeError):
                    hours = ""

            writer.writerow([
                "google_maps",
                row.get("google_id", ""),
                row.get("name", ""),
                phone_formatted,
                row.get("address", ""),
                row.get("city", ""),
                row.get("state", ""),
                row.get("country", "Mexico"),
                row.get("latitude", ""),
                row.get("longitude", ""),
                row.get("photo", ""),
                row.get("rating", "") or "",
                row.get("reviews", "") or "",
                cats_pg,
                specialties,
                hours,
                row.get("website", "") or "",
                row.get("postal_code", ""),
                phone_digits,
            ])

    print(f"Generated clean CSV: {clean_csv} ({len(new_rows)} rows)")

    # Read CSV back for piping through stdin
    with open(clean_csv, "r", encoding="utf-8") as f:
        csv_data = f.read()

    # Build psql script: create temp table, \copy from stdin, then INSERT SELECT
    # \copy reads from psql's stdin which flows through docker exec -i
    cols = "source,source_id,business_name,phone,location_address,location_city,location_state,country,latitude,longitude,feature_image_url,rating_average,rating_count,matched_categories,specialties,working_hours,website,location_zip,phone_raw"

    psql_script = f"""CREATE TEMP TABLE _import (
    source text, source_id text, business_name text, phone text,
    location_address text, location_city text, location_state text, country text,
    latitude text, longitude text, feature_image_url text,
    rating_average text, rating_count text,
    matched_categories text, specialties text,
    working_hours text, website text, location_zip text, phone_raw text
);
\\copy _import ({cols}) FROM STDIN WITH (FORMAT csv)
{csv_data}\\.
SELECT COUNT(*) AS rows_loaded FROM _import;
INSERT INTO discovered_salons (
    source, source_id, business_name, phone,
    location_address, location_city, location_state, country,
    latitude, longitude,
    feature_image_url, rating_average, rating_count,
    matched_categories, specialties,
    working_hours, website, location_zip, phone_raw,
    scraped_at
)
SELECT
    source, source_id, business_name, phone,
    location_address, location_city, location_state, country,
    NULLIF(latitude, '')::double precision,
    NULLIF(longitude, '')::double precision,
    feature_image_url,
    NULLIF(rating_average, '')::double precision,
    NULLIF(rating_count, '')::double precision::integer,
    matched_categories::text[],
    specialties::text[],
    working_hours, website, location_zip, phone_raw,
    NOW()
FROM _import
ON CONFLICT DO NOTHING;
SELECT COUNT(*) AS total_mx FROM discovered_salons WHERE country IN ('Mexico', 'MX');
"""

    print(f"Running \\copy + INSERT ({len(new_rows)} rows)...")
    cmd = [
        "ssh", "www-bc",
        "docker", "exec", "-i", "supabase-db",
        "psql", "-U", "postgres", "-d", "postgres",
    ]
    result = subprocess.run(cmd, input=psql_script, capture_output=True, text=True, timeout=300)
    print(result.stdout)
    if result.stderr:
        print("STDERR:", result.stderr[:1000])
    print(f"Return code: {result.returncode}")


if __name__ == "__main__":
    main()
