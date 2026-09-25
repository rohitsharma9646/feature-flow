Recommended: sliding-window log file per caller, guarded by a per-caller `mkdir` lock

## Architecture Decision

Persist a sliding-window request log per `<caller-id>` as a plain file under a state directory in
`/tmp`, one epoch-seconds timestamp per line. On each invocation: acquire an exclusive per-caller
lock (atomic `mkdir`, which is POSIX-guaranteed atomic and needs no new binary — unlike `flock`,
which isn't installed everywhere and would violate "no new runtime dependency"), read the log,
drop entries older than `RATE_LIMIT_WINDOW_SECS`, compare the remaining count to
`RATE_LIMIT_MAX`, then either append `now` and print `ok`, or print `denied` without appending.
Release the lock via `trap ... EXIT` so it clears on normal exit and signals. Filtering on every
read also keeps each log file self-trimming (bounded to ~`RATE_LIMIT_MAX` lines), so no separate
cleanup job is needed.

Locking is scoped per `caller_id` (lock dir `$STATE_DIR/<caller_id>.lock`), so concurrent requests
from *different* callers never block each other (matches AC3's independence requirement), while
concurrent requests from the *same* caller serialize correctly (satisfies the concurrency
constraint).

## Component Map

- `src/api.sh` (modify) — add before the existing `echo "ok"`:
  - `rl_state_dir()` → `${RATE_LIMIT_STATE_DIR:-/tmp/api-rate-limit}` (env-overridable for test
    isolation), `mkdir -p`.
  - `rl_check <caller_id>` → does lock/read/filter/decide/write/unlock, returns 0 (ok) or 1
    (denied) and prints nothing itself.
  - Main body: `if rl_check "$caller_id"; then echo ok; else echo denied; fi` (replaces the bare
    `echo "ok"`).
- `tests/test.sh` (modify) — extend `check()` usage:
  - Export `RATE_LIMIT_STATE_DIR="$(mktemp -d)"` at the top so each test run is isolated from
    previous runs and from `/tmp/api-rate-limit`.
  - Set small `RATE_LIMIT_MAX=2 RATE_LIMIT_WINDOW_SECS=1` (exported) so tests run fast.
  - AC1/AC2: loop calling `src/api.sh bob` `RATE_LIMIT_MAX` times expecting `ok`, then once more
    expecting `denied`.
  - AC3: interleave calls for `bob` (now denied) and a fresh `carol` (still `ok`).
  - Optional concurrency check: fire `RATE_LIMIT_MAX + 2` backgrounded calls for one caller id,
    `wait`, count `ok` occurrences, assert it equals `RATE_LIMIT_MAX`.
- `README.md` — one line documenting `RATE_LIMIT_MAX` / `RATE_LIMIT_WINDOW_SECS` (optional,
  small, keeps docs truthful).

## Data Flow

invocation → parse `caller_id` → `rl_state_dir` (mkdir -p) → acquire `$STATE_DIR/<id>.lock` (spin
on `mkdir`) → read `$STATE_DIR/<id>.log` → `awk` filter to `now-window < ts` → count vs
`RATE_LIMIT_MAX` → append-and-write-back (ok) or leave-unchanged (denied) → release lock (EXIT
trap) → print `ok`/`denied`.

## Build Sequence

1. Add `rl_state_dir`/`rl_check` to `src/api.sh`, wire into main body.
2. Update `tests/test.sh` with isolated state dir, fast thresholds, AC1–AC3 checks.
3. Run `bash tests/test.sh`; add the concurrency check last since it's the trickiest to get
   flake-free.

## Critical Details

- **Atomicity**: `mkdir` is the lock primitive — no `flock` dependency, portable to any POSIX
  shell environment.
- **Stale locks**: `trap 'rmdir "$lock_dir" 2>/dev/null' EXIT` covers normal exit and most
  signals; a `kill -9` mid-lock would deadlock future requests for that caller — acceptable given
  scope (short-lived script, not a daemon) but worth a one-line comment in the code.
- **Test isolation**: `RATE_LIMIT_STATE_DIR` env override is new surface added purely for
  testability; defaults to `/tmp/api-rate-limit` in production use.
- **First-time caller**: empty/missing log file → filtered count 0 → always `ok` (AC covered
  naturally, no special-case code needed).
- **Window boundary**: use `now - ts < window` (strict) so entries exactly at the boundary age
  out, matching "within the window" semantics.

## Patterns Followed

- `set -u`, `caller_id="${1:-}"` usage-check pattern from `src/api.sh:3-8` preserved unchanged.
- `tests/test.sh:4` `check()` helper reused as-is; new tests are additional `check` calls / loops
  in the same style, not a new test framework.

Rejected: fixed-counter-with-reset-timestamp (store `count,window_start` per caller instead of a
timestamp log) — smaller file but requires the same locking anyway, and fixed-window counters
allow a burst of `2*MAX` at window boundaries, weakening the "within a rolling window" guarantee
the spec implies — complexity: low, risk: med, test effort: low.
Rejected: single global state file with one lock for all callers — simpler locking code, but
serializes unrelated callers against each other, breaking AC3's independence expectation under
concurrent load — complexity: low, risk: med, test effort: low.
