#!/usr/bin/env python3
"""
Outscraper — Puerto Vallarta / Banderas Bay Deep Rescan
Covers PV plus all surrounding small towns in the bay area.

Usage:
    python3 outscraper_pv_banderas.py
"""

import json
import csv
import os
import time
from datetime import datetime
from outscraper import ApiClient

API_KEY = 'MGQ2MGIwNzVhOGRlNDcxNjk0N2JjZmYzYThjZTBkNGR8ZGRiYjI0MDExNg'

QUERIES = [
    "salon de belleza",
    "estetica",
    "peluqueria",
    "salon de uñas",
    "barberia",
    "spa de belleza",
    "extensiones de pestañas",
    "maquillaje profesional",
    "corte de cabello",
    "manicure pedicure",
    "tratamiento facial",
    "depilacion",
    "keratina",
    "tinte de cabello",
    "cejas y pestañas",
]

# All towns in Banderas Bay / Riviera Nayarit + surrounding area
CITIES = [
    "Puerto Vallarta, Jalisco",
    "Nuevo Vallarta, Nayarit",
    "Bucerias, Nayarit",
    "Cruz de Huanacaxtle, Nayarit",
    "Punta de Mita, Nayarit",
    "Sayulita, Nayarit",
    "San Pancho, Nayarit",
    "La Cruz de Huanacaxtle, Nayarit",
    "Mezcales, Nayarit",
    "San Jose del Valle, Nayarit",
    "Bahia de Banderas, Nayarit",
    "Rincon de Guayabitos, Nayarit",
    "Lo de Marcos, Nayarit",
    "San Francisco, Nayarit",
    "Ixtapa, Jalisco",
    "Las Juntas, Jalisco",
    "Pitillal, Jalisco",
    "El Pitillal, Puerto Vallarta",
    "Mismaloya, Puerto Vallarta",
    "Conchas Chinas, Puerto Vallarta",
    "Marina Vallarta, Puerto Vallarta",
    "Fluvial Vallarta, Puerto Vallarta",
    "Versalles, Puerto Vallarta",
]

FIELDS = [
    "name", "phone", "address", "street", "city", "state", "postal_code",
    "country", "country_code", "latitude", "longitude",
    "category", "subtypes", "type",
    "rating", "reviews", "verified",
    "website", "photo", "logo",
    "working_hours",
    "google_id", "place_id",
    "business_status",
    "owner_title",
]

OUTPUT_DIR = os.path.expanduser("~/futureBeauty/scripts/outscraper_output")
PROGRESS_FILE = os.path.join(OUTPUT_DIR, "pv_progress.json")


def load_progress():
    if os.path.exists(PROGRESS_FILE):
        with open(PROGRESS_FILE) as f:
            return json.load(f)
    return {"completed": [], "total_results": 0}


def save_progress(progress):
    with open(PROGRESS_FILE, "w") as f:
        json.dump(progress, f, indent=2)


def main():
    os.makedirs(OUTPUT_DIR, exist_ok=True)
    client = ApiClient(api_key=API_KEY)
    progress = load_progress()

    all_combos = []
    for query in QUERIES:
        for city in CITIES:
            combo_key = f"{query}|{city}"
            if combo_key not in progress["completed"]:
                all_combos.append((query, city, combo_key))

    total = len(QUERIES) * len(CITIES)
    done = len(progress["completed"])
    remaining = len(all_combos)
    print(f"Total queries: {total}")
    print(f"Already completed: {done}")
    print(f"Remaining: {remaining}")
    print(f"Results so far: {progress['total_results']}")
    print()

    if remaining == 0:
        print("All queries completed!")
        return

    # Batch by city
    cities_remaining = {}
    for query, city, combo_key in all_combos:
        if city not in cities_remaining:
            cities_remaining[city] = []
        cities_remaining[city].append((query, combo_key))

    csv_path = os.path.join(OUTPUT_DIR, f"pv_banderas_{datetime.now():%Y%m%d_%H%M}.csv")
    csv_file = None
    csv_writer = None
    row_count = 0

    for city_idx, (city, queries_for_city) in enumerate(cities_remaining.items()):
        batch_queries = [f"{q}, {city}, Mexico" for q, _ in queries_for_city]
        combo_keys = [ck for _, ck in queries_for_city]

        print(f"[{city_idx + 1}/{len(cities_remaining)}] {city} ({len(batch_queries)} queries)...", end=" ", flush=True)

        try:
            results = client.google_maps_search(
                query=batch_queries,
                limit=500,
                drop_duplicates=True,
                language="es",
                region="MX",
                fields=FIELDS,
            )

            places = []
            if isinstance(results, list):
                for item in results:
                    if isinstance(item, dict):
                        places.append(item)
                    elif isinstance(item, list):
                        places.extend(item)

            if places and csv_writer is None:
                csv_file = open(csv_path, "w", newline="", encoding="utf-8")
                csv_writer = csv.DictWriter(csv_file, fieldnames=places[0].keys(), extrasaction="ignore")
                csv_writer.writeheader()

            if csv_writer:
                for place in places:
                    if isinstance(place.get("working_hours"), dict):
                        place["working_hours"] = json.dumps(place["working_hours"], ensure_ascii=False)
                    csv_writer.writerow(place)
                    row_count += 1

            for ck in combo_keys:
                progress["completed"].append(ck)
            progress["total_results"] += len(places)
            save_progress(progress)

            print(f"{len(places)} results (total: {progress['total_results']})")

        except Exception as e:
            print(f"ERROR: {e}")
            if "402" in str(e) or "insufficient" in str(e).lower():
                print("\n*** INSUFFICIENT FUNDS — deposit more credits and re-run ***")
                break
            time.sleep(5)
            continue

        time.sleep(1)

    if csv_file:
        csv_file.close()
        print(f"\nResults saved to: {csv_path}")
        print(f"Total rows: {row_count}")
        print(f"Total results across all runs: {progress['total_results']}")
        print("\nNext: python3 scripts/import_outscraper_v2.py " + csv_path)


if __name__ == "__main__":
    main()
