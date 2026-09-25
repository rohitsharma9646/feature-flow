# Changelog

## [0.24.0] — 2026-09-25 — One architect in ff-design instead of a three-way fan-out

`ff-design` fanned out three `ff-code-architect` agents (minimal / clean / pragmatic) to produce
three full designs so the user could pick one. Over the last four full-tier runs the pragmatic
option won every time — three full designs to use one, which the user called "only time waste".
This release drops the fan-out for a single, better-briefed dispatch.

- **One dispatch.** `ff-design` now dispatches exactly **one** `ff-code-architect` (`models.architect`
  stays the architect's model key). It develops the best approach in full and lists the genuinely
  different approaches it rejected, weighing the smallest change, the cleanest structure and the
  codebase's conventions, within a **report budget** (~400 words; the plan phase owns exact steps and
  code), and a last check drops any alternative that loses to the spec itself — `ff-design` screens the list
  again before the choice, rewriting a spec-breaking line as `Dropped (contradicts the spec): …`. `ff-design` briefs it
  with the spec and explore findings only — never suggested approaches. Its report uses fixed markers,
  each one physical line — `Recommended: <name>`, `Rejected: <name> —
  <why> — complexity: low|med|high, risk: low|med|high, test effort: low|med|high`, or, when only one
  approach is sane, `one obvious approach — <why>`.
- **Report saved before the choice.** The architect writes its report to `<run dir>/architect.md`
  itself (it gains the `Write` tool for that one file — still no `Edit` or `Bash`) and returns only
  its markers and a short summary, so the main session never re-emits it; the choice pause points to
  the file. The report is on disk before the choice pause, with its repo-relative path (`<base>/<slug>/architect.md`) recorded in the
  new `manifest.artifacts.architect`. Re-entering the phase reads that file instead of re-dispatching.
  Picking a rejected approach re-dispatches the same architect **once** to develop it in full; the new
  report is appended under `## Developed on request: <name>`, and `design.md` and `decision.md` are
  derived from it.
  The trade-off matrix now scores every approach the architect considered, chosen and rejected alike.
  The devil's-advocate pass, failure scenarios and `decision.md` derivation are unchanged.
- **Removed the `architectAgents` config key.** A project whose `.feature-flow.json` still sets it
  gets the standard unknown-key warning (`config: unknown key 'architectAgents' in .feature-flow.json
  — ignored (did you mean '<nearest>'?)`) rather than any special handling.
- **Guards:** new `scripts/checks/single-architect-guard.sh` (one dispatch, no `architectAgents`, the
  architect's fixed markers, the write-before-pause-before-devil's-advocate order, the re-dispatch +
  append, dist parity). New forward test `evals/forward/single-architect` (fired: a spec with a
  genuine architectural fork; control: a spec with one sane approach) with `sm1-ratio.sh` comparing
  mean cost and wall time against a v0.23.0 baseline (`FF_FORWARD_PLUGIN_DIR` on a worktree of
  `e95c4de`). New two-turn forward tests `architect-pick` and `architect-decline` drive the choice
  pause live.
- **Forward-test harness:** an arm may carry `followup.txt` — the runner resumes the same session
  (`claude -p --resume`) to answer a pause, summing both turns' cost; every run leaves
  `run-<i>.wall` (wall-clock seconds — `duration_ms` under-reports sessions with background
  subagents); `FF_FORWARD_KEEP=1` keeps each run's `.feature-flow/` state as evidence.

**Measured** (`single-architect` fired arm, n = 2 per side, against v0.23.0): session cost **0.88×**
($0.413 vs $0.471) and wall time **~1.9×** (133 s vs 69.5 s) in the final pass — each tightening of the
architect's no-padding rules made it think longer (an earlier pass measured 0.72× / 1.4×). The main
session is ~80% of the phase's cost, so the saving is the architects' share plus the report no longer
being copied out; one architect weighing three lenses alone cannot match three running in parallel on
wall time. SM1 was amended by the user from "≤ 60%" to "mean cost ≤ 90%, wall time recorded, not
gated".

**Unchanged:** Gates A/B and revision binding (0.22.0) — a WP4 merge must still preserve both;
the trade-off matrix, devil's-advocate pass and `decision.md` contracts; the design-choice pause stays
an in-session ask in both modes.

**Known limits:** the design phase is slower in wall time (1.4–1.9× on the forward-test fixture,
+25–65 s) — the price of one architect instead of three in parallel. The picked-rejected-approach
branch of the choice pause is not forward-tested live (the `architect-pick` fixture stopped forking
once alternatives had to satisfy the spec; the same re-dispatch + append is proven by
`architect-decline`). The no-padding rule is prose-enforced
in the agent; the forward tests check it (no `Rejected:` line citing the spec) but the pipeline does
not; design quality itself is not measured,
only that the forward test and structural guard stay green.

## [0.23.0] — 2026-09-24 — ff-implement as a per-task controller, with executable plans

Implement was the last phase that did all its work inline: one agent wrote every task in one
context (332–426 tool calls and ~5 compactions per session in the July review, F11), no task was
checked until the final review, and a compaction mid-implement left nothing finer than "implement is
in progress" to resume from. This release adopts Superpowers' subagent-driven development inside
Feature Flow's gates (recommendations #1 and #2 of the 2026-09-24 comparison, and #4 in part).

- **Task controller** (`docs/schema/task-controller.md`, new topic). On a **full-tier** run whose plan
  has `## Global Constraints`, `ff-implement` works one task at a time: it writes a brief holding
  only that task (plus the global constraints and the spec/design paths), dispatches a fresh
  **`ff-implementer`** subagent (`models.implementer`), fingerprints the working tree before and after,
  and has one `ff-code-reviewer` check that task's diff — handed over as a file, never pasted — for
  conformance (the task's ACs, its interfaces, the constraints, no out-of-scope files) and quality.
  Lite runs and plans written before 0.23.0 implement inline exactly as before, and say so.
- **Fix loop per task:** up to three rounds — two resuming the same implementer, one fresh implementer
  on **`models.escalation`** (default `opus`) — each ending in a scoped re-review
  (`ADDRESSED` / `NOT ADDRESSED`). An open Critical after the third round stops the phase; open
  Important findings become recorded **rulings** (`decision — why — cost if wrong`), listed at the end
  and shown to `ff-review`'s reviewers.
- **Status contract:** the implementer returns `DONE`, `DONE_WITH_CONCERNS`, `NEEDS_CONTEXT` (answered
  from the spec/design, at most twice) or `BLOCKED`, with a ≤ 15-line summary; detail goes to a report
  file. With `toggles.tdd` on, every code task records its RED run before the implementation and its
  GREEN run after — per-task test-first evidence on the feature track for the first time.
- **Task ledger** (`<run dir>/tasks/ledger.md`, via the new `manifest.artifacts.ledger`): base/head
  fingerprints, statuses, review verdicts, fix rounds, rulings and TDD lines per task, rewritten before
  every dispatch. A new session, a compaction or `ff-resume` continues at the first incomplete task
  and fix round; `ff-status` and the SessionStart re-anchor name the current task.
- **Three new stops** (`docs/schema/autopilot.md`): Plan placeholder (pre-flight), Task blocked, and
  Critical-after-cap — none of them "unconditional"; the caps live in the ledger, not the manifest.
- **Executable plans:** `templates/plan.md` / `plan-bugfix.md` gain `## Global Constraints`,
  per-task `**Interfaces:**` (`Consumes:` / `Produces:`), complete test code in every test step,
  implementation steps that name the exact change, `**Run:**` / `**Expected:**` lines, and a
  **No Placeholders** list that `ff-plan` self-checks before completing and `ff-implement` re-checks
  before its first dispatch.
- **`hooks/lib/task.sh`** (new): `task_section` extracts one plan section, fence-aware (a heading-shaped
  line inside a code block never cuts a brief); `task_diff` packages a tree-to-tree diff without
  touching the index. Reproduced byte-for-byte in §Task packaging for Codex.
- **`ff-review`** now hands its reviewers the diff as a file, built from HEAD's tree to the current
  fingerprint — so new untracked files are included, which `git diff HEAD` missed. Both sides leave
  out Feature Flow's bookkeeping: `hooks/lib/revision.sh` gains `revision_head_tree` (CLI:
  `revision.sh <dir> head`), HEAD's tree minus the same paths — the raw HEAD tree would show every
  committed run record as deleted. The fingerprint and Gate B are unchanged; the verbatim block in
  `enforcement.md` §Revision fingerprint is updated to match.
- **Codex:** no subagents needed — the same loop runs inline with the same files and role boundaries
  (`codex-tools.md`); only the fresh context per task is lost.
- **Guards:** new `implement-controller-guard.sh` (132 checks, incl. the §Task packaging byte identity
  with a one-character-drift self-test); a `task-controller` eval fixture (fence-aware extraction,
  tree diffs, index untouched); `session-start-guard.sh` S11 (ledger re-anchor); a new forward test
  `evals/forward/implement-controller` (fired: controller + a seeded review finding; control: a plan
  without Global Constraints stays inline) with `sm1-ratio.sh` for the context measurement.

**Measured while building it:** a completed subagent resumed by `SendMessage` keeps its context (the
fix loop's resume rounds rely on this). Full code in every plan step made a task ~10× longer
(23 → 242 lines); the adopted rule — complete test code and interfaces, implementation steps naming
the exact change — is ~6× (130 lines) with briefs of ~140 lines. **Controller cost on a small plan
(the forward test: 3 tasks, one-line scripts each):** the controller's own session used 1.5–1.9× the
main-session input tokens of an inline session on the same plan (480k vs 329k, 488k vs 257k — mostly
cache reads) and ~4× the money ($1.37–1.40 vs $0.35–0.38 per session, subagents included). The
spec's success metric — controller context ≤ 60% of inline — was **not met** and was waived; the
context saving is expected on large plans, where inline sessions accumulate hundreds of tool calls,
but that is not measured yet.

**Unchanged:** Gates A/B and revision binding (0.22.0) — a WP4 merge must still preserve both;
the never-commit rule (no task commits; diffs come from fingerprints); lite tiers.

**Known limits:** the implementer's "never touch the git index or history" rule is prose-enforced (its
reviewer catches out-of-scope edits one step later); on small plans the controller costs more than
inline — in context and in money (measured above), and there is no size threshold yet; the loop firing
(a subagent per task, a fix round on a real finding) is proven by the forward test, not by CI, and the
placeholder stop, `NEEDS_CONTEXT` / `BLOCKED`, fix rounds 2–3 with escalation, the Critical-after-cap
stop, an escalated bugfix under the controller and the escalation fallback have not fired in a live
session yet.

## [0.22.0] — 2026-09-24 — Review and verify bound to the same code revision

