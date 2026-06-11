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
> cleanly and confirm `/feature-flow:ff` resolves before canonizing the slash-command path.

## Smoke log

### Task 9 — feature track end to end (✅ COMPLETE, 2026-06-11)
- **On disk (necessary, not sufficient):** ✅ `known_marketplaces.json`
  (`feature-flow-dev` → directory source `/home/netzwelt/feature-flow`), `settings.json`
  `enabledPlugins["feature-flow@feature-flow-dev"]=true`, cache populated (10 cmds, 5 agents).
- **AC8 (loads clean / commands register):** ✅ VERIFIED live — after a **full Claude Code
  restart**, `/help` lists all 11 commands + the `feature-flow` skill. Two operational facts:
  - **A full process restart is required** after install — plugins load at process startup,
    so a new conversation / `/clear` / new tab in an already-running process will NOT pick up
    a freshly-installed plugin (`/feature-flow:ff` stays "Unknown command"). Confirmed by Anthropic's
    `plugin-dev > command-development` skill ("Command not appearing → Restart Claude Code").
  - **Commands invoke under the namespace `/feature-flow:<cmd>`** (e.g. `/feature-flow:ff`),
    not bare `/feature-flow:ff`. Run BOTH install steps first; a bare `/plugin install` without a succeeded
    `/plugin marketplace add` does NOT persist (Claude may narrate "Installed" anyway).
  - TODO (Task 16): audit doc/prompt references that say bare `/feature-flow:ff` — confirm whether the
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
    `ExitPlanMode` in `/feature-flow:ff`, or an edge-case note "don't run in plan mode"). Hit immediately
    in practice → worth a spec edge case + Task 16 hardening.
- **AC2 (standalone commands r/w manifest):** ✅ VERIFIED. `ff-clarify`, `ff-design`,
  `ff-plan`, and `ff-implement` each ran standalone, read the manifest + upstream artifacts
  on their own, updated state, and stopped — phase-by-phase continuity works.
- **AC3 (ff-test-runner really executes):** ✅ VERIFIED. `ff-verify` dispatched
  `ff-test-runner`, which **executed** `npm test` (`node --test`) — real output `tests 6 /
  pass 6 / fail 0`, exit 0 — and `verify.md` maps **each** AC1–AC7 → `pass` with per-test
  evidence (name + `cli.test.js` line). build/lint `n/a` with reasons; explicit "not a
  no-tests run." Verdict DONE, nothing `manual-unverified`. Matches an independent
  `node --test` (6/6). **Feature spine verified end-to-end.**
