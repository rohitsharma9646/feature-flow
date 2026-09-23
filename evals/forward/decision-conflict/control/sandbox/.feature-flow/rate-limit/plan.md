# Plan: Login rate limit

**Goal:** A per-client 5-attempts-per-minute limiter.

## Outcome gate

**Spec:** `spec.md`
**Acceptance criteria:** see spec §Acceptance criteria (AC1).
**User signed off:** yes (2026-09-20)

## Tasks

### Task 1: Limiter script

**Files:**
- Create: `src/limiter.sh`

**Covers:** AC1

- [ ] **Step 1:** Implement `src/limiter.sh <client-id>` printing `allow`/`deny` per the design.
- [ ] **Step 2: Verify** — `for i in 1 2 3 4 5 6; do bash src/limiter.sh c1; done` prints five `allow` then `deny`.

## Dependency graph

| Task | Depends on |
|------|------------|
| Task 1 | — (root) |

## Critical path

**Path:** Task 1

## Risk register

| Risk | Likelihood | Impact | Mitigation |
|------|-----------|--------|-----------|
| Counter files accumulate | Low | Low | accepted, not mitigated: tiny files |

## Rollback plan

| Task | Recovery action if `Step N: Verify` fails |
|------|--------------------------------------------|
| Task 1 | `rm -f src/limiter.sh && rm -rf .limiter` |

## Status conventions

`[ ]` pending · `[~]` in progress · `[x]` done · `[!]` blocked · `[→]` deferred.

**Status:** 0/1 tasks done.