Closes F01 (rated Critical) from `docs/feature-flow-architectural-review-2026-07-23.md`: a run
could reach `done` on code that was never both reviewed **and** verified. On the feature track
review runs before verify, and verify's autopilot repair — or any edit in between — changed code
after review had passed; on the bugfix track review's fix cycle could change code after verify.
Recording `git HEAD` would not have helped: Feature Flow never commits during a run, so HEAD does
not move while the working tree does.

- **Working-tree fingerprint** — `hooks/lib/revision.sh`: a git tree id over the whole git top
  level (tracked files as they are, plus untracked non-ignored files), minus `paths.base`,
  `paths.durable`, `paths.kb` and nested repositories. Built in a throwaway index: the real index,
  working tree and history are never touched; nothing is staged or committed. Same tree → same id;
  any code change → new id; revert → old id. `docs/schema/enforcement.md` §Revision fingerprint
  carries the file verbatim so Codex (which ships no `hooks/`) runs byte-identical text.
- **Manifest:** `revisionBound: true` at creation (`ff`, and the cold-start paths of `ff-explore` /
  `ff-clarify` / `ff-diagnose`); `phases.review.revision` / `phases.verify.revision` stamped when the
  phase completes, after any fix or repair cycle. Absent `revisionBound` = a pre-0.22.0 run: nothing
  is stamped or checked. No migration.
- **Revision agreement** (`docs/schema/terminal-convergence.md`): the done-transition compares the
  other phase's stamp to its own. Stale → the new **Stale-phase re-run cycle**
  (`docs/schema/autopilot.md`): autopilot re-runs the stale phase once — review with its focus and
  spec-conformance reviewers, verify with a full `ff-test-runner` dispatch — capped by a durable
  `## Stale re-run` section in that phase's artifact, exactly like `## Resolution` / `## Repair`;
  step-by-step stops and names the phase and the changed files.
- **Gate B** (`hooks/enforce-gate`, Claude Code): on a revision-bound `done` write the hook
  recomputes the fingerprint and denies unless both stamps equal it — `<phase> revision not
  recorded` or `<phase> revision is stale`, with up to 10 changed paths (`(+N more)`, or `changed
  paths unavailable` if the stamped tree object was pruned — still a deny). Skipped silently for
  pre-0.22.0 runs and outside git; allowed **loudly** (a `systemMessage`) when a `.git` exists but
  the fingerprint cannot be computed. Stamped ids are validated as hex before reaching git.
- **WP4 constraint:** the unmerged `feature/p0-integrity-wp4` branch replaces `hooks/enforce-gate`
  with an observe-only launcher for the Go kernel. Any WP4 merge must preserve Gates A/B including
  revision binding, or supersede them with the kernel's enforce mode — never regress to observe-only.
- **Guards:** `enforce-gate-guard.sh` gains 37 cases against real temporary git repositories (the
  fingerprint's inclusions and exclusions, a subdirectory project, every `paths.*` form, the real
  index left byte-identical, every Gate B allow/deny/warn path, one case through `run-hook.cmd`);
  new `revision-binding-guard.sh` pins the wiring, the byte identity of the documented recipe (with
  a one-character-drift self-test) and the lib's defaults against `config/defaults.json`.

**Measured** (synthetic repo, 22,000 tracked files, 5 modified + 5 untracked): the fingerprint takes
0.06–0.08 s steady state and 0.17–0.25 s when every file's stat info is stale; a `done` write through
the hook takes 0.02–0.03 s without the check and 0.10–0.51 s with it. Running this repo's full guard
and eval suite leaves no untracked files, so verify's own commands do not move the fingerprint here.

**Known limits:** a manifest rewritten through `Bash` is still outside the hook (prose-gated, as
before); Codex follows the rule as prose only; build or test output that is not gitignored counts as
code, so it makes review look stale once (the deny reason lists the paths — ignore them in
`.gitignore`). The Stale-phase re-run cycle firing once and then stopping is a behavioural claim not
covered by CI — it needs a fresh-session self-run, like the other autopilot cycles.

## [0.21.0] — 2026-09-24 — Manifest contract split into a core + topic files

From Claude Code's best-practices guide ("keep context lean"). Every phase re-reads the manifest
contract, and with v0.20.0's fresh-context hand-offs it does so once per phase. The contract was
one ~93 KB file; a phase used a fraction of it.

- **`docs/manifest-schema.md` is now the core** — Schema, Field notes, Config resolution &
  validation, Run resolution, Rules every command MUST follow, Manifest write safety, Re-run guard,
  Progress strip — plus a new **Topic index**. The other 13 topics moved **verbatim** to
  `docs/schema/<topic>.md` (evidence, enforcement, disk-inference, sign-off-rendering,
  terminal-convergence, knowledge-base, planning-intelligence, assumption-records,
  design-tradeoffs, discovery-fields, autopilot, delivery, retrospective). No rule text changed:
  the core and topic files rejoin byte-identically to the old file.
- **References point at the topic's file** (`see **Autopilot** in …/docs/schema/autopilot.md`);
  SKILL.md states the reading rule — the core plus only the topic files the command names.
  `§Name` cross-references inside the rules resolve through the Topic index.
- **Guards:** the schema-reading guards read the joined contract (`scripts/checks/lib/schema.sh`),
  so every assertion is unchanged. New `schema-layout-guard.sh` pins the layout, the core's
  contents, the index, **reference integrity** (every `**Name** in …/docs/<file>.md` and
  `…/docs/<file>.md §Name` must point at a file that defines Name — new protection against a
  moved or renamed topic) and dist parity.
- **Packaging:** the Claude, Codex and integrity packages ship `docs/schema/`.

