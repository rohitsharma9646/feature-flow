# Manifest contract — `.feature-flow/<slug>/manifest.json`

Every feature-flow command reads and writes this file. It is the single shared,
durable state object for a run. Defining it here once means every phase command
obeys the same contract instead of inventing its own state shape — this is what
makes phases composable, standalone-runnable, and resumable from disk.

## Topic index

The core (this file) holds the rules every command uses. Each other topic lives in its own file
under `docs/schema/`; a `§Name` reference in any rule resolves through this table. Read the core
plus only the topic files the current command names — by path or by `§Name`/`**Name**`. Paths are
relative to the plugin root (`${CLAUDE_PLUGIN_ROOT}`, the directory holding this `docs/`), never to
the project you are working in.

| Topic | File | What it covers |
|---|---|---|
| Evidence | `docs/schema/evidence.md` | Evidence kinds, record shape, Confidence ladder, tier scaling, evidence-gap stop and waiver. |
| Enforcement (Claude Code) | `docs/schema/enforcement.md` | Claude Code hooks: the PreToolUse gates (A: implement needs sign-off, B: done needs evidence) and the SessionStart re-anchor. |
| Disk inference procedure | `docs/schema/disk-inference.md` | Rebuilding phase state from artifacts on disk when the manifest is missing or corrupt. |
| Sign-off rendering | `docs/schema/sign-off-rendering.md` | How a sign-off gate shows the contract: grouped checklists, the assumptions echo. |
| Terminal convergence | `docs/schema/terminal-convergence.md` | Which command marks a run `done`, per track. |
| Knowledge base | `docs/schema/knowledge-base.md` | KB capture and recall, staleness, decision recall. |
| Planning intelligence | `docs/schema/planning-intelligence.md` | Plan dependency graph, critical path, risk register. |
| Task controller | `docs/schema/task-controller.md` | Executable plans; `ff-implement`'s per-task implementer, review, fix loop and ledger. |
| Assumption records | `docs/schema/assumption-records.md` | Assumption tables, the validation stop, waivers, actuations. |
| Design trade-offs & devil's advocate | `docs/schema/design-tradeoffs.md` | Trade-off matrix, failure scenarios, devil's advocate. |
| Discovery fields | `docs/schema/discovery-fields.md` | Success metrics, AC dependencies, touchpoints, the end-to-end check. |
| Autopilot | `docs/schema/autopilot.md` | Run-start ask, chaining, mandatory pauses, fix and repair cycles. |
| Delivery | `docs/schema/delivery.md` | The optional delivery report. |
| Retrospective | `docs/schema/retrospective.md` | The optional post-done retrospective. |

## Schema

```json
{
  "slug": "add-oauth",
  "track": "feature | bugfix",
  "tier": "full | lite",
  "createdAt": "<ISO8601>",
  "updatedAt": "<ISO8601>",
  "closedAt": null,
  "autopilot": false,
  "revisionBound": true,
  "currentPhase": "explore|clarify|design|plan|diagnose|implement|review|verify|done|abandoned",
  "phases": {
    "<phase>": { "status": "pending|in_progress|complete", "artifact": "<relative path or null>" },
    "review":  { "status": "complete", "artifact": "review.md", "revision": "<git tree id or null>" },
    "verify":  { "status": "complete", "artifact": "verify.md", "revision": "<git tree id or null>" }
  },
  "signOff": { "required": true, "signed": false, "date": null },
  "lock": null,
  "bugfix": {
    "red":   { "command": "<test cmd>", "exit": 1, "evidence": "<failing output, pre-fix>" },
    "green": { "command": "<test cmd>", "exit": 0, "evidence": "<passing output, post-fix>" }
  },
  "artifacts": {
    "spec": "spec.md",
    "design": "design.md",
    "decision": "decision.md",
    "diagnosis": "diagnosis.md",
    "plan": "plan.md",
    "review": "review.md",
    "verify": "verify.md",
    "ledger": ".feature-flow/add-oauth/tasks/ledger.md"
  }
}
```

