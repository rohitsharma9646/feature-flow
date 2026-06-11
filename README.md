# feature-flow

Composable, durable, verifying Claude Code plugin for **feature development** and **bug fixing** — two tracks, one spine, real (executed) verification.

> **Status: WIP** (v0.1.0). Being built per `docs/plans/2026-06-11-feature-flow-plugin.md`.

## Install (local dev)

```
/plugin marketplace add ~/feature-flow
/plugin install feature-flow@feature-flow-dev
```

> **Install path status (2026-06-11):** what's *verified* on disk is the `claude plugin`
> CLI path — `claude plugin marketplace add ~/feature-flow && claude plugin install
> feature-flow@feature-flow-dev` (drivable headlessly; this is what actually persisted).
> The interactive slash-command pair above is NOT yet certified: one attempt narrated
> "Installed" without persisting (the `marketplace add` step had not succeeded). Re-run both
> cleanly and confirm `/ff` resolves before canonizing the slash-command path.

## Smoke log

### Task 9 — feature track end to end (in progress, 2026-06-11)
- **On disk (necessary, not sufficient):** ✅ `known_marketplaces.json`
  (`feature-flow-dev` → directory source `/home/netzwelt/feature-flow`), `settings.json`
  `enabledPlugins["feature-flow@feature-flow-dev"]=true`, cache populated (10 cmds, 5 agents).
- **AC8 (loads clean / commands register):** ✅ VERIFIED live — after a **full Claude Code
  restart**, `/help` lists all 11 commands + the `feature-flow` skill. Two operational facts:
  - **A full process restart is required** after install — plugins load at process startup,
    so a new conversation / `/clear` / new tab in an already-running process will NOT pick up
    a freshly-installed plugin (`/ff` stays "Unknown command"). Confirmed by Anthropic's
    `plugin-dev > command-development` skill ("Command not appearing → Restart Claude Code").
  - **Commands invoke under the namespace `/feature-flow:<cmd>`** (e.g. `/feature-flow:ff`),
    not bare `/ff`. Run BOTH install steps first; a bare `/plugin install` without a succeeded
    `/plugin marketplace add` does NOT persist (Claude may narrate "Installed" anyway).
  - TODO (Task 16): audit doc/prompt references that say bare `/ff` — confirm whether the
    unqualified alias resolves, else update them to `/feature-flow:ff`.
- **⚠️ Dev-loop refresh (verified):** the install **copies** source into
  `~/.claude/plugins/cache/feature-flow-dev/feature-flow/<version>/` (NOT a symlink). After
  editing `~/feature-flow/`, refresh the cache with **uninstall + reinstall** —
  `claude plugin update` no-ops on an unchanged version (won't re-copy):
  ```
  claude plugin uninstall feature-flow@feature-flow-dev
  claude plugin install   feature-flow@feature-flow-dev
  ```
  (drivable headlessly from a shell; stays enabled at user scope). Then **always** confirm
  with `diff -rq ~/feature-flow/commands <cache>/commands` before re-smoking, and the user
  must **fully restart** their Claude session to load the refreshed cache.
- **AC1 (orchestrator scaffolds + stops):** ✅ VERIFIED (2nd smoke). `/feature-flow:ff`
  created `.feature-flow/add-greeting-flag/manifest.json` (`track: feature`, `tier: full`,
  `signOff.signed: false`, `currentPhase: explore`), wrote `explore.md` with real codebase
  analysis, marked only explore complete, and **stopped** — no writes to `~/.claude/plans/`,
  repo untouched.
  - **TRUE root cause of the 1st-smoke failure: PLAN MODE was active.** Plan mode forbids
    all writes except the plan file in `~/.claude/plans/` and "supersedes any other
    instructions" — so the manifest/`explore.md` writes were *impossible*, and the only
    writable file was the one feature-flow forbids. (My initial "writing-plans workflow
    hijack" diagnosis was wrong; the artifact on disk was a plan-mode plan file.)
  - **The fix still mattered:** before it, the model silently produced a plan; after, the
    precedence block made it **conflict-aware** — it detected the plan-mode↔feature-flow
    incompatibility, asked, then recovered via `ExitPlanMode` and ran the real phase.
  - **Fix shipped:** (1) **precedence block** on every command (feature-flow phases REPLACE
    generic brainstorming/writing-plans; no writes to `~/.claude/plans`/`docs/plans`);
    (2) `ff.md` rewritten **phase-by-phase** (setup + explore + hard STOP, no chaining —
    user-chosen, revises the signed-off "chain end-to-end" behavior); (3) imperative Write
    + explicit STOP at each boundary; (4) `ff-resume` no longer chains.
  - **TODO (real follow-up):** feature-flow should handle plan mode explicitly (auto
    `ExitPlanMode` in `/ff`, or an edge-case note "don't run in plan mode"). Hit immediately
    in practice → worth a spec edge case + Task 16 hardening.
- **AC2 (standalone commands r/w manifest):** ✅ VERIFIED. `ff-clarify`, `ff-design`,
  `ff-plan`, and `ff-implement` each ran standalone, read the manifest + upstream artifacts
  on their own, updated state, and stopped — phase-by-phase continuity works.
- **AC3 (ff-test-runner really executes):** _pending (ff-verify step)._
- **🔧 Finding — advisor injected into every subagent (fixed in feature-flow):** during
  `ff-review`, the dispatched `ff-code-reviewer` agents each called the harness-native
  `advisor` tool (configured only by `settings.json > advisorModel`; injected into ALL
  subagents of ALL plugins regardless of their `tools:` grant — there is no config toggle
  to exclude subagents). Multiplies cost/latency across a parallel fleet. **Fix:** each of
  feature-flow's 5 agents now opens with a *leaf-subagent* directive (return findings
  directly; do not call `advisor`, spawn subagents, or invoke skills). Portable (harmless
  where advisor doesn't exist). The proper *global* fix would be a harness `<SUBAGENT-STOP>`
  guard on the advisor guidance — not config-fixable today; worth an Anthropic feature
  request. Verify at the post-restart `ff-verify` (ff-test-runner should NOT call advisor).
- **AC4 (implement refuses w/o sign-off):** ✅ VERIFIED. With `signOff.signed: false`,
  `/feature-flow:ff-implement` read the manifest + spec, refused to write code (verbatim
  gate message), and made **no** manifest changes — `cli.js` unmodified, `currentPhase`
  stayed `clarify`. Gate is checked before the cold-start path, so this is a true gate hit.
- **Sign-off gate (AC1 gate):** ✅ VERIFIED. `/feature-flow:ff-clarify` wrote `spec.md`
  (binary acceptance criteria, `User signed off: no`) and STOPPED asking for sign-off;
  honored "don't sign off" by holding `clarify: in_progress` with nothing downstream.
- **AC5 (resume targets deleted phase):** _pending_
