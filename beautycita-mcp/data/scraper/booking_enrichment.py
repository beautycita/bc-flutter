#!/usr/bin/env python3
"""
BeautyCita — Booking System Detection Enrichment
Playwright daemon that crawls salon websites to detect what booking platform
they use (Vagaro, Fresha, Booksy, AgendaPro, etc.), calendar feeds, and
generic booking buttons.

Runs as systemd service: beautycita-booking-enrichment.service

Usage:
    python booking_enrichment.py              # run daemon
    python booking_enrichment.py --once       # process one batch then exit
    python booking_enrichment.py --limit 10   # process N sites then exit
"""

import argparse
import csv
import io
import random
import re
import subprocess
import time
from datetime import datetime
from urllib.parse import urljoin, urlparse

from playwright.sync_api import sync_playwright, TimeoutError as PwTimeout

# ── Configuration ───────────────────────────────────────────────────────────

BATCH_SIZE = 50
DELAY_MIN = 30
DELAY_MAX = 60
CONTEXT_ROTATE_EVERY = 15
BREAK_AFTER_BATCH_MIN = 1800   # 30 min
BREAK_AFTER_BATCH_MAX = 3600   # 60 min
MAX_CONSECUTIVE_FAILS = 3
LONG_SLEEP_SECS = 10800        # 3 hours
PAGE_TIMEOUT = 30000           # 30s

DB_CMD = ['ssh', 'www-bc', 'docker', 'exec', '-i', 'supabase-db',
          'psql', '-U', 'postgres', '-d', 'postgres']

USER_AGENTS = [
    "Mozilla/5.0 (X11; Linux x86_64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/131.0.0.0 Safari/537.36",
    "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/131.0.0.0 Safari/537.36",
    "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/131.0.0.0 Safari/537.36",
    "Mozilla/5.0 (X11; Linux x86_64; rv:128.0) Gecko/20100101 Firefox/128.0",
    "Mozilla/5.0 (Windows NT 10.0; Win64; x64; rv:128.0) Gecko/20100101 Firefox/128.0",
    "Mozilla/5.0 (Macintosh; Intel Mac OS X 10.15; rv:128.0) Gecko/20100101 Firefox/128.0",
    "Mozilla/5.0 (X11; Linux x86_64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/130.0.0.0 Safari/537.36",
    "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/130.0.0.0 Safari/537.36",
    "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/18.2 Safari/605.1.15",
    "Mozilla/5.0 (X11; Linux x86_64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/129.0.0.0 Safari/537.36",
]

# ── Booking Platform Patterns ──────────────────────────────────────────────

BOOKING_PATTERNS = {
    'vagaro': {
        'urls': ['vagaro.com'],
        'scripts': ['vagaro.com/widget', 'vagaro.com/resources'],
        'iframes': ['vagaro.com'],
    },
    'fresha': {
        'urls': ['fresha.com', 'shedul.com'],
        'scripts': ['fresha.com', 'shedul.com'],
        'iframes': ['fresha.com', 'widget.shedul.com'],
    },
    'booksy': {
        'urls': ['booksy.com'],
        'scripts': ['booksy.com'],
        'iframes': ['booksy.com'],
    },
    'agendapro': {
        'urls': ['agendapro.com', 'agendapro.cl'],
        'scripts': ['agendapro.com'],
        'iframes': ['agendapro.com'],
    },
    'calendly': {
        'urls': ['calendly.com'],
        'scripts': ['assets.calendly.com'],
        'iframes': ['calendly.com'],
    },
    'google_calendar': {
        'urls': ['calendar.google.com/calendar'],
        'iframes': ['calendar.google.com/calendar/embed'],
    },
    'simplybook': {
        'urls': ['simplybook.me'],
        'scripts': ['simplybook.me'],
        'iframes': ['simplybook.me'],
    },
    'setmore': {
        'urls': ['setmore.com', 'my.setmore.com'],
        'scripts': ['my.setmore.com'],
        'iframes': ['my.setmore.com'],
    },
    'acuity': {
        'urls': ['acuityscheduling.com', 'squarespacescheduling.com', 'app.acuityscheduling.com'],
        'scripts': ['acuityscheduling.com'],
        'iframes': ['app.acuityscheduling.com'],
    },
    'appointy': {
        'urls': ['appointy.com'],
        'scripts': ['appointy.com'],
        'iframes': ['appointy.com'],
    },
    'miagenda': {
        'urls': ['miagendaonline.com', 'miagenda.com.mx'],
        'scripts': ['miagendaonline.com'],
    },
}

