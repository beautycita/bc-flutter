# Django Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Build Django, a standalone MCP server that stores code review findings, manages sessions, tracks history, and provides tools for Claude to query/curate results — all backed by SQLite.

**Architecture:** Django is a storage + utility layer. Claude is the brain. During autonomous sessions, Claude reads files, reasons through 9 lens prompts (provided by Django), and calls Django's MCP tools to store findings. Django owns the DB, file hashing, session management, and auto-close logic. Pulse (web trend intel) is triggered by Claude calling Django's `pulse_search` tool which performs web lookups.

**Tech Stack:** TypeScript, Node.js (ESM), `@modelcontextprotocol/sdk`, `better-sqlite3`, `zod`, `vitest`

**Spec:** `docs/superpowers/specs/2026-04-02-django-code-reviewer-design.md`

---

## File Structure

```
/home/bc/django/
├── src/
│   ├── db.ts                    # Database connection, schema, migrations
│   ├── types.ts                 # Shared TypeScript types/interfaces
│   ├── findings.ts              # Findings CRUD + history tracking
│   ├── sessions.ts              # Session lifecycle management
│   ├── file-inventory.ts        # File discovery + content hashing
│   ├── lenses.ts                # 9 lens definitions (prompts + metadata)
│   ├── auto-close.ts            # Check edits against open findings
│   ├── mcp/
│   │   ├── server.ts            # MCP entry point (stdio transport)
│   │   └── tools.ts             # All tool definitions + handlers
│   └── pulse/
│       └── scanner.ts           # Web search for trend intel
├── tests/
│   ├── db.test.ts
│   ├── findings.test.ts
│   ├── sessions.test.ts
│   ├── file-inventory.test.ts
│   ├── auto-close.test.ts
│   └── lenses.test.ts
├── package.json
├── tsconfig.json
└── vitest.config.ts
```

Each file has one responsibility:
- `db.ts` — open/close/migrate the database. No business logic.
- `types.ts` — all interfaces. No runtime code.
- `findings.ts` — CRUD for findings + automatic history entries on every mutation.
- `sessions.ts` — create/update/query sessions.
- `file-inventory.ts` — glob files in a scope, compute SHA-256 hashes, check if changed.
- `lenses.ts` — the 9 lens definitions as structured data (name, category, prompt template). No LLM calls — Claude uses these prompts.
- `auto-close.ts` — given a file path and its new content, check which open findings are resolved.
- `mcp/server.ts` — MCP server bootstrap. No logic.
- `mcp/tools.ts` — tool schemas + handlers that call into the modules above.
- `pulse/scanner.ts` — construct a search query from a finding, return structured result.

---

### Task 1: Project Scaffolding

**Files:**
- Create: `/home/bc/django/package.json`
- Create: `/home/bc/django/tsconfig.json`
- Create: `/home/bc/django/vitest.config.ts`
- Create: `/home/bc/django/.gitignore`

- [ ] **Step 1: Create project directory**

```bash
mkdir -p /home/bc/django
cd /home/bc/django
```

- [ ] **Step 2: Create package.json**

```json
{
  "name": "django",
  "version": "1.0.0",
  "description": "Autonomous code review & intelligence system for Claude Code",
  "type": "module",
  "main": "dist/mcp/server.js",
  "scripts": {
    "build": "tsc && chmod +x dist/mcp/server.js",
    "test": "vitest run",
    "test:watch": "vitest",
    "typecheck": "tsc --noEmit",
    "start": "node dist/mcp/server.js"
  }
}
```

- [ ] **Step 3: Install dependencies**

```bash
cd /home/bc/django
npm install better-sqlite3 @modelcontextprotocol/sdk zod
npm install -D typescript @types/better-sqlite3 @types/node vitest
```

- [ ] **Step 4: Create tsconfig.json**

```json
{
  "compilerOptions": {
    "target": "ES2022",
    "module": "Node16",
    "moduleResolution": "Node16",
    "outDir": "dist",
    "rootDir": "src",
    "strict": true,
    "esModuleInterop": true,
    "skipLibCheck": true,
    "declaration": true,
    "declarationMap": true,
    "sourceMap": true
  },
  "include": ["src/**/*.ts"],
  "exclude": ["node_modules", "dist", "tests"]
}
```

- [ ] **Step 5: Create vitest.config.ts**

```typescript
import { defineConfig } from 'vitest/config';

export default defineConfig({
  test: {
    globals: true,
    testTimeout: 10000,
  },
});
```

- [ ] **Step 6: Create .gitignore**

```
node_modules/
dist/
django.db
*.db-journal
*.db-wal
```

- [ ] **Step 7: Initialize git and commit**

```bash
cd /home/bc/django
git init
git add package.json tsconfig.json vitest.config.ts .gitignore package-lock.json
git commit -m "feat: project scaffolding for Django code reviewer"
```

- [ ] **Step 8: Verify build compiles (empty project)**

```bash
cd /home/bc/django
mkdir -p src/mcp
echo 'console.log("django");' > src/mcp/server.ts
npx tsc --noEmit
```

Expected: No errors.

---

### Task 2: Types

**Files:**
- Create: `/home/bc/django/src/types.ts`

- [ ] **Step 1: Write the types file**

```typescript
// src/types.ts

export const LENS_NAMES = [
  'security',
  'code-quality',
  'ui',
  'ux',
  'data-integrity',
  'business-logic',
  'performance',
  'compliance',
  'showmanship',
] as const;

export type LensName = (typeof LENS_NAMES)[number];

export const SEVERITY_LEVELS = ['critical', 'major', 'minor', 'opportunity'] as const;
export type Severity = (typeof SEVERITY_LEVELS)[number];

export const FINDING_STATUSES = [
  'new',
  'curated',
  'planned',
  'in_progress',
  'completed',
  'suspended',
  'needs_verification',
] as const;
export type FindingStatus = (typeof FINDING_STATUSES)[number];

export const SESSION_STATUSES = ['running', 'wrapping_up', 'completed', 'killed'] as const;
export type SessionStatus = (typeof SESSION_STATUSES)[number];

export const HISTORY_ACTIONS = [
  'created',
  'rescored',
  'curated',
  'started',
  'completed',
  'suspended',
  'reopened',
  'auto_completed',
  'auto_verified',
] as const;
export type HistoryAction = (typeof HISTORY_ACTIONS)[number];

export const ACTORS = ['django', 'claude', 'bc'] as const;
export type Actor = (typeof ACTORS)[number];

export interface Finding {
  id: number;
  session_id: string;
  file_path: string;
  line_start: number | null;
  line_end: number | null;
  lens: LensName;
  severity: Severity;
  title: string;
  description: string;
  suggestion: string | null;
  trend_intel: string | null;
  urgency: number;
  necessity: number;
  priority: number;
  status: FindingStatus;
  build_number: string | null;
  version: string | null;
  created_at: string;
  updated_at: string | null;
  completed_at: string | null;
  completed_in_build: string | null;
  completed_in_version: string | null;
}

export interface Session {
  id: string;
  started_at: string;
  stopped_at: string | null;
  trigger: 'manual' | 'targeted';
  scope: string;
  files_reviewed: number;
  findings_count: number;
  status: SessionStatus;
}

export interface HistoryEntry {
  id: number;
  finding_id: number;
  action: HistoryAction;
  actor: Actor;
  note: string | null;
  build_number: string | null;
  version: string | null;
  created_at: string;
}

export interface FileHash {
  file_path: string;
  content_hash: string;
  last_reviewed_session: string | null;
  last_reviewed_at: string | null;
}

export interface LensDefinition {
  name: LensName;
  display_name: string;
  description: string;
  prompt: string;
}

export interface FindingInput {
  session_id: string;
  file_path: string;
  line_start?: number;
  line_end?: number;
  lens: LensName;
  severity: Severity;
  title: string;
  description: string;
  suggestion?: string;
  trend_intel?: string;
  urgency: number;
  necessity: number;
  build_number?: string;
  version?: string;
}

export interface FindingFilter {
  lens?: LensName;
  status?: FindingStatus;
  severity?: Severity;
  file_path?: string;
  session_id?: string;
  min_priority?: number;
  limit?: number;
  offset?: number;
}

export interface FindingSummary {
  total: number;
  by_severity: Record<Severity, number>;
  by_lens: Record<LensName, number>;
  by_status: Record<FindingStatus, number>;
}
```

- [ ] **Step 2: Verify types compile**

```bash
cd /home/bc/django && npx tsc --noEmit
```

Expected: No errors.

- [ ] **Step 3: Commit**

```bash
cd /home/bc/django
git add src/types.ts
git commit -m "feat: add all TypeScript type definitions"
```

---

### Task 3: Database Layer

**Files:**
- Create: `/home/bc/django/src/db.ts`
- Create: `/home/bc/django/tests/db.test.ts`

- [ ] **Step 1: Write the failing test**

```typescript
// tests/db.test.ts
import { describe, it, expect, afterEach } from 'vitest';
import { openDatabase, closeDatabase, getDatabase } from '../src/db.js';
import { unlinkSync, existsSync } from 'fs';

const TEST_DB = '/tmp/django-test.db';

afterEach(() => {
  closeDatabase();
  if (existsSync(TEST_DB)) unlinkSync(TEST_DB);
  if (existsSync(TEST_DB + '-wal')) unlinkSync(TEST_DB + '-wal');
  if (existsSync(TEST_DB + '-shm')) unlinkSync(TEST_DB + '-shm');
});

describe('database', () => {
  it('should open a database and create all tables', () => {
    openDatabase(TEST_DB);
    const db = getDatabase();

    const tables = db
      .prepare("SELECT name FROM sqlite_master WHERE type='table' ORDER BY name")
      .all()
      .map((r: any) => r.name);

    expect(tables).toContain('findings');
    expect(tables).toContain('sessions');
    expect(tables).toContain('history');
    expect(tables).toContain('file_hashes');
  });

  it('should have the priority generated column', () => {
    openDatabase(TEST_DB);
    const db = getDatabase();

    // Insert a session first (FK constraint)
    db.prepare("INSERT INTO sessions (id, started_at, trigger, scope) VALUES ('s1', datetime('now'), 'manual', 'full')").run();

    // Insert a finding with urgency=3, necessity=4
    db.prepare(`
      INSERT INTO findings (session_id, file_path, lens, severity, title, description, urgency, necessity)
      VALUES ('s1', '/test.ts', 'security', 'major', 'test', 'test desc', 3, 4)
    `).run();

    const row: any = db.prepare('SELECT priority FROM findings WHERE id = 1').get();
    expect(row.priority).toBe(12); // 3 * 4
  });

  it('should enforce foreign key from findings to sessions', () => {
    openDatabase(TEST_DB);
    const db = getDatabase();

    expect(() => {
      db.prepare(`
        INSERT INTO findings (session_id, file_path, lens, severity, title, description, urgency, necessity)
        VALUES ('nonexistent', '/test.ts', 'security', 'major', 'test', 'desc', 3, 4)
      `).run();
    }).toThrow();
  });
});
```

