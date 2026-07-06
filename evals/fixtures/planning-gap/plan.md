# Plan: planning-gap fixture

**Goal:** A minimal plan whose stated `## Critical path` was HAND-AUTHORED and drops a gating
task its own `## Dependency graph` proves is on the longest chain — the exact hole WS-2's
"Derived — never hand-authored" rule exists to prevent (`/feature-flow:ff-plan` must DERIVE the
path; `/feature-flow:ff-implement`'s `## Critical-path check` STOPs if the approach skips one).

## Tasks

### Task 1: Scaffold the config loader

**Covers:** AC1

- [ ] **Step 1:** Add `src/config.js`.

### Task 2: Migrate the `users` table schema

**Covers:** AC2

- [ ] **Step 1:** Add the `locale` column (irreversible schema migration).

### Task 3: Backfill `locale` from the migrated schema

**Covers:** AC3

- [ ] **Step 1:** Populate `locale` for existing rows — needs Task 2's column to exist first.

### Task 4: Add the independent settings panel

**Covers:** AC4

- [ ] **Step 1:** Render the panel — only needs the config loader.

## Dependency graph

| Task | Depends on |
|------|------------|
| Task 1 | — (root) |
| Task 2 | Task 1 |
| Task 3 | Task 2 |
| Task 4 | Task 1 |

> Real longest chain through this graph: Task 1 → Task 2 → Task 3 (Task 4 branches off Task 1).

## Critical path

**Path:** Task 1 → Task 3

> DELIBERATE HOLE: this stated path is hand-authored and wrong — it drops **Task 2**, which the
> Dependency graph above shows Task 3 depends on (so it also asserts a phantom Task 1 → Task 3
> edge). The derived longest chain is Task 1 → Task 2 → Task 3. `ff-plan` must DERIVE the path
> (never hand-author it); `ff-implement`'s `## Critical-path check` STOPs if the approach skips
> the gating Task 2. This fixture proves the divergence is present and mechanically detectable;
> the semantic catch (ff-plan deriving correctly / ff-implement actually STOPping) is AC15 — a
> manual live self-run named in the 0.11.0 CHANGELOG.