# Text patterns for generic booking buttons (case-insensitive)
BOOKING_BUTTON_TEXTS = [
    r'\bReservar\b', r'\bAgendar\b', r'\bBook\s+Now\b', r'\bBook\s+Online\b',
    r'\bCita\b', r'\bAppointment\b', r'\bHacer\s+cita\b', r'\bAgendar\s+cita\b',
    r'\bReserva\s+tu\s+cita\b', r'\bSchedule\b',
]
BOOKING_BUTTON_RE = re.compile('|'.join(BOOKING_BUTTON_TEXTS), re.IGNORECASE)


# ── Helpers ─────────────────────────────────────────────────────────────────

def log(msg: str):
    print(f"[{datetime.now().strftime('%Y-%m-%d %H:%M:%S')}] {msg}", flush=True)


def escape_sql(val: str) -> str:
    """Escape a string for safe inclusion in a SQL single-quoted literal."""
    if val is None:
        return ''
    return val.replace("'", "''").replace("\\", "\\\\")


def sql_str_or_null(val: str | None) -> str:
    """Return 'escaped_val' or NULL for SQL."""
    if not val or not val.strip():
        return "NULL"
    return f"'{escape_sql(val.strip())}'"


def run_sql(sql: str) -> str:
    """Execute SQL via SSH to production psql."""
    try:
        proc = subprocess.run(
            DB_CMD, input=sql, capture_output=True, text=True, timeout=120,
        )
        if proc.returncode != 0:
            log(f"SQL error: {proc.stderr}")
            return ""
        return proc.stdout
    except subprocess.TimeoutExpired:
        log("SQL timeout (120s)")
        return ""
    except Exception as e:
        log(f"SQL exception: {e}")
        return ""


def is_scraper_running() -> bool:
    """Check if another heavy scraper is using Chromium (RAM guard)."""
    try:
        result = subprocess.run(
            ["pgrep", "-f", "scrape_google_maps|ig_enrichment"],
            capture_output=True, text=True, timeout=5,
        )
        return result.returncode == 0
    except Exception:
        return False


# ── DB Access ───────────────────────────────────────────────────────────────

def fetch_queue(limit: int = BATCH_SIZE) -> list[dict]:
    """Get next batch of salons with websites to check."""
    sql = f"""
    COPY (
        SELECT id, website, business_name, location_city
        FROM discovered_salons
        WHERE website IS NOT NULL AND website != ''
          AND booking_enriched_at IS NULL
        ORDER BY (country IN ('Mexico', 'MX')) DESC, rating_count DESC NULLS LAST
        LIMIT {limit}
    ) TO STDOUT WITH CSV HEADER;
    """
    output = run_sql(sql)
    if not output or not output.strip():
        return []
    reader = csv.DictReader(io.StringIO(output))
    return list(reader)


def save_result(salon_id: str, booking_system: str | None,
                booking_url: str | None, calendar_url: str | None):
    """Write detection results to DB."""
    sql = f"""
    UPDATE discovered_salons SET
        booking_system = {sql_str_or_null(booking_system)},
        booking_url = {sql_str_or_null(booking_url)},
        calendar_url = {sql_str_or_null(calendar_url)},
        booking_enriched_at = now(),
        updated_at = now()
    WHERE id = '{escape_sql(salon_id)}';
    """
    run_sql(sql)


def mark_checked(salon_id: str):
    """Mark salon as checked even if nothing found."""
    run_sql(
        f"UPDATE discovered_salons SET booking_enriched_at = now(), "
        f"updated_at = now() WHERE id = '{escape_sql(salon_id)}';"
    )


# ── Detection Logic ────────────────────────────────────────────────────────

