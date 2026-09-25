Recommended: Sliding-window log, per-caller hashed file, mkdir-based spinlock — one obvious approach for the persistence/locking mechanics; the only real alternatives are inferior on a specific sub-axis (see Rejected below).

## Patterns & Conventions Found

- `src/api.sh:1-9` — entire current script: `set -u`, arg-count guard printing usage to stderr + `exit 2`, then unconditional `echo "ok"`. No state, no helpers, no sourced libs. Style: flat, no functions, minimal.
- `tests/test.sh:1-6` — single `check()` helper: `got="$(bash "$1" "$2" 2>/dev/null)"`, compares to want, sets `fail=1` on mismatch, final `exit $fail`. Runs the script as a **separate bash subprocess** per check (matches the "fresh short-lived process" model in the spec) and env vars exported in `test.sh` before calling `check` are automatically inherited by that subprocess.
- `README.md:1-4` — describes this as a "tiny bash API"; no `lib/` directory, no multi-file convention. Everything lives directly in `src/api.sh` today.
- No CLAUDE.md, no existing state/tmp directory, no other scripts to mimic. This is a from-scratch design constrained only by the spec's touchpoints (`src/api.sh`, `tests/test.sh`).

Given the codebase's own convention is "one flat script, no libs," and the spec's touchpoint list names only `src/api.sh` and `tests/test.sh`, the throttle logic is added **inline in `src/api.sh`** rather than split into a new `src/ratelimit.sh`. This is both the smallest change and consistent with existing style.

## Architecture Decision

**Sliding-window request log, one file per caller, guarded by a per-caller `mkdir`-based lock.**

- **Persistence**: one append-mostly file per caller, each line a Unix timestamp (seconds) of an *admitted* request. To check/admit, prune lines older than `now - RATE_LIMIT_WINDOW_SECS`, count what remains, compare to `RATE_LIMIT_MAX`.
- **Locking**: `mkdir <lockdir>` is atomic on every POSIX filesystem and needs no extra binary (unlike `flock(1)`, which is util-linux-specific and not guaranteed on every host bash runs on). A spin-wait loop with a bounded timeout and stale-lock breakout makes this safe and simple.
- **Sanitization**: caller-id is never used as a filename directly. It's hashed (`sha256sum`) to a fixed-format hex string, eliminating path traversal, whitespace, and length concerns in one step (stronger than an allow-list regex, and it's also the sanitization + a natural per-caller sharding key at the same time).
- **State dir override**: `RATE_LIMIT_STATE_DIR` env var (default `${TMPDIR:-/tmp}/ff-rate-limit`), read by `src/api.sh`; tests set this to a fresh `mktemp -d` per test run for isolation and reproducibility.
- **Denied requests are not logged.** Only admitted ("ok") timestamps are written. This keeps each caller's file bounded to at most `RATE_LIMIT_MAX` lines at any time (no unbounded growth during a denial burst) and doesn't change the window-recovery math, since recovery is governed by the *admitted* timestamps aging out, not by how many denials occurred.

## Component Design

**`src/api.sh`** (modified) — single file, throttle check added before the existing "handle request" line (`echo "ok"` becomes the "admitted" branch).

Responsibilities:
1. Validate args (unchanged, `src/api.sh:4-8`).
2. Read config: `RATE_LIMIT_MAX` (default 5), `RATE_LIMIT_WINDOW_SECS` (default 10), `RATE_LIMIT_STATE_DIR` (default `${TMPDIR:-/tmp}/ff-rate-limit`).
3. Compute `caller_hash="$(printf '%s' "$caller_id" | sha256sum | cut -d' ' -f1)"`; derive `state_file` and `lock_dir` from it inside `RATE_LIMIT_STATE_DIR`.
4. Acquire per-caller lock (`mkdir` spin loop, bounded retries, stale-lock recovery), register `trap 'rmdir "$lock_dir" 2>/dev/null' EXIT` immediately after acquiring.
5. Compute `now=$(date +%s)`, `window_start=$((now - RATE_LIMIT_WINDOW_SECS))`.
6. Read `state_file` (if present), keep only lines `>= window_start` (via `awk`).
7. If kept-count `< RATE_LIMIT_MAX`: append `now` to kept set, atomically rewrite `state_file` (`tmp` + `mv -f`), `echo ok`.
8. Else: atomically rewrite `state_file` with the pruned (but not appended) kept set, `echo denied`.
9. Exit; `EXIT` trap removes the lock dir.

No new files needed — everything above lives in `src/api.sh`, matching existing single-file convention and the spec's touchpoint list.

**`tests/test.sh`** (modified) — extends the existing `check()`-based harness:
1. At top: `state_dir="$(mktemp -d)"; export RATE_LIMIT_STATE_DIR="$state_dir"; trap 'rm -rf "$state_dir"' EXIT` for isolation/cleanup across runs.
2. AC1/AC2/AC3 checks using small, deterministic `RATE_LIMIT_MAX`/`RATE_LIMIT_WINDOW_SECS` (exported before the `check` calls so the subprocess inherits them).
3. A concurrency check (new, not using the `check()` helper since it needs to fan out N parallel invocations and count outcomes rather than compare one string).

## Data Flow

```
tests/test.sh                         src/api.sh <caller>
  export RATE_LIMIT_STATE_DIR=tmp  →   reads env (MAX, WINDOW, STATE_DIR)
  export RATE_LIMIT_MAX=3          →   hash caller_id → caller_hash
  check src/api.sh alice ok         →   mkdir lock_dir (spin until acquired)
                                          trap unlock on EXIT
                                          now = date +%s
                                          read+prune state_file (awk >= window_start)
                                          count kept lines
                                          count < MAX? append now, mv tmp→state_file, echo ok
                                          count >= MAX? mv pruned tmp→state_file, echo denied
                                          (EXIT trap: rmdir lock_dir)
  got="$(bash src/api.sh alice)"   ←   stdout: "ok" | "denied"
  compare to want, set fail=1 if mismatch
```

