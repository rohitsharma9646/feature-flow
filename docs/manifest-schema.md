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
    "decision": "decision.md",
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
    `smoke-checklist`, and `manifest.json` itself stay in `<base>/<S>/`.
  - Promotion is **write-only**: Feature Flow writes the doc into the working tree but never
    runs `git add`/`commit`; the user commits it through their normal flow.

## Evidence

The single canonical contract for **evidence-based verification**: what counts as evidence,
how confidence is derived, and when a run may not reach `done`. `commands/ff-verify.md`,
`agents/ff-test-runner.md`, and `templates/verify.md` reference this section by name and never
restate it — same house style as **Durable artifact resolution** above. Unlike the Knowledge
base there is **no activation toggle**: evidence collection runs whenever `ff-verify` runs. The
**floor** — executed test/build/lint commands mapped per contract item with real exit codes —
is mandatory and tier-invariant; **breadth** (the widened kinds below) is detection-driven,
never configured.

### Evidence-kind taxonomy

| Kind | Detection surface(s) | Capture |
|---|---|---|
| `executed-test` | `package.json` test script, Makefile test target, pyproject/tox, `composer.json` test script, `phpunit.xml(.dist)`, MFTF acceptance suite | run it; exit code authoritative |
| `build/static-analysis` | build/lint/analyse scripts (tsc, eslint, phpcs, phpstan, `composer.json` lint), Makefile targets | run it; exit code authoritative |
| `e2e/browser` | `playwright.config.*`, MFTF | Playwright CLI under Bash only (`npx playwright test` / `screenshot`); no MCP browser tools |
| `http/api` | a running dev server / documented endpoint | `curl` with the real HTTP status captured (e.g. `-w '%{http_code}'`) |
| `db` | the project's **own** CLI (`bin/magento`, `artisan`, `manage.py`, a documented db script) — never raw driver credentials, never provisioning | command output + exit code |
| `cli-output` | project CLI commands (e.g. `bin/magento setup:di:compile`) | stdout/stderr excerpt + exit code |
| `logs` | project log files (`var/log/*.log`, `storage/logs/*.log`, …) | excerpt proving an expected line present / forbidden line absent |
| `before/after` | any kind above, captured pre- and post-change | paired records, saved with `-before` / `-after` suffixes |

### Evidence record shape

Every piece of evidence is one record:
`{kind, command, actual exit/HTTP status, excerpt, artifact paths}`
— every field literal, never narrated. `artifact paths` are relative to
`<run dir>/evidence/`; an empty list is valid when the kind produces no file (e.g.
`cli-output` with only a stdout excerpt). A record without a captured status can never back
a `pass` — it is `manual-unverified` at best.

### Evidence directory

All captured files (screenshots, traces, logs, response bodies) live under
`<run dir>/evidence/`, named `<kind>-<n>-<short-desc>.<ext>` (e.g. `e2e-1-checkout.png`,
`http-1-login.json`). It is the **only** path `ff-test-runner` may write. It is **cleared at
the start of each verify run** so stale artifacts never mix with fresh evidence. On durable
promotion it is copied alongside `verify.md` — see **Evidence companion copy** in the
Durable-artifact bullet above. Every file must be referenced from `verify.md` by relative
path — no orphaned or unreferenced evidence claims.

### Confidence ladder

Four levels, applied **per contract item** (acceptance criterion, bugfix item,
a design-time failure scenario — full tier, §Design trade-offs & devil's advocate —
or a full-tier success metric, §Discovery fields), derived
**mechanically** — anyone can recount them from the report; no numeric scores anywhere
(the v0.5.0 rejection of numeric confidence as unfalsifiable LLM output is upheld):

1. `Verified (multi-source)` — ≥2 **independent kinds** passed for this item.
2. `Verified (single-source)` — exactly 1 kind passed.
3. `Partially verified` — some evidence exists, but an **expected** (detected) kind failed
   or is missing for this item.
4. `Unverified` — no captured evidence for this item at all.

**Independence:** two records are independent iff their `kind` differs. Duplicates of one
kind collapse to a single source (two `http/api` calls are still one source). **Overall run
confidence = the minimum across all contract items** (order: `Unverified` < `Partially
verified` < `Verified (single-source)` < `Verified (multi-source)`).

### Detection and N/A rule

- Detected surface + ran + passed → cite it.
- Detected surface + not run / failed / tool unavailable (e.g. `playwright.config.ts` exists
  but `npx playwright` is missing) → an explicit **gap** (attempt + reason). **N/A is never
  valid for a detected surface.**
- Undetected surface → `N/A` **with a reason** in the coverage matrix — never silently absent.
- Codex degrade: none — all kinds run via Bash CLI on both platforms; tool availability is a
  property of the *target project*, not the coding platform. (Gate B's content check remains
  Claude-Code-only per §Enforcement; Codex keeps prose gates.)

### Evidence waiver

Exact line, verbatim, in `verify.md`: `Evidence gap accepted by user (<date>): <reason>`.
It may be recorded **only from the user's own in-conversation words** — never authored,
inferred, or dated by the assistant, and never on autopilot's behalf (see the **Evidence gap
stop** row in §Autopilot). A waiver **does not upgrade confidence** — it only unblocks the
`done` transition while the report keeps stating the true confidence levels.

### Tier scaling

The floor (executed test/build/lint mapped per contract item, real exit codes) is
**tier-invariant** — a lite run never skips it, mirroring the bugfix track's never-skipped
RED→GREEN. The **Evidence coverage matrix** and detected-breadth expectations
(e2e/http/db/cli/logs/before-after) apply on **full**-tier runs; **lite** runs render the
floor-only report (single template; the matrix section carries the lite skip note).

### Adding an evidence kind

Two edits, in lockstep: a row in the taxonomy table above (kind, detection surface, capture)
and a matching capture bullet in `agents/ff-test-runner.md`. The confidence ladder, waiver
rule, and `templates/verify.md` are kind-agnostic — they iterate the record list — so nothing
else changes.

### v1 non-goals

