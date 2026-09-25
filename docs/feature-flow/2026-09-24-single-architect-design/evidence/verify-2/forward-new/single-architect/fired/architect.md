Recommended: sliding-window log file per caller, guarded by an atomic `mkdir`-based mutex (pure bash, no external locking binary)

**Architecture Decision**

State must outlive the process, so persistence is unavoidable. Store one small file per `caller_id` under a state directory (`RATE_LIMIT_STATE_DIR`, default `${TMPDIR:-/tmp}/api-rate-limit`), containing one epoch-second timestamp per line — one line per previously *allowed* request. Each invocation: acquire a per-caller mutex, read the file, drop lines older than `now - RATE_LIMIT_WINDOW_SECS`, count what remains. If count `>= RATE_LIMIT_MAX`, print `denied` and leave the file untouched (bounds file size naturally — denied calls never grow it). Otherwise append `now`, rewrite the file, print `ok`. Mutual exclusion uses `mkdir "$lock_dir"` as the atomic primitive (POSIX-guaranteed, no external tool), with a bounded retry/backoff loop and staleness recovery (if the lock dir's mtime exceeds a small max age, assume a crashed holder and reclaim it) — this satisfies the concurrency constraint without adding a dependency.

**Component Map**
- `src/api.sh`: add, before the existing `echo "ok"` (api.sh:9):
  - `rl_now()`, `rl_paths(caller)` → state file + lock dir paths
  - `rl_lock()/rl_unlock()`: mkdir-spinlock with timeout + stale-lock reclaim
  - `rl_check(caller)`: prune, count, decide, rewrite; returns 0=ok/1=denied
  - main: read `RATE_LIMIT_MAX` (default 5), `RATE_LIMIT_WINDOW_SECS` (default 10); call `rl_check`; on denial `echo denied; exit 0` (existing "ok" path unchanged for allowed requests)
- `tests/test.sh`: `rm -rf` the state dir (or `mktemp -d` and export `RATE_LIMIT_STATE_DIR`) before each scenario for isolation; extend `check()` or add a variant to run with exported `RATE_LIMIT_MAX`/`RATE_LIMIT_WINDOW_SECS`; add cases: N calls `ok` for `alice` then `denied`, a fresh caller `bob` still `ok`, and a distinct-caller independence check.

**Data Flow**
`argv[1]` → `rl_paths` → lock acquired → read+prune log file → count vs threshold → (append+write | leave as-is) → lock released → stdout `ok`/`denied`.

**Build Sequence**
1. Add lock/prune/count helpers to `api.sh`. 2. Wire threshold check before the existing handler. 3. Extend `test.sh` with isolated state dirs and the new allow/deny/independence cases. 4. Verify `bash tests/test.sh` exits 0.

**Critical Details**
- Isolate test runs via a per-run `RATE_LIMIT_STATE_DIR` (mktemp -d) to avoid flakiness from leftover state across CI runs.
- Lock timeout must be short (e.g. a few hundred ms with backoff) to keep single-request latency low; stale-lock reclaim prevents permanent deadlock from a killed process.
- `set -u` already present (api.sh:3); keep new code compatible.
- No unbounded growth: file only grows with allowed requests, capped at `RATE_LIMIT_MAX` lines per caller.

**Patterns Followed**: keeps `set -u` and the `usage`/exit-2 guard (api.sh:3-8) untouched; test additions follow the existing single `check()` helper style (test.sh:4-5) rather than introducing a new test framework.

Rejected: flock-based locking — relies on an external `flock` binary/kernel feature not guaranteed present, versus mkdir which needs nothing beyond POSIX shell — complexity: low, risk: med, test effort: low.
Rejected: fixed-window counter (single count + window-start timestamp instead of a timestamp log) — simpler state, but allows bursts up to ~2x threshold at window boundaries, violating the spec's "rolling window" requirement — complexity: low, risk: low, test effort: low.