Concurrent case: N `bash src/api.sh carol &` processes race on `mkdir "$STATE_DIR/<hash>.lock"`; only one succeeds at a time, each fully completes its read-count-decide-write cycle before releasing, so the count seen by the next waiter always reflects all prior admissions — no undercounting, no overcounting.

## Build Sequence

1. Edit `src/api.sh`: add config-var block (with defaults) after the existing arg guard (`src/api.sh:8`).
2. Add `caller_hash`, `state_file`, `lock_dir` derivation.
3. Add `mkdir -p "$RATE_LIMIT_STATE_DIR"`.
4. Add lock-acquire loop (bounded spin + stale-lock recovery) and `trap ... EXIT` for unlock.
5. Add prune/count/decide/write logic; replace the unconditional `echo "ok"` with the `ok`/`denied` branches.
6. Edit `tests/test.sh`: add `mktemp -d` state dir + cleanup trap at top.
7. Add AC1 checks: export small `RATE_LIMIT_MAX`/large `RATE_LIMIT_WINDOW_SECS`, run `check src/api.sh alice ok` `RATE_LIMIT_MAX` times in a loop.
8. Add AC2 check: one more `check src/api.sh alice denied`.
9. Add AC3 check: `check src/api.sh bob ok` (fresh caller, unaffected by alice's state).
10. Add concurrency test block: fan out `RATE_LIMIT_MAX + K` parallel `bash src/api.sh carol` invocations to per-process output files, `wait`, count `ok` vs `denied`, assert `ok` count exactly equals `RATE_LIMIT_MAX`.
11. Run `bash tests/test.sh`; confirm exit 0 and all lines print `ok   ...`.
12. (Optional, extra coverage beyond stated ACs) add a window-recovery check: small `RATE_LIMIT_WINDOW_SECS` (e.g. 2), exhaust limit, `sleep 3`, confirm next call is `ok` again — proves the *rolling* (not permanent) nature of the limit. Not required by the signed-off ACs but cheap and closes an edge case explicitly called out in the spec.

## Critical Details

- **Error handling**: if `mkdir -p "$RATE_LIMIT_STATE_DIR"` or lock acquisition fails after the timeout, fail safe by treating it as `denied` (never silently admit) — a rate limiter should never fail open. Add this as an explicit branch after the lock-wait loop's timeout.
- **Lock staleness / crash safety**: `trap ... EXIT` handles normal exits and most signals, but `SIGKILL` skips traps entirely and could leave a stale `lock_dir`. Mitigate with a bounded wait (e.g., 5s of 50ms polls) followed by a forced `rmdir` of the stale lock and one retry — acceptable best-effort recovery for this sandbox's scope; document as a known limitation rather than solving distributed lock recovery fully.
- **Caller-id sanitization**: hashing via `sha256sum` fully replaces the need for character allow-listing — any caller-id (including ones containing `/`, `..`, spaces, or control characters) maps to a fixed-format, filesystem-safe hex string. If `sha256sum` is ever unavailable on a target host, `cksum` (POSIX-mandated) is a drop-in fallback with a small collision-risk tradeoff — worth a one-line comment in the code, not a design change.
- **Rolling window correctness**: chosen sliding-log approach avoids the classic fixed-window flaw where a caller could send `MAX` requests right before a window boundary and another `MAX` right after, achieving `2×MAX` in a short span. Sliding log strictly enforces "no more than `MAX` in any trailing `WINDOW_SECS`."
- **Bounded storage**: because denied requests are never logged, and the file is rewritten with only in-window entries on every call (both admit and deny paths), each caller's file never exceeds `RATE_LIMIT_MAX` lines and old entries are actively pruned — no unbounded disk growth per caller. (Files for callers that go permanently idle are never deleted; acceptable since cleanup/expiry isn't in scope per the spec's non-goals.)
- **Timestamp resolution**: second-granularity (`date +%s`) is sufficient — correctness under concurrency comes from the lock serializing the read-decide-write cycle, not from timestamp precision; multiple admits within the same second are still counted correctly because each holds the lock in turn.
- **Testing isolation**: a fresh `mktemp -d` per `tests/test.sh` run (exported as `RATE_LIMIT_STATE_DIR`) guarantees repeated test runs never see stale counts from a previous run, and different caller-ids (`alice`, `bob`, `carol`) keep AC and concurrency tests independent of each other.
- **Concurrency test mechanics**: background subshells' stdout can't be captured via `$(...)` while backgrounded, so redirect each to its own file in a scratch dir, `wait` for all, then `grep -l '^ok$'`/count over the files — deterministic and doesn't depend on output ordering.

Rejected: Fixed-window counter (single count + window-start timestamp per caller, reset when the window elapses) — simpler file format, but allows up to 2x-burst admission at window boundaries and matches the spec's "rolling window" wording less precisely — complexity: low, risk: med, test effort: low.
Rejected: flock(1)-based per-file locking instead of mkdir spinlock — a single syscall is cleaner than a spin loop, but `flock` is a util-linux binary not guaranteed present on every host running bash (macOS/BSD, minimal/busybox containers), risking a de-facto new runtime dependency the spec forbids — complexity: low, risk: med, test effort: low.
Rejected: Single shared state file for all callers with one global lock — fewer files to manage, but serializes every caller's requests behind one lock with no correctness benefit (spec only requires per-caller safety), needlessly hurting concurrency for unrelated callers — complexity: low, risk: low, test effort: low.
