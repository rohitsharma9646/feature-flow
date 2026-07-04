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
  "lock": null,
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
`models.{explorer,architect,reviewer,diagnostician,testRunner}`; `reviewThreshold`;
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

## Enforcement (Claude Code)

Two manifest transitions are **machine-enforced** by a `PreToolUse` hook
(`hooks/enforce-gate`), on by default (`toggles.enforce: true`):

- **Gate A** — a write that enters `implement` (`currentPhase: "implement"`, or
  `phases.implement.status` advanced) is **denied** unless the track's sign-off precondition
  holds: `signOff.signed == true` (feature / bugfix-full) or `phases.diagnose.status == "complete"`
  (bugfix-lite).
- **Gate B** — a write that sets `currentPhase: "done"` is **denied** unless the proposed
  terminal phase(s) are `complete` AND the artifact(s) named by `artifacts.verify` (feature) or
  `artifacts.verify` + `artifacts.review` (bugfix) exist on disk, are non-empty, and contain a
  markdown heading.

The hook is **fail-open**: it denies only a determinate-illegal transition and otherwise allows
(no manifest write · `jq` absent · unparseable proposed manifest · missing `track`/`currentPhase`
· `toggles.enforce: false`). It is **Claude-Code-only** — the Codex package excludes `hooks/`, so
Codex runs the same workflow under the **prose** gates (the hook backstops the prose; it does not
replace it). Kill switch: set `toggles.enforce: false` in `.feature-flow.json`. Behavioral test:
`scripts/checks/enforce-gate-guard.sh`.

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

## Terminal convergence (which command marks a run `done`)

Independent of the KB — this governs **every** run, including KB-off ones. A run reaches
`currentPhase = "done"` at its **done-transition**: the single command that completes the run's
**last** required phase. By track:

- **Feature:** review runs **before** verify, so **verify is terminal** — `ff-verify` is always
  the done-transition (it sets `done` once every acceptance criterion passes).
- **Bugfix:** verify and review may run in **either order**; the done-transition is **whichever
  runs second**. The command that finds the other phase already `complete` is the one that sets
  `done`; the command that runs first hands off instead (or, in autopilot, chains). This is
  enforced by each command reading the other's status — `ff-verify` checks
  `phases.review.status`, `ff-review` checks `phases.verify.status` — so neither sets `done` early.

The done-transition is the **single** point where the KB **capture** gate fires (exactly once —
see **Knowledge base** §Capture rule below), which is why the bugfix track never double- or
zero-captures. This section is the canonical statement of the rule; §Capture rule and the two
terminal commands (`ff-verify`, `ff-review`) **reference** it rather than restating it.

## Knowledge base

The Knowledge base (KB) closes feature-flow's learning loop: it **captures** each finished run's
architectural decisions / project conventions as committed, project-local markdown entries, and
**recalls** matching entries into the `explore`, `design`, and `diagnose` fan-outs of later runs —
stale ones flagged, never silently presented as fresh. This is the single canonical contract; the
five hooked commands (`ff-verify`, `ff-review`, `ff-explore`, `ff-design`, `ff-diagnose`) reference
this section by name and never restate it inline. It is the same house style as **Durable artifact
resolution** above.

### Activation (on by default; opt out with `toggles.kb: false`)

The KB is **active iff `toggles.kb === true` AND `paths.kb` is non-null** (defense-in-depth: a
half-configuration skips cleanly, never errors). Both ship active since v0.8.0; setting either
off in `.feature-flow.json` — `toggles.kb: false` or `paths.kb: null` — cleanly deactivates the
KB: capture and recall become skipped no-ops and every hooked phase behaves as if the KB did not
exist. Config keys (`config/defaults.json`, overridable in `.feature-flow.json`):

- `toggles.kb` (default `true`) — master switch; set `false` to opt out.
- `paths.kb` (default `".feature-flow-kb"`) — store directory, **relative to repo root**;
  `null` also deactivates. The KB is **cross-run**:
  it is resolved from config, NOT under `paths.durable`, and NOT added to `manifest.artifacts`
  (which is per-run only).
- `kb.freshnessWindowDays` (default `90`) — age-based staleness window.
- `kb.maxRecallEntries` (default `5`) — recall surfacing cap.

### Store layout + path resolution

When active, each accepted entry is written **one file per entry** at
`<paths.kb>/<YYYY-MM-DD>-<runSlug>-<short-title>.md` (`<YYYY-MM-DD>` = capture date; `<short-title>`
= a kebab slug of the entry title). **No index file in v1** — recall `Glob`s the store directory and
reads each entry's frontmatter. (The index's only real payoff is the dedup/supersession seam, which
is deferred — see v1 non-goals; the fast-follow adds the index when it adds dedup.) The store
directory is `mkdir -p`'d on first write.

### Entry schema

Entries are written from `templates/kb-entry.md`. Frontmatter fields (all required; provenance is
the point):

- `title` — one-line decision/convention name.
- `captureDate` — `YYYY-MM-DD`, the date the entry was captured.
- `captureCommitSha` — `git rev-parse HEAD` at capture, or `null` (not a git repo / `git rev-parse`
  fails / Codex degrade). Recorded for provenance and a future commit-distance refinement; v1's
  staleness trigger does **not** use it.
- `runSlug` — the capturing run's slug.
- `tags` — 1–3-word topic nouns (user-editable at the capture gate); the recall match key.
- `referencedFiles` — repo-relative paths this entry depends on; the staleness referent set.

