Recommended: per-caller timestamp file + mkdir-mutex lock

## Architecture Decision

Persist each caller's recent request timestamps in a per-caller file under a state directory, and
guard every read-modify-write cycle with a `mkdir`-based mutex (mkdir is atomic on POSIX filesystems
and needs no extra binary beyond what bash already uses, so it satisfies "no new runtime
dependency" more conservatively than `flock`, which depends on util-linux being installed).
Per-caller files/locks (rather than one global file) keep unrelated callers from contending on the
same lock, matching the per-caller semantics the spec already requires (AC3).

## Component Map

- `src/api.sh` (modify): before the existing `echo "ok"`, add:
  - config: `max="${RATE_LIMIT_MAX:-5}"`, `window="${RATE_LIMIT_WINDOW_SECS:-10}"`,
    `state_dir="${RATE_LIMIT_STATE_DIR:-/tmp/rate-limit-state}"`; `mkdir -p "$state_dir"`.
  - `times_file="$state_dir/$caller_id.times"`, `lock_dir="$state_dir/$caller_id.lock"`.
  - `acquire_lock()`: spin on `mkdir "$lock_dir" 2>/dev/null`, short `sleep 0.02` between tries,
    with a bounded retry count (e.g. 200 tries ≈ 4s) and a stale-lock override (remove `lock_dir`
    if its mtime is older than `window`, to recover from a crashed holder); `trap 'rmdir "$lock_dir"
    2>/dev/null' EXIT` once acquired so the lock always releases.
  - `check_and_record()`: `now=$(date +%s)`; read `times_file` (empty if absent); keep only lines
    where `now - ts < window`; `count=<kept lines>`; if `count >= max` → write back the pruned list,
    release lock, print `denied`, `exit 0`; else append `now`, write file, release lock, fall
    through to the existing request handling (`echo "ok"`).
- `tests/test.sh` (modify): export a fresh `RATE_LIMIT_STATE_DIR="$(mktemp -d)"` and small
  `RATE_LIMIT_MAX`/`RATE_LIMIT_WINDOW_SECS` (e.g. 2/2) at the top so runs are isolated and fast;
  add checks: N calls for one caller are `ok`, the next is `denied` (AC1/AC2), and a different
  `caller-id` is still `ok` while the first is denied (AC3).

## Data Flow

`api.sh <caller-id>` → resolve config/paths → acquire per-caller lock → read+prune timestamp file
→ decide `ok`/`denied` → write pruned(+appended) file → release lock → print result (and continue
to existing handling only on `ok`).

## Build Sequence

Implement the lock helper first (independently testable by hammering it with background
subshells), then the check-and-record logic wired into `api.sh`, then extend `tests/test.sh`.

## Critical Details

- Concurrency: the lock must wrap *read, prune, count, decide, write* as one critical section —
  locking only the write would let two concurrent readers both see a stale under-threshold count.
- Stale locks: bound the spin with a timeout and a max-age override so a killed process can't wedge
  future calls forever; this is an added robustness measure beyond the spec's stated cases.
- Growth: pruning on every call keeps each `.times` file bounded to ~`max` lines; no separate
  cleanup job needed.
- Test isolation: per-run `mktemp -d` state dir avoids cross-test-run pollution and flakiness from
  real wall-clock windows.

## Patterns Followed

- `set -u`, `caller_id="${1:-}"` guard, `exit 2` usage message — reused verbatim from
  `src/api.sh:3-8`.
- `tests/test.sh:4` `check()` helper pattern extended with more `check` calls rather than a new
  test framework.

Rejected: single global state file/lock for all callers — serializes unrelated callers on one lock, adding contention/latency the per-caller design avoids for no benefit — complexity: low, risk: med, test effort: low
Rejected: per-request marker files enumerated via `ls`/`find` instead of one counter file — still needs the same lock around count-then-create (mktemp'd files don't remove the TOCTOU race), while adding stale-file accumulation and directory-listing overhead — complexity: high, risk: med, test effort: med
