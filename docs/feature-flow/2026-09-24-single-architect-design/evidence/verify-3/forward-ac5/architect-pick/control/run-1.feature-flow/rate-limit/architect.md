Recommended: File-backed sliding-window log with mkdir-based mutex

## Architecture Decision

Persist each accepted request's timestamp in a per-caller log file under a state directory
(`${RATE_LIMIT_STATE_DIR:-${TMPDIR:-/tmp}/api-rate-limit}`). On each invocation, prune entries older
than `RATE_LIMIT_WINDOW_SECS`, count what remains, and compare to `RATE_LIMIT_MAX`. Mutual exclusion
per caller is done with `mkdir <file>.lock` — `mkdir` is POSIX-atomic, so it needs no new binary
(unlike `flock`) and satisfies "no new runtime dependency" while still closing the concurrent-request
race the spec calls out.

This is the smallest change that meets every constraint: pure bash/coreutils, no daemon, per-caller
files give natural isolation (AC3) without a shared-counter contention point, and the sliding log
(rather than a single counter) is what lets pruning and counting share one read.

## Component Map

- `src/api.sh` (modify): add near top, before `echo "ok"`:
  - `RATE_LIMIT_MAX="${RATE_LIMIT_MAX:-5}"`, `RATE_LIMIT_WINDOW_SECS="${RATE_LIMIT_WINDOW_SECS:-10}"`
  - `state_dir="${RATE_LIMIT_STATE_DIR:-${TMPDIR:-/tmp}/api-rate-limit}"`; `mkdir -p "$state_dir"`
  - `safe_id="$(printf '%s' "$caller_id" | tr -c 'A-Za-z0-9_-' '_')"` — sanitize before using as a
    filename (caller_id is untrusted input; blocks path traversal via `/` or `..`).
  - function `rate_limit_check`: acquire lock (`mkdir "$log.lock"` in a spin loop, `sleep 0.02`,
    bounded by ~5s timeout, then fail closed → `denied`), read `$log` (one epoch-seconds timestamp
    per line), keep lines `> now - RATE_LIMIT_WINDOW_SECS` via `awk`, write the pruned list back; if
    kept-count `>= RATE_LIMIT_MAX` print `denied`, exit 1; else append `now`, print `ok`, exit 0;
    always `rmdir "$log.lock"` on the way out (trap for cleanup on error paths too).
  - Call `rate_limit_check` right after the existing usage check, replacing the unconditional
    `echo "ok"`.
- `tests/test.sh` (modify): add a scenario block that exports `RATE_LIMIT_STATE_DIR` to a fresh
  `mktemp -d` (test isolation — no leakage between test runs or into `/tmp/api-rate-limit`), sets
  `RATE_LIMIT_MAX=2 RATE_LIMIT_WINDOW_SECS=5`, then runs `api.sh bob` three times expecting
  `ok, ok, denied`, and `api.sh carol` once expecting `ok` (independent counter, AC3). Keep the
  existing default-env `alice -> ok` check unchanged (AC1 default path).

## Data Flow

invocation → parse/validate `caller_id` → sanitize → compute `$log` path → acquire per-caller lock →
read+prune timestamps → count vs threshold → (append+`ok` | leave file+`denied`) → release lock →
stdout.

## Build Sequence

1. Add config/env defaults and sanitization to `src/api.sh`.
2. Implement `rate_limit_check` (lock, prune, decide, persist) as a self-contained function.
3. Wire it into the existing flow, replacing the static `echo "ok"`.
4. Extend `tests/test.sh` with isolated-state, multi-call scenarios; verify `bash tests/test.sh`
   exits 0.

## Critical Details

- Fail-closed on lock timeout (print `denied`, exit 1) rather than fail-open, since undercounting
  under contention is the exact bug the spec forbids.
- Sliding-window log (not a fixed-bucket counter) makes "exceeds threshold within the window" exact
  rather than approximate at window boundaries.
- Known limitation to note in the code comment, not fixed here (no AC requires it): a process killed
  while holding the lock leaves a stale `.lock` dir; out of scope per the spec's non-goals/edge-case
  list, but worth a one-line comment for future maintainers.
- No exit-code assertions exist in `tests/test.sh`'s `check()` today; the new scenario block asserts
  stdout only, consistent with existing style.

## Patterns Followed

- Single-file script style and `set -u` guard: `src/api.sh:1-9`.
- Test style — plain functions, stdout string comparison, `fail` accumulator, explicit exit code:
  `tests/test.sh:1-6`.

Rejected: flock(1)-based locking — reintroduces a binary (util-linux `flock`) not guaranteed present, against the spirit of "no new runtime dependency"; mkdir is equally atomic and dependency-free — complexity: low, risk: med, test effort: low.
Rejected: lock-free optimistic read-modify-write (temp file + atomic rename, retry on conflict) — genuinely different structure (no mutex, versioned writes) but needs generation counters to avoid lost updates under the same-caller race the spec explicitly requires handling correctly; much harder to prove correct — complexity: high, risk: high, test effort: high.
