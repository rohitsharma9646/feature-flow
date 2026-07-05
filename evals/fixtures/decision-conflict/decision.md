---
tags: [session-storage, auth]
referencedFiles:
  - src/auth/session.ts
---

# Decision: Sessions are stateless JWTs (no server-side session store)

**Spec:** `docs/specs/2026-01-01-auth.md`
**Created:** 2026-01-01

## Decision

Sessions are stateless, signed JWTs verified per-request; the service keeps **no** server-side
session store.

## Context

The service must scale horizontally with no sticky sessions and no shared session cache to
operate. A server-side store (Redis/DB sessions) was the alternative under consideration.

## Options considered

| Option | Why considered / rejected |
|--------|----------------------------|
| Stateless JWTs | chosen — see Chosen + rationale below |
| Server-side Redis sessions | rejected — adds a stateful dependency and sticky-session ops |

## Trade-offs

| Option | Effort | Risk | Reversibility |
|--------|--------|------|----------------|
| Stateless JWTs | low | med (revocation is harder) | hard to undo once tokens are issued |
| Server-side Redis sessions | med | med (new stateful dep) | easy |

## Chosen + rationale

Stateless JWTs win because the deployment target is horizontally scaled with no shared cache.
Reopening this requires a concrete revocation/latency requirement that statelessness cannot meet.

**Related ACs:** AC3, AC7
**Related files:** src/auth/session.ts

## Outcome

Pending implementation.

## Future considerations

Revisit if per-request revocation becomes a hard requirement (would force a server-side store).