Stated, not silent: no MCP/interactive browser automation (Playwright CLI via Bash only);
no numeric confidence or readiness scores (v0.5.0 upheld); no separate client report
artifact — `verify.md` **is** the report (v0.5.0 upheld); no new phase, agent, or config
keys; no environment provisioning (no docker orchestration or test-DB seeding — an app that
cannot run is a recorded gap); no CI-pipeline integration; no perf-benchmark framework (a
project's existing perf command is just `cli-output`); no retroactive re-verification of
past runs.

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
  markdown heading. **For `artifacts.verify` specifically** the file must additionally contain
  a `## Contract mapping` heading and at least one captured status token (an exit code or
  HTTP/status code — see §Evidence, Evidence record shape); the check is deliberately shallow —
  it denies an empty-shell report, it does not grade evidence quality or waiver coverage
  (that judgment is `ff-verify`'s prose responsibility). `artifacts.review` keeps the generic
  existence+heading check.

The hook matches **`Write`, `Edit`, and `MultiEdit`** (v0.19.0; earlier versions matched only
`Write`, so an Edit could flip `currentPhase` past a gate unchecked). For Edit/MultiEdit the
proposed manifest is reconstructed by applying the edit(s), in order, to the on-disk file —
literal match, first occurrence unless `replace_all` — and the same Gate A/B logic judges the
result. An Edit with an empty `old_string` on a missing or empty file is the tool's create form:
the manifest becomes `new_string` and is gated exactly like a Write. A manifest rewritten through a shell command (`Bash`) is **not** covered: shell text
cannot be parsed reliably, so that path stays prose-gated.

The hook is **fail-open**: it denies only a determinate-illegal transition and otherwise allows
(no manifest write · `jq` absent · unparseable proposed manifest · missing `track`/`currentPhase`
· an Edit whose non-empty `old_string` is not found, or an empty `old_string` on a non-empty
file — Claude Code rejects those edits itself · `toggles.enforce: false`). It is **Claude-Code-only** — the Codex package excludes `hooks/`, so
Codex runs the same workflow under the **prose** gates (the hook backstops the prose; it does not
replace it). Kill switch: set `toggles.enforce: false` in `.feature-flow.json`. Behavioral test:
`scripts/checks/enforce-gate-guard.sh`.

### Session re-anchor (SessionStart hook)

The `SessionStart` hook (`hooks/session-start`, sources `startup|clear|compact`) appends an
**active-run block** to its discovery pointer: every run under `<cwd>/<paths.base>/` whose
`currentPhase` is not `done`/`abandoned` and whose `closedAt` is null, newest `updatedAt`
first, max 3 (overflow points at `/feature-flow:ff-list`). Each line carries slug, track/tier,
`currentPhase` + that phase's status, autopilot, sign-off (`n/a` on bugfix-lite), the
`/feature-flow:ff-resume <slug>` command, and every `artifacts.<name>` path (a bare name is
shown under the run dir, a slashed path as-is). On `compact` it tells the model it was mid-run
and to re-read the manifest and artifacts from disk; on `startup`/`clear` it is conditional
("if the user's request relates"). It is advisory context, never a gate, and best-effort: no
`jq`, no `cwd`, no active run, or an unparseable manifest simply omits that part.
Claude-Code-only, like the enforcement hook. Behavioral test: `scripts/checks/session-start-guard.sh`.

## Disk inference procedure

Used by `/ff-resume` and `/ff-status` when the manifest is missing/corrupt, or to validate a
manifest that claims phases are complete:

1. Walk the track's phase order — feature: explore(`explore`) → clarify(`spec`) →
   design(`design`, `decision` — `decision` optional, absent tolerated pre-v0.10.0) →
   plan(`plan`) → implement(no artifact) → review(`review`) → verify(`verify`); bugfix:
   diagnose(`diagnosis`) → implement(no artifact) → verify(`verify`) → review(`review`).
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
   `confirmed` or `signed-off` (a draft-status diagnosis fails validity); `verify.md` must
   pass the same content check as Gate B (§Enforcement) — a `## Contract mapping` heading and
   at least one captured status token — so inference and the hook never disagree; all
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
the contract in the sign-off ask. Three rules, all mandatory:

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
3. **Unvalidated-assumptions echo, as a distinct trailing block.** Every still-unvalidated
   `validation-required: y` assumption (§Assumption records — that section owns the trigger,
   actuation, and waiver; this rule owns only the *rendering shape*) is echoed **after** the
   AC/contract checklist as its own `### Unvalidated assumptions` block — **never folded into the
   `- [ ] AC<n>` checkboxes** (a "please confirm" checkbox ≠ a "still unvalidated" flag). The block
   **always states the true status**: a clean `_None unvalidated._` when there are none (it never
   false-fires a block). Its presence with entries **blocks a clean sign-off** — the run cannot reach
   `signOff.signed = true` until each is **resolved** (validated, waived via the verbatim `Assumption
   validation waived by user (<date>): <reason>` line, or acknowledged-open — §Assumption records →
   Actuation 1 owns the three exits). This is the Evidence-gap-stop shape, **not** the
   do-not-contradict STOP — so the §Autopilot row for it must **not** say "unconditional".

Example shape:

    ### Switch & defaults
    - [ ] **AC1 — config key**: `config/defaults.json` contains `toggles.autopilot` …
    - [ ] **AC2 — run-start ask**: When a new run starts and resolved `toggles.autopilot` …

    ### Chaining behavior
    - [ ] **AC6 — boundaries chain**: With `autopilot: true`, every ceremonial phase …

    ### Unvalidated assumptions
    These `validation-required: y` assumptions are not yet validated — validate each, or reply
    with `Assumption validation waived by user (<date>): <reason>`. Sign-off cannot complete until
    then:
    - **Assumption 2**: <the assumption statement, verbatim from the table> (if-wrong: <impact>)

    (When none are outstanding this block reads `### Unvalidated assumptions` / `_None unvalidated._`
    — always shown, never a false-firing block.)

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

> **Delivery is post-terminal.** The optional `deliver` phase (§Delivery) runs *after* the
> done-transition and does **not** change it: `ff-deliver` never sets `done` (the run is already
> there) and never fires KB capture. `currentPhase` stays `done` throughout delivery.

## Knowledge base

The Knowledge base (KB) closes feature-flow's learning loop: it **captures** each finished run's
architectural decisions / project conventions as committed, project-local markdown entries, and
**recalls** matching entries into the `explore`, `design`, and `diagnose` fan-outs of later runs
(and, via **Decision recall** below, into `implement`) — stale ones flagged, never silently
presented as fresh. This is the single canonical contract; the six hooked commands (`ff-verify`,
`ff-review`, `ff-explore`, `ff-design`, `ff-diagnose`, `ff-implement`) reference this section by
name and never restate it inline. It is the same house style as **Durable artifact resolution** above.

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
   `design`, `decision`, and `plan` if present, `verify`, `review`) — never bare filenames. When
   a `decision` record is present, it is the **preferred** distillation source for the run's
   architectural decision (already structured — options, trade-offs, chosen rationale), so
   capture lifts it rather than re-deriving the decision from `design` prose.
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

### Decision recall (ff-design, ff-implement)

Closes feature-flow's actuation gap: a run's decision record does not just get filed — it
**constrains** later phases of the same run, and (once captured to the KB) later runs. This is
the single canonical contract; `ff-design` and `ff-implement` reference this subsection by name
and never restate its steps inline. Two sources feed the **do-not-contradict** STOP, resolved
differently and **never conflated**:

1. **This run's own decision — `manifest.artifacts.decision`, unconditional (no KB needed).**
   The sole locating authority (never a hardcoded filename). The read is unconditional — it
   costs nothing and applies identically on full tier (resolves to the promoted decision record)
   and lite tier (resolves to the `spec` — `ff-clarify` set the pointer there, since the spec's
   inline `## Solution approaches considered` *is* the lite decision record). **No tier branch in
   the locating logic** — the same pointer read serves both. Absent `artifacts.decision`
   (pre-v0.10.0 manifest) → "no decision recorded"; proceed, no error. `ff-design` does **not**
   read this source (a run cannot contradict a decision it has not made yet) — it reads only
   source 2.
2. **Prior decisions from other runs — KB-gated, reuses the Recall rule above verbatim.**
   Gated on `toggles.kb` + `paths.kb`. Every KB entry already records a settled decision or
   convention (`templates/kb-entry.md` §Decision / convention), so the generic recall surface
   **is** the prior-decision surface — glob, tag-match, apply the **Staleness rule** below
   (stale entries flagged `[STALE — <reason>]`, never dropped). `ff-design` tag-matches the
   spec's `## Problem` before the architecture pick; `ff-implement` tag-matches this run's
   decision content alongside its source-1 read. KB off → source 2 is skipped; source 1 still fires.

**Do-not-contradict STOP (the refuse).** A **prose gate only** — no hook can diff semantic
contradiction, so this is honorable by instruction (Codex-safe), not machine-enforced. If the
architecture about to be chosen (`ff-design`, vs source 2) or the approach about to be coded
(`ff-implement`, vs source 1 or 2) **diverges** from a recalled decision, **STOP unconditionally
in both modes** — never self-resolved, never autopilot-retried (unlike a Critical review
finding). Surface the conflict, shaped:

> Decision conflict detected — not proceeding on the current approach:
> - **Recalled decision:** `<prior KB entry path | this run's decision>` — `<title>` (`<date>`):
>   `<the settled decision statement>`
> - **Diverges because:** `<the specific way the current pick/approach contradicts it>`
> To proceed: (a) realign the approach with the settled decision, or (b) reply with an explicit
> override — recorded verbatim as `Decision override by user (<date>): <reason>` in the resolved
> `artifacts.decision` record, and the run continues.

The override is **never self-authored** — record only the user's own in-conversation words,
exactly like the evidence waiver (§Evidence). No prior decision recalled / no conflict →
one-line note, proceed (mirrors empty-store recall). See the **Decision conflict stop** row in
§Autopilot.

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

## Planning intelligence

`ff-plan` derives four sections into every `plan.md` (feature) / `plan-bugfix.md` (bugfix-full),
between `## Tasks` and `## Status conventions`: **Dependency graph**, **Critical path**, **Risk
register**, **Rollback plan**. This is the single canonical contract; `ff-plan`, `ff-implement`,
and `ff-verify` reference this section by name and never restate its rules inline — same house
style as §Evidence and §Knowledge base → Decision recall. The **Critical path** is the only one
that hard-gates a later phase; the other three are inputs to consumers that already exist.
**Always-on:** no `toggles.*` key gates any of this, and no new `manifest.json` top-level field —
every section lives inside the plan, located solely via `manifest.artifacts.plan` (the sole
locating authority, per **Durable artifact resolution**). This closes the v2 Actuation line: a
planning section a human reads but no phase acts on is a documentation cost, not a capability —
the same trap **Decision recall** exists to close.

### Dependency graph notation

One row per task: `| Task | Depends on |` — `Depends on` names a prior `Task N` or "— (root)".
Expressed purely in the `Task N` IDs already defined under `## Tasks` — never a phantom task.

**Structural invariant (this is what makes the derivation below deterministic and
hand-computable): a task's `Depends on` list may name only STRICTLY LOWER-numbered tasks.** The
plan's task numbering is therefore always already a valid topological order of the graph — a cycle
is unexpressible, and no topological sort is ever needed. `ff-plan` enforces the lower-numbered
rule when it writes the graph. Multiple roots are normal and are **not** an instruction to run
tasks concurrently — this is dependency *data*, not a scheduling directive.

### Critical-path derivation

`ff-plan` computes the critical path **after** writing the Dependency graph, **from** it — never
as an independent judgment call. Given tasks `1..N` (already topological, by the invariant above)
and each task's `Depends on` set:

1. For `i = 1..N` in increasing order, `depth(i)` = `0` if `Task i` is a root, else
   `1 + max(depth(j) for j in Depends-on(i))`; `chainLength(i) = depth(i) + 1`.
2. **Sink** = the task with the greatest `chainLength`. Deterministic tie-break, in order:
   (a) most `Step` items, then (b) lowest task number.
3. Walk backward from the sink: at each task, move to the dependency with the greatest
   `chainLength` (same tie-break) until a root is reached; reverse the walk.

Rendered `**Path:** Task a → … → Task sink`. Degenerate cases, stated literally (never invent an
edge to force a chain): **no edges at all** → "no gating chain — all tasks independent" (every
`chainLength` is 1; the tie-break names the single longest task); **fully linear** → the whole
task sequence. Because the path is derived, an edit that changes the graph invalidates a stale
path — re-derive, don't hand-patch.

### Critical-path check (ff-implement)

The **sole hard actuator**. `ff-implement` resolves the plan via `manifest.artifacts.plan` (full
tier only — feature full, or an escalated full-tier bugfix; lite tiers have no plan and skip it),
reads the `## Critical path`, and, before executing a task, compares the approach it is about to
take against that path exactly as **Decision recall**'s do-not-contradict STOP compares an
approach against a recalled decision — same shape, same unconditional-in-both-modes rule, reused
rather than reinvented. **Trigger:** the approach skips a task the critical path names, or executes
critical-path tasks out of the stated order. On trigger, **STOP unconditionally in both modes** —
autopilot does not auto-resolve or retry. Resolve **only** by realigning the work to the critical
path, or by the user replying with an explicit override recorded verbatim as
`Critical-path override by user (<date>): <reason>` in the plan's `## Critical path` section (the
plan, not the decision record — the critical path lives in the plan) — never self-authored. No
divergence, or no
critical path recorded (a pre-WS-2 plan) → one-line note, proceed. See the **Critical-path stop**
row in §Autopilot.