- **🔩 Task 16 hardening backlog (found during smoke):**
  - **Plan mode:** `/feature-flow:ff` should auto-`ExitPlanMode` or document "don't run in plan mode."
  - **Run resolution:** phase commands (`ff-verify`, `ff-design`, `ff-plan`, `ff-implement`,
    `ff-review`) say only "resolve the manifest" — standardize on `ff-resume`/`ff-status`'s
    rule (named slug → most-recently-updated → ask if ambiguous). Fine with one run; ambiguous
    with several. (Commands already accept a slug arg as the escape hatch.)
  - **Slash namespace:** audit any doc/prompt references to bare `/feature-flow:ff*` → `/feature-flow:ff*`.
  - **Clarify ordering:** reconcile whether sign-off gates `ff-design` or only `ff-implement`
    (SKILL says implement-only; clarify's hand-off implies before design).
- **🔧 Finding — advisor injected into every subagent (fixed in feature-flow):** during
  `ff-review`, the dispatched `ff-code-reviewer` agents each called the harness-native
  `advisor` tool (configured only by `settings.json > advisorModel`; injected into ALL
  subagents of ALL plugins regardless of their `tools:` grant — there is no config toggle
  to exclude subagents). Multiplies cost/latency across a parallel fleet. **Fix:** each of
  feature-flow's 5 agents now opens with a *leaf-subagent* directive (return findings
  directly; do not call `advisor`, spawn subagents, or invoke skills). Portable (harmless
  where advisor doesn't exist). The proper *global* fix would be a harness `<SUBAGENT-STOP>`
  guard on the advisor guidance — not config-fixable today; worth an Anthropic feature
  request. **✅ Fix VERIFIED post-restart:** the 3 `ff-code-reviewer` agents re-dispatched by
  the AC5 resume invoked only read-only discovery tools (Glob/Grep/Read) — **0** `advisor`
  `tool_use` calls across all three subagent transcripts (the word "advisor" survives only as
  the injected guidance + our own suppression directive).
- **AC4 (implement refuses w/o sign-off):** ✅ VERIFIED. With `signOff.signed: false`,
  `/feature-flow:ff-implement` read the manifest + spec, refused to write code (verbatim
  gate message), and made **no** manifest changes — `cli.js` unmodified, `currentPhase`
  stayed `clarify`. Gate is checked before the cold-start path, so this is a true gate hit.
- **Sign-off gate (AC1 gate):** ✅ VERIFIED. `/feature-flow:ff-clarify` wrote `spec.md`
  (binary acceptance criteria, `User signed off: no`) and STOPPED asking for sign-off;
  honored "don't sign off" by holding `clarify: in_progress` with nothing downstream.
### Task 13 — bugfix track end to end (✅ COMPLETE, 2026-06-11)
- **Smoked GREEN** against `/tmp/ff-sample` (planted bug `cli hi`→`hihi`, `cli.js:11`):
  - **AC10** ✅ `/feature-flow:ff` classified bugfix → `manifest.track:bugfix`, `diagnosis.md`, **no** `design.md`.
  - **AC11** ✅ test-first: `ff-implement` wrote the regression test first, captured RED
    (`bugfix.red` exit 1, `'hihi' !== 'hi'`, 6/7) then GREEN (`bugfix.green` exit 0, 7/7);
    `verify.md` maps RED→GREEN with real `node --test` output.
  - **AC12** ✅ `diagnosis.md` named hotfix + proper + recommendation.
  - **AC13-lite** ✅ tier `lite`, no separate sign-off; implement proceeded from the confirmed diagnosis.
  - **advisor** ✅ 6 bugfix subagents, **0** advisor `tool_use`.
- **🔩 Hardening encoded post-smoke (`7dcd082`):** the run executed **review→verify** (the
  user's order), and `ff-verify` had to override its literal "never set `done` on bugfix"
  rule because review was already complete. Now encoded: on bugfix, `ff-verify` sets `done`
  if review is already complete, else hands off to review — mirrors `ff-review`. Both phases
  converge on `done` in either order (consistent with AC2 standalone-command design). The
  smoke itself proved order-independence.

### Task 13 — staging notes (build + pre-smoke)
- **Tasks 10–12 built:** `ff-diagnose` + `diagnosis.md` (hotfix-vs-proper, tiering);
  test-first bugfix mode in `ff-implement`/`ff-verify` (AC11 RED→GREEN via
  `manifest.bugfix.red/green`); track classification + routing in `/feature-flow:ff` (feature vs bugfix,
  ask-once, split-if-both).
- **🔧 Pre-smoke advisor review caught a coherence bug (fixed `5c11d68`):** the bugfix track
  is spec'd `diagnose→implement→verify→**review**` (review terminal), but the phase handoffs
  executed `review→verify` (`ff-implement` routed to review-then-verify; `ff-verify` set the
  run `done`) — contradicting the spec, schema, and `ff-resume`. Per a user decision
  (conform to the signed-off spec), `ff-implement`/`ff-verify`/`ff-review` are now
  **track-aware** (bugfix ends verify→review, review sets `done`), and `ff-plan` is now
  **bugfix-aware** (reads `diagnosis.md` for full-tier bugs; routes lite bugs straight to
  implement). Grep/`plugin validate` could not have caught this — only cross-file reasoning.
- **Smoke pending:** needs a fresh session. Sample repo pre-staged with a planted bug
  (`cli <word>` echoes twice; `cli.js:11`) that the 6/6-green suite does NOT cover — forcing
  the flow to write a real regression test (AC11). Handoff:
  `~/.claude/handoffs/2026-06-11T09-16-12Z-feature-flow-task13-bugfix-smoke.md`.

### Task 9 (feature track) — detail

- **AC5 (resume targets exactly the missing phase):** ✅ VERIFIED. Set-up: `review.md`
  deleted on disk while the manifest still recorded `review: complete` **and**
  `currentPhase: done`. After a full restart, `/feature-flow:ff-resume` detected the
  **missing artifact** (not just trusting manifest status), re-entered at **review
  specifically** — overriding the `done` currentPhase — re-dispatched the 3 `ff-code-reviewer`
  agents, rewrote `review.md` (correctly dismissing two ≥-threshold convention nits against
  the design record), and **stopped** (did not chain into verify/done). Resume keys off
  artifact presence, exactly the intended semantic.
- **✅ Feature track smoked GREEN end-to-end** (AC1, AC2, AC3, AC4, AC5, AC8, sign-off gate)
  — Task 9 feature-track complete (2026-06-11).
