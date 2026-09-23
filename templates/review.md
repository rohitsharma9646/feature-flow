# Review: <feature title or change>

**Reviewing:** <what was reviewed — branch / diff / working tree / specific files>
**Threshold:** <reviewThreshold, default 80>
**Date:** <date>

> Findings come from `ff-code-reviewer` agents fanned out with differentiated focuses
> (e.g. simplicity / bugs / conventions), plus one spec-conformance reviewer that checks the
> change against the run's contract. Only issues scoring ≥ threshold are reported.

## Spec conformance

> One row per contract item (acceptance criterion, diagnosis fix, plan task). An unimplemented
> or partial criterion is also listed under Critical; out-of-scope changes and unrealized plan
> tasks under Important. No contract → `Spec conformance: skipped — no contract artifact resolved`.

| Contract item | Verdict (implemented / partial / missing) | Where (`file:line`) |
|---|---|---|
| <AC1: …> | <implemented> | `<path>:<line>` |

**Out-of-scope changes:** <none | list with `file:line`>

## Critical (≥ threshold, will impact functionality)

### <short title> — confidence <NN>
- **File:** `<path>:<line>`
- **Issue:** <what's wrong and why it matters>
- **Fix:** <concrete suggestion>

## Important (≥ threshold, worth addressing)

### <short title> — confidence <NN>
- **File:** `<path>:<line>`
- **Issue:** <…>
- **Fix:** <…>

## If no high-confidence issues

> No issues met the confidence threshold. The change meets standards. Brief summary:
> <one or two sentences on what was checked and why it's sound.>
