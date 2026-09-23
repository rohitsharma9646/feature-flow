# Plan: CSV export

**Goal:** `src/export.sh` writes the report as CSV.

## Outcome gate

**Spec:** `spec.md`
**Acceptance criteria:** see spec §Acceptance criteria (AC1–AC3).
**User signed off:** yes (2026-09-20)

## Tasks

### Task 1: Report rows

**Files:**
- Create: `src/rows.sh`

**Covers:** AC1

- [ ] **Step 1:** `src/rows.sh` prints three fixed rows: `alpha|3`, `beta, inc|5`, `gamma|0`.
- [ ] **Step 2: Verify** — `bash src/rows.sh` prints 3 `name|count` lines.

### Task 2: CSV encoder

**Files:**
- Create: `src/csv.sh`

**Covers:** AC2

- [ ] **Step 1:** `src/csv.sh` reads `name|count` on stdin, prints `name,count`, quoting a name that contains a comma or quote.
- [ ] **Step 2: Verify** — `bash src/rows.sh | bash src/csv.sh` prints `"beta, inc",5` for row 2.

### Task 3: Export entry point

**Files:**
- Create: `src/export.sh`

**Covers:** AC3

- [ ] **Step 1:** `src/export.sh` prints `name,count` then `bash src/rows.sh | bash src/csv.sh`.
- [ ] **Step 2: Verify** — `bash src/export.sh | head -1` prints `name,count`.

## Dependency graph

| Task | Depends on |
|------|------------|
| Task 1 | — (root) |
| Task 2 | Task 1 |
| Task 3 | Task 2 |

## Critical path

**Path:** Task 1 → Task 2 → Task 3

## Risk register

| Risk | Likelihood | Impact | Mitigation |
|------|-----------|--------|-----------|
| Quoting edge cases | Low | Low | Task 2 verify covers a comma |

## Rollback plan

| Task | Recovery action if `Step N: Verify` fails |
|------|--------------------------------------------|
| Task 1 | `rm -f src/rows.sh` |
| Task 2 | `rm -f src/csv.sh` |
| Task 3 | `rm -f src/export.sh` |

## Status conventions

`[ ]` pending · `[~]` in progress · `[x]` done · `[!]` blocked · `[→]` deferred.

**Status:** 0/3 tasks done.