## Field notes

- **`track`** and **`tier`** are set by `/ff` at classification time, or by the first
  standalone command run if a phase command is invoked directly with no manifest yet.
  - `track: feature` → phases: explore → clarify → design → plan → implement → review → verify.
  - `track: feature`, `tier: lite` → phases: explore → clarify → implement → review → verify
    (skips design + plan; 1-agent explore).
  - `track: bugfix` → phases: diagnose → implement (test-first) → verify → review.
- **`tier`**: `full` (larger work; requires a signed-off `spec.md`/`diagnosis.md` and a `plan.md`)
  vs `lite` (small/obvious work). A lite **bugfix** uses a confirmed `diagnosis.md` as the gate
  with no separate sign-off; a lite **feature** keeps sign-off but skips the design + plan phases
  and uses a 1-agent explore (`explore → clarify → implement → review → verify`).
- **`currentPhase`** is the phase most recently entered; `done` when the run is complete;
  `abandoned` when the run was cancelled via `/feature-flow:ff-abandon`. An abandoned run is
  **excluded from automatic run resolution** (steps 3–4 below); its phases and artifacts are
  left untouched, and it remains reachable by explicit slug.
- **`closedAt`** (ISO8601 or `null`): set by `/feature-flow:ff-close` on a `done` run. A closed
  run is **excluded from automatic run resolution**. Absent/`null` in older (v0.1.0) manifests
  — treat as not closed; no migration needed.
- **`autopilot`** (boolean): whether this run chains phases automatically — see **Autopilot**
  below. Set **once** at run start by the run-start procedure, read-only afterwards. **Absent
  field = `false`** (every pre-v0.3.0 manifest): treat as step-by-step everywhere — no error,
  no mid-run ask, no migration.
- **`revisionBound`** (boolean, added v0.22.0): this run binds review and verify to one code
  revision — see **Enforcement (Claude Code)** in `docs/schema/enforcement.md` (Gate B, §Revision
  fingerprint) and **Revision agreement** in `docs/schema/terminal-convergence.md`. Written
  `true` **once** at manifest creation by every entry point that creates a manifest (`ff`, and the
  cold-start paths of `ff-explore` / `ff-clarify` / `ff-diagnose`), alongside `autopilot`; never
  changed afterwards. **Absent field = not revision-bound** (every pre-v0.22.0 manifest): no revision
  is stamped or checked, Gate B behaves exactly as in v0.21.0 — no error, no migration.
