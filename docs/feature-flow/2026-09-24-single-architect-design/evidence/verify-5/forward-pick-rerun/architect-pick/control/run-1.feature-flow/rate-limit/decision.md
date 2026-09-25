---
tags: [rate-limiting, persistence, concurrency, locking, bash]
referencedFiles:
  - src/api.sh
  - tests/test.sh
---

# Decision: persist rate-limit state as a per-caller timestamp log guarded by flock

**Spec:** `.feature-flow/rate-limit/spec.md`
**Created:** 2026-09-25

## Decision

`src/api.sh` keeps a per-caller log of request timestamps on disk (`RATE_LIMIT_STATE_DIR`, default
`${TMPDIR:-/tmp}/api-rate-limit`) and holds an exclusive per-caller `flock` for the whole
read-prune-count-append cycle.

## Context

Each request is a separate short-lived bash process, so the counter must survive between runs. The
spec requires a rolling window, safety when requests for one caller arrive at the same time, and no
daemon or external service. This is the first cross-invocation state in the repo.

## Options considered

| Option | Why considered / rejected |
|--------|----------------------------|
| flock-guarded per-caller timestamp log | chosen — see Chosen + rationale below |
| Lock-free marker files (atomic `mkdir` / timestamp-named files) | Avoids the `flock` binary but is more race-prone to prune and count accurately under concurrency, and needs its own cleanup |
| Fixed-window counter | Dropped: contradicts the spec's "rolling window" (up to 2× `RATE_LIMIT_MAX` around a boundary) |

## Trade-offs

| Option | Effort | Risk | Reversibility |
|--------|--------|------|----------------|
| flock-guarded timestamp log | low | low | easy to undo (self-contained in `api.sh`; state files are disposable) |
| Lock-free marker files | med | med | easy to undo |
| Fixed-window counter | low | med | easy to undo |

## Chosen + rationale

The flock-guarded log is the simplest option that gives a true rolling window and a correct count
when requests for one caller arrive at the same time. Locking per caller keeps callers independent
(AC3). The user accepted `flock` (util-linux) as allowed under the "no new runtime dependency"
constraint (2026-09-25). The known ways this option can fail are listed in design.md §Devil's
advocate (FS1–FS3).

A later run should reopen this only if the target stops being Linux (so `flock` can't be relied
on), if limits must span several hosts (currently a non-goal), or if the whole-second resolution or
the shared `/tmp` default becomes a real problem.

**Related ACs:** AC1, AC2, AC3, E2E
**Related files:** src/api.sh, tests/test.sh

## Outcome

Pending implementation.

## Future considerations

- Portability to macOS/BSD (no `flock`): would need a `mkdir`-based lock or a different primitive.
- Distributed or multi-host limiting is out of scope and would need shared storage or a service,
  which is a new decision.
- Cleaning up state files for callers that have gone quiet, if the number of callers grows large.
