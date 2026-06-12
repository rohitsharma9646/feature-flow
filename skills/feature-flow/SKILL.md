---
name: feature-flow
description: 'Use when developing a non-trivial feature or fixing a bug and you want a durable, resumable, verified workflow. Runs two tracks (feature: explore→clarify→design→plan→implement→review→verify; bugfix test-first: diagnose→failing-regression-test→fix→verify→review) over on-disk artifacts with real executed verification. Triggers on "build a feature", "add X", "fix this bug", "/feature-flow:ff", or any request that benefits from gated, recoverable, evidence-backed development.'
---

# feature-flow

A composable, durable, verifying workflow for **feature development** and **bug fixing**.
Two tracks share one spine; each phase is a standalone command that reads and writes
on-disk artifacts, so work is resumable and a dropped session is recoverable.

## When to use which track

- **Feature** — adding new behavior. Phases:
  `explore → clarify → design → plan → implement → review → verify`.
  *clarify* challenges the premise (is this the right need?), weighs 2-3 problem-level solution
  approaches, and locks testable acceptance criteria — it owns the WHAT; *design* owns the HOW.
- **Bugfix** — restoring intended behavior in existing code. Phases (test-first):
  `diagnose → implement (write failing regression test → RED → fix → GREEN) → verify → review`.

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
block (autopilot gets exactly one fix-and-re-review cycle, then stops). Honor the STOPs.

> **Proportional ceremony / don't over-fire.** This is for *non-trivial* work. A genuine
> one-line typo fix or an obvious, reversible change does not need a full run — just do it
> (the bugfix **lite** path already keeps trivial bugs cheap). Reserve the workflow for work
> that benefits from gated, recoverable, evidence-backed development.

**Manual controls (these DO require typing, no natural-language trigger exists):** the
individual phases `/feature-flow:ff-explore`, `/feature-flow:ff-clarify`, `/feature-flow:ff-design`,
`/feature-flow:ff-plan`, `/feature-flow:ff-diagnose`, `/feature-flow:ff-implement`,
`/feature-flow:ff-review`, `/feature-flow:ff-verify`, plus the run-management commands:
`/feature-flow:ff-status` (inspect a run), `/feature-flow:ff-resume` (re-enter an interrupted
run), `/feature-flow:ff-list` (list all runs, including abandoned/closed),
`/feature-flow:ff-abandon <slug>` (drop a run from automatic resolution), and
`/feature-flow:ff-close <slug>` (close a `done` run).

## The manifest is the shared state

Each run lives in `.feature-flow/<slug>/` with a `manifest.json` recording `track`,
`tier`, `currentPhase`, per-phase status + artifact paths, and sign-off. Every command:
**read the manifest → check the gate → do the phase → write the artifact → update the
manifest.** Resume and status read this file; if it's missing, resume infers the phase
from which artifacts exist on disk.

## Soft gates (honor them)

Nothing in the harness fails closed — the gates are prose you must respect:

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
- **Verification gate:** `/feature-flow:ff-verify` refuses "done" unless every contract item has a
  `pass` or an explicit `manual-unverified` line, backed by **real executed** test output
  from `ff-test-runner`. A bugfix without a RED→GREEN regression test is incomplete.

## Proportional ceremony

Match the ritual to the work. A trivial, obvious bug takes the **lite** bugfix path: a
short `diagnosis.md` (repro + root cause + fix approach) is the gate — no separate
signed-off spec. Larger bugs escalate to **full**: a `plan.md` + sign-off, like a feature.
Don't impose feature-weight ceremony on a one-line fix, and don't skip the spec on real
feature work.

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
