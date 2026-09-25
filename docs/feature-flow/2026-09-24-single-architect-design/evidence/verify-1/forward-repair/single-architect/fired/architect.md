Recommended: Per-caller timestamp-log + flock sliding-window — a `src/ratelimit.sh` library, sourced by `src/api.sh`, that records every request's epoch timestamp in a per-caller log file (keyed by a hashed, filesystem-safe caller-id) under a lock, prunes entries outside the rolling window, and denies once the in-window count exceeds `RATE_LIMIT_MAX`.

## Patterns & Conventions Found

- `src/api.sh` (9 lines) is the entire runtime: validates `$1`, then `echo "ok"` (src/api.sh:9). No prior persistence anywhere in the repo — this feature introduces the first cross-invocation state.
- `set -u` is already used (src/api.sh:3); keep strict-mode consistency in any new script.
- `tests/test.sh` has one helper, `check() { got="$(bash "$1" "$2" 2>/dev/null)"; ... }` (tests/test.sh:4), invoked as `check src/api.sh alice ok` (tests/test.sh:5). Tests run `bash <script> <single-arg>` and compare stdout only — stderr is discarded, exit code isn't checked by `check`. Any new output must go to stdout exactly `ok`/`denied` with no extra lines.
- No env-var plumbing exists yet in tests, so `RATE_LIMIT_*` config and a test-isolated state directory must be introduced in `tests/test.sh` itself.
- Repo is Linux (system-reminder confirms Linux 6.17), so `flock` (util-linux) and `sha1sum` (coreutils) can be treated as always-present system tools, not "new runtime dependencies" — same category as `date`, `mkdir`.

## Architecture Decision

**Sliding-window request log per caller, guarded by a per-caller `flock`.** Every invocation of `api.sh` for a given caller-id appends its own timestamp to that caller's log file (whether the outcome is `ok` or `denied`), then counts how many entries fall within the trailing `RATE_LIMIT_WINDOW_SECS` seconds to decide the verdict. This directly matches the spec's language ("count requests per caller-id", "rolling window") and its concurrency requirement ("must not both be undercounted") — every request is recorded exactly once, atomically, before the decision is made, so no request can be silently dropped by a race.

Per-caller locking (rather than one global lock) keeps unrelated callers from serializing on each other, matching the isolation implied by AC3 ("different caller tracked independently") without adding real complexity.

Trade-offs accepted: log file could grow unbounded under sustained flooding within a single window — mitigated with a cheap cap (see Critical Details). Clock-based (not counter-based) window means a backward NTP jump could theoretically under-throttle briefly; acceptable for this sandbox's scope (non-goal: distributed/production-grade limiting).

## Component Design

**`src/ratelimit.sh`** (new, sourced library)
- Responsibility: own all rate-limit state — location, format, locking, pruning, decision.
- Public function: `rate_limit_allow <caller-id>` → returns 0 (allow) or 1 (deny) via exit status; has the side effect of recording the request.
- Dependencies: `date`, `mkdir`, `flock`, `sha1sum`/`cut` (all standard Linux tools).
- Config (env, with spec defaults): `RATE_LIMIT_MAX` (default 5), `RATE_LIMIT_WINDOW_SECS` (default 10), `RATE_LIMIT_STATE_DIR` (default `${TMPDIR:-/tmp}/rate-limit-state`) — new env var added for test isolation and operator control, not in the spec's named vars but required to satisfy "state must survive process exit" while still being testable.

**`src/api.sh`** (modified)
- Add: source `ratelimit.sh` from its own directory (`BASH_SOURCE`-relative, cwd-independent), call `rate_limit_allow "$caller_id"` after the existing usage-validation block and before `echo "ok"`; on denial, `echo "denied"` and exit 0 (a denial is a valid handled response, not a script error — keeps `check()`'s stdout-only comparison working and doesn't require test changes to exit-code handling).

