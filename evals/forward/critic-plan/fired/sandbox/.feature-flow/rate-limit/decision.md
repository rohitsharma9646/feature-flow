---
tags: [rate-limit, api, locking]
referencedFiles:
  - src/api.sh
  - src/lib/lock.sh
---

# Decision: rate-limit uses a per-caller counter file with the existing `with_lock` helper

**Spec:** `.feature-flow/rate-limit/spec.md`
**Created:** 2026-09-24

## Decision

`src/api.sh` throttles per caller with **one counter file per caller under `.ratelimit/<caller-id>`**,
guarded by the **repo's existing `with_lock` helper** in `src/lib/lock.sh` — **not** `flock` and
no new locking code.

## Context

Each request is a fresh, short-lived process (no daemon), so any rate-limit state has to survive
across separate invocations on disk, and the read-prune-append-write sequence has to be safe under
concurrent invocations for the same caller (spec constraint). A locking mechanism had to be picked.

## Options considered

| Option | Why considered / rejected |
|--------|----------------------------|
| Per-caller file + existing `with_lock` | chosen — see Chosen + rationale below |
| `flock`-based locking | `flock(1)` is not guaranteed present on every target (notably absent from stock macOS); the repo's own `with_lock` is already proven on every target it runs on |

## Trade-offs

| Option | Effort | Risk | Reversibility |
|--------|--------|------|----------------|
| Per-caller file + existing `with_lock` | low | low | easy to undo |
| `flock`-based locking | low | med | easy to undo |

## Chosen + rationale

`with_lock` is already proven in this repo (`src/api.sh`'s request log uses it today) and needs no
new locking code, so it is the lowest-effort, lowest-risk option. The chosen approach's accepted
risk is design FS1: `with_lock`'s own crash-recovery behavior for a dead lock holder is inherited
as-is rather than re-verified here.

**Related ACs:** AC1, AC2, AC3
**Related files:** src/api.sh, src/lib/lock.sh

## Outcome

Pending implementation.

## Future considerations

Revisit the lock primitive if `with_lock`'s crash-recovery behavior (FS1) turns out to block
indefinitely on a dead holder in production.