Body sections: **Decision/convention**, **Why**, **Referenced artifacts**, **Scope**.

### Capture rule (confirm-gated, at the done-transition)

Capture fires **once per run, at whichever command sets `currentPhase="done"`** (the run-completion
convergence), sequenced **after** that phase's artifact + manifest update but **before**
`currentPhase="done"`, so a dropped session stays recoverable (the command re-runs and re-fires the
gate). Capture fires at the run's **done-transition** — defined once in **Terminal convergence**
above. The only capture-specific detail: `ff-review` carries a **feature-track guard** — on the
feature track review precedes verify, so `ff-review` skips capture and it happens at `ff-verify`.
Firing only at the done-transition guarantees capture happens exactly once and never
double-captures.

When active, the command reaching the done-transition:

1. Reads the run's artifacts via **`manifest.artifacts.<name>`** pointers (`spec`/`diagnosis`,
   `design` and `plan` if present, `verify`, `review`) — never bare filenames.
2. Captures `git rev-parse HEAD` inline → `captureCommitSha` or `null` on failure (never blocks).
3. Distills **1–3 candidate entries**, biased to architectural decisions + project conventions
   (lessons/pitfalls are opt-in), auto-proposing `tags` + `referencedFiles`.
4. **CONFIRM GATE (cross-turn, mandatory in both modes):** presents the candidates; the user
   accepts / edits / rejects each. **Nothing is written until the user confirms.**
5. For each accepted entry: `mkdir -p <paths.kb>` and `Write` the file from the template.
   **feature-flow performs no `git add` / `git commit`** (write-only doctrine — the user commits).
6. Reject-all / none proposed → write nothing; the run completes without error → `currentPhase="done"`.

### Recall rule (wired into explore, design, and diagnose)

Recall runs **before the agent fan-out** in `ff-explore` (before the explorer dispatch),
`ff-design` (after the sign-off gate, before the architect dispatch), and `ff-diagnose`
(before the diagnostician dispatch). When active:

1. `Glob <paths.kb>/*.md`. **Empty store** → print a one-line note and proceed normally (no error).
2. Extract keywords from `$ARGUMENTS` (for diagnose that is the bug report; for design, also the
   spec's `## Problem` resolved via `manifest.artifacts.spec`) and **tag-match** them against each
   entry's `tags` frontmatter.
3. Run the staleness check (below) on each match.
4. Surface up to `kb.maxRecallEntries` matches (recency-ordered by `captureDate`) to the fan-out
   agents as appended context — fresh entries plain, stale entries decorated (never dropped).
   **No match** → one-line note, proceed.

### Staleness rule

An entry is **stale** if **any** of its `referencedFiles` is missing/moved **OR** the entry is
older than `kb.freshnessWindowDays` (default 90, measured from `captureDate`). Staleness is computed
inline (no agent). A stale entry is **flagged, not suppressed**: surfaced to the agents decorated
`[STALE — <reason>]` (e.g. `[STALE — referenced file src/foo.ts missing]` / `[STALE — 120d old,
window 90d]`) — never silently dropped and never presented as current truth. `captureCommitSha` is
**not** part of the v1 trigger (provenance only).

### Codex degrade table

| Capability | Claude Code | Codex / non-git degrade |
|---|---|---|
| `captureCommitSha` (`git rev-parse HEAD` via inline `Bash`) | recorded | `null`; entry still written |
| Staleness referent check (`Read`/`Glob`) | file-existence + age | falls back to **referent-existence only** if `Glob`/`Read` unavailable; age check always applies |
| Tag-match recall + confirm gate | native | **platform-neutral** — no degrade |

### v1 non-goals (honest deferral)

Deferred to a fast-follow run, stated here, in the SKILL, and the README so the gap is explicit
(not silent): **dedup** of new entries against existing, **supersession** (newer marks older
superseded), an **`index.json`** query surface, a standalone ad-hoc **`ff-learn`** command,
**content-similarity / referenced-file-overlap relevance** (v1 is tag-match only), **mid-run /
continuous capture** (capture fires once, at run completion), **auto-committing** entries, and a
**cross-project / global KB** (v1 is project-scoped). Duplicate insights across runs therefore
persist — accepted v1 limitation, surfaced not silently dropped.

## Autopilot

`manifest.autopilot: true` makes ceremonial phase-end STOPs **continuations**: after
completing a phase (artifact written, manifest updated — **never batched**, so a dropped
session stays recoverable by `ff-resume` at the first incomplete phase), emit the progress
strip, then read `${CLAUDE_PLUGIN_ROOT}/commands/ff-<next-phase>.md` and execute it in the
same turn, exactly as written — no abbreviation, no improvisation. `false` **or absent** →
step-by-step: every STOP ends the turn (v0.2.0 behavior, unchanged).

**Ceremonial boundaries (chain through these):**
- feature: explore → clarify; post-sign-off → design → plan → implement → review → verify
- feature lite: explore → clarify; post-sign-off → implement → review → verify
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
| KB capture confirm-gate (`ff-verify` feature-terminal / `ff-review` bugfix-terminal), only when `toggles.kb` active | cross-turn | distill candidates, end the turn for the user to accept/edit/reject; never write entries unconfirmed; chain resumes to `currentPhase="done"` on the answer or `ff-resume` — see §Knowledge base |
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
