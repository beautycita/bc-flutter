#!/usr/bin/env python3
"""
BeautyPi Status & Action API
Port 3210 — stdlib only, no pip dependencies

GET  /api/bpi/status   — system + service status (no auth)
POST /api/bpi/action    — restart/diagnose/logs/repair (Bearer token)
"""

import json
import subprocess
import time
from http.server import HTTPServer, BaseHTTPRequestHandler

ADMIN_TOKEN = "bc-bpi-admin-2026"
PORT = 3210

# Mapping from friendly service name to systemd unit
SERVICE_MAP = {
    "guestkey": "guestkey",
    "wa-enrichment": "beautycita-wa-enrichment",
    "ig-enrichment": "beautycita-ig-enrichment",
    "lead-generator": "beautycita-scraper",
    "wa-validator": "wa-validator",
}

# Status endpoint service checks (key in response → systemd unit)
STATUS_SERVICES = {
    "guestkey": "guestkey",
    "lead_generator": "beautycita-scraper",
    "wa_enrichment": "beautycita-wa-enrichment",
    "ig_enrichment": "beautycita-ig-enrichment",
    "wa_validator": "wa-validator",
}

LOG_PATHS = {
    "ig_last": "/tmp/ig_enrichment.log",
    "wa_last": "/home/dmyl/beautycita-scraper/logs/wa_enrichment.log",
}


def run_cmd(cmd, timeout=30):
    """Run a shell command and return stdout (empty string on failure)."""
    try:
        r = subprocess.run(cmd, capture_output=True, text=True, timeout=timeout)
        return r.stdout.strip()
    except Exception:
        return ""


def is_active(unit):
    """Check if a systemd unit is active."""
    return run_cmd(["systemctl", "is-active", unit]) == "active"


def tail_file(path, n=1):
    """Read last n lines from a file."""
    try:
        with open(path, "rb") as f:
            # Seek from end to find last n lines
            f.seek(0, 2)
            size = f.tell()
            if size == 0:
                return ""
            buf_size = min(size, 8192)
            f.seek(-buf_size, 2)
            data = f.read().decode("utf-8", errors="replace")
            lines = data.splitlines()
            return "\n".join(lines[-n:])
    except Exception:
        return ""


def get_guestkey_last_log():
    """Get last non-heartbeat log line from guestkey journal."""
    try:
        out = run_cmd([
            "journalctl", "-u", "guestkey", "-n", "20", "--no-pager"
        ])
        if not out:
            return ""
        for line in reversed(out.splitlines()):
            if "Heartbeat send error" not in line:
                return line
        return ""
    except Exception:
        return ""


def get_memory_free_mb():
    """Read free memory from /proc/meminfo."""
    try:
        with open("/proc/meminfo") as f:
            for line in f:
                if line.startswith("MemAvailable:"):
                    kb = int(line.split()[1])
                    return round(kb / 1024)
    except Exception:
        pass
    return 0


def get_disk_free_gb():
    """Get free disk space on root partition."""
    try:
        out = run_cmd(["df", "-BG", "/"])
        # Second line, fourth column (Available)
        parts = out.splitlines()[1].split()
        return round(float(parts[3].rstrip("G")), 1)
    except Exception:
        return 0.0


def get_uptime():
    """Get system uptime string."""
    return run_cmd(["uptime", "-p"])


def build_status():
    """Build the full status response dict."""
    result = {}

    # Service active checks
    for key, unit in STATUS_SERVICES.items():
        result[key] = is_active(unit)

    # Log tails
    for key, path in LOG_PATHS.items():
        result[key] = tail_file(path, n=1)

    result["guestkey_last"] = get_guestkey_last_log()

    # System info
    result["uptime"] = get_uptime()
    result["memory_free_mb"] = get_memory_free_mb()
    result["disk_free_gb"] = get_disk_free_gb()

    return result


