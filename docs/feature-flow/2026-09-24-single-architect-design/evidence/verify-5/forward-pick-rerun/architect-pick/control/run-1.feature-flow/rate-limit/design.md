# Design: rate-limit — throttle requests in src/api.sh

**Spec:** `.feature-flow/rate-limit/spec.md`
**Created:** 2026-09-25

## Chosen approach

**A per-caller timestamp log, locked with `flock`** (the architect's recommendation, full report in
`.feature-flow/rate-limit/architect.md`).

Each invocation is a fresh process, so state lives on disk. Each caller gets a log file holding one
epoch-seconds timestamp per line, under `RATE_LIMIT_STATE_DIR` (default
`${TMPDIR:-/tmp}/api-rate-limit`). Every request holds an exclusive per-caller `flock` for the whole
read → prune → count → append/rewrite cycle, so near-simultaneous requests for the same caller take
turns and can't both see an outdated count. Different callers never contend for the same lock.

`flock` (util-linux, `/usr/bin/flock`) is a locking tool, not a daemon or external service. The user
accepted it as allowed under the spec's "no new runtime dependency" constraint when choosing this
design on 2026-09-25. It is not portable to macOS/BSD without an extra install (see Risks).

Why this one: it is the simplest option that gives a true rolling window and meets the spec's
concurrency constraint, and pruning on every rewrite keeps the file small with no separate cleanup.

## Rejected alternatives

| Alternative | Why rejected |
|-------------|--------------|
| Counting with lock-free marker files (atomic `mkdir` or timestamp-named files as request "slots", no `flock`) | Avoids the `flock` binary, but accurate pruning and counting when requests arrive together is more race-prone, and it needs its own cleanup of old marker files. |
| Fixed-window counter (single `count:window_start` file) | Dropped before the choice: it contradicts the spec's "rolling window" (§Problem), since it can let through up to 2× `RATE_LIMIT_MAX` requests around a window boundary. |

## Trade-off matrix

| Option | Complexity | Risk / operational impact | Test effort | Portability |
|--------|------------|----------------------------|-------------|-------------|
| **flock-guarded timestamp log (chosen)** | low | low | med | med (needs util-linux `flock`) |
| Lock-free marker files | med | med | med | high (bash + coreutils only) |
| Fixed-window counter (dropped — contradicts spec) | low | med | low | med (still needs a lock for concurrency safety) |

> Portability is added because it is the one axis on which the chosen option loses.

## Component map

| File / module | Responsibility | New or modified |
|---------------|----------------|-----------------|
| `src/api.sh` | Config vars `RATE_LIMIT_MAX` (default 5), `RATE_LIMIT_WINDOW_SECS` (default 10), `RATE_LIMIT_STATE_DIR`; `sanitize_caller()` (caller-id → safe filename, `tr -c 'A-Za-z0-9_-' '_'`); `rate_limit_check()` (lock, prune, count, decide, persist); main flow calls it before the existing `echo ok` and prints only `denied` when the caller is over the limit | modified |
| `tests/test.sh` | Per-run isolated state dir (`mktemp -d`); tests for AC1, AC2 and AC3; a concurrent-burst test; tests for FS1–FS3 below | modified |

## Data flow

argv `<caller-id>` → `sanitize_caller` → `mkdir -p` state dir → open `<dir>/<id>.lock` on fd 9 →
`flock -x 9` → read `<dir>/<id>.log` (a missing file counts as empty) → drop timestamps older than
`now - RATE_LIMIT_WINDOW_SECS` → if count ≥ `RATE_LIMIT_MAX`: print `denied`, exit non-zero →
else append `now`, rewrite the log (still holding the lock), print `ok` → the lock is released when
fd 9 closes at process exit.

## Risks

- **`flock` portability**: Linux/util-linux only. Accepted for the stated Linux target; revisit if
  the target changes (see decision.md §Future considerations).
- **Shared default state dir under `/tmp`**: other users on the host could read or pre-create lock
  and log files. Accepted for this single-host scope; `RATE_LIMIT_STATE_DIR` lets operators move it.
- **Whole-second resolution**: `date +%s` granularity. Adequate for windows measured in seconds.

## Devil's advocate

### Failure scenarios

- **FS1:** The lock can't be acquired (state dir unwritable, `mkdir` or `exec 9>` fails, or `flock`
  is missing from `PATH`). The script runs without `set -e`, so it could carry on without the lock,
  or skip the check entirely and print `ok` for every request. That silently turns the rate limit
  off, and concurrent requests get undercounted. The check must detect a failed lock or state write
  and fail closed with a non-zero exit and an error on stderr, never an unguarded `ok`.
- **FS2:** A burst of N > `RATE_LIMIT_MAX` requests for the same caller launched at once
  (background `&` then `wait`) must produce **exactly** `RATE_LIMIT_MAX` `ok` lines. If the lock
  doesn't cover the whole read → rewrite cycle (for example, the log is rewritten after the lock is
  released, or read before it is taken), two processes read the same count and both print `ok`.
  Over-admission is the exact failure the spec forbids.
- **FS3:** Window boundary: a timestamp exactly `RATE_LIMIT_WINDOW_SECS` old gets pruned or kept by
  an off-by-one comparison (`<` vs `<=`). The caller is then denied one second too long, or let in
  early. Once the window has fully passed (e.g. `RATE_LIMIT_WINDOW_SECS=1`, wait 2s), a caller who
  was throttled must get `ok` again.

### Edge cases & operational risk

- **Sanitized-ID collisions**: `a/b` and `a_b` map to the same file, so they share a counter.
  Accepted, since the goal is safety against path traversal, not distinguishing exotic IDs. An empty
  caller-id is already rejected with exit 2.
- **Invalid env values** (e.g. `RATE_LIMIT_MAX=abc`, or `0`): bash arithmetic would error or deny
  everything. The implementation should validate these as positive integers and fall back to the
  defaults, or exit non-zero with a clear message.
- **Wall-clock jumps backwards** (NTP step): timestamps appear to be in the future and stay counted
  until real time catches up, so the caller is denied longer than intended. Accepted at this scope.
- **Lock/log files are never deleted**: each caller that has ever made a request leaves two small
  files behind. Accepted; operators can clear the state dir.
- **No migration**: this is new state, and a first-ever call finds no log file and returns `ok`.
