Recommended: Per-caller sliding-window log file, guarded by an mkdir-based spinlock

## Architecture Decision
State lives in one flat file per caller under a state directory
(`${RATE_LIMIT_STATE_DIR:-/tmp/ff-rate-limit}/<caller-id>.log`), each line an epoch-seconds
timestamp of one accepted request ("sliding window log"). Concurrency safety comes from a
per-caller lock directory (`<caller-id>.lock`), acquired with `mkdir` — atomic on all POSIX
filesystems, needs no new binary beyond coreutils already implied by "plain bash". A stale-lock
timeout (lock dir older than ~5s is force-removed) prevents permanent deadlock if a process is
killed mid-critical-section. This is the smallest mechanism that satisfies the explicit "rolling
window" wording in the spec and the concurrency constraint, without inventing a daemon or DB.

## Component Map
- `src/api.sh` (modify): add, before the existing `echo "ok"`:
  - `rl_config()` — reads `RATE_LIMIT_MAX` (default 5), `RATE_LIMIT_WINDOW_SECS` (default 10),
    `RATE_LIMIT_STATE_DIR` (default `/tmp/ff-rate-limit`); `mkdir -p` the dir.
  - `rl_sanitize(caller_id)` — reject ids containing `/` (path-traversal guard), reuse existing
    usage-error exit path.
  - `rl_lock(caller_id)` / `rl_unlock(caller_id)` — spin on `mkdir "$dir/$id.lock"` (sleep 0.02s
    between tries), force-clear locks older than 5s.
  - `rl_check(caller_id)` — under the lock: read `$dir/$id.log`, keep lines with
    `now - ts < WINDOW`; if kept-count `< MAX`, append `now`, rewrite file, return 0 (ok);
    else rewrite pruned file (no append), return 1 (denied). Uses `date +%s`.
  - Wire: `rl_check "$caller_id" && echo ok || { echo denied; exit 1; }` ahead of current logic.
- `tests/test.sh` (modify): set a scratch `RATE_LIMIT_STATE_DIR` per run (`mktemp -d`), small
  `RATE_LIMIT_MAX`/`RATE_LIMIT_WINDOW_SECS` via exported env; add: burst test (MAX ok calls then
  1 denied for `alice`), independent-caller test (`bob` still `ok` after alice is denied), and a
  concurrency test launching `MAX+2` backgrounded invocations for one caller with `wait`, then
  asserting exactly `MAX` `ok` and the rest `denied` (no double-undercount).

## Data Flow
invocation → parse/sanitize `caller_id` → load config → acquire caller lock → read+prune log →
count vs `RATE_LIMIT_MAX` → (append timestamp | leave pruned) → release lock → print `ok`/`denied`
→ existing request handling only runs when `ok`.

## Build Sequence
1. Add config/sanitize/lock helpers to `api.sh`. 2. Add `rl_check` and wire it before existing
logic (exit 1 on denial, matching new test expectations). 3. Extend `tests/test.sh` with
state-dir isolation, burst, independent-caller, and concurrency checks.

## Critical Details
- Lock is per-caller, not global, so unrelated callers never serialize on each other.
- `flock` was considered but avoided — not guaranteed present; `mkdir` needs no extra binary.
- Denied requests are not recorded, so a flood of denials doesn't permanently pin the window.
- Sub-second races within the same `date +%s` value are still serialized correctly because the
  lock — not the timestamp resolution — is what makes counting atomic.
- Test isolation requires a fresh `RATE_LIMIT_STATE_DIR` per test run to avoid cross-run bleed.

Rejected: fixed-window counter (single `window_start,count` field per caller instead of a
timestamp log) — simpler O(1) state but allows up to 2x burst at window boundaries, diverging
from the spec's explicit "rolling window" requirement — complexity: low, risk: med, test effort: low.
Rejected: single global lock file for all callers — trivial to implement but serializes every
caller's requests through one lock, an unnecessary throughput bottleneck and a worse long-term
structure than per-caller locking — complexity: low, risk: low, test effort: low.