**`tests/test.sh`** (modified)
- Export `RATE_LIMIT_STATE_DIR` as a fresh `mktemp -d`, trapped for cleanup — isolates test runs from each other and from any real `/tmp/rate-limit-state`.
- Export small, deterministic `RATE_LIMIT_MAX`/`RATE_LIMIT_WINDOW_SECS` for a fast, non-flaky test.
- Add checks for AC1 (first N calls → `ok`), AC2 (N+1th call → `denied`), AC3 (different caller → `ok`).

## Implementation Map

1. **Create `src/ratelimit.sh`**
```bash
#!/usr/bin/env bash
# rate_limit_allow <caller-id>
# Records this request and returns 0 if the caller has made at most
# RATE_LIMIT_MAX requests (this one included) in the trailing
# RATE_LIMIT_WINDOW_SECS seconds, 1 otherwise. State persists under
# RATE_LIMIT_STATE_DIR across process invocations and is safe under
# concurrent calls for the same caller-id via a per-caller flock.
rate_limit_allow() {
  local caller_id="$1"
  local max="${RATE_LIMIT_MAX:-5}"
  local window="${RATE_LIMIT_WINDOW_SECS:-10}"
  local state_dir="${RATE_LIMIT_STATE_DIR:-${TMPDIR:-/tmp}/rate-limit-state}"
  mkdir -p "$state_dir" 2>/dev/null

  local key
  key="$(printf '%s' "$caller_id" | sha1sum | cut -d' ' -f1)"
  local log_file="$state_dir/$key.log"
  local lock_file="$state_dir/$key.lock"

  local now cutoff count
  now="$(date +%s)"
  cutoff=$(( now - window ))

  exec 9>"$lock_file"
  flock -x 9

  count=0
  local -a kept=()
  if [ -f "$log_file" ]; then
    while IFS= read -r ts; do
      if [ -n "$ts" ] && [ "$ts" -gt "$cutoff" ]; then
        kept+=("$ts"); count=$((count + 1))
      fi
    done < "$log_file"
  fi
  kept+=("$now")

  local cap=$(( max * 10 ))
  if [ "${#kept[@]}" -gt "$cap" ]; then
    kept=("${kept[@]: -$cap}")
  fi
  printf '%s\n' "${kept[@]}" > "$log_file"

  flock -u 9
  exec 9>&-

  [ "$((count + 1))" -le "$max" ]
}
```

2. **Modify `src/api.sh`** — insert after the existing usage check (line 7/8), before `echo "ok"`:
```bash
script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$script_dir/ratelimit.sh"

if ! rate_limit_allow "$caller_id"; then
  echo "denied"
  exit 0
fi
```

3. **Modify `tests/test.sh`** — before the existing `check` line:
```bash
export RATE_LIMIT_STATE_DIR="$(mktemp -d)"
trap 'rm -rf "$RATE_LIMIT_STATE_DIR"' EXIT
export RATE_LIMIT_MAX=3
export RATE_LIMIT_WINDOW_SECS=5

check src/api.sh alice ok       # AC1
check src/api.sh alice ok       # AC1
check src/api.sh alice ok       # AC1 (3rd = max)
check src/api.sh alice denied   # AC2
check src/api.sh bob ok         # AC3
```
Keep the existing `check src/api.sh alice ok` as the first of the three AC1 lines (no need to duplicate).

## Data Flow

1. `bash src/api.sh <caller-id>` starts a fresh process.
2. Arg validation (unchanged) — empty caller-id exits 2 before any rate-limit code runs.
3. `rate_limit_allow` computes `key = sha1sum(caller-id)`, opens/locks `$STATE_DIR/$key.lock` via `flock -x`.
4. Reads `$STATE_DIR/$key.log`, keeps timestamps `> now - window`, counts them.
5. Appends `now`, writes the pruned+appended list back to the log (this also performs compaction), releases the lock.
6. Returns allow/deny based on `count + 1 <= max`.
7. `api.sh` prints `ok` or `denied` to stdout, exits 0.
8. State on disk (`$STATE_DIR/$key.log`) is the only thing that survives process exit; next invocation for the same caller-id re-reads it.

## Build Sequence

