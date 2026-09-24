# Verify: <feature title or bug>

**Track:** feature | bugfix
**Tier:** full | lite
**Date:** <date>
**Verified by:** `ff-test-runner` (executed) — evidence below is real command output.

## Commands run

| Command | Kind | Status | Evidence |
|---------|------|--------|----------|
| `<test command>` | executed-test | pass / fail | <exit status + key output excerpt> |
| `<build command>` | build/static-analysis | pass / fail | <…> |
| `<lint command>` | build/static-analysis | pass / fail | <…> |

> If no automated tests exist, that is stated here explicitly and build/lint/smoke is
> run instead — a "no tests" run is never reported as a pass.

## Evidence coverage matrix

> **Full tier only.** Lite runs replace this section's table with one line — "Lite tier:
> floor evidence only (executed-test / build/static-analysis); see `docs/schema/evidence.md`
> §Evidence, Tier scaling." Contract mapping and Regression risk still apply in full.

| Detected surface | Expected kind | Ran? | Result | Notes (gap / N/A reason) |
|------------------|---------------|------|--------|--------------------------|
| <e.g. playwright.config.ts> | e2e/browser | yes / no | pass / fail / gap | <…> |
| <e.g. no DB layer> | db | — | N/A | <reason — N/A is valid only for undetected surfaces> |

## Contract mapping

Confidence per item — exactly one of `Verified (multi-source)` | `Verified (single-source)`
| `Partially verified` | `Unverified`, derived per `docs/schema/evidence.md` §Evidence,
Confidence ladder.

**Feature track** — one block per acceptance criterion from `spec.md`:

### AC1: <requirement verbatim>
- **Method:** <evidence kinds used, or "manual — unverified">
- **Evidence:**
  - `<command>` — exit <n> | HTTP <nnn> — <excerpt>
  - artifact: `evidence/<kind>-<n>-<desc>.<ext>` (if any)
- **Confidence:** <one of the four levels>
- **Gap (only if below Verified):** <what's missing, why, what evidence is required>

**Feature track, full tier only** — plus one block per named failure scenario from `design.md`'s
`## Devil's advocate → ### Failure scenarios` (resolved via `manifest.artifacts.design`; absent
design, a lite run, or a design naming none → no FS blocks, not an empty section):

### FS1: <failure scenario verbatim>
- **Method:** <evidence kinds used, or "manual — unverified">
- **Evidence:**
  - `<command>` — exit <n> | HTTP <nnn> — <excerpt>
  - artifact: `evidence/<kind>-<n>-<desc>.<ext>` (if any)
- **Confidence:** <one of the four levels>
- **Gap (only if below Verified):** <what's missing, why, what evidence is required>

**Feature track** — plus one block per named success metric from `spec.md`'s `## Success metrics`
(resolved via `manifest.artifacts.spec`, the same pointer the AC blocks use — no new pointer; a
**presence check on the section's rows, not a tier check** — absent section, or a section with no
rows [lite tier, or a pre-WS-7 spec] → no SM blocks, not an empty section):

### E2E: <end-to-end check verbatim>
- **Method:** <evidence kinds used, or "manual — unverified">
- **Evidence:**
  - `<command>` — exit <n> | HTTP <nnn> — <excerpt>
  - artifact: `evidence/<kind>-<n>-<desc>.<ext>` (if any)
- **Confidence:** <one of the four levels>
- **Gap (only if below Verified):** <what's missing, why, what evidence is required>

### SM1: <success metric verbatim>
- **Method:** <evidence kinds used, or "manual — unverified">
- **Evidence:**
  - `<command>` — exit <n> | HTTP <nnn> — <excerpt>
  - artifact: `evidence/<kind>-<n>-<desc>.<ext>` (if any)
- **Confidence:** <one of the four levels>
- **Gap (only if below Verified):** <what's missing, why, what evidence is required>

**Bugfix track** — same block shape for each item:

### Bug no longer reproduces
- **Method / Evidence / Confidence:** <as above; repro attempt output>

### Regression test: RED before fix
- **Evidence:** <pre-fix failing output from `bugfix.red` — command + non-zero exit>

### Regression test: GREEN after fix
- **Evidence:** <post-fix passing output from `bugfix.green` — command + a zero exit code>

## Evidence artifacts index

| File | Kind | Backs |
|------|------|-------|
| `evidence/<file>` | <kind> | AC<n> / <item> |

> Every file under `evidence/` is referenced here and from at least one contract item —
> no orphaned or unreferenced evidence claims. If empty: "No evidence files captured."

## Regression risk

**Level:** Low | Medium | High
**Reason:** <what nearby behavior this change could affect, and why this level — e.g.
"touched only the new module, no shared code → Low", or "modified the shared session helper
used by checkout + wishlist → Medium">.

## Limitations & remaining risks

- <Detected-but-ungathered surfaces, environment constraints, timeouts, anything a client
  should know before signing off. "None" only when the matrix has no gaps.>

## Verdict

**Overall confidence:** <minimum level across all contract items>

> Not "done" unless every contract item is `Verified (single-source)` or better. A
> `Partially verified` or `Unverified` item blocks the done transition — the run ends with
> a gap report instead — unless the user records the explicit waiver line below. On the
> bugfix track, a fix without RED→GREEN regression evidence is **incomplete**, not done.

**Waiver (only if user-recorded):** `Evidence gap accepted by user (<date>): <reason>`

**Verdict:** Ready for done | Gap report (blocking)

## Repair

> **Autopilot + full tier only, exactly one cycle.** Present **only** when the one-cycle
> repair-and-re-verify fired (`docs/schema/autopilot.md` §Autopilot, **Repair-and-re-verify
> cycle**) — omitted on a clean pass, a pure evidence gap, a failed `FS<n>`, a lite-tier run,
> or step-by-step mode. This section's mere presence **is** the one-cycle cap: a second failure
> with it already present falls through to the standard gap-report stop, never a second attempt.
> The unfilled skeleton carries no exit/HTTP/status token, so it still DENIES Gate B on its own.

**Triggering item:** <AC<n> | the failing bugfix item> — <what failed, verbatim>
**Captured failure:** `<command>` — exit <n> | HTTP <nnn> — <excerpt> (a genuine failure — a check
that ran and failed, not a pure evidence gap)
**Diagnosis:** <the smallest plausible root cause>
**Fix applied:** <what changed, inline — no re-entry to `/feature-flow:ff-implement`>
**Re-touched items:** <AC<n>, AC<m>, … | the re-touched bugfix item(s)> — every item the fix plausibly re-touches, drawn
conservatively (when uncertain, include); exactly the set re-verified below. **An item not listed
here was NOT re-verified** and keeps its prior evidence — omission is an auditable choice, not a
default.
**Re-verify outcome:** <per re-touched item: Verified (single-source) | Verified (multi-source) |
still Partially verified | still Unverified> — every re-touched item at `Verified (single-source)`
or better clears through to done; any still below it falls through to the gap-report stop.

> Every un-touched contract item's captured evidence is preserved unchanged — an explicit
> exception to the start-of-verify evidence-clear rule; only the items named above were re-run.
