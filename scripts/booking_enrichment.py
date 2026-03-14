#!/usr/bin/env python3
"""
BeautyCita — Booking System Enrichment Daemon
Playwright daemon that crawls salon websites to detect embedded booking systems.
Runs on beautypi (Raspberry Pi, Debian, Python 3.11, Playwright installed).

Detects: Vagaro, Fresha, Booksy, AgendaPro, Calendly, Google Calendar,
SimplyBook, Setmore, Acuity, MiAgenda, Appointy, and custom booking buttons.

Usage:
    python booking_enrichment.py              # run daemon
    python booking_enrichment.py --once       # process one batch then exit
    python booking_enrichment.py --limit 5    # process N salons then exit
"""

import argparse
import random
import re
import subprocess
import time
from datetime import datetime
from urllib.parse import urlparse

from playwright.sync_api import sync_playwright, TimeoutError as PwTimeout

# ── Configuration ────────────────────────────────────────────────────────────

BATCH_SIZE = 10
DELAY_MIN = 30
DELAY_MAX = 60
BATCH_BREAK_SECS = 300  # 5 minutes between batches
PAGE_TIMEOUT_MS = 30000

DB_CMD_QUERY = [
    'ssh', '-o', 'ConnectTimeout=10', '-o', 'StrictHostKeyChecking=no', 'www-bc',
    'docker', 'exec', '-i', 'supabase-db',
    'psql', '-U', 'postgres', '-d', 'postgres',
    '-t', '-A', '-F', '\t',
]

DB_CMD_EXEC = [
    'ssh', '-o', 'ConnectTimeout=10', '-o', 'StrictHostKeyChecking=no', 'www-bc',
    'docker', 'exec', '-i', 'supabase-db',
    'psql', '-U', 'postgres', '-d', 'postgres',
]

USER_AGENTS = [
    "Mozilla/5.0 (X11; Linux x86_64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/131.0.0.0 Safari/537.36",
    "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/131.0.0.0 Safari/537.36",
    "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/131.0.0.0 Safari/537.36",
    "Mozilla/5.0 (X11; Linux x86_64; rv:128.0) Gecko/20100101 Firefox/128.0",
    "Mozilla/5.0 (Windows NT 10.0; Win64; x64; rv:128.0) Gecko/20100101 Firefox/128.0",
]

# ── Booking Platform Patterns ────────────────────────────────────────────────

BOOKING_PATTERNS = {
    'vagaro': {
        'urls': ['vagaro.com'],
        'scripts': ['vagaro.com/widget', 'vagaro.com/js'],
        'iframes': ['vagaro.com'],
    },
    'fresha': {
        'urls': ['fresha.com', 'shedul.com'],
        'scripts': ['fresha.com'],
        'iframes': ['fresha.com'],
    },
    'booksy': {
        'urls': ['booksy.com'],
        'scripts': ['booksy.com'],
        'iframes': ['booksy.com'],
    },
    'agendapro': {
        'urls': ['agendapro.com'],
        'scripts': ['agendapro.com'],
        'iframes': ['agendapro.com'],
    },
    'calendly': {
        'urls': ['calendly.com'],
        'scripts': ['assets.calendly.com'],
        'iframes': ['calendly.com'],
    },
    'google_calendar': {
        'urls': ['calendar.google.com'],
        'iframes': ['calendar.google.com/calendar/embed'],
    },
    'simplybook': {
        'urls': ['simplybook.me'],
        'scripts': ['simplybook.me'],
    },
    'setmore': {
        'urls': ['setmore.com'],
        'scripts': ['setmore.com'],
    },
    'acuity': {
        'urls': ['acuityscheduling.com', 'squarespacescheduling.com'],
        'scripts': ['acuityscheduling.com'],
    },
    'miagenda': {
        'urls': ['miagenda.com.mx'],
        'scripts': ['miagenda.com.mx'],
    },
    'appointy': {
        'urls': ['appointy.com'],
        'scripts': ['appointy.com'],
    },
}

# Button text patterns that suggest booking functionality
BOOKING_BUTTON_PATTERNS = re.compile(
    r'\b(reservar|book\s*(now|online|appointment)?|agendar|hacer\s*cita|'
    r'schedule|cita\s*online|appointment)\b',
    re.IGNORECASE,
)


# ── Logging ──────────────────────────────────────────────────────────────────

def log(level: str, msg: str):
    ts = datetime.now().strftime('%Y-%m-%d %H:%M:%S')
    print(f"[{ts}] [{level}] {msg}", flush=True)


# ── Database ─────────────────────────────────────────────────────────────────

def db_query(sql: str) -> str:
    """Execute SQL via ssh to production Supabase PostgreSQL."""
    result = subprocess.run(
        DB_CMD_QUERY, input=sql, capture_output=True, text=True, timeout=30,
    )
    if result.returncode != 0:
        raise Exception(f"DB error: {result.stderr}")
    return result.stdout.strip()


