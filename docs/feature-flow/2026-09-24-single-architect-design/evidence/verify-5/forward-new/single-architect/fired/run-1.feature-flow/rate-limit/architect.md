Recommended: lock-free per-caller marker-directory (insert-then-count)

## Architecture Decision
Persist state as one empty "marker" file per accepted request, under a per-caller subdirectory of a state root (default `${TMPDIR:-/tmp}/ff-rate-limit`, overridable via `RATE_LIMIT_STATE_DIR` so tests can isolate). Each invocation: sanitize `<caller-id>` into a filesystem-safe name, `mkdir -p` its directory, atomically create a uniquely-named marker file for *this* request, then list/prune markers to decide `ok`/`denied`. Correctness relies only on standard POSIX directory semantics (concurrent creates in the same directory are serialized by the kernel; a process always sees its own just-completed create when it lists afterward), so no `flock` or other external locking binary is required — this keeps the implementation to plain bash + coreutils (`mkdir`, `date`, `find`, `wc`), which best satisfies "no new runtime dependency." This is the "insert first, then count" pattern: because every request unconditionally records itself before deciding, two near-simultaneous requests can never both be undercounted — whichever create is serialized second will see the first's marker already on disk.

## Component Map
- `src/api.sh` (modify) — before the existing `echo "ok"` handling, add:
  - config: `max=${RATE_LIMIT_MAX:-5}`, `window=${RATE_LIMIT_WINDOW_SECS:-10}`, `state_root=${RATE_LIMIT_STATE_DIR:-${TMPDIR:-/tmp}/ff-rate-limit}`.
  - `safe=$(printf '%s' "$caller_id" | tr -c 'A-Za-z0-9._-' '_')`; `dir="$state_root/$safe"`; `mkdir -p "$dir"`.
  - `now=$(date +%s)`; marker name `"$dir/${now}_$$_$RANDOM"`; create with `: >`.
  - prune: `find "$dir" -type f -not -newermt "@$((now-window))" -delete 2>/dev/null`.
  - count: `count=$(find "$dir" -type f | wc -l)`.
  - `if [ "$count" -gt "$max" ]; then echo denied; exit 1; fi` — else fall through to existing `echo "ok"`.
- `tests/test.sh` (modify) — export a fresh `RATE_LIMIT_STATE_DIR=$(mktemp -d)` (trap cleanup) and small `RATE_LIMIT_MAX`/`RATE_LIMIT_WINDOW_SECS` (e.g. MAX=3, WINDOW=100 — large window avoids timing flakiness) per test group; loop `RATE_LIMIT_MAX` calls for `alice` expecting `ok`, one more expecting `denied`; a call for `bob` in the same window expecting `ok` (AC3).

## Data Flow
`api.sh <caller-id>` → sanitize id → per-caller marker directory → atomically add this request's marker → prune markers older than the window → count remaining → compare to `RATE_LIMIT_MAX` → print `ok`/`denied`. State survives process exit purely as files on disk; the next invocation re-derives everything from the directory listing, no in-memory state needed.

## Build Sequence
1. Implement the throttle block in `src/api.sh` ahead of existing handling.
2. Extend `tests/test.sh` with isolated `RATE_LIMIT_STATE_DIR`, the allow-then-deny loop, and the independent-caller check.
3. Run `bash tests/test.sh`.

## Critical Details
- Sanitizing `caller_id` prevents path traversal/injection via the directory name.
- Pruning happens every call, so directories self-clean and never grow unbounded from a single sustained caller.
- Marker filenames include `$$` and `$RANDOM` to avoid same-second collisions without needing atomic-exclusive semantics.
- Denied requests still create a marker, so a caller can't reset its own window by spamming past the threshold.
- Exit code 1 on `denied` is informational only; `tests/test.sh`'s `check()` compares stdout only.

## Patterns Followed
- Single-purpose script invoked per request, `set -u`, argument validation via `${1:-}` (`src/api.sh:3-8`).
- Test harness's `check()` string-compare convention (`tests/test.sh:4`) is reused unchanged for the new checks.

Rejected: flock-based single lock file per caller — flock is an extra external binary, not guaranteed present everywhere, and adds fd-management code the marker-directory approach avoids entirely — complexity: low, risk: med, test effort: low
Rejected: single global state file for all callers under one lock — serializes unrelated callers on one lock, adding contention that per-caller marker directories avoid, while giving no benefit over per-caller storage — complexity: low, risk: med, test effort: low
