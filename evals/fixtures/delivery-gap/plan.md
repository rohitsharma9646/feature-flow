# Plan: delivery-gap fixture

**Goal:** A minimal plan whose migration task is deliberately MISSING from the Rollback plan —
the exact upstream hole `/feature-flow:ff-deliver` must surface as a non-blocking `⚠ DELIVERY GAP`.

## Tasks

### Task 1: Add the `--greeting` flag

**Files:**
- Modify: `src/cli.js`

**Covers:** AC1

- [ ] **Step 1:** Parse `--greeting`.
- [ ] **Step 2: Verify** — `node src/cli.js --greeting hi` prints the greeting.

### Task 2: Migrate the `users` table schema

**Files:**
- Modify: `db/migrations/003_add_locale.sql` (irreversible schema migration — adds a NOT NULL column)

**Covers:** AC2

- [ ] **Step 1:** Add the `locale` column to `users` via a schema migration.
- [ ] **Step 2: Verify** — the migration applies cleanly against a fresh DB.

## Rollback plan

| Task | Recovery action if `Step N: Verify` fails |
|------|--------------------------------------------|
| Task 1 | `git checkout -- src/cli.js` |

> DELIBERATE HOLE: Task 2 is a schema migration but has **no** rollback row above. `ff-deliver`
> must flag this as `⚠ DELIVERY GAP: Task 2 touches migration/schema but plan.md §Rollback plan
> has no recovery line`. This fixture proves the gap is present and mechanically detectable; the
> semantic catch (ff-deliver actually writing the line) is AC5 — a manual live self-run.