- **`phases.review.revision`** / **`phases.verify.revision`** (added v0.22.0, revision-bound runs
  only): the working-tree fingerprint (a git tree id, §Revision fingerprint) the phase attested,
  written by `ff-review` / `ff-verify` when the phase completes — after any in-phase fix or repair
  cycle — and overwritten on every re-run. `null` = not a git repository, or the fingerprint could
  not be computed (the artifact's `**Revision:**` line says why). Absent = the phase has not
  completed on a revision-bound run, or the run predates v0.22.0.
- **`phases.<phase>.artifact`** holds the resolved path of the artifact that phase produced
  (or `null` if it writes no file, e.g. explore may summarize inline). It is a
  **human-readable display mirror only — no command uses it to locate a file**;
  `manifest.artifacts.<name>` (below) is the sole locating authority. The two are kept in
  sync, but reads trust `artifacts.<name>`.
- **`signOff`**: feature track and escalated (`full`) bugfixes require sign-off before
  `/ff-implement` may write code. Lite bugfixes set `required: false`. The manifest's
  `signOff.signed` is **authoritative**; the `User signed off:` line in `spec.md`/`diagnosis.md`
  is a human-readable **mirror**. If the two ever disagree (a hand-edit or partial resume),
  trust the manifest and offer to re-sync the document line.
- **`lock`** (advisory; `null`/absent = unlocked — any manifest written before this field
  existed): a soft
  concurrency guard, `{ "owner": "<short session/run label>", "acquiredAt": "<ISO8601>" }`
  when held. It is **advisory, not a kernel lock** — see **Manifest write safety** below for
  the acquire / release / stale-takeover rules. Absent field = unlocked; no migration.
- **`bugfix`** (bugfix track only): the test-first evidence. `/ff-implement` writes
  `red` when the regression test fails pre-fix and `green` after the fix passes;
  `/ff-verify` cites both for the RED→GREEN contract. A run with no `bugfix.red`
  recorded was not done test-first and `/ff-verify` reports it incomplete.
- **`artifacts`** maps logical names to the file path each phase wrote. `artifacts.<name>` is
  the **sole authority** for locating an artifact — every read (implement, status, resume,
  disk-inference) resolves through it.
- **`artifacts.ledger`** (added v0.23.0): the task ledger `ff-implement`'s controller keeps at
  `<run dir>/tasks/ledger.md`, recorded as its resolved repo-relative path
  (`<base>/<slug>/tasks/ledger.md`) — written when the ledger is created, before the first task is
  dispatched, so a resumed or compacted session finds it. Absent = the run implemented inline (lite
  tier, or a plan without `## Global Constraints`). Ephemeral: never promoted. Format and resume rule:
  **Ledger** in `${CLAUDE_PLUGIN_ROOT}/docs/schema/task-controller.md`.
- **`artifacts.decision`** (added v0.10.0): the resolved path of the run's decision record —
  written by `ff-design` on the **full** tier (a promoted `decision.md`), or set by
  `ff-clarify` to the **spec's** path on the **lite** tier (the spec's inline `## Solution
  approaches considered` *is* the lite decision record). **Dual-shaped:** full → a
  `decision.md`-shaped file, lite → a `spec.md`-shaped file — a consumer that globs/parses
  `artifacts.decision` targets must not assume a uniform shape. **Absent field = no decision
  recorded** (every pre-v0.10.0 manifest, and any run whose design predates this field): treat
  as "this run has no decision artifact" — no error, no migration; `ff-status`/disk-inference
  report it as not-present, never missing-and-invalid.
- **`phases.deliver`** and **`artifacts.delivery`** (added v0.12.0): the optional, post-`done`
  delivery phase's status and the resolved path of its `delivery.md`. Both are **absent-defaulted**:
  absent `phases.deliver` = the run predates delivery or never ran it (treat as an optional,
  not-yet-run phase — never missing-and-invalid); absent `artifacts.delivery` = no delivery artifact
  recorded. `currentPhase` **stays `done`** throughout delivery and the enum is not extended — see
  §Delivery for the full contract. No migration; every pre-v0.12.0 manifest resolves and resumes unchanged.