def action_restart(unit):
    """Restart a service and report status."""
    run_cmd(["sudo", "systemctl", "restart", unit])
    time.sleep(3)
    active = is_active(unit)
    return {"success": active, "message": "Service restarted", "active": active}


def action_diagnose(unit):
    """Gather diagnostics for a service."""
    status_output = run_cmd(["systemctl", "status", unit, "--no-pager", "-n", "10"])
    recent_logs = run_cmd(["journalctl", "-u", unit, "-n", "20", "--no-pager"])
    memory_mb = get_memory_free_mb()
    load_avg = run_cmd(["uptime"])

    return {
        "status_output": status_output,
        "recent_logs": recent_logs,
        "memory_mb": memory_mb,
        "load_avg": load_avg,
    }


def action_logs(unit):
    """Return last 50 journal lines for a service."""
    logs = run_cmd(["journalctl", "-u", unit, "--no-pager", "-n", "50"])
    return {"logs": logs}


def action_repair(unit):
    """Attempt stop → start repair sequence."""
    run_cmd(["sudo", "systemctl", "stop", unit])
    time.sleep(2)
    run_cmd(["sudo", "systemctl", "start", unit])
    time.sleep(3)
    active = is_active(unit)

    result = {"success": active, "active": active}
    if active:
        result["message"] = "Service repaired and running"
    else:
        error = run_cmd(["journalctl", "-u", unit, "-n", "10", "--no-pager"])
        result["message"] = "Service still not active after repair attempt"
        result["error_output"] = error

    return result


ACTION_HANDLERS = {
    "restart": action_restart,
    "diagnose": action_diagnose,
    "logs": action_logs,
    "repair": action_repair,
}


class Handler(BaseHTTPRequestHandler):

    def log_message(self, format, *args):
        """Suppress default stderr logging."""
        pass

    def send_json(self, data, status=200):
        body = json.dumps(data, ensure_ascii=False).encode("utf-8")
        self.send_response(status)
        self.send_header("Content-Type", "application/json")
        self.send_header("Content-Length", str(len(body)))
        self.end_headers()
        self.wfile.write(body)

    def do_GET(self):
        if self.path == "/api/bpi/status":
            try:
                self.send_json(build_status())
            except Exception as e:
                self.send_json({"error": str(e)}, 500)
        else:
            self.send_json({"error": "Not found"}, 404)

    def do_POST(self):
        if self.path != "/api/bpi/action":
            self.send_json({"error": "Not found"}, 404)
            return

        # Auth check
        auth = self.headers.get("Authorization", "")
        if auth != f"Bearer {ADMIN_TOKEN}":
            self.send_json({"error": "Unauthorized"}, 401)
            return

        # Parse body
        try:
            length = int(self.headers.get("Content-Length", 0))
            body = json.loads(self.rfile.read(length))
        except Exception:
            self.send_json({"error": "Invalid JSON body"}, 400)
            return

        action = body.get("action", "")
        service = body.get("service", "")

        # Validate action
        if action not in ACTION_HANDLERS:
            self.send_json({
                "error": f"Unknown action: {action}",
                "valid_actions": list(ACTION_HANDLERS.keys()),
            }, 400)
            return

        # Validate service name against whitelist
        if service not in SERVICE_MAP:
            self.send_json({
                "error": f"Unknown service: {service}",
                "valid_services": list(SERVICE_MAP.keys()),
            }, 400)
            return

        unit = SERVICE_MAP[service]

        try:
            result = ACTION_HANDLERS[action](unit)
            self.send_json(result)
        except Exception as e:
            self.send_json({"error": str(e)}, 500)


def main():
    server = HTTPServer(("0.0.0.0", PORT), Handler)
    print(f"bpi_status API listening on 0.0.0.0:{PORT}")
    try:
        server.serve_forever()
    except KeyboardInterrupt:
        print("\nShutting down.")
        server.server_close()


if __name__ == "__main__":
    main()
