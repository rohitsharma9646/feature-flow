# Plan: a Critic inside the design and plan phases

**Goal:** One independent `ff-critic` (Opus) reviews the written `design.md` and `plan.md` against the signed contract; the orchestrator screens its findings, revises once on a Critical, and stops if one survives — no new phase.

## Outcome gate

**Spec:** `docs/feature-flow/2026-09-25-critic-plan-design/spec.md`
**Design:** `docs/feature-flow/2026-09-25-critic-plan-design/design.md`
**Acceptance criteria:** see spec §Acceptance criteria (AC1–AC10), plus E2E, SM1, SM2 and design FS1–FS3.
**User signed off:** yes (2026-09-25)

> **Coverage.** Every spec AC maps to at least one task's `**Covers:**` line. No AC is uncovered.
>
> | AC | Task(s) |
> |---|---|
> | AC1 | T1 |
> | AC2 | T2 |
> | AC4 | T3 |
> | AC3, AC5, AC6, AC7, AC8, AC10 | T4 |
> | AC9 | T5, T6, T8 |
> | E2E, SM1, SM2 | T7 |
>
> **Assumption validation (full tier).** Assumption 1 → Task 7 (`**Validates:** Assumption 1`), acknowledged open at
> sign-off. Assumptions 2 and 3 are `n`, so they get no task; SM1/SM2 measure Assumption 2 directly.
>
> **Requirement-graph coverage.** Folded into the dependency graph:
> - `AC3/AC4 depends-on AC1, AC2`: T3 and T4 depend on T1 and T2.
> - `AC5/AC6 depends-on AC4`: T4 depends on T3.
> - `AC9 depends-on AC1`: T5 and T6 depend on T1.
>
> Named gaps (both ACs covered by the same Task 4): `AC5 depends-on AC3`, `AC6 depends-on AC3`,
> `AC7 depends-on AC5`, `AC8 depends-on AC5`.

## Global Constraints

Copied verbatim from the spec's `## Constraints`:

