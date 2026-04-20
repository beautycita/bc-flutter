#!/usr/bin/env python3
"""Scaffold compile-anchor tests for every lib file that lacks one.

Compile-anchor tests are deliberate: they don't exercise behavior, but they
do pin two guarantees at build time:
  1. The target module still imports cleanly (catches dep drift, bad imports,
     accidental public API removal).
  2. If the file declares a primary class, that class symbol still exists.

When a file gains real logic worth exercising, replace its anchor with
proper behavior tests. The @anchor tag at the top marks auto-generated
files so a future sweep can pick them out for upgrade.

Usage:
    python3 tools/scaffold_tests.py [--scope app|web|core|all] [--dry-run]

Env: reads pubspec.yaml from each scope to discover package name.
"""
from __future__ import annotations
import argparse, os, re, sys
from pathlib import Path
from typing import Iterator, Optional

ROOT = Path(__file__).resolve().parent.parent

SCOPES = {
    "app":  dict(root="beautycita_app",               pkg="beautycita",
                 skip=("lib/main.dart", "lib/firebase_options.dart")),
    "web":  dict(root="beautycita_web",               pkg="beautycita_web",
                 skip=("lib/main.dart",)),
    "core": dict(root="packages/beautycita_core",     pkg="beautycita_core",
                 skip=("lib/beautycita_core.dart", "lib/models.dart",
                       "lib/supabase.dart", "lib/theme.dart")),
}

EXPORT_ONLY_RE = re.compile(r'^\s*export\s+["\']', re.MULTILINE)
PRIMARY_CLASS_RE = re.compile(
    r'^(?:abstract\s+|final\s+|sealed\s+|base\s+|mixin\s+|interface\s+)?class\s+([A-Z][A-Za-z0-9_]*)',
    re.MULTILINE,
)
ENUM_RE = re.compile(r'^enum\s+([A-Z][A-Za-z0-9_]*)', re.MULTILINE)
JS_INTEROP_RE = re.compile(r"import\s+['\"]dart:js_interop['\"]")

ANCHOR_TAG = "@anchor-test"

HEADER = f"""// {ANCHOR_TAG}: auto-generated compile-anchor test by tools/scaffold_tests.py.
// Pins module import + primary-symbol existence. Replace with real behavior
// tests when the target gains non-trivial logic. The @anchor-test marker
// lets a future sweep list all scaffolded tests for upgrade.
"""

CLASS_TEMPLATE = HEADER + """{teston}
import 'package:flutter_test/flutter_test.dart';
import 'package:{pkg}/{rel}';

void main() {{
  test('{cls_name} symbol exists', () {{
    // Compile-time anchor. If {cls_name} is renamed/removed this fails to compile.
    expect({cls_name}, isNotNull);
  }});
}}
"""

IMPORT_ONLY_TEMPLATE = HEADER + """{teston}
import 'package:flutter_test/flutter_test.dart';
// ignore: unused_import
import 'package:{pkg}/{rel}';

void main() {{
  test('module imports cleanly', () {{
    // No primary class detected; import-only compile anchor.
    expect(true, isTrue);
  }});
}}
"""

def lib_files(scope: dict) -> Iterator[Path]:
    lib = ROOT / scope["root"] / "lib"
    if not lib.is_dir():
        return
    for p in lib.rglob("*.dart"):
        rel = p.relative_to(ROOT / scope["root"]).as_posix()
        if any(rel == s or rel.endswith(s.split("/", 1)[-1]) for s in scope["skip"]):
            continue
        if rel.endswith(".g.dart") or rel.endswith(".freezed.dart"):
            continue
        yield p

def test_path_for(scope: dict, lib_file: Path) -> Path:
    rel = lib_file.relative_to(ROOT / scope["root"] / "lib")
    return ROOT / scope["root"] / "test" / rel.with_name(rel.stem + "_test.dart")

def has_test(scope: dict, lib_file: Path) -> bool:
    primary = test_path_for(scope, lib_file)
    if primary.exists():
        return True
    flat = ROOT / scope["root"] / "test" / (lib_file.stem + "_test.dart")
    return flat.exists()

def is_export_barrel(src: str) -> bool:
    lines = [l.strip() for l in src.splitlines() if l.strip() and not l.strip().startswith("//")]
    if not lines:
        return False
    meaningful = [l for l in lines if not (
        l.startswith("library") or l.startswith("/*") or l.startswith("*") or l == "*/"
    )]
    return bool(meaningful) and all(l.startswith("export ") or l.startswith("part ") for l in meaningful)

def detect_primary(src: str) -> Optional[str]:
    m = PRIMARY_CLASS_RE.search(src)
    if m:
        return m.group(1)
    m = ENUM_RE.search(src)
    if m:
        return m.group(1)
    return None

def gen_for(scope: dict, lib_file: Path) -> Optional[Path]:
    if has_test(scope, lib_file):
        return None
    try:
        src = lib_file.read_text()
    except Exception:
        return None
    if is_export_barrel(src):
        return None  # barrel files don't need their own test

    out = test_path_for(scope, lib_file)
    rel_lib = lib_file.relative_to(ROOT / scope["root"] / "lib").as_posix()
    # Web files frequently pull package:web transitively even when their
    # source doesn't name dart:js_interop. Safer to mark every web-scope
    # scaffold as browser-only so `flutter test` (VM) doesn't trip on
    # transitive JS-interop compile errors. Existing hand-written tests
    # stay on VM by virtue of being hand-written (this generator skips
    # files that already have a test).
    scope_name = next(k for k, v in SCOPES.items() if v is scope)
    browser_only = bool(JS_INTEROP_RE.search(src)) or scope_name == "web"
    teston = "@TestOn('browser')\nlibrary;\n" if browser_only else ""

    cls_name = detect_primary(src)
    if cls_name:
        body = CLASS_TEMPLATE.format(
            teston=teston, pkg=scope["pkg"], rel=rel_lib, cls_name=cls_name,
        )
    else:
        body = IMPORT_ONLY_TEMPLATE.format(
            teston=teston, pkg=scope["pkg"], rel=rel_lib,
        )

    out.parent.mkdir(parents=True, exist_ok=True)
    out.write_text(body)
    return out

def run(which: str, dry: bool) -> None:
    scopes = list(SCOPES.values()) if which == "all" else [SCOPES[which]]
    totals = {"scanned": 0, "already_covered": 0, "barrel_skipped": 0, "generated": 0}
    for scope in scopes:
        scope_name = next(k for k, v in SCOPES.items() if v is scope)
        s_scan = s_cov = s_bar = s_gen = 0
        for lf in lib_files(scope):
            s_scan += 1
            if has_test(scope, lf):
                s_cov += 1
                continue
            src = lf.read_text()
            if is_export_barrel(src):
                s_bar += 1
                continue
            if dry:
                s_gen += 1
                continue
            out = gen_for(scope, lf)
            if out:
                s_gen += 1
        print(f"[{scope_name:4}] scanned={s_scan:4} covered={s_cov:4} barrel_skipped={s_bar:3} {'would-generate' if dry else 'generated'}={s_gen:4}")
        for k, v in [("scanned", s_scan), ("already_covered", s_cov),
                     ("barrel_skipped", s_bar), ("generated", s_gen)]:
            totals[k] += v
    print(f"[total] {totals}")

if __name__ == "__main__":
    p = argparse.ArgumentParser()
    p.add_argument("--scope", default="all", choices=["app", "web", "core", "all"])
    p.add_argument("--dry-run", action="store_true")
    a = p.parse_args()
    run(a.scope, a.dry_run)
