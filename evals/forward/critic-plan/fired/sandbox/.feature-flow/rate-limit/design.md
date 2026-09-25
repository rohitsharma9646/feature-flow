# Design: rate-limit — throttle requests in src/api.sh

**Spec:** `.feature-flow/rate-limit/spec.md`
**Created:** 2026-09-24

## Chosen approach

**Per-caller counter file, guarded by the existing `with_lock` helper.** Keep one counter file per
caller under `.ratelimit/<caller-id>` holding the epoch-second timestamps of the caller's recent
requests. Reuse the repo's existing lock helper `with_lock` from `src/lib/lock.sh` (already used
by `src/api.sh` for its request log) to make the read-prune-append-write sequence atomic across
concurrent invocations, so no new locking code is needed. Once locked: read the caller's counter
file (missing → empty), drop timestamps older than `RATE_LIMIT_WINDOW_SECS` (default 10), and if
the remaining count is already `>= RATE_LIMIT_MAX` (default 5) print `denied` and release without
appending; otherwise append the current epoch second, write the file back, release the lock, and
print `ok`. This keeps state entirely in the filesystem, which is what a fresh-process-per-request
script needs, and needs no new runtime dependency.

## Rejected alternatives

| Alternative | Why rejected |
|-------------|--------------|
| `flock`-based locking | `flock(1)` is not available on every target this repo ships to (notably absent from stock macOS); the repo's own `with_lock` is already proven on every target it runs on |

## Trade-off matrix

| Option | Complexity | Risk / operational impact | Test effort |
|--------|------------|----------------------------|--------------|
| Per-caller file + existing `with_lock` (chosen) | low | low | low |
| `flock`-based locking | low | med | low |

## Component map

| File / module | Responsibility | New or modified |
|---------------|----------------|-----------------|
| `src/lib/lock.sh` | `with_lock <lockdir> <fn> [args...]` — atomic locking helper | existing — reused |
| `src/api.sh` | add `rate_check <caller>` (`with_lock`-guarded read-prune-count-append-write) called before the existing `echo "ok"`; print `denied` and exit 0 when the window is exceeded | modified |
| `tests/test.sh` | add checks for AC1–AC3 (allow under threshold, deny once exceeded, independent per-caller tracking) | modified |

## Data flow

`api.sh <caller-id>` → `rate_check <caller-id>` → `with_lock ".ratelimit/<caller-id>.lock"
rate_check_inner <caller-id>` → read `.ratelimit/<caller-id>` → prune timestamps older than
`RATE_LIMIT_WINDOW_SECS` → count `>= RATE_LIMIT_MAX`? → `denied` (no write) : append now, write
back → `ok`.

## Risks

- **`with_lock` failure or timeout on a crashed holder.** Whatever `with_lock` does when its lock
  is held by a dead process (retry, time out, or block) governs how a caller's counter behaves
  under a crash; since the design reuses it as-is, that behavior is inherited rather than chosen
  here (see FS1).

## Devil's advocate

### Failure scenarios

- **FS1:** A process crashes while holding `with_lock`'s lock for a caller. Every later call for
  that caller is at the mercy of `with_lock`'s own crash-recovery behavior (retry/timeout/block) —
  a behavior this design did not verify and is not this design's to fix, since it reuses the helper
  as-is; if `with_lock` blocks indefinitely on a dead holder, that caller is denied of service
  until the lock is cleared by hand.

### Edge cases & operational risk

- FS1's inherited crash behavior is the only operational risk beyond normal operation; there is no
  separate migration concern since `.ratelimit/` is created on first use and holds no schema to
  migrate.
