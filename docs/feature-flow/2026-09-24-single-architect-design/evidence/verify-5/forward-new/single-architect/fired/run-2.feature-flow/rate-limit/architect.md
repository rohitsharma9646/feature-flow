Recommended: mkdir-lock + per-caller timestamp-log file under a state directory

## Architecture Decision
Persist a per-caller sliding-window log of request timestamps in a plain file, guarded by an
mkdir-based mutex (mkdir is atomic on POSIX filesystems, so it's a dependency-free lock — no
`flock`, no daemon). Each invocation: acquire the caller's lock, read the log, prune entries
older than `RATE_LIMIT_WINDOW_SECS`, count what remains, decide `ok`/`denied`, write the pruned
(+ new, if `ok`) log back, release the lock. This is the smallest mechanism that satisfies the
concurrency constraint: mkdir's atomicity means two near-simultaneous invocations serialize on
the lock, so neither can read a stale count and both under-count.

## Component Map
- `src/api.sh` (modify): add a `rate_limit_check <caller-id>` function near the top, called
  before the existing `echo "ok"` handling.
  - State dir: `state_dir="${RATE_LIMIT_STATE_DIR:-/tmp/ff-rate-limit-state}"`, `mkdir -p`.
  - Log file: `$state_dir/<caller-id>.log` (one epoch-seconds timestamp per line).
  - Lock dir: `$state_dir/<caller-id>.lock` acquired via `until mkdir "$lock" 2>/dev/null; do sleep 0.02; done`, released with `rmdir` in a `trap`/explicit call so a crash mid-check doesn't wedge future calls forever (add a stale-lock timeout: if lock dir's mtime is older than a few seconds, force-remove it before retrying).
  - Reads `RATE_LIMIT_MAX` (default 5) and `RATE_LIMIT_WINDOW_SECS` (default 10).
  - On `denied`: print `denied`, exit 1, skip the existing request handling.
  - On `ok`: append timestamp, release lock, fall through to existing `echo "ok"` logic.
- `tests/test.sh` (modify): extend `check()`-style assertions — loop `RATE_LIMIT_MAX` calls for
  one caller expecting `ok` each time, one more expecting `denied`, then a different caller-id
  expecting `ok`. Export a fresh `RATE_LIMIT_STATE_DIR=$(mktemp -d)` (and optionally small
  `RATE_LIMIT_MAX`/`RATE_LIMIT_WINDOW_SECS` for speed/determinism) at the top of the script so
  runs are isolated and don't inherit stale state from prior runs.

## Data Flow
invocation -> parse `caller-id` -> `rate_limit_check` acquires per-caller lock -> reads log ->
prunes by `now - RATE_LIMIT_WINDOW_SECS` -> counts -> compares to `RATE_LIMIT_MAX` -> writes
pruned(+new) log -> releases lock -> prints `ok`/`denied` (existing handling only runs on `ok`).

## Build Sequence
Implement `rate_limit_check` in `src/api.sh` first (self-contained, testable via manual repeated
invocations), wire it into the request path, then extend `tests/test.sh` to cover AC1–AC3, using
an isolated `RATE_LIMIT_STATE_DIR` per run.

## Critical Details
- Lock must be released on all exit paths (use `trap 'rmdir "$lock" 2>/dev/null' EXIT` right
  after acquiring it) so `set -u`/early exits can't leave it held.
- Stale-lock recovery avoids permanent denial-of-service from a killed process holding the lock.
- Pruning on every call keeps the log file bounded (never larger than `RATE_LIMIT_MAX` lines).
- First-ever caller has no log file — treat missing file as empty log (`ok`), satisfying the
  never-seen-caller edge case.
- Different caller-ids use different log/lock files, so they're naturally independent (AC3).

## Patterns Followed
- `src/api.sh:3` already uses `set -u` and the `caller_id="${1:-}"` guard pattern — the new
  check reuses this style and slots in right before `src/api.sh:9`'s `echo "ok"`.
- `tests/test.sh:4`'s `check()` helper (compares captured stdout to an expected literal) is
  reused unchanged for the new `ok`/`denied` assertions — no new test framework introduced.

Rejected: single global lock (one `flock`/mkdir mutex shared by all callers, guarding one counter-per-caller table file) — mechanically similar locking idea but serializes every caller's request behind one lock instead of letting independent caller-ids proceed in parallel, adding contention with no benefit over per-caller locks — complexity: low, risk: low, test effort: low
Rejected: atomic per-request marker files (empty file per request, named by timestamp+pid, under a per-caller directory, no mutex at all) — relies on atomic file creation instead of locking, but every call must list/stat a growing set of small files, inode usage climbs unboundedly under bursty callers, and two creations racing at the exact threshold can over-deny — complexity: med, risk: med, test effort: med