### Risk register (feeds ff-verify)

One row per identified risk: `| Risk | Likelihood | Impact | Mitigation |`, categorical
(`Low | Medium | High`) — **no numeric scores** (same doctrine as §Evidence's confidence ladder).
`ff-verify` reads it via `manifest.artifacts.plan` (full tier) and cross-references it into the
existing `verify.md` §Regression risk rather than deriving risk cold from the diff — any risk the
register named, and whether it materialized, folds into the verdict. A risk accepted without
mitigation is recorded as such (mirrors the Evidence waiver's "state it, don't hide it").

### Rollback plan (recovery on a failed Verify step)

Not an actuator — a **prescribed recovery**. One row per task that risks a half-applied state,
naming the concrete recovery action `ff-implement` takes when that task's `Step N: Verify` fails,
so a failure never leaves the tree silently half-applied. An **irreversible** step states so
explicitly and names a mitigation instead of a fake undo. No plan (lite tier) → recover ad hoc and
note it under the manifest's Blockers.

### v1 non-goals (honest deferral)

No automatic scheduling or parallel execution of independent (root) tasks — the dependency graph
is data, not a scheduling instruction. No numeric risk/priority scoring. No cross-run KB recall of
past risk registers or rollback plans. No machine/CI verification of the critical-path STOP
actually firing — a fresh-session self-run, exactly like the Decision-recall STOP's behavioral AC.

## Assumption records

The single canonical contract for **structured assumption records**: what a Beat-4 assumption row
is, when its `validation-required: y` flag actuates, and how it is waived. `ff-clarify`,
`ff-diagnose`, and `ff-plan` reference this section by name and never restate it inline — the same
house style as §Planning intelligence and §Knowledge base above. Like WS-2's planning intelligence it
is **always-on**: no `toggles.*` key gates it and no new `manifest.json` field carries it — assumption
data lives inside the artifact, located solely via `manifest.artifacts.spec` / `.diagnosis` (the sole
locating authority, per **Durable artifact resolution**). This closes the same Actuation line WS-1/2/3
close: an assumption a human reads but no phase acts on is a documentation cost, not a capability.

### Row schema

Beat-4 assumptions are a **markdown table**, one row per assumption, header columns in this exact
order — replacing the former free-text bullets:

| Column | Values | Meaning |
|---|---|---|
| `Statement` | prose | the WHAT-changing assumption |
| `Confidence` | `low \| med \| high` | categorical only — **no numeric scores** (upholds §Evidence's ladder) |
| `Basis / evidence` | prose (may be empty) | why it is believed |
| `If-wrong impact` | prose (may be empty) | what breaks in scope/ACs if it is false |
| `Validation-required` | `y \| n` | the actuation trigger (below) |

**Positional identity:** an assumption's number is its **table row order** (first data row =
Assumption 1). Row order is **stable once written** — reordering rows silently breaks any
`**Validates:** Assumption N` reference (§Planning intelligence). There is no rendered number column
(it is outside the locked column set); position **is** N. A row is valid even when `If-wrong impact`
or `Basis` is empty — the trigger is the flag, not cell completeness.

### Tier / track scope

- **feature** — both tiers (`lite` and `full`) carry the table: both have a sign-off gate to echo into.
- **bugfix** — **full tier only**. A `lite` bugfix has **no sign-off gate** (`diagnosis.md` reads
  `n/a (lite)`), so it carries no assumptions table and no echo — consistent, not an exception.

### Trigger — `validation-required: y` alone

The actuation trigger is the `validation-required: y` flag **by itself** — **author-set, never
derived**. `Confidence` and `If-wrong impact` are descriptive context that inform the author's
judgment; they do **not** couple into the trigger (there is no "flag AND high impact" rule). An
assumption validated during clarify/diagnose (the user answers it) is marked `n` and no longer
actuates.

### Actuation 1 — the sign-off echo (feature both tiers; bugfix full)

At the sign-off gate, every **still-unvalidated** `validation-required: y` assumption is **echoed** in
the sign-off ask and **blocks a clean (silent) sign-off**: the run cannot reach `signOff.signed = true`
until the user **resolves each one** — **(a) validate** it now (mark it `n` — no task), **(b) waive**
it (**mark it `n`** and record the verbatim line below as the audit trail; accepted risk — no task), or, **full tier only, (c) acknowledge it stays
open** (the row remains `y` and is carried into the full-tier plan for **Actuation 2** to spawn a
`**Validates:**` task). Exit (c) requires a plan to carry the row into, so it is **full-tier only**: a
**lite** feature (no plan phase) resolves via (a) or (b) only — the assumption safety net still fires,
but there is no defer-to-plan option. What the gate forbids is a *silent* sign-off that never surfaces
the assumption — **not** a consciously-acknowledged open assumption carried forward as tracked work. The echo's
**rendering shape** is owned by
§Sign-off rendering **rule 3** (a distinct trailing block after the contract checklist, never folded
into the `- [ ] AC<n>` boxes, always states the true status). This is the **Evidence-gap-stop shape**
— a turn-ending, waivable stop on a *transition* — **not** the do-not-contradict STOP (§Decision
recall / §Critical-path check): an unvalidated assumption is *unaddressed*, not *contradicting*, so
there is nothing to diff. Consequently the §Autopilot row below must **not** carry the word
"unconditional" (that word is the do-not-contradict marker).

### Actuation 2 — the plan validation task (full tier)

On the **full** tier, `ff-plan` maps each still-unvalidated `validation-required: y` assumption
carried from the signed spec/diagnosis — the **exit-(c) "acknowledged-open" rows** of Actuation 1,
neither validated nor waived — to **≥1 task's `**Validates:** Assumption N` line**, or records
it as an explicit named coverage gap — cloning the `**Covers:**` AC→task discipline (§Planning
intelligence). A validation task logically precedes the tasks that depend on the assumption (the
lower-numbered dependency invariant). A **waived** assumption spawns **no** task (waive = accepted
risk, not deferred work); an assumption validated at sign-off likewise spawns none. Because exits (a)
and (b) both **mark the row `n`** (see Waiver), a surviving `validation-required: y` row *is* an
acknowledged-open row — the flag alone selects Actuation 2's targets, with no cross-referencing of the
waiver line, so `ff-plan` resolves them from the artifact in any session (never from conversational
memory).

### Waiver

The waiver is the verbatim line, recorded in the spec/diagnosis:

    Assumption validation waived by user (<date>): <reason>

It may be recorded **only from the user's own in-conversation words** — never assistant-authored,
inferred, or dated by the assistant, and **never on autopilot's behalf** (see the §Autopilot
"Assumption validation stop" row). Mirrors the §Evidence waiver exactly. A waiver **marks the row
`Validation-required: n`** — the verbatim line is the audit trail recording *that* the row was resolved
by waiver (accepted risk), not by empirical validation, and *why*. It **does not change the
assumption's recorded `Confidence`** or `Statement`. The `Validation-required` flag records
*resolution state*: validate and waive both set `n`; only exit-(c) acknowledge-open leaves `y`, so a
surviving `y` unambiguously marks Actuation 2's task target — readable from the artifact alone, never
from conversational memory. Telling a *waived* `n` from a *validated* `n` per-row is **not**
load-bearing — neither spawns a task nor echoes, and no phase branches on the difference — so it needs
no on-disk index; the waiver line's `<reason>` is the human record, not a machine key (per-row waiver
identification is out of scope).

