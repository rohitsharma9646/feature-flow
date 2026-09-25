# Design: rate-limit — throttle requests in src/api.sh

**Spec:** `.feature-flow/rate-limit/spec.md`
**Created:** 2026-09-24

## Chosen approach

**Per-caller counter file, `mkdir`-based lock.** Keep one counter file per caller under
`.ratelimit/<caller-id>` holding the epoch-second timestamps of the caller's recent requests.
Before touching that file, acquire an exclusive lock by `mkdir .ratelimit/<caller-id>.lock`
(atomic on every POSIX filesystem this repo targets); spin-wait up to 2 seconds, retrying the
`mkdir` every 50 ms, and `rmdir` the lock directory on exit via a `trap` so a normal exit — or a
signal — always releases it. Once locked: read the caller's counter file (missing → empty), drop
timestamps older than `RATE_LIMIT_WINDOW_SECS` (default 10), and if the remaining count is already
`>= RATE_LIMIT_MAX` (default 5) print `denied` and release without appending; otherwise append the
current epoch second, write the file back, release the lock, and print `ok`. This keeps state
entirely in the filesystem, which is what a fresh-process-per-request script needs, and needs no
new runtime dependency.

## Rejected alternatives

| Alternative | Why rejected |
|-------------|--------------|
| `flock`-based locking | `flock(1)` is not available on every target this repo ships to (notably absent from stock macOS); `mkdir` is atomic everywhere the script already runs |

## Trade-off matrix

| Option | Complexity | Risk / operational impact | Test effort |
|--------|------------|----------------------------|--------------|
| Per-caller file + `mkdir` lock (chosen) | low | low | low |
| `flock`-based locking | low | med | low |

## Component map

| File / module | Responsibility | New or modified |
|---------------|----------------|-----------------|
| `src/api.sh` | add `rate_check <caller>` (mkdir-lock, read-prune-count-append-write) called before the existing `echo "ok"`; print `denied` and exit 0 when the window is exceeded | modified |
| `tests/test.sh` | add checks for AC1–AC3 (allow under threshold, deny once exceeded, independent per-caller tracking) | modified |

## Data flow

`api.sh <caller-id>` → `rate_check <caller-id>` → `mkdir .ratelimit/<caller-id>.lock` (spin-wait,
`trap` release) → read `.ratelimit/<caller-id>` → prune timestamps older than
`RATE_LIMIT_WINDOW_SECS` → count `>= RATE_LIMIT_MAX`? → `denied` (no write) : append now, write
back → `ok`.

## Risks

- **Stale lock on a crashed process.** A process killed between `mkdir` and its `trap`-registered
  `rmdir` leaves `.ratelimit/<caller-id>.lock` behind. Mitigated by the 2-second spin-wait cap:
  later callers proceed rather than hanging forever, accepting a brief unlocked window rather than
  a permanent denial-of-service against that caller (see FS1).

## Devil's advocate

### Failure scenarios

- **FS1:** A crashed process leaves a stale lock dir (`mkdir` succeeded, the process was killed
  before its `trap`-registered `rmdir` ran). Every later call for that caller spin-waits the full
  2 seconds, then proceeds **unlocked** — so a burst of concurrent requests arriving in that window
  can all read the same pre-crash counter state and all get appended, undercounting the window
  until the stale lock is cleared by hand or a subsequent call's timing luck lets it settle.

### Edge cases & operational risk

- The stale-lock window in FS1 is the only operational risk beyond normal operation; there is no
  separate migration concern since `.ratelimit/` is created on first use and holds no schema to
  migrate.
