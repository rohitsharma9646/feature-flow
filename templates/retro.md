# Retrospective: <feature title or bug>

**Track:** feature | bugfix
**Tier:** full | lite
**Date:** <date>
**Run:** `<slug>` — recorded by `/feature-flow:ff-retro` after the run reached `done`.

> **What the workflow's own safeguards did on this run** — gates, STOPs, cycles, waivers — and where
> the fix for each failure belongs. Built only from on-disk signals in this run's artifacts (resolved
> via `manifest.artifacts.<name>`) plus the user's notes; never a transcript. Every finding below was
> **accepted by the user** at the confirm gate. Nothing here was applied — improvements are separate,
> user-initiated work. See `${CLAUDE_PLUGIN_ROOT}/docs/manifest-schema.md` §Retrospective.

## Findings

### Finding 1: <event, one line>

- **Event:** <what happened>
- **Expected:** <what the workflow should have done>
- **Observed evidence:** <artifact path, or a quoted line — never a paraphrase>
- **Impact:** <effect on scope, quality, safety, time, or confidence>
- **Safeguard:** <the gate / STOP / cycle / guard / instruction that applies>
- **Safeguard result:** worked | failed | missing | ambiguous | bypassed
- **Generalizability:** one-off | repo-specific | reusable
- **Recommended owner:** repo instructions | run artifacts | feature-flow command/skill | feature-flow reference doc | guard/validator script | regression/forward test | new skill | no change
- **Proposed validation:** <how a fix would be shown to work>

<!-- Owner = regression/forward test → write Proposed validation in the forward-test case shape
     (feature-flow repo's evals/forward/README.md — not shipped with the plugin), one line each:
       - **Proposed validation:**
         - Fired input: <the input that must trigger the behavior>
         - Expected outcome: <the observable that proves it fired>
         - Control input: <the closest input that must NOT trigger it> (when applicable)
     Zero candidates proposed → replace this whole section body with exactly: _No material events._
     Candidates proposed but all rejected → replace it with exactly: _No accepted findings — see Rejected._ -->

## Rejected

<n> candidate(s) proposed and rejected by the user.

## Notes

<User notes passed to ff-retro that did not become a finding, or "None".>