- [ ] **Step 2: Run test to verify it fails**

```bash
cd /home/bc/django && npx vitest run tests/db.test.ts
```

Expected: FAIL — module `../src/db.js` not found.

- [ ] **Step 3: Write the database module**

```typescript
// src/db.ts
import Database from 'better-sqlite3';

let db: Database.Database | null = null;

const SCHEMA_SQL = `
CREATE TABLE IF NOT EXISTS sessions (
  id TEXT PRIMARY KEY,
  started_at TIMESTAMP NOT NULL DEFAULT (datetime('now')),
  stopped_at TIMESTAMP,
  trigger TEXT NOT NULL DEFAULT 'manual',
  scope TEXT NOT NULL DEFAULT 'full',
  files_reviewed INTEGER NOT NULL DEFAULT 0,
  findings_count INTEGER NOT NULL DEFAULT 0,
  status TEXT NOT NULL DEFAULT 'running'
);

CREATE TABLE IF NOT EXISTS findings (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  session_id TEXT NOT NULL,
  file_path TEXT NOT NULL,
  line_start INTEGER,
  line_end INTEGER,
  lens TEXT NOT NULL,
  severity TEXT NOT NULL,
  title TEXT NOT NULL,
  description TEXT NOT NULL,
  suggestion TEXT,
  trend_intel TEXT,
  urgency INTEGER NOT NULL,
  necessity INTEGER NOT NULL,
  priority INTEGER GENERATED ALWAYS AS (urgency * necessity) STORED,
  status TEXT NOT NULL DEFAULT 'new',
  build_number TEXT,
  version TEXT,
  created_at TIMESTAMP NOT NULL DEFAULT (datetime('now')),
  updated_at TIMESTAMP,
  completed_at TIMESTAMP,
  completed_in_build TEXT,
  completed_in_version TEXT,
  FOREIGN KEY (session_id) REFERENCES sessions(id)
);

CREATE TABLE IF NOT EXISTS history (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  finding_id INTEGER NOT NULL,
  action TEXT NOT NULL,
  actor TEXT NOT NULL,
  note TEXT,
  build_number TEXT,
  version TEXT,
  created_at TIMESTAMP NOT NULL DEFAULT (datetime('now')),
  FOREIGN KEY (finding_id) REFERENCES findings(id)
);

CREATE TABLE IF NOT EXISTS file_hashes (
  file_path TEXT PRIMARY KEY,
  content_hash TEXT NOT NULL,
  last_reviewed_session TEXT,
  last_reviewed_at TIMESTAMP,
  FOREIGN KEY (last_reviewed_session) REFERENCES sessions(id)
);

CREATE INDEX IF NOT EXISTS idx_findings_session ON findings(session_id);
CREATE INDEX IF NOT EXISTS idx_findings_file ON findings(file_path);
CREATE INDEX IF NOT EXISTS idx_findings_lens ON findings(lens);
CREATE INDEX IF NOT EXISTS idx_findings_status ON findings(status);
CREATE INDEX IF NOT EXISTS idx_findings_priority ON findings(priority DESC);
CREATE INDEX IF NOT EXISTS idx_history_finding ON history(finding_id);
CREATE INDEX IF NOT EXISTS idx_history_action ON history(action);
`;

export function openDatabase(path?: string): Database.Database {
  const dbPath = path ?? process.env.DJANGO_DB_PATH ?? new URL('../../django.db', import.meta.url).pathname;
  db = new Database(dbPath);
  db.pragma('journal_mode = WAL');
  db.pragma('foreign_keys = ON');
  db.exec(SCHEMA_SQL);
  return db;
}

export function getDatabase(): Database.Database {
  if (!db) throw new Error('Database not open. Call openDatabase() first.');
  return db;
}

export function closeDatabase(): void {
  if (db) {
    db.close();
    db = null;
  }
}
```

- [ ] **Step 4: Run tests to verify they pass**

```bash
cd /home/bc/django && npx vitest run tests/db.test.ts
```

Expected: 3 tests PASS.

- [ ] **Step 5: Commit**

```bash
cd /home/bc/django
git add src/db.ts tests/db.test.ts
git commit -m "feat: database layer with schema and migrations"
```

---

### Task 4: Findings CRUD + History

**Files:**
- Create: `/home/bc/django/src/findings.ts`
- Create: `/home/bc/django/tests/findings.test.ts`

- [ ] **Step 1: Write the failing tests**

```typescript
// tests/findings.test.ts
import { describe, it, expect, beforeEach, afterEach } from 'vitest';
import { openDatabase, closeDatabase } from '../src/db.js';
import {
  createFinding,
  getFinding,
  queryFindings,
  updateFindingStatus,
  rescoreFinding,
  summarizeFindings,
} from '../src/findings.js';
import type { FindingInput } from '../src/types.js';
import { unlinkSync, existsSync } from 'fs';

const TEST_DB = '/tmp/django-findings-test.db';

function seedSession(id = 's1') {
  const { getDatabase } = await import('../src/db.js');
  const db = getDatabase();
  db.prepare("INSERT OR IGNORE INTO sessions (id, trigger, scope) VALUES (?, 'manual', 'full')").run(id);
}

const baseFinding: FindingInput = {
  session_id: 's1',
  file_path: '/home/bc/futureBeauty/docs/roi-calculator.html',
  line_start: 272,
  line_end: 272,
  lens: 'code-quality',
  severity: 'major',
  title: 'Magic number: bcGrowthRate = 0.25',
  description: 'Hardcoded 25% growth rate with no data source. Inflates revenue projections.',
  suggestion: 'Expose as configurable slider or label as estimate with disclaimer.',
  urgency: 2,
  necessity: 4,
  build_number: '48219',
  version: '1.1.1',
};

beforeEach(() => {
  openDatabase(TEST_DB);
  seedSession();
});

afterEach(() => {
  closeDatabase();
  for (const ext of ['', '-wal', '-shm']) {
    if (existsSync(TEST_DB + ext)) unlinkSync(TEST_DB + ext);
  }
});

describe('createFinding', () => {
  it('should insert a finding and create a history entry', () => {
    const id = createFinding(baseFinding);
    expect(id).toBe(1);

    const finding = getFinding(id);
    expect(finding).not.toBeNull();
    expect(finding!.title).toBe('Magic number: bcGrowthRate = 0.25');
    expect(finding!.priority).toBe(8); // 2 * 4
    expect(finding!.status).toBe('new');
  });
});

describe('queryFindings', () => {
  it('should filter by lens', () => {
    createFinding(baseFinding);
    createFinding({ ...baseFinding, lens: 'security', title: 'XSS risk' });

    const results = queryFindings({ lens: 'security' });
    expect(results).toHaveLength(1);
    expect(results[0].title).toBe('XSS risk');
  });

  it('should sort by priority descending', () => {
    createFinding({ ...baseFinding, urgency: 1, necessity: 1 }); // priority 1
    createFinding({ ...baseFinding, urgency: 5, necessity: 5, title: 'critical' }); // priority 25

    const results = queryFindings({});
    expect(results[0].title).toBe('critical');
  });

  it('should filter by minimum priority', () => {
    createFinding({ ...baseFinding, urgency: 1, necessity: 1 }); // priority 1
    createFinding({ ...baseFinding, urgency: 3, necessity: 3 }); // priority 9

    const results = queryFindings({ min_priority: 5 });
    expect(results).toHaveLength(1);
    expect(results[0].priority).toBe(9);
  });
});

describe('updateFindingStatus', () => {
  it('should update status and record history', () => {
    const id = createFinding(baseFinding);
    updateFindingStatus(id, 'completed', 'claude', 'Fixed in edit to line 272', '48220', '1.1.2');

    const finding = getFinding(id);
    expect(finding!.status).toBe('completed');
    expect(finding!.completed_at).not.toBeNull();
    expect(finding!.completed_in_build).toBe('48220');
  });
});

describe('rescoreFinding', () => {
  it('should update urgency/necessity and record history with old scores', () => {
    const id = createFinding(baseFinding);
    rescoreFinding(id, 4, 5, 'claude', 'Elevated after discovering it affects all pricing displays');

    const finding = getFinding(id);
    expect(finding!.urgency).toBe(4);
    expect(finding!.necessity).toBe(5);
    expect(finding!.priority).toBe(20);
  });
});

describe('summarizeFindings', () => {
  it('should return counts by severity, lens, and status', () => {
    createFinding(baseFinding);
    createFinding({ ...baseFinding, severity: 'critical', lens: 'security' });

    const summary = summarizeFindings();
    expect(summary.total).toBe(2);
    expect(summary.by_severity.critical).toBe(1);
    expect(summary.by_severity.major).toBe(1);
    expect(summary.by_lens['code-quality']).toBe(1);
    expect(summary.by_lens.security).toBe(1);
  });
});
```

- [ ] **Step 2: Run tests to verify they fail**

```bash
cd /home/bc/django && npx vitest run tests/findings.test.ts
```

Expected: FAIL — module `../src/findings.js` not found.

- [ ] **Step 3: Write the findings module**

