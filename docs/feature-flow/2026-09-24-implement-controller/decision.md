---
tags: [implement, controller, subagents, planning, review, ledger]
referencedFiles:
  - commands/ff-implement.md
  - docs/schema/task-controller.md
  - hooks/lib/task.sh
  - agents/ff-implementer.md
  - templates/plan.md
  - commands/ff-plan.md
---

# Decision: ff-implement runs a per-task subagent controller, with one contract topic and a shared fence-aware task lib

**Spec:** `docs/feature-flow/2026-09-24-implement-controller/spec.md`
**Created:** 2026-09-24

## Decision

On full-tier runs whose plan has `## Global Constraints`, `ff-implement` dispatches a fresh
`ff-implementer` per plan task from a brief extracted by `hooks/lib/task.sh` (fence-aware, reproduced
verbatim in `docs/schema/task-controller.md` for Codex), reviews each task's fingerprint-to-fingerprint
diff with one `ff-code-reviewer`, runs a 2-resume + 1-escalated fix loop, and records everything in
`<run dir>/tasks/ledger.md`; the contract lives in one new topic, prompts are composed inline, and no
stop it adds is "unconditional".

## Context

Implement was the last inline phase: 332–426 tool calls and ~5 compactions per session, no per-task
review, and nothing finer than `phases.implement: in_progress` to resume from (F11, backlog item 7,
Superpowers comparison #1/#2). The controller must keep every existing gate, the never-commit
doctrine, artifact-resident caps and Codex parity (no `hooks/`/`scripts/` shipped there).

## Options considered

| Option | Why considered / rejected |
|--------|----------------------------|
| Pragmatic + grafts | chosen — see Chosen + rationale below |
| Minimal (no topic/lib, hand-copied briefs, contract across two topics) | rejected: nondeterministic briefs on fenced plans, scattered contract, mislabelled stop shape |
| Pragmatic as proposed (`task-diff.sh` one-liner, hand-copied briefs) | rejected: pins the trivial part, leaves the risky part to the model |
| Clean (topic + lib + 4 pinned templates) | rejected: double guard/dist surface for wording no one else consumes |

## Trade-offs

| Option | Effort | Risk | Reversibility |
|--------|--------|------|----------------|
| Pragmatic + grafts | med | low | easy to undo (presence-gated on `## Global Constraints`; older plans run inline) |
| Pragmatic as proposed | med | med | easy to undo |
| Minimal | low | med | easy to undo |
| Clean | high | low | easy to undo, but four templates to retire |

## Chosen + rationale

Pragmatic + grafts: one discoverable contract topic referenced by name (house style); dispatch
prompts inline like every other dispatch site; the reviewer reused unchanged; and determinism only
where it pays — section extraction and diff packaging — via one functions-only lib reproduced
byte-for-byte for Codex (the settled KB convention from revision binding). Fingerprints reuse the
unchanged `hooks/lib/revision.sh`, so Gate B and its byte guard are untouched. Caps and rulings live in
the ledger (no manifest/config counter); the three new stops are passive or capped-then-stop, per the
three-shapes convention. The failure scenarios this choice must survive are in `design.md`
§Devil's advocate (FS1–FS4).

Reopen if Codex gains subagents with a different dispatch model, if WP4's kernel takes over
revision/diff computation, or if a later run unifies the three capped cycles (recommendation #5) —
the per-task fix loop is written in the same shape language so it can be folded in.

**Related ACs:** AC1–AC20
**Related files:** commands/ff-implement.md, docs/schema/task-controller.md, hooks/lib/task.sh, agents/ff-implementer.md, templates/plan.md, commands/ff-plan.md

## Outcome

Pending implementation.

## Future considerations

- A PreToolUse deny for git index/history mutations by subagents (today prose-enforced).
- Model per task chosen from the plan (recommendation #6) — the ledger already records the model per
  dispatch.
- Unifying review fix / verify repair / stale re-run / per-task fix into one escalating budget (#5).
- Transcript/cost analysis over `tasks/` in `ff-retro` (#9).
- If Assumption 2 fails (no live resume), rounds 1–2 stay as fresh dispatches with the report as memory.
