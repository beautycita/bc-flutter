#!/usr/bin/env python3
"""
Import Outscraper CSV into discovered_salons table.
Deduplicates against existing records by phone number and google_id.

Usage:
    python3 import_outscraper_to_db.py <csv_file>
"""

import csv
import json
import sys
import subprocess
from pathlib import Path


def normalize_phone(phone: str) -> str:
    """Strip to digits only for dedup comparison."""
    if not phone:
        return ""
    return "".join(c for c in phone if c.isdigit())


def run_sql(sql: str) -> str:
    """Run SQL on production DB via ssh, piping through stdin to avoid shell escaping issues."""
    cmd = [
        "ssh", "www-bc",
        "docker", "exec", "-i", "supabase-db",
        "psql", "-U", "postgres", "-d", "postgres",
        "-t", "-A",
    ]
    result = subprocess.run(cmd, input=sql, capture_output=True, text=True)
    if result.returncode != 0:
        print(f"SQL error: {result.stderr[:200]}")
    return result.stdout.strip()


def get_existing_phones() -> set:
    """Get all existing phone numbers (normalized) from discovered_salons."""
    raw = run_sql("SELECT phone FROM discovered_salons WHERE phone IS NOT NULL AND phone != '';")
    phones = set()
    for line in raw.split("\n"):
        line = line.strip()
        if line:
            phones.add(normalize_phone(line))
    return phones


def get_existing_google_ids() -> set:
    """Get all existing source_ids from Google Maps source."""
    raw = run_sql("SELECT source_id FROM discovered_salons WHERE source = 'google_maps' AND source_id IS NOT NULL;")
    return {line.strip() for line in raw.split("\n") if line.strip()}


def map_categories(category: str, subtypes: str) -> list:
    """Map Google Maps category to BeautyCita category IDs."""
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
        cats.append("beauty")  # default
    return cats


def escape_sql(val: str) -> str:
    """Escape single quotes for SQL."""
    if not val:
        return ""
    return val.replace("'", "''")


def main():
    if len(sys.argv) < 2:
        print("Usage: python3 import_outscraper_to_db.py <csv_file>")
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

    # Read CSV
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

    # Insert in batches of 100
    batch_size = 100
    total_inserted = 0

    for batch_start in range(0, len(new_rows), batch_size):
        batch = new_rows[batch_start : batch_start + batch_size]
        values = []

        for row in batch:
            name = escape_sql(row.get("name", ""))
            phone_raw = row.get("phone", "")
            phone = normalize_phone(phone_raw)
            # Format as +52XXXXXXXXXX for MX numbers
            if phone.startswith("52") and len(phone) >= 12:
                phone_formatted = f"+{phone}"
            elif len(phone) == 10:
                phone_formatted = f"+52{phone}"
            else:
                phone_formatted = phone_raw

            address = escape_sql(row.get("address", ""))
            street = escape_sql(row.get("street", ""))
            city = escape_sql(row.get("city", ""))
            state = escape_sql(row.get("state", ""))
            postal_code = escape_sql(row.get("postal_code", ""))
            country = escape_sql(row.get("country", "Mexico"))
            lat = row.get("latitude", "0") or "0"
            lng = row.get("longitude", "0") or "0"
            category = row.get("category", "")
            subtypes = row.get("subtypes", "")
            rating = row.get("rating", "0") or "0"
            reviews = row.get("reviews", "0") or "0"
            website = escape_sql(row.get("website", "") or "")
            photo = escape_sql(row.get("photo", "") or "")
            google_id = escape_sql(row.get("google_id", "") or "")
            hours = row.get("working_hours", "")
            if hours and not hours.startswith("{"):
                try:
                    hours = json.dumps(json.loads(hours), ensure_ascii=False)
                except (json.JSONDecodeError, TypeError):
                    hours = ""
            hours = escape_sql(hours)

            cats = map_categories(category, subtypes)
            cats_sql = "ARRAY[" + ",".join(f"'{c}'" for c in cats) + "]::text[]"
            specialties = escape_sql(f"{category}, {subtypes}" if subtypes else category)

            values.append(
                f"('google_maps', '{google_id}', '{name}', '{phone_formatted}', "
                f"'{address}', '{city}', '{state}', '{country}', "
                f"{lat}, {lng}, "
                f"'{photo}', {rating}, {reviews}, "
                f"{cats_sql}, '{specialties}', "
                f"'{hours}', '{website}', '{postal_code}', '{phone}', "
                f"NOW())"
            )

        sql = f"""
INSERT INTO discovered_salons (
    source, source_id, business_name, phone,
    location_address, location_city, location_state, country,
    latitude, longitude,
    feature_image_url, rating_average, rating_count,
    matched_categories, specialties,
    working_hours, website, location_zip, phone_raw,
    scraped_at
) VALUES {', '.join(values)}
ON CONFLICT DO NOTHING;
"""
        result = run_sql(sql)
        batch_num = batch_start // batch_size + 1
        total_batches = (len(new_rows) + batch_size - 1) // batch_size
        total_inserted += len(batch)
        print(f"  Batch {batch_num}/{total_batches}: {len(batch)} rows ({total_inserted}/{len(new_rows)} total)")

    print(f"\nDone! Inserted {total_inserted} new salons into discovered_salons.")

    # Verify count
    new_total = run_sql("SELECT COUNT(*) FROM discovered_salons WHERE country = 'Mexico' OR country = 'MX';")
    print(f"Total MX salons now: {new_total}")


if __name__ == "__main__":
    main()
