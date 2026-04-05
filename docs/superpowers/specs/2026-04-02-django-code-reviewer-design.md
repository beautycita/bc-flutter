# Django — Autonomous Code Review & Intelligence System

**Date:** 2026-04-02
**Author:** BC + Claude
**Status:** Finished (2026-04-03 — MCP server built, 40+ tools, SQLite DB, 9 lenses. Needs session restart to appear in /mcp.)

---

## Purpose

Django is a standalone MCP server that autonomously reviews code through 9 specialized lenses, produces prioritized findings with trend intelligence, and maintains a permanent historical record of every issue found, fixed, or suspended — tied to build and version numbers.

Django exists because Jetsam proved the concept: an autonomous reviewer that spots dishonest math, magic numbers, unrealistic defaults, and missed opportunities. Django is that concept built properly — structured output, persistent storage, curated presentation, and web pulse intelligence.

## Non-Goals

- Not a linter or formatter. Django reasons about code, it doesn't enforce semicolons.
- Not a CI/CD gate. It runs when BC says so, not on every push.
- Not project-specific. Django reviews any codebase, though it loads project context (CLAUDE.md, memory files) to understand what "correct" means.
- Not a cron job. No scheduled automation. Manual trigger only.

---

## Architecture

```
/home/bc/django/
├── src/
│   ├── mcp/
│   │   ├── server.ts       # MCP entry point (stdio transport)
│   │   └── tools.ts        # Tool definitions and handlers
│   ├── reviewer/
│   │   ├── engine.ts        # Orchestrates file scanning through all lenses
│   │   └── lenses/
│   │       ├── security.ts
│   │       ├── code-quality.ts
│   │       ├── ui.ts
│   │       ├── ux.ts
│   │       ├── data-integrity.ts
│   │       ├── business-logic.ts
│   │       ├── performance.ts
│   │       ├── compliance.ts
│   │       └── showmanship.ts
│   ├── taskqueue/
│   │   ├── db.ts            # Schema, migrations, connection
│   │   ├── queries.ts       # CRUD, priority scoring, history tracking
│   │   └── auto-close.ts    # Watches edits, auto-completes resolved findings
│   ├── pulse/
│   │   └── scanner.ts       # Trend intelligence — 1 result per finding, P1-P3 only
│   └── runner/
│       └── session.ts       # 6-hour session manager with graceful shutdown
├── django.db                # SQLite — all findings, sessions, history
├── package.json
└── tsconfig.json
```

### Dependencies

- `@modelcontextprotocol/sdk` — MCP server protocol
- `better-sqlite3` — SQLite driver (matches memesh stack)
- `zod` — input validation
- `typescript` — type safety

### Registration

Django registers as a Claude Code MCP server in `~/.claude/settings.json` under `mcpServers`:

```json
{
  "mcpServers": {
    "django": {
      "command": "node",
      "args": ["/home/bc/django/dist/mcp/server.js"],
      "env": { "NODE_ENV": "production" }
    }
  }
}
```

---

## Database Schema

### `findings` — Every finding Django produces

| Column | Type | Description |
|--------|------|-------------|
| id | INTEGER PK | Auto-increment |
| session_id | TEXT NOT NULL | Which Django run produced this |
| file_path | TEXT NOT NULL | Absolute path to reviewed file |
| line_start | INTEGER | Start line of the issue |
| line_end | INTEGER | End line of the issue |
| lens | TEXT NOT NULL | One of: security, code-quality, ui, ux, data-integrity, business-logic, performance, compliance, showmanship |
| severity | TEXT NOT NULL | critical, major, minor, opportunity |
| title | TEXT NOT NULL | Short summary |
| description | TEXT NOT NULL | Full explanation of the issue |
| suggestion | TEXT | Proposed fix or direction |
| trend_intel | TEXT | Single top web pulse result (nullable) |
| urgency | INTEGER NOT NULL | 1-5 scale |
| necessity | INTEGER NOT NULL | 1-5 scale |
| priority | INTEGER GENERATED | urgency * necessity (1-25, higher = more important) |
| status | TEXT DEFAULT 'new' | new, curated, planned, in_progress, completed, suspended, needs_verification |
| build_number | TEXT | Build when finding was created |
| version | TEXT | Version when finding was created |
| created_at | TIMESTAMP | When Django found it |
| updated_at | TIMESTAMP | Last status change |
| completed_at | TIMESTAMP | When closed |
| completed_in_build | TEXT | Which build closed this |
| completed_in_version | TEXT | Which version closed this |

### `sessions` — Django's review sessions

| Column | Type | Description |
|--------|------|-------------|
| id | TEXT PK | UUID |
| started_at | TIMESTAMP | Session start |
| stopped_at | TIMESTAMP | Session end |
| trigger | TEXT | 'manual' or 'targeted' |
| scope | TEXT | File path, directory, or 'full' |
| files_reviewed | INTEGER DEFAULT 0 | Count |
| findings_count | INTEGER DEFAULT 0 | Count |
| status | TEXT DEFAULT 'running' | running, wrapping_up, completed, killed |

