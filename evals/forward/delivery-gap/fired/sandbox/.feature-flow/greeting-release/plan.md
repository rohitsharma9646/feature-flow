# Plan: Localized greeting

**Goal:** Ship a `--greeting` flag and a `locale` column on `users`.

## Tasks

### Task 1: Add the `--greeting` flag

**Files:**
- Modify: `src/cli.js`

**Covers:** AC1

- [x] **Step 1:** Parse `--greeting`.
- [x] **Step 2: Verify** — `node src/cli.js --greeting hi` prints the greeting.

### Task 2: Migrate the `users` table schema

**Files:**
- Create: `db/migrations/003_add_locale.sql` (schema migration — adds a NOT NULL column)

**Covers:** AC2

- [x] **Step 1:** Add the `locale` column to `users` via a schema migration.
- [x] **Step 2: Verify** — the migration applies cleanly against a fresh DB.

## Dependency graph

| Task | Depends on |
|------|------------|
| Task 1 | — (root) |
| Task 2 | — (root) |

## Critical path

**Path:** Task 2

## Risk register

| Risk | Likelihood | Impact | Mitigation |
|------|-----------|--------|-----------|
| Migration locks `users` on large tables | Low | Med | run off-peak |

## Rollback plan

| Task | Recovery action if `Step N: Verify` fails |
|------|--------------------------------------------|
| Task 1 | `git checkout -- src/cli.js` |
