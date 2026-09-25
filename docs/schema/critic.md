# Critic — feature-flow manifest contract
> Part of the manifest contract. Core rules and the topic index: `docs/manifest-schema.md`.

## Critic

The single canonical contract for the **Critic step**: an independent `ff-critic` review of the design and the plan, run inside `ff-design` (full tier) and `ff-plan` (feature, and full-tier bugfix) before either phase completes. Both commands reference this section by name and never restate it. It is **not a phase** — no `currentPhase` value, no progress-strip entry, no `toggles.*` key — and is always on wherever those two phases run (lite tiers skip both phases, so they never run it).

### Dispatch

Once the phase has written its own artifact (`design.md`, before `decision.md`; `plan.md`), dispatch **exactly one** `ff-critic`, passing `models.critic` (`.feature-flow.json` → `${CLAUDE_PLUGIN_ROOT}/config/defaults.json`) as its model. Brief it with **paths only** — the artifact under review and its contract (feature design: the signed spec, the explore findings and any prior decision the KB recall surfaced; feature plan: the signed spec and the design; full-tier bugfix plan: the signed diagnosis) — never pasted content and never suggested findings. Name `<run dir>/critic-<phase>.md` (`critic-design.md` / `critic-plan.md`) as its **report path**: it writes the report there itself and returns only its marker lines. Check the file exists and starts with `Verdict:`; only if it does not (the write failed, or the role ran inline — Codex without subagents) write the critique there yourself, with `(inline)` at the end of its `Verdict:` line — never skip the step. Then write its repo-relative path (`<base>/<slug>/critic-<phase>.md`) to `manifest.artifacts.critic-design` / `manifest.artifacts.critic-plan`.

### Screen

The Critic reviews; the orchestrator, which holds the signed contract, decides. Before acting on any finding, screen each one:

- **Out of scope.** It asks for work the contract excludes — a non-goal, something beyond the scope, a different *what* → rewrite its line in the report as `Dropped (contradicts the spec): <finding> — <the clause it breaks>` and do not apply it (on a bugfix plan, the clause is the diagnosis's).
- **The contract is wrong.** It says the signed spec (or diagnosis) itself cannot be right → **STOP** in both modes and route the user to `/feature-flow:ff-clarify` (bugfix: `/feature-flow:ff-diagnose`); never edit the signed contract.
- **Another approach.** A design Critical whose only fix is a different approach from the one the user picked → **STOP** and ask the user (AskUserQuestion, in-session in both modes): revise within the approach, or go back to the design choice; never switch the approach yourself. In `ff-plan`, a Critical whose only fix is a change to the design → **STOP** and route to `/feature-flow:ff-design`.

The screen is idempotent: a line already `Dropped (contradicts the spec):` stays as it is.

### Revise once

- **No Critical left after the screen** → fix each Important finding in the artifact, or append `**Ruling:** I<n> — <why it stands>` to the report; the step is clear.
- **A Critical left, and the report has no `## Resolution` section** → run the one revise cycle, in this order: (1) append `## Resolution` to the report — each open Critical ID and the fix you will apply — **before** changing anything, so a dropped session finds the cycle spent; (2) revise the artifact in place; (3) re-dispatch the same `ff-critic` **once** with the same paths plus the report, and **no report path**; append its return value under `## Re-check` — never overwrite; (4) screen the re-check the same way, and fix or rule its Important findings as above.
- **A Critical still open after the re-check** → the **Critic stop** (a Mandatory pauses row in §Autopilot): cross-turn in both modes. End the turn naming each open Critical and the report path; `phases.<phase>.status` stays `in_progress`. It clears when the user fixes or redirects the artifact and re-runs the phase, confirming a fresh critique (**At a Critic stop**, below), or writes `Critic finding accepted by user (<date>): <reason>` under the finding in the report — never self-authored, never written by autopilot. There is no second cycle, in either mode.

The cycle runs in **both modes** — revising is the phase's own work, not a skipped gate. The report is its durable record (as `review.md`'s `## Resolution` is for review) — **no manifest field**.

### Re-entry and re-runs

- **Re-entry.** A phase re-entered (session drop, `ff-resume`) whose artifact is already written and whose report is on disk — found by the manifest pointer or at `<run dir>/critic-<phase>.md` — never re-dispatches the first critique. Re-run the screen, then continue from the report's state: `## Re-check` present with a Critical still open → **At a Critic stop** below (a drop between the re-check and the stop lands here too); `## Re-check` present and clear → finish ruling its Important findings, and the step is clear; `## Resolution` without `## Re-check` → the cycle is spent: finish the revision and re-dispatch the re-check once; neither → **Revise once** from the top. Artifact written but no report → dispatch as above.
- **At a Critic stop.** Re-entering a phase whose report holds a Critic stop (a `## Re-check` with a Critical still open) never re-dispatches on its own. An open Critical carrying `Critic finding accepted by user (<date>): <reason>` counts as ruled — none left open → the step is clear. Otherwise ask the user (AskUserQuestion, in-session in both modes) whether to **re-critique the current artifact** — they fixed or redirected it — or keep the stop. Re-critique → delete `<run dir>/critic-<phase>.md` and clear its pointer, then **Dispatch** afresh: a new first critique with its own revise cycle, at the user's request. Keep → end the turn at the Critic stop again.
- **Re-run.** A confirmed re-run of the phase (**Re-run guard** in `${CLAUDE_PLUGIN_ROOT}/docs/manifest-schema.md`) deletes `<run dir>/critic-<phase>.md` and clears its pointer, so the new artifact gets a fresh critique.

### Closing line

The phase's closing message carries one line, `Critic: <ready | revised | stopped> — <n> Critical, <n> Important (<report path>)`: `ready` — no Critical in the first critique; `revised` — the cycle ran and no Critical remains; `stopped` — the Critic stop. The counts are the first critique's, after the screen.

### Non-goals

No new phase, command, `currentPhase` value or toggle; no waiver line beyond the Critic stop's accept line; no critic fan-out and no second cycle; no numeric scores. `templates/design.md`, `templates/plan.md`, `templates/plan-bugfix.md` and `templates/decision.md` are unchanged — the critique lives only in its own report, located via `manifest.artifacts.critic-<phase>`. On Codex the step follows the Agent Mapping in `skills/feature-flow/references/codex-tools.md`.
