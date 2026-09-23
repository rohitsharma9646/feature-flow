# feature-flow

A Claude Code (and Codex) plugin that turns "build this feature" or "fix this bug" into a
**gated, resumable, verified** workflow — instead of a one-shot edit you have to babysit.

> **Status:** v0.19.0 · MIT licensed

## Why use it

Ad-hoc AI coding drifts: it builds the wrong thing, loses context mid-task, or claims "done"
without proof. feature-flow fixes all three with a durable pipeline:

- **Align before building** — a *clarify* phase locks testable acceptance criteria and makes you
  sign off before any code is written.
- **Never lose your place** — every run's state lives on disk in `.feature-flow/<slug>/`, so an
  interrupted session resumes exactly where it stopped.
- **Proof, not promises** — the *verify* phase actually runs your tests/build/lint **plus every
  detected evidence surface** (Playwright e2e, HTTP/API, DB via your own CLI, `bin/magento`-style
  CLI output, logs, before/after), maps every acceptance criterion to captured evidence with a
  mechanical confidence level, and produces a client-sign-off-grade `verify.md`. Insufficient
  evidence **blocks "done"** unless you explicitly waive the gap.

It runs **two tracks over one spine**:

- **Feature** — `explore → clarify → design → plan → implement → review → verify`
  (small features can run a **lite** tier that skips design + plan but keeps sign-off).
- **Bugfix** (test-first) — `diagnose → implement (failing test → RED → fix → GREEN) → verify → review`.

The full behavioral contract lives in
[skills/feature-flow/SKILL.md](skills/feature-flow/SKILL.md); the on-disk state format in
[docs/manifest-schema.md](docs/manifest-schema.md).

## Install

### Claude Code

```
claude plugin marketplace add rohitsharma9646/feature-flow#dist
claude plugin install feature-flow@feature-flow
```

Then **fully restart Claude** — plugins load at startup, so `/clear` or a new conversation is
**not** enough.

`#dist` installs from the `dist` branch, which CI publishes on every push to `master` and which holds
**only the runtime files** (commands, agents, skills, hooks, templates, config, the reference docs).
The development repo — Go sources, tests, eval fixtures, CI scripts, run history — never lands on
your machine. Runtime needs are just bash and `jq`.

**Already installed from the full repo?** Re-add the marketplace once so its local clone is clean too:

```
claude plugin marketplace remove feature-flow
claude plugin marketplace add rohitsharma9646/feature-flow#dist
claude plugin install feature-flow@feature-flow
```

(Your plugin cache is already clean after `claude plugin update feature-flow@feature-flow` — the
marketplace entry now points at `dist` — but the old marketplace clone keeps the full repo until you
re-add it.)

### Codex

Build a package and add it through your personal marketplace:

```
scripts/package-codex-plugin.sh --install-link
codex plugin add feature-flow@personal
```

