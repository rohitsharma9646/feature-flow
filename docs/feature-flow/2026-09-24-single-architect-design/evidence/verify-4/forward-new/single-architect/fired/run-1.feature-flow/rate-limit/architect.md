Recommended: per-caller timestamp log + atomic-mkdir lock (sliding-window log)

## Architecture Decision

Persist each caller's recent request timestamps in a small on-disk log file, one line per
accepted request (epoch seconds), pruned to the current window on every read. Concurrent
read-modify-write is serialized with a spinlock built from `mkdir` (atomic on POSIX
filesystems — no new tool, no daemon). This gives exact sliding-window semantics (not
bucket/boundary-fuzzy) and keeps all state and logic in `src/api.sh`, matching the
single-script convention already in the repo.

State root: `RATE_LIMIT_STATE_DIR` (env, default `/tmp/rate-limit-state`), so `tests/test.sh`
can point it at a fresh `mktemp -d` per run for isolation/repeatability, while production runs
share the default. Per caller: `$STATE_DIR/<safe-id>.log` (data) and
`$STATE_DIR/<safe-id>.lock` (lock dir). `<safe-id>` = `caller_id` with every char outside
`[A-Za-z0-9_-]` mapped to `_`, closing the path-injection risk of an attacker-controlled
`caller_id`.

## Component Map

- `src/api.sh` (modify) — add, before the existing `echo ok`:
  - `sanitize_id()` — maps caller_id to a safe filename fragment.
  - `acquire_lock()` / `release_lock()` — `mkdir "$lock"` spin-loop (short sleep, bounded
    retries); if the lock dir's mtime is older than `2 * RATE_LIMIT_WINDOW_SECS`, treat it as
    abandoned (crashed holder) and `rm -rf` it before retrying — avoids permanent deadlock.
  - `check_and_record()` — under the lock: read log, keep lines with
    `now - ts < RATE_LIMIT_WINDOW_SECS`, count them; if `count < RATE_LIMIT_MAX`, append `now`
    and print `ok`; else print `denied` without appending. Rewrite the pruned (+ maybe new)
    lines back via a temp file + `mv` (atomic replace) so a crash mid-write can't corrupt state.
  - Reads `RATE_LIMIT_MAX` (default 5) / `RATE_LIMIT_WINDOW_SECS` (default 10) as today's env
    vars.
- `tests/test.sh` (modify) — wrap each scenario with its own `RATE_LIMIT_STATE_DIR=$(mktemp -d)`
  export; add AC1 (loop `RATE_LIMIT_MAX` calls → `ok`), AC2 (next call → `denied`), AC3
  (different caller under the same window → `ok`). Use small `RATE_LIMIT_MAX`/
  `RATE_LIMIT_WINDOW_SECS` overrides so tests run fast and deterministically.

## Data Flow

invocation → parse `caller_id` → sanitize → acquire per-caller lock → load+prune log →
count vs threshold → (append timestamp | skip) → persist log → release lock → print
`ok`/`denied` → exit. No state touches disk outside `$RATE_LIMIT_STATE_DIR`.

## Build Sequence

Add sanitize/lock helpers first (unit-testable in isolation), then the prune/count/record
logic, then wire into `main`, then extend `tests/test.sh` last so it exercises the finished
script.

## Critical Details

Lock has a bounded retry count with a final hard failure (`denied`, safe default) rather than
an infinite spin, so a stuck lock can't hang requests forever. Log rewritten via temp-file+`mv`
for atomicity. Stale-lock takeover uses mtime, not PID liveness (simpler, adequate for this
single-host, short-lived-process scope per the non-goals). No cleanup daemon needed — pruning
happens lazily on each caller's own next request.

## Patterns Followed

Single self-contained script per `src/api.sh:1-9`; env-var configuration already implied by the
spec's `RATE_LIMIT_MAX`/`RATE_LIMIT_WINDOW_SECS`; `tests/test.sh:4` `check()` helper pattern
reused unchanged for new assertions.

Rejected: fixed-window counter (single count + window-start per caller, reset when window elapses) — simpler state but allows up to 2x burst at window boundaries, less faithful to "rolling window" in the spec's problem statement — complexity: low, risk: med, test effort: low
Rejected: lockless atomic marker-file-per-request (one empty file per accepted request, count by filename timestamp, no explicit lock) — check-then-create is a TOCTOU race that can admit more than RATE_LIMIT_MAX under truly simultaneous requests, weaker than the log+lock design's exact enforcement — complexity: low, risk: med, test effort: med