def db_execute(sql: str):
    """Execute SQL that doesn't return results."""
    result = subprocess.run(
        DB_CMD_EXEC, input=sql, capture_output=True, text=True, timeout=30,
    )
    if result.returncode != 0:
        raise Exception(f"DB error: {result.stderr}")


def is_scraper_running() -> bool:
    """Check if scraper is actively using Chromium (RAM guard)."""
    try:
        result = subprocess.run(
            ["pgrep", "-f", "scrape_google_maps"],
            capture_output=True, text=True, timeout=5,
        )
        return result.returncode == 0
    except Exception:
        return False


# ── Queue ────────────────────────────────────────────────────────────────────

def fetch_batch(limit: int = BATCH_SIZE) -> list[dict]:
    """Get next batch of salons with websites to check."""
    sql = (
        f"SELECT id, business_name, website FROM discovered_salons "
        f"WHERE website IS NOT NULL AND website != '' "
        f"AND booking_enriched_at IS NULL "
        f"ORDER BY (country IN ('Mexico', 'MX')) DESC, created_at DESC "
        f"LIMIT {limit};"
    )
    output = db_query(sql)
    if not output:
        return []
    rows = []
    for line in output.split('\n'):
        parts = line.split('\t')
        if len(parts) >= 3:
            rows.append({
                'id': parts[0],
                'business_name': parts[1],
                'website': parts[2],
            })
    return rows


def update_salon(salon_id: str, booking_system: str | None,
                 booking_url: str | None, calendar_url: str | None):
    """Write booking detection results to DB."""
    bs = f"'{_esc(booking_system)}'" if booking_system else "NULL"
    bu = f"'{_esc(booking_url)}'" if booking_url else "NULL"
    cu = f"'{_esc(calendar_url)}'" if calendar_url else "NULL"
    sql = (
        f"UPDATE discovered_salons SET "
        f"booking_system = {bs}, "
        f"booking_url = {bu}, "
        f"calendar_url = {cu}, "
        f"booking_enriched_at = NOW() "
        f"WHERE id = '{_esc(salon_id)}';"
    )
    db_execute(sql)


def mark_enriched(salon_id: str):
    """Mark salon as enriched with no results (error or nothing found)."""
    sql = (
        f"UPDATE discovered_salons SET "
        f"booking_enriched_at = NOW() "
        f"WHERE id = '{_esc(salon_id)}';"
    )
    db_execute(sql)


def _esc(val: str) -> str:
    """Escape single quotes for SQL."""
    return val.replace("'", "''") if val else ""


# ── Detection Engine ─────────────────────────────────────────────────────────

def detect_booking(page) -> dict:
    """
    Analyze loaded page for booking system integrations.
    Returns dict with keys: booking_system, booking_url, calendar_url
    """
    result = {
        'booking_system': None,
        'booking_url': None,
        'calendar_url': None,
    }

    # Collect all hrefs from <a> tags
    hrefs = []
    try:
        for el in page.query_selector_all('a[href]'):
            href = el.get_attribute('href') or ''
            if href and not href.startswith('#') and not href.startswith('javascript:'):
                hrefs.append(href)
    except Exception:
        pass

    # Collect all <script> src values
    scripts = []
    try:
        for el in page.query_selector_all('script[src]'):
            src = el.get_attribute('src') or ''
            if src:
                scripts.append(src)
    except Exception:
        pass

    # Collect all <iframe> src values
    iframes = []
    try:
        for el in page.query_selector_all('iframe[src]'):
            src = el.get_attribute('src') or ''
            if src:
                iframes.append(src)
    except Exception:
        pass

    # Check each booking platform
    for platform, patterns in BOOKING_PATTERNS.items():
        matched_url = None

        # Check hrefs against platform URL patterns
        for pattern_str in patterns.get('urls', []):
            for href in hrefs:
                if pattern_str in href.lower():
                    matched_url = href
                    break
            if matched_url:
                break

        # Check scripts
        if not matched_url:
            for pattern_str in patterns.get('scripts', []):
                for src in scripts:
                    if pattern_str in src.lower():
                        matched_url = src
                        break
                if matched_url:
                    break

        # Check iframes
        if not matched_url:
            for pattern_str in patterns.get('iframes', []):
                for src in iframes:
                    if pattern_str in src.lower():
                        matched_url = src
                        break
                if matched_url:
                    break

        if matched_url:
            result['booking_system'] = platform
            result['booking_url'] = matched_url
            break  # First match wins

    # Check for Google Calendar embeds in iframes (calendar_url)
    for src in iframes:
        if 'calendar.google.com/calendar/embed' in src.lower():
            result['calendar_url'] = src
            if not result['booking_system']:
                result['booking_system'] = 'google_calendar'
                result['booking_url'] = src
            break

    # Check for ICS feed links
    for href in hrefs:
        if href.lower().endswith('.ics'):
            result['calendar_url'] = href
            break

    # If no known platform found, check for booking buttons pointing externally
    if not result['booking_system']:
        try:
            # Get the salon's own domain for comparison
            page_domain = urlparse(page.url).netloc.lower()

            for el in page.query_selector_all('a[href]'):
                text = (el.inner_text() or '').strip()
                if not text or len(text) > 60:
                    continue
                if BOOKING_BUTTON_PATTERNS.search(text):
                    href = el.get_attribute('href') or ''
                    if not href or href.startswith('#') or href.startswith('javascript:'):
                        continue
                    try:
                        link_domain = urlparse(href).netloc.lower()
                    except Exception:
                        continue
                    # External booking link (different domain)
                    if link_domain and link_domain != page_domain:
                        result['booking_system'] = 'custom'
                        result['booking_url'] = href
                        break
        except Exception:
            pass

    return result


