# Verify: repair-gap fixture (cap-detectable — one cycle already spent)

**Track:** feature
**Tier:** full
**Date:** 2026-07-06

## Contract mapping

### AC1: the counter increments correctly
- **Method:** executed-test
- **Evidence:**
  - `npm test` — exit 1 — AssertionError: expected 2 to equal 3
- **Confidence:** Partially verified
- **Gap:** still failing after one repair cycle (see ## Repair) — no second cycle is allowed

## Verdict

**Overall confidence:** Partially verified
**Verdict:** Gap report (blocking)

## Repair

**Triggering item:** AC1 — the counter increments correctly
**Captured failure:** `npm test` — exit 1 — AssertionError: expected 2 to equal 3
**Diagnosis:** off-by-one in the increment
**Fix applied:** adjusted the increment in counter.js
**Re-touched items:** AC1
**Re-verify outcome:** AC1 still Partially verified — the fix did not clear it, so the run falls through to the gap-report stop; no second cycle.
