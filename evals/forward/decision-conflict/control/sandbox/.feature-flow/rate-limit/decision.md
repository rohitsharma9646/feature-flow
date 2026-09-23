---
tags: [rate-limit, login, limiter]
referencedFiles:
  - src/limiter.sh
---

# Decision: Login rate limiting uses a fixed-window counter

**Spec:** `spec.md`
**Created:** 2026-09-20

## Decision

The login limiter is a **fixed-window counter** (per client, per clock minute) — **not** a token bucket or sliding log.

## Context

Credential stuffing on login; the requirement is a hard 5-per-minute cap, not burst smoothing.

## Options considered

| Option | Why considered / rejected |
|--------|----------------------------|
| Fixed-window counter | chosen — see Chosen + rationale below |
| Token bucket | refill arithmetic + per-client timestamps for smoothing nobody asked for |
| Sliding log | unbounded per-client state |

## Trade-offs

| Option | Effort | Risk | Reversibility |
|--------|--------|------|----------------|
| Fixed-window counter | low | low | easy to undo |
| Token bucket | med | low | easy to undo |

## Chosen + rationale

Fixed-window: simplest state (one integer per client per minute), trivially testable. Reopen only if
burst traffic at window edges becomes a measured problem (design FS1).

**Related ACs:** AC1
**Related files:** src/limiter.sh

## Outcome

Pending implementation.

## Future considerations

Revisit if window-edge bursts show up in login logs.