Start a new Codex thread afterward so the skills load. (Enforcement is machine-checked only on
Claude Code — see [Enforcement](#enforcement).)

## Quick start

Kick off a feature run:

```
/feature-flow:ff "add a --csv flag to the export command"
```

It classifies the request (feature vs. bugfix), creates the run, asks **autopilot or
step-by-step?** once, and starts phase 1. Each phase writes an artifact and **stops** for you:

| Phase | What happens | Artifact |
|---|---|---|
| **explore** | Read-only agents map the codebase | `explore.md` |
| **clarify** | Challenges the premise, locks acceptance criteria, asks you to **sign off**; on non-trivial full-tier work also captures optional **success metrics** + a **requirement graph** | `spec.md` |
| **design** | Architect agents fan out (minimal / clean / pragmatic); scores a lean trade-off matrix; stress-tests the pick with a devil's-advocate pass (≥1 failure scenario); you pick | `design.md` |
| **plan** | Decomposes the design into tasks with an Outcome gate | `plan.md` |
| **implement** | Refuses to code until the spec is signed, then builds task by task | *(code)* |
| **review** | Reviewer agents report issues, plus a spec-conformance reviewer that checks the diff against the spec/plan (missing criterion = Critical, out-of-scope change = Important); a Critical finding blocks the run | `review.md` |
| **verify** | Really runs tests/build/lint + detected evidence surfaces; maps each criterion (plus full-tier design failure scenarios and spec success metrics) to evidence + confidence; gaps block done | `verify.md` + `evidence/` |

Every stop ends with a progress strip, e.g.
`explore[done] → clarify[done] → design[NEXT] → plan → implement → review → verify`.

A bug report takes the other track:

```
/feature-flow:ff "fix: save throws TypeError on empty title"
```

→ diagnose (reproduce + root cause) → implement (write a failing regression test, watch it go RED,
fix, confirm GREEN) → verify → review.

## Autopilot

By default each run asks **autopilot or step-by-step?** In autopilot the phases chain
automatically, pausing only at the gates that genuinely need you:

1. `/feature-flow:ff "..."` → pick **autopilot** → explore + clarify run, then it pauses at
   **sign-off**.
2. Your sign-off resumes the chain: design pauses for **your architecture pick**, then plan →
   implement → review → verify run through.
3. If review finds Critical issues, autopilot fixes and re-reviews **once**; if any remain it stops
   for you.

Auto-completed phases show `[auto]` in the strip. **Sign-offs are never automated** — every gate
still applies. Set `toggles.autopilot` to `true`/`false` in `.feature-flow.json` to skip the
run-start question. Full rules: `docs/manifest-schema.md` §Autopilot.

## Enforcement

On Claude Code, two gates are **machine-enforced** by a PreToolUse hook (on by default, requires
`jq`): no run enters **implement** without sign-off, and none reaches **done** without valid verify
(and, on bugfix, review) evidence on disk — for `verify.md` that now includes a content check
(a `## Contract mapping` section and at least one captured exit/HTTP/status code), so an
empty-shell report can no longer pass. The hook **fails open** — it blocks only a provably
illegal state write and otherwise stays out of the way. It gates `Write`, `Edit`, and `MultiEdit`
of a manifest alike (an Edit is judged on the manifest it would produce); a manifest rewritten
through a shell command is outside its reach. Disable with `toggles.enforce: false`. On
Codex (no hook mechanism) these gates are enforced by prose instruction, not code.

A second hook re-anchors context: at session start, after `/clear`, and after an automatic
compaction, it lists this project's active runs (slug, phase, sign-off, resume command, artifact
paths) so the model continues from the on-disk manifest instead of a lossy summary.

## Evidence-based verification

Every verify phase is **evidence-driven, never assumption-driven**: no run reaches `done` on
code inspection or reasoning alone.

- **Eight evidence kinds** — executed-test, build/static-analysis, e2e/browser (Playwright CLI),
  http/api (curl, real HTTP status), db (your project's own CLI), cli-output, logs,
  before/after. Detection is automatic: `package.json`, Makefile, pyproject, `composer.json`,
  `phpunit.xml(.dist)`, `playwright.config.*`, `bin/magento`, MFTF.
- **Mechanical confidence, no scores** — each criterion gets one of `Verified (multi-source)` /
  `Verified (single-source)` / `Partially verified` / `Unverified`, derived by counting the
  distinct evidence kinds that passed — recountable from the report, never an LLM-asserted number.
- **Gaps block done** — a detected surface that didn't run/pass is an explicit gap; any item
  below `Verified (single-source)` stops the run with a gap report (what, why, what evidence is
  required). Only an explicit user waiver (`Evidence gap accepted by user (<date>): <reason>`)
  unblocks it — and it never upgrades the stated confidence.
- **Client-ready report** — `verify.md` carries the coverage matrix, per-criterion evidence
  blocks (commands, status codes, `evidence/` artifacts), limitations & remaining risks, and an
  overall confidence — suitable for client acceptance. With `paths.durable` set it promotes out
  of the sandbox with its `evidence/` directory copied alongside.
  > **Note:** promoted `evidence/` directories can contain large binaries (screenshots, traces).
  > feature-flow never runs `git add` — review what you commit.
- The floor (executed tests/build/lint with real exit codes) is **tier-invariant**; the widened
  breadth applies to full-tier runs.

Full contract: `docs/manifest-schema.md` §Evidence.

## Knowledge base (on by default)

feature-flow **remembers** what a run decided and **recalls** it in later runs, so you don't
re-derive or contradict a settled decision. It's **on by default** (store: `.feature-flow-kb/`
at your repo root; override with `paths.kb`). To opt out per-project:

```json
{ "toggles": { "kb": false } }
```

- **Capture** at run close, confirm-gated — it proposes 1–3 entries, you accept/edit/reject.
  Accepted entries are project-local, git-committed markdown with provenance; you commit them.
- **Recall** at the start of *explore*, *design*, and *diagnose* — tag-matched entries are
  surfaced as context.
- **Staleness** — an entry is flagged `[STALE]` (shown, never silently dropped) if a referenced
  file is gone or it's older than `kb.freshnessWindowDays`.
- **Not in v1:** dedup and supersession of near-duplicate entries (deferred to a fast-follow).

Full contract: `docs/manifest-schema.md` §Knowledge base.

## Commands

| Command | What it does |
|---|---|
| `/feature-flow:ff "<request>"` | Entry point: classify, create the run, ask autopilot vs step-by-step, start phase 1 |
| `/feature-flow:ff-explore` | [feature] Fan out read-only explorers → `explore.md` |
| `/feature-flow:ff-clarify` | [feature] Grill requirements, write `spec.md`, collect sign-off |
| `/feature-flow:ff-design` | [feature] Architect fan-out + lean trade-off matrix + devil's-advocate pass, record the chosen design → `design.md` |
| `/feature-flow:ff-plan` | [shared] Decompose into a phased `plan.md` with an Outcome gate |
| `/feature-flow:ff-diagnose` | [bugfix] Reproduce + root-cause, decide hotfix-vs-proper → `diagnosis.md` |
| `/feature-flow:ff-implement` | [shared] Build from the plan (sign-off gated) / test-first bugfix (RED→GREEN) |
| `/feature-flow:ff-review` | [shared] Reviewer fan-out → `review.md`; Critical findings block |
| `/feature-flow:ff-verify` | [shared] Really run tests/build/lint + evidence surfaces; confidence-graded report; one autopilot repair-and-re-verify cycle on a genuine failure; gaps block done |
| `/feature-flow:ff-deliver` | [shared] Optional, post-`done`: assemble `delivery.md` (release notes / deploy / rollback / migration / known issues) from upstream artifacts; never blocks done |
| `/feature-flow:ff-retro` | [shared] Optional, post-`done`: classify what the workflow's safeguards did (worked / failed / missing / ambiguous / bypassed), route each lesson to one owner → `retro.md`, written only after you confirm each finding |
| `/feature-flow:ff-status` | Print a run's track, tier, phase statuses, sign-off, artifacts |
| `/feature-flow:ff-resume` | Re-enter an interrupted run at the first incomplete phase |
| `/feature-flow:ff-list` | List ALL runs (incl. abandoned/closed) |
| `/feature-flow:ff-abandon <slug>` | Mark a run abandoned (excluded from auto-resolution) |
| `/feature-flow:ff-close <slug>` | Close a `done` run (excluded from auto-resolution) |

On autopilot runs, phase commands chain into the next phase instead of stopping.

## Configuration

Drop a `.feature-flow.json` at your repo root to override the shipped defaults:

| Key | Default | Effect |
|---|---|---|
| `explorerAgents` | `3` | Parallel explorer agents in *explore* |
| `architectAgents` | `3` | Parallel architect agents in *design* |
| `reviewerAgents` | `3` | Parallel reviewer agents in *review* (the spec-conformance reviewer is extra, not counted) |
| `diagnosticianAgents` | `1` | Diagnostician agents in *diagnose* |
| `models.*` | `"sonnet"` | Model for each agent role: `explorer`, `architect`, `reviewer`, `diagnostician`, `testRunner` |
| `reviewThreshold` | `80` | Reviewers report only issues with confidence ≥ this (0–100) |
| `toggles.tdd` | `true` | Test-first on the feature track (bugfix RED→GREEN is always on) |
| `toggles.worktree` | `false` | Implement in an isolated git worktree |
| `toggles.greenfield` | `false` | Relax git-diff assumptions for new/non-git projects |
| `toggles.autopilot` | `"ask"` | `"ask"` (per-run prompt), `true` (always), or `false` (never) |
| `toggles.enforce` | `true` | Machine-enforce the sign-off and evidence gates (Claude Code) |
| `toggles.kb` | `true` | Knowledge base master switch — set `false` to opt out |
| `paths.base` | `".feature-flow"` | Run sandbox root |
| `paths.durable` | `null` | Directory for **committed** decision docs; unset keeps everything in the gitignored sandbox |
| `paths.kb` | `".feature-flow-kb"` | Knowledge base store directory (repo-relative); `null` also disables the KB |
| `kb.freshnessWindowDays` | `90` | Age past which a recalled entry is flagged stale |
| `kb.maxRecallEntries` | `5` | Max KB entries surfaced at recall |

> **Models & 1M context:** on the Anthropic API, `"sonnet"` already resolves to Sonnet 5 with the
> full 1M-token context window — nothing to enable. The explicit form `"sonnet[1m]"` only matters
> behind an LLM gateway or on Bedrock/Vertex with older Sonnet versions.

`paths.spec` / `paths.plan` also exist as legacy per-artifact overrides — see
`docs/manifest-schema.md` for those and the full resolution rules.

## Native integrity operations

The CI-built native packages (`scripts/build-integrity-packages.sh`, one per platform) include a
directly invocable `ff-integrity` binary. It is **not** part of the marketplace (`#dist`) install:

```sh
ff-integrity doctor <slug> --format human
ff-integrity doctor --all --format json
ff-integrity migrate <slug> --to 1 --dry-run --format json
ff-integrity migrate <slug> --to 1 --apply --expect-plan sha256:<reviewed-digest>
```

Doctor and preview are strictly read-only. Apply is explicit, retains the exact legacy bytes, and
refuses source, profile, plan, or artifact-pointer drift. Terminal runs additionally require
`--confirm-reopen-terminal`. Existing Feature Flow commands and hooks do not invoke these
operations automatically. See `docs/integrity/wp2-operations.md`.

## Troubleshooting

- **Commands not found after install** — fully restart Claude. `/clear` doesn't reload plugins.
- **A command picked the wrong run** — run `/feature-flow:ff-list`, then pass the slug explicitly
  (e.g. `/feature-flow:ff-status my-run`). Abandon stale runs with `/feature-flow:ff-abandon`.
- **Resume re-entered a phase you thought was done** — the artifact was missing or failed its
  validity check (disk is the source of truth); the resume message names the file.
- **`models.*` not taking effect** — key names must match exactly:
  `explorer` / `architect` / `reviewer` / `diagnostician` / `testRunner`.

## Development

Working on the plugin itself, not just using it:

- **Claude Code source edits** — the install **copies** source into
  `~/.claude/plugins/cache/feature-flow/feature-flow/<version>/` (not a symlink). After editing,
  refresh with uninstall + reinstall (`claude plugin update` no-ops on an unchanged version), then
  restart the session.
- **Codex packaging** — `.codex-plugin/plugin.json` holds the Codex metadata. Rebuild the package
  after source edits with `scripts/package-codex-plugin.sh --install-link` (updates the
  `~/.agents/plugins/marketplace.json` symlink to `dist/codex/feature-flow`), then reinstall and
  start a new Codex thread.
- **Forward tests** — `scripts/forward-test.sh [behavior...]` proves the 7 semantic behaviors (STOPs,
  gap lines, repair cycle) fire in a fresh headless Claude session and stay quiet on a control input.
  It is local-only (needs Claude credentials, about $4 for the full suite) and never run in CI. Re-run
  the affected behavior after editing its instruction text. See `evals/forward/README.md`.

## License

MIT — see [LICENSE](LICENSE).