def normalize_url(website: str) -> str:
    """Ensure URL has a scheme."""
    url = website.strip()
    if not url:
        return ''
    if not url.startswith(('http://', 'https://')):
        url = 'https://' + url
    return url


def detect_booking_system(page) -> dict:
    """
    Analyze a loaded page for booking system indicators.

    Returns dict with keys:
        booking_system: str | None  — detected platform name
        booking_url: str | None     — URL to booking page/widget
        calendar_url: str | None    — ICS feed or calendar share link
    """
    result = {
        'booking_system': None,
        'booking_url': None,
        'calendar_url': None,
    }

    try:
        # Collect all href values from <a> tags
        hrefs = page.eval_on_selector_all(
            'a[href]',
            'els => els.map(e => e.getAttribute("href")).filter(h => h)'
        )
    except Exception:
        hrefs = []

    try:
        # Collect all script src values
        script_srcs = page.eval_on_selector_all(
            'script[src]',
            'els => els.map(e => e.getAttribute("src")).filter(s => s)'
        )
    except Exception:
        script_srcs = []

    try:
        # Collect all iframe src values
        iframe_srcs = page.eval_on_selector_all(
            'iframe[src]',
            'els => els.map(e => e.getAttribute("src")).filter(s => s)'
        )
    except Exception:
        iframe_srcs = []

    try:
        # Meta tag content
        meta_contents = page.eval_on_selector_all(
            'meta[content]',
            'els => els.map(e => e.getAttribute("content")).filter(c => c)'
        )
    except Exception:
        meta_contents = []

    # Combine all sources for pattern matching
    all_urls = hrefs + script_srcs + iframe_srcs + meta_contents

    # ── 1. Match against known booking platforms ─────────────────────
    for platform, patterns in BOOKING_PATTERNS.items():
        matched_url = None

        # Check hrefs against URL patterns
        for href in hrefs:
            href_lower = href.lower()
            for pattern in patterns.get('urls', []):
                if pattern in href_lower:
                    matched_url = href
                    break
            if matched_url:
                break

        # Check script srcs
        if not matched_url:
            for src in script_srcs:
                src_lower = src.lower()
                for pattern in patterns.get('scripts', []):
                    if pattern in src_lower:
                        matched_url = src
                        break
                if matched_url:
                    break

        # Check iframe srcs
        if not matched_url:
            for src in iframe_srcs:
                src_lower = src.lower()
                for pattern in patterns.get('iframes', []):
                    if pattern in src_lower:
                        matched_url = src
                        break
                if matched_url:
                    break

        # Check meta tags
        if not matched_url:
            for content in meta_contents:
                content_lower = content.lower()
                for pattern in patterns.get('urls', []):
                    if pattern in content_lower:
                        matched_url = content
                        break
                if matched_url:
                    break

        if matched_url:
            result['booking_system'] = platform
            # Clean up the booking URL
            if matched_url.startswith(('http://', 'https://', '//')):
                result['booking_url'] = matched_url
            elif matched_url.startswith('/'):
                try:
                    base = page.url
                    result['booking_url'] = urljoin(base, matched_url)
                except Exception:
                    result['booking_url'] = matched_url
            else:
                result['booking_url'] = matched_url
            break  # First match wins

    # ── 2. Detect ICS feeds ──────────────────────────────────────────
    for href in hrefs:
        href_lower = href.lower()
        if href_lower.endswith('.ics') or '/ical/' in href_lower:
            result['calendar_url'] = href
            break

    # ── 3. Detect Google Calendar share links ────────────────────────
    if not result['calendar_url']:
        for href in hrefs:
            if 'calendar.google.com/calendar' in href and 'cid=' in href:
                result['calendar_url'] = href
                break

    # Also check iframes for embedded Google Calendar
    if not result['calendar_url']:
        for src in iframe_srcs:
            if 'calendar.google.com/calendar/embed' in src:
                result['calendar_url'] = src
                break

    # ── 4. Generic booking buttons (fallback if no platform matched) ─
    if not result['booking_system']:
        booking_btn_url = _find_booking_button(page, hrefs)
        if booking_btn_url:
            result['booking_system'] = 'generic_button'
            result['booking_url'] = booking_btn_url

    return result


