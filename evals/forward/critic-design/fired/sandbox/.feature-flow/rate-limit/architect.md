Recommended: Per-caller counter file guarded by the existing lock helper

## Architecture Decision
Keep one counter file per caller under `.ratelimit/<caller-id>` holding the epoch-second timestamps of recent requests. Reuse the repo's existing lock helper `with_lock` from `src/lib/lock.sh` (already used by `src/api.sh` for its request log) to make the read-prune-append-write sequence atomic across concurrent invocations, so no new locking code is needed.

## Component Map
- `src/api.sh` — source `src/lib/lock.sh`; before `echo "ok"`, call `with_lock ".ratelimit/$caller_id.lock" rate_check "$caller_id"`; print `denied` and exit 0 when it fails.
- `src/api.sh` `rate_check <caller>` — read the caller's file, drop timestamps older than `RATE_LIMIT_WINDOW_SECS` (default 10), deny when `RATE_LIMIT_MAX` (default 5) remain, else append now and write back.
- `tests/test.sh` — checks for AC1–AC3.

## Data Flow
`api.sh <caller>` → `with_lock` → `rate_check` (read, prune, count, append) → `ok` | `denied`.

## Build Sequence
Add `rate_check` and wire it through `with_lock`, then the tests.

## Critical Details
Concurrency safety comes entirely from `with_lock`; the window is rolling because old timestamps are pruned on every call.

## Patterns Followed
`src/lib/lock.sh` `with_lock` (existing), `src/api.sh` usage message.

one obvious approach — a rolling window over separate short-lived processes needs a per-caller file and a lock, and the repo already ships the lock