- **`phases.retro`** and **`artifacts.retro`** (added v0.18.0): the optional, post-`done`
  retrospective phase's status and the resolved path of its `retro.md`. Both are **absent-defaulted**
  exactly like `phases.deliver`/`artifacts.delivery`: absent = never ran (an optional, not-yet-run
  phase — never missing-and-invalid). `currentPhase` **stays `done`** and the enum is not extended —
  see §Retrospective. No migration.

  **Durable artifact resolution.** Each producing phase resolves where to write its artifact
  (and records the result) by this rule. Given artifact name `N`, slug `S`, and the run's
  `createdAt` UTC date `D` (`createdAt.split("T")[0]`):

  1. **Legacy per-artifact key wins** (back-compat, never silently changes an existing config):
     - `N = spec` & `paths.spec` set → `<paths.spec>/<S>.md`
     - `N = plan` & `paths.plan` set → `<paths.plan>/<S>.md`
  2. **else `paths.durable` set** → `<paths.durable>/<D>-<S>/<N>.md` — **you MUST create the
     `<paths.durable>/<D>-<S>/` directory before writing** if it does not yet exist.
  3. **else (sandbox default)** → `<base>/<S>/<N>.md`.

  Then record the **resolved actual path** in **both** `manifest.artifacts.<N>` *and*
  `phases.<phase>.artifact` (reads trust `artifacts.<N>`; the phase field is the display
  mirror). `paths.spec` / `paths.plan` values are each a **directory** (relative to the repo
  root), never a full file path — e.g. `paths.spec: "specs"` + slug `add-oauth` →
  `specs/add-oauth.md`.

  - **Durable artifacts** (resolution-eligible — promote when a durable location is configured):
    `spec`, `design`, `decision`, `plan`, `diagnosis`, `verify`, `delivery`, `retro`. They co-locate in one
    `<D>-<S>/` directory even when produced on different calendar days, because `D` derives from `createdAt`.
    (`decision` promotes only on the full tier — it rides alongside `design` in the same
    `<D>-<S>/` dir; on lite, `artifacts.decision` points at the already-promoted `spec` instead.
    `delivery` promotes only when the optional post-`done` `deliver` phase actually runs — see §Delivery;
    `retro` likewise only when the optional post-`done` `retro` phase runs — see §Retrospective.)
    **Evidence companion copy:** `verify` is special — when it promotes, the run's
    `<base>/<S>/evidence/` directory is **copied** alongside to `<paths.durable>/<D>-<S>/evidence/`
    (copy, never move — the sandbox stays the one place `ff-test-runner` clears and writes; on
    re-promotion the destination is **replaced, never merged into**, so stale files and
    `evidence/evidence` nesting cannot occur), so the report's relative `evidence/...` links
    keep resolving and the client report is self-contained.
  - **Ephemeral artifacts** (always step 3 — never promoted): `explore`, `review`,
    `smoke-checklist`, `ledger` (with its `tasks/` directory), and `manifest.json` itself stay in
    `<base>/<S>/`.
  - Promotion is **write-only**: Feature Flow writes the doc into the working tree but never
    runs `git add`/`commit`; the user commits it through their normal flow.

## Config resolution & validation

Every command resolves config the same way: a repo-root `.feature-flow.json` shallow-merges
over `${CLAUDE_PLUGIN_ROOT}/config/defaults.json` (user keys win; unset keys fall through to
the default). **`/feature-flow:ff` — and any cold-start phase command that creates a manifest —
MUST validate the resolved config and surface problems; never silently no-op.** A
misconfiguration that fails silent is the worst outcome for a tool that promises durability.

Validation is advisory: **warn and fall back to the safe default — never hard-fail a run.**

1. **Unknown key.** A top-level or nested key not in the known set below → warn
   `config: unknown key '<key>' in .feature-flow.json — ignored (did you mean '<nearest>'?)`
   and proceed with defaults. Catches the silent-typo footgun: `explorerAgent` (vs
   `explorerAgents`) would otherwise fall through to the default with no signal at all.
2. **Half-configuration.** `toggles.kb: true` (the default) with `paths.kb` explicitly
   `null` → warn
   `config: toggles.kb is true but paths.kb is unset — the knowledge base stays OFF`, then run
   with the KB inactive (the documented defense-in-depth, now surfaced rather than silent).
   Same shape for any feature whose activation needs two coordinated keys.
3. **Type / domain mismatch.** `toggles.autopilot` not one of `"ask" | true | false`; an agent
   count that is not a positive integer; `reviewThreshold` outside 0–100 → warn and fall back
   to that key's default.

**Known keys** (the schema of `defaults.json` — keep in sync when adding a config key):
`explorerAgents`, `architectAgents`, `reviewerAgents`, `diagnosticianAgents`;
`models.{explorer,architect,reviewer,diagnostician,testRunner,implementer,escalation}`; `reviewThreshold`;
`toggles.{tdd,worktree,greenfield,autopilot,kb,enforce}`; `paths.{base,spec,plan,durable,kb}`;
`kb.{freshnessWindowDays,maxRecallEntries}`.

