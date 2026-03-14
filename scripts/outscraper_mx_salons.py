#!/usr/bin/env python3
"""
Outscraper — Mexico Salon Scrape
Pulls all beauty businesses across 80 Mexican cities using 9 search queries.
Results saved to CSV, then imported into discovered_salons via import script.

Cost estimate: ~$43 (at $3/1K results, first 500 free)
Expected results: ~15K new salons (37 cities not yet in our DB)

Usage:
    python3 outscraper_mx_salons.py
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
]

# Only cities we DON'T already have in discovered_salons (checked 2026-03-11)
# 43 cities already covered by beautypi scraper — skipped to avoid paying twice
CITIES = [
    "Xalapa, Veracruz",
    "Celaya, Guanajuato",
    "Irapuato, Guanajuato",
    "Ciudad Juarez, Chihuahua",
    "Nuevo Laredo, Tamaulipas",
    "Matamoros, Tamaulipas",
    "Ensenada, Baja California",
    "San Miguel de Allende, Guanajuato",
    "Tapachula, Chiapas",
    "Ciudad Obregon, Sonora",
    "Nogales, Sonora",
    "Uruapan, Michoacan",
    "Tehuacan, Puebla",
    "Tlaxcala, Tlaxcala",
    "Tulum, Quintana Roo",
    "Cozumel, Quintana Roo",
    "San Cristobal de las Casas, Chiapas",
    "Zihuatanejo, Guerrero",
    "Ecatepec, Estado de Mexico",
    "Naucalpan, Estado de Mexico",
    "Tlalnepantla, Estado de Mexico",
    "Apodaca, Nuevo Leon",
    "San Pedro Garza Garcia, Nuevo Leon",
    "Guadalupe, Nuevo Leon",
    "Rosarito, Baja California",
    "Los Cabos, Baja California Sur",
    "Salamanca, Guanajuato",
    "San Juan del Rio, Queretaro",
    "Tulancingo, Hidalgo",
    "Ciudad del Carmen, Campeche",
    "Coatzacoalcos, Veracruz",
    "Poza Rica, Veracruz",
    "Orizaba, Veracruz",
    "Chilpancingo, Guerrero",
    "Gomez Palacio, Durango",
    "Monclova, Coahuila",
    "Ciudad Victoria, Tamaulipas",
]

# Fields we want (skip heavy stuff like reviews text, posts)
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
PROGRESS_FILE = os.path.join(OUTPUT_DIR, "progress.json")


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

    # Build all query combinations
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

    # Batch queries: Outscraper accepts up to 250 queries at once
    # We'll batch by city — all 9 search terms for one city = 1 API call
    cities_remaining = {}
    for query, city, combo_key in all_combos:
        if city not in cities_remaining:
            cities_remaining[city] = []
        cities_remaining[city].append((query, combo_key))

    csv_path = os.path.join(OUTPUT_DIR, f"mx_salons_{datetime.now():%Y%m%d_%H%M}.csv")
    csv_file = None
    csv_writer = None
    row_count = 0

    for city_idx, (city, queries_for_city) in enumerate(cities_remaining.items()):
        # Build batch: "salon de belleza, CityName, Mexico"
        batch_queries = [f"{q}, {city}, Mexico" for q, _ in queries_for_city]
        combo_keys = [ck for _, ck in queries_for_city]

        print(f"[{done + city_idx + 1}/{total // len(QUERIES)}] {city} ({len(batch_queries)} queries)...", end=" ", flush=True)

        try:
            results = client.google_maps_search(
                query=batch_queries,
                limit=400,
                drop_duplicates=True,
                language="es",
                region="MX",
                fields=FIELDS,
            )

            # Flatten results — with drop_duplicates=True, returns flat list of dicts
            places = []
            if isinstance(results, list):
                for item in results:
                    if isinstance(item, dict):
                        places.append(item)
                    elif isinstance(item, list):
                        places.extend(item)

            # Write to CSV
            if places and csv_writer is None:
                csv_file = open(csv_path, "w", newline="", encoding="utf-8")
                csv_writer = csv.DictWriter(csv_file, fieldnames=places[0].keys(), extrasaction="ignore")
                csv_writer.writeheader()

            if csv_writer:
                for place in places:
                    # Flatten working_hours to string
                    if isinstance(place.get("working_hours"), dict):
                        place["working_hours"] = json.dumps(place["working_hours"], ensure_ascii=False)
                    csv_writer.writerow(place)
                    row_count += 1

            # Update progress
            for ck in combo_keys:
                progress["completed"].append(ck)
            progress["total_results"] += len(places)
            save_progress(progress)

            print(f"{len(places)} results (total: {progress['total_results']})")

        except Exception as e:
            print(f"ERROR: {e}")
            # Don't mark as completed so it retries next run
            if "402" in str(e) or "insufficient" in str(e).lower():
                print("\n*** INSUFFICIENT FUNDS — deposit more credits and re-run ***")
                break
            time.sleep(5)
            continue

        # Small delay between cities to be polite
        time.sleep(1)

    if csv_file:
        csv_file.close()
        print(f"\nResults saved to: {csv_path}")
        print(f"Total rows: {row_count}")
        print(f"Total results across all runs: {progress['total_results']}")


if __name__ == "__main__":
    main()
