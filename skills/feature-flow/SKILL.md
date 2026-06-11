---
name: feature-flow
description: Use when developing a non-trivial feature or fixing a bug and you want a durable, resumable, verified workflow. Runs two tracks (feature: explore→clarify→design→plan→implement→review→verify; bugfix test-first: diagnose→failing-regression-test→fix→verify→review) over on-disk artifacts with real executed verification. Triggers on "build a feature", "add X", "fix this bug", "/feature-flow:ff", or any request that benefits from gated, recoverable, evidence-backed development.
---

# feature-flow

A composable, durable, verifying workflow for **feature development** and **bug fixing**.
Two tracks share one spine; each phase is a standalone command that reads and writes
on-disk artifacts, so work is resumable and a dropped session is recoverable.

## When to use which track

- **Feature** — adding new behavior. Phases:
  `explore → clarify → design → plan → implement → review → verify`.
- **Bugfix** — restoring intended behavior in existing code. Phases (test-first):
  `diagnose → implement (write failing regression test → RED → fix → GREEN) → verify → review`.

`/feature-flow:ff "<request>"` classifies the request and runs the matching track, pausing at human
gates. If a request is genuinely both, split it: fix first, then feature — don't run a
hybrid. Every phase is also runnable standalone (`/feature-flow:ff-explore`, `/feature-flow:ff-clarify`,
`/feature-flow:ff-design`, `/feature-flow:ff-plan`, `/feature-flow:ff-diagnose`, `/feature-flow:ff-implement`, `/feature-flow:ff-review`, `/feature-flow:ff-verify`),
plus `/feature-flow:ff-status` and `/feature-flow:ff-resume`.

## The manifest is the shared state

Each run lives in `.feature-flow/<slug>/` with a `manifest.json` recording `track`,
`tier`, `currentPhase`, per-phase status + artifact paths, and sign-off. Every command:
**read the manifest → check the gate → do the phase → write the artifact → update the
manifest.** Resume and status read this file; if it's missing, resume infers the phase
from which artifacts exist on disk.

## Soft gates (honor them)

Nothing in the harness fails closed — the gates are prose you must respect:

- **Sign-off gate:** on the feature track (and escalated bugfixes), `/feature-flow:ff-implement` does
  **not** write code until `spec.md` is signed off. If it reads `Signed off: no`, stop and
  route back to `/feature-flow:ff-clarify`.
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
