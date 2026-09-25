Recommended: per-caller file log + mkdir-based mutex, sliding window in `src/api.sh`

## Architecture Decision

Persist a sliding-window request log per caller as a small file under a state directory, guarded
by a `mkdir`-based mutex (the classic POSIX-atomic bash lock: `mkdir` either succeeds or fails
atomically, so no external locking tool is needed). This satisfies "plain bash, no new runtime
dependency" more strictly than `flock` (not guaranteed present everywhere, e.g. macOS/minimal
containers) while still giving correct read-modify-write serialization per caller, so concurrent
requests for the same caller cannot undercount. Different callers get independent lock/log files,
so they never contend with each other (AC3 for free, no shared bottleneck).

## Component Map

- `src/api.sh` (modify): before the existing `echo "ok"`, add:
  - config: `max="${RATE_LIMIT_MAX:-5}"`, `window="${RATE_LIMIT_WINDOW_SECS:-10}"`,
    `state_dir="${RATE_LIMIT_STATE_DIR:-/tmp/api-rate-limit}"`; `mkdir -p "$state_dir"`.
  - `id_hash=$(printf '%s' "$caller_id" | cksum | cut -d' ' -f1)` — hashes the caller id so it is
    always a safe filename (no path traversal / injection via crafted caller ids), no new tool.
  - `log="$state_dir/$id_hash.log"`, `lockdir="$state_dir/$id_hash.lockd"`.
  - acquire: loop `mkdir "$lockdir" 2>/dev/null` with short `sleep 0.02` and a bounded retry count
    (e.g. 500 tries ~10s) to avoid hanging forever; `trap 'rmdir "$lockdir" 2>/dev/null' EXIT`.
  - read `$log` if present, keep only lines where `now - ts < window`; `count=` kept-lines count.
  - if `count >= max`: rewrite `$log` with kept lines only (prune), print `denied`, exit 0.
  - else: rewrite `$log` with kept lines plus `now` appended (write to `$log.tmp`, `mv` into place
    for atomicity), print `ok`.
- `tests/test.sh` (modify): add a block that exports `RATE_LIMIT_STATE_DIR=$(mktemp -d)` and small
  `RATE_LIMIT_MAX=3`/`RATE_LIMIT_WINDOW_SECS=10` for isolation and speed, loops `MAX` calls for
  `alice` expecting `ok` each time (AC1), one more expecting `denied` (AC2), then one call for
  `bob` in the same window expecting `ok` (AC3); clean up the temp dir at the end.

## Data Flow

`api.sh <caller-id>` -> hash caller id -> acquire per-caller mutex dir -> read+prune per-caller
timestamp log -> decide `ok`/`denied` from pruned count vs `RATE_LIMIT_MAX` -> write pruned(+new)
log atomically -> release mutex (trap) -> print result.

## Build Sequence

1. Add config/hash/paths and `mkdir -p` to `src/api.sh`.
2. Add the mkdir-mutex acquire/trap-release helper.
3. Add read-prune-count-decide-write logic, replacing the unconditional `echo "ok"`.
4. Extend `tests/test.sh` with the isolated-env AC1/AC2/AC3 block; keep existing `check` line.

## Critical Details

- Undercounting risk lives entirely in the acquire step: only after `mkdir "$lockdir"` succeeds
  does the process read/decide/write, so two racing invocations for one caller strictly serialize.
- Bound the lock-wait loop (do not spin forever) and always `trap` the `rmdir` so a killed process
  doesn't leave a stale lock; document that a stale `*.lockd` after a hard crash must be removed
  manually (acceptable for this sandbox scope — no daemon to auto-clean it).
- Prune-on-every-call keeps log files small (self-cleaning), no separate GC needed.
- Tests must set `RATE_LIMIT_STATE_DIR` to a fresh `mktemp -d` per run so repeated `bash
  tests/test.sh` invocations don't inherit exhausted quota from a previous run.

## Patterns Followed

- `src/api.sh:3` already uses `set -u` and `${1:-}` guard style — new code keeps the same
  defensive-bash style and `${VAR:-default}` convention for the new env vars.
- `tests/test.sh:4` uses a small inline `check()` helper invoking `bash "$1" "$2"` — new AC1–AC3
  checks follow the same call/compare/echo pattern rather than introducing a new test framework.

Rejected: flock-based per-caller lock — flock is not guaranteed available in a "plain bash, no new
dependency" environment (absent on macOS/BSD/minimal containers), while mkdir gives the same
atomicity with only POSIX builtins — complexity: low, risk: med, test effort: low.
Rejected: single global lock/state file for all callers — still correct, but serializes unrelated
callers through one mutex and one file, adding contention and coupling that per-caller files avoid
for free — complexity: low, risk: med, test effort: low.
