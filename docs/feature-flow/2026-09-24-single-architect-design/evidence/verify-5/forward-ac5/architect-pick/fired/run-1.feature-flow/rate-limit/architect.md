Recommended: per-caller sliding-window log file with mkdir-based mutual exclusion

## Architecture Decision

Each invocation of `src/api.sh` is a fresh process, so state must live on disk. I chose a
**per-caller timestamp-log file** (one epoch-seconds integer per line, one file per caller) under
a state directory, guarded by a **mkdir-based lock** scoped to that caller's file. `mkdir` is
atomic on POSIX filesystems, ships with bash/coreutils (no new runtime dependency, satisfies the
"plain bash" constraint), and — unlike `flock` — needs no extra binary that might be absent from a
minimal environment. Locking per-caller (not globally) means unrelated callers never contend, which
matters because the constraint only requires safety for concurrent requests from the *same*
caller-id. The log is self-pruning: only timestamps inside the current window are kept, so the file
never grows unbounded and a first-time caller has no file at all (naturally `ok`).

## Component Map

- `src/api.sh` (modify): before the existing `echo "ok"`, add:
  - config: `max="${RATE_LIMIT_MAX:-5}"`, `window="${RATE_LIMIT_WINDOW_SECS:-10}"`
  - `state_dir="${RATE_LIMIT_STATE_DIR:-${TMPDIR:-/tmp}/api-rate-limit}"`; `mkdir -p "$state_dir"`
  - `safe_id` = `caller_id` with any char outside `[A-Za-z0-9_.-]` replaced by `_` (prevents path
    traversal / injection via caller-id into the filename)
  - `state_file="$state_dir/$safe_id.log"`, `lock_dir="$state_file.lock"`
  - `acquire_lock()`: loop `mkdir "$lock_dir" 2>/dev/null && return 0`; sleep 0.02s; after ~2s
    (100 tries) treat the lock as stale (crashed holder) and force `rmdir`+retry once. Set
    `trap 'rmdir "$lock_dir" 2>/dev/null' EXIT` immediately after acquiring, so the lock always
    releases even on error/interrupt.
  - decision: `now=$(date +%s)`; read `state_file` (empty if absent) into an array; keep only
    entries `> now - window`; `count=${#kept[@]}`; if `count >= max` print `denied` and rewrite
    `state_file` with `kept` (no growth on denial); else append `now`, rewrite `state_file`, print
    `ok`.
- `tests/test.sh` (modify): add a `check_seq` helper or inline loop that sets
  `RATE_LIMIT_MAX=2 RATE_LIMIT_WINDOW_SECS=2` and asserts: 1st and 2nd calls for `bob` are `ok`,
  3rd is `denied` (AC1/AC2); a call for `carol` in between is `ok` (AC3, independent counters);
  optionally sleep past the window and confirm `bob` is `ok` again. Use a fresh
  `RATE_LIMIT_STATE_DIR` (mktemp -d) per test run for isolation/idempotency.

## Data Flow

argv → parse `caller_id` → load env config → sanitize id → acquire per-id lock → read+prune log →
compare `count` vs `max` → (conditionally append) rewrite log → release lock (trap) → print
`ok`/`denied` → exit 0.

## Build Sequence

1. Add config/sanitization/paths to `src/api.sh`. 2. Add lock acquire/release with stale-lock
recovery. 3. Add read-prune-decide-write logic, replacing the bare `echo "ok"`. 4. Extend
`tests/test.sh` with the burst/independence/reset checks above.

## Critical Details

- Lock is per-caller file, not global, so independent callers never block each other.
- Stale-lock recovery avoids permanent deadlock if a prior process was killed mid-lock.
- Filename sanitization guards against a caller-id containing `/` or `..`.
- File rewrite is a full overwrite (`> state_file.tmp && mv`) done while holding the lock, so a
  reader never sees a half-written file.
- State directory defaults to `TMPDIR`/`/tmp`, overridable via `RATE_LIMIT_STATE_DIR` for test
  isolation and to avoid clashing with any other `/tmp` usage.

## Patterns Followed

`src/api.sh:3-8` already establishes `set -u`, positional-arg parsing, and usage-error-to-stderr +
`exit 2` conventions — the new code keeps that style and only adds logic before the final
`echo "ok"`. `tests/test.sh:4` establishes a single `check()` helper pattern comparing captured
stdout to an expected string, which the new checks reuse/extend rather than introducing a new
test framework.

Dropped (contradicts the spec): fixed-window counter — spec ## Problem: "reject requests once a caller exceeds a threshold within a rolling window" (a reset-based fixed window is not rolling)
Rejected: single shared state file for all callers under one global lock — simpler to write but serializes every request across every caller through one lock, causing contention/latency unrelated to the per-caller safety the constraint actually requires — complexity: low, risk: high, test effort: low