```typescript
// src/findings.ts
import { getDatabase } from './db.js';
import type {
  Finding,
  FindingInput,
  FindingFilter,
  FindingStatus,
  FindingSummary,
  HistoryAction,
  Actor,
  Severity,
  LensName,
  SEVERITY_LEVELS,
  LENS_NAMES,
  FINDING_STATUSES,
} from './types.js';

export function findingExists(filePath: string, lens: string, lineStart?: number): boolean {
  const db = getDatabase();
  const openStatuses = ['new', 'curated', 'planned', 'in_progress', 'needs_verification'];
  const placeholders = openStatuses.map(() => '?').join(', ');

  if (lineStart != null) {
    const row = db.prepare(
      `SELECT id FROM findings WHERE file_path = ? AND lens = ? AND line_start = ? AND status IN (${placeholders}) LIMIT 1`
    ).get(filePath, lens, lineStart, ...openStatuses);
    return !!row;
  }

  const row = db.prepare(
    `SELECT id FROM findings WHERE file_path = ? AND lens = ? AND status IN (${placeholders}) LIMIT 1`
  ).get(filePath, lens, ...openStatuses);
  return !!row;
}

export function createFinding(input: FindingInput): number {
  // Skip duplicates: same file + lens + line in an open status
  if (findingExists(input.file_path, input.lens, input.line_start)) {
    return -1; // Signal: duplicate, not stored
  }

  const db = getDatabase();
  const result = db.prepare(`
    INSERT INTO findings (session_id, file_path, line_start, line_end, lens, severity, title, description, suggestion, trend_intel, urgency, necessity, build_number, version)
    VALUES (@session_id, @file_path, @line_start, @line_end, @lens, @severity, @title, @description, @suggestion, @trend_intel, @urgency, @necessity, @build_number, @version)
  `).run({
    session_id: input.session_id,
    file_path: input.file_path,
    line_start: input.line_start ?? null,
    line_end: input.line_end ?? null,
    lens: input.lens,
    severity: input.severity,
    title: input.title,
    description: input.description,
    suggestion: input.suggestion ?? null,
    trend_intel: input.trend_intel ?? null,
    urgency: input.urgency,
    necessity: input.necessity,
    build_number: input.build_number ?? null,
    version: input.version ?? null,
  });

  const findingId = Number(result.lastInsertRowid);

  addHistory(findingId, 'created', 'django', null, input.build_number, input.version);

  return findingId;
}

export function getFinding(id: number): Finding | null {
  const db = getDatabase();
  const row = db.prepare('SELECT * FROM findings WHERE id = ?').get(id);
  return (row as Finding) ?? null;
}

export function queryFindings(filter: FindingFilter): Finding[] {
  const db = getDatabase();
  const conditions: string[] = [];
  const params: Record<string, any> = {};

  if (filter.lens) {
    conditions.push('lens = @lens');
    params.lens = filter.lens;
  }
  if (filter.status) {
    conditions.push('status = @status');
    params.status = filter.status;
  }
  if (filter.severity) {
    conditions.push('severity = @severity');
    params.severity = filter.severity;
  }
  if (filter.file_path) {
    conditions.push('file_path = @file_path');
    params.file_path = filter.file_path;
  }
  if (filter.session_id) {
    conditions.push('session_id = @session_id');
    params.session_id = filter.session_id;
  }
  if (filter.min_priority) {
    conditions.push('priority >= @min_priority');
    params.min_priority = filter.min_priority;
  }

  const where = conditions.length > 0 ? 'WHERE ' + conditions.join(' AND ') : '';
  const limit = filter.limit ?? 50;
  const offset = filter.offset ?? 0;

  return db.prepare(`SELECT * FROM findings ${where} ORDER BY priority DESC, created_at DESC LIMIT @limit OFFSET @offset`).all({
    ...params,
    limit,
    offset,
  }) as Finding[];
}

export function updateFindingStatus(
  id: number,
  status: FindingStatus,
  actor: Actor,
  note?: string,
  buildNumber?: string,
  version?: string,
): void {
  const db = getDatabase();
  const isCompleting = status === 'completed';

  db.prepare(`
    UPDATE findings SET
      status = @status,
      updated_at = datetime('now'),
      completed_at = CASE WHEN @is_completing THEN datetime('now') ELSE completed_at END,
      completed_in_build = CASE WHEN @is_completing THEN @build_number ELSE completed_in_build END,
      completed_in_version = CASE WHEN @is_completing THEN @version ELSE completed_in_version END
    WHERE id = @id
  `).run({
    id,
    status,
    is_completing: isCompleting ? 1 : 0,
    build_number: buildNumber ?? null,
    version: version ?? null,
  });

  const action: HistoryAction = status === 'completed' ? 'completed'
    : status === 'suspended' ? 'suspended'
    : status === 'in_progress' ? 'started'
    : status === 'curated' ? 'curated'
    : 'reopened';

  addHistory(id, action, actor, note ?? null, buildNumber, version);
}

export function rescoreFinding(
  id: number,
  urgency: number,
  necessity: number,
  actor: Actor,
  note: string,
): void {
  const db = getDatabase();
  const old = getFinding(id);
  if (!old) throw new Error(`Finding ${id} not found`);

  db.prepare(`
    UPDATE findings SET urgency = @urgency, necessity = @necessity, updated_at = datetime('now')
    WHERE id = @id
  `).run({ id, urgency, necessity });

  addHistory(
    id,
    'rescored',
    actor,
    `U:${old.urgency}→${urgency} N:${old.necessity}→${necessity}. ${note}`,
    old.build_number,
    old.version,
  );
}

export function summarizeFindings(filter?: { session_id?: string }): FindingSummary {
  const db = getDatabase();
  const where = filter?.session_id ? 'WHERE session_id = ?' : '';
  const params = filter?.session_id ? [filter.session_id] : [];

  const total = (db.prepare(`SELECT COUNT(*) as count FROM findings ${where}`).get(...params) as any).count;

  const bySeverity = Object.fromEntries(
    (db.prepare(`SELECT severity, COUNT(*) as count FROM findings ${where} GROUP BY severity`).all(...params) as any[])
      .map(r => [r.severity, r.count])
  ) as Record<Severity, number>;

  const byLens = Object.fromEntries(
    (db.prepare(`SELECT lens, COUNT(*) as count FROM findings ${where} GROUP BY lens`).all(...params) as any[])
      .map(r => [r.lens, r.count])
  ) as Record<LensName, number>;

  const byStatus = Object.fromEntries(
    (db.prepare(`SELECT status, COUNT(*) as count FROM findings ${where} GROUP BY status`).all(...params) as any[])
      .map(r => [r.status, r.count])
  ) as Record<FindingStatus, number>;

  return { total, by_severity: bySeverity, by_lens: byLens, by_status: byStatus };
}

export function getHistory(findingId: number): import('./types.js').HistoryEntry[] {
  const db = getDatabase();
  return db.prepare('SELECT * FROM history WHERE finding_id = ? ORDER BY created_at ASC').all(findingId) as any[];
}

function addHistory(
  findingId: number,
  action: HistoryAction,
  actor: Actor,
  note: string | null,
  buildNumber?: string,
  version?: string,
): void {
  const db = getDatabase();
  db.prepare(`
    INSERT INTO history (finding_id, action, actor, note, build_number, version)
    VALUES (@finding_id, @action, @actor, @note, @build_number, @version)
  `).run({
    finding_id: findingId,
    action,
    actor,
    note,
    build_number: buildNumber ?? null,
    version: version ?? null,
  });
}
```

- [ ] **Step 4: Fix test — seedSession needs to be synchronous**

The test file has `await import()` inside a non-async function. Fix `seedSession`:

```typescript
// In tests/findings.test.ts, replace the seedSession function with:
import { openDatabase, closeDatabase, getDatabase } from '../src/db.js';

function seedSession(id = 's1') {
  const db = getDatabase();
  db.prepare("INSERT OR IGNORE INTO sessions (id, trigger, scope) VALUES (?, 'manual', 'full')").run(id);
}
```

- [ ] **Step 5: Run tests**

```bash
cd /home/bc/django && npx vitest run tests/findings.test.ts
```

Expected: All 6 tests PASS.

- [ ] **Step 6: Commit**

```bash
cd /home/bc/django
git add src/findings.ts tests/findings.test.ts
git commit -m "feat: findings CRUD with automatic history tracking"
```

---

### Task 5: Session Management

**Files:**
- Create: `/home/bc/django/src/sessions.ts`
- Create: `/home/bc/django/tests/sessions.test.ts`

- [ ] **Step 1: Write the failing tests**

```typescript
// tests/sessions.test.ts
import { describe, it, expect, beforeEach, afterEach } from 'vitest';
import { openDatabase, closeDatabase } from '../src/db.js';
import {
  createSession,
  getSession,
  updateSessionStatus,
  incrementSessionCounters,
} from '../src/sessions.js';
import { unlinkSync, existsSync } from 'fs';

const TEST_DB = '/tmp/django-sessions-test.db';

beforeEach(() => { openDatabase(TEST_DB); });
afterEach(() => {
  closeDatabase();
  for (const ext of ['', '-wal', '-shm']) {
    if (existsSync(TEST_DB + ext)) unlinkSync(TEST_DB + ext);
  }
});

describe('createSession', () => {
  it('should create a session with running status', () => {
    const id = createSession('manual', 'full');
    const session = getSession(id);
    expect(session).not.toBeNull();
    expect(session!.status).toBe('running');
    expect(session!.trigger).toBe('manual');
    expect(session!.scope).toBe('full');
    expect(session!.files_reviewed).toBe(0);
    expect(session!.findings_count).toBe(0);
  });
});

describe('updateSessionStatus', () => {
  it('should update status and set stopped_at on completion', () => {
    const id = createSession('manual', 'full');
    updateSessionStatus(id, 'completed');

    const session = getSession(id);
    expect(session!.status).toBe('completed');
    expect(session!.stopped_at).not.toBeNull();
  });
});

describe('incrementSessionCounters', () => {
  it('should increment files_reviewed and findings_count', () => {
    const id = createSession('targeted', '/home/bc/futureBeauty/docs/');
    incrementSessionCounters(id, { files: 1, findings: 3 });
    incrementSessionCounters(id, { files: 1, findings: 2 });

    const session = getSession(id);
    expect(session!.files_reviewed).toBe(2);
    expect(session!.findings_count).toBe(5);
  });
});
```

- [ ] **Step 2: Run tests to verify they fail**

```bash
cd /home/bc/django && npx vitest run tests/sessions.test.ts
```

Expected: FAIL — module not found.

- [ ] **Step 3: Write the sessions module**