Schema bytes each command must read — the core plus every topic it names, by path or by
`§Name`/`**Name**` (an upper bound; a topic file's own `§` cross-references may lead further).
Every other command reads 43–76% less; **ff-verify** touches seven topics, so it saves only 24%, and
**ff-clarify** 39%:

| Command | Before (bytes) | After (bytes) | Topic files it names | Reduction |
|---|---|---|---|---|
| ff-abandon | 93,586 | 21,850 | — | 76% |
| ff-clarify | 93,586 | 56,179 | assumption-records, autopilot, discovery-fields, planning-intelligence, sign-off-rendering | 39% |
| ff-close | 93,586 | 21,850 | — | 76% |
| ff-deliver | 93,586 | 36,670 | autopilot, delivery, terminal-convergence | 60% |
| ff-design | 93,586 | 48,066 | autopilot, design-tradeoffs, knowledge-base | 48% |
| ff-diagnose | 93,586 | 53,129 | assumption-records, autopilot, knowledge-base, sign-off-rendering | 43% |
| ff-explore | 93,586 | 42,611 | autopilot, knowledge-base | 54% |
| ff-implement | 93,586 | 48,503 | autopilot, knowledge-base, planning-intelligence | 48% |
| ff-list | 93,586 | 21,850 | — | 76% |
| ff-plan | 93,586 | 53,084 | assumption-records, autopilot, discovery-fields, planning-intelligence | 43% |
| ff-resume | 93,586 | 33,889 | autopilot, disk-inference | 63% |
| ff-retro | 93,586 | 38,248 | autopilot, retrospective | 59% |
| ff-review | 93,586 | 44,337 | autopilot, knowledge-base, terminal-convergence | 52% |
| ff-status | 93,586 | 24,203 | disk-inference | 74% |
| ff-verify | 93,586 | 70,648 | autopilot, design-tradeoffs, discovery-fields, evidence, knowledge-base, planning-intelligence, terminal-convergence | 24% |
| ff | 93,586 | 31,536 | autopilot | 66% |

## [0.20.0] — 2026-09-23 — Fresh-context hand-offs, clarify interview, touchpoints + end-to-end check

Two more changes from Claude Code's best-practices guide: "a clean session with a better prompt
beats a long one", and "have Claude interview you, then write a self-contained spec that ends with
an end-to-end verification step".

**Fresh-context hint at step-by-step hand-offs.** §Progress strip gains one rule. When a phase
completes in step-by-step mode and hands off to the next command, the message adds
``Fresh context: `/clear`, then `/feature-flow:ff-<next>` — the run's state is on disk.`` Every
phase already ends its hand-off through §Progress strip, so the one rule reaches all of them. The
hint never appears in autopilot, at a sign-off / decision / blocking pause, or on a `done` report.
After `/clear`, v0.19.0's SessionStart re-anchor re-lists the run.

**Clarify interviews with AskUserQuestion in both modes.** Closed-choice questions now use
AskUserQuestion in step-by-step mode too (it was autopilot-only): picking a solution option,
confirming an edge-case behaviour, keeping an assumption. That means one decision per question,
the recommendation first, and independent questions batched. Open-ended probes (the premise
"why") stay plain text so a menu doesn't lead the answer.

**Spec gains `## Touchpoints` and `## End-to-end check` (both tiers).**
- *Touchpoints* lists the concrete files / interfaces the change should touch, from `explore.md`.
  The spec-conformance reviewer now uses it as its scope reference.
- *End-to-end check* is one binary check that proves the whole feature works as a user would use
  it. `ff-verify` maps it into an `### E2E` contract item exactly like an acceptance criterion:
  same Confidence ladder, same evidence-gap stop and waiver, and it's proven by actually running
  the stated command or flow. Both sections are presence-gated, so older specs are unaffected.
  Contract: §Discovery fields → Touchpoints / End-to-end check / Actuation 3.
- `ff-verify` passes the E2E row to `ff-test-runner`, which runs it as stated under its true kind.
  That includes lite, the one exception to lite's floor-only rule. Without this, E2E would
  routinely sit at Unverified.
- Work with no user-facing flow writes `E2E: none — <reason>`, which verify treats as absent.
- A captured E2E **failure** is a repair-cycle trigger, like an AC. `SM<n>` is now stated as not
  being one, which is what the old wording already implied.
- `E2E` joins the retro's closed signal list of unproven contract items.

**Fix:** the v0.19.0 spec-conformance reviewer was told to read the spec's `## Out of scope`
section. The template calls it `## Non-goals`, so it now reads `## Non-goals` (plus
`## Touchpoints`).

New structural guard: `scripts/checks/fresh-context-interview-guard.sh`. Whether the model
actually emits the hint, asks via the picker, and proves the E2E check on a live run is behavioral
and not covered in CI.

## [0.19.0] — 2026-09-23 — Edit-proof gates, session re-anchor, spec-conformance review

Three changes taken from Claude Code's best-practices guide ("hooks are deterministic", "the
context window is the resource to manage", "review the diff against the plan in a fresh
context").

**Gates now cover Edit and MultiEdit.** `hooks/hooks.json` matched only `Write`, so an `Edit` to
`manifest.json` that flipped `currentPhase` to `done`, or entered `implement` unsigned, skipped
both gates. The matcher is now `Write|Edit|MultiEdit`. For an edit, `enforce-gate` rebuilds the
manifest the edit would produce by applying each replacement in order to the on-disk file
(literal match, first occurrence unless `replace_all`), then runs the unchanged Gate A/B logic
on the result. An Edit with an empty `old_string` on a missing or empty file is the tool's
create form, so it is gated like a Write of `new_string`. The hook fails open only on edits
Claude Code itself rejects: a non-empty `old_string` that isn't found, or an empty one on a
non-empty file. Rewrites through `Bash` are still outside the hook, and that is now documented
as a known limit in §Enforcement. `enforce-gate-guard.sh` gains 16 cases, including a
`replace_all` pair (same edit, different outcome), the create form, and a check that the matcher
routes every tool.

**SessionStart re-anchors active runs.** The hook already fired on `startup|clear|compact` but
only printed a static pointer. It now adds up to 3 active runs, newest first: slug, track/tier,
phase + status, autopilot, sign-off, `/feature-flow:ff-resume <slug>`, and resolved artifact
paths. It honors `paths.base` and leaves out done / abandoned / closed runs. After `compact` it
tells the model it was mid-run and must re-read state from disk. After `startup`/`clear` the
wording is conditional. Everything is best-effort: without jq, a cwd, or a parseable manifest
it emits exactly what it did before. The envelope is now JSON-escaped by jq, so control
characters in a hand-edited manifest can't break it. Contract: §Enforcement → Session re-anchor. New
behavioral test: `scripts/checks/session-start-guard.sh`.

**Spec-conformance reviewer + over-engineering guard.** `ff-review`'s focus reviewers
(simplicity / bugs / conventions) never checked the diff against what the run promised. One
extra `ff-code-reviewer` now runs **in addition to** `reviewerAgents` and gets the diff plus
the contract via manifest pointers (spec + plan on feature, diagnosis + plan on bugfix):
- an unimplemented or partial criterion is **Critical**;
- an out-of-scope change or a plan task with no change is **Important**;
- no contract → it is skipped, with a note in `review.md`.

`templates/review.md` gains a `## Spec conformance` table. Every reviewer, including this one,
now reports only gaps that affect correctness or the stated requirements. Style and speculative
hardening are never Critical, so autopilot's one fix cycle can't turn reviewer nitpicks into new
code. New structural guard: `scripts/checks/spec-conformance-guard.sh`. Whether the reviewer
actually *catches* a missing criterion on a live run is behavioral. That is not covered in CI and
is a candidate forward-test case.

## [0.18.0] — 2026-09-23 — Retrospective (`ff-retro`) + forward-testing of semantic behaviors

Two additions that close feature-flow's own feedback loop.

**`/feature-flow:ff-retro` — optional, post-`done`, confirm-gated retrospective.** Classifies what
the **workflow's own safeguards** did on a finished run and routes each lesson to one owner. It scans
a closed list of on-disk signals (user override/waiver lines, review `## Resolution`, verify
`## Repair`, contract items below `Verified (single-source)`, Critical findings, `⚠ DELIVERY GAP:`
lines) plus the user's notes, keeps only events that pass a **materiality test**, and proposes
candidates with nine fields: event, expected, observed evidence, impact, safeguard, **safeguard
result** (`worked | failed | missing | ambiguous | bypassed`), generalizability, **recommended owner**
(repo instructions · run artifacts · feature-flow command/skill · reference doc · guard/validator
script · regression/forward test · new skill · no change), and proposed validation. **Nothing is
written until the user accepts, edits, or rejects each candidate** (the KB capture confirm-gate
shape). Then `retro.md` is written; it's durable-eligible, tracked in `phases.retro`/`artifacts.retro`
(absent-defaulted), and `currentPhase` stays `done`. It never applies a fix, never writes KB entries,
and autopilot never runs it. Runs on lite and bugfix too. Contract: `docs/manifest-schema.md`
§Retrospective. `ff-verify`/`ff-review` completion now names `ff-deliver` and `ff-retro` as optional
next steps. A finding routed to **regression/forward test** states its validation as **Fired input /
Expected outcome / Control input**, which converts 1:1 into a forward-test case.

**Forward tests — `scripts/forward-test.sh` + `evals/forward/`.** The 7 behavioral catches that CI
only checked structurally (do-not-contradict STOP, critical-path STOP, `⚠ DELIVERY GAP`,
unvalidated-assumption echo, unproven `FS<n>`, one-cycle repair, unproven `SM<n>`) now each have a
committed **fired** and **control** case. The runner plays each one in a **fresh headless
`claude -p --plugin-dir <repo>` session** against a planted sandbox, which is the only way to prove
an edited command actually fires. It then asserts on the behavior's own on-disk/output marker.
ERROR (timeout, CLI failure, budget cap, crashed assertion) is never PASS; with `--repeat N` a flaky
arm is FAIL. Per-session budget cap, per-arm and total cost, and transcripts go to
`.feature-flow/forward-test-runs/`. **Local only — not CI** (needs Claude credentials and costs
tokens; the full suite is about $4). `scripts/checks/forward-test-guard.sh` pins the case structure
in CI; `evals/` is not shipped in the Codex dist.

**Known coverage limits (named, not silent):**
- `discovery-gap` covers WS-7's `SM<n>` half only. The requirement-graph Outcome-gate gap in `ff-plan`
  is still manual, and so is `ff-plan`'s critical-path *derivation* (the `ff-implement` STOP is covered).
- **Mutation check:** stripping the `⚠ DELIVERY GAP` cross-check from a scratch copy of the plugin
  makes `delivery-gap/fired` FAIL, so the harness catches a hollowed behavior. Stripping the
  do-not-contradict STOP from every file did **not** make `decision-conflict/fired` FAIL: the model
  still refuses from the sandbox's explicit decision record. That case proves the behavior, not that
  the instruction causes it.
- Forward tests must be re-run by hand after editing a behavior's instruction text; CI won't do it.

**Runtime-only install (`#dist`).** Claude Code copies a plugin's whole directory (no ignore
mechanism) and clones the marketplace repo, so installs used to carry the entire dev repo — Go
sources, eval fixtures, CI scripts, run history. Now `scripts/package-claude-plugin.sh` builds an
allowlisted runtime tree (commands, agents, skills, hooks, templates, config, the two reference docs,
README, LICENSE, and a marketplace.json serving it from `./`), and a new `publish-dist` CI job (push to
`master` only, after guards pass, `contents: write` on that job alone) publishes it to the **`dist`
branch** with `scripts/publish-claude-dist.sh`. Install with
`claude plugin marketplace add rohitsharma9646/feature-flow#dist`; master's `marketplace.json` now
sources the plugin from `dist` over HTTPS, so existing installs get a clean plugin cache on update
(re-add the marketplace once to clean its local clone). `scripts/checks/claude-dist-guard.sh` pins the
exact allowlist, forbids dev-only files, and checks every `${CLAUDE_PLUGIN_ROOT}` reference resolves
inside the package. The native `ff-integrity` binary stays CI-package-only. The packager refuses `/`,
`$HOME`, the repo or an ancestor of it, and any non-empty non-package directory as `--output`.

Also: `scripts/eval.sh`'s header now says it is a blocking gate (it has been since v2.3).

## [0.17.1] — 2026-09-23 — Prompt-surface audit cleanup

Prompt-only patch from a dated-pattern audit of the agent, command, and skill text. No manifest,
schema, config, hook, or template change.

- **`ff-code-reviewer` scope contract fixed.** The agent defaulted to "review unstaged changes from
  `git diff`" but has no shell, so it could not run git. It now reviews exactly the diff or file list
  it is given, and `ff-review` runs `git diff HEAD` itself and passes the output (or the touched file
  list on greenfield).
- **Read-budget rationale updated** in the four read-only agents. The rule is unchanged; its reason no
  longer cites context-window compaction (written for a 200K-context Sonnet) and instead names phase
  latency.
- **`ff-code-explorer` scoped to its dispatched focus.** The generic four-stage trace checklist is
  replaced by a focus-scoped goal so the three differentiated explorers stop each doing an end-to-end
  tour. The output contract, including the essential-files list `ff-explore` reads, is kept.
- **Development-history labels removed from prompts:** `(AC4)`/`(AC12)`/`(AC13)` (easily confused with a
  run's own `AC<n>`), `pre-WS-N`, `pre-v0.x`, `Since v0.x`, and relative phrasing such as "exactly as
  today (byte-identical behavior)". The SKILL.md KB non-goals are restated as current rules (still
  naming dedup and supersession).
- **Codex mapping** gains the missing `/feature-flow:ff-deliver` row.

## [0.17.0] — 2026-07-06 — Discovery field completeness (WS-7)

`spec.md` gains two **optional, full-tier, actuating** discovery fields — closing the RFC's named
discovery gaps without letting either become a field only a human reads (guardrail #9). **Success
metrics** are binary-threshold rows ("metric M ≤/≥ T, measured by `<method>`", reusing the
acceptance-criterion discipline — a metric that can't be phrased as a checkable threshold is rejected
at clarify). Each becomes its own `### SM<n>` block in `ff-verify`'s contract mapping — mapped
**exactly as an acceptance criterion** (same Confidence ladder, same waivable Evidence-gap stop), so
an unproven metric holds the run at the existing stop and blocks `done`. A **requirement graph** is an
`| AC | Depends on |` table reusing §Planning intelligence's dependency notation (lower-numbered
invariant, cycle unexpressible); `ff-plan` derives task-dependency edges from it via the `**Covers:**`
map by **ordering tasks to satisfy the edges as it decomposes** (never a backward renumber pass), and
an edge that no numbering can represent — the same task covers both ACs — surfaces as an explicit
named gap under the plan's Outcome gate, never silently dropped. `ff-clarify` prompts for both only on
**non-trivial full-tier** work; a **lite** spec omits both with no placeholder and no warning
(presence-gated on the section's rows, never a `tier` read — the `spec.md` template is shared by both
tiers, unlike the design-only `FS<n>`). Metrics are verify-time items, **not** part of the sign-off
render — §Sign-off rendering stays "Three rules". `## Stakeholders` was **cut** (no downstream
consumer). Additive and non-breaking: **no new `manifest.json` field, no `toggles.*` key, no new
phase, no new hook, no new §Autopilot row, no new waiver line** — both fields ride `manifest.artifacts.spec`,
and a pre-WS-7 spec resolves/resumes unchanged. Full tier only; `lite-tier-guard.sh` passes unmodified.

**Known coverage gap (named, not silent)** *(v0.18.0: the `SM<n>` catch (AC6) is now covered by the local forward-test runner `scripts/forward-test.sh`; the requirement-graph Outcome-gate gap (AC8) is still manual — still not CI; see [0.18.0])*: the two *behavioral* catches have **no automated
regression guard** — verified by a fresh-session fired-vs-control self-run (same posture as WS-1 AC13
/ WS-2 AC15 / WS-4 AC6-AC7 / WS-5 AC7-AC8 / WS-6 AC13-AC14):
- **AC6 (fired arm):** a full-tier run whose spec carries an **unproven** `## Success metrics` row →
  `ff-verify` emits a `### SM<n>` block below `Verified` and holds the run at the Evidence-gap stop
  (blocks `done`, waivable); a proven metric does not false-fire.
