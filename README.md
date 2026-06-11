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
- **⚠️ Dev-loop gotcha:** the install **copies** source into
  `~/.claude/plugins/cache/feature-flow-dev/feature-flow/<version>/` (NOT a symlink). Editing
  `~/feature-flow/` does not affect a running session until the cache is refreshed
  (`/plugin marketplace update feature-flow-dev` + `/reload-plugins`, or reinstall). Always
  re-verify the cached copy after a fix before re-smoking, or you'll test stale prompts.
- **AC1 (orchestrator scaffolds + gates):** ❌→🔧 First smoke FAILED: `/feature-flow:ff`
  produced no `.feature-flow/` sandbox, no manifest, no `spec.md`, and skipped the sign-off
  gate. Root cause (confirmed via artifact on disk): the session's **global
  CLAUDE.md/superpowers `writing-plans` workflow hijacked** the command — output landed in
  `~/.claude/plans/add-a-greeting-flag-*.md`, not the sandbox. feature-flow's soft
  *descriptive* gate prose lost to standing instructions that *command* a different flow.
  **Fix applied (pending re-smoke):** (1) every command now opens with a **precedence
  block** asserting feature-flow phases REPLACE generic brainstorming/writing-plans and
  forbidding writes to `~/.claude/plans`/`docs/plans`; (2) orchestrator `ff.md` rewritten
  **phase-by-phase** — setup + explore + hard STOP, no chaining (user-chosen design,
  revises the signed-off "chain end-to-end" behavior); (3) imperative "use the Write tool"
  for every artifact + explicit STOP at each phase boundary; (4) `ff-resume` no longer
  "continues the chain."
- **AC2 (standalone commands r/w manifest):** _pending_
- **AC3 (ff-test-runner really executes):** _pending_
- **AC4 (implement refuses w/o sign-off):** _pending_
- **AC5 (resume targets deleted phase):** _pending_