```typescript
// src/sessions.ts
import { randomUUID } from 'crypto';
import { getDatabase } from './db.js';
import type { Session, SessionStatus } from './types.js';

export function createSession(trigger: 'manual' | 'targeted', scope: string): string {
  const db = getDatabase();
  const id = randomUUID();
  db.prepare(`
    INSERT INTO sessions (id, trigger, scope) VALUES (@id, @trigger, @scope)
  `).run({ id, trigger, scope });
  return id;
}

export function getSession(id: string): Session | null {
  const db = getDatabase();
  const row = db.prepare('SELECT * FROM sessions WHERE id = ?').get(id);
  return (row as Session) ?? null;
}

export function updateSessionStatus(id: string, status: SessionStatus): void {
  const db = getDatabase();
  const isTerminal = status === 'completed' || status === 'killed';
  db.prepare(`
    UPDATE sessions SET
      status = @status,
      stopped_at = CASE WHEN @is_terminal THEN datetime('now') ELSE stopped_at END
    WHERE id = @id
  `).run({ id, status, is_terminal: isTerminal ? 1 : 0 });
}

export function incrementSessionCounters(
  id: string,
  counts: { files?: number; findings?: number },
): void {
  const db = getDatabase();
  db.prepare(`
    UPDATE sessions SET
      files_reviewed = files_reviewed + @files,
      findings_count = findings_count + @findings
    WHERE id = @id
  `).run({
    id,
    files: counts.files ?? 0,
    findings: counts.findings ?? 0,
  });
}

export function listSessions(limit = 10): Session[] {
  const db = getDatabase();
  return db.prepare('SELECT * FROM sessions ORDER BY started_at DESC LIMIT ?').all(limit) as Session[];
}
```

- [ ] **Step 4: Run tests**

```bash
cd /home/bc/django && npx vitest run tests/sessions.test.ts
```

Expected: All 3 tests PASS.

- [ ] **Step 5: Commit**

```bash
cd /home/bc/django
git add src/sessions.ts tests/sessions.test.ts
git commit -m "feat: session lifecycle management"
```

---

### Task 6: File Inventory + Content Hashing

**Files:**
- Create: `/home/bc/django/src/file-inventory.ts`
- Create: `/home/bc/django/tests/file-inventory.test.ts`

- [ ] **Step 1: Write the failing tests**

```typescript
// tests/file-inventory.test.ts
import { describe, it, expect, beforeEach, afterEach } from 'vitest';
import { openDatabase, closeDatabase } from '../src/db.js';
import { hashFile, hasFileChanged, recordFileHash, inventoryFiles } from '../src/file-inventory.js';
import { writeFileSync, mkdirSync, unlinkSync, existsSync, rmSync } from 'fs';

const TEST_DB = '/tmp/django-fileinv-test.db';
const TEST_DIR = '/tmp/django-fileinv-testdir';

beforeEach(() => {
  openDatabase(TEST_DB);
  mkdirSync(TEST_DIR, { recursive: true });
  mkdirSync(TEST_DIR + '/sub', { recursive: true });
  writeFileSync(TEST_DIR + '/app.dart', 'void main() {}');
  writeFileSync(TEST_DIR + '/page.html', '<html></html>');
  writeFileSync(TEST_DIR + '/sub/widget.dart', 'class Widget {}');
  writeFileSync(TEST_DIR + '/readme.md', '# Readme');
});

afterEach(() => {
  closeDatabase();
  rmSync(TEST_DIR, { recursive: true, force: true });
  for (const ext of ['', '-wal', '-shm']) {
    if (existsSync(TEST_DB + ext)) unlinkSync(TEST_DB + ext);
  }
});

describe('hashFile', () => {
  it('should return a consistent SHA-256 hash', () => {
    const h1 = hashFile(TEST_DIR + '/app.dart');
    const h2 = hashFile(TEST_DIR + '/app.dart');
    expect(h1).toBe(h2);
    expect(h1).toHaveLength(64); // SHA-256 hex
  });
});

describe('hasFileChanged', () => {
  it('should return true for a file never reviewed', () => {
    expect(hasFileChanged(TEST_DIR + '/app.dart')).toBe(true);
  });

  it('should return false for an unchanged file after recording', () => {
    recordFileHash(TEST_DIR + '/app.dart', 's1');
    expect(hasFileChanged(TEST_DIR + '/app.dart')).toBe(false);
  });

  it('should return true after file content changes', () => {
    recordFileHash(TEST_DIR + '/app.dart', 's1');
    writeFileSync(TEST_DIR + '/app.dart', 'void main() { print("changed"); }');
    expect(hasFileChanged(TEST_DIR + '/app.dart')).toBe(true);
  });
});

describe('inventoryFiles', () => {
  it('should find dart and html files recursively', () => {
    const files = inventoryFiles(TEST_DIR, ['*.dart', '*.html']);
    expect(files).toHaveLength(3);
    expect(files.some(f => f.endsWith('app.dart'))).toBe(true);
    expect(files.some(f => f.endsWith('widget.dart'))).toBe(true);
    expect(files.some(f => f.endsWith('page.html'))).toBe(true);
  });

  it('should not include non-matching files', () => {
    const files = inventoryFiles(TEST_DIR, ['*.dart']);
    expect(files.every(f => f.endsWith('.dart'))).toBe(true);
  });
});
```

- [ ] **Step 2: Run tests to verify they fail**

```bash
cd /home/bc/django && npx vitest run tests/file-inventory.test.ts
```

Expected: FAIL — module not found.

- [ ] **Step 3: Write the file-inventory module**

```typescript
// src/file-inventory.ts
import { createHash } from 'crypto';
import { readFileSync, readdirSync, statSync } from 'fs';
import { join, extname } from 'path';
import { getDatabase } from './db.js';

export function hashFile(filePath: string): string {
  const content = readFileSync(filePath);
  return createHash('sha256').update(content).digest('hex');
}

export function hasFileChanged(filePath: string): boolean {
  const db = getDatabase();
  const row = db.prepare('SELECT content_hash FROM file_hashes WHERE file_path = ?').get(filePath) as
    | { content_hash: string }
    | undefined;

  if (!row) return true;

  const currentHash = hashFile(filePath);
  return currentHash !== row.content_hash;
}

export function recordFileHash(filePath: string, sessionId: string): void {
  const db = getDatabase();
  const hash = hashFile(filePath);
  db.prepare(`
    INSERT INTO file_hashes (file_path, content_hash, last_reviewed_session, last_reviewed_at)
    VALUES (@file_path, @hash, @session_id, datetime('now'))
    ON CONFLICT(file_path) DO UPDATE SET
      content_hash = @hash,
      last_reviewed_session = @session_id,
      last_reviewed_at = datetime('now')
  `).run({ file_path: filePath, hash, session_id: sessionId });
}

export function inventoryFiles(directory: string, patterns: string[]): string[] {
  const results: string[] = [];
  const extensions = patterns.map(p => p.replace('*', ''));

  function walk(dir: string): void {
    const entries = readdirSync(dir, { withFileTypes: true });
    for (const entry of entries) {
      const fullPath = join(dir, entry.name);
      if (entry.isDirectory()) {
        if (entry.name === 'node_modules' || entry.name === '.git' || entry.name === 'build' || entry.name === 'dist') continue;
        walk(fullPath);
      } else if (entry.isFile()) {
        const ext = extname(entry.name);
        if (extensions.some(e => ext === e)) {
          results.push(fullPath);
        }
      }
    }
  }

  walk(directory);
  return results.sort();
}
```

- [ ] **Step 4: Run tests**

```bash
cd /home/bc/django && npx vitest run tests/file-inventory.test.ts
```

Expected: All 5 tests PASS.

- [ ] **Step 5: Commit**

```bash
cd /home/bc/django
git add src/file-inventory.ts tests/file-inventory.test.ts
git commit -m "feat: file inventory with content hashing for skip-unchanged logic"
```

---

### Task 7: Lens Definitions

**Files:**
- Create: `/home/bc/django/src/lenses.ts`
- Create: `/home/bc/django/tests/lenses.test.ts`

- [ ] **Step 1: Write the failing test**

```typescript
// tests/lenses.test.ts
import { describe, it, expect } from 'vitest';
import { getLens, getAllLenses, LENS_NAMES } from '../src/lenses.js';

describe('lenses', () => {
  it('should have exactly 9 lenses', () => {
    const all = getAllLenses();
    expect(all).toHaveLength(9);
  });

  it('should have a lens for every LENS_NAME', () => {
    for (const name of LENS_NAMES) {
      const lens = getLens(name);
      expect(lens).not.toBeNull();
      expect(lens!.name).toBe(name);
      expect(lens!.prompt.length).toBeGreaterThan(100);
    }
  });

  it('each lens prompt should contain the lens focus area', () => {
    const security = getLens('security');
    expect(security!.prompt).toContain('security');

    const showmanship = getLens('showmanship');
    expect(showmanship!.prompt).toContain('wow');
  });

  it('each lens prompt should include the "unless" escape clause', () => {
    for (const lens of getAllLenses()) {
      expect(lens.prompt.toLowerCase()).toContain('unless');
    }
  });
});
```

- [ ] **Step 2: Run tests to verify they fail**

```bash
cd /home/bc/django && npx vitest run tests/lenses.test.ts
```

Expected: FAIL — module not found.

- [ ] **Step 3: Write the lenses module**

```typescript
// src/lenses.ts
import type { LensDefinition, LensName } from './types.js';
export { LENS_NAMES } from './types.js';

const LENSES: LensDefinition[] = [
  {
    name: 'security',
    display_name: 'Security',
    description: 'Injection, exposed secrets, auth gaps, XSS, CORS, OWASP top 10',
    prompt: `You are a security auditor reviewing this file. Focus on:
- SQL injection, command injection, XSS, CSRF vulnerabilities
- Exposed secrets, API keys, tokens, passwords in code or config
- Authentication and authorization gaps (missing checks, bypassable guards)
- CORS misconfigurations
- Insecure data handling (unencrypted PII, logs with sensitive data)
- OWASP top 10 vulnerabilities
- Supabase RPC/RLS policy gaps — does the query trust user input?

For each issue found, provide: title, description, severity (critical/major/minor/opportunity), line numbers, and a specific fix suggestion.

Score urgency (1-5): how soon this needs fixing (5 = actively exploitable).
Score necessity (1-5): how important this is to the product (5 = user data at risk).

Rules are strict unless the code is in a test file, a local-only dev script, or the "secret" is a well-known placeholder (e.g., example API keys in documentation).

Return findings as JSON array. If no issues found, return empty array.`,
  },
  {
    name: 'code-quality',
    display_name: 'Code Quality',
    description: 'Magic numbers, dead code, hardcoded values, dishonest math, copy-paste',
    prompt: `You are a code quality reviewer. Focus on:
- Magic numbers and hardcoded values that should be configurable or named constants
- Dead code, unreachable branches, unused variables/imports
- Dishonest math — calculations that inflate, hide, or misrepresent values (e.g., cost savings shown as revenue, unsubstantiated growth rates)
- Copy-paste code that should be abstracted
- Misleading variable names or comments that contradict the code
- Functions doing too many things
- Inconsistent patterns within the same file

For each issue found, provide: title, description, severity, line numbers, and a specific fix suggestion.

Score urgency (1-5): how soon this needs fixing (5 = actively misleading users).
Score necessity (1-5): how important this is (5 = fundamentally wrong logic).

Rules are strict unless the hardcoded value is a mathematical constant (pi, e), a well-documented industry standard, or a test fixture. Preset/default values in UI are acceptable if the user can change them via controls.

Return findings as JSON array. If no issues found, return empty array.`,
  },
  {
    name: 'ui',
    display_name: 'UI',
    description: 'Layout issues, spacing, brand consistency, responsive breakpoints, accessibility',
    prompt: `You are a UI design reviewer. Focus on:
- Layout issues: elements that would overlap, overflow, or misalign
- Inconsistent spacing, padding, margins within the file
- Brand drift: colors, fonts, or styles that don't match the design system
- Responsive breakpoints: missing or broken at key widths (mobile, tablet, desktop)
- Accessibility: missing alt text, insufficient contrast, missing ARIA labels, focus order
- Z-index conflicts
- Touch targets too small (< 44px for mobile)

For each issue found, provide: title, description, severity, line numbers, and a specific fix suggestion.

Score urgency (1-5): how soon this needs fixing (5 = visually broken for users).
Score necessity (1-5): how important this is (5 = brand/accessibility violation).

Rules are strict unless the element is intentionally hidden, a debug overlay, or explicitly styled differently for a documented reason.

Return findings as JSON array. If no issues found, return empty array.`,
  },
  {
    name: 'ux',
    display_name: 'UX',
    description: 'Flow friction, tap count, cognitive load, error/empty states',
    prompt: `You are a UX reviewer focused on user flow and interaction quality. Focus on:
- Flow friction: unnecessary steps, confusing navigation, dead ends
- Tap/click count: can the user achieve their goal in fewer interactions?
- Cognitive load: too many options, unclear labels, information overload
- Missing error states: what happens when things fail?
- Missing empty states: what does the user see when there's no data?
- Missing loading states: does the user know something is happening?
- Keyboard input where it shouldn't be required (for mobile-first apps)
- Confirmation dialogs missing for destructive actions

For each issue found, provide: title, description, severity, line numbers, and a specific fix suggestion.

Score urgency (1-5): how soon this needs fixing (5 = users are getting stuck).
Score necessity (1-5): how important this is (5 = core flow is broken).

Rules are strict unless keyboard input is genuinely required (freeform text, search, custom messages), or the extra step serves a safety purpose (confirming a payment, verifying identity).

Return findings as JSON array. If no issues found, return empty array.`,
  },
  {
    name: 'data-integrity',
    display_name: 'Data Integrity',
    description: 'Missing constraints, unvalidated boundaries, race conditions, orphaned records',
    prompt: `You are a data integrity reviewer. Focus on:
- Missing foreign key constraints or cascading rules
- Unvalidated data at system boundaries (user input, API responses)
- Race conditions: concurrent writes that could corrupt state
- Orphaned records: operations that create records without cleaning up on failure
- Missing transactions around multi-step operations
- Nullable fields that should be required, or vice versa
- Inconsistent data formats (dates, currencies, IDs)
- Missing unique constraints where duplicates would be harmful

For each issue found, provide: title, description, severity, line numbers, and a specific fix suggestion.

Score urgency (1-5): how soon this needs fixing (5 = data corruption possible now).
Score necessity (1-5): how important this is (5 = financial data at risk).

Rules are strict unless the code is a read-only query, a UI component with no data writes, or a test fixture.

Return findings as JSON array. If no issues found, return empty array.`,
  },
  {
    name: 'business-logic',
    display_name: 'Business Logic',
    description: 'Code contradicts product rules — commissions, flows, constraints',
    prompt: `You are a business logic reviewer. You verify that code matches the product's stated rules. Focus on:
- Commission rules: does every money movement (booking, cancel, product sale, gift card) trigger a 3% commission record?
- Booking flow: is it truly 4-6 taps, zero keyboard, one-thumb operable?
- Time inference: is the system inferring booking time rather than showing a calendar/time picker?
- Saldo (balance): does it auto-apply, not appear as a selectable payment option?
- Cancellation: does deposit forfeiture apply per the cancellation policy?
- Staff roles: are the 5 position types enforced with correct permissions?
- Pricing: are all prices in MXN? Are tax withholdings applied correctly?

For each issue found, provide: title, description, severity, line numbers, and a specific fix suggestion.

Score urgency (1-5): how soon this needs fixing (5 = users experiencing wrong behavior).
Score necessity (1-5): how important this is (5 = revenue or legal impact).

Rules are strict unless the file is clearly unrelated to the business logic being checked (e.g., a theme file, an animation utility). When in doubt, flag it.

Return findings as JSON array. If no issues found, return empty array.`,
  },
  {
    name: 'performance',
    display_name: 'Performance',
    description: 'N+1 queries, unnecessary rebuilds, unoptimized assets, blocking calls',
    prompt: `You are a performance reviewer. Focus on:
- N+1 query patterns: loops that make individual DB/API calls instead of batching
- Unnecessary widget rebuilds (Flutter): missing const constructors, rebuilding on every setState
- Unoptimized assets: large images without compression, missing lazy loading
- Blocking calls on the main thread/UI thread
- Missing pagination for list queries
- Redundant API calls: fetching data that's already available
- Missing caching where appropriate
- Large synchronous operations that should be async

For each issue found, provide: title, description, severity, line numbers, and a specific fix suggestion.

Score urgency (1-5): how soon this needs fixing (5 = app visibly slow/janky).
Score necessity (1-5): how important this is (5 = affects core user experience).

Rules are strict unless the code runs once at startup, is a background job, or handles tiny fixed-size datasets where optimization would be premature.

Return findings as JSON array. If no issues found, return empty array.`,
  },
  {
    name: 'compliance',
    display_name: 'Compliance',
    description: 'SAT requirements, LFPDPPP, PROFECO, legal promises vs code reality',
    prompt: `You are a compliance reviewer for a Mexican business platform. Focus on:
- SAT (tax authority): Are ISR/IVA withholdings calculated and recorded? Does the system support CFDI generation or at least track the data needed for it?
- LFPDPPP (data privacy): Is personal data handled per privacy policy? Can users request deletion? Is consent obtained before data collection?
- PROFECO (consumer protection): Do cancellation policies match what's advertised? Are prices transparent? Are terms of service enforced consistently?
- Legal page promises vs code: If the privacy policy says "we delete your data on request," does a delete endpoint actually exist?
- Gift card terms: Do they match the legal terms displayed to users?
- Seller agreement: Does the commission structure in code match the seller agreement?

For each issue found, provide: title, description, severity, line numbers, and a specific fix suggestion.

Score urgency (1-5): how soon this needs fixing (5 = actively non-compliant, legal risk).
Score necessity (1-5): how important this is (5 = regulatory requirement).

Rules are strict unless the file is clearly not customer-facing or data-handling (e.g., a color theme file, an animation). When reviewing legal compliance, err on the side of flagging — false positives are cheaper than violations.

Return findings as JSON array. If no issues found, return empty array.`,
  },
  {
    name: 'showmanship',
    display_name: 'Showmanship',
    description: 'Missed opportunities for wow — where static could be cinematic, flat could have depth',
    prompt: `You are a showmanship reviewer. Your job is to find every place where the UI is technically correct but visually forgettable. Focus on:
- Screens that display data but don't make you want to TOUCH it
- Transitions that are instant or basic fades when they could be cinematic
- Static content that could animate: numbers that could count up, cards that could flip, lists that could stagger in
- Flat surfaces that could have depth: glassmorphism, parallax, layered shadows, 3D transforms
- Confirmations that are plain text when they could be celebrations: confetti, particle bursts, haptic feedback
- Loading states that are boring spinners when they could be entertaining
- Empty states that are just text when they could be illustrated or interactive
- Data visualizations that are basic charts when they could be beautiful, interactive experiences
- Micro-interactions missing: button press effects, scroll-linked animations, gesture responses
- Sound design opportunities (subtle, optional audio feedback)

For each opportunity found, provide: title, description of what exists now, vision of what it could be, severity (always 'opportunity'), line numbers, and a specific implementation direction.

Score urgency (1-5): 1-2 for most (these are enhancements), 3+ only if a key brand moment is flat.
Score necessity (1-5): how much this screen matters to the brand impression (5 = first thing users see, booking confirmation, onboarding).

This lens finds opportunities, not bugs. Every finding is a "this could be wow" not a "this is wrong." Rules bend freely here — the only hard rule is: if something could make someone say "holy shit, how did they do that?" and it doesn't, flag it.

Return findings as JSON array. If no opportunities found, return empty array.`,
  },
];

export function getLens(name: LensName): LensDefinition | null {
  return LENSES.find(l => l.name === name) ?? null;
}

export function getAllLenses(): LensDefinition[] {
  return [...LENSES];
}
```

- [ ] **Step 4: Run tests**

```bash
cd /home/bc/django && npx vitest run tests/lenses.test.ts
```

Expected: All 4 tests PASS.

- [ ] **Step 5: Commit**

```bash
cd /home/bc/django
git add src/lenses.ts tests/lenses.test.ts
git commit -m "feat: 9 review lens definitions with prompt templates"
```

---

### Task 8: Auto-Close Logic

**Files:**
- Create: `/home/bc/django/src/auto-close.ts`
- Create: `/home/bc/django/tests/auto-close.test.ts`

- [ ] **Step 1: Write the failing tests**