- No new phase or command: the Critic runs inside `ff-design` and `ff-plan`; `currentPhase` values, the phase list, the progress strip and every existing gate (sign-off, choice pause, do-not-contradict STOP, devil's-advocate pass stays) are unchanged.
- Exactly one Critic dispatch per phase, plus at most one re-check. No fan-out.
- The Critic is a leaf: it never edits code or the artifacts it reviews (no `Edit`, no `Bash`); its only write is its own report, to the path the caller names; it returns marker lines, each on one physical line.
- A short report (on the order of the architect's ~400–800-word budget), not a multi-section human report. Severity is feature-flow's Critical / Important — no third vocabulary.
- The Critic never authors a waiver, sign-off or override. `Critic finding accepted by user (<date>): <reason>` is user-authored only; autopilot never writes it.
- Codex parity: on Codex the Critic runs as a native subagent, or inline when subagents are unavailable; `dist/` is repackaged and stays byte-identical to its sources.
- No commits; the user's `~/.claude/skills/critical-plan-review` is left untouched. Every guard and `scripts/eval.sh` exits 0 (the Go-only guard excepted, as on every run of this repo).

Binding decisions from the design:

- Report paths are `<run dir>/critic-design.md` and `<run dir>/critic-plan.md`. Their repo-relative paths go in `manifest.artifacts.critic-design` and `manifest.artifacts.critic-plan`. They are ephemeral and never promoted.
- `docs/schema/critic.md` §Critic is the one canonical procedure. The commands reference it by name and never restate it.
- The Critic reviews the **written** artifact. In `ff-design`, `design.md` is written, then the Critic runs, then `decision.md` is written. In `ff-plan`, `plan.md` is written, then the Critic runs. Neither phase becomes `"complete"` before the Critic clears.
- In the revise cycle, `## Resolution` is appended **before** the revision. The re-check has **no report path**, and its return is appended under `## Re-check`.
- The markers are exactly:
  - `Verdict: ready` or `Verdict: revise`
  - `Critical C<n>: <title> — <where> — basis: verified|from the contract|inferred`
  - `Important I<n>: <title> — <where> — basis: verified|from the contract|inferred`
  - `No findings — <why the artifact holds>`
- The closing line is `Critic: <ready | revised | stopped> — <n> Critical, <n> Important (<report path>)`.
- `templates/design.md`, `templates/plan.md`, `templates/plan-bugfix.md` and `templates/decision.md` stay byte-unchanged.
- After editing any packaged file, run `bash scripts/package-codex-plugin.sh`. Never `git add`, `git commit`, `git stash` or `git reset`.

## Tasks

> **No Placeholders.** Every task is executable from this task, `## Global Constraints` and the
> spec/design paths.

**Self-check ran:** yes — hits found and fixed (Task 7's fixtures first said "a sound design"; they now give the exact file content. The `<n>`, `<title>`, `<where>`, `<date>`, `<reason>`, `<phase>`, `<base>`, `<slug>` tokens inside quoted text are literal product text the tasks write, not unfilled plan placeholders.)

### Task 1: The `ff-critic` agent

**Files:**
- Create: `agents/ff-critic.md`

**Covers:** AC1
**Interfaces:**
- Consumes: the preamble paragraphs `> **Leaf subagent — return findings directly.** …` and `> **Read budget.** …` from `agents/ff-code-architect.md` lines 9 and 11 (copied verbatim)
- Produces: agent `ff-critic`, with the markers from Global Constraints (read by Task 2's §Critic and Task 7's asserts)

- [x] **Step 1:** Create `agents/ff-critic.md` with exactly this content. Copy lines 9 and 11 of `agents/ff-code-architect.md` verbatim where marked.
  ```markdown
  ---
  name: ff-critic
  description: Critiques a written design or plan against the signed contract and the real codebase before implementation — finds gaps, false premises, unverified load-bearing assumptions and risks. Never edits code or the artifact it reviews; writes only its own report file when the caller names one.
  tools: Glob, Grep, LS, Read, Write, NotebookRead, WebFetch, WebSearch, TodoWrite
  model: opus
  color: red
  ---

  <line 9 of agents/ff-code-architect.md, verbatim>

  <line 11 of agents/ff-code-architect.md, verbatim>

  You are a skeptical principal engineer reviewing a design or a plan **before** any code is written. Your job is to find what will break, what is missing and what is wrong, and to say so plainly — approval, a confident tone or a signed spec is not evidence that the artifact is right. You review; you never edit code or the artifact under review. Your one write is your own report, to the report path the caller names (see **Report format**).

  ## What you are given

  The caller names the artifact under review (`design.md` or `plan.md`) and the **contract** it must satisfy: the signed spec (feature) — plus the design, when the artifact is a plan — or the signed diagnosis (full-tier bugfix), and any explore findings or prior decisions. The contract is fixed: you check the artifact against it; you never ask for a different *what*.

  ## Process

  1. **Model the artifact.** Read it end to end, then note for yourself its goal, its load-bearing assumptions (stated and unstated), the decisions it makes, and any two statements that cannot both hold.
  2. **Check it against the contract.** Every acceptance criterion, constraint, non-goal, touchpoint, success metric and failure scenario: does the artifact meet it, contradict it, or leave it uncovered? For a plan, also: does it build the design that was chosen, in an order its dependency graph allows, with a `Step N: Verify` that would actually catch its failure? For a bugfix plan: is the regression test first, and does it capture RED before the fix?
  3. **Ground its claims in the repo.** Every file, function, command, config key or behaviour the artifact says exists or works a certain way — check it read-only (Grep/Glob, then Read the lines). A premise that is false about the current code is Critical: only you can catch it, because the author believed it.
  4. **Do the arithmetic.** Recompute every number the artifact's conclusions rest on — limits, counts, budgets, orderings, timings — from its own figures.
  5. **Sweep the lenses that fit a code change:** contract fit; assumptions; logic and contradictions; edge cases and failure (empty, duplicate, concurrent, a partial failure halfway, a retry, the dependency that is down); architecture and integration (the reused component — what does it do that the artifact did not think about?); security and data; operations and rollback; testability (could the verify steps actually fail?). Ask: this works in the demo — what breaks in week three?
  6. **An unverified load-bearing assumption is a finding, not a to-do.** If you could not confirm something the artifact depends on, report it at the severity of what happens if it is false, with "verify X; if false, do Y" as the fix.

  ## Severity — calibrate it

  - **Critical** — the artifact, as written, cannot meet an acceptance criterion, a constraint or a failure scenario; contradicts the contract or (for a plan) the chosen design; rests on a false premise about the repo; or holds a contradiction that makes it unbuildable. It must be fixed before implementation.
  - **Important** — it will likely cause rework, an incident or a failed verify, but the artifact can still meet its contract. Fix it, or record why not.
  - Report nothing else. Style, wording, generic hardening ("add monitoring", "add retries") not tied to a specific failure of *this* artifact, and speculative future needs are noise — leave them out. If everything is Critical, nothing is: a sound artifact usually has no Critical at all.

  **Report budget.** Keep the report to about **400 words** — up to about 800 only when the artifact spans several modules. State each finding once: where (`path:line` or the section), the problem, why it matters, the fix. Do not restate the artifact, praise it or tour it section by section.

  ## Report format

  **When the caller names a report path**, write the whole report there with the Write tool — your only write; never create or change any other file — then return just the marker lines and the path. **With no path named**, return the whole report. The caller finds your verdict and findings by these exact lines — do not paraphrase them, and write each as **one physical line — never wrap it**, however long. The report is:

  - first line: `Verdict: ready` (no Critical finding) or `Verdict: revise` (one or more)
  - then one line per finding, Criticals first, each numbered in order:
    `Critical C<n>: <title> — <where> — basis: verified|from the contract|inferred`
    `Important I<n>: <title> — <where> — basis: verified|from the contract|inferred`
  - or, instead of finding lines, the single line `No findings — <why the artifact holds>`
  - then, below the marker lines, each finding's detail — problem, why it matters, fix — within the budget

  **Basis** says how you know: `verified` — you checked it in the repo (cite `path:line`); `from the contract` — it follows from the artifact's or the contract's own text (quote it); `inferred` — a reasoned risk you could not confirm (say what would confirm it).
  ```
- [x] **Step 2: Verify** — **Run:** `grep -E '^tools:' agents/ff-critic.md; grep -c 'one physical line — never wrap it' agents/ff-critic.md; diff <(sed -n 9p agents/ff-code-architect.md) <(sed -n 9p agents/ff-critic.md) && diff <(sed -n 11p agents/ff-code-architect.md) <(sed -n 11p agents/ff-critic.md) && echo preambles-match` **Expected:** the tools line has `Write` and no `Edit`/`Bash`; count `1`; `preambles-match`.

### Task 2: §Critic contract, config key, manifest pointers

**Files:**
- Create: `docs/schema/critic.md`
- Modify: `config/defaults.json`, `docs/manifest-schema.md`, `scripts/checks/lib/schema.sh`

**Covers:** AC2
**Interfaces:**
- Consumes: agent `ff-critic` (Task 1)
- Produces: `docs/schema/critic.md` §Critic, whose subsections are **Dispatch**, **Screen**, **Revise once**, **Re-entry and re-runs**, **Closing line** and **Non-goals** (referenced by Tasks 3 and 4); config key `models.critic`; pointers `artifacts.critic-design` and `artifacts.critic-plan`

- [x] **Step 1:** Create `docs/schema/critic.md` with exactly this content:
  ```markdown
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
  - **A Critical still open after the re-check** → the **Critic stop** (a Mandatory pauses row in §Autopilot): cross-turn in both modes. End the turn naming each open Critical and the report path; `phases.<phase>.status` stays `in_progress`. It clears when the user fixes or redirects and re-runs the phase, or writes `Critic finding accepted by user (<date>): <reason>` under the finding in the report — never self-authored, never written by autopilot. There is no second cycle, in either mode.

  The cycle runs in **both modes** — revising is the phase's own work, not a skipped gate. The report is its durable record (as `review.md`'s `## Resolution` is for review) — **no manifest field**.

  ### Re-entry and re-runs

  - **Re-entry.** A phase re-entered (session drop, `ff-resume`) whose artifact is already written and whose report is on disk — found by the manifest pointer or at `<run dir>/critic-<phase>.md` — never re-dispatches the first critique. Re-run the screen, then continue from the report's state: `## Re-check` present → screen it and apply **Revise once**'s last rule; `## Resolution` without `## Re-check` → the cycle is spent: finish the revision and re-dispatch the re-check once; neither → **Revise once** from the top. Artifact written but no report → dispatch as above.
  - **Re-run.** A confirmed re-run of the phase (**Re-run guard** in `${CLAUDE_PLUGIN_ROOT}/docs/manifest-schema.md`) deletes `<run dir>/critic-<phase>.md` and clears its pointer, so the new artifact gets a fresh critique.

  ### Closing line

  The phase's closing message carries one line, `Critic: <ready | revised | stopped> — <n> Critical, <n> Important (<report path>)`: `ready` — no Critical in the first critique; `revised` — the cycle ran and no Critical remains; `stopped` — the Critic stop. The counts are the first critique's, after the screen.

  ### Non-goals

  No new phase, command, `currentPhase` value or toggle; no waiver line beyond the Critic stop's accept line; no critic fan-out and no second cycle; no numeric scores. `templates/design.md`, `templates/plan.md`, `templates/plan-bugfix.md` and `templates/decision.md` are unchanged — the critique lives only in its own report, located via `manifest.artifacts.critic-<phase>`. On Codex the step follows the Agent Mapping in `skills/feature-flow/references/codex-tools.md`.
  ```
- [x] **Step 2:** In `config/defaults.json`, change the `models` line to:
  `"models": { "explorer": "sonnet", "architect": "sonnet", "reviewer": "sonnet", "diagnostician": "sonnet", "testRunner": "sonnet", "implementer": "sonnet", "escalation": "opus", "critic": "opus" },`
- [x] **Step 3:** Make these edits in `docs/manifest-schema.md`:
  - **Topic index.** After the `| Design trade-offs & devil's advocate |` row, insert:
    `| Critic | \`docs/schema/critic.md\` | The independent critique of the design and the plan: dispatch, screen, the revise-once cycle, the Critic stop. |`
  - **Schema example.** In `"artifacts"`, after `"architect": ".feature-flow/add-oauth/architect.md",`, insert these two lines:
    `    "critic-design": ".feature-flow/add-oauth/critic-design.md",`
    `    "critic-plan": ".feature-flow/add-oauth/critic-plan.md",`
  - **Field notes.** After the `**\`artifacts.architect\`** (added v0.24.0)` bullet, insert:
    ```
    - **`artifacts.critic-design`** / **`artifacts.critic-plan`** (added v0.25.0): the Critic's report
      on `design.md` / `plan.md` (the Critic writes it; the phase checks it and records the pointer) —
      `<base>/<slug>/critic-design.md` / `critic-plan.md`, recorded as that repo-relative path. It also
      holds the revise cycle's `## Resolution` / `## Re-check` record (§Critic in
      `${CLAUDE_PLUGIN_ROOT}/docs/schema/critic.md`). Ephemeral: never promoted. Absent = a phase
      completed before 0.25.0.
    ```
  - **Ephemeral list.** Change `` `architect` (`ff-design`'s architect
    report), `` to `` `architect` (`ff-design`'s architect
    report), `critic-design` and `critic-plan` (the Critic's reports), ``.
  - **Known keys.** Change `models.{explorer,architect,reviewer,diagnostician,testRunner,implementer,escalation}` to `models.{explorer,architect,reviewer,diagnostician,testRunner,implementer,escalation,critic}`.
- [x] **Step 4:** In `scripts/checks/lib/schema.sh` `SCHEMA_LAYOUT`, after the line `Design trade-offs & devil's advocate|design-tradeoffs`, insert the line `Critic|critic`.
- [x] **Step 5: Verify** — **Run:** `jq -r .models.critic config/defaults.json; bash scripts/checks/schema-layout-guard.sh | tail -1` **Expected:** `opus`; `PASS…` (exit 0). The guard's L1 checks the topic header, L3 the index row and L4 the references.

### Task 3: Wire the Critic into `ff-plan` (both tracks)

**Files:**
- Modify: `commands/ff-plan.md`

**Covers:** AC4
**Interfaces:**
- Consumes: `docs/schema/critic.md` §Critic (Task 2); `artifacts.critic-plan`
- Produces: `ff-plan`'s `## Critic — before the plan completes` section (pinned by Task 6)

- [x] **Step 1:** Replace the **Re-run guard** step (step 3 of `## Manifest contract`) with:
  ```
  3. **Re-run guard:** if `phases.plan.status` is already `"complete"`, stop and ask for
     explicit confirmation before overwriting `plan.md` — see **Re-run guard** in
     `${CLAUDE_PLUGIN_ROOT}/docs/manifest-schema.md`. A confirmed re-run also discards the previous
     critique — delete `<run dir>/critic-plan.md` and clear `manifest.artifacts.critic-plan`.
     **Re-entry:** if `phases.plan.status` is `"in_progress"` and `manifest.artifacts.plan` already
     resolves to an existing file, the plan was written before a session drop — skip to
     **Critic — before the plan completes** below; never re-decompose it.
  ```
- [x] **Step 2:** Insert this section directly before `## Update manifest`:
  ```
  ## Critic — before the plan completes

  With `plan.md` written, run the **Critic** step exactly as §Critic in
  `${CLAUDE_PLUGIN_ROOT}/docs/schema/critic.md` specifies (do not restate it here): one `ff-critic`
  on `models.critic`, the plan as the artifact under review, and as its contract the signed spec and
  the design (**feature**, via `artifacts.spec` + `artifacts.design`) or the signed diagnosis
  (**bugfix**, via `artifacts.diagnosis`). Its report path is `<run dir>/critic-plan.md`, recorded in
  `manifest.artifacts.critic-plan`. Screen its findings, revise `plan.md` once if a Critical
  survives — re-deriving the planning-intelligence sections and re-running the No-Placeholders
  self-check when tasks change — and end the turn at the Critic stop if one is still open. The plan
  is not complete until the step is clear.
  ```
- [x] **Step 3:** In `## Update manifest`, replace `Set \`phases.plan = { status: "complete", artifact: "<resolved plan path>" }\`, bump
  \`updatedAt\`.` with:
  ```
  Only once the Critic step is clear, set `phases.plan = { status: "complete", artifact: "<resolved plan path>" }`, bump
  `updatedAt`. The phase's closing message — the autopilot progress strip, or the step-by-step hand-off —
  includes the §Critic **Closing line** (`Critic: <ready | revised | stopped> — …`).
  ```
- [x] **Step 4: Verify** — **Run:** `bash scripts/checks/planning-intelligence-guard.sh | tail -1; bash scripts/checks/assumption-guard.sh | tail -1; bash scripts/checks/schema-layout-guard.sh | tail -1` **Expected:** each prints `PASS…` (exit 0), so the existing `ff-plan` pins still hold. (The dist-parity lines in these guards need `dist/` repackaged. If they fail on parity, run `bash scripts/package-codex-plugin.sh` and re-run.)

### Task 4: Wire the Critic into `ff-design`, plus the re-entry screen fix

**Files:**
- Modify: `commands/ff-design.md`

**Covers:** AC3, AC5, AC6, AC7, AC8, AC10
**Interfaces:**
- Consumes: `docs/schema/critic.md` §Critic (Task 2); `artifacts.critic-design`; Task 3's wording pattern
- Produces: `ff-design`'s `## Critic — before the decision record` section and the reordered write (pinned by Task 6)

- [x] **Step 1:** In the **Re-run guard** step (step 3), change `A confirmed re-run also discards the previous
  architect report — delete \`<run dir>/architect.md\` and clear \`manifest.artifacts.architect\` — so` to
  `A confirmed re-run also discards the previous
  architect report and critique — delete \`<run dir>/architect.md\` and \`<run dir>/critic-design.md\` and clear \`manifest.artifacts.architect\` and \`manifest.artifacts.critic-design\` — so`.
- [x] **Step 2 (AC10 + re-entry):** Replace the whole **Re-entry check** paragraph with:
  ```
  **Re-entry check.** If `manifest.artifacts.design` already resolves to an existing file while
  `phases.design.status` is `"in_progress"`, the pick was made and the design written before a drop:
  skip to **Critic — before the decision record** below. Otherwise, if `manifest.artifacts.architect` resolves to an existing file, or
  `<run dir>/architect.md` exists, read it, re-run **Screen the rejected list** below (idempotent —
  lines already `Dropped (contradicts the spec):` stay as they are), then go to **The choice pause** — never
  re-dispatch for a report that is already on disk. If it already holds a `## Developed on request:`
  section, the choice was made before the drop: skip the pause and resume at the **Do-not-contradict
  STOP** with that appended report — never ask again or re-dispatch a second time.
  ```
  Keep these guard-pinned strings intact: `**Re-entry check.**`, `` or `<run dir>/architect.md` exists ``, `never re-dispatch for a report that is already on disk`, `skip the pause and resume at the **Do-not-contradict`.
- [x] **Step 3:** In `## Write the artifact + update manifest`, change the design paragraph's ending
  `Record the resolved path in **both**
  \`artifacts.design\` and \`phases.design.artifact\`: set \`phases.design = { status: "complete",
  artifact: "<resolved design path>" }\`, bump \`updatedAt\`.` to
  `Record the resolved path in **both**
  \`artifacts.design\` and \`phases.design.artifact\` (\`phases.design.status\` stays \`"in_progress"\`), bump \`updatedAt\`.`
- [x] **Step 4:** Insert this section between the design paragraph and **Then record the decision.**:
  ```
  ## Critic — before the decision record

  With `design.md` written, run the **Critic** step exactly as §Critic in
  `${CLAUDE_PLUGIN_ROOT}/docs/schema/critic.md` specifies (do not restate it here): one `ff-critic`
  on `models.critic`, the design as the artifact under review, and as its contract the signed spec,
  the explore findings and any prior decision the KB recall surfaced. Its report path is
  `<run dir>/critic-design.md`, recorded in `manifest.artifacts.critic-design`. Screen its findings
  — a Critical whose only fix is another approach is asked of the user, never applied — revise
  `design.md` once if a Critical survives (keeping the trade-off matrix and the `FS<n>` list in step
  with the revision; `FS<n>` numbers are never reused), and end the turn at the Critic stop if one
  is still open. The decision record below is written only once the step is clear, so it derives
  from the final design.
  ```
- [x] **Step 5:** Directly after the decision paragraph (which ends `…and what KB capture
  distills at run close.`), insert:
  ```
  Then set `phases.design = { status: "complete", artifact: "<resolved design path>" }`, bump
  `updatedAt`. The phase's closing message — the autopilot progress strip, or the step-by-step
  hand-off — includes the §Critic **Closing line** (`Critic: <ready | revised | stopped> — …`).
  ```
- [x] **Step 6: Verify** — **Run:** `for g in single-architect design-tradeoff decision-record kb schema-layout; do bash scripts/checks/$g-guard.sh | tail -1; done` **Expected:** each prints `PASS…`. Dist-parity lines may fail until Task 8 repackages; if they do, run `bash scripts/package-codex-plugin.sh` and re-run.

### Task 5: Docs — autopilot row, SKILL.md, codex-tools, README

**Files:**
- Modify: `docs/schema/autopilot.md`, `skills/feature-flow/SKILL.md`, `skills/feature-flow/references/codex-tools.md`, `README.md`

**Covers:** AC9
**Interfaces:**
- Consumes: §Critic (Task 2)
- Produces: the autopilot row `| Critic stop (\`ff-design\`, \`ff-plan\`) |` (pinned by Task 6)

- [x] **Step 1:** In `docs/schema/autopilot.md`'s Mandatory pauses table, insert this row directly after the `| Critical review block (\`ff-review\`) |` row:
  `| Critic stop (\`ff-design\`, \`ff-plan\`) | cross-turn | capped — one revise-and-re-check cycle (§Critic, in both modes), then stop if a Critical is still open; end the turn naming each open finding and the report path; the chain resumes when the user fixes or redirects and re-runs the phase, or writes \`Critic finding accepted by user (<date>): <reason>\` in the report — never self-authored — see §Critic in \`\${CLAUDE_PLUGIN_ROOT}/docs/schema/critic.md\` |`
- [x] **Step 2:** Edit `skills/feature-flow/SKILL.md`:
  - **Design description.** Replace `(one architect develops the best design and reports the approaches it rejected, a lean trade-off
  matrix is scored, and stress-test the pick with a
  devil's-advocate pass naming ≥1 failure scenario that *verify* later proves or blocks done on).` with `(one architect develops the best design and reports the approaches it rejected, a lean trade-off
  matrix is scored, and stress-test the pick with a
  devil's-advocate pass naming ≥1 failure scenario that *verify* later proves or blocks done on).
  Before *design* and *plan* complete, an independent **Critic** (\`ff-critic\`) reviews the written
  design and plan against the signed contract and the real code; a Critical finding gets one
  revise-and-re-check cycle, then stops the run.`
  - **Agent list.** Replace `The analysis agents (\`ff-code-explorer\`,
\`ff-code-architect\`, \`ff-code-reviewer\`, \`ff-diagnostician\`) are strictly read-only.` with `The analysis agents \`ff-code-explorer\`,
\`ff-code-reviewer\` and \`ff-diagnostician\` are strictly read-only; \`ff-code-architect\` and \`ff-critic\`
never edit code and write only their own report file when the caller names one.`
- [x] **Step 3:** In `skills/feature-flow/references/codex-tools.md` **Agent Mapping**, after the `ff-code-architect` bullet (two lines), insert:
  ```
  - `ff-critic`: design and plan critique — never edits code or the artifact it
    reviews; writes only its own report when the caller names a report path
    (inline: the orchestrator critiques its own artifact and marks the report `(inline)`)
  ```
- [x] **Step 4:** Edit `README.md`:
  - **Phase table, design row.** Change its middle cell's ending `; you pick` to `; you pick; then an independent **Critic** reviews the written design against the spec (one revise cycle on a Critical)`.
  - **Phase table, plan row.** Change its middle cell's ending `no placeholders` to `no placeholders; an independent **Critic** reviews the written plan against the spec and design (one revise cycle on a Critical)`.
  - **Config table.** After the `| \`models.escalation\` |` row, insert `| \`models.critic\` | \`"opus"\` | Model for the Critic that reviews the written design and plan |`.
  - **Autopilot list, item 3.** After item 3's text, append ` The Critic's Critical findings get the same single cycle in *design* and *plan*.`
- [x] **Step 5: Verify** — **Run:** `grep -c 'Critic stop (`ff-design`, `ff-plan`)' docs/schema/autopilot.md; grep -c 'ff-critic' skills/feature-flow/SKILL.md skills/feature-flow/references/codex-tools.md; grep -c 'models.critic' README.md; bash scripts/checks/schema-layout-guard.sh | tail -1` **Expected:** `1`; each count ≥ 1; `1`; `PASS…`.

### Task 6: `critic-guard.sh`, the AC10 pin, forward-test registration

**Files:**
- Create: `scripts/checks/critic-guard.sh`
- Modify: `scripts/checks/single-architect-guard.sh`, `scripts/checks/forward-test-guard.sh`, `scripts/checks/claude-dist-guard.sh`, `scripts/checks/implement-controller-guard.sh`, `commands/ff-design.md`, `commands/ff-plan.md` (Step 3b — added during implement, see Decisions)

**Covers:** AC9, AC10
**Interfaces:**
- Consumes: the texts written by Tasks 1–5
- Produces: `scripts/checks/critic-guard.sh` (exit 0 = all pins hold)

- [x] **Step 1:** Create `scripts/checks/critic-guard.sh` (mode 755) with exactly this content:
  ```bash
  #!/usr/bin/env bash
  # Regression guard: the Critic inside ff-design and ff-plan (v0.25.0, .feature-flow/critic-plan-design).
  #   AC1  agents/ff-critic.md: leaf, Write but no Edit/Bash, the distilled process, fixed one-line markers.
  #   AC2  models.critic = opus in defaults, Known keys, README; both commands pass it (via §Critic).
  #   AC3  ff-design: Critic after design.md, before decision.md; complete only after the Critic.
  #   AC4  ff-plan: Critic after plan.md, before complete; both tracks' contracts named.
  #   AC5  §Critic: Resolution before the revision, re-check appended with no report path, Critic stop, accept line.
  #   AC6  §Critic screen: Dropped line, contract-is-wrong route, another-approach ask.
  #   AC7  artifacts.critic-design/-plan documented; the Critic: closing line.
  #   AC8  re-entry reuses the report; re-run discards it (both commands).
  #   AC9  autopilot row, SKILL/codex-tools listing, templates untouched, dist parity.
  # Whether the Critic actually catches a seeded defect and stays quiet on a sound artifact is the
  # forward tests evals/forward/critic-design and critic-plan; cost/time is SM1/SM2 (critic-ratio.sh).
  set -u
  cd "$(dirname "$0")/../.." || exit 2
  fail=0
  err() { echo "FAIL: $1"; fail=1; }
  ok()  { echo "ok:   $1"; }
  flat() { tr '\n' ' ' | sed 's/ > / /g' | tr -s '[:space:]' ' '; }
  need() { if flat < "$1" | grep -qF -- "$3"; then ok "$2: $1 has '$3'"; else err "$2: $1 must contain '$3'"; fi; }
  lineno() { grep -nF -- "$2" "$1" | head -1 | cut -d: -f1; }
  before() { # before <file> <label> <first> <second>
    local a b; a=$(lineno "$1" "$3"); b=$(lineno "$1" "$4")
    if [ -n "$a" ] && [ -n "$b" ] && [ "$a" -lt "$b" ]; then ok "$2: '$3' ($a) before '$4' ($b) in $1"
    else err "$2: '$3' must come before '$4' in $1"; fi
  }

  AG="agents/ff-critic.md"; CR="docs/schema/critic.md"; DES="commands/ff-design.md"; PLN="commands/ff-plan.md"
  CORE="docs/manifest-schema.md"; AP="docs/schema/autopilot.md"; SK="skills/feature-flow/SKILL.md"
  CX="skills/feature-flow/references/codex-tools.md"

  # AC1
  [ -f "$AG" ] && ok "AC1: $AG exists" || err "AC1: $AG missing"
  grep -qE '^tools: Glob, Grep, LS, Read, Write, NotebookRead, WebFetch, WebSearch, TodoWrite$' "$AG" \
    && ok "AC1: critic tools line exact" || err "AC1: critic tools line must be exactly Glob, Grep, LS, Read, Write, NotebookRead, WebFetch, WebSearch, TodoWrite"
  grep -E '^tools:' "$AG" | grep -qE '\b(Edit|MultiEdit|Bash)\b' && err "AC1: critic must not have Edit or Bash" || ok "AC1: critic has no Edit or Bash"
  cmp -s <(sed -n 9p agents/ff-code-architect.md) <(sed -n 9p "$AG") && ok "AC1: leaf preamble verbatim" || err "AC1: line 9 must be the architect's leaf preamble"
  cmp -s <(sed -n 11p agents/ff-code-architect.md) <(sed -n 11p "$AG") && ok "AC1: read budget verbatim" || err "AC1: line 11 must be the architect's read budget"
  for p in '**Ground its claims in the repo.**' '**Do the arithmetic.**' \
           '**An unverified load-bearing assumption is a finding, not a to-do.**' \
           'If everything is Critical, nothing is' '**Report budget.**' 'about **400 words**' \
           '**When the caller names a report path**' 'never create or change any other file' \
           'one physical line — never wrap it' '`Verdict: ready`' '`Verdict: revise`' \
           '`Critical C<n>: <title> — <where> — basis: verified|from the contract|inferred`' \
           '`Important I<n>: <title> — <where> — basis: verified|from the contract|inferred`' \
           '`No findings — <why the artifact holds>`' 'you never ask for a different *what*'; do
    need "$AG" AC1 "$p"
  done
  # AC2
  if command -v jq >/dev/null 2>&1; then
    [ "$(jq -r '.models.critic // empty' config/defaults.json)" = opus ] && ok "AC2: models.critic = opus" || err "AC2: config/defaults.json models.critic must be \"opus\""
  else err "AC2: needs jq"; fi
  need "$CORE" AC2 'escalation,critic}'
  need README.md AC2 '| `models.critic` | `"opus"` |'
  need "$CR" AC2 'passing `models.critic`'
  # AC3
  need "$DES" AC3 '## Critic — before the decision record'
  need "$DES" AC3 '§Critic in `${CLAUDE_PLUGIN_ROOT}/docs/schema/critic.md`'
  need "$DES" AC3 '`phases.design.status` stays `"in_progress"`'
  before "$DES" AC3 "## Devil's-advocate pass" '## Critic — before the decision record'
  before "$DES" AC3 '## Critic — before the decision record' '**Then record the decision.**'
  before "$DES" AC3 '**Then record the decision.**' 'Then set `phases.design = { status: "complete"'
  # AC4
  need "$PLN" AC4 '## Critic — before the plan completes'
  need "$PLN" AC4 '§Critic in `${CLAUDE_PLUGIN_ROOT}/docs/schema/critic.md`'
  need "$PLN" AC4 '(**bugfix**, via `artifacts.diagnosis`)'
  need "$PLN" AC4 'Only once the Critic step is clear, set `phases.plan'
  before "$PLN" AC4 '**No Placeholders self-check' '## Critic — before the plan completes'
  before "$PLN" AC4 '## Critic — before the plan completes' '## Update manifest'
  # AC5
  for p in 'dispatch **exactly one** `ff-critic`' '**before** changing anything' 'and **no report path**' \
           'append its return value under `## Re-check` — never overwrite' '**Critic stop**' \
           '`Critic finding accepted by user (<date>): <reason>`' 'never self-authored, never written by autopilot' \
           'There is no second cycle, in either mode' 'The cycle runs in **both modes**' '**no manifest field**' \
           '`**Ruling:** I<n> — <why it stands>`'; do
    need "$CR" AC5 "$p"
  done
  before "$CR" AC5 'append `## Resolution` to the report' '(2) revise the artifact in place'
  # AC6
  for p in '`Dropped (contradicts the spec): <finding> — <the clause it breaks>`' '**The contract is wrong.**' \
           'never edit the signed contract' '**Another approach.**' 'never switch the approach yourself' \
           'route to `/feature-flow:ff-design`' 'The screen is idempotent'; do
    need "$CR" AC6 "$p"
  done
  # AC7
  need "$CORE" AC7 '"critic-design": ".feature-flow/add-oauth/critic-design.md"'
  need "$CORE" AC7 '**`artifacts.critic-design`** / **`artifacts.critic-plan`** (added v0.25.0)'
  need "$CORE" AC7 '`critic-design` and `critic-plan` (the Critic'"'"'s reports)'
  need "$CR" AC7 '`Critic: <ready | revised | stopped> — <n> Critical, <n> Important (<report path>)`'
  need "$DES" AC7 '**Closing line**'
  need "$PLN" AC7 '**Closing line**'
  # AC8
  need "$CR" AC8 'never re-dispatches the first critique'
  need "$CR" AC8 'deletes `<run dir>/critic-<phase>.md` and clears its pointer'
  need "$DES" AC8 'delete `<run dir>/architect.md` and `<run dir>/critic-design.md`'
  need "$DES" AC8 'skip to **Critic — before the decision record** below'
  need "$PLN" AC8 'delete `<run dir>/critic-plan.md` and clear `manifest.artifacts.critic-plan`'
  need "$PLN" AC8 'skip to **Critic — before the plan completes** below'
  # AC9
  need "$AP" AC9 '| Critic stop (`ff-design`, `ff-plan`) | cross-turn |'
  need "$CORE" AC9 '| Critic | `docs/schema/critic.md` |'
  need "$SK" AC9 '`ff-code-architect` and `ff-critic` never edit code and write only their own report file'
  need "$SK" AC9 'an independent **Critic** (`ff-critic`)'
  need "$CX" AC9 '- `ff-critic`: design and plan critique'
  if flat < "$SK" | grep -qF '`ff-code-architect`, `ff-code-reviewer`, `ff-diagnostician`) are strictly read-only'; then
    err "AC9: SKILL.md still lists ff-code-architect as strictly read-only"; else ok "AC9: SKILL.md no longer calls the architect read-only"; fi
  for t in templates/design.md templates/plan.md templates/plan-bugfix.md templates/decision.md; do
    grep -qi 'critic' "$t" && err "AC9: $t must stay unchanged (no Critic section)" || ok "AC9: $t has no Critic section"
  done
  DIST="dist/codex/feature-flow"
  for rel in "$AG" "$CR" "$DES" "$PLN" "$CORE" "$AP" "$SK" "$CX" config/defaults.json README.md; do
    cmp -s "$rel" "$DIST/$rel" && ok "dist parity: $rel" \
      || err "dist parity: $rel differs from or is missing in $DIST/$rel (re-run scripts/package-codex-plugin.sh)"
  done

  if [ "$fail" -eq 0 ]; then echo "PASS: critic guard"; else echo "RED: critic guard failed"; fi
  exit "$fail"
  ```
- [x] **Step 2 (AC10):** In `scripts/checks/single-architect-guard.sh`, after the line `need "$DES" AC4 'skip the pause and resume at the **Do-not-contradict'`, insert:
  ```bash
  need "$DES" AC10 're-run **Screen the rejected list** below (idempotent'
  r=$(lineno "$DES" 're-run **Screen the rejected list** below'); p=$(lineno "$DES" 'then go to **The choice pause**')
  if [ -n "$r" ] && [ -n "$p" ] && [ "$r" -le "$p" ]; then ok "AC10: re-entry screens ($r) before the pause ($p)"
  else err "AC10: the Re-entry check must re-run the screen before going to the choice pause"; fi
  ```
  Also add `#   AC10  (v0.25.0) the Re-entry check re-runs the rejected-list screen before the choice pause.` to the header comment block.
  Then update the AC4 pin that Task 4 Step 1's wording change retires: replace
  `need "$DES" AC4 'delete \`<run dir>/architect.md\` and clear \`manifest.artifacts.architect\`'` with
  `need "$DES" AC4 'delete \`<run dir>/architect.md\` and \`<run dir>/critic-design.md\` and clear \`manifest.artifacts.architect\`'`.
- [x] **Step 3:** In `scripts/checks/forward-test-guard.sh`, append ` critic-design critic-plan` inside the `BEHAVIORS="…"` string (after `architect-decline`).
- [x] **Step 3b (added during implement — existing guards the earlier tasks broke):**
  - `scripts/checks/claude-dist-guard.sh`: in `want_schema`, insert `critic.md ` after `autopilot.md `, and change both `14 topic files` messages to `15 topic files`.
  - `scripts/checks/implement-controller-guard.sh` line 153: change the pin to `'models.{explorer,architect,reviewer,diagnostician,testRunner,implementer,escalation,critic}'`.
  - `commands/ff-design.md` `## Critic — before the decision record`: change `With \`design.md\` written, run` to `With the design written (\`manifest.artifacts.design\`), run`, and change `revise
  \`design.md\` once if a Critical survives` to `revise the design (\`artifacts.design\`) once if a Critical survives`.
  - `commands/ff-plan.md` `## Critic — before the plan completes`: change `With \`plan.md\` written, run` to `With the plan written (\`manifest.artifacts.plan\`), run`, and change `revise \`plan.md\` once if a Critical` to `revise the plan (\`artifacts.plan\`) once if a Critical`.

  These are the pointer forms `durable-paths-guard.sh`'s read-site check requires: a bare `design.md` / `plan.md` in a reader line fails it.
- [x] **Step 4: Verify** — **Run:** `bash scripts/package-codex-plugin.sh >/dev/null && bash scripts/checks/critic-guard.sh | tail -1; bash scripts/checks/single-architect-guard.sh | tail -1; for g in claude-dist durable-paths implement-controller; do bash scripts/checks/$g-guard.sh | tail -1; done` **Expected:** `PASS: critic guard`, `PASS: single-architect guard`, and PASS for the claude-dist, durable-paths and implement-controller guards. `forward-test-guard.sh` stays red until Task 7 adds the arms.

### Task 7: Forward tests — `critic-design`, `critic-plan`, and the budget ratio

**Files:**
- Create: `evals/forward/critic-design/{fired,control}/{sandbox/…,prompt.txt,followup.txt,expected.md,assert.sh}`, `evals/forward/critic-plan/{fired,control}/{sandbox/…,prompt.txt,expected.md,assert.sh}`, `evals/forward/critic-ratio.sh`
- Modify: `evals/forward/README.md`

**Covers:** E2E, SM1, SM2
**Validates:** Assumption 1
**Interfaces:**
- Consumes: `evals/forward/lib.sh` helpers `artifact`, `m`, `section`, `changed_outside_ff`, `ok`, `bad`, `done_`; the `rate-limit` sandbox in `evals/forward/architect-pick/control/sandbox/`
- Produces: behaviors `critic-design` and `critic-plan`; `evals/forward/critic-ratio.sh <new arm dir> <old arm dir>`

- [x] **Step 1 (critic-design/control):** Copy `evals/forward/architect-pick/control/sandbox` to `evals/forward/critic-design/control/sandbox` unchanged. That is the rate-limit spec, with no `architect.md`, so the architect is dispatched as normal and the phase is complete. Write:
  - `prompt.txt`: `/feature-flow:ff-design rate-limit`
  - `followup.txt`: `Go with your recommendation.`
  - `expected.md`: "critic-design / control — a sound design: the architect runs, the user accepts, `design.md` is written, one Critic reviews it and reports `Verdict: ready`; no `## Resolution`; `decision.md` written; design complete; the final message has a `Critic:` line. No source file changed."
  - `assert.sh`:
  ```bash
  #!/usr/bin/env bash
  . "$(dirname "$0")/../../lib.sh"
  S=rate-limit
  C="$(artifact $S critic-design)"; [ -n "$C" ] && [ -f "$C" ] || C="$T/.feature-flow/$S/critic-design.md"
  [ -f "$C" ] && ok "critic-design.md written" || { bad "no critic-design.md"; done_; }
  head -1 "$C" | grep -qE '^Verdict: ready' && ok "Verdict: ready" || bad "first line is not 'Verdict: ready': $(head -1 "$C")"
  grep -qE '^## Resolution' "$C" && bad "a revise cycle ran on a sound design" || ok "no revise cycle"
  [ "$(m $S '.phases.design.status')" = complete ] && ok "design complete" || bad "design not complete: $(m $S '.phases.design.status')"
  D="$(artifact $S decision)"; [ -n "$D" ] && [ -f "$D" ] && ok "decision.md written" || bad "no decision.md"
  result_text | grep -qE 'Critic: (ready|revised)' && ok "closing Critic: line" || bad "no 'Critic: ready|revised' line in the final message"
  [ -z "$(changed_outside_ff)" ] && ok "no source written" || bad "source files changed during design"
  done_
  ```
- [x] **Step 2 (critic-design/fired):** Copy the control sandbox, then add the planted file `.feature-flow/rate-limit/architect.md`. The Re-entry check reuses it, so no architect runs. Its recommendation carries a seeded false premise about the repo: it relies on a helper that does not exist.
  ```markdown
  Recommended: Per-caller counter file guarded by the existing lock helper

  ## Architecture Decision
  Keep one counter file per caller under `.ratelimit/<caller-id>` holding the epoch-second timestamps of recent requests. Reuse the repo's existing lock helper `with_lock` from `src/lib/lock.sh` (already used by `src/api.sh` for its request log) to make the read-prune-append-write sequence atomic across concurrent invocations, so no new locking code is needed.

  ## Component Map
  - `src/api.sh` — source `src/lib/lock.sh`; before `echo "ok"`, call `with_lock ".ratelimit/$caller_id.lock" rate_check "$caller_id"`; print `denied` and exit 0 when it fails.
  - `src/api.sh` `rate_check <caller>` — read the caller's file, drop timestamps older than `RATE_LIMIT_WINDOW_SECS` (default 10), deny when `RATE_LIMIT_MAX` (default 5) remain, else append now and write back.
  - `tests/test.sh` — checks for AC1–AC3.

  ## Data Flow
  `api.sh <caller>` → `with_lock` → `rate_check` (read, prune, count, append) → `ok` | `denied`.

  ## Build Sequence
  Add `rate_check` and wire it through `with_lock`, then the tests.

  ## Critical Details
  Concurrency safety comes entirely from `with_lock`; the window is rolling because old timestamps are pruned on every call.

  ## Patterns Followed
  `src/lib/lock.sh` `with_lock` (existing), `src/api.sh` usage message.

  one obvious approach — a rolling window over separate short-lived processes needs a per-caller file and a lock, and the repo already ships the lock
  ```
  Write:
  - `prompt.txt`: `/feature-flow:ff-design rate-limit`
  - `followup.txt`: `Go with your recommendation.`
  - `expected.md`: "critic-design / fired — the planted `architect.md` rests on `src/lib/lock.sh` `with_lock`, which does not exist (the sandbox has only `src/api.sh`). The spec's concurrency constraint depends on it. Expected: the Critic reports it as a Critical (or, once the orchestrator catches it first, the design no longer relies on it); a `## Resolution` section is recorded; the final `design.md` does not claim `with_lock` already exists; design completes or stops at the Critic stop naming the finding. No source file changed. A fired FAIL where `design.md` still relies on the missing helper is the defect the pipeline lets through."
  - `assert.sh`:
  ```bash
  #!/usr/bin/env bash
  . "$(dirname "$0")/../../lib.sh"
  S=rate-limit
  C="$(artifact $S critic-design)"; [ -n "$C" ] && [ -f "$C" ] || C="$T/.feature-flow/$S/critic-design.md"
  [ -f "$C" ] && ok "critic-design.md written" || { bad "no critic-design.md"; done_; }
  if grep -qE '^Critical C[0-9]+: .*(with_lock|lock\.sh|lock helper)' "$C"; then ok "the Critic flagged the missing lock helper as Critical"
  else bad "no Critical finding names the missing with_lock / src/lib/lock.sh"; fi
  grep -qE '^## Resolution' "$C" && ok "revise cycle recorded (## Resolution)" || bad "no ## Resolution section"
  D="$(artifact $S design)"; [ -n "$D" ] && [ -f "$D" ] || D="$(find "$T" -name design.md -path '*rate-limit*' | head -1)"
  if [ -n "$D" ] && [ -f "$D" ]; then
    if grep -qiE '(existing|already (ships|used|exists)|reuse)[^.]*with_lock|with_lock[^.]*(existing|already)' "$D"; then bad "design.md still relies on an existing with_lock"
    else ok "design.md no longer relies on a pre-existing with_lock"; fi
  else bad "no design.md"; fi
  st="$(m $S '.phases.design.status')"
  if [ "$st" = complete ] || result_text | grep -qi 'Critic stop'; then ok "design completed or stopped at the Critic stop ($st)"; else bad "design neither complete nor at the Critic stop ($st)"; fi
  [ -z "$(changed_outside_ff)" ] && ok "no source written" || bad "source files changed during design"
  done_
  ```
- [x] **Step 3 (critic-plan/control):** Build the sandbox from the control sandbox of Step 1:
  - **Manifest.** `currentPhase: "plan"`, `autopilot: false`, `phases.design = { "status": "complete", "artifact": ".feature-flow/rate-limit/design.md" }`, `artifacts.design = ".feature-flow/rate-limit/design.md"`, `artifacts.decision = ".feature-flow/rate-limit/decision.md"`.
  - **`design.md`** has these sections:
    - `## Chosen approach`: one file per caller under `.ratelimit/<caller-id>` holding request epoch seconds, guarded by `mkdir`-based locking (`mkdir .ratelimit/<caller>.lock` spin-wait up to 2 s, `rmdir` on exit via `trap`), prune older than the window, deny at `RATE_LIMIT_MAX`.
    - `## Rejected alternatives`: `flock` — not on every target (macOS).
    - `## Trade-off matrix`: two rows.
    - `## Component map`: `src/api.sh` modified; `tests/test.sh` modified.
    - `## Data flow`
    - `## Risks`
    - `## Devil's advocate`, with `**FS1:** a crashed process leaves a stale lock dir → every later call waits 2 s then proceeds unlocked` and an `### Edge cases & operational risk` line.
  - **`decision.md`** follows `templates/decision.md`, deriving from that design.
  - `prompt.txt`: `/feature-flow:ff-plan rate-limit`
  - `expected.md`: "critic-plan / control — a sound design; the plan is written, one Critic reviews it: no Critical, no `## Resolution`, plan complete, `Critic:` line in the final message. No source file changed."
  - `assert.sh`: the same as Step 1's, with `critic-design` → `critic-plan`, `phases.design.status` → `phases.plan.status`, the `decision.md` check replaced by `P="$(artifact $S plan)"; [ -n "$P" ] && [ -f "$P" ] && ok "plan.md written" || bad "no plan.md"`, and the messages saying "plan".
- [x] **Step 4 (critic-plan/fired):** Copy the plan control sandbox. Replace `## Chosen approach` in `design.md` with the same approach, except that the lock is "the existing `with_lock` helper in `src/lib/lock.sh`" (which does not exist) and `## Component map` lists `src/lib/lock.sh` as "existing — reused". Update `decision.md` to match. The seeded defect is the same false premise, now inherited by the plan.
  - `prompt.txt`: `/feature-flow:ff-plan rate-limit`
  - `expected.md`: "critic-plan / fired — the plan consumes `with_lock` from a `src/lib/lock.sh` that does not exist. Expected: a Critical naming it and a `## Resolution`. The final `plan.md` either creates the helper in a task (`Produces:` `with_lock`) or no longer consumes it — **or** the run stops routing to `/feature-flow:ff-design` (a design-level fix, §Critic Screen). No source file changed."
  - `assert.sh`:
  ```bash
  #!/usr/bin/env bash
  . "$(dirname "$0")/../../lib.sh"
  S=rate-limit
  C="$(artifact $S critic-plan)"; [ -n "$C" ] && [ -f "$C" ] || C="$T/.feature-flow/$S/critic-plan.md"
  [ -f "$C" ] && ok "critic-plan.md written" || { bad "no critic-plan.md"; done_; }
  if grep -qE '^Critical C[0-9]+: .*(with_lock|lock\.sh|lock helper)' "$C"; then ok "the Critic flagged the missing lock helper as Critical"
  else bad "no Critical finding names the missing with_lock / src/lib/lock.sh"; fi
  P="$(artifact $S plan)"
  if result_text | grep -q 'ff-design'; then ok "routed to ff-design for a design-level fix"
  elif [ -n "$P" ] && [ -f "$P" ] && grep -qE '^## Resolution' "$C"; then
    ok "revise cycle recorded (## Resolution)"
    if grep -qE 'Consumes:.*with_lock' "$P" && ! grep -qE '(Create|Produces:)[^\n]*(src/lib/lock\.sh|with_lock)' "$P"; then bad "plan.md still consumes a with_lock no task creates"
    else ok "plan.md creates the helper or no longer consumes it"; fi
  else bad "neither a revise cycle with plan.md nor a route to ff-design"; fi
  [ -z "$(changed_outside_ff)" ] && ok "no source written" || bad "source files changed during plan"
  done_
  ```
- [x] **Step 5 (budget ratio):** Create `evals/forward/critic-ratio.sh` (mode 755). Copy `evals/forward/single-architect/sm1-ratio.sh`'s `mean` function verbatim, then apply these changes:
  - **Usage** is `critic-ratio.sh <new control arm dir> <old control arm dir>`.
  - **Header comment:**
    ```
    SM1/SM2 (v0.25.0): the control arm's cost and wall time vs the same arm run against v0.24.0 (no
    Critic). Baseline: git worktree add <dir> 488bc5d, then
    FF_FORWARD_PLUGIN_DIR=<dir> scripts/forward-test.sh --repeat 2 --output-dir <out> critic-design critic-plan
    ```
  - **Outputs:**
    - `cost new=$… old=$… ratio=<r> (<= 1.35)`
    - `wall new=…s old=…s delta=<d>s (<= 90)`
    - `PASS` when `r <= 1.35` **and** `d <= 90`, else `FAIL`. Exit 0 only on PASS.
  - **Delta** is computed as `awk -v n="$nw" -v o="$ow" 'BEGIN { printf "%.1f", n - o }'`.
- [x] **Step 6:** In `evals/forward/README.md`'s behaviors table, add two rows:
  - `| \`critic-design\` | \`ff-design\` | the Critic flags a false repo premise as Critical, one revise cycle | \`Verdict: ready\`, no cycle, design complete |`
  - `| \`critic-plan\` | \`ff-plan\` | the Critic flags the plan's false premise as Critical, one revise cycle or a route to ff-design | \`Verdict: ready\`, no cycle, plan complete |`

  Also add one line under the table: "SM1/SM2 (v0.25.0): `evals/forward/critic-ratio.sh` compares each control arm to v0.24.0 (`488bc5d`)."
- [x] **Step 7: Verify** — **Run:** `chmod +x evals/forward/critic-*/*/assert.sh evals/forward/critic-ratio.sh; bash scripts/checks/forward-test-guard.sh | tail -1; for f in evals/forward/critic-*/*/assert.sh evals/forward/critic-ratio.sh; do bash -n "$f" || echo "syntax: $f"; done` **Expected:** `PASS…` and no `syntax:` line. The paid runs themselves are `ff-verify`'s E2E, SM1 and SM2 (and Assumption 1's validation).

### Task 8: Release — version, changelog, dist, full check

**Files:**
- Modify: `.claude-plugin/plugin.json`, `.codex-plugin/plugin.json`, `.claude-plugin/marketplace.json`, `CHANGELOG.md`; regenerate `dist/`

**Covers:** AC9
**Interfaces:**
- Consumes: everything above
- Produces: version `0.25.0`

- [x] **Step 1:** Set `"version": "0.25.0"` in all three version files. Change only the version string.
- [x] **Step 2:** Add a `## [0.25.0] — 2026-09-25 — A Critic inside the design and plan phases` entry at the top of `CHANGELOG.md`, below `# Changelog`. It covers:
  - **Why.** No independent check existed before implement. The devil's-advocate and red-team passes are self-critiques, and the plan had no adversarial pass at all.
  - **The agent.** The new `ff-critic` leaf (Opus via `models.critic`), distilled from the user's `critical-plan-review` process: basis labels, load-bearing assumptions as findings, do the arithmetic, verify against the repo, calibrated Critical/Important, a ~400-word budget, fixed one-line markers, and a report written to `critic-design.md` / `critic-plan.md`.
  - **Where it runs.** After `design.md` is written and before `decision.md`, and after `plan.md` on both tracks. Neither phase completes before the Critic clears.
  - **The screen.** Findings are screened at the orchestrator: out of scope → `Dropped (contradicts the spec): …`; the contract is wrong → clarify or diagnose; another approach → ask the user.
  - **The cycle.** One revise-and-re-check cycle in both modes, recorded as `## Resolution` / `## Re-check` in the report. Then the new **Critic stop**, cleared by a re-run or the user's `Critic finding accepted by user (<date>): <reason>`.
  - **Closing line.** A `Critic:` line in each phase's closing message.
  - **Docs.** The new `docs/schema/critic.md` §Critic; the `artifacts.critic-design` / `critic-plan` pointers (ephemeral); the autopilot Critic stop row.
  - **Also fixed** (v0.24.0 review findings): `ff-design`'s Re-entry check now re-runs the rejected-list screen before the choice pause, and SKILL.md no longer calls `ff-code-architect` read-only.
  - **Measured.** Leave the line `Measured: <filled at verify>`; `ff-verify` fills it from SM1/SM2.
- [x] **Step 3:** Run `bash scripts/package-codex-plugin.sh`.
- [x] **Step 4: Verify** — **Run:** `for g in scripts/checks/*.sh; do bash "$g" >/dev/null 2>&1 && echo "PASS $g" || echo "FAIL $g"; done; bash scripts/eval.sh >/dev/null 2>&1; echo "eval=$?"; bash scripts/checks/version-sync-guard.sh | tail -1` **Expected:** every guard is `PASS` except `integrity-conformance-guard.sh`, which fails for the missing Go toolchain as on every run; `eval=0`; version-sync `PASS…`.

## Dependency graph

| Task | Depends on |
|------|------------|
| Task 1 | — (root) |
| Task 2 | Task 1 |
| Task 3 | Task 1, Task 2 |
| Task 4 | Task 1, Task 2, Task 3 |
| Task 5 | Task 1, Task 2 |
| Task 6 | Task 3, Task 4, Task 5 |
| Task 7 | Task 3, Task 4 |
| Task 8 | Task 6, Task 7 |

## Critical path

**Path:** Task 1 → Task 2 → Task 3 → Task 4 → Task 7 → Task 8

> Derived: chainLength T1=1, T2=2, T3=3, T4=4, T5=3, T6=5, T7=5, T8=6. The sink is Task 8.
> Walking back from Task 8, Task 6 and Task 7 tie on chainLength 5. The tie-break goes to the task
> with the most Steps, which is Task 7 (7 steps, against Task 6's 4). From there the walk goes
> Task 4 → Task 3 → Task 2 → Task 1.

## Risk register

| Risk | Likelihood | Impact | Mitigation |
|------|-----------|--------|-----------|
| An existing guard pins a string the ff-design/ff-plan edits change (re-run guard sentence, write paragraph) | Med | Med | Each command task's Verify runs the guards that pin that command; the edits keep every pinned phrase listed in the task |
| The seeded false premise is caught by the orchestrator before the Critic sees it, so the fired arm cannot tell whether the Critic adds value | Med | Med | The fired assert accepts only a Critic `Critical` line naming the helper; a FAIL for that reason is reported honestly against Assumption 1, not papered over |
| Opus Critic breaks SM1/SM2 (Assumption 2, low) | High | Med | Accepted, not mitigated beyond the report/read budgets and paths-only briefing: SM1/SM2 measure it and the user decides (amend, or `models.critic: sonnet`) |
| Moving `phases.design` completion after `decision.md` breaks a resumed pre-0.25.0 run | Low | Low | A pre-0.25.0 run has `design` complete already (the Re-run guard applies); an in-progress one without a report dispatches the Critic normally (§Critic Re-entry) |
| `forward-test-guard.sh` goes red between Task 6 and Task 7 | High | Low | Accepted: Task 7 closes it; Task 8's full run is the gate |

## Rollback plan

| Task | Recovery action if `Step N: Verify` fails |
|------|--------------------------------------------|
| Task 1 | `rm agents/ff-critic.md` |
| Task 2 | `git checkout -- config/defaults.json docs/manifest-schema.md scripts/checks/lib/schema.sh && rm docs/schema/critic.md` |
| Task 3 | `git checkout -- commands/ff-plan.md` |
| Task 4 | `git checkout -- commands/ff-design.md` |
| Task 5 | `git checkout -- docs/schema/autopilot.md skills/feature-flow/SKILL.md skills/feature-flow/references/codex-tools.md README.md` |
| Task 6 | `rm scripts/checks/critic-guard.sh && git checkout -- scripts/checks/single-architect-guard.sh scripts/checks/forward-test-guard.sh` |
| Task 7 | `rm -r evals/forward/critic-design evals/forward/critic-plan evals/forward/critic-ratio.sh && git checkout -- evals/forward/README.md` |
| Task 8 | `git checkout -- .claude-plugin .codex-plugin CHANGELOG.md && bash scripts/package-codex-plugin.sh` |

## Status conventions

Stateful document. After each task bump its status:
`[ ]` pending · `[~]` in progress · `[x]` done · `[!]` blocked · `[→]` deferred.

**Status:** 8/8 tasks done.

## Blockers

(none yet)

## Decisions made during execution

- **Task 1, fix round 1 (orchestrator finding):** the harness (Claude Code 2.1.282) refused a subagent's
  `Write` of a report file ("Subagents should return findings as text, not write report files").
  `agents/ff-critic.md` §Report format now says: if the Write is refused or fails, return the whole
  report instead — so §Critic's fallback ("write the critique there yourself") always has content.
- **Task 4 (plan defect, found by the implementer):** Task 4 Step 1 rewords the re-run sentence that
  `single-architect-guard.sh` pins literally (`delete \`<run dir>/architect.md\` and clear
  \`manifest.artifacts.architect\``), and no task updated the pin. The implementer reported BLOCKED
  with a question the plan answers (Task 6 already edits that guard), so the controller treated it as
  NEEDS_CONTEXT: Task 6 Step 2 now also updates the AC4 pin, and Task 4's Verify accepts that one
  single-architect line red until Task 6.
- **Task 4, fix round 1 (review Critical C1):** a confirmed re-run hit the new re-entry fast path
  (status is already `in_progress` and the old design pointer still resolved). The Re-run guard now also
  clears `manifest.artifacts.design`. Task 6's AC4 pin text still matches (`… and clear
  \`manifest.artifacts.architect\`` stays a substring).
- **Task 5 sweep (plan defect):** the full guard sweep after Task 5 showed three existing guards broken by
  Tasks 2–4, none in the plan: `claude-dist-guard.sh` pins the 14 schema topic files; `durable-paths-guard.sh`
  forbids bare `design.md`/`plan.md` in command reader prose; `implement-controller-guard.sh` pins the old
  Known-keys models list. Task 6 gained Step 3b to fix all three.
- **Task 6 (plan defect, found by the implementer):** two pins in the planned `critic-guard.sh` were wrong —
  a line-number order check on two steps that share one physical line, and `grep -qi 'critic'` matching
  `## Critical path` in the plan templates. Reported BLOCKED; answered as NEEDS_CONTEXT (the fix is in the
  task's own file): a flat-text order check and a whole-word `critic` match.
