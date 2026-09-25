# Spec: rate-limit — throttle requests in src/api.sh

**Created:** 2026-09-24
**Track:** feature
**Status:** signed-off

## Problem

`src/api.sh` handles one request per invocation (each call is a fresh, short-lived bash process —
there is no long-running daemon). It currently accepts every request with no limit, so a caller
can flood it. We need to reject requests once a caller exceeds a threshold within a rolling window.

## Expected outcome

`src/api.sh <caller-id>` keeps counting requests per `<caller-id>` across separate invocations of
the script (since each request is its own process, any counter state must survive between calls)
and prints `denied` once a caller exceeds the threshold within the window, `ok` otherwise.

## Solution approaches considered

One obvious approach was not available here: because state must survive across separate process
invocations, at least one persistence mechanism has to be chosen and its concurrency behavior
worked out; `ff-clarify` leaves that HOW-level choice to `ff-design`.

## Assumptions (WHAT-changing)

| Statement | Confidence | Basis / evidence | If-wrong impact | Validation-required |
|---|---|---|---|---|
| none | | | | n |

## Constraints

- Plain bash; no new runtime dependency (no daemon, no external service).
- Threshold and window are read from `RATE_LIMIT_MAX` and `RATE_LIMIT_WINDOW_SECS` env vars
  (defaults: 5 requests / 10 seconds).
- Must be safe under concurrent invocations for the same `<caller-id>` (two requests arriving at
  nearly the same time must not both be undercounted).

## Touchpoints

- `src/api.sh` — add the throttling check before the existing request handling.
- `tests/test.sh` — new checks for allow/deny behavior.

## Edge cases

- Two requests for the same `<caller-id>` arriving concurrently.
- The counter state surviving process exit and being read by the next invocation.
- A caller that has never made a request before (first call always `ok`).

## Non-goals

- Distributed rate limiting across multiple hosts.
- Per-endpoint (as opposed to per-caller) limits.

## Acceptance criteria

- [ ] AC1: `bash src/api.sh alice` prints `ok` for the first `RATE_LIMIT_MAX` calls within
  `RATE_LIMIT_WINDOW_SECS` seconds.
- [ ] AC2: The next call for the same caller within the window prints `denied`.
- [ ] AC3: A different `<caller-id>` is tracked independently.

## End-to-end check

- [ ] E2E: `bash tests/test.sh` exits 0.

## Sign-off

**User signed off:** yes (2026-09-24)