def _find_booking_button(page, hrefs: list[str]) -> str | None:
    """
    Look for <a> or <button> with booking-related text and extract the href.
    Returns the first matching URL, or None.
    """
    # Check <a> tags with booking text
    try:
        links = page.eval_on_selector_all(
            'a',
            """els => els.map(e => ({
                text: (e.innerText || '').trim().substring(0, 100),
                href: e.getAttribute('href') || ''
            })).filter(l => l.text && l.href)"""
        )
        for link in links:
            if BOOKING_BUTTON_RE.search(link['text']):
                href = link['href']
                if href and href != '#' and not href.startswith('javascript:'):
                    if href.startswith(('http://', 'https://')):
                        return href
                    try:
                        return urljoin(page.url, href)
                    except Exception:
                        return href
    except Exception:
        pass

    # Check <button> tags inside <a> or with onclick
    try:
        buttons = page.eval_on_selector_all(
            'button',
            """els => els.map(e => ({
                text: (e.innerText || '').trim().substring(0, 100),
                onclick: e.getAttribute('onclick') || '',
                parentHref: e.closest('a') ? e.closest('a').getAttribute('href') : ''
            })).filter(b => b.text)"""
        )
        for btn in buttons:
            if BOOKING_BUTTON_RE.search(btn['text']):
                if btn['parentHref'] and btn['parentHref'] != '#':
                    href = btn['parentHref']
                    if href.startswith(('http://', 'https://')):
                        return href
                    try:
                        return urljoin(page.url, href)
                    except Exception:
                        return href
                # Check onclick for window.open or location.href patterns
                onclick = btn.get('onclick', '')
                url_match = re.search(r"(?:window\.open|location\.href)\s*[=(]\s*['\"]([^'\"]+)['\"]", onclick)
                if url_match:
                    return url_match.group(1)
    except Exception:
        pass

    return None


def crawl_website(page, url: str) -> dict | None:
    """
    Load a salon website and detect booking system.
    Returns detection dict or None on hard failure.
    """
    try:
        response = page.goto(url, wait_until="domcontentloaded", timeout=PAGE_TIMEOUT)

        if response is None:
            return None

        status = response.status
        if status >= 400:
            log(f"    HTTP {status}")
            return None

        # Wait a bit for JS to load widgets/iframes
        time.sleep(3)

        # Check for common error/parking pages
        page_title = page.title().lower()
        parking_indicators = [
            'domain for sale', 'this domain', 'parked', 'suspended',
            'expired', 'coming soon', 'under construction',
            'buy this domain', 'godaddy', 'namecheap parking',
        ]
        for indicator in parking_indicators:
            if indicator in page_title:
                log(f"    Parked/dead domain: {page_title[:60]}")
                return {'booking_system': None, 'booking_url': None, 'calendar_url': None}

        return detect_booking_system(page)

    except PwTimeout:
        log(f"    Timeout ({PAGE_TIMEOUT/1000:.0f}s)")
        return None
    except Exception as e:
        err_str = str(e).lower()
        # Common non-retryable errors
        if any(x in err_str for x in ['net::err_name_not_resolved', 'dns', 'ssl',
                                        'net::err_connection_refused',
                                        'net::err_connection_reset',
                                        'net::err_cert', 'certificate']):
            log(f"    Network error: {str(e)[:80]}")
            return {'booking_system': None, 'booking_url': None, 'calendar_url': None}
        log(f"    Error: {str(e)[:120]}")
        return None


# ── Batch Processing ────────────────────────────────────────────────────────