## Run resolution (how every command finds the run before reading the manifest)

All commands resolve the target run the **same way** — this is the canonical rule; phase
commands reference it instead of restating their own:

1. **Resolve the base.** Read config (`.feature-flow.json` →
   `${CLAUDE_PLUGIN_ROOT}/config/defaults.json`); use `paths.base` (default `.feature-flow`)
   as the sandbox root.
2. **Named run wins.** If `$ARGUMENTS` names a slug (or a run dir), use `<base>/<slug>/` —
   this works even for abandoned/closed runs (so inspection commands can reach them). Unknown
   slug → error naming it and suggesting `/feature-flow:ff-list`. Re-entry commands
   (`ff-resume` and the phase commands) still honor their own abandoned/closed guards even
   when the slug is explicit.
3. **Single eligible run.** Otherwise, **exclude runs with `currentPhase: "abandoned"` or a
   non-null `closedAt`** — they are never auto-selected. If exactly one eligible run remains
   under `<base>/`, use it (zero eligible → cold-start, even if abandoned/closed runs exist).
4. **Several eligible runs → most recent, but disambiguate when unclear.** Use the **most
   recently updated** (`updatedAt`) of the eligible runs. If that is genuinely ambiguous
   (e.g. two updated at nearly the same time, or the request clearly points at a different
   run), **ask the user which run** — listing `slug | track | currentPhase | updatedAt` for
   each candidate — rather than guessing.
5. **Cold-start / new run.** An entry or first-phase command starting fresh work instead
   derives a new kebab `slug` from `$ARGUMENTS` and **creates** `<base>/<slug>/`.
6. **Corrupt manifest — never improvise (applies to EVERY command, not just resume/status).**
   If the located run has a `manifest.json` that exists but does **not** parse as JSON, do
   **not** proceed on a guessed state and do **not** overwrite it blind. Apply the **Disk
   inference procedure** below to reconstruct phase state from the artifacts on disk, tell the
   user the manifest was corrupt and exactly what was inferred, and continue from the inferred
   resume point (a mutating phase first rewrites a clean manifest from the inference, then
   proceeds). This was previously honored only by `ff-resume`/`ff-status`; it is now universal
   so a phase command can never act on — or clobber — a corrupt manifest.
7. **Before mutating, apply Manifest write safety.** Once the run is resolved, any command that
   will write the manifest follows **Manifest write safety** below — whole-object atomic write
   plus the advisory `lock` (acquire before the first mutation, release at turn end). Stated
   here, in the universally-referenced resolution rule, so every mutating command inherits it
   (the same way step 6 makes corrupt-manifest handling universal).

## Rules every command MUST follow

1. **Read the manifest first.** If absent, create it (set `slug`, `track`, `tier`,
   `autopilot` — resolved via the **Run-start procedure** in §Autopilot *before* this
   write, never self-chosen — `createdAt`, empty `phases`, `signOff`).
2. **Check the gate** for this phase (e.g. `/ff-implement` requires `signOff.signed`
   on the feature/full track; a confirmed `diagnosis.md` on the lite bugfix track).
   On Claude Code these two gates are additionally **machine-enforced** by the `enforce-gate`
   PreToolUse hook (see **Enforcement** below); on Codex (no hooks) and when `toggles.enforce`
   is `false`, the prose gate is the sole control.
3. **Do the phase work**, reading any required upstream artifacts.
4. **Write the artifact** to the run dir (or the configured override path).
5. **Update the manifest**: set this phase's `status` + `artifact`, bump `updatedAt`
   and `currentPhase`. **Write the whole object atomically and release the lock** — see
   **Manifest write safety** below.

Resume (`/ff-resume`) and status (`/ff-status`) read this file. **Every** command — not
only those two — applies the **Disk inference procedure** below when the manifest is missing
or corrupt (Run resolution step 6); no command may improvise on, or blind-overwrite, a
manifest it could not parse.

