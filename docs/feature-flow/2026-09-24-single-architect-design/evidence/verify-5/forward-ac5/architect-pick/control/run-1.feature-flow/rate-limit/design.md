# Design: rate-limit — throttle requests in src/api.sh

**Spec:** `.feature-flow/rate-limit/spec.md`
**Created:** 2026-09-25

## Chosen approach

**Per-caller timestamp file + `mkdir`-mutex lock** (full architect report:
`.feature-flow/rate-limit/architect.md`).

Each caller's recent request timestamps (epoch seconds, one per line) live in
`$RATE_LIMIT_STATE_DIR/<caller-id>.times` (default state dir `/tmp/rate-limit-state`). Every
invocation takes a per-caller lock — `mkdir "$state_dir/<caller-id>.lock"`, atomic on POSIX
filesystems and needing no binary beyond coreutils (preferred over `flock`, which depends on
util-linux) — and holds it across the whole **read → prune → count → decide → write** critical
section, so concurrent calls for the same caller cannot both see a stale under-threshold count.

Decision rule: `now=$(date +%s)`; keep timestamps with `now - ts < RATE_LIMIT_WINDOW_SECS`;
if `kept >= RATE_LIMIT_MAX` → write back the pruned list, print `denied`; else append `now`,
write back, fall through to the existing handling (`echo "ok"`). Defaults `RATE_LIMIT_MAX=5`,
`RATE_LIMIT_WINDOW_SECS=10`. Denied requests are **not** recorded (a flooding caller recovers
once its accepted requests age out of the window).

Lock mechanics:
- Spin on `mkdir` with `sleep 0.02` between tries, bounded (~200 tries ≈ 4 s).
- `trap 'rmdir "$lock_dir"' EXIT` is installed **only after** the lock is acquired, so a
  process that never got the lock can never release someone else's.
- Stale-lock recovery: a lock dir whose mtime is older than `max(window, 5)` seconds is treated as
  abandoned by a crashed holder. It is broken by atomically renaming it aside
  (`mv "$lock_dir" "$lock_dir.stale.$$"` — only one waiter's rename can succeed) and then removing
  the renamed copy; the waiter then retries `mkdir`.
- Lock acquisition timeout → **fail closed**: print `denied`, a diagnostic on stderr, exit 0.

Input hardening: `caller-id` is used in a file path, so it must match `^[A-Za-z0-9._-]+$` and not
be `.` or `..`; otherwise print the usage message and `exit 2` (same path as the existing empty-id
guard).

Why this one: per-caller state matches the spec's per-caller semantics (AC3) with no cross-caller
contention, uses plain bash + coreutils only (Constraints), and pruning on every call keeps each
file bounded to ~`RATE_LIMIT_MAX` lines with no cleanup job.

## Rejected alternatives

| Alternative | Why rejected |
|-------------|--------------|
| Single global state file + lock for all callers | Serializes unrelated callers on one lock — contention/latency grows with total traffic for no benefit over per-caller locks. |
| Per-request marker files counted via `ls`/`find` | Still needs the same lock around count-then-create (the TOCTOU race remains), and adds stale-file accumulation and directory-listing overhead. |

## Trade-off matrix

| Option | Complexity | Risk / operational impact | Test effort | Cross-caller contention |
|--------|------------|----------------------------|-------------|--------------------------|
| **Per-caller timestamp file + mkdir lock (chosen)** | med | low | med | low |
| Single global state file + lock | low | med | low | high |
| Per-request marker files via ls/find | high | med | med | low |

> Extra axis kept because it differentiates: contention is the main thing the global-file option
> loses on.

## Component map

| File / module | Responsibility | New or modified |
|---------------|----------------|-----------------|
| `src/api.sh` | Config from env vars; caller-id validation; per-caller lock (acquire / stale-break / release via EXIT trap); read-prune-count-decide-write; prints `denied` or falls through to existing `ok` | modified |
| `tests/test.sh` | Exports a fresh `RATE_LIMIT_STATE_DIR="$(mktemp -d)"` and small `RATE_LIMIT_MAX`/`RATE_LIMIT_WINDOW_SECS`; checks AC1–AC3 plus the FS scenarios below via the existing `check()` helper | modified |

## Data flow

`api.sh <caller-id>` → validate id → resolve `max` / `window` / `state_dir` (`mkdir -p`) →
acquire `<id>.lock` (spin, stale-break, or time out → `denied`) → read `<id>.times` (empty if
absent → first call always `ok`) → prune to window → count → decide → write pruned (+ `now` if
allowed) back via temp file + `mv` → release lock (EXIT trap) → print `denied`, or continue to the
existing handling which prints `ok`.

## Risks

- **Undercount under concurrency** — mitigated by holding the lock across the whole
  read-modify-write, not just the write. Proven by FS1.
- **Wedged caller after a crashed holder** — mitigated by stale-lock breaking via atomic rename.
  Proven by FS2.
- **Path traversal via caller-id** — mitigated by the allow-list validation. Proven by FS3.
- **Partial write on crash** — writes go to a temp file then `mv` into place (atomic rename), so a
  reader never sees a truncated `.times` file.

## Devil's advocate

### Failure scenarios

- **FS1:** A burst of concurrent invocations for the same caller (e.g. `2 × RATE_LIMIT_MAX`
  background `api.sh alice` calls started together) undercounts because the lock does not really
  serialize the read-prune-count-write cycle — more than `RATE_LIMIT_MAX` calls print `ok`, which
  breaks the spec's concurrency constraint. Must be proven: exactly `RATE_LIMIT_MAX` of the burst
  print `ok` and the rest print `denied`.
- **FS2:** A holder killed mid-critical-section (e.g. `kill -9`, so the EXIT trap never runs)
  leaves `alice.lock` behind. Without working stale-lock recovery, every later `alice` request
  spins until timeout and fails closed with `denied` forever — a self-inflicted denial of service.
  Must be proven: with a leftover lock dir whose mtime is older than the stale threshold, the next
  call still returns the correct result.
- **FS3:** A caller-id containing `/` or `..` (e.g. `../../tmp/x`) makes the script create or
  overwrite files outside `RATE_LIMIT_STATE_DIR`, or makes the `mkdir` lock fail in a way that
  looks like contention. Must be proven: such ids are rejected with exit 2 and nothing is written
  outside the state dir.

### Edge cases & operational risk

- **Stale-break race:** waiters A and B both see a stale lock; B renames it aside and takes a fresh
  lock before A's rename, so A renames away B's *live* lock. This can only happen after a crash left
  a stale lock, and the window is a few milliseconds. Accepted as a residual risk (it could cause at
  most one extra undercount), not a contract item.
- **Clock steps backwards (NTP):** timestamps "from the future" satisfy `now - ts < window` and keep
  counting until the clock catches up, so a caller may see `denied` for longer than the window.
  Accepted; `date +%s` is the only clock plain bash offers.
- **Shared default state dir `/tmp/rate-limit-state`:** if another OS user created it first,
  writes fail on permissions. Operators should set `RATE_LIMIT_STATE_DIR` per deployment. On write
  failure the script fails closed.
- **Non-numeric / zero env vars:** `RATE_LIMIT_MAX=0` denies everything, and a non-numeric value
  breaks `$(( ))` arithmetic. Fall back to the defaults when a value is not a positive integer.
- **Test timing:** tests that rely on the real wall-clock window must use a small window (≤ 2 s)
  and should avoid asserting behavior exactly at the window boundary to stay deterministic.
