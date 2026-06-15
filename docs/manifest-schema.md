# Manifest contract — `.feature-flow/<slug>/manifest.json`

Every feature-flow command reads and writes this file. It is the single shared,
durable state object for a run. Defining it here once means every phase command
obeys the same contract instead of inventing its own state shape — this is what
makes phases composable, standalone-runnable, and resumable from disk.

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
  "currentPhase": "explore|clarify|design|plan|diagnose|implement|review|verify|done|abandoned",
  "phases": {
    "<phase>": { "status": "pending|in_progress|complete", "artifact": "<relative path or null>" }
  },
  "signOff": { "required": true, "signed": false, "date": null },
  "bugfix": {
    "red":   { "command": "<test cmd>", "exit": 1, "evidence": "<failing output, pre-fix>" },
    "green": { "command": "<test cmd>", "exit": 0, "evidence": "<passing output, post-fix>" }
  },
  "artifacts": {
    "spec": "spec.md",
    "design": "design.md",
    "diagnosis": "diagnosis.md",
    "plan": "plan.md",
    "review": "review.md",
    "verify": "verify.md"
  }
}
```

## Field notes

- **`track`** and **`tier`** are set by `/ff` at classification time, or by the first
  standalone command run if a phase command is invoked directly with no manifest yet.
  - `track: feature` → phases: explore → clarify → design → plan → implement → review → verify.
  - `track: bugfix` → phases: diagnose → implement (test-first) → verify → review.
- **`tier`**: `full` (larger work; requires a signed-off `spec.md`/`diagnosis.md` and a `plan.md`)
  vs `lite` (trivial/obvious bug; a confirmed `diagnosis.md` is the gate, no separate signed spec).
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
- **`bugfix`** (bugfix track only): the test-first evidence. `/ff-implement` writes
  `red` when the regression test fails pre-fix and `green` after the fix passes;
  `/ff-verify` cites both for the RED→GREEN contract. A run with no `bugfix.red`
  recorded was not done test-first and `/ff-verify` reports it incomplete.
- **`artifacts`** maps logical names to the file path each phase wrote. `artifacts.<name>` is
  the **sole authority** for locating an artifact — every read (implement, status, resume,
  disk-inference) resolves through it.

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
    `spec`, `design`, `plan`, `diagnosis`. They co-locate in one `<D>-<S>/` directory even when
    produced on different calendar days, because `D` derives from `createdAt`.
  - **Ephemeral artifacts** (always step 3 — never promoted): `explore`, `review`, `verify`,
    `smoke-checklist`, and `manifest.json` itself stay in `<base>/<S>/`.
  - Promotion is **write-only**: Feature Flow writes the doc into the working tree but never
    runs `git add`/`commit`; the user commits it through their normal flow.

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

## Rules every command MUST follow

1. **Read the manifest first.** If absent, create it (set `slug`, `track`, `tier`,
   `autopilot` — resolved via the **Run-start procedure** in §Autopilot *before* this
   write, never self-chosen — `createdAt`, empty `phases`, `signOff`).
2. **Check the gate** for this phase (e.g. `/ff-implement` requires `signOff.signed`
   on the feature/full track; a confirmed `diagnosis.md` on the lite bugfix track).
3. **Do the phase work**, reading any required upstream artifacts.
4. **Write the artifact** to the run dir (or the configured override path).
5. **Update the manifest**: set this phase's `status` + `artifact`, bump `updatedAt`
   and `currentPhase`.

Resume (`/ff-resume`) and status (`/ff-status`) read this file. If the manifest is
missing or corrupt, they apply the **Disk inference procedure** below.

## Disk inference procedure

Used by `/ff-resume` and `/ff-status` when the manifest is missing/corrupt, or to validate a
manifest that claims phases are complete:

1. Walk the track's phase order — feature: explore(`explore`) → clarify(`spec`) →
   design(`design`) → plan(`plan`) → implement(no artifact) → review(`review`) →
   verify(`verify`); bugfix: diagnose(`diagnosis`) → implement(no artifact) →
   verify(`verify`) → review(`review`).
2. **Resolve each phase's artifact path before checking existence.** When the manifest is
   present, take the path from `manifest.artifacts.<name>` (the sole locating authority) — so a
   doc promoted to `<paths.durable>/<D>-<slug>/` is checked at its real path, never mis-marked
   missing because it left the sandbox. When the manifest is **lost**, resolve by applying the
   **Durable artifact resolution** rule to config: infer the slug from the run-dir name, then
   for each durable artifact use `<paths.durable>/<D>-<slug>/<name>.md` (or the legacy
   `paths.spec`/`paths.plan` location); if `createdAt` — hence `<D>` — is unrecoverable, do a
   **bounded glob `<paths.durable>/*-<slug>/`** (most-recently-modified on ties), scoped to
   `paths.durable` only — never a repo-wide scan. Ephemeral artifacts always resolve to
   `<base>/<slug>/<name>.md`.
3. For each phase marked `complete` (or, with no manifest, each phase in order): the resolved
   artifact must **exist on disk** AND pass **minimal validity** — `spec.md` must contain a
   `User signed off:` line; `diagnosis.md` must contain a `**Status:**` line reading
   `confirmed` or `signed-off` (a draft-status diagnosis fails validity); all
   other artifacts: existence suffices.
4. The first phase whose artifact is missing or invalid is the true resume point. Announce
   why: "manifest claims complete but artifact missing: `<path>`" or "artifact failed validity
   check: `<path>`".

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

**In autopilot** (`manifest.autopilot: true`): phases completed automatically (chained,
not user-invoked) render `<phase>[auto]` instead of `<phase>[done]` — derived at render
time, no manifest field records it (in an autopilot run, only the entry phase and phases
re-entered after a pause were user-invoked). Emit the strip after **each** auto-completed
phase so the chain is followable as it runs; full STOP messaging appears only at mandatory
pauses and at run completion. Example mid-chain:

    explore[done] → clarify[auto] → design[auto] → plan[NEXT] → implement → review → verify

## Sign-off rendering

How `ff-clarify` (spec sign-off) and `ff-diagnose` (full-tier diagnosis sign-off) present
the contract in the sign-off ask. Two rules, both mandatory:

1. **Verbatim.** The ask quotes the contract items exactly as written in the artifact —
   the spec's acceptance criteria / the diagnosis's fix approach, root cause, fix surface,
   and regression-test plan. The user reviews exactly what they are signing without opening
   the file; a summary is not a substitute.
2. **Grouped checklist, never a blockquote wall.** Render the items as a plain-markdown
   checklist grouped under short theme headings — **not** inside a `>` blockquote:
   - 3–6 theme headings (`### <Theme>`), chosen by subject-matter clustering at ask time;
     aim for ≤ ~5 items per group.
   - Each item: `- [ ] **AC<n> — <short label>**: <criterion text verbatim>` (diagnosis
     contracts use `**<item name>**` instead of an AC number).
   - The label is additive; the criterion text after the colon stays verbatim (rule 1).

Example shape:

    ### Switch & defaults
    - [ ] **AC1 — config key**: `config/defaults.json` contains `toggles.autopilot` …
    - [ ] **AC2 — run-start ask**: When a new run starts and resolved `toggles.autopilot` …

    ### Chaining behavior
    - [ ] **AC6 — boundaries chain**: With `autopilot: true`, every ceremonial phase …

## Autopilot

`manifest.autopilot: true` makes ceremonial phase-end STOPs **continuations**: after
completing a phase (artifact written, manifest updated — **never batched**, so a dropped
session stays recoverable by `ff-resume` at the first incomplete phase), emit the progress
strip, then read `${CLAUDE_PLUGIN_ROOT}/commands/ff-<next-phase>.md` and execute it in the
same turn, exactly as written — no abbreviation, no improvisation. `false` **or absent** →
step-by-step: every STOP ends the turn (v0.2.0 behavior, unchanged).

**Ceremonial boundaries (chain through these):**
- feature: explore → clarify; post-sign-off → design → plan → implement → review → verify
- bugfix lite: diagnose → implement → verify → review
- bugfix full: post-sign-off → plan → implement → verify → review

**Mandatory pauses — gates are physics, not preference; autopilot never skips, overrides,
or self-answers a gate:**

| Gate | Type | Behavior in autopilot |
|---|---|---|
| Spec sign-off (`ff-clarify`) | cross-turn | end the turn with the sign-off ask (**Sign-off rendering** above); never set `signOff.signed` yourself; chain resumes on the user's confirmation or `ff-resume` |
| Diagnosis sign-off, full tier (`ff-diagnose`) | cross-turn | same as spec sign-off |
| Not-reproduced stop (`ff-diagnose`) | cross-turn | ends the chain unconditionally — autopilot does not retry |
| Critical review block (`ff-review`) | cross-turn | one fix-and-re-review cycle (below), then stop if Criticals remain |
| Design option choice (`ff-design`) | in-session | ask (AskUserQuestion), then continue the chain in the same turn |
| Run-start mode ask (every manifest-creating entry point, config `"ask"`) | in-session | resolve BEFORE the manifest write: ask (AskUserQuestion), then write the manifest including the answer — never choose `manifest.autopilot` yourself |
| Clarify interrogation questions | in-session | ask, then continue |
| Run disambiguation / re-run guard confirmations | in-session | ask, then continue |

Any **gate failure** mid-chain (missing artifact, unsigned contract, wrong track) stops the
chain with that gate's existing prescribed message — routing back, never forward.

**Fix-and-re-review cycle (Critical findings, autopilot only).** Before starting a cycle,
check `review.md` for an existing `## Resolution` section recording a prior autopilot fix
cycle — the review artifact is the durable cycle record (it survives session drops). No
prior cycle → apply fixes for the Critical findings, append the Resolution record (pre-fix
findings, fixes applied, outcome), and re-run the review dispatch **once**. A prior cycle
exists, or Criticals remain after the re-review → emit the standard Critical-block message
and end the turn. `phases.review.status` stays `in_progress` until the review is clear.
Zero Critical findings → no cycle; chain proceeds.

**Run-start procedure (every entry point that creates a manifest: `ff`, and the cold-start
paths of `ff-explore` / `ff-clarify` / `ff-diagnose`).** The value is resolved
**before the manifest is written** — the creation Write includes `autopilot`; a manifest
written with a self-chosen `autopilot` is a defect:
1. If a manifest for this run already exists with an `autopilot` field (any value) →
   **skip; never re-ask** — not on resume, re-run, or any later phase.
2. Read `toggles.autopilot` from config (`.feature-flow.json` →
   `${CLAUDE_PLUGIN_ROOT}/config/defaults.json`; default `"ask"`).
3. `"ask"` → ask the user once (AskUserQuestion): **autopilot** (phases chain automatically,
   pausing only at sign-offs, design choice, and Critical review findings) vs
   **step-by-step** (each phase stops; current behavior). `true` / `false` → use that value
   directly; no question. The boolean may come ONLY from config `true`/`false` or the
   user's in-conversation answer — **never choose `manifest.autopilot` yourself**; include
   it in the manifest creation Write.

**Resume.** `ff-resume` on a run with `autopilot: true` re-enters the first incomplete
phase and **continues the chain** to the next mandatory pause, honoring every gate exactly
as a live run would. With `false`/absent: run exactly one phase and stop (unchanged).