### v1 non-goals

Stated, not silent: **no negative-outcome re-entry** (a validation task later proving an assumption
*wrong* during implement does not auto-reopen clarify/design — a named future workstream); **no
numeric confidence or scoring** (upholds §Evidence); **no new manifest field, no `toggles.*` key, no
new phase** (always-on, artifact-resident, WS-2 posture); **no automated regression guard for the echo
actually firing** (the catch is semantic — a fresh-session self-run, named in the CHANGELOG, same
posture as the Decision-recall / Critical-path behavioral ACs); **no cross-run KB recall of past
assumptions**.

## Design trade-offs & devil's advocate

The single canonical contract for the **design-time adversarial pass**: the lean trade-off matrix,
the devil's-advocate failure-scenario list, and how a named scenario actuates at verify. `ff-design`,
`ff-verify`, and `templates/design.md` / `templates/verify.md` reference this section by name and
never restate it — same house style as §Planning intelligence and §Assumption records above.
**Full tier, feature track only** — the bugfix track has no design phase, and lite skips `ff-design`
by construction (§Field notes). **Always-on:** no `toggles.*` key gates it and **no new
`manifest.json` field** carries it — the matrix and failure scenarios live inside `design.md`,
located solely via `manifest.artifacts.design` (the sole locating authority, per **Durable artifact
resolution**). This closes the same Actuation line WS-1/2/4 close: a failure scenario a human reads
but no phase acts on is a documentation cost, not a capability.