# ── Page Loading ─────────────────────────────────────────────────────────────

def normalize_url(url: str) -> str:
    """Ensure URL has a scheme."""
    url = url.strip()
    if not url.startswith(('http://', 'https://')):
        url = 'https://' + url
    return url


def load_and_detect(page, url: str) -> dict:
    """Load a URL and run booking detection. Returns detection result dict."""
    url = normalize_url(url)
    page.goto(url, wait_until='domcontentloaded', timeout=PAGE_TIMEOUT_MS)
    # Give dynamic content a moment to load (widgets, iframes)
    time.sleep(3)
    return detect_booking(page)


# ── Batch Processing ─────────────────────────────────────────────────────────

def process_batch(browser, batch: list[dict]) -> tuple[int, int]:
    """Process a batch of salons. Returns (found_count, total_count)."""
    found = 0
    total = 0
    context = browser.new_context(
        viewport={"width": 1280, "height": 900},
        user_agent=random.choice(USER_AGENTS),
    )
    page = context.new_page()

    try:
        for i, salon in enumerate(batch):
            # RAM guard
            while is_scraper_running():
                log('INFO', 'Scraper active, waiting 60s...')
                time.sleep(60)

            salon_id = salon['id']
            name = salon['business_name']
            website = salon['website']
            total += 1

            log('INFO', f'Checking salon: {name} ({website})')

            try:
                result = load_and_detect(page, website)

                if result['booking_system']:
                    log('FOUND', f"{result['booking_system']} detected for {name} -> {result['booking_url']}")
                    found += 1
                else:
                    log('NONE', f'No booking system found for {name}')

                update_salon(
                    salon_id,
                    result['booking_system'],
                    result['booking_url'],
                    result['calendar_url'],
                )

            except PwTimeout:
                log('WARN', f'Timeout loading {website} for {name}')
                try:
                    mark_enriched(salon_id)
                except Exception as db_err:
                    log('ERROR', f'DB mark-enriched failed for {name}: {db_err}')

            except Exception as e:
                log('ERROR', f'Error checking {name}: {e}')
                try:
                    mark_enriched(salon_id)
                except Exception as db_err:
                    log('ERROR', f'DB mark-enriched failed for {name}: {db_err}')

            # Delay between requests (skip after last)
            if i < len(batch) - 1:
                delay = random.uniform(DELAY_MIN, DELAY_MAX)
                time.sleep(delay)

    finally:
        page.close()
        context.close()

    return found, total


# ── Main ─────────────────────────────────────────────────────────────────────

def main():
    parser = argparse.ArgumentParser(description='Booking system enrichment daemon')
    parser.add_argument('--once', action='store_true', help='Process one batch then exit')
    parser.add_argument('--limit', type=int, default=0, help='Process N salons then exit')
    args = parser.parse_args()

    log('INFO', 'BeautyCita Booking Enrichment starting')

    with sync_playwright() as pw:
        browser = pw.chromium.launch(
            headless=True,
            args=['--disable-blink-features=AutomationControlled', '--no-sandbox'],
        )

        batch_num = 0
        total_found = 0
        total_checked = 0

        try:
            while True:
                batch_num += 1
                limit = args.limit if args.limit else BATCH_SIZE

                try:
                    batch = fetch_batch(limit)
                except Exception as e:
                    log('ERROR', f'DB fetch error: {e}')
                    time.sleep(60)
                    continue

                if not batch:
                    log('INFO', 'Queue empty — sleeping 1 hour')
                    if args.once or args.limit:
                        break
                    time.sleep(3600)
                    continue

                log('INFO', f'Batch {batch_num}: {len(batch)} salons')
                found, checked = process_batch(browser, batch)
                total_found += found
                total_checked += checked
                log('INFO',
                    f'Batch {batch_num} done: {found}/{checked} found '
                    f'(total: {total_found}/{total_checked})')

                if args.once or args.limit:
                    break

                log('INFO', f'Next batch in {BATCH_BREAK_SECS // 60} min')
                time.sleep(BATCH_BREAK_SECS)

        finally:
            browser.close()

    log('INFO', f'Done. Total: {total_found} booking systems found in {total_checked} salons')


if __name__ == '__main__':
    main()
