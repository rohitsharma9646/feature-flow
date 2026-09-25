Recommended: per-caller flock-guarded sliding-window log file

## Architecture Decision
Each invocation of `src/api.sh` is a fresh process, so the request counter must live on disk. Persist a small **sliding-window timestamp log per caller** under a state directory, and guard every read-prune-count-append cycle with `flock` on a per-caller lock file. `flock` is a standard util-linux binary already present on the target Linux environment; it is a locking primitive, not a daemon or external service, so it does not violate the "plain bash, no new runtime dependency" constraint. Per-caller (not global) locking keeps unrelated callers from serializing on each other, satisfying AC3's independence requirement while still making the concurrent-same-caller case (edge case 1) safe: two near-simultaneous requests for `alice` block on the same lock, so neither reads a stale count.

## Component Map
- `src/api.sh`
  - New config vars: `RATE_LIMIT_MAX=${RATE_LIMIT_MAX:-5}`, `RATE_LIMIT_WINDOW_SECS=${RATE_LIMIT_WINDOW_SECS:-10}`, `RATE_LIMIT_STATE_DIR=${RATE_LIMIT_STATE_DIR:-${TMPDIR:-/tmp}/api-rate-limit}`.
  - `sanitize_caller()` — maps `caller_id` to a safe filename (`tr -c 'A-Za-z0-9_-' '_'`) to prevent path traversal via a crafted caller-id.
  - `rate_limit_check()` — given the sanitized id: `mkdir -p` the state dir; open `"$dir/$id.lock"` on fd 9 (`exec 9>"$lockfile"`); `flock -x 9`; read `"$dir/$id.log"` (one epoch-seconds timestamp per line, missing file = empty); prune entries older than `now - RATE_LIMIT_WINDOW_SECS`; if remaining count `>= RATE_LIMIT_MAX` print `denied` and return 1; else append `now`, rewrite the pruned+appended log, print `ok`, return 0. Lock releases automatically when fd 9 closes at function/process exit.
  - Main flow calls `rate_limit_check` before the existing `echo ok`; on denial, skip the request-handling `echo ok` (replace it, since `denied` is the only output for that path) and exit.
- `tests/test.sh`
  - Isolate each test run: `export RATE_LIMIT_STATE_DIR="$(mktemp -d)"` at top, so prior runs never leak counts.
  - Sequential check: loop `RATE_LIMIT_MAX` calls for `alice` expecting `ok`, then one more expecting `denied` (AC1/AC2).
  - Independence check: `bob`'s first call still `ok` while `alice` is throttled (AC3).
  - Concurrency check: launch several background `api.sh carol` calls with `&`, `wait`, then count exactly `RATE_LIMIT_MAX` `ok` outputs and the rest `denied` — exercises the flock path directly.

## Data Flow
argv `<caller-id>` -> sanitize -> acquire per-caller flock -> read+prune log file -> compare count to `RATE_LIMIT_MAX` -> (append timestamp + write log + print `ok`) or (print `denied`) -> release lock (fd close) -> exit.

## Build Sequence
1. Add config vars, `sanitize_caller`, `rate_limit_check` to `api.sh`. 2. Wire the check into main flow, replacing the unconditional `echo ok`. 3. Update `tests/test.sh` with per-run state-dir isolation and the three new checks. 4. Run `bash tests/test.sh`.

## Critical Details
- Prune-and-rewrite on every call keeps the log file bounded (no separate GC needed at this scale).
- `flock` auto-releases on process death, so a killed request can't wedge the lock.
- First-ever call for a caller: missing log file treated as empty -> count 0 -> `ok` (edge case satisfied).
- Risk: `flock` availability is a Linux/util-linux assumption; not portable to BSD/macOS userlands without it — acceptable given the stated Linux environment, but worth flagging if the target shifts.

## Patterns Followed
`src/api.sh:3-9` is the only existing control flow (arg check -> handle) — the new check slots in as the same style of early-exit guard before the existing `echo ok`. `tests/test.sh:4` `check()` helper is reused unchanged for the new allow/deny assertions.

Rejected: lock-free marker-file counting (atomic `mkdir`/timestamp-named files as request "slots", no flock) — state held as directory entries instead of a log+lock, avoids the flock dependency but makes accurate pruning/counting under concurrency racier and needs its own file GC — complexity: med, risk: med, test effort: med.
Dropped (contradicts the spec): fixed-window counter — spec §Problem: "reject requests once a caller exceeds a threshold within a rolling window" (a fixed window admits up to 2x RATE_LIMIT_MAX across a boundary).
