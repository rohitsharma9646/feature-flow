---
name: feature-flow
description: 'Use when developing a non-trivial feature or fixing a bug and you want a durable, resumable, verified workflow. Runs two tracks (feature: explore→clarify→design→plan→implement→review→verify; bugfix test-first: diagnose→failing-regression-test→fix→verify→review) over on-disk artifacts with real executed verification. Triggers on "build a feature", "add X", "fix this bug", "/feature-flow:ff", or any request that benefits from gated, recoverable, evidence-backed development.'
---

# feature-flow

A composable, durable, verifying workflow for **feature development** and **bug fixing**.
Two tracks share one spine; each phase is a standalone command that reads and writes
on-disk artifacts, so work is resumable and a dropped session is recoverable.

## Platform adaptation

Claude Code exposes the files under `commands/` as slash commands. Other agent
platforms should preserve the same workflow contract with their native tools. In
Codex, read `references/codex-tools.md` before following a phase procedure.

## When to use which track

- **Feature** — adding new behavior. Phases:
  `explore → clarify → design → plan → implement → review → verify`.
  *clarify* challenges the premise (is this the right need?), weighs 2-3 problem-level solution
  approaches, and locks testable acceptance criteria — it owns the WHAT; *design* owns the HOW
  (architects fan out, score a lean trade-off matrix, and stress-test the pick with a
  devil's-advocate pass naming ≥1 failure scenario that *verify* later proves or blocks done on).
  A small, single-approach **lite feature** (`tier: lite`, soft-judged at entry — in doubt,
  full) runs `explore → clarify → implement → review → verify`, skipping the design + plan
  phases and using a 1-agent explore while keeping sign-off; it can escalate to full before
  implement if it turns out bigger.
- **Bugfix** — restoring intended behavior in existing code. Phases (test-first):
  `diagnose → implement (write failing regression test → RED → fix → GREEN) → verify → review`.
- **Delivery (optional, both tracks).** After a run is `done`, `/feature-flow:ff-deliver` assembles
  a `delivery.md` (release notes, deploy/rollback/migration checklists, known issues, release
  validation) by **consuming** the run's upstream artifacts. It is **post-terminal and non-gated** —
  it never blocks `done`, is off for `tier: lite` unless requested, and autopilot never runs it; you
  invoke it by hand. A plan migration task missing its rollback line surfaces here as a non-blocking
  `⚠ DELIVERY GAP`. See `docs/manifest-schema.md` §Delivery.

## Starting a run — you do NOT have to type a command

This skill is **self-executing**. There are two ways a run begins, and in both you (the
assistant) drive it — the user never has to know the command names:

1. **Auto-trigger (the common path).** When this skill fires from a natural-language
   request for non-trivial work — *"add a greeting flag"*, *"build a CSV exporter"*,
   *"fix: clicking save throws"* — **do not just tell the user to run `/feature-flow:ff`.**
   Start the run yourself, following the entry procedure below. Briefly announce which track
   you detected ("This is a feature — starting a feature-flow run"), then proceed.
2. **Explicit command.** `/feature-flow:ff "<request>"` does the exact same thing on demand.

**Entry procedure (identical to `/feature-flow:ff`; the canonical steps live in
`${CLAUDE_PLUGIN_ROOT}/commands/ff.md` — read and follow them):**
1. **Classify** feature vs bugfix (soft judgment). Ambiguous → ask once. Genuinely both →
   split (fix first, then feature), don't run a hybrid.
2. **Read config** (`.feature-flow.json` → `config/defaults.json`), then **resolve
   `autopilot` first** (run-start procedure in `docs/manifest-schema.md` §Autopilot —
   BEFORE the manifest write): config `toggles.autopilot` — `"ask"` (default) → ask the
   user once (autopilot vs step-by-step); `true`/`false` → use directly, no ask; never
   re-ask a run that already has the field, and never choose the value yourself.
3. **Write the `manifest.json`** with the resolved `track` AND `autopilot`. **If you are
   in plan mode**, the manifest write is blocked — call `ExitPlanMode` first (the
   feature-flow run IS the plan), or tell the user to exit plan mode and re-run. See Step
   2.0 in `commands/ff.md`.
4. **Run the first phase only** — feature → `explore` inline; bugfix → hand off to the gated
   `diagnose` phase — then **STOP** at the phase boundary. In step-by-step mode, do not
   chain forward.

After the first phase, the modes diverge. **Step-by-step** (`autopilot: false` or absent):
continue **phase by phase** — each later phase is its own command the user (or you) invokes
next, so every human gate is honored and a dropped session is recoverable. **Autopilot**
(`manifest.autopilot: true`): ceremonial phase-end STOPs become continuations — chain
forward per **Autopilot** in `docs/manifest-schema.md`, pausing at every mandatory gate.

**Unconditional in BOTH modes — these lines never bend:** never run past a spec or
diagnosis sign-off gate on your own; never set `signOff.signed` yourself;
never choose `manifest.autopilot` yourself (config `"ask"` → the value comes only from
the user's answer, asked **before** the manifest is written); never proceed
past a not-reproduced diagnosis; never route forward past an unresolved Critical review
block (autopilot gets exactly one fix-and-re-review cycle, then stops); never attempt a
second verify repair cycle on a genuine failure (on a full-tier run autopilot gets exactly
one repair-and-re-verify cycle, then the gap-report stop). Honor the STOPs.

> **Proportional ceremony / don't over-fire.** This is for *non-trivial* work. A genuine
> one-line typo fix or an obvious, reversible change does not need a full run — just do it
> (the bugfix **lite** path already keeps trivial bugs cheap). Reserve the workflow for work
> that benefits from gated, recoverable, evidence-backed development.

**Manual controls (these DO require typing, no natural-language trigger exists):** the
individual phases `/feature-flow:ff-explore`, `/feature-flow:ff-clarify`, `/feature-flow:ff-design`,
`/feature-flow:ff-plan`, `/feature-flow:ff-diagnose`, `/feature-flow:ff-implement`,
`/feature-flow:ff-review`, `/feature-flow:ff-verify`, `/feature-flow:ff-deliver` (optional,
post-`done` delivery notes), plus the run-management commands:
`/feature-flow:ff-status` (inspect a run), `/feature-flow:ff-resume` (re-enter an interrupted
run), `/feature-flow:ff-list` (list all runs, including abandoned/closed),
`/feature-flow:ff-abandon <slug>` (drop a run from automatic resolution), and
`/feature-flow:ff-close <slug>` (close a `done` run).

## The manifest is the shared state

Each run lives in `.feature-flow/<slug>/` with a `manifest.json` recording `track`,
`tier`, `currentPhase`, per-phase status + artifact paths, and sign-off.
**`manifest.artifacts.<name>` is the sole authority for locating an artifact**
(`phases.<phase>.artifact` is a human-readable display mirror, never used to find a file).
With `paths.durable` set, the durable decision docs (spec/design/plan/diagnosis) are
**promoted** — as each producing phase completes — to a committed
`<paths.durable>/<createdAt-date>-<slug>/` directory instead of the gitignored sandbox, so a
teammate reviewing the PR sees the reasoning; see **Durable artifact resolution** in
`docs/manifest-schema.md`. Every command: **read the manifest → check the gate → do the phase
→ write the artifact → update the manifest.** Resume and status read this file; if it's
missing, resume infers the phase from which artifacts exist on disk.

## Soft gates (honor them)

The gates are prose you must respect. On Claude Code, two of them are additionally
**machine-enforced** by the `enforce-gate` PreToolUse hook — it denies a manifest write that
enters `implement` without sign-off, or reaches `done` without verify/review evidence (requires
`jq`; disable with `toggles.enforce: false`). On Codex the gates remain prose-only. The hook
backstops the prose; honoring the gates below is still your job:

- **Sign-off gate** (differs by track — the bugfix track has no clarify/design phase):
  - **Feature track:** sign-off is **collected at the end of `/feature-flow:ff-clarify`** and
    gates everything downstream — `ff-design`, `ff-plan`, and `ff-implement` each require a
    **signed** `spec.md` (lock the WHAT before building the HOW) and route back to
    `/feature-flow:ff-clarify` on `Signed off: no` / `signOff.signed: false`.
  - **Escalated (`full`) bugfix:** the contract is `diagnosis.md` (there is no clarify or
    design phase); sign-off is **collected at the end of `/feature-flow:ff-diagnose`** (mirroring
    clarify) and gates `ff-plan` and `ff-implement`. Lite bugfixes need no sign-off — a
    confirmed `diagnosis.md` is the gate.
  - `/feature-flow:ff-implement` is the hard backstop on every track: it writes **no** code until
    the track's gate is satisfied (AC4).
- **Diagnosis gate (bugfix):** `/feature-flow:ff-implement` requires a confirmed `diagnosis.md`
  (reproduced + root cause + chosen fix approach). An unreproduced bug never proceeds to a
  fix — guessing a fix for an unconfirmed bug is forbidden.
- **Verification gate:** `/feature-flow:ff-verify` refuses "done" on evidence gaps — every
  contract item must clear the mechanical confidence bar or the run ends with a gap report,
  pending the user's explicit waiver. Contract: `docs/manifest-schema.md` §Evidence;
  doctrine: **Real verification, not reasoning** below. A bugfix without a RED→GREEN
  regression test is incomplete.

## Proportional ceremony

Match the ritual to the work. A trivial, obvious bug takes the **lite** bugfix path: a
short `diagnosis.md` (repro + root cause + fix approach) is the gate — no separate
signed-off spec. Larger bugs escalate to **full**: a `plan.md` + sign-off, like a feature.
Don't impose feature-weight ceremony on a one-line fix, and don't skip the spec on real
feature work.

The **feature** track mirrors this: a small feature takes the **lite** tier (skips the
design + plan phases, 1-agent explore, keeps sign-off); a larger one stays **full**. Tier is
soft-judged at entry — in doubt, full — and a lite run can escalate to full before implement.

## Solution horizon

When a bug has a quick band-aid and a proper root-cause fix, `diagnosis.md` names **both**
with a recommendation — even when the recommendation is "proper fix only." Default to the
long-term fix; if a hotfix is right, write down what the proper fix would be so the
band-aid doesn't calcify.

## Real verification, not reasoning

Verification means the `ff-test-runner` agent (which has `Bash`) actually ran the tests,
build, and lint and returned real output. The analysis agents (`ff-code-explorer`,
`ff-code-architect`, `ff-code-reviewer`, `ff-diagnostician`) are strictly read-only.
"Tests pass" is a claim you back with captured output in `verify.md`, never an assertion.

Since v0.9.0 verification is **evidence-based across the project's whole detected surface**
(`docs/manifest-schema.md` §Evidence — the canonical contract): eight evidence kinds
(executed-test, build/static-analysis, e2e/browser via Playwright CLI, http/api, db,
cli-output, logs, before/after) captured as literal records with real exit/HTTP status
codes and files under `<run dir>/evidence/`; per-criterion confidence derived
**mechanically** by counting distinct passing kinds — the four levels
`Verified (multi-source)` / `Verified (single-source)` / `Partially verified` /
`Unverified`, never a numeric score; detected-but-ungathered surfaces are explicit gaps
(N/A only for undetected surfaces, always with a reason); and any item below
`Verified (single-source)` blocks `done` pending the user's explicit waiver. Code
inspection alone is never proof — that rule now spans both tracks, not just the bugfix
RED→GREEN contract.

## Searching the repo (performance)

When you (or any `Bash`-capable step) search the codebase, use the **Grep** and **Glob**
tools — **never** Bash `grep -r` / `find` over the repo root. They run ripgrep, honor
`.gitignore`, and are far faster on large repos because they skip the ignored dependency,
build, and cache trees that `grep -r`/`find` would otherwise walk in full. Reserve Bash
`grep`/`find` for a scoped subdirectory or a piped filter — not the root. The read-only
analysis agents already lack `Bash` and search via these tools; keep it that way.

## Knowledge base

**On by default** (since v0.8.0): `toggles.kb: true` and `paths.kb: ".feature-flow-kb"` ship as
defaults, so every project has an active KB from its first run. Opt out in `.feature-flow.json`
with `toggles.kb: false` (or `paths.kb: null`) — either cleanly deactivates capture and recall.
The canonical contract is `docs/manifest-schema.md` §Knowledge base — the commands reference it
by name.

- **Capture** (confirm-gated, at the terminal phase — `ff-verify` feature / `ff-review` bugfix, with
  a feature-track guard on `ff-review` so feature runs don't double-capture): feature-flow distills
  1–3 candidate entries from the run's artifacts (architectural decisions + project conventions),
  records provenance (capture date, git commit SHA or `null`, referenced files, topic tags), and
  writes only the entries you accept — **no `git add`/`commit`** (write-only; you commit).
- **Recall** (wired into `ff-explore`, `ff-design`, and `ff-diagnose`, before each fan-out):
  tag-matches the request against stored entries and surfaces up to `kb.maxRecallEntries` to the
  agents as context.
- **Staleness:** an entry is flagged stale if a referenced file is missing/moved OR it is older than
  `kb.freshnessWindowDays` (default 90). Stale entries are **decorated, never dropped and never shown
  as fresh** — a KB serving knowledge written against since-changed code is worse than none.
- **v1 non-goals (deferred to a fast-follow run):** **dedup** of near-duplicate entries and
  **supersession** (a newer entry marking an older one obsolete) are NOT in v1 — duplicates persist
  and are surfaced, not silently dropped. Also deferred: an `index.json`, a standalone `ff-learn`
  command, content-similarity relevance, mid-run capture, auto-commit, and a cross-project KB.