- **AC8 (fired arm):** a spec whose `## Requirement graph` edge is un-derivable (the same task covers
  both ACs) → `ff-plan` surfaces the Outcome-gate gap rather than writing an invalid graph; a
  satisfiable graph does not spuriously gap.

`discovery-fields-guard.sh` and the `discovery-gap` eval fixture pin only the mechanical
structure/wiring. The eval harness is now **7 fixtures, all green** (still non-blocking in CI).

### Added
- **`## Discovery fields` canonical section** (`docs/manifest-schema.md`) — Success metrics /
  Requirement graph field definitions, Actuation 1 (SM<n> → ff-verify, presence-not-tier gating,
  reuses the Evidence-gap stop) / Actuation 2 (requirement graph → ff-plan task edges,
  order-at-decomposition, Outcome-gate gap for un-derivable edges), Tier/track scope, v1 non-goals.
  Plus the §Evidence Confidence-ladder **fourth** contract-item class (success metric).
- **`## Success metrics` + `## Requirement graph`** (`templates/spec.md`) — optional, full-tier-only
  banners; binary-threshold discipline (cross-referencing, not diverging from, the AC discipline) and
  the `| AC | Depends on |` notation reused from §Planning intelligence.
- **`### SM1:` contract-mapping block** (`templates/verify.md`) — digit-free placeholders mirroring
  `### FS1:`; Gate-B safety proven by `enforce-gate-guard.sh`'s `b-template` fixture (not re-derived).
- **`scripts/checks/discovery-fields-guard.sh`** — structural guard: the two spec headers + banners +
  no-Stakeholders, the binary-threshold + reuse cross-references, the clarify/verify/plan wiring (with
  `lineno` placement of the ff-plan bullet), the SM1 template block, the plan Outcome-gate gap rule,
  the schema section + subsections + ladder class, the negative no-new-field / no-new-config-key /
  no-new-Autopilot-row checks, and per-file dist parity. mawk-portable.
- **`evals/fixtures/discovery-gap/`** (`spec.md` with a labeled SM row + an `AC2→AC1` edge; `plan.md`
  dropping the derived `Task 2 → Task 1` edge) + a `scripts/eval.sh` block — pins the mechanical
  preconditions of both actuations. The harness is now **7 fixtures, all green**.

### Changed
- `commands/ff-clarify.md` — a full-tier/non-trivial prompt for the two fields (riding Beat 3/4, not a
  fifth beat), an explicit lite-skip clause, and the spec fill-list extended to name them.
- `commands/ff-verify.md` — a new contract-mapping bullet turning each `## Success metrics` row into a
  `### SM<n>` item (presence check, not tier check), between the AC and FS bullets.
- `commands/ff-plan.md` — a new "Derive requirement-graph task edges" bullet (between "Map every AC"
  and "Derive planning intelligence") deriving task deps from the spec's requirement graph.