def process_batch(browser, batch: list[dict]) -> int:
    """Process a batch of salon websites. Returns count of successful detections."""
    enriched = 0
    consecutive_fails = 0
    sites_in_context = 0

    context = browser.new_context(
        viewport={"width": 1280, "height": 900},
        user_agent=random.choice(USER_AGENTS),
        ignore_https_errors=True,
    )
    page = context.new_page()

    # Block heavy resources to save bandwidth/RAM
    def block_media(route):
        if route.request.resource_type in ('image', 'media', 'font', 'stylesheet'):
            route.abort()
        else:
            route.fallback()

    page.route("**/*", block_media)

    for salon in batch:
        # RAM guard: wait if heavy scraper is running
        while is_scraper_running():
            log("Other scraper active, waiting 60s...")
            time.sleep(60)

        salon_id = salon['id']
        website = salon.get('website', '').strip()
        name = salon.get('business_name', '')
        city = salon.get('location_city', '')

        if not website:
            mark_checked(salon_id)
            continue

        url = normalize_url(website)
        if not url:
            mark_checked(salon_id)
            continue

        log(f"  {url[:60]} ({name[:30]}, {city})")
        data = crawl_website(page, url)

        if data is None:
            # Hard failure (timeout, crash) — counts toward consecutive fails
            consecutive_fails += 1
            log(f"  FAIL ({consecutive_fails}/{MAX_CONSECUTIVE_FAILS})")

            if consecutive_fails >= MAX_CONSECUTIVE_FAILS:
                log(f"  {MAX_CONSECUTIVE_FAILS} consecutive fails — sleeping {LONG_SLEEP_SECS/3600:.0f}h")
                mark_checked(salon_id)
                time.sleep(LONG_SLEEP_SECS)
                consecutive_fails = 0
                # Rotate context after long sleep
                page.close()
                context.close()
                context = browser.new_context(
                    viewport={"width": 1280, "height": 900},
                    user_agent=random.choice(USER_AGENTS),
                    ignore_https_errors=True,
                )
                page = context.new_page()
                page.route("**/*", block_media)
                sites_in_context = 0
            else:
                mark_checked(salon_id)
            continue

        consecutive_fails = 0

        # Save results
        bs = data.get('booking_system')
        bu = data.get('booking_url')
        cu = data.get('calendar_url')

        save_result(salon_id, bs, bu, cu)

        if bs:
            enriched += 1
            log(f"    -> {bs} | {(bu or '')[:80]}")
        elif cu:
            enriched += 1
            log(f"    -> calendar: {cu[:80]}")
        else:
            log(f"    -> no booking system detected")

        sites_in_context += 1

        # Rotate context every N sites to prevent memory leaks
        if sites_in_context >= CONTEXT_ROTATE_EVERY:
            page.close()
            context.close()
            context = browser.new_context(
                viewport={"width": 1280, "height": 900},
                user_agent=random.choice(USER_AGENTS),
                ignore_https_errors=True,
            )
            page = context.new_page()
            page.route("**/*", block_media)
            sites_in_context = 0
            log("  Rotated browser context")

        delay = random.uniform(DELAY_MIN, DELAY_MAX)
        time.sleep(delay)

    page.close()
    context.close()
    return enriched


# ── Main ────────────────────────────────────────────────────────────────────

def main():
    parser = argparse.ArgumentParser(description="Booking system detection enrichment daemon")
    parser.add_argument("--once", action="store_true", help="Process one batch then exit")
    parser.add_argument("--limit", type=int, default=0, help="Process N sites then exit")
    args = parser.parse_args()

    log("BeautyCita Booking Enrichment starting")

    with sync_playwright() as pw:
        browser = pw.chromium.launch(
            headless=True,
            args=["--disable-blink-features=AutomationControlled", "--no-sandbox"],
        )

        batch_num = 0
        total_enriched = 0

        while True:
            batch_num += 1
            limit = args.limit if args.limit else BATCH_SIZE
            queue = fetch_queue(limit)

            if not queue:
                log("Queue empty — sleeping 1 hour")
                if args.once or args.limit:
                    break
                time.sleep(3600)
                continue

            log(f"Batch {batch_num}: {len(queue)} sites")
            enriched = process_batch(browser, queue)
            total_enriched += enriched
            log(f"Batch {batch_num} done: {enriched}/{len(queue)} detected (total: {total_enriched})")

            if args.once or args.limit:
                break

            break_time = random.uniform(BREAK_AFTER_BATCH_MIN, BREAK_AFTER_BATCH_MAX)
            log(f"Batch break: {break_time/60:.0f} min")
            time.sleep(break_time)

        browser.close()

    log(f"Done. Total with booking system: {total_enriched}")


if __name__ == "__main__":
    main()