### Trade-off matrix

`ff-design` scores **every** fanned-out option (not only the winner) in `design.md`'s
`## Trade-off matrix` on three **core axes**, every run: **Complexity**, **Risk / operational
impact**, **Test effort** — categorical (`low | med | high`), never numeric (upholds §Evidence's
no-numeric-scores doctrine). Any other axis (performance, maintainability, scalability, security,
cost) is added as an extra column **only when it actually differentiates** the options — dropped,
never padded in. The matrix is not an actuator by itself; it is the structured input the
devil's-advocate pass and `decision.md`'s Trade-offs row are both derived from.

### Devil's-advocate notation

Scoped to the **chosen** option only. Each concrete failure scenario is a labeled `**FS<n>:**`
bullet under `design.md`'s `## Devil's advocate → ### Failure scenarios` — an **explicit inline
label** (write order, `FS1` first), because `ff-verify` quotes it verbatim into a `### FS<n>` block
exactly as it quotes a spec `AC<n>` from the acceptance-criteria checklist (the closer analog is the
AC checklist, not §Assumption records' positional-only table — both AC and FS are consumed as
literal contract-item headers). **At least one scenario is required** for every full-tier design,
even one with a single obvious option. Edge cases and migration/operational risks accompany the list
as prose in the same section — context, **not** contract items.

### Actuation — the FS<n> contract item (feeds ff-verify)

`ff-verify` resolves `design.md` via `manifest.artifacts.design` (full tier; absent on lite, on the
bugfix track, or on a pre-WS-5 design → skip, no FS blocks, never a STOP) and maps each named
failure scenario into its own `### FS<n>` block in `verify.md`'s `## Contract mapping` — **exactly
as an acceptance criterion is mapped**: same four Confidence-ladder levels (which now name three
contract-item classes: acceptance criterion, bugfix item, or design-time failure scenario), same
evidence-gap-stop shape. An `FS<n>` stuck at `Partially verified` or `Unverified` holds the run at
the existing **Evidence gap stop** (§Autopilot) — the SAME turn-ending, waivable stop an unverified
AC already uses, **not** the do-not-contradict STOP (an unproven scenario is *unaddressed*, not
*contradicting*). It is cleared by proving it, or by the SAME verbatim `Evidence gap accepted by
user (<date>): <reason>` waiver ACs use (§Evidence, Evidence waiver) — **no new waiver line is
minted, no new §Autopilot row, no new hook**: the existing "Evidence gap stop" row already
generalizes over "any contract item," and Gate B (`hooks/enforce-gate`) is already scenario-agnostic.

### decision.md reconciliation

`ff-design` **derives** `decision.md`'s existing `## Trade-offs` row (`Effort | Risk |
Reversibility`, pinned unchanged by `decision-record-guard.sh`) from this matrix — Complexity + Test
effort → Effort, Risk / operational impact → Risk, Reversibility assessed as before — **never a
second, divergent scoring pass** — and names the chosen option's failure scenario(s) in
`## Chosen + rationale` **by reference** (`see design.md §Devil's advocate`), never copied verbatim.
`design.md` stays the single source of truth for the `FS<n>` list and its numbering (mirrors
§Assumption records' single-canonical-home discipline); `decision.md`'s schema is unchanged and
grows no numbered FS list.

### v1 non-goals

Stated, not silent: **no new `manifest.json` field, no `toggles.*` key, no new phase, no new
§Autopilot row, no new waiver line** (always-on, artifact-resident, reuses the evidence-gap stop
verbatim — WS-1/2/4 posture); **no numeric trade-off or risk scoring** (upholds §Evidence); **no
per-item on-disk distinction between an FS waiver and an AC waiver** (accepted — FS carries no
validation-required flag the way an assumption does; reopen only if a future workstream audits
FS-waiver rates); **no bugfix-track devil's-advocate pass**; **no automated regression guard** for an
`FS<n>` block actually blocking `done` and a covered scenario not false-firing — that catch is
semantic, a fresh-session STOP-vs-control self-run, named in the CHANGELOG (same posture as the
Decision-recall / Critical-path / Assumption-echo behavioral ACs).

## Discovery fields

Two **optional, full-tier** structured fields in `spec.md` (added WS-7, v0.17.0), each **actuating**
a downstream phase rather than merely recording — the v2 guardrail that a field only a human reads is
a documentation cost, not a capability. Always-on, **artifact-resident**: both live inside `spec.md`
and are located solely via `manifest.artifacts.spec` (the sole locating authority) — **no new
`manifest.json` field, no `toggles.*` key, no new phase, no new hook.** A pre-WS-7 spec, or any spec
omitting a section, resolves unaffected. `ff-clarify` prompts for them only on **non-trivial
full-tier** work; a **lite** spec omits both with no placeholder and no warning (the template is
shared by both tiers, so the gate is a **presence check on the section's rows**, never a read of
`manifest.tier`).

### Success metrics

A `## Success metrics` section of **binary-threshold** rows — "metric M ≤/≥ T, measured by
`<method>`" — reusing the binary, checkable **acceptance-criterion discipline** (that section owns it;
this is not a divergent grammar). A metric that cannot be phrased as a checkable threshold is rejected
at clarify, never recorded as a soft/directional statement. An SM's number is its row order (first
row = SM1), stable once written. Metrics are **verify-time** items, **not** part of the sign-off
render — §Sign-off rendering stays "Three rules".

