# Spec: Locale-aware timestamps

**Created:** 2026-09-22
**Track:** feature
**Status:** draft

## Problem

Users in non-US locales read timestamps in the upstream API's raw format and misread dates.

## Expected outcome

Every timestamp in the activity list renders in the viewer's locale.

## Solution approaches considered

- **Chosen — format on render with `Intl.DateTimeFormat`:** no new dependency, one call site.
- Rejected — ask the upstream API for localized strings: API has no locale parameter.

## Assumptions (WHAT-changing)

| Statement | Confidence | Basis / evidence | If-wrong impact | Validation-required |
|---|---|---|---|---|
| The upstream API returns ISO-8601 timestamps. | high | checked against 200 production responses on 2026-09-21 — all ISO-8601 | date parsing + every downstream AC breaks | n |
| The feature flag defaults off in every environment. | high | confirmed in config review | none | n |

## Constraints

- No new runtime dependency.

## Edge cases

- Missing timestamp → render an em dash.

## Non-goals

- Relative times ("3 minutes ago").

## Acceptance criteria

- [ ] AC1: A timestamp `2026-09-01T14:05:00Z` renders as `01/09/2026, 14:05` for locale `en-GB`.
- [ ] AC2: A missing timestamp renders as `—`.

## Sign-off

**User signed off:** no