```typescript
// tests/auto-close.test.ts
import { describe, it, expect, beforeEach, afterEach } from 'vitest';
import { openDatabase, closeDatabase, getDatabase } from '../src/db.js';
import { createFinding, getFinding } from '../src/findings.js';
import { getOpenFindingsForFile, checkFindingResolved } from '../src/auto-close.js';
import type { FindingInput } from '../src/types.js';
import { unlinkSync, existsSync } from 'fs';

const TEST_DB = '/tmp/django-autoclose-test.db';

function seedSession() {
  const db = getDatabase();
  db.prepare("INSERT OR IGNORE INTO sessions (id, trigger, scope) VALUES ('s1', 'manual', 'full')").run();
}

const baseFinding: FindingInput = {
  session_id: 's1',
  file_path: '/test/file.dart',
  line_start: 10,
  line_end: 15,
  lens: 'code-quality',
  severity: 'major',
  title: 'Magic number on line 10',
  description: 'Hardcoded value 0.25 should be a named constant',
  suggestion: 'Extract to a constant',
  urgency: 2,
  necessity: 3,
};

beforeEach(() => {
  openDatabase(TEST_DB);
  seedSession();
});

afterEach(() => {
  closeDatabase();
  for (const ext of ['', '-wal', '-shm']) {
    if (existsSync(TEST_DB + ext)) unlinkSync(TEST_DB + ext);
  }
});

describe('getOpenFindingsForFile', () => {
  it('should return only open findings for the given file', () => {
    createFinding(baseFinding);
    createFinding({ ...baseFinding, file_path: '/other/file.dart' });
    createFinding({ ...baseFinding, status: 'completed' } as any);

    const open = getOpenFindingsForFile('/test/file.dart');
    expect(open).toHaveLength(1);
    expect(open[0].title).toBe('Magic number on line 10');
  });
});

describe('checkFindingResolved', () => {
  it('should detect when the offending line is gone', () => {
    const id = createFinding(baseFinding);
    const oldContent = 'line1\nline2\nconst rate = 0.25;\nline4';
    const newContent = 'line1\nline2\nconst GROWTH_RATE = getConfigValue("growth_rate");\nline4';

    const result = checkFindingResolved(id, oldContent, newContent);
    expect(result).toBe('resolved');
  });

  it('should return ambiguous when file changed but issue lines unchanged', () => {
    const id = createFinding(baseFinding);
    const oldContent = 'line1\nline2\nconst rate = 0.25;\nline4';
    const newContent = 'line0\nline1\nline2\nconst rate = 0.25;\nline4';

    const result = checkFindingResolved(id, oldContent, newContent);
    expect(result).toBe('ambiguous');
  });

  it('should return unresolved when nothing changed in the relevant area', () => {
    const id = createFinding(baseFinding);
    const content = 'line1\nline2\nconst rate = 0.25;\nline4';

    const result = checkFindingResolved(id, content, content);
    expect(result).toBe('unresolved');
  });
});
```

- [ ] **Step 2: Run tests to verify they fail**

```bash
cd /home/bc/django && npx vitest run tests/auto-close.test.ts
```

Expected: FAIL — module not found.

- [ ] **Step 3: Write the auto-close module**

```typescript
// src/auto-close.ts
import { getDatabase } from './db.js';
import { getFinding } from './findings.js';
import type { Finding } from './types.js';

const OPEN_STATUSES = ['new', 'curated', 'planned', 'in_progress', 'needs_verification'];

export function getOpenFindingsForFile(filePath: string): Finding[] {
  const db = getDatabase();
  const placeholders = OPEN_STATUSES.map(() => '?').join(', ');
  return db.prepare(
    `SELECT * FROM findings WHERE file_path = ? AND status IN (${placeholders}) ORDER BY priority DESC`
  ).all(filePath, ...OPEN_STATUSES) as Finding[];
}

export function checkFindingResolved(
  findingId: number,
  oldContent: string,
  newContent: string,
): 'resolved' | 'ambiguous' | 'unresolved' {
  if (oldContent === newContent) return 'unresolved';

  const finding = getFinding(findingId);
  if (!finding) return 'unresolved';

  // If we don't have line numbers, we can't do line-level comparison
  if (!finding.line_start) {
    return 'ambiguous';
  }

  const oldLines = oldContent.split('\n');
  const newLines = newContent.split('\n');

  // Extract the region around the finding (with some buffer)
  const start = Math.max(0, finding.line_start - 2);
  const end = Math.min(oldLines.length, (finding.line_end ?? finding.line_start) + 2);
  const oldRegion = oldLines.slice(start, end).join('\n');

  // Check if the old region still exists in the new content
  const newFullText = newLines.join('\n');

  if (!newFullText.includes(oldRegion)) {
    // The region that contained the issue has changed
    return 'resolved';
  }

  // Region still exists but file changed elsewhere
  return 'ambiguous';
}
```

- [ ] **Step 4: Run tests**

```bash
cd /home/bc/django && npx vitest run tests/auto-close.test.ts
```

Expected: All 4 tests PASS.

- [ ] **Step 5: Commit**

```bash
cd /home/bc/django
git add src/auto-close.ts tests/auto-close.test.ts
git commit -m "feat: auto-close logic for resolved findings"
```

---

### Task 9: MCP Server + Tool Definitions

**Files:**
- Create: `/home/bc/django/src/mcp/server.ts`
- Create: `/home/bc/django/src/mcp/tools.ts`

- [ ] **Step 1: Write the MCP tools module**

