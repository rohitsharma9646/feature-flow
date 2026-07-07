# Plan: discovery-gap fixture

**Goal:** A minimal plan whose `## Dependency graph` DROPS the task-dependency edge the companion
`spec.md`'s `## Requirement graph` proves — the spec says `AC2 depends-on AC1`, Task 2 covers AC2
and Task 1 covers AC1, so Task 2 should depend on Task 1, yet the graph lists Task 2 as a root.
This is the exact hole WS-7's `ff-plan` requirement-graph derivation must catch (fold the edge in,
or surface an Outcome-gate gap — never silently drop it).

## Tasks

### Task 1: Add the config loader

**Covers:** AC1

- [ ] **Step 1:** Add `src/config.js`.

### Task 2: Serve requests from the loaded config

**Covers:** AC2

- [ ] **Step 1:** Wire the request handler to the loader — needs Task 1's loader to exist first.

## Dependency graph

| Task | Depends on |
|------|------------|
| Task 1 | — (root) |
| Task 2 | — (root) |

> DELIBERATE HOLE: the companion `spec.md` `## Requirement graph` proves `AC2 depends-on AC1`.
> Task 2 covers AC2 and Task 1 covers AC1, so the derived task edge is `Task 2 → Task 1`, yet
> Task 2 is listed as a root here — the AC-derived dependency is dropped. `ff-plan`'s
> requirement-graph derivation must fold it in (or surface an Outcome-gate gap). This fixture
> proves the drop is present and mechanically detectable; the semantic catch (ff-plan deriving /
> gapping) is AC8 — a manual live self-run named in the 0.17.0 CHANGELOG.
