# Codex Tool Mapping

Feature Flow was written first for Claude Code, where the files under
`commands/` are slash commands. Codex exposes this repository as a skill through
`.codex-plugin/plugin.json`, so use the same command files as procedure
references instead of trying to invoke Claude slash commands.

## Phase Procedures

When a Feature Flow instruction references `/feature-flow:ff-*`, treat that as a
phase name:

| Feature Flow reference | Codex action |
| --- | --- |
| `/feature-flow:ff` | Read `commands/ff.md` and run that entry procedure inline |
| `/feature-flow:ff-explore` | Read `commands/ff-explore.md` and run that phase inline |
| `/feature-flow:ff-clarify` | Read `commands/ff-clarify.md` and run that phase inline |
| `/feature-flow:ff-design` | Read `commands/ff-design.md` and run that phase inline |
| `/feature-flow:ff-plan` | Read `commands/ff-plan.md` and run that phase inline |
| `/feature-flow:ff-diagnose` | Read `commands/ff-diagnose.md` and run that phase inline |
| `/feature-flow:ff-implement` | Read `commands/ff-implement.md` and run that phase inline |
| `/feature-flow:ff-review` | Read `commands/ff-review.md` and run that phase inline |
| `/feature-flow:ff-verify` | Read `commands/ff-verify.md` and run that phase inline |
| `/feature-flow:ff-deliver` | Read `commands/ff-deliver.md` and run that phase inline |
| `/feature-flow:ff-status` | Read `commands/ff-status.md` and run that phase inline |
| `/feature-flow:ff-resume` | Read `commands/ff-resume.md` and run that phase inline |
| `/feature-flow:ff-list` | Read `commands/ff-list.md` and run that phase inline |
| `/feature-flow:ff-abandon` | Read `commands/ff-abandon.md` and run that phase inline |
| `/feature-flow:ff-close` | Read `commands/ff-close.md` and run that phase inline |

Do not expose `commands/` as a Codex manifest field. The Codex manifest should
only point at `skills`; the command files are supporting reference documents.

## Path Mapping

Resolve `${CLAUDE_PLUGIN_ROOT}` to the plugin root, two directories above
`skills/feature-flow/SKILL.md`.

Common paths:

- `${CLAUDE_PLUGIN_ROOT}/commands/ff.md` -> `commands/ff.md`
- `${CLAUDE_PLUGIN_ROOT}/config/defaults.json` -> `config/defaults.json`
- `${CLAUDE_PLUGIN_ROOT}/docs/manifest-schema.md` -> `docs/manifest-schema.md`
- `${CLAUDE_PLUGIN_ROOT}/docs/schema/*.md` -> `docs/schema/*.md`
- `${CLAUDE_PLUGIN_ROOT}/templates/*.md` -> `templates/*.md`
- run state remains project-local under `.feature-flow/<slug>/`

## Tool Mapping

| Claude instruction | Codex equivalent |
| --- | --- |
| `Write` | Use native Codex file editing tools to create files |
| `Read` | Use native Codex file reading tools |
| `Edit` | Use native Codex file editing tools |
| `Bash` | Use native Codex shell tools |
| `AskUserQuestion` | Ask the user directly in the conversation |
| `ExitPlanMode` | Claude-only; if Codex writes are allowed, proceed. If the current mode forbids writes, stop and ask the user to switch modes. |

When `toggles.autopilot` is `"ask"`, ask the user for autopilot vs
step-by-step before writing the manifest. Do not choose the value yourself.

## Agent Mapping

When a phase asks to dispatch bundled Claude agents, use Codex multi-agent
tooling if it is available. If it is not available, perform the same role inline
while preserving boundaries:

- `ff-code-explorer`: read-only exploration
- `ff-code-architect`: read-only design analysis
- `ff-code-reviewer`: read-only review
- `ff-diagnostician`: read-only diagnosis until a confirmed fix plan exists
- `ff-test-runner`: executes verification commands and captures real output

Do not let analysis roles modify files. Verification claims must be backed by
commands that actually ran.

## Workflow Precedence

An active Feature Flow run replaces generic planning, brainstorming, TDD,
debugging, and verification workflows for that same request. Do not run a
parallel generic workflow for an active `.feature-flow/<slug>/` run.