- [ ] Create `src/ratelimit.sh` with `rate_limit_allow` as specified.
- [ ] Modify `src/api.sh` to source it and gate `echo "ok"` behind `rate_limit_allow`.
- [ ] Modify `tests/test.sh`: export isolated `RATE_LIMIT_STATE_DIR` (mktemp + trap cleanup), export `RATE_LIMIT_MAX`/`RATE_LIMIT_WINDOW_SECS`, add AC1/AC2/AC3 checks.
- [ ] Run `bash tests/test.sh`, confirm exit 0 and all `ok   ...` lines.
- [ ] (Recommended addition, not required by the ACs but validates the explicit concurrency requirement) add a smoke check that launches `RATE_LIMIT_MAX + a few` concurrent `src/api.sh sameCaller` calls backgrounded with `&`, `wait`s, and asserts the number of `ok` outputs equals exactly `RATE_LIMIT_MAX` — this is the only way to actually exercise the "not undercounted under concurrency" requirement, since the sequential AC checks alone can't prove the lock works.
- [ ] Optionally verify default-path behavior once (no `RATE_LIMIT_STATE_DIR` override) in a throwaway manual run, confirming it lands under `${TMPDIR:-/tmp}/rate-limit-state` and doesn't break repeated `bash tests/test.sh` runs (it won't, since tests always override the dir).

## Critical Details

- **Denied requests are counted.** Every call — allowed or denied — appends a timestamp and occupies a window slot. This matches "count requests per caller-id" literally and means a caller can't game the limiter by spamming denied calls to "reset" anything; it also means throttled callers only recover once their own past attempts age out of the window.
- **Caller-id sanitization.** Raw caller-id is never used in a path; `sha1sum` collapses it to a fixed 40-hex-char key, eliminating path-traversal (`../`), slash, space, and encoding concerns entirely. If `sha1sum` is ever unavailable, `cksum` (POSIX-guaranteed) is a drop-in fallback — worth a `command -v` guard if portability beyond this Linux sandbox is ever needed.
- **Locking.** `flock -x` on an fd held open for the read-modify-write of the log file makes the prune-count-append-write sequence atomic per caller; the lock is released implicitly when the fd is closed / process exits (script is short-lived, so explicit `exec 9>&-` is just defensive cleanup, not required for correctness).
- **Unbounded growth guard.** The log is capped to `max * 10` most-recent entries after each write, bounding disk usage under sustained flooding without affecting correctness of the windowed count (anything beyond the cap is already far outside any realistic window before it'd be evicted).
- **First-ever caller.** No log file exists → `count=0` → `0+1 <= max` → `ok`, satisfying "first-ever caller always ok" with zero special-casing.
- **Test isolation.** `RATE_LIMIT_STATE_DIR` is the seam that makes this testable without touching the real filesystem state between runs or between parallel CI jobs; production/default behavior falls back to a shared `/tmp` location, satisfying "survive process exit" without requiring any new persistent volume or service.
- **Output contract preserved.** `check()` only compares stdout; `denied` is printed exactly like `ok` was, with exit 0, so no changes needed to the `check` helper itself.

Rejected: Fixed-window counter (single counter + window-start timestamp reset per caller) — simpler state but suffers the classic boundary-burst problem (up to 2x MAX requests across a window edge) and doesn't match the spec's explicit "rolling window" wording — complexity: low, risk: med, test effort: low.
Rejected: mkdir-based spin-lock instead of flock — genuinely more portable (no flock dependency) but adds busy-wait polling and stale-lock-on-crash risk for no benefit on this Linux-only target, where flock is a standard, always-present tool — complexity: med, risk: med, test effort: med.
Rejected: single shared state file + one global lock for all callers — serializes every caller behind one lock (hurts AC3-style independence and scales worse), and requires embedding/escaping caller-id as data inside a shared file instead of using it to select a file, adding parsing/delimiter risk — complexity: med, risk: med, test effort: med.

(sqlite/external-store state was considered and discarded outright, not weighed as an option, since it violates the explicit "no new runtime dependency" constraint.)
