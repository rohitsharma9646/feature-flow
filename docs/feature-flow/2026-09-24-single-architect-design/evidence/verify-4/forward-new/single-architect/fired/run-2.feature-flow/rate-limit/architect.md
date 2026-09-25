# Architect: rate-limit

Recommended: per-caller sliding-window log file, guarded by a per-caller flock

## Architecture Decision

State must survive across the fresh-process-per-call model, so persistence is unavoidable (per
spec's own note). I chose **one log file per `<caller-id>` holding request-epoch timestamps**,
read-pruned-written atomically under a **per-caller `flock`**. This directly matches the spec's own
wording ("rolling window"): a fixed-window counter+reset-timestamp is simpler to write but permits a
2x burst at the window boundary, which is not a rolling window — so it is excluded, not merely
disfavored. Per-caller lock files (rather than one global lock) keep unrelated callers from
contending on the same critical section, satisfying AC3's independence requirement structurally, not
just by namespacing keys. `flock` is a standard Linux utility (already implied available per the
sandbox), used purely as a synchronization primitive, not a daemon or external service, so it does
not violate the "no new runtime dependency" constraint.

## Component Map

- `src/api.sh` — insert a throttle block before the existing `echo "ok"`:
  - Read `RATE_LIMIT_MAX` (default 5), `RATE_LIMIT_WINDOW_SECS` (default 10), and
    `RATE_LIMIT_STATE_DIR` (default `/tmp/api-rate-limit`, overridable so tests can isolate state).
  - Sanitize `caller_id` (reject/strip `/` and whitespace) before using it as a filename, to avoid
    path traversal via a crafted caller id.
  - `mkdir -p "$state_dir"`; lock file `"$state_dir/$caller_id.lock"`, log file
    `"$state_dir/$caller_id.log"`.
  - `{ flock -x 200; ... } 200>"$lock_file"` wraps: read existing timestamps (`mapfile`, empty if
    file absent), prune those `< now - window`, count survivors. If count `>= max`: rewrite the
    pruned (unextended) list, print `denied`. Else: append `now`, rewrite, print `ok`.
  - Denied requests are never appended, so a flood of denied calls doesn't extend the caller's own
    ban — only accepted calls consume quota, which is what "rolling window" implies.
- `tests/test.sh` — add throttle checks: use `mktemp -d` for `RATE_LIMIT_STATE_DIR` and small
  values (`RATE_LIMIT_MAX=3 RATE_LIMIT_WINDOW_SECS=5`) for fast, deterministic runs; loop `MAX`
  calls for `alice` expecting `ok` (AC1), one more expecting `denied` (AC2), and a call for `bob`
  in the same window expecting `ok` (AC3). Clean up the temp dir at the end.

## Data Flow

invoke `api.sh <caller-id>` -> validate/sanitize id -> load env thresholds -> acquire per-caller
flock -> read+prune log -> compare count vs max -> write updated log -> emit `ok`/`denied` -> lock
released as subshell exits -> process exits 0.

## Build Sequence

1. Implement the sanitize+lock+prune+decide block in `src/api.sh`, replacing the unconditional
   `echo "ok"`. 2. Update `tests/test.sh` with the isolated-state throttle checks alongside the
   existing baseline check. 3. Run `bash tests/test.sh` to confirm exit 0.

## Critical Details

- Lock scope is per caller, not global, so contention and correctness for one caller never block or
  race with another (AC3, plus better concurrency under load).
- Pruning happens on every call (both `ok` and `denied` paths) so the log file never grows
  unbounded even under sustained flooding.
- `state_dir` defaults to `/tmp/api-rate-limit`; note as a minor hardening follow-up that this could
  be `chmod 700`'d since `/tmp` is world-writable, though out of scope for this spec.
- Caller-id sanitization is a small addition beyond the literal spec text but necessary once the id
  becomes a filename component.

## Patterns Followed

- `src/api.sh:3` (`set -u`), `src/api.sh:4-8` (arg validation with usage message) are preserved and
  extended rather than replaced.
- `tests/test.sh:4` `check()` helper is reused for the existing baseline assertion; new throttle
  assertions are added as direct `bash src/api.sh` invocations with env overrides, following the
  file's existing plain-bash, no-framework testing style.

Rejected: single shared state file/lock for all callers — satisfies every constraint but serializes unrelated callers through one critical section instead of per-caller sharding, adding needless contention with no benefit — complexity: low, risk: low, test effort: low