- `templates/plan.md` — a new Outcome-gate **Requirement-graph coverage** rule bullet; the
  `## Dependency graph` table is byte-unchanged (derive-don't-widen).
- `docs/manifest-schema.md` — the §Evidence Confidence-ladder contract-item enumeration.
- `skills/feature-flow/SKILL.md`, `README.md` — describe the optional success-metrics /
  requirement-graph capture in *clarify* and their verify/plan actuation in the phase tables.

## [0.16.0] — 2026-07-06 — Feedback / repair loop (WS-6)

`ff-verify` gains a **bounded one-cycle repair-and-re-verify** on a genuine failure — a transplant
of the autopilot **fix-and-re-review cycle** (`ff-review`) applied to a verify *failure* instead of
a review finding. When `manifest.autopilot: true` **and** `tier == "full"` **and** ≥1 contract item
(an acceptance criterion or bugfix item, **never** a design-time `FS<n>`) is backed by a **captured
non-success** exit/HTTP/status — a check that actually **ran and failed**, as opposed to a pure
evidence *gap* with nothing captured — `ff-verify` emits a short repair plan (what failed → smallest
diagnosis → proposed fix → re-touched ACs), applies the fix inline, and re-verifies **only the named
re-touched ACs, exactly once**, before the existing evidence-gap stop. A pure gap and a failed
`FS<n>` are unchanged (wait/waive). Step-by-step and lite tier are byte-for-byte unchanged.

The one-cycle cap is **artifact-resident**: a `## Repair` section in `verify.md` is the durable cycle
record (exactly as review's `## Resolution`) — a second failure with `## Repair` already present falls
through to the standard gap-report stop, never a second cycle. The scoped repair re-verify is an
explicit exception to the "clear `<run dir>/evidence/` at the start of each verify" rule: it preserves
every un-touched item's captured evidence and only re-runs the named re-touched ACs (a one-clause
carve-out in `agents/ff-test-runner.md`). **Deliberately reversing the WS-6 plan's literal text, there
is no `verify.repairCycles` manifest field** — matching the review cap it mirrors and the WS-1/2/4/5
"no new manifest field" doctrine; `ff-status`/`ff-resume` are unchanged. Additive and non-breaking:
**no new `manifest.json` field, no `toggles.*` key, no new phase, no new hook.** The one schema
addition is a §Autopilot mandatory-pauses **row** (capped-then-stop shape, explicitly **not**
"unconditional") + a mirrored **"Repair-and-re-verify cycle"** subsection. Full tier only;
`lite-tier-guard.sh` passes unmodified (lite has no design and its evidence-gap stop is untouched).

**Known coverage gap (named, not silent)** *(v0.18.0: firing now covered by the local forward-test runner `scripts/forward-test.sh` — still not CI; see [0.18.0])*: the *behavioral* catch has **no automated regression
guard** — verified by a fresh-session STOP-vs-control self-run (same posture as WS-1 AC13 / WS-2 AC15
/ WS-4 AC6-AC7 / WS-5 AC7-AC8):
- **AC13 (fired arm):** a full-tier autopilot run with a seeded failing repairable AC → `ff-verify`
  emits the repair plan and attempts **exactly one** repair-and-re-verify cycle; if still failing it
  stops with the gap report and does **not** attempt a second cycle.
- **AC14 (control arm):** a full-tier autopilot run whose verify passes (or whose only sub-Verified
  items are pure gaps, not failures) does **not** spuriously trigger a repair cycle.

Re-run the self-run after any edit to the `ff-verify` repair branch or the §Autopilot
"Repair-and-re-verify cycle" subsection. `repair-loop-guard.sh` and the `repair-gap` eval fixture pin
only the mechanical structure/wiring.

### Added
- **`## Autopilot → Verify repair-and-re-verify cycle` row + `**Repair-and-re-verify cycle`
  subsection** (`docs/manifest-schema.md`) — the capped-then-stop contract mirroring
  Fix-and-re-review cycle: durable `## Repair` record check, the one-cycle branch, the scoped
  re-verify + evidence-preservation exception, per-phase cap, no manifest field.
- **`scripts/checks/repair-loop-guard.sh`** — structural guard: the §Autopilot row (present + **not**
  "unconditional") + subsection, the `ff-verify.md` branch placement (inside "Refuse premature done",
  before the fall-through STOP) + full-tier precondition, the scoped-re-verify/evidence-exception
  strings in `ff-verify.md` + the carve-out in `ff-test-runner.md`, the `## Repair` template headers
  (digit-free proven by `enforce-gate-guard.sh`'s b-template fixture), the negative no-manifest-field
  /no-config-toggle check, and per-file dist parity.
- **`evals/fixtures/repair-gap/`** (`verify.md` first-cycle-available + `verify-capped.md`
  cap-detectable) + a `scripts/eval.sh` block — pins the mechanical preconditions of the repair
  actuation. The harness is now **6 fixtures, all green**.

### Changed
- `commands/ff-verify.md` — the "Refuse premature 'done'" section gains the autopilot
  repair-and-re-verify branch (before the unchanged fall-through gap-report STOP + waiver).
- `templates/verify.md` — new `## Repair` section (digit-free, Gate-B-safe).
- `agents/ff-test-runner.md` — the evidence-clear rule gains the scoped-repair-re-verify carve-out.
- `docs/manifest-schema.md` — §Autopilot row + "Repair-and-re-verify cycle" subsection.
- `skills/feature-flow/SKILL.md`, `README.md` — repair-cap doctrine + command-row + status badge.

## [0.15.0] — 2026-07-06 — Design-time trade-off matrix + devil's advocate (WS-5)

`ff-design` gains a **lean/adaptive trade-off matrix** (`design.md §Trade-off matrix`) — every
fanned-out option scored on three **core axes**, always (**complexity, risk/operational impact,
test effort**), with performance/maintainability/scalability/security/cost added as columns **only
when they differentiate** the options — and a **devil's-advocate pass** (`§Devil's advocate →
Failure scenarios`) naming ≥1 concrete failure scenario for the *chosen* option, plus edge cases and
migration/operational risk. This is the framework's only adversarial pass against the *selected
design* (`ff-clarify`'s red-team pass targets the *spec*), added as a final beat in `ff-design`
between the do-not-contradict STOP and the artifact write.

Each named failure scenario **actuates**: `ff-verify` resolves `manifest.artifacts.design` (full
tier; absent on lite/bugfix/pre-WS-5 → skip, never a STOP) and maps each `**FS<n>:**` bullet into
its own `### FS<n>` contract item in `verify.md`, **exactly as an acceptance criterion is mapped**.
An unproven `FS<n>` holds the run at `Partially verified`/`Unverified` and **blocks `done`** — cleared
only by proving it or the **same** verbatim `Evidence gap accepted by user (<date>): <reason>` waiver
an unverified AC already uses. The `docs/manifest-schema.md §Evidence` confidence ladder now names a
third contract-item class (design-time failure scenario). `decision.md`'s existing Trade-offs row
(`Effort | Risk | Reversibility`, **unchanged**, still pinned by `decision-record-guard.sh`) is now
explicitly **derived** from the design matrix rather than independently re-scored, and its rationale
names the failure scenario(s) by reference — `design.md` stays the single source of truth for the
`FS<n>` list. Additive and non-breaking: **no new `manifest.json` field, no `toggles.*` key, no new
phase, no new §Autopilot row, no new waiver line** — the existing "Evidence gap stop" row already
generalizes over any contract item, and Gate B (`hooks/enforce-gate`) is already scenario-agnostic.
Full tier only; `lite-tier-guard.sh` passes unmodified (lite skips `ff-design` by construction).

**Known coverage gap (named, not silent)** *(v0.18.0: firing now covered by the local forward-test runner `scripts/forward-test.sh` — still not CI; see [0.18.0])*: the *behavioral* catch has **no automated regression
guard** — verified by a fresh-session STOP-vs-control self-run (same posture as WS-1 AC13 / WS-2
AC15 / WS-3 AC5 / WS-4 AC6/AC7):
- **AC7 (fired arm):** a full-tier design names a failure scenario with no mechanical way to capture
  evidence → `ff-verify` reports it `Unverified`, the run does **not** reach `done`, and the gap
  names the `FS<n>`; supplying the verbatim waiver then unblocks it.
- **AC8 (control arm):** a full-tier design names a scenario the implementation actually covers and
  the runner CAN capture → `ff-verify` reports `Verified` and the run reaches `done` with **no**
  waiver — the mechanism does not false-fire on a genuinely-proven scenario.

Also accepted as a named non-goal: an `FS<n>` waiver and an `AC` waiver are **not** distinguishable
per-item on disk (FS carries no validation-required flag the way WS-4's assumptions do). Re-run the
self-run after any edit to the `ff-design` beat or the `ff-verify` FS-mapping text.
`design-tradeoff-guard.sh` and the `design-gap` eval fixture pin only the mechanical structure/wiring.

### Added
- **`## Design trade-offs & devil's advocate`** canonical contract (`docs/manifest-schema.md`) —
  core/adaptive axes, the `FS<n>` labeled-bullet notation, its actuation into `ff-verify` (reusing
  the evidence-gap stop + waiver, no new row/field/hook), and the `decision.md` derive-don't-widen
  reconciliation, with a `### v1 non-goals` naming the un-guarded AC7/AC8 catch.
- **`scripts/checks/design-tradeoff-guard.sh`** — structural guard: design-template sections + core
  header, the `ff-design` beat placement (asserts both anchors before comparing), the `ff-verify`
  FS-mapping + `artifacts.design` wiring, the **digit-free** FS placeholder (mirrors Gate B's regex),
  the no-new-config-key negative check, an assertion that `templates/decision.md`'s Trade-offs header
  is untouched, and per-file dist parity.
- **`evals/fixtures/design-gap/`** + a non-blocking `scripts/eval.sh` block — pins the mechanical
  preconditions of the `FS<n>` actuation (a labeled unprovable failure scenario + drift guard vs
  `templates/design.md` + `ff-verify` wiring string). The harness is now **5 fixtures, all green**.

### Changed
- `templates/design.md` — new `## Trade-off matrix` (after Rejected alternatives) and
  `## Devil's advocate` (`### Failure scenarios` labeled bullets + `### Edge cases & operational
  risk`) — additive; existing sections untouched.
- `commands/ff-design.md` — the devil's-advocate pass beat (between the do-not-contradict STOP and
  `## Write the artifact`); the decision-writing step now states the Trade-offs derive-not-diverge rule.
- `commands/ff-verify.md` — Cold-start resolves `artifacts.design` (full tier, absent-tolerant); a
  new FS-mapping bullet alongside the AC/bugfix mapping bullets.
- `templates/verify.md` — new digit-free `### FS1` contract-mapping block.
- `docs/manifest-schema.md` — §Evidence Confidence ladder names the third contract-item class.
- `skills/feature-flow/SKILL.md`, `README.md` — describe the matrix + devil's-advocate pass.

## [0.14.0] — 2026-07-06 — Eval harness: WS-2 coverage + non-blocking CI wiring

Closes the eval harness's (WS-8) largest hole and gives it a home in CI. WS-2 Planning
Intelligence — the highest-value, most-actuating merged workstream — was the only one of
WS-1/WS-3/WS-4 with **no** eval fixture, so a regression in critical-path derivation had nothing
pinning it. New `evals/fixtures/planning-gap/` supplies a plan whose stated `## Critical path`
(`Task 1 → Task 3`) is **hand-authored** and drops the gating `Task 2` its own `## Dependency
graph` proves `Task 3` depends on — the exact "Derived — never hand-authored" violation the WS-2
`ff-implement` STOP exists to catch. The new `scripts/eval.sh` block asserts the mechanical
preconditions: the graph proves the gating dependency, the stated path omits it (the gap is
present and detectable), a drift guard against `templates/plan.md`, and the derive/STOP wiring in
`ff-plan.md` / `ff-implement.md §Critical-path check`. The harness is now **4 fixtures, all green**.

`scripts/eval.sh` is now **wired into CI** (`.github/workflows/ci.yml`) as a `continue-on-error`
**report** step — non-blocking from this release (a RED fixture is visible but never wedges a
release), to be promoted to blocking at v2.3 by dropping the `continue-on-error` line. This lands
the plan's "add to CI as a non-blocking report initially" step, so v2.1's actuation claims are
measured in CI rather than only runnable by hand.

**Known coverage gap (named, not silent)** *(v0.18.0: `ff-implement`'s critical-path STOP is now covered by the local forward-test runner `scripts/forward-test.sh`; `ff-plan` deriving the path is not — still not CI; see [0.18.0])*: the *behavioral* catch — `ff-plan` actually deriving
the path and `ff-implement` actually STOPping on a critical-path skip (AC15) — has no automated
regression guard; it is a semantic, LLM-judgment behavior verified by a fresh-session
STOP-vs-control self-run (same posture as WS-1 AC13 / WS-3 AC5 / WS-4 AC6/AC7). The `planning-gap`
fixture pins only the mechanical preconditions and wiring.

### Added
- **`evals/fixtures/planning-gap/plan.md`** + a `scripts/eval.sh` block — pins the mechanical
  preconditions of WS-2's derived-critical-path actuation: gating dependency present in the graph,
  dropped from the stated path, a drift guard against `templates/plan.md`, and ff-plan/ff-implement wiring.
- **CI eval step** (`.github/workflows/ci.yml`) — runs `scripts/eval.sh` as a non-blocking
  `continue-on-error` report after the guard scripts.

### Changed
- `scripts/eval.sh` — header updated to reflect the CI wiring; adds the fourth (`planning-gap`) fixture.

## [0.13.0] — 2026-07-06 — Structured assumption records (validation-required → sign-off block → plan task)

Beat-4 assumptions become a **structured 5-column table** — `Statement`, `Confidence` (`low|med|high`),
`Basis / evidence`, `If-wrong impact`, `Validation-required` (`y|n`) — in both `spec.md` and (full-tier)
`diagnosis.md`, replacing the former free-text bullets. The `validation-required: y` flag now **actuates**
instead of sitting inert: (1) at the **sign-off gate** (feature both tiers; bugfix full tier), every
still-unvalidated `y` assumption is **echoed** in the sign-off ask as a distinct `### Unvalidated
assumptions` block (never folded into the `- [ ] AC<n>` checkboxes) and **blocks a clean sign-off** — the
run cannot reach `signOff.signed = true` until each is **resolved**: validated, waived, or (full tier)
explicitly acknowledged as staying open; (2) on the **full tier**, `ff-plan` maps each such
acknowledged-open `y` assumption to a plan **validation task** carrying `**Validates:** Assumption N`
(or a named coverage gap), cloning the `**Covers:**` AC-mapping discipline.
So a surfaced assumption produces a decision (validate/waive at sign-off) or work (a full-tier plan
task) — it can no longer be recorded and silently forgotten. The actuation is the **Evidence-gap-stop shape** —
turn-ending and waivable by the verbatim, **user-authored** line `Assumption validation waived by user
(<date>): <reason>` (autopilot never records it) — **not** the do-not-contradict STOP: an unvalidated
assumption is *unaddressed*, not *contradicting*, so its §Autopilot mandatory-pause row deliberately does
**not** say "unconditional". Additive and non-breaking: no new `manifest.json` field and no `toggles.*`
key — assumption data lives inside the artifact, located via the existing `manifest.artifacts.spec` /
`.diagnosis` pointers (WS-2's always-on, artifact-resident posture). New canonical `## Assumption records`
section in `docs/manifest-schema.md`; `§Sign-off rendering` bumped to "Three rules". `scripts/checks/assumption-guard.sh`
pins the structure against the shipped files; a non-blocking `evals/fixtures/assumption-gap/` fixture pins
the mechanical preconditions.

**Known coverage gap (named, not silent)** *(v0.18.0: firing now covered by the local forward-test runner `scripts/forward-test.sh` — still not CI; see [0.18.0])*: the *behavioral* catch — the echo actually **rendering** an
unvalidated assumption and **blocking** a clean sign-off (AC6), and the clean control **not** false-firing
(AC7) — has **no automated regression guard**; it is a semantic, LLM-judgment behavior verified by a
fresh-session STOP-vs-control self-run (same posture as WS-1 AC13 / WS-2 AC15 / WS-3 AC5).
`assumption-guard.sh` and the `assumption-gap` eval fixture pin only the mechanical structure and wiring.

### Added
- **`## Assumption records`** canonical contract (`docs/manifest-schema.md`) — 5-column row schema,
  the `validation-required: y` trigger (author-set, never derived), Actuation 1 (sign-off echo) /
  Actuation 2 (plan validation task), waiver semantics, and tier/track scope.
- **`scripts/checks/assumption-guard.sh`** — structural guard: table columns, clarify/diagnose wiring,
  §Sign-off rendering rule 3, the verbatim waiver line + §Autopilot row, the plan-mapping rule, and a
  per-file Codex dist-parity check. Deliberately does not assert "unconditional" on the WS-4 row.
- **`evals/fixtures/assumption-gap/`** + a non-blocking `scripts/eval.sh` block — pins the mechanical
  preconditions of the sign-off echo (an unvalidated `y` row + drift guard + echo/waiver wiring).

### Changed
- `templates/spec.md` / `templates/diagnosis.md` — free-text assumption bullets → identical 5-column
  table (`diagnosis.md`'s is full-tier-only, between `## Fix approach` and `## Fix surface`).
- `templates/plan.md` — Outcome-gate `**Validates:** Assumption N` mapping rule + a task example.
- `commands/ff-clarify.md` / `commands/ff-diagnose.md` — Beat-4 / fix-approach steps write assumption
  rows; sign-off gate echoes unvalidated `y` rows as a distinct block + the verbatim waiver line.
- `commands/ff-plan.md` — full-tier assumption→task mapping bullet, between the AC-map bullet and
  "Derive planning intelligence".
- `docs/manifest-schema.md` — `§Sign-off rendering` bumped to "Three rules" (rule 3); `§Autopilot`
  gains an "Assumption validation stop" mandatory-pause row.

## [0.12.0] — 2026-07-05 — Delivery intelligence (release / deploy / rollback / migration)

Runs gain an optional, post-`done` **delivery** phase. `/feature-flow:ff-deliver` assembles a
`delivery.md` — release notes, deployment checklist, rollback checklist, migration notes, known
issues, release validation — by **consuming** the run's upstream artifacts, never restating them:
release notes from the spec's ACs + `decision.md`, the rollback checklist row-for-row from
`plan.md §Rollback plan`, known issues mirrored from `verify.md §Limitations & remaining risks`,
validation steps from `verify.md §Commands run`. Delivery is a **value-add**: it is invoked by hand,
**never blocks `done`**, is off for `tier: lite` unless requested, and autopilot never chains into
it. Its actuation is the **delivery gap** — a plan task touching migration/schema/irreversible I/O
with no `§Rollback plan` recovery line is surfaced as a non-blocking `⚠ DELIVERY GAP`, back-pressuring
the plan to record the rollback WS-2 asks for. Additive and non-breaking: `currentPhase` stays `done`
(the enum is unchanged and Gate B is untouched); delivery is tracked only in a new `phases.deliver` +
`artifacts.delivery`, both absent-defaulted, so every pre-v0.12.0 manifest resolves and resumes unchanged.

**Known coverage gap (named, not silent)** *(v0.18.0: firing now covered by the local forward-test runner `scripts/forward-test.sh` — still not CI; see [0.18.0])*: the *semantic* catch — `ff-deliver` actually writing the
`⚠ DELIVERY GAP` line on a live run — has **no automated regression guard**; it is a manual/fresh-session
behavioral AC (AC5). `delivery-guard.sh` and the `delivery-gap` eval fixture pin only the mechanical
preconditions (template headers, the gap-detection instruction's presence, the fixture hole is
detectable) — not that the catch fires. Same honest posture as v0.10.0's AC13 and v0.11.0's AC15.

### Added
- **`deliver` phase** — new `commands/ff-deliver.md` (optional, post-`done`, non-gated, shared across
  feature + bugfix) and `templates/delivery.md` (six sections, each consuming section names its source).
- **`## Delivery`** canonical contract (`docs/manifest-schema.md`): `phases.deliver` +
  `artifacts.delivery` (absent-defaulted, promotion-eligible), the consumption-source table, and the
  delivery-gap actuation. The `currentPhase` enum is unchanged.
- **`scripts/checks/delivery-guard.sh`** — structural guard (template headers, command wiring, schema
  fields, enum-unchanged, SKILL/README wiring, dist parity).
- **`evals/fixtures/delivery-gap/`** + a `scripts/eval.sh` block — a done run whose plan's migration
  task is missing its rollback line, proving the gap is mechanically detectable.

### Changed
- `skills/feature-flow/SKILL.md` phase lists + manual-controls list, and the `README.md` command table,
  now document the optional delivery phase.
- `docs/manifest-schema.md` §Terminal convergence + §Autopilot note that delivery is post-terminal and
  never chained; the durable-eligible artifact set includes `delivery`.

## [0.11.0] — 2026-07-05 — Planning intelligence (dependency graph → critical path → STOP)

Plans stop being a flat task list. `ff-plan` now derives four sections into every `plan.md` /
`plan-bugfix.md` (between `## Tasks` and `## Status conventions`): a **Dependency graph** (edges
naming only lower-numbered `Task N` IDs — so task order is always topological and cycles are
unexpressible), a **Critical path** *derived* from that graph (the longest dependency chain,
deterministic tie-break — never hand-authored), a categorical **Risk register**, and a **Rollback
plan**. The critical path is the **sole hard actuator**: `ff-implement` reads it (via
`manifest.artifacts.plan`) and **STOPs** — unconditional in both modes, cloned from the
decision-recall do-not-contradict STOP — if the approach skips or reorders a critical-path task; an
override is the user's own words, recorded verbatim as `Critical-path override by user (<date>):
<reason>` in the plan, never self-authored. The other three plug into existing consumers: the risk
register feeds `ff-verify`'s `## Regression risk`; the rollback plan is the recovery `ff-implement`
runs on a failed `Step N: Verify`. Additive and non-breaking: **no new config toggle, no new
manifest field** (the sections live inside the already-durable plan); a pre-WS-2 plan with no
sections is absent-tolerated everywhere (STOP proceeds, verify derives risk cold).

**Known coverage gap (named, not silent)** *(v0.18.0: firing now covered by the local forward-test runner `scripts/forward-test.sh` — still not CI; see [0.18.0])*: the *semantic* catch — `ff-implement` actually
STOPping on a critical-path-skipping approach — has **no automated regression guard**; it is a
manual/fresh-session self-run behavioral AC (AC15). `planning-intelligence-guard.sh` pins only the
STOP *instruction's presence*, section placement, and the derivation rule's wording — not that the
catch fires. Same honest posture as v0.10.0's AC13.

### Added
- **Four planning-intelligence sections** in `templates/plan.md` and `templates/plan-bugfix.md`
  (`## Dependency graph`, `## Critical path`, `## Risk register`, `## Rollback plan`), each with
  house-style `> ` fill-in guidance; categorical risk (Low/Med/High), no numeric scores.
- **`## Planning intelligence`** canonical contract (`docs/manifest-schema.md`) — the dependency
  notation + lower-numbered invariant, the deterministic critical-path derivation, the
  `ff-implement` do-not-contradict STOP, and the risk/rollback consumer contracts; plus a
  **Critical-path stop** row in the Autopilot mandatory-pauses table (unconditional, no
  auto-resolve retry).
- **`scripts/checks/planning-intelligence-guard.sh`** — pins both templates' four sections
  (presence, order, placement, categorical risk table, Task-ID edges), the schema section +
  Autopilot row, the `ff-plan` derive-instruction placement, the `ff-implement` `## Critical-path
  check` section (placement + `artifacts.plan` + unconditional + override string + rollback
  pointer), the `ff-verify` risk cross-reference, the no-new-config/manifest-field negatives, and
  Codex dist parity.

### Changed
- **`ff-plan`** derives the four sections after task decomposition / AC-mapping and before the
  Outcome gate (both tracks); the critical path is derived from the graph, never hand-authored.
- **`ff-implement`** gained a `## Critical-path check` section (between `## Decision recall` and
  `## Do the work — feature track`): the critical-path STOP plus the rollback-on-failed-Verify
  recovery pointer.
- **`ff-verify`** cross-references the plan's `## Risk register` into its `## Regression risk`
  assessment instead of deriving risk cold (full tier; lite/pre-WS-2 unchanged).

## [0.10.0] — 2026-07-05 — Structured decision records (record → recall → enforce)

Design decisions stop being write-only. `ff-design` now records the chosen architecture in a
structured `decision.md` (options, trade-offs, chosen rationale), promoted alongside `design.md`;
and that decision **constrains later phases** — `ff-implement` recalls this run's own decision
(and, when the KB is active, prior decisions from other runs) before writing code and **STOPs** if
the approach diverges, and `ff-design` STOPs if a pick contradicts a prior settled decision. The
STOP is a **prose gate** (an LLM judgment, like sign-off — no hook, semantic contradiction is not
machine-checkable) and **unconditional in both modes**; an override is the user's own words,
recorded verbatim, never self-authored. Additive and non-breaking: no new phase or agent; the one
new manifest field (`artifacts.decision`) is absent-tolerated with no migration, and `tier: lite`
stays cheap (the spec's inline decision *is* the record — `artifacts.decision` points at the spec).

**Known coverage gap (named, not silent)** *(v0.18.0: the STOP is now covered by the local forward-test runner `scripts/forward-test.sh` — but a mutation run showed the model still STOPs with the instruction removed, so that case proves the behavior, not that this instruction causes it — still not CI; see [0.18.0])*: the *semantic* catch — the agent actually STOPping on a
contradiction — has **no automated regression guard**; it is a manual/self-run behavioral AC
(AC13). Automated coverage pins only the STOP *instruction's presence* in the command files
(`decision-record-guard.sh`) and the recall *preconditions* (`scripts/eval.sh`). A future
fast-follow could deepen this; today it is honestly manual.

### Added
- **`templates/decision.md`** — the decision record: frontmatter (`tags`, `referencedFiles`, for
  recall tag-match + staleness) + `## Decision / Context / Options considered / Trade-offs
  (matrix) / Chosen + rationale / Outcome / Future considerations` + `**Related ACs:**` /
  `**Related files:**`.
- **`### Decision recall`** contract (`docs/manifest-schema.md` §Knowledge base) — the canonical
  two-source rule (this run's `artifacts.decision`, unconditional; prior KB decisions, KB-gated)
  and the do-not-contradict STOP; a **Decision conflict stop** row in the Autopilot mandatory-pauses
  table; `artifacts.decision` field note (absent = no decision recorded, no migration; dual-shaped
  full/lite); `decision` added to the durable-artifact list + the disk-inference tuple.
- **`scripts/checks/decision-record-guard.sh`** — pins the template headers (against the verbatim
  shipped template), the ff-design/ff-implement/ff-clarify wiring, the STOP-instruction survival in
  both command files, and dist parity of `templates/decision.md`.
- **`scripts/eval.sh` + `evals/`** (WS-8) — a **non-blocking** precondition harness (outside
  `scripts/checks/`, not in CI): one fixture asserting a decision record is well-formed,
  tag-matchable against a contradicting request, and that the STOP wiring exists. Not the semantic
  catch (see coverage gap above).

### Changed
- **`commands/ff-design.md`** — after the architecture pick, writes `decision.md` (recorded in
  `artifacts.decision`) and STOPs on a pick that contradicts a prior settled decision.
- **`commands/ff-implement.md`** — new `## Decision recall` section (between Cold-start and Do the
  work) recalls the run's decision and STOPs on divergence before any code is written.
- **`commands/ff-clarify.md`** — lite branch points `artifacts.decision` at the spec, so implement's
  recall is tier-agnostic (no fork).
- **KB capture** now reads `decision` (preferred distillation source over `design` prose), closing
  the decision-record ↔ KB-entry redundancy.
- **`scripts/checks/kb-guard.sh`** (`check_recall` generalized + `ff-implement` decision-recall
  call) and **`durable-paths-guard.sh`** (`decision` writer check + bare-name coverage) extended.

## [0.9.0] — 2026-07-05 — Evidence-based verification

No task reaches `done` without objective, reproducible, multi-source evidence. The verify
pipeline widens from generic test/build/lint to the project's whole **detected** evidence
surface, `verify.md` becomes a client-sign-off-grade report, and insufficient evidence now
**blocks completion** pending an explicit user waiver. Additive and non-breaking: no new
phase, agent, config key, or artifact type; existing runs and configs behave as before —
the verify phase simply produces (and is gated on) more than a bare pass/fail table.

### Added
- **Canonical `## Evidence` contract** (`docs/manifest-schema.md`): the 8-kind taxonomy
  (executed-test, build/static-analysis, e2e/browser via Playwright CLI, http/api, db,
  cli-output, logs, before/after), the literal record shape
  `{kind, command, actual exit/HTTP status, excerpt, artifact paths}`, the evidence
  directory rule (`<run dir>/evidence/`, cleared per run, copied on durable promotion),
  the **mechanical confidence ladder** (`Verified (multi-source)` / `Verified
  (single-source)` / `Partially verified` / `Unverified`; overall = minimum; independence
  = distinct kinds), the detection→gap/N-A rule, the waiver rule, tier scaling, an
  "Adding an evidence kind" recipe, and stated v1 non-goals. Commands reference it by
  name — never restate it.
- **Widened `ff-test-runner`** (`agents/ff-test-runner.md`): detects `composer.json`
  scripts, `phpunit.xml(.dist)`, `playwright.config.*`, `bin/magento`, and MFTF alongside
  package.json/Makefile/pyproject; captures all 8 kinds with real status codes; writes
  only under `<run dir>/evidence/` (cleared at start); bounds every command with a
  timeout; guarantees ≥1 attempted command with a real exit code even on a no-tests
  project (cheapest smoke/syntax check).
- **Client-grade `verify.md`** (`templates/verify.md`): evidence coverage matrix
  (full-tier; lite renders the floor-only note), per-criterion evidence blocks
  (requirement verbatim → method → evidence with commands + status codes + `evidence/`
  artifacts → confidence), evidence artifacts index, Limitations & remaining risks, and an
  overall-confidence verdict. `## Commands run`, `## Contract mapping`, and
  `## Regression risk` headings unchanged.
- **Evidence gap stop** (`commands/ff-verify.md` + §Autopilot mandatory-pauses row): any
  contract item below `Verified (single-source)` blocks `done` — the run ends with a gap
  report (what could not be verified, why, what evidence is required). Only the user's own
  waiver line — `Evidence gap accepted by user (<date>): <reason>` — unblocks it; a waiver
  never upgrades confidence, and autopilot never records one.
- **Gate B content check** (`hooks/enforce-gate`): `artifacts.verify` must now also contain
  a `## Contract mapping` heading and ≥1 captured exit/HTTP/status token — the historic
  `# Verify` stub that previously passed Gate B is now denied
  (`scripts/checks/enforce-gate-guard.sh` fixtures flipped/added to prove it: stub → deny,
  filled report → allow, heading-without-token → deny). Still fail-open, `jq`-only,
  verify-specific (`artifacts.review` keeps the generic check), Claude-Code-only.
- **Durable client report**: `verify` joins the durable-eligible artifacts — with
  `paths.durable` set, `verify.md` promotes to `<paths.durable>/<D>-<slug>/` with the
  run's `evidence/` directory **copied** alongside (Evidence companion copy), keeping
  relative links resolving. README warns about committing binary-heavy evidence dirs.
- **Guards**: `scripts/checks/evidence-guard.sh` extended with sections (f)–(l) pinning
  the §Evidence subsections + record shape + taxonomy, the four confidence tokens (schema
  AND template), the new report headings + lite note, the ff-test-runner detection tokens +
  evidence-dir discipline, the Autopilot pause row, the ff-verify wiring + waiver line, and
  dist parity for the newly pinned files. `durable-paths-guard.sh` now `check_writer`s
  `commands/ff-verify.md` for `artifacts.verify`.

### Changed
- `commands/ff-verify.md`: evidence authority extends to all kinds (a detected surface that
  did not run/pass is an explicit **gap**; N/A only for undetected surfaces, always with a
  reason); confidence derived mechanically (count distinct passing kinds — never eyeballed);
  `## Refuse premature "done"` is now the evidence gap stop; verify resolves its path per
  Durable artifact resolution and records it in `artifacts.verify`.
- `docs/manifest-schema.md` §Disk inference: `verify.md` minimal validity now matches Gate
  B's content check (heading + status token), so inference and the hook never disagree.

### Reconciliation with v0.5.0
v0.5.0 deferred a "completion-proof framework" (duplicative of verify.md) and rejected
numeric confidence/readiness scores ("unfalsifiable LLM output"). **Both decisions are
upheld**: there is still no parallel report artifact — `verify.md` itself is the report,
upgraded in place — and there are still no numeric scores — confidence is categorical and
mechanically recountable from the captured evidence (count the distinct passing kinds).
What changed since v0.5.0 is the external requirement: client sign-off now depends on the
verification report, and the evidence surface widens from test/build/lint to everything
the project detectably has (incl. Magento/PHP stacks: composer, PHPUnit, `bin/magento`,
MFTF — and Playwright e2e via CLI).

### Deferred (stated, not silent)
MCP/interactive browser automation (Playwright CLI via Bash only); Gate B waiver-coverage
checking (semantic, not grep-determinate — v2 hardening candidate); environment
provisioning; CI integration; perf-benchmark framework; retroactive re-verification.

## [0.8.0] — 2026-07-04 — Knowledge base on by default + bugfix-track recall

The KB (0.4.0, opt-in) becomes **on by default**, and recall reaches the bugfix track. **Zero
runtime-logic change**: the activation AND-gate, recall procedure (tag-match + staleness
flag-not-drop), confirm-gated capture, and Codex degrade path are all semantically identical —
only the shipped default *values* and the set of recall-hooked commands change. Projects with an
explicit `.feature-flow.json` behave exactly as before (explicit keys override defaults).

### Changed
- **KB defaults flipped** (`config/defaults.json`): `toggles.kb` `false` → `true`, `paths.kb`
  `null` → `".feature-flow-kb"`. A fresh project has an active KB from its first run — capture
  at the done-transition, recall before the fan-outs. **Opt out per-project** with
  `{ "toggles": { "kb": false } }` (or `paths.kb: null`); either cleanly deactivates (the
  half-config warning from 0.6.0 still fires on an explicit `paths.kb: null` with the toggle on).
  `kb.freshnessWindowDays` (90) and `kb.maxRecallEntries` (5) unchanged.
- **`kb-guard.sh` re-pinned**: section (a) now asserts the *new* defaults (RED→GREEN
  demonstrated against the old config); sections (e)/(g)/(h) extended to cover
  `commands/ff-diagnose.md`.

### Added
- **KB recall on the bugfix track** (`commands/ff-diagnose.md` `## KB recall`): tag-matched
  entries are surfaced to the diagnostician agents before dispatch, keyword source = the bug
  report (`$ARGUMENTS`). Previously recall was feature-track-only (`ff-explore`/`ff-design`),
  leaving the KB write-only on bugfix-heavy projects — captured at `ff-review` but never
  consumed. The canonical contract (`docs/manifest-schema.md` §Knowledge base) now names five
  hooked commands and a three-command recall rule.

### Docs
- `manifest-schema.md` §Activation rewritten for on-by-default (+ the half-config example now
  says *explicitly null*, matching the post-flip reality — also mirrored in `ff.md`); SKILL.md
  §Knowledge base and README (section + config table) updated; the repo's own KB entry
  recording the old default-off decision rewritten in place to the new convention. Historical
  CHANGELOG entries (0.4.0–0.7.0) untouched.

## [0.7.0] — 2026-06-26 — lite feature tier

Brings the feature track to parity with the bugfix track's lite/full split (M2 from the v0.5.0 architecture review). **Non-breaking and additive**: `tier` already existed on the manifest; this teaches the feature track to use `lite`. A feature with no/`full` tier behaves byte-identically to before.

### Added
- **Lite feature tier (M2).** Small, single-approach features can run `tier: lite` — `explore → clarify → implement → review → verify` — **skipping the design + plan phases** and using a **1-agent explore**, while keeping sign-off + review + verify. Tier is **soft-judged at `/ff` entry** (announced; ambiguous → ask once; **in doubt → full**), mirroring the existing feature-vs-bugfix classification. A lite run can **escalate to full before implement** (sets `tier=full`, resets sign-off, carries the spec forward into the full clarify → design path). `ff-clarify` runs a minimal clarify on lite (skips the premise + approach-weighing beats, asks only enough to lock binary ACs); `ff-implement`'s feature cold-start is now tier-aware (lite requires only the signed `spec.md`, never routes to the non-existent design/plan phases). `enforce-gate`'s Gate A already covers `feature/*`, so a lite feature is enforced (no implement without sign-off) with **no hook change**. Contract pinned by `scripts/checks/lite-tier-guard.sh`; the free hook coverage pinned by two new `enforce-gate-guard.sh` fixtures.

## [0.6.0] — 2026-06-26 — reliability hardening + fail-closed enforcement

Foundation-safety fixes from the v0.5.0 architecture review (`docs/feature-flow/architecture-review-2026-06-25.md`). All **non-breaking**: additive frontmatter, additive schema rules, prose clarifications, one optional manifest field (`lock`, absent = unlocked), and new dev/CI tooling. Manifests authored before this change still validate; no migration.

### Added
- **Manifest write safety** (`manifest-schema.md` §Manifest write safety, wired via Run resolution step 7): mandates whole-object atomic writes (never partial line-edits that can leave torn JSON) — closing the highest-probability corruption path — and adds an **advisory `lock`** field, a soft staleness-self-healing concurrency guard (15-minute stale-takeover) so two sessions touching one run warn rather than silently clobber. The lock is advisory prose, not an enforced mutex (C1).
- **Universal corrupt-manifest handling** (`manifest-schema.md` Run resolution step 6): the "on a corrupt manifest, fall back to Disk inference — never improvise or blind-overwrite" rule, previously honored only by `ff-resume`/`ff-status`, now applies to **every** command. Phase commands inherit it via their existing `Run resolution` reference (C3).
- **Least-privilege `allowed-tools`** on the inspect/management commands: `ff-status`/`ff-list` → `Read, Glob, Grep`; `ff-abandon`/`ff-close` → `Read, Glob, Write`. The read-only/scoped claims are now tool-enforced, not prose-only (C4).
- **Config validation at run start** (`manifest-schema.md` §Config resolution & validation, wired from `ff`): `/feature-flow:ff` now validates the resolved config and **warns** on an unknown/typo'd key (e.g. `explorerAgent` vs `explorerAgents`), a half-configuration (`toggles.kb` true with `paths.kb` unset), or a type/domain mismatch — then falls back to the safe default. Misconfigurations are surfaced instead of silently no-op'ing (Q2).
- **Comprehensive dist-parity guard** (`scripts/checks/dist-parity-guard.sh`): checks **every** packaged file is byte-identical to source, not the ~half the other guards spot-checked — so a future edit to any packaged file that isn't re-packaged is caught (Q4).
- **CI workflow** (`.github/workflows/ci.yml`): builds the Codex package (fixing the fresh-clone landmine where the gitignored `dist/` left parity checks with nothing to diff), JSON-parses every config/manifest, then runs all guard scripts on every push and PR. Previously nothing ran the guards (Q5).
- **Fail-closed enforcement on Claude Code** (`hooks/enforce-gate` + `toggles.enforce`, default on): a `PreToolUse` hook now **denies** two illegal `manifest.json` transitions instead of merely asking commands not to make them — entering `implement` without the track's sign-off precondition (**Gate A**) and reaching `done` without valid on-disk verify (and, on bugfix, review) evidence (**Gate B**). The hook **fails open** (allows on any indeterminate state — `jq` absent, unparseable manifest, missing fields, `toggles.enforce: false`) and denies only a determinate-illegal write, so it can never block normal editing or wedge a run. Requires `jq`; warns loudly (`systemMessage`) if absent. Codex (no hook mechanism) keeps the prose gates — the hook backstops the prose, it does not replace it. Behavioral test: `scripts/checks/enforce-gate-guard.sh` (19 cases incl. the `run-hook.cmd` dispatch seam). Turns the workflow's hardest promises from "asked nicely" to enforced (M1).

### Changed
- **Single-sourced the KB recall/capture procedures** (Q3): `ff-explore`/`ff-design` (recall) and `ff-verify`/`ff-review` (capture) inlined the full numbered procedure that the schema's §Knowledge base already owns — a triple. Each command now keeps only its gating sentence, a by-name reference to the canonical rule, and its command-specific input (recall keyword source / capture artifact list); the procedure guts live only in the schema. Behavior byte-identical. Also enriched the schema capture rule to name `plan` (previously omitted there while both commands relied on it).
- **Single-sourced the terminal-convergence rule** (Q6): which command marks a run `done` (feature → `ff-verify`; bugfix → whichever of verify/review runs second) is a core-workflow invariant that governs even KB-off runs, but its only statement was buried inside the §KB capture rule. Extracted to a canonical `manifest-schema.md` §Terminal convergence section; §KB capture and both terminal commands now reference it. The two commands' status-check routing is intentionally left in place (it is irreducibly two-sided); `kb-guard` gained checks pinning the new single-source structure and still counts the `**KB capture**` invocations.
- **Design fan-out builds on exploration** (`ff-design`): architects are now passed the `explore.md` findings as context instead of cold re-scanning the repo, eliminating ~3× redundant codebase scans per design phase (Q7).
- **Verification authority moved off read-only agents** (C2, minimal prose): `ff-diagnostician` now labels its reproduction a **static hypothesis** (it is read-only and cannot execute); `ff-diagnose` states the binding executed evidence is the RED regression test in `ff-implement`; `ff-verify` records the test runner's literal exit evidence and may mark `pass` only when backed by a captured success exit code (no narration-only or reasoning-only passes); `ff-test-runner` derives each status from the **actual exit code** and has an explicit no-write-to-tracked-files constraint.

## [0.5.0] — 2026-06-24

Evidence over assumptions. Three additive guardrails folded into existing templates and phase
prompts — no new artifacts, no new workflow phase, no migration. Runs authored against the v0.4.0
templates still validate.

### Added
- **AC traceability (feature track)**: the `plan.md` task template gains a `**Covers:**` field,
  and the Outcome gate now requires every spec acceptance criterion to map to ≥1 task — an
  uncovered AC is flagged as an explicit gap, never left silent. `ff-plan` enforces this, scoped
  to the feature track (a full-tier bugfix has no spec/ACs; its contract is the diagnosis).
- **Regression risk in verification**: `verify.md` gains a `## Regression risk` section
  (`Low | Medium | High` + reason; no numeric score), filled by `ff-verify` from the surface the
  change touched.
- **Root-cause candidate ranking (full-tier bugfix)**: `diagnosis.md` separates
  `## Root cause candidates` (≥2 hypotheses with evidence for/against) from
  `## Confirmed root cause`. `ff-diagnose` requires candidate enumeration on the full tier and
  leaves lite (trivial) bugs single-cause — no ceremony on a one-spot fix.

### Deferred (stated, not silent)
- New `test-design.md` / `investigation.md` artifacts and a completion-proof framework (they
  duplicate the existing design / diagnosis / verify artifacts); numeric confidence/readiness
  scores (unfalsifiable LLM output); and the verify→review reorder (entangled with the KB
  single-fire invariant and `kb-guard` assertions — warrants its own guard-tested change).

## [0.4.0] — 2026-06-15

Knowledge base. **Off by default** — with `toggles.kb` false or `paths.kb` null, every phase
behaves byte-identically to v0.3.1 (no migration, no new prompts).

### Added
- **Knowledge base (opt-in)**: a finished run can **capture** its architectural decisions /
  project conventions as project-local markdown entries (confirm-gated, fired exactly once at the
  run's done-transition across both tracks), and later runs **recall** tag-matching entries into
  the `explore` and `design` fan-outs. Stale entries (referent missing/moved, or older than
  `kb.freshnessWindowDays`) are flagged `[STALE — …]`, never silently dropped or shown as fresh.
- Config: `toggles.kb` (default `false`), `paths.kb` (default `null`), `kb.freshnessWindowDays`
  (default `90`), `kb.maxRecallEntries` (default `5`).
- Canonical `## Knowledge base` contract in `docs/manifest-schema.md` (store layout, entry schema,
  capture/recall/staleness rules, Codex degrade table); entry template `templates/kb-entry.md`;
  regression guard `scripts/checks/kb-guard.sh`.
- v1 non-goals (deferred to a fast-follow, stated not silent): dedup, supersession, an index
  query surface, content-similarity relevance, mid-run capture, auto-committing, and a global KB.

### Note
- The KB's **structural** wiring is guard-pinned (RED→GREEN). Its **behavioral** path
  (live capture/recall/staleness) is verified by a manual smoke in a KB-enabled session; treat the
  opt-in feature as **beta** until that smoke is run.

## [0.3.1] — 2026-06-12

### Fixed
- **Run-start autopilot ask was silently skippable** (first real-world v0.3.0 run locked
  itself to step-by-step: the executor wrote `autopilot: false` without asking, and
  "never re-ask" made it permanent). The ask is now structurally non-droppable: the value
  is resolved **before** the manifest is written, `autopilot` is a required creation
  field at all four manifest-creating entry points, the unconditional doctrine gains
  "never choose `manifest.autopilot` yourself", and the mandatory-gate table gains the
  in-session "Run-start mode ask" row. `ff-status` now prints the run's mode. Regression
  guard: `scripts/checks/run-start-ask-guard.sh`.

## [0.3.0] — 2026-06-12

Autopilot mode. No breaking changes; pre-v0.3.0 manifests (no `autopilot` field) behave as
step-by-step everywhere — no migration, no mid-run ask.

### Added
- **Autopilot mode**: per-run `manifest.autopilot` boolean — when `true`, ceremonial
  phase-end STOPs become continuations (the assistant chains into the next phase in the
  same turn), pausing only at human gates: spec/diagnosis sign-off, the design option
  choice, an unreproduced bug, and an unresolved Critical review block. Step-by-step
  behavior is unchanged.
- Config `toggles.autopilot` (`"ask"` | `true` | `false`, default `"ask"`): `"ask"` asks
  once at run start (every manifest-creating entry point); the answer is recorded per-run
  and never re-asked.
- Canonical sections in `docs/manifest-schema.md`: **Autopilot** (chaining rule,
  mandatory-pause table, fix-cycle bound, run-start procedure, resume semantics) and
  **Sign-off rendering** (verbatim rule + grouped-checklist format).
- Autopilot Critical-review handling: exactly one fix-and-re-review cycle, recorded in
  `review.md`'s `## Resolution` section (the durable cycle record); then stop if Criticals
  remain.
- Progress strip renders auto-completed phases as `<phase>[auto]`; the strip is emitted
  after each chained phase.

### Changed
- Sign-off asks (`ff-clarify`, full-tier `ff-diagnose`) now render the contract as a
  **grouped checklist** (theme headings, `**AC<n> — <label>**` items, text verbatim) —
  never a blockquote wall.
- A user sign-off on an autopilot run continues the chain in the same turn (the commands
  re-read `manifest.autopilot` from disk when the confirmation arrives).
- `ff-resume` on an autopilot run continues the chain from the resume point to the next
  mandatory pause; step-by-step resume is unchanged (one phase, then stop).
- All 8 phase commands + `ff`, `ff-resume`, and SKILL.md doctrine are mode-conditional;
  the unconditional gate lines (never auto-sign, never pass a sign-off/not-reproduced/
  exhausted-Critical gate) are explicit in both modes.

## [0.2.0] — 2026-06-12

Pre-promotion hardening round. No breaking changes; v0.1.0 run manifests need no migration.

### Added
- `/feature-flow:ff-list` — list all runs (slug, track, tier, phase, dates), including
  abandoned/closed ones.
- `/feature-flow:ff-abandon <slug>` — mark a run abandoned; abandoned runs are excluded from
  automatic run resolution.
- `/feature-flow:ff-close <slug>` — close a completed (`done`) run; closed runs are excluded
  from automatic run resolution.
- `templates/explore.md` — structure contract for the explore artifact.
- `templates/plan-bugfix.md` — bugfix-track plan template (diagnosis gate, test-first Task 1).
- Manifest fields: `closedAt`; `currentPhase` value `abandoned`.
- Canonical sections in `docs/manifest-schema.md`: Disk inference procedure, Re-run guard,
  Progress strip.
- Config: `diagnosticianAgents` (default 1).
- Sign-off asks now quote the contract inline: `ff-clarify` quotes the spec's acceptance
  criteria verbatim; `ff-diagnose` (full tier) quotes the fix approach + contract items.

### Changed
- `models.*` config is now honored: every agent-dispatching command passes `models.<role>` as
  the dispatched agent's model.
- Run resolution excludes abandoned/closed runs; ambiguity prompts list
  `slug | track | currentPhase | updatedAt` per candidate.
- `ff-resume` validates manifest claims against disk (artifact existence + minimal validity)
  instead of trusting `status: complete`.
- `ff-status` performs its own disk inference on a missing/corrupt manifest, labeled
  `[inferred from disk]`.
- Every phase command: re-run guard on already-complete phases; progress strip in every
  STOP/hand-off message.
- `ff-review` (feature track) now blocks on Critical findings instead of routing to verify;
  bugfix branch routes to `ff-verify` when verify hasn't run yet.
- `ff-implement` gates on `design.md` (feature cold-start) and states that `toggles.tdd`
  never applies to the bugfix track.
- `ff-design` / `ff-plan` / `ff-diagnose` gained prescribed quoted gate-failure messages.
- `ff-verify` cold-start routes to `ff-clarify`/`ff-diagnose` instead of asking an open question.
- `ff.md` delegates the explore procedure to `ff-explore.md` (duplication eliminated).
- `ff-clarify` fill-list now includes the spec's Constraints section.
- README rewritten: worked example, configuration reference, command table, teammate vs
  author install, troubleshooting.

### Fixed
- `plugin.json`: added `repository`; `marketplace.json`: real plugin description.

## [0.1.0] — 2026-06-11

Initial release: feature track (explore → clarify → design → plan → implement → review →
verify) and test-first bugfix track (diagnose → implement RED→GREEN → verify → review),
durable `.feature-flow/<slug>/` run state, soft gates, read-only analysis agents, executed
verification via `ff-test-runner`.
