# feature-flow

Composable, durable, verifying Claude Code plugin for **feature development** and **bug fixing** — two tracks, one spine, real (executed) verification.

> **Status:** v0.2.0.

## What it is

Two gated, resumable workflows over on-disk artifacts, each verified by really-executed tests:

- **Feature track** — `explore → clarify → design → plan → implement → review → verify`.
  *clarify* challenges the premise, weighs problem-level solution approaches, and locks testable
  acceptance criteria (it owns the WHAT; *design* owns the HOW).
- **Bugfix track** (test-first) — `diagnose → implement (failing regression test → RED → fix →
  GREEN) → verify → review`.

All run state lives in a `.feature-flow/<slug>/` sandbox with a `manifest.json`, so work is
resumable and a dropped session is recoverable. The full behavioral contract (gates, tracks,
proportional ceremony) lives in [skills/feature-flow/SKILL.md](skills/feature-flow/SKILL.md);
the manifest/state contract in [docs/manifest-schema.md](docs/manifest-schema.md).

## Install

### Teammate install (using the plugin)

```
claude plugin marketplace add rohitsharma9646/feature-flow
claude plugin install feature-flow@feature-flow
```

Then **fully restart your Claude session** — plugins load at process startup, so a new
conversation or `/clear` is not enough.

### Plugin author (local development)

The install **copies** source into `~/.claude/plugins/cache/feature-flow/feature-flow/<version>/`
(not a symlink). After editing the source, refresh the cache with **uninstall + reinstall**
(`claude plugin update` no-ops on an unchanged version), then fully restart the session.

## Quick start — a worked feature run

```
/feature-flow:ff "add a --csv flag to the export command"
```

1. **explore** runs immediately: read-only explorer agents map the codebase, findings land in
   `.feature-flow/add-csv-flag/explore.md`. STOP.
2. `/feature-flow:ff-clarify` — grills the premise, weighs 2–3 solution approaches, writes
   `spec.md`, and asks you to **sign off**, quoting the acceptance criteria verbatim. STOP.
3. `/feature-flow:ff-design` — architect agents fan out (minimal/clean/pragmatic), you pick;
   `design.md` records the choice and rejected alternatives. STOP.
4. `/feature-flow:ff-plan` — decomposes the design into tasks with a populated Outcome gate in
   `plan.md`. STOP.
5. `/feature-flow:ff-implement` — refuses to write code until the spec is signed; then executes
   the plan task by task. STOP.
6. `/feature-flow:ff-review` — reviewer agents report issues ≥ the confidence threshold into
   `review.md`; a Critical finding blocks the run until resolved. STOP.
7. `/feature-flow:ff-verify` — `ff-test-runner` actually executes tests/build/lint and maps
   every acceptance criterion to pass/fail with evidence in `verify.md`. Run is `done`.

Every STOP message ends with a progress strip, e.g.
`explore[done] → clarify[done] → design[NEXT] → plan → implement → review → verify`.

A bug report (`/feature-flow:ff "fix: save throws TypeError"`) takes the bugfix track instead:
diagnose (reproduce + root cause + sign-off if escalated) → implement (failing regression test,
RED, fix, GREEN) → verify → review.

## Commands

| Command | What it does |
|---|---|
| `/feature-flow:ff "<request>"` | Entry point: classify feature vs bugfix, create the run, start the first phase |
| `/feature-flow:ff-explore` | [feature] Fan out read-only explorers, write `explore.md` |
| `/feature-flow:ff-clarify` | [feature] Grill requirements, write `spec.md`, collect sign-off |
| `/feature-flow:ff-design` | [feature] Architect fan-out, record the chosen design in `design.md` |
| `/feature-flow:ff-plan` | [shared] Decompose the contract into a phased `plan.md` with an Outcome gate |
| `/feature-flow:ff-diagnose` | [bugfix] Reproduce + root-cause, decide hotfix-vs-proper, write `diagnosis.md` |
| `/feature-flow:ff-implement` | [shared] Build from the plan (sign-off gated) / test-first bugfix (RED→GREEN) |
| `/feature-flow:ff-review` | [shared] Reviewer fan-out into `review.md`; Critical findings block |
| `/feature-flow:ff-verify` | [shared] Really execute tests/build/lint; map the contract to pass/fail |
| `/feature-flow:ff-status` | Print a run's track, tier, phase statuses, sign-off, artifacts |
| `/feature-flow:ff-resume` | Re-enter an interrupted run at the first incomplete (or invalid) phase |
| `/feature-flow:ff-list` | List ALL runs — slug, track, tier, phase, dates — incl. abandoned/closed |
| `/feature-flow:ff-abandon <slug>` | Mark a run abandoned (excluded from automatic run resolution) |
| `/feature-flow:ff-close <slug>` | Close a `done` run (excluded from automatic run resolution) |

## Configuration

A repo-root `.feature-flow.json` overrides `config/defaults.json`:

| Key | Default | Effect |
|---|---|---|
| `explorerAgents` | `3` | Parallel `ff-code-explorer` agents in the explore phase |
| `architectAgents` | `3` | Parallel `ff-code-architect` agents in the design phase |
| `reviewerAgents` | `3` | Parallel `ff-code-reviewer` agents in the review phase |
| `diagnosticianAgents` | `1` | `ff-diagnostician` agents in the diagnose phase |
| `models.explorer` | `"sonnet"` | Model passed to dispatched explorer agents |
| `models.architect` | `"sonnet"` | Model passed to dispatched architect agents |
| `models.reviewer` | `"sonnet"` | Model passed to dispatched reviewer agents |
| `models.diagnostician` | `"sonnet"` | Model passed to dispatched diagnostician agents |
| `models.testRunner` | `"sonnet"` | Model passed to the test-runner agent |
| `reviewThreshold` | `80` | Reviewers report only issues with confidence ≥ this (0–100) |
| `toggles.tdd` | `true` | Test-first on the feature track (bugfix RED→GREEN is always mandatory) |
| `toggles.worktree` | `false` | Implement in an isolated git worktree |
| `toggles.greenfield` | `false` | Relax git-diff assumptions for new/non-git projects |
| `paths.base` | `".feature-flow"` | Run sandbox root |
| `paths.spec` | `null` | Directory to relocate specs to (file becomes `<dir>/<slug>.md`) |
| `paths.plan` | `null` | Directory to relocate plans to (file becomes `<dir>/<slug>.md`) |

## Troubleshooting

- **Commands not found after install** — fully restart the Claude session. Plugins load at
  process startup; a new conversation or `/clear` does not reload them.
- **Edits to the plugin source not taking effect** — the cache is a copy: uninstall, reinstall,
  then restart the session (`plugin update` no-ops on an unchanged version).
- **A command picked the wrong run** — run `/feature-flow:ff-list` to see every run, then pass
  the slug explicitly (e.g. `/feature-flow:ff-status my-run`). Abandon stale runs with
  `/feature-flow:ff-abandon <slug>` so they stop capturing commands.
- **Resume re-entered a phase you thought was done** — the manifest claimed `complete` but the
  artifact was missing or failed its validity check; the resume message names the file. This is
  intentional (disk is the ground truth).
- **`models.*` not taking effect** — key names must match the role exactly:
  `explorer` / `architect` / `reviewer` / `diagnostician` / `testRunner`.

## License

MIT — see [LICENSE](LICENSE).