### `history` — Permanent timeline, nothing is ever deleted

| Column | Type | Description |
|--------|------|-------------|
| id | INTEGER PK | Auto-increment |
| finding_id | INTEGER NOT NULL | FK to findings |
| action | TEXT NOT NULL | created, rescored, curated, started, completed, suspended, reopened, auto_completed, auto_verified |
| actor | TEXT NOT NULL | 'django', 'claude', 'bc' |
| note | TEXT | Reasoning for the change |
| build_number | TEXT | Build at time of action |
| version | TEXT | Version at time of action |
| created_at | TIMESTAMP | When the action happened |

### `file_hashes` — Skip unchanged files between sessions

| Column | Type | Description |
|--------|------|-------------|
| file_path | TEXT PK | Absolute path |
| content_hash | TEXT NOT NULL | SHA-256 of file contents |
| last_reviewed_session | TEXT | FK to sessions |
| last_reviewed_at | TIMESTAMP | When last reviewed |

### Design Rules

- **Nothing is ever deleted.** Status changes are the only mutations. History records every change.
- **Completed findings stay forever**, tagged with the build/version they were closed in.
- **Every status change produces a history entry** with who did it, why, and in which build.
- **Priority is recomputable.** Rescoring updates urgency/necessity and history records old vs new with reasoning.

---

## The 9 Review Lenses

Each lens is an independent analysis pass with a focused expert perspective. All 9 run on every file.

### Lens Definitions

| # | Lens | Focus | Example Finding |
|---|------|-------|-----------------|
| 1 | **Security** | Injection, exposed secrets, auth gaps, XSS, CORS, OWASP top 10 | `supabase.rpc()` call with unescaped user input |
| 2 | **Code Quality** | Magic numbers, dead code, hardcoded values, dishonest math, copy-paste | `bcGrowthRate = 0.25` with no data source |
| 3 | **UI** | Broken layouts, inconsistent spacing, brand drift, responsive gaps, accessibility | Desktop card grid that stacks wrong at 1024px |
| 4 | **UX** | Flow friction, tap count, missing error/empty states, cognitive load | Booking flow requires keyboard input (violates zero-keyboard rule) |
| 5 | **Data Integrity** | Missing constraints, unvalidated boundaries, race conditions, orphaned records | Commission record created without FK to booking |
| 6 | **Business Logic** | Code contradicts product rules (3% on every movement, 4-6 taps, etc.) | Gift card redemption path skips commission |
| 7 | **Performance** | N+1 queries, unnecessary rebuilds, unoptimized assets, blocking calls | Full salon list fetched on every search keystroke |
| 8 | **Compliance** | SAT requirements, LFPDPPP, PROFECO, legal page promises vs actual code behavior | Privacy policy promises data deletion but no delete endpoint exists |
| 9 | **Showmanship** | Missed opportunities for wow. Static where it could animate. Flat where it could have depth. Boring where it could be memorable. | Booking confirmation is a plain card — could be cinematic reveal with haptics and particle burst |

### Lens Rules

Each lens has strict rules loaded from project context (CLAUDE.md, memory files, product rules). However, every rule includes an "unless" escape — conditions where the rule bends. Django flags the deviation but doesn't score it as a violation if the exception is justified.

**Example:** "Zero keyboard input" is a hard UX rule. But freeform text input (gift card messages, custom notes) justifies keyboard use. Django notes "keyboard used here — justified by freeform text" rather than "VIOLATION."

Lenses reason about code. They don't pattern match. A finding must include:
- What the issue is (specific, not vague)
- Why it matters (in context of this product)
- What to do about it (actionable suggestion)

---

## Pulse — Trend Intelligence

After Django scores a finding and writes a suggestion, it does a targeted web scan for what's new and relevant to that specific fix.

### What It Searches

- **GitHub:** Recent repos, releases, stars relevant to the suggestion
- **HuggingFace:** Models that could solve or enhance the suggestion
- **Package registries:** pub.dev (Flutter), npm (web) — new packages or major versions
- **General web:** Blog posts, tutorials, case studies

### Output Format

One result per finding. Top hit only. No filler.

```
Trend Intel: [source] name — why it's relevant (age, stars, status)
```

If nothing relevant exists, field is null. No padding.

### Scope

- Pulse runs only on P1-P3 findings (priority >= 6)
- P4-P5 findings get no trend intel unless manually requested
- One search per finding, one result kept
- Additional searches triggered manually by BC when reviewing findings

---

## Session Runner

### Trigger

BC says "start django unchained" in conversation. Optional scope:
- `"start django unchained"` — full sweep of entire project
- `"start django unchained on beautycita_web/lib/screens/"` — targeted directory
- `"start django unchained on docs/roi-calculator.html"` — single file

### Session Flow

```
1. Create session record in DB
2. Inventory all files in scope
3. Skip files with matching content hash from previous session (unchanged)
4. For each file:
   a. Run all 9 lenses (full LLM analysis, no shortcuts)
   b. Write findings to DB
   c. Pulse scan on P1-P3 findings (1 result each)
   d. Record content hash
   e. Move to next file
5. Natural completion: all files reviewed → session status = 'completed'
6. Safety net (timer, not work limit):
   - 6h  → signal "find a stopping point"
   - 6h30 → signal "stop within 30 minutes"
   - 7h  → kill process
   - verify process is dead
```

