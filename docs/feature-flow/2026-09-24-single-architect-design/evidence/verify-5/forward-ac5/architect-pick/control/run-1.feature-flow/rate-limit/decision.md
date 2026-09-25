---
tags: [rate-limit, persistence, locking, concurrency]
referencedFiles:
  - src/api.sh
  - tests/test.sh
---

# Decision: rate-limit state is a per-caller timestamp file guarded by a mkdir mutex

**Spec:** `.feature-flow/rate-limit/spec.md`
**Created:** 2026-09-25

## Decision

`src/api.sh` persists each caller's request timestamps in `$RATE_LIMIT_STATE_DIR/<caller-id>.times`
and serializes every read-prune-count-decide-write cycle behind a per-caller `mkdir`-based lock
(with stale-lock breaking via atomic rename, and failing closed on lock timeout).

## Context

`src/api.sh` runs as a fresh short-lived bash process per request, so rate-limit counters must
survive across processes. The spec forbids daemons and external services, and requires correctness
under concurrent calls for the same caller. This is the first cross-invocation state in the repo,
so the persistence and locking mechanism had to be chosen.

## Options considered

| Option | Why considered / rejected |
|--------|----------------------------|
| Per-caller timestamp file + mkdir lock | chosen — see Chosen + rationale below |
| Single global state file + lock | Simplest, but serializes unrelated callers on one lock (high contention). |
| Per-request marker files counted via ls/find | Still needs the same lock (TOCTOU), plus file accumulation and listing overhead. |

## Trade-offs

| Option | Effort | Risk | Reversibility |
|--------|--------|------|----------------|
| Per-caller timestamp file + mkdir lock | med | low | easy to undo |
| Single global state file + lock | low | med | easy to undo |
| Per-request marker files via ls/find | high | med | easy to undo |

## Chosen + rationale

Per-caller timestamp file + mkdir lock. It matches the per-caller semantics of AC3 without
cross-caller contention. It needs only bash + coreutils (`mkdir` is atomic, and it avoids depending
on util-linux `flock`). Pruning on each call keeps the state bounded with no cleanup job. The lock
wrapping the entire read-modify-write cycle is what satisfies the spec's concurrency constraint.
The chosen option's failure scenarios (concurrent-burst undercount, stale lock from a killed holder,
caller-id path traversal) are listed in design.md §Devil's advocate. They are verify contract items
there.

Re-litigation bar: reopen only if the limiter must span hosts (currently a spec non-goal), a
long-running daemon is introduced, or `flock`/another runtime dependency becomes acceptable.

**Related ACs:** AC1, AC2, AC3, E2E (plus the spec's concurrency constraint)
**Related files:** src/api.sh, tests/test.sh

## Outcome

Pending implementation.

## Future considerations

- Distributed limiting across hosts (spec non-goal) would need shared state, e.g. Redis, which
  would supersede this decision.
- If the per-caller file count in the state dir grows large (many one-off callers), add a sweep of
  `.times` files older than the window.
- A monotonic clock source would remove the clock-step edge case if bash ever offers one cheaply.
