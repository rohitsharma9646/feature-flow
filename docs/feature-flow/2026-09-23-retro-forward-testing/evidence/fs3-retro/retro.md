# Retrospective: URL slugs

**Track:** feature
**Tier:** full
**Date:** 2026-09-23
**Run:** `url-slugs` — recorded by `/feature-flow:ff-retro` after the run reached `done`.

> **What the workflow's own safeguards did on this run** — gates, STOPs, cycles, waivers — and where
> the fix for each failure belongs. Built only from on-disk signals in this run's artifacts (resolved
> via `manifest.artifacts.<name>`) plus the user's notes; never a transcript. Every finding below was
> **accepted by the user** at the confirm gate. Nothing here was applied — improvements are separate,
> user-initiated work. See `${CLAUDE_PLUGIN_ROOT}/docs/manifest-schema.md` §Retrospective.

## Findings

### Finding 1: The missing-lowercase bug got past review and was only caught at verify

- **Event:** `src/slugify.sh` shipped from implement → review without its lowercase stage; only verify's executed test caught it.
- **Expected:** Review should compare the diff against AC1's stated behaviour ("lowercases, collapses non-alphanumerics to `-`, trims") and flag the missing lowercase stage before verify.
- **Observed evidence:** `.feature-flow/url-slugs/verify.md` — "`FAIL 'Hello World' -> 'Hello-World'`" and "the `tr '[:upper:]' '[:lower:]'` stage was missing from the pipeline."; user note — "the lowercase bug should have been caught by review".
- **Impact:** Time — cost one repair-and-re-verify round-trip. No quality impact in the end, because verify caught it.
- **Safeguard:** The review phase (`/feature-flow:ff-review` reviewers checking the implementation against the contract).
- **Safeguard result:** failed
- **Generalizability:** reusable
- **Recommended owner:** feature-flow command/skill
- **Proposed validation:** Given an implementation that satisfies all but one clause of a multi-clause AC (e.g. slugify without lowercasing), review raises a finding naming the missing clause; a control implementation covering every clause raises no such finding. (Fix location: ff-review — require an explicit check, per acceptance criterion, that the diff implements every behaviour the AC names.)

### Finding 2: The verify repair cycle caught the bug and fixed it in one pass

- **Event:** AC1 failed at verify, and was diagnosed, fixed and re-verified to exit 0 in one cycle.
- **Expected:** Verify runs the AC test for real; a failure triggers a single, limited repair cycle.
- **Observed evidence:** `.feature-flow/url-slugs/verify.md` — "**Outcome:** repaired in one cycle."
- **Impact:** Time — cost the extra round-trip the user noted, but stopped a broken slugifier from reaching `done`.
- **Safeguard:** Verify's executed-test gate and its `## Repair` cycle.
- **Safeguard result:** worked
- **Generalizability:** one-off
- **Recommended owner:** no change
- **Proposed validation:** None needed. Finding 1's fix is effective if later runs show fewer verify `## Repair` cycles for bugs visible in the diff.

## Rejected

1 candidate(s) proposed and rejected by the user.

## Notes

None. The user note ("url-slugs the repair cycle cost us an extra round-trip; the lowercase bug should have been caught by review") is covered by Findings 1 and 2. The FS1 CDN evidence-gap waiver was a clean, ticketed one-off and was not material.