### Key Behaviors

- **Reviews deeply, not quickly.** All 9 lenses per file before moving on.
- **Stops naturally when done.** Timer is safety net, not work limit.
- **Skips unchanged files.** Content hash comparison between sessions.
- **No duplicate findings.** If a finding already exists for the same file+line+lens, skip it.
- **Partial work is preserved.** If killed, session status = 'killed', all findings written so far are kept.
- **No cron. No auto-start. No hooks.** BC says the words or it doesn't run.

---

## Auto-Close Logic

When Claude edits a file that has open findings against it, Django checks whether the specific issue was addressed.

| Condition | Action |
|-----------|--------|
| Edit clearly resolves the finding | Auto-mark `completed`, record build number, history: `actor: 'claude', action: 'auto_completed'` |
| Edit is ambiguous — might have fixed it | Mark `needs_verification`, bubbles up next time BC reviews findings |
| File deleted or completely rewritten | Mark `completed`, note: 'file removed/rewritten' |
| Finding still present after edit | No change |

**Rule:** We never have to remember to close tasks. Django watches the work and closes what's done. If it's wrong, we reopen with one action.

---

## Interaction Model

BC never touches the DB directly. Conversation drives everything.

### Query Patterns

| BC says | Claude does |
|---------|-------------|
| "what did django find?" | Summary: X findings (N critical, N major, N minor, N opportunities) |
| "show me security concerns" | Security lens findings sorted by priority, 5 at a time |
| "show me showmanship opportunities" | Showmanship findings sorted by priority, 5 at a time |
| "let's plan fixes for the top 3" | Enter planning mode, draw up the work |
| "suspend the rest for now" | Mark suspended with reasoning in history |
| "more detail on finding #12" | Full context: description, suggestion, trend intel, history |
| "search more on that trend" | Additional pulse searches on that specific finding |
| "mark #12 done, build 48220" | Close with build/version, history records it |
| "start django unchained" | Launch 6-hour review session |
| "start django unchained on docs/" | Launch targeted review of docs directory |

### Presentation Rules

- Small chunks. 5 findings at a time max.
- Sorted by priority (urgency * necessity) descending.
- Each finding shows: ID, title, severity, priority score, one-line suggestion.
- Full detail only when BC asks for it.
- Trend intel shown inline with the finding, not separate.

---

## Priority Scoring

Two axes, each 1-5:

| | Low Necessity (1-2) | High Necessity (3-5) |
|---|---|---|
| **High Urgency (4-5)** | Noise — looks urgent, doesn't matter | Critical — fix now |
| **Low Urgency (1-2)** | Backlog — nice to have | Important — must do, can schedule |

**Composite:** urgency * necessity = 1-25. Higher = more important.

**Examples:**
- Security hole exposing user data → U:5 N:5 = **25 (P1)**
- Magic number in ROI calc → U:2 N:4 = **8 (P3)**
- Flat boring screen, could be cinematic → U:1 N:3 = **3 (P4)**
- Broken desktop layout → U:4 N:4 = **16 (P2)**

Django assigns initial scores. Claude re-evaluates with reasoning when curating. BC sees final scores with the reasoning visible. History tracks every rescore.

---

## Codebase Bounds

Django's workload is finite and bounded:

- ~100 screens (mobile app)
- ~100 pages (web app + docs)
- ~100 edge functions (Supabase)
- ~300 total review targets

Full sweep: ~300 files * 9 lenses = ~2,700 reviews. This is a manageable, bounded set. After a complete sweep and fix cycle, subsequent runs find almost nothing on unchanged files. Django doesn't run nightly forever — it runs hard, you fix, it goes quiet until the next significant build.

---

## Execution Model — How Django Thinks

Django's review engine needs an LLM to reason through the 9 lenses. During autonomous sessions ("start django unchained"), the session runner launches a Claude Code remote agent (or background agent) that drives the review loop. This agent:

- Reads each file
- Runs it through each lens prompt
- Writes findings to the SQLite DB via direct `better-sqlite3` calls (not MCP — Django owns its own DB)
- Calls web search for pulse intel on P1-P3 findings

During interactive sessions (BC + Claude in conversation), Claude calls Django's MCP tools directly — `review` to trigger analysis, `tasks` to query/curate findings, `pulse` to fetch additional trend intel.

The MCP tools are the query/command interface. The autonomous runner is the batch processor. Both write to the same DB.

---

## Future Considerations (Not In Scope Now)

- **Hook integration:** PostToolUse hook to auto-review files after edits (bolt on later)
- **Multi-project support:** Django already stores file paths, adding project scoping is trivial
- **Dashboard:** HTML visualization of findings timeline (like memesh-view)
- **Lens plugins:** Custom lenses added without modifying core (e.g., i18n lens, a11y lens)