### Requirement graph

A `## Requirement graph` `| AC | Depends on |` table reusing §Planning intelligence's **dependency
notation** verbatim (not a divergent grammar): `Depends on` names only a strictly **lower-numbered**
`AC<n>` (or "— (root)") already defined under `## Acceptance criteria`, so a cycle is unexpressible —
the same lower-numbered invariant the task graph carries. Only dependent ACs need a row; an
all-independent spec omits the section.

### Actuation 1 — the SM<n> contract item (feeds ff-verify)

`ff-verify` resolves `spec.md` via `manifest.artifacts.spec` (already read in Cold-start; no new
pointer) and maps each `## Success metrics` row into its own `### SM<n>` block in `verify.md`'s
`## Contract mapping` — **exactly as an acceptance criterion is mapped**: the same four
Confidence-ladder levels (which now name **four** contract-item classes — acceptance criterion, bugfix
item, design-time failure scenario, success metric), the same evidence-gap-stop shape. An `SM<n>`
stuck at `Partially verified` or `Unverified` holds the run at the existing **Evidence gap stop**
(§Autopilot) — the SAME turn-ending, waivable stop an unverified AC or `FS<n>` already uses, **not**
the do-not-contradict STOP — cleared by proving it or by the SAME verbatim `Evidence gap accepted by
user (<date>): <reason>` waiver. **No new waiver line, no new §Autopilot row, no new hook**: the
Evidence gap stop already generalises over "any contract item," and the unfilled `### SM1:`
placeholder's Gate-B digit-free safety is proven end-to-end by `enforce-gate-guard.sh`'s `b-template`
fixture (which copies the whole shipped `verify.md` through the real hook) — never re-derived.
**Presence, not tier, gates:** unlike `FS<n>` (whose home `design.md` structurally never exists on
lite), `## Success metrics` lives in the one shared `spec.md` template, so absent-or-empty gates —
never `manifest.tier`.

### Actuation 2 — task-dependency derivation (feeds ff-plan)

`ff-plan` derives edges in the plan's **existing** `## Dependency graph` — §Planning intelligence's
same table, notation, and lower-numbered invariant; this adds only the AC-edge → task-edge
translation, it does **not** widen `templates/plan.md` (no new column, no new table). For each
`AC_i depends-on AC_j` edge in `## Requirement graph`: every task whose `**Covers:**` line names
`AC_i` depends on every task covering `AC_j`.

**Order-at-decomposition, never renumber.** Task numbering is an *output* choice `ff-plan` makes
while authoring the plan (unlike AC numbers, pinned at spec sign-off), so `ff-plan` numbers tasks to
satisfy the AC-derived edges **as it decomposes** — a valid topological order always exists unless an
edge is un-derivable. This is **not** a backward re-sort of already-written tasks (which would rewrite
`**Covers:**`/`**Validates:**` references — the "second divergent pass" §Assumption records' row
stability forbids). An edge that cannot be represented as a lower-numbered task dependency — the same
task covers both `AC_i` and `AC_j` (a self-edge), or no numbering satisfies it (e.g. multi-task
coverage forcing a forward edge) — surfaces as an **explicit named gap under the plan's Outcome gate**
naming the reason (e.g. `AC_i depends-on AC_j: covered by the same Task <n>`), never silently dropped
and never forced with a forward-pointing `Depends on`. Rendered in the Outcome gate's requirement-graph rule bullet
(`templates/plan.md`), alongside the existing AC-coverage and Assumption-validation gap bullets.

### Tier / track scope

**Feature track, full tier only.** Lite features omit both sections (no design/plan weight added to
lite); the bugfix track has no `spec.md` and no requirement graph. Both actuations skip cleanly by
presence check when the sections are absent — a pre-WS-7 spec is byte-identically unaffected.

### v1 non-goals