```typescript
// src/mcp/tools.ts
import { z } from 'zod';
import { createFinding, getFinding, queryFindings, updateFindingStatus, rescoreFinding, summarizeFindings, getHistory } from '../findings.js';
import { createSession, getSession, updateSessionStatus, incrementSessionCounters, listSessions } from '../sessions.js';
import { inventoryFiles, hasFileChanged, recordFileHash, hashFile } from '../file-inventory.js';
import { getLens, getAllLenses } from '../lenses.js';
import { getOpenFindingsForFile, checkFindingResolved } from '../auto-close.js';
import type { LensName, FindingStatus, Severity, Actor } from '../types.js';

// --- Zod Schemas ---

const AddFindingSchema = z.object({
  session_id: z.string(),
  file_path: z.string(),
  line_start: z.number().optional(),
  line_end: z.number().optional(),
  lens: z.string(),
  severity: z.string(),
  title: z.string(),
  description: z.string(),
  suggestion: z.string().optional(),
  trend_intel: z.string().optional(),
  urgency: z.number().int().min(1).max(5),
  necessity: z.number().int().min(1).max(5),
  build_number: z.string().optional(),
  version: z.string().optional(),
});

const QueryFindingsSchema = z.object({
  lens: z.string().optional(),
  status: z.string().optional(),
  severity: z.string().optional(),
  file_path: z.string().optional(),
  session_id: z.string().optional(),
  min_priority: z.number().optional(),
  limit: z.number().int().min(1).max(100).optional(),
  offset: z.number().int().min(0).optional(),
});

const UpdateStatusSchema = z.object({
  finding_id: z.number().int(),
  status: z.string(),
  actor: z.string().default('claude'),
  note: z.string().optional(),
  build_number: z.string().optional(),
  version: z.string().optional(),
});

const RescoreSchema = z.object({
  finding_id: z.number().int(),
  urgency: z.number().int().min(1).max(5),
  necessity: z.number().int().min(1).max(5),
  actor: z.string().default('claude'),
  note: z.string(),
});

const StartSessionSchema = z.object({
  trigger: z.enum(['manual', 'targeted']).default('manual'),
  scope: z.string().default('full'),
});

const UpdateSessionSchema = z.object({
  session_id: z.string(),
  status: z.string(),
});

const SessionCountersSchema = z.object({
  session_id: z.string(),
  files: z.number().int().optional(),
  findings: z.number().int().optional(),
});

const InventorySchema = z.object({
  directory: z.string(),
  patterns: z.array(z.string()).default(['*.dart', '*.html', '*.ts', '*.js', '*.sql']),
});

const FileChangedSchema = z.object({
  file_path: z.string(),
});

const RecordHashSchema = z.object({
  file_path: z.string(),
  session_id: z.string(),
});

const GetLensSchema = z.object({
  name: z.string(),
});

const CheckAutoCloseSchema = z.object({
  file_path: z.string(),
  old_content: z.string(),
  new_content: z.string(),
});

const FindingIdSchema = z.object({
  finding_id: z.number().int(),
});

const SummarizeSchema = z.object({
  session_id: z.string().optional(),
});

// --- Tool Definitions ---

export const TOOL_DEFINITIONS = [
  {
    name: 'django_add_finding',
    description: 'Store a code review finding. Called by Claude after analyzing a file through a lens. Automatically creates a history entry.',
    inputSchema: zodToJsonSchema(AddFindingSchema),
  },
  {
    name: 'django_query_findings',
    description: 'Query findings with filters. Sorted by priority descending. Use to show BC categorized results.',
    inputSchema: zodToJsonSchema(QueryFindingsSchema),
  },
  {
    name: 'django_get_finding',
    description: 'Get full detail for a single finding including all fields.',
    inputSchema: zodToJsonSchema(FindingIdSchema),
  },
  {
    name: 'django_get_history',
    description: 'Get the full history timeline for a finding — every status change, rescore, and action.',
    inputSchema: zodToJsonSchema(FindingIdSchema),
  },
  {
    name: 'django_update_status',
    description: 'Update a finding status (new → curated → planned → in_progress → completed/suspended). Records history automatically.',
    inputSchema: zodToJsonSchema(UpdateStatusSchema),
  },
  {
    name: 'django_rescore',
    description: 'Change a finding urgency/necessity scores with reasoning. Records old and new scores in history.',
    inputSchema: zodToJsonSchema(RescoreSchema),
  },
  {
    name: 'django_summarize',
    description: 'Get finding counts grouped by severity, lens, and status. Optional session_id filter.',
    inputSchema: zodToJsonSchema(SummarizeSchema),
  },
  {
    name: 'django_start_session',
    description: 'Start a new review session. Returns the session ID for use in subsequent tool calls.',
    inputSchema: zodToJsonSchema(StartSessionSchema),
  },
  {
    name: 'django_update_session',
    description: 'Update session status (running → wrapping_up → completed/killed).',
    inputSchema: zodToJsonSchema(UpdateSessionSchema),
  },
  {
    name: 'django_session_counters',
    description: 'Increment files_reviewed and/or findings_count for a session.',
    inputSchema: zodToJsonSchema(SessionCountersSchema),
  },
  {
    name: 'django_list_sessions',
    description: 'List recent review sessions.',
    inputSchema: { type: 'object', properties: { limit: { type: 'number' } } },
  },
  {
    name: 'django_inventory_files',
    description: 'List all reviewable files in a directory matching patterns. Excludes node_modules, .git, build, dist.',
    inputSchema: zodToJsonSchema(InventorySchema),
  },
  {
    name: 'django_file_changed',
    description: 'Check if a file has changed since last review (by content hash). Returns true if file should be re-reviewed.',
    inputSchema: zodToJsonSchema(FileChangedSchema),
  },
  {
    name: 'django_record_hash',
    description: 'Record a file content hash after reviewing it. Used to skip unchanged files in future sessions.',
    inputSchema: zodToJsonSchema(RecordHashSchema),
  },
  {
    name: 'django_get_lens',
    description: 'Get a specific lens definition including its full prompt template. Claude uses this prompt to analyze a file.',
    inputSchema: zodToJsonSchema(GetLensSchema),
  },
  {
    name: 'django_get_all_lenses',
    description: 'Get all 9 lens definitions with their prompts.',
    inputSchema: { type: 'object', properties: {} },
  },
  {
    name: 'django_check_auto_close',
    description: 'Given a file path and old/new content, check which open findings were resolved by the edit. Returns list of findings with resolution status.',
    inputSchema: zodToJsonSchema(CheckAutoCloseSchema),
  },
];

// --- Tool Handlers ---

function ok(data: unknown) {
  return { content: [{ type: 'text' as const, text: JSON.stringify(data, null, 2) }] };
}

function fail(message: string) {
  return { content: [{ type: 'text' as const, text: message }], isError: true };
}

export function handleTool(name: string, args: unknown) {
  try {
    switch (name) {
      case 'django_add_finding': {
        const input = AddFindingSchema.parse(args);
        const id = createFinding(input as any);
        if (id === -1) return ok({ stored: false, duplicate: true });
        return ok({ stored: true, finding_id: id });
      }
      case 'django_query_findings': {
        const filter = QueryFindingsSchema.parse(args);
        const results = queryFindings(filter as any);
        return ok(results);
      }
      case 'django_get_finding': {
        const { finding_id } = FindingIdSchema.parse(args);
        const finding = getFinding(finding_id);
        return finding ? ok(finding) : fail(`Finding ${finding_id} not found`);
      }
      case 'django_get_history': {
        const { finding_id } = FindingIdSchema.parse(args);
        const history = getHistory(finding_id);
        return ok(history);
      }
      case 'django_update_status': {
        const input = UpdateStatusSchema.parse(args);
        updateFindingStatus(
          input.finding_id,
          input.status as FindingStatus,
          input.actor as Actor,
          input.note,
          input.build_number,
          input.version,
        );
        return ok({ updated: true });
      }
      case 'django_rescore': {
        const input = RescoreSchema.parse(args);
        rescoreFinding(input.finding_id, input.urgency, input.necessity, input.actor as Actor, input.note);
        return ok({ rescored: true });
      }
      case 'django_summarize': {
        const input = SummarizeSchema.parse(args);
        const summary = summarizeFindings(input.session_id ? { session_id: input.session_id } : undefined);
        return ok(summary);
      }
      case 'django_start_session': {
        const input = StartSessionSchema.parse(args);
        const id = createSession(input.trigger, input.scope);
        return ok({ session_id: id });
      }
      case 'django_update_session': {
        const input = UpdateSessionSchema.parse(args);
        updateSessionStatus(input.session_id, input.status as any);
        return ok({ updated: true });
      }
      case 'django_session_counters': {
        const input = SessionCountersSchema.parse(args);
        incrementSessionCounters(input.session_id, { files: input.files, findings: input.findings });
        return ok({ incremented: true });
      }
      case 'django_list_sessions': {
        const limit = (args as any)?.limit ?? 10;
        return ok(listSessions(limit));
      }
      case 'django_inventory_files': {
        const input = InventorySchema.parse(args);
        const files = inventoryFiles(input.directory, input.patterns);
        return ok({ files, count: files.length });
      }
      case 'django_file_changed': {
        const input = FileChangedSchema.parse(args);
        return ok({ changed: hasFileChanged(input.file_path) });
      }
      case 'django_record_hash': {
        const input = RecordHashSchema.parse(args);
        recordFileHash(input.file_path, input.session_id);
        return ok({ recorded: true });
      }
      case 'django_get_lens': {
        const input = GetLensSchema.parse(args);
        const lens = getLens(input.name as LensName);
        return lens ? ok(lens) : fail(`Lens "${input.name}" not found`);
      }
      case 'django_get_all_lenses': {
        return ok(getAllLenses());
      }
      case 'django_check_auto_close': {
        const input = CheckAutoCloseSchema.parse(args);
        const openFindings = getOpenFindingsForFile(input.file_path);
        const results = openFindings.map(f => ({
          finding_id: f.id,
          title: f.title,
          status: checkFindingResolved(f.id, input.old_content, input.new_content),
        }));
        return ok(results);
      }
      default:
        return fail(`Unknown tool: ${name}`);
    }
  } catch (err: any) {
    return fail(`Tool "${name}" failed: ${err.message}`);
  }
}

// --- Zod to JSON Schema helper ---

function zodToJsonSchema(schema: z.ZodType): Record<string, unknown> {
  // Simple conversion for our flat schemas
  if (schema instanceof z.ZodObject) {
    const shape = schema.shape;
    const properties: Record<string, unknown> = {};
    const required: string[] = [];

    for (const [key, value] of Object.entries(shape)) {
      const zodField = value as z.ZodType;
      properties[key] = zodFieldToJson(zodField);
      if (!isOptional(zodField)) {
        required.push(key);
      }
    }

    return { type: 'object', properties, ...(required.length > 0 ? { required } : {}) };
  }
  return { type: 'object', properties: {} };
}

function zodFieldToJson(field: z.ZodType): Record<string, unknown> {
  if (field instanceof z.ZodOptional) return zodFieldToJson(field._def.innerType);
  if (field instanceof z.ZodDefault) return zodFieldToJson(field._def.innerType);
  if (field instanceof z.ZodString) return { type: 'string' };
  if (field instanceof z.ZodNumber) return { type: 'number' };
  if (field instanceof z.ZodEnum) return { type: 'string', enum: field._def.values };
  if (field instanceof z.ZodArray) return { type: 'array', items: zodFieldToJson(field._def.type) };
  return { type: 'string' };
}

function isOptional(field: z.ZodType): boolean {
  if (field instanceof z.ZodOptional) return true;
  if (field instanceof z.ZodDefault) return true;
  return false;
}
```

- [ ] **Step 2: Write the MCP server entry point**

```typescript
// src/mcp/server.ts
#!/usr/bin/env node
import { Server } from '@modelcontextprotocol/sdk/server/index.js';
import { StdioServerTransport } from '@modelcontextprotocol/sdk/server/stdio.js';
import { CallToolRequestSchema, ListToolsRequestSchema } from '@modelcontextprotocol/sdk/types.js';
import { openDatabase, closeDatabase } from '../db.js';
import { handleTool, TOOL_DEFINITIONS } from './tools.js';

const server = new Server(
  { name: 'django', version: '1.0.0' },
  { capabilities: { tools: {} } },
);

server.setRequestHandler(ListToolsRequestSchema, async () => ({
  tools: TOOL_DEFINITIONS.map(t => ({
    name: t.name,
    description: t.description,
    inputSchema: t.inputSchema,
  })),
}));

server.setRequestHandler(CallToolRequestSchema, async (request) => {
  const { name, arguments: args } = request.params;
  return handleTool(name, args);
});

async function main() {
  openDatabase();
  const transport = new StdioServerTransport();
  await server.connect(transport);
}

function shutdown() {
  try { closeDatabase(); } catch {}
  process.exit(0);
}

process.on('SIGINT', shutdown);
process.on('SIGTERM', shutdown);

main().catch((err) => {
  console.error('Django server error:', err instanceof Error ? err.message : String(err));
  try { closeDatabase(); } catch {}
  process.exit(1);
});
```

- [ ] **Step 3: Verify the project compiles**

```bash
cd /home/bc/django && npx tsc
```

Expected: No errors. `dist/` directory created.

- [ ] **Step 4: Verify MCP server starts and responds to tool listing**

```bash
echo '{"jsonrpc":"2.0","id":1,"method":"tools/list","params":{}}' | timeout 3 node /home/bc/django/dist/mcp/server.js 2>&1 | head -5
```

Expected: JSON response listing all django_* tools.

- [ ] **Step 5: Commit**

```bash
cd /home/bc/django
git add src/mcp/server.ts src/mcp/tools.ts
git commit -m "feat: MCP server with 17 tools for review, findings, sessions, and auto-close"
```

---

### Task 10: Register Django in Claude Code Settings

**Files:**
- Modify: `/home/bc/.claude/settings.json`

- [ ] **Step 1: Read current settings**

```bash
cat /home/bc/.claude/settings.json
```

- [ ] **Step 2: Add Django MCP server to settings**

Add the `mcpServers` block to `/home/bc/.claude/settings.json`:

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

Merge this with existing settings — do not overwrite the `enabledPlugins` or `skipDangerousModePermissionPrompt` keys.

- [ ] **Step 3: Verify registration by restarting Claude Code**

After registration, a new Claude Code session should show `django` in available MCP servers. The `django_*` tools should be available.

- [ ] **Step 4: Commit settings change**

```bash
cd /home/bc/django
git add -A
git commit -m "feat: register Django MCP server in Claude Code settings"
```

---

### Task 11: Integration Test — Full Round Trip

**Files:**
- Create: `/home/bc/django/tests/integration.test.ts`

- [ ] **Step 1: Write the integration test**

