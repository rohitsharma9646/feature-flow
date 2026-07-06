# Design: design-gap fixture

**Spec:** `docs/specs/2026-01-01-fixture.md`
**Created:** 2026-07-06

## Chosen approach

Synchronous write-through cache in front of the existing DB read path.

## Rejected alternatives

| Alternative | Why rejected |
|-------------|--------------|
| Async cache invalidation | eventual-consistency window unacceptable for this data |

## Trade-off matrix

| Option | Complexity | Risk / operational impact | Test effort |
|--------|------------|----------------------------|--------------|
| Async cache invalidation | med | med | med |
| Write-through cache (chosen) | low | med | low |

## Component map

| File / module | Responsibility | New or modified |
|---------------|----------------|-----------------|
| `src/cache/writeThrough.ts` | write-through cache wrapper | new |

## Data flow

Write request → cache write → DB write (same transaction) → ack.

## Risks

- Cache/DB write ordering could diverge under a crash mid-write.

## Devil's advocate

At least one failure scenario is required.

### Failure scenarios

- **FS1:** A process crash between the cache write and the DB write commit leaves the cache holding a value the DB never persisted — a stale-ahead read follows, with no sandbox harness available here to inject the crash and capture evidence.

### Edge cases & operational risk

- Cold-cache stampede on deploy is out of scope for this fixture.

> DELIBERATE HOLE: FS1 names a concrete failure scenario with **no** mechanical way to capture
> evidence in this sandbox — that absence IS the gap `ff-verify` must surface as an `Unverified`
> `### FS1` contract item, blocking `done` until proven or waived. This fixture proves the gap is
> present and mechanically detectable; the semantic catch (ff-verify actually mapping it + the gap
> actually blocking done, AC7, and a covered scenario NOT false-firing, AC8) is a manual self-run.