## Manifest write safety

The `manifest.json` is the single durable state object and is rewritten on every phase, so
its write is the highest-probability corruption path. Two rules, both mandatory for every
command that mutates it:

1. **Whole-object atomic write.** Always serialize and **Write the complete manifest object
   in one operation** — never a partial line-edit, never an append. A half-applied edit can
   leave the file as invalid JSON; rewriting the whole (small) object each time means the
   file is either the old valid state or the new valid state, never a torn middle. Read →
   mutate in memory → Write the whole thing.

2. **Advisory lock (soft concurrency guard).** Guards against two sessions touching one run
   (e.g. an autopilot chain in one session while the user invokes a phase manually in
   another). It is advisory — prose, not enforced — so it is staleness-self-healing rather
   than blocking:
   - **Before the first mutation of a turn**, read `lock`. If it is set, owned by **another**
     session, and **fresh** (`acquiredAt` within the last 15 minutes), do not write — warn the
     user that run `<slug>` looks active in another session and ask whether to proceed; only
     continue on confirmation. If `lock` is null/absent, **stale** (`acquiredAt` older than 15
     minutes — assume the prior session died), or already yours, take it: set
     `lock = { owner, acquiredAt: <now> }` as part of that same whole-object Write.
   - **Release at the natural turn end** (phase complete / STOP / hand-off): set `lock = null`
     in the final whole-object Write. A dropped session leaves a lock behind; the 15-minute
     staleness rule reclaims it automatically, so a crash never wedges a run.
   - `lock` is **advisory and back-compatible**: a manifest without the field is simply
     unlocked. Never block a run solely because the field is missing.

## Re-run guard

Before re-entering a phase whose `status` is already `"complete"`, a command **must ask for
explicit user confirmation**, naming what will be overwritten (the artifact) and what will be
reset (e.g. `signOff.signed` when re-running clarify). Without confirmation, stop and leave
the phase unchanged. This protects a signed spec from a silent sign-off reset.

## Progress strip

Every phase command's STOP / hand-off message ends with a one-line strip generated from
`manifest.phases`, in the track's phase order: completed phases as `<phase>[done]`, the next
phase to run as `<phase>[NEXT]`, later phases as bare names, joined by ` → `. Example:

    explore[done] → clarify[done] → design[NEXT] → plan → implement → review → verify

`[NEXT]` marks the next command to run, regardless of the phase's position in the canonical
order (e.g. a bugfix where review ran before verify renders `verify[NEXT]`). The
`<slug>[abandoned]` / `<slug>[closed]` rendering applies **only** to `ff-list`/`ff-status`
output; abandoned/closed early-exit STOP messages emit no strip (those runs execute no
phases).

**Fresh-context hint.** On a **step-by-step phase-end hand-off** — the phase completed and the
message tells the user which phase command to run next — add one line after the strip:

    Fresh context: `/clear`, then `/feature-flow:ff-<next>` — the run's state is on disk.

A phase re-reads everything it needs from the manifest and artifacts, so the next phase loses
nothing by starting clean and gains a context free of this phase's exploration and tool output
(on Claude Code the SessionStart hook re-lists the active run after `/clear` — §Enforcement →
Session re-anchor). The hint is **never in autopilot** (the chain continues in-session), **never
at a sign-off, decision, or blocking pause** (the user answers those in the same session —
clearing would drop the question), and never on a run-complete (`done`) report.

**In autopilot** (`manifest.autopilot: true`): phases completed automatically (chained,
not user-invoked) render `<phase>[auto]` instead of `<phase>[done]` — derived at render
time, no manifest field records it (in an autopilot run, only the entry phase and phases
re-entered after a pause were user-invoked). Emit the strip after **each** auto-completed
phase so the chain is followable as it runs; full STOP messaging appears only at mandatory
pauses and at run completion. Example mid-chain:

    explore[done] → clarify[auto] → design[auto] → plan[NEXT] → implement → review → verify

