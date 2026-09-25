---
tags: [rate-limiting, locking, persistence, bash]
referencedFiles:
  - src/api.sh
  - tests/test.sh
---

# Decision: Per-caller file-backed sliding log with mkdir mutex for api.sh rate limiting

**Spec:** `.feature-flow/rate-limit/spec.md`
**Created:** 2026-09-25

## Decision

`src/api.sh` rate-limits by keeping a per-caller file of request timestamps (a sliding-window log)
under `${RATE_LIMIT_STATE_DIR:-${TMPDIR:-/tmp}/api-rate-limit}`. Each caller's file is protected by
an atomic `mkdir` lock, and the check fails closed if the lock can't be taken in time. It does not
use `flock`, a daemon, or lock-free versioned writes.

## Context

Each request is a separate short-lived bash process, so the counter state has to persist between
invocations. The spec also requires correct counting when two requests for the same caller arrive
concurrently, with no new runtime dependency. This is the first cross-invocation state in the repo.

## Options considered

| Option | Why considered / rejected |
|--------|----------------------------|
| File log + `mkdir` mutex | chosen — see Chosen + rationale below |
| `flock(1)` locking | Simplest, but `flock` isn't guaranteed to be installed, which violates "no new runtime dependency" |
| Lock-free optimistic read-modify-write (temp + rename, retry) | Needs generation counters to prevent lost updates in the same-caller race. Hard to prove and test. |

## Trade-offs

| Option | Effort | Risk | Reversibility |
|--------|--------|------|----------------|
| File log + `mkdir` mutex | med | med | easy to undo |
| `flock(1)` locking | low | med | easy to undo |
| Lock-free optimistic RMW | high | high | easy to undo |

> Effort and Risk are derived from `design.md` §Trade-off matrix (Complexity + Test effort → Effort;
> Risk / operational impact → Risk). All three options keep their logic in one function and their
> state in a temp dir, so all are easy to reverse.

## Chosen + rationale

File log + `mkdir` mutex. It is the only option that meets both "no new runtime dependency" and
race-safety for concurrent same-caller requests with provable simplicity. `mkdir` is atomic without
extra tooling. Per-caller files give independent tracking. The sliding log counts exactly within the
window. Failing closed on lock timeout was chosen deliberately: undercounting is the bug the spec
forbids.

Known failure scenarios for this choice (stale lock after a hard kill, caller-id sanitization
collisions, a concurrent burst accepting more than `RATE_LIMIT_MAX`) are listed as FS1–FS3 in
`design.md` §Devil's advocate. That file is the canonical list.

Reopen this decision only if `flock` (or another locking primitive) becomes an accepted dependency,
the limiter must span hosts (currently a non-goal), or the stale-lock failure (see design.md
§Devil's advocate) proves unacceptable in practice and can't be fixed within this approach.

**Related ACs:** AC1, AC2, AC3, E2E
**Related files:** src/api.sh, tests/test.sh

## Outcome

Pending implementation.

## Future considerations

- Stale-lock recovery (e.g. an owner-PID file plus a liveness check, or breaking locks older than N
  seconds) was deferred. Revisit if FS1 shows up in practice.
- Distributed or cross-host limiting and per-endpoint limits are out of scope per the spec's
  non-goals.