Stated, not silent: **no `## Stakeholders` field** (cut — no downstream consumer, so it would fail
guardrail #9); **no new `manifest.json` field, no `toggles.*` key, no new phase, no new §Autopilot
row, no new waiver line** (always-on, artifact-resident, reuses the evidence-gap stop and the
Outcome-gate gap verbatim — WS-1/2/4/5 posture); **no fourth §Sign-off rendering rule / no metrics
echo in the sign-off ask** (metrics are verify-time items); **no directional/soft metrics** (binary
thresholds only, upholding §Evidence); **no task renumbering pass** (order-at-decomposition instead);
**no automated regression guard** for a success metric actually blocking `done` and an un-derivable
requirement-graph edge actually surfacing at the Outcome gate — that catch is semantic, a
fresh-session fired-vs-control self-run, named in the CHANGELOG (same posture as the Decision-recall /
Critical-path / Assumption-echo / FS<n> behavioral ACs).

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

**Delivery is never chained.** The optional `deliver` phase (§Delivery) is post-terminal and
manual: autopilot ends at the done-transition and **never** auto-runs `ff-deliver`. Delivery is a
value-add the user invokes explicitly — chaining it would add ceremony a non-gated phase must not.

**Retro is never chained.** The optional `retro` phase (§Retrospective) is post-terminal and manual in
exactly the same way: autopilot **never** auto-runs `ff-retro`, and never answers its confirm gate.

**Mandatory pauses — gates are physics, not preference; autopilot never skips, overrides,
or self-answers a gate:**

| Gate | Type | Behavior in autopilot |
|---|---|---|
| Spec sign-off (`ff-clarify`) | cross-turn | end the turn with the sign-off ask (**Sign-off rendering** above); never set `signOff.signed` yourself; chain resumes on the user's confirmation or `ff-resume` |
| Diagnosis sign-off, full tier (`ff-diagnose`) | cross-turn | same as spec sign-off |
| Not-reproduced stop (`ff-diagnose`) | cross-turn | ends the chain unconditionally — autopilot does not retry |
| Decision conflict stop (`ff-design` vs prior decisions; `ff-implement` vs this run's own decision) | cross-turn | **unconditional** STOP in both modes — autopilot does not auto-resolve or retry (unlike the Critical-review fix cycle); the chain resumes only when the user realigns the approach or replies with an explicit `Decision override by user (<date>): <reason>` — never self-authored — see §Knowledge base → **Decision recall** |
| Critical-path stop (`ff-implement` vs the plan's derived critical path) | cross-turn | **unconditional** STOP in both modes — autopilot does not auto-resolve or retry (same severity as the Decision conflict stop above); the chain resumes only when the user realigns the work to respect the critical path or replies with an explicit `Critical-path override by user (<date>): <reason>` — recorded in the plan's `## Critical path`, never self-authored — see §Planning intelligence → **Critical-path check** |
| Critical review block (`ff-review`) | cross-turn | one fix-and-re-review cycle (below), then stop if Criticals remain |
| Verify repair-and-re-verify cycle (`ff-verify`) | cross-turn | capped — one repair-and-re-verify cycle (below) on a genuine AC/bugfix failure (a captured non-success status), then the Evidence gap stop if it still fails; a pure evidence gap or a failed `FS<n>` never triggers a cycle |
| Evidence gap stop (`ff-verify`) | cross-turn | any contract item below `Verified (single-source)` blocks `done` — end the turn with the gap report (what could not be verified, why, what evidence is required); autopilot never records a waiver itself; chain resumes on the user's waiver (see §Evidence, Evidence waiver) or a re-run after the gap is addressed |
| Assumption validation stop (`ff-clarify`; `ff-diagnose` full tier) | cross-turn | an unvalidated `validation-required: y` assumption blocks a clean sign-off — end the turn with the `### Unvalidated assumptions` echo block (which assumptions are still unvalidated); autopilot never records a waiver itself; chain resumes once the user resolves each — validate it, waive it (`Assumption validation waived by user (<date>): <reason>`), or acknowledge it stays open (carried to the plan as a `**Validates:**` task; see §Assumption records → Actuation 1). Same waivable shape as the Evidence-gap-stop row above |
| KB capture confirm-gate (`ff-verify` feature-terminal / `ff-review` bugfix-terminal), only when `toggles.kb` active | cross-turn | distill candidates, end the turn for the user to accept/edit/reject; never write entries unconfirmed; chain resumes to `currentPhase="done"` on the answer or `ff-resume` — see §Knowledge base |
| Retro confirm-gate (`ff-retro`, only when the user invokes it after `done`) | cross-turn | distill retrospective candidates, end the turn for the user to accept/edit/reject each; never write `retro.md` unconfirmed and never answer the gate on the user's behalf; `ff-retro` is never chained, so there is no chain to resume — see §Retrospective |
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

**Repair-and-re-verify cycle (verify failure, autopilot + full tier only).** Mirrors the
Fix-and-re-review cycle above, applied to a genuine verify *failure* instead of a review finding.
Before starting a cycle, check `verify.md` for an existing `## Repair` section — the verify
artifact is the durable one-cycle record (it survives session drops), exactly as review's
`## Resolution`. **No prior cycle AND ≥1 contract item is an acceptance criterion or bugfix item
(never a design-time `FS<n>`) backed by a captured non-success exit/HTTP/status** (a check that ran
and failed — not a pure gap with no captured evidence) → emit the repair plan (what failed →
smallest diagnosis → proposed fix → re-touched contract items, drawn conservatively — when uncertain,
include), apply the fix inline (no `ff-implement` re-entry), append the `## Repair` record, and
re-verify **only the named re-touched contract items** (ACs or the bugfix item(s)), **once** — the
scoped repair re-verify does **not** re-clear `<run dir>/evidence/` (an explicit exception to
§Evidence, Evidence directory: every un-touched item's evidence is preserved). A prior `## Repair` section exists, a re-touched item
still fails, the failure is a pure gap or a failed `FS<n>`, or the run is step-by-step / lite tier
→ fall through to the Evidence gap stop above — never a second cycle. `phases.verify.status` stays
`in_progress` throughout; the cap is **per-phase** (independent of review's cycle) and carries **no
manifest field** — the `## Repair` section is the sole record. The waiver is untouched by this
cycle (it never upgrades confidence; autopilot never records one).

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

## Delivery

The **delivery** phase is **optional, post-terminal, and non-gated** (added v0.12.0). It runs
*after* a run reaches `currentPhase = "done"` and produces `delivery.md` by **consuming** the run's
upstream artifacts — it never denies, never blocks `done`, and is off for `tier: lite` unless the
user explicitly requests it. `ff-deliver` is the only command that touches it and it is **never
chained by autopilot** (see §Autopilot). This is the canonical contract; `ff-deliver` references it
by name and never restates it inline — same house style as **Planning intelligence** and **Knowledge
base** above.

### Manifest shape (absent-defaulted)

- `phases.deliver` (`{ status, artifact }`, following the generic phase shape
  `pending|in_progress|complete` defined once in §Schema) — the delivery phase's status.
  **Absent = the run predates delivery or never ran it** (every pre-v0.12.0 manifest, and any `done`
  run without delivery): `ff-status`/`ff-resume` treat it as an optional, not-yet-run phase, never
  missing-and-invalid. No migration.
- `artifacts.delivery` — the resolved path of `delivery.md`. **Absent = no delivery artifact
  recorded.** Promotion-eligible (durable set in §Field notes); with `paths.durable` null it stays
  in the sandbox.
- **`currentPhase` stays `"done"` and the `currentPhase` enum is NOT extended with `deliver`.** `done`
  is the immutable terminal state Gate B guards and run-resolution excludes; delivery is tracked
  **only** in `phases.deliver`. A command reading `currentPhase` never sees `deliver`, so Gate B, the
  sign-off gate, resume, and close are all untouched.

### Consumption sources (delivery restates nothing)

`ff-deliver` resolves each source **only** via `manifest.artifacts.<name>` (never a bare filename):

- **Release notes** ← the spec's acceptance criteria (`artifacts.spec`) + `artifacts.decision` (if present).
- **Rollback checklist** ← `plan.md §Rollback plan` (`artifacts.plan`), row for row.
- **Migration notes** ← `plan.md` tasks flagged migration/schema/irreversible in `§Rollback plan` / `§Risk register`.
- **Known issues** ← `verify.md §Limitations & remaining risks` (`artifacts.verify`), mirrored.
- **Release validation steps** ← `verify.md §Commands run` — the executed commands, to re-run post-deploy.
- **Deployment checklist** — a generic ordered scaffold seeded by detectable signals (migration tasks
  present? verify commands?); it is **not** an inferred infrastructure model.

A source that cannot be resolved (a lite/pre-WS-2 run with no `plan.md`, an empty `§Limitations`) is
**reported as what it is** — "no plan.md — rollback not derivable", "None reported" — never invented.

### Delivery gap (the actuation)

For every plan task touching **migration / schema / irreversible I/O** that has **no** `§Rollback
plan` recovery line, `ff-deliver` records a `⚠ DELIVERY GAP:` line in `delivery.md` and reports it to
the user — **non-blocking** (delivery never blocks `done`). This is the back-pressure that makes an
upstream missing rollback visible at ship time, closing WS-2's rollback loop. A task carrying an
`irreversible: mitigation is <X>` line is **not** a gap — it has a mitigation, which delivery surfaces
instead.

## Retrospective

The **retrospective** phase is **optional, post-terminal, and confirm-gated** (added v0.18.0). It runs
*after* a run reaches `currentPhase = "done"` and records **what the workflow's own safeguards did** on
this run — which gates, STOPs, cycles, and waivers fired, whether each worked, and where the fix for any
failure belongs. It is **not** a second KB: the KB captures *project* decisions and conventions; the
retrospective captures *workflow* behavior (feature-flow's own safeguards). `ff-retro` is the only
command that touches it; it is **never chained by autopilot** (see §Autopilot) and never answered on the
user's behalf. This is the canonical contract; `ff-retro` references it by name and never restates it
inline — same house style as §Delivery.

### Manifest shape (absent-defaulted)

- `phases.retro` (`{ status, artifact }`, the generic phase shape) and `artifacts.retro` (the resolved
  path of `retro.md`) — both **absent-defaulted** (never ran = optional, not-yet-run; never
  missing-and-invalid). No migration.
- **`currentPhase` stays `"done"` and the `currentPhase` enum is NOT extended with `retro`** — the
  §Delivery rule, reused verbatim: `done` is the immutable terminal; retro is tracked only in
  `phases.retro`.
- `retro` is **durable-eligible** (§Field notes): with `paths.durable` set, `retro.md` lands in
  `<paths.durable>/<D>-<S>/retro.md`; otherwise in the sandbox.

### Activation

Any `done` run — **either track, either tier (lite included, unlike delivery), closed or not**
(`closedAt` is left untouched). A run whose `currentPhase` is not `done` (in progress, or abandoned)
STOPs with a message naming its current phase and writes nothing. A second invocation on a run whose
`phases.retro.status` is `complete` goes through the **Re-run guard**.

### Signals (the closed list — never transcript-mined)

`ff-retro` resolves upstream artifacts **only** via `manifest.artifacts.<name>` (`spec` or
`diagnosis`, `design`, `decision`, `plan`, `review`, `verify`, `delivery` — each optional; an absent
one is "not available", never invented) and scans them for exactly these on-disk safeguard signals:

1. **User override / waiver lines** — `Decision override by user`, `Critical-path override by user`,
   `Assumption validation waived by user`, `Evidence gap accepted by user`, `sign-off waived by user`.
2. **Cycle records** — review `## Resolution` (a fix-and-re-review cycle ran), verify `## Repair`
   (a repair-and-re-verify cycle ran).
3. **Unproven contract items** — any AC / bugfix item / `FS<n>` / `SM<n>` left below
   `Verified (single-source)` in the final `verify.md`.
4. **Critical review findings** — raised, whether or not later resolved.
5. **`⚠ DELIVERY GAP:` lines** in `delivery.md`.
6. **User notes** — free text passed to `ff-retro` (friction that left no disk trace; the only way it
   is captured).

### Materiality test

A candidate is proposed **only if both** hold: **(a)** it traces to a specific signal above (or a
user note), and **(b)** that signal does not fully close it — the safeguard **failed**, was **missing**,
was **bypassed**, fired **ambiguously**, or the event **recurred / cost a cycle**. A clean waiver of a
one-off gap, or a gate that fired once and was resolved exactly as designed, is **not** material on its
own (it may still be proposed as `worked` when the user's notes ask about it). No signal and no notes →
no candidates.

### Candidate schema (nine fields, categorical — no numeric scores)

| Field | Content |
|---|---|
| Event | what happened, one line |
| Expected | what the workflow should have done |
| Observed evidence | an artifact path or a quoted line — never a paraphrase |
| Impact | effect on scope, quality, safety, time, or confidence |
| Safeguard | the gate / STOP / cycle / guard / instruction that applies |
| Safeguard result | `worked` · `failed` · `missing` · `ambiguous` · `bypassed` |
| Generalizability | `one-off` · `repo-specific` · `reusable` |
| Recommended owner | `repo instructions` · `run artifacts` · `feature-flow command/skill` · `feature-flow reference doc` · `guard/validator script` · `regression/forward test` · `new skill` · `no change` |
| Proposed validation | how a fix would be shown to work |

A finding whose owner is **`regression/forward test`** states its proposed validation as
**Fired input / Expected outcome / Control input** (control when applicable) — the case shape in
`evals/forward/README.md` in the feature-flow repository (repo-internal, not shipped with the
plugin), so it converts 1:1 into a forward-test case. `ff-retro` never creates the
case (or any other fix) itself. **`new skill`** is recommended only when the need has a distinct
intent, recurs across repositories, has a clear owner, and no existing command can own it.

### Confirm gate (cross-turn, mandatory in both modes)

The **KB capture confirm-gate shape**, reused (§Knowledge base → Capture rule): `ff-retro` presents
the candidates and **ends its turn**; **nothing is written until the user accepts, edits, or rejects
each one**. The user's own reply is the only input that resolves it — autopilot, a headless
session, or the assistant never answers it. It is a **passive confirm gate**: not an unconditional
STOP (nothing is wrong), not a capped cycle (nothing retries). Zero candidates → the gate says
**"no material events"** and still waits for the user's confirmation.

### Write mechanics

On confirmation, write `retro.md` from `templates/retro.md` at the **Durable artifact resolution**
path, containing **only accepted findings** (as edited) plus the **rejected count**. Zero candidates
proposed → the findings section reads `_No material events._`; candidates proposed but all rejected →
`_No accepted findings — see Rejected._` (the record never says "no material events" when events were found). Record the path in **both**
`artifacts.retro` and `phases.retro.artifact`, set `phases.retro.status = "complete"`, bump
`updatedAt`. **Nothing else is created or modified** — no KB entry, no code, no instruction or skill
edit, no `git add`/`commit`. Improvements are separate, user-initiated work.

### v1 non-goals

- Applying any improvement, or scaffolding forward-test cases, from a finding.
- Writing KB entries (KB capture already ran at the done-transition).
- Transcript mining — only on-disk signals and user notes.
- A machine-enforced (hook) gate — the confirm gate is prose, like KB capture.
- Aggregating retros across runs.
