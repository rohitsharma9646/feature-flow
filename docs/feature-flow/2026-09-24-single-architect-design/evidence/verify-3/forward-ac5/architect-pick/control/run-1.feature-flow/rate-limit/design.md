# Design: rate-limit — throttle requests in src/api.sh

**Spec:** `.feature-flow/rate-limit/spec.md`
**Created:** 2026-09-25

## Chosen approach

**File-backed sliding-window log with an `mkdir`-based per-caller mutex.** (Full blueprint:
`.feature-flow/rate-limit/architect.md`.)

- Config: `RATE_LIMIT_MAX` (default 5), `RATE_LIMIT_WINDOW_SECS` (default 10), and state dir
  `${RATE_LIMIT_STATE_DIR:-${TMPDIR:-/tmp}/api-rate-limit}` (created with `mkdir -p`).
- The caller-id is untrusted and is sanitized before use as a filename:
  `tr -c 'A-Za-z0-9_-' '_'` (blocks `/` and `..` path traversal). Log file: `$state_dir/$safe_id`.
- `rate_limit_check` in `src/api.sh`:
  1. Acquire the lock with `mkdir "$log.lock"` in a spin loop (`sleep 0.02`, ~5 s bound). On timeout,
     **fail closed**: print `denied`, exit 1.
  2. Read epoch-second timestamps (one per line). Keep only those `> now - RATE_LIMIT_WINDOW_SECS`
     (`awk`) and write the pruned list back.
  3. If kept-count `>= RATE_LIMIT_MAX`, print `denied` and exit 1. Otherwise append `now`, print
     `ok`, and exit 0.
  4. Always `rmdir "$log.lock"` (trap covers the error paths).
- This check replaces the unconditional `echo "ok"`, after the existing usage check.

**Why this one:** `mkdir` either creates the directory or fails, in one step. That closes the
concurrent-same-caller race the spec calls out without adding a new binary. Plain bash/coreutils and
no daemon satisfy the constraints. Per-caller files give independent tracking (AC3). A sliding log
makes "exceeds threshold within the window" exact rather than bucket-approximate.

## Rejected alternatives

| Alternative | Why rejected |
|-------------|--------------|
| `flock(1)`-based locking | Adds a util-linux binary that isn't guaranteed present, which breaks the "no new runtime dependency" constraint. `mkdir` is equally atomic and needs nothing extra. |
| Lock-free optimistic read-modify-write (temp file + atomic rename, retry on conflict) | Needs generation counters to avoid lost updates in the same-caller race the spec requires handling. Much harder to prove correct and to test. |

## Trade-off matrix

| Option | Complexity | Risk / operational impact | Test effort | New runtime dependency |
|--------|------------|----------------------------|-------------|------------------------|
| File log + `mkdir` mutex (chosen) | med | med | med | none |
| `flock(1)` locking | low | med | low | yes (util-linux `flock`) |
| Lock-free optimistic RMW | high | high | high | none |

> Extra column kept because it is the axis that eliminates `flock` against the spec constraint.

## Component map

| File / module | Responsibility | New or modified |
|---------------|----------------|-----------------|
| `src/api.sh` | Env defaults, caller-id sanitization, `rate_limit_check` (lock → prune → decide → persist → unlock), wired in place of `echo "ok"` | modified |
| `tests/test.sh` | New isolated scenario: `RATE_LIMIT_STATE_DIR=$(mktemp -d)`, `RATE_LIMIT_MAX=2`, `RATE_LIMIT_WINDOW_SECS=5`; `bob` → ok, ok, denied; `carol` → ok. Existing `alice -> ok` check kept. | modified |
| `${RATE_LIMIT_STATE_DIR:-$TMPDIR/api-rate-limit}/<safe_id>` (+ `.lock` dir) | Runtime state: per-caller timestamp log and its mutex | new (runtime, not committed) |

## Data flow

invocation → validate `caller_id` → sanitize → resolve `$log` → acquire per-caller `mkdir` lock →
read + prune timestamps → count vs `RATE_LIMIT_MAX` → (append `now` + `ok` | leave log + `denied`)
→ release lock → stdout.

## Risks

- **Undercount under contention.** Mitigated by the per-caller lock, and by failing closed on lock
  timeout rather than open.
- **Stale lock after a hard kill.** Accepted for now and noted in a code comment (see FS1). Spec
  non-goals don't require recovery.
- **Test leakage into the shared `/tmp` state.** Mitigated by pointing `RATE_LIMIT_STATE_DIR` at a
  `mktemp -d` in tests.

## Devil's advocate

### Failure scenarios

- **FS1:** A process is killed (SIGKILL / OOM / host crash) while it holds `$log.lock`. The trap
  never runs, so the lock directory is left behind. From then on, every call for that caller spins
  ~5 s, times out, and fails closed with `denied`. That caller is **permanently locked out** until
  someone deletes the `.lock` dir by hand.
- **FS2:** Sanitization collisions merge different callers onto one log file. `alice.b`, `alice/b`
  and `alice_b` all become `alice_b`, so they share one counter. One caller can exhaust another's
  quota, which violates AC3's independent tracking for IDs that differ only in disallowed
  characters.
- **FS3:** A burst of concurrent invocations for the same caller (e.g. 10 parallel
  `bash src/api.sh bob` with `RATE_LIMIT_MAX=2`) must produce **exactly** 2 `ok`. If the lock is
  ineffective (e.g. the read happens before the lock is acquired, or the write-back isn't done under
  the lock), more than `RATE_LIMIT_MAX` requests are accepted. That is the undercount the spec
  forbids. The planned sequential test would not catch it.

### Edge cases & operational risk

- `sleep 0.02` (fractional sleep) is not POSIX. On a `sleep` that only accepts integers the spin loop
  errors out or busy-waits, so check it during implementation.
- Timestamps are whole seconds, so the window edge is accurate only to within one second (acceptable
  for AC1/AC2).
- Under heavy legitimate contention (many waiters for one caller), the 5 s timeout can return
  `denied` even though the caller is under quota. This is a deliberate fail-closed trade-off.
- Rewriting the pruned log in place (truncate + write) can lose the history if the process dies
  mid-write, which causes a one-window undercount. Writing to a temp file and renaming would avoid
  it (decide in plan).
- The state dir defaults to `/tmp`. It is cleared on reboot (resets counters, harmless), and on a
  shared host it could be pre-created by another user. Using `mkdir -p` on a directory someone else
  owns is a local-trust caveat and out of scope.
