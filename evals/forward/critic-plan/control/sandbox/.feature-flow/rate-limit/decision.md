---
tags: [rate-limit, api, locking]
referencedFiles:
  - src/api.sh
---

# Decision: rate-limit uses a per-caller counter file with an `mkdir`-based lock

**Spec:** `.feature-flow/rate-limit/spec.md`
**Created:** 2026-09-24

## Decision

`src/api.sh` throttles per caller with **one counter file per caller under `.ratelimit/<caller-id>`**,
guarded by an **`mkdir`-based lock** (spin-wait up to 2 s, released via `trap`) — **not** `flock`.

## Context

Each request is a fresh, short-lived process (no daemon), so any rate-limit state has to survive
across separate invocations on disk, and the read-prune-append-write sequence has to be safe under
concurrent invocations for the same caller (spec constraint). A locking mechanism had to be picked.

## Options considered

| Option | Why considered / rejected |
|--------|----------------------------|
| Per-caller file + `mkdir` lock | chosen — see Chosen + rationale below |
| `flock`-based locking | `flock(1)` is not guaranteed present on every target (notably absent from stock macOS); the repo needs a lock primitive available everywhere it ships |

## Trade-offs

| Option | Effort | Risk | Reversibility |
|--------|--------|------|----------------|
| Per-caller file + `mkdir` lock | low | low | easy to undo |
| `flock`-based locking | low | med | easy to undo |

## Chosen + rationale

`mkdir` is an atomic, portable lock primitive available on every POSIX shell this repo targets,
with no new dependency; `flock` risks being unavailable on some targets. The chosen approach's
accepted risk is design FS1: a crashed holder leaves a stale lock dir, and later callers spin-wait
2 s then proceed unlocked rather than hang forever.

**Related ACs:** AC1, AC2, AC3
**Related files:** src/api.sh

## Outcome

Pending implementation.

## Future considerations

Revisit the lock primitive if the script ever needs to run on a filesystem where `mkdir` is not
atomic (none known today), or if FS1's stale-lock window is observed to cause real undercounting
in production logs.