```typescript
// tests/integration.test.ts
import { describe, it, expect, beforeEach, afterEach } from 'vitest';
import { openDatabase, closeDatabase, getDatabase } from '../src/db.js';
import { handleTool } from '../src/mcp/tools.js';
import { unlinkSync, existsSync, writeFileSync, mkdirSync, rmSync } from 'fs';

const TEST_DB = '/tmp/django-integration-test.db';
const TEST_DIR = '/tmp/django-integration-testdir';

beforeEach(() => {
  openDatabase(TEST_DB);
  mkdirSync(TEST_DIR, { recursive: true });
  writeFileSync(TEST_DIR + '/app.dart', 'void main() { const rate = 0.25; }');
  writeFileSync(TEST_DIR + '/page.html', '<html><body>Hello</body></html>');
});

afterEach(() => {
  closeDatabase();
  rmSync(TEST_DIR, { recursive: true, force: true });
  for (const ext of ['', '-wal', '-shm']) {
    if (existsSync(TEST_DB + ext)) unlinkSync(TEST_DB + ext);
  }
});

describe('full round trip', () => {
  it('should complete a full review cycle: session → inventory → finding → query → auto-close', () => {
    // 1. Start a session
    const sessionResult = handleTool('django_start_session', { trigger: 'targeted', scope: TEST_DIR });
    const sessionData = JSON.parse(sessionResult.content[0].text);
    expect(sessionData.session_id).toBeTruthy();
    const sessionId = sessionData.session_id;

    // 2. Inventory files
    const invResult = handleTool('django_inventory_files', { directory: TEST_DIR, patterns: ['*.dart', '*.html'] });
    const invData = JSON.parse(invResult.content[0].text);
    expect(invData.count).toBe(2);

    // 3. Check file changed (first time = always true)
    const changedResult = handleTool('django_file_changed', { file_path: TEST_DIR + '/app.dart' });
    const changedData = JSON.parse(changedResult.content[0].text);
    expect(changedData.changed).toBe(true);

    // 4. Get a lens prompt
    const lensResult = handleTool('django_get_lens', { name: 'code-quality' });
    const lensData = JSON.parse(lensResult.content[0].text);
    expect(lensData.prompt).toContain('Magic numbers');

    // 5. Add a finding
    const findingResult = handleTool('django_add_finding', {
      session_id: sessionId,
      file_path: TEST_DIR + '/app.dart',
      line_start: 1,
      line_end: 1,
      lens: 'code-quality',
      severity: 'major',
      title: 'Magic number: rate = 0.25',
      description: 'Hardcoded growth rate',
      suggestion: 'Use named constant',
      urgency: 2,
      necessity: 4,
    });
    const findingData = JSON.parse(findingResult.content[0].text);
    expect(findingData.finding_id).toBe(1);

    // 6. Record file hash
    handleTool('django_record_hash', { file_path: TEST_DIR + '/app.dart', session_id: sessionId });

    // 7. Increment counters
    handleTool('django_session_counters', { session_id: sessionId, files: 1, findings: 1 });

    // 8. Query findings
    const queryResult = handleTool('django_query_findings', { lens: 'code-quality' });
    const findings = JSON.parse(queryResult.content[0].text);
    expect(findings).toHaveLength(1);
    expect(findings[0].priority).toBe(8);

    // 9. Get summary
    const summaryResult = handleTool('django_summarize', {});
    const summary = JSON.parse(summaryResult.content[0].text);
    expect(summary.total).toBe(1);

    // 10. Check auto-close after file edit
    const oldContent = 'void main() { const rate = 0.25; }';
    const newContent = 'void main() { const GROWTH_RATE = getConfig("rate"); }';
    const autoCloseResult = handleTool('django_check_auto_close', {
      file_path: TEST_DIR + '/app.dart',
      old_content: oldContent,
      new_content: newContent,
    });
    const autoCloseData = JSON.parse(autoCloseResult.content[0].text);
    expect(autoCloseData).toHaveLength(1);
    expect(autoCloseData[0].status).toBe('resolved');

    // 11. Mark completed
    handleTool('django_update_status', {
      finding_id: 1,
      status: 'completed',
      actor: 'claude',
      note: 'Auto-resolved: magic number replaced with config lookup',
      build_number: '48220',
    });

    // 12. Verify history
    const historyResult = handleTool('django_get_history', { finding_id: 1 });
    const history = JSON.parse(historyResult.content[0].text);
    expect(history).toHaveLength(2); // created + completed
    expect(history[0].action).toBe('created');
    expect(history[1].action).toBe('completed');

    // 13. File should NOT be flagged as changed anymore
    const changedAgain = handleTool('django_file_changed', { file_path: TEST_DIR + '/app.dart' });
    expect(JSON.parse(changedAgain.content[0].text).changed).toBe(false);

    // 14. Complete session
    handleTool('django_update_session', { session_id: sessionId, status: 'completed' });
  });
});
```

- [ ] **Step 2: Run the integration test**

```bash
cd /home/bc/django && npx vitest run tests/integration.test.ts
```

Expected: PASS — full round trip works.

- [ ] **Step 3: Run all tests together**

```bash
cd /home/bc/django && npx vitest run
```

Expected: All tests across all files PASS.

- [ ] **Step 4: Commit**

```bash
cd /home/bc/django
git add tests/integration.test.ts
git commit -m "feat: integration test covering full review cycle round trip"
```

---

### Task 12: Pulse Scanner (Trend Intelligence)

**Files:**
- Create: `/home/bc/django/src/pulse/scanner.ts`

- [ ] **Step 1: Write the pulse scanner**

The pulse scanner constructs a targeted search query from a finding and returns a structured result. It doesn't do the web search itself — it prepares the query and format for Claude to execute via WebSearch, then stores the result.

```typescript
// src/pulse/scanner.ts
import { getDatabase } from '../db.js';
import { getFinding } from '../findings.js';

export interface PulseQuery {
  finding_id: number;
  search_query: string;
  sources: string[];
}

export interface PulseResult {
  finding_id: number;
  source: string;
  title: string;
  relevance: string;
  url?: string;
}

export function buildPulseQuery(findingId: number): PulseQuery | null {
  const finding = getFinding(findingId);
  if (!finding) return null;

  // Build a targeted search query from the finding's suggestion and lens
  const lensKeywords: Record<string, string> = {
    'security': 'security fix library',
    'code-quality': 'best practice pattern',
    'ui': 'UI component library design',
    'ux': 'UX pattern interaction design',
    'data-integrity': 'database constraint validation',
    'business-logic': 'business rules engine',
    'performance': 'performance optimization',
    'compliance': 'compliance automation',
    'showmanship': 'animation effect visual library flutter',
  };

  const keywords = lensKeywords[finding.lens] ?? finding.lens;
  const suggestion = finding.suggestion ?? finding.title;
  const query = `${suggestion} ${keywords} 2025 2026`;

  return {
    finding_id: findingId,
    search_query: query,
    sources: ['github', 'pub.dev', 'npm', 'huggingface'],
  };
}

export function storePulseResult(findingId: number, intel: string): void {
  const db = getDatabase();
  db.prepare('UPDATE findings SET trend_intel = ?, updated_at = datetime(\'now\') WHERE id = ?').run(intel, findingId);
}
```

- [ ] **Step 2: Add pulse tools to MCP tools.ts**

Add these two tool definitions to the `TOOL_DEFINITIONS` array in `src/mcp/tools.ts`:

```typescript
{
  name: 'django_build_pulse_query',
  description: 'Build a targeted web search query from a finding. Returns the query string and suggested sources. Claude then performs the actual web search.',
  inputSchema: zodToJsonSchema(FindingIdSchema),
},
{
  name: 'django_store_pulse_result',
  description: 'Store the trend intel result for a finding after Claude performs the web search.',
  inputSchema: {
    type: 'object',
    properties: {
      finding_id: { type: 'number' },
      intel: { type: 'string', description: 'One-line trend intel: [source] name — relevance' },
    },
    required: ['finding_id', 'intel'],
  },
},
```

Add the corresponding cases to the `handleTool` switch:

```typescript
case 'django_build_pulse_query': {
  const { finding_id } = FindingIdSchema.parse(args);
  const query = buildPulseQuery(finding_id);
  return query ? ok(query) : fail(`Finding ${finding_id} not found`);
}
case 'django_store_pulse_result': {
  const input = z.object({ finding_id: z.number(), intel: z.string() }).parse(args);
  storePulseResult(input.finding_id, input.intel);
  return ok({ stored: true });
}
```

Add the import at the top of tools.ts:

```typescript
import { buildPulseQuery, storePulseResult } from '../pulse/scanner.js';
```

- [ ] **Step 3: Verify build**

```bash
cd /home/bc/django && npx tsc
```

Expected: No errors.

- [ ] **Step 4: Run all tests**

```bash
cd /home/bc/django && npx vitest run
```

Expected: All tests PASS.

- [ ] **Step 5: Commit**

```bash
cd /home/bc/django
git add src/pulse/scanner.ts src/mcp/tools.ts
git commit -m "feat: pulse scanner for trend intelligence queries"
```

---

### Task 13: Final Build + Verify MCP Server

- [ ] **Step 1: Clean build**

```bash
cd /home/bc/django
rm -rf dist
npx tsc
chmod +x dist/mcp/server.js
```

- [ ] **Step 2: Run full test suite**

```bash
cd /home/bc/django && npx vitest run
```

Expected: All tests PASS.

- [ ] **Step 3: Verify MCP server lists all tools**

```bash
echo '{"jsonrpc":"2.0","id":1,"method":"tools/list","params":{}}' | timeout 3 node /home/bc/django/dist/mcp/server.js 2>&1 | python3 -c "import sys,json; data=json.load(sys.stdin); tools=data['result']['tools']; print(f'{len(tools)} tools:'); [print(f'  - {t[\"name\"]}') for t in tools]"
```

Expected: 19 tools listed (17 original + 2 pulse).

- [ ] **Step 4: Typecheck**

```bash
cd /home/bc/django && npx tsc --noEmit
```

Expected: No errors.

- [ ] **Step 5: Final commit**

```bash
cd /home/bc/django
git add -A
git commit -m "feat: Django v1.0.0 — autonomous code review MCP server, ready for registration"
```

---

## Summary

| Task | What it builds | Tests |
|------|---------------|-------|
| 1 | Project scaffolding | — |
| 2 | TypeScript types | compile check |
| 3 | Database layer | 3 tests |
| 4 | Findings CRUD + history | 6 tests |
| 5 | Session management | 3 tests |
| 6 | File inventory + hashing | 5 tests |
| 7 | 9 lens definitions | 4 tests |
| 8 | Auto-close logic | 4 tests |
| 9 | MCP server + 17 tools | compile + manual verify |
| 10 | Claude Code registration | manual verify |
| 11 | Integration test | 1 comprehensive test |
| 12 | Pulse scanner | compile + existing tests |
| 13 | Final build + verify | full suite |

Total: 13 tasks, ~26 tests, 19 MCP tools, 1 standalone MCP server.
