# Enforcement (Claude Code) — feature-flow manifest contract
> Part of the manifest contract. Core rules and the topic index: `docs/manifest-schema.md`.

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

