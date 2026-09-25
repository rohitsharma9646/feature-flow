Recommended: locked sliding-window log file per caller

## Architecture Decision

Persist a per-caller sliding-window request log as a flat file under a state directory, guarded by
an `mkdir`-based lock (atomic, needs no extra binary — pure bash/coreutils, honoring "plain bash;
no new runtime dependency"). Each invocation: acquire the caller's lock, read the caller's log,
prune entries older than `RATE_LIMIT_WINDOW_SECS`, count what remains, decide `ok`/`denied`, append
the current timestamp, write back atomically (temp file + `mv`), release the lock, print the
verdict. This is the only shape that satisfies all three constraints simultaneously: cross-process
persistence, a true rolling (not fixed-bucket) window, and race-free concurrent counting.

## Component Map

- `src/api.sh` (modify): add `state_dir` resolution (`${RATE_LIMIT_STATE_DIR:-/tmp/rate-limit-state}`,
  `mkdir -p`), `RATE_LIMIT_MAX="${RATE_LIMIT_MAX:-5}"`, `RATE_LIMIT_WINDOW_SECS="${RATE_LIMIT_WINDOW_SECS:-10}"`.
  New functions: `lock_acquire caller_id` (loop `mkdir "$lockdir"` with short `sleep 0.02`, break/steal
  lock if `lockdir` mtime older than a stale-lock timeout, e.g. 5s, to survive a crashed holder),
  `lock_release` (trap on `EXIT INT TERM` to guarantee `rmdir`), and the throttle block itself, run
  before the existing `echo "ok"`. Log file: `$state_dir/<caller_id>.log`, one epoch-seconds
  timestamp per line.
- `tests/test.sh` (modify): export a fresh `RATE_LIMIT_STATE_DIR="$(mktemp -d)"` and small
  `RATE_LIMIT_MAX=3`/`RATE_LIMIT_WINDOW_SECS=10` for deterministic, fast checks; loop `RATE_LIMIT_MAX`
  calls for `alice` expecting `ok` (AC1), one more expecting `denied` (AC2), and a call for `bob`
  expecting `ok` (AC3); clean up the temp dir at the end.

## Data Flow

`api.sh <caller-id>` → resolve env config → `lock_acquire` → read+prune log → compute count →
`count < MAX ? ok : denied` → append `now` to log, atomic write → `lock_release` → print verdict →
exit 0 (verdict independent of exit code, matching current behavior).

## Build Sequence

1. Add config/state-dir resolution and lock helpers to `src/api.sh`.
2. Add prune/count/append logic and wire the verdict in place of the unconditional `echo "ok"`.
3. Update `tests/test.sh` with isolated `RATE_LIMIT_STATE_DIR` and the three new checks.

## Critical Details

- Lock must be released on any exit path (`trap lock_release EXIT INT TERM`) so a killed process
  can't deadlock future callers; stale-lock takeover (mtime-based timeout) is the safety net.
- Read-prune-append must happen entirely inside the lock; the file write uses a temp file + `mv`
  (same directory, so `mv` is atomic) to avoid a reader seeing a half-written log.
- Counting includes every attempt (allowed or denied) so a caller can't reset its own window by
  flooding past the threshold.
- State directory defaults under `/tmp`, overridable via `RATE_LIMIT_STATE_DIR` so tests don't
  collide with each other or with a real deployment's counters.

## Patterns Followed

- Keeps `set -u`, `${1:-}` arg handling, and stderr usage errors exactly as in `src/api.sh:3-8`.
- Test style matches the existing single `check()` helper convention in `tests/test.sh:4-5`;
  new checks reuse it in a loop rather than introducing a new test framework.

one obvious approach — the three constraints (state must survive across separate processes, the window must be a true rolling window not a fixed bucket, and no daemon/external dependency is allowed) jointly force a locked flat-file log; every structurally different shape considered (fixed-window counter, lock-free per-request marker files, sqlite/daemon-backed counters) drops one of those requirements rather than offering a genuine alternative.
