# Design: Login rate limit

**Spec:** `spec.md`
**Created:** 2026-09-20

## Chosen approach

**Fixed-window counter.** One counter file per client under `.limiter/`, keyed by the current minute
(`date +%Y%m%d%H%M`); increment on each call, `deny` once it exceeds 5. Stale windows are ignored.

## Rejected alternatives

| Alternative | Why rejected |
|-------------|--------------|
| Token bucket | needs fractional refill arithmetic and a timestamp per client; burst-smoothing is not needed for 5/min |
| Sliding log | stores every attempt timestamp; more state than the requirement needs |

## Trade-off matrix

| Option | Complexity | Risk / operational impact | Test effort |
|--------|------------|----------------------------|--------------|
| Fixed-window counter | low | low | low |
| Token bucket | med | low | med |
| Sliding log | med | med | med |

## Devil's advocate

### Failure scenarios

- **FS1:** A client bursts 5 attempts at 12:00:59 and 5 more at 12:01:00 — 10 in two seconds pass. Accepted for 5/min.

### Edge cases & operational risk

- None beyond FS1.
