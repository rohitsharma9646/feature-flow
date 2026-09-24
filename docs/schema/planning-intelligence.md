# Planning intelligence — feature-flow manifest contract
> Part of the manifest contract. Core rules and the topic index: `docs/manifest-schema.md`.

## Planning intelligence

`ff-plan` derives four sections into every `plan.md` (feature) / `plan-bugfix.md` (bugfix-full),
between `## Tasks` and `## Status conventions`: **Dependency graph**, **Critical path**, **Risk
register**, **Rollback plan**. This is the single canonical contract; `ff-plan`, `ff-implement`,
and `ff-verify` reference this section by name and never restate its rules inline — same house
style as §Evidence and §Knowledge base → Decision recall. The **Critical path** is the only one
that hard-gates a later phase; the other three are inputs to consumers that already exist.
**Always-on:** no `toggles.*` key gates any of this, and no new `manifest.json` top-level field —
every section lives inside the plan, located solely via `manifest.artifacts.plan` (the sole
locating authority, per **Durable artifact resolution**). This closes the v2 Actuation line: a
planning section a human reads but no phase acts on is a documentation cost, not a capability —
the same trap **Decision recall** exists to close.

### Dependency graph notation

One row per task: `| Task | Depends on |` — `Depends on` names a prior `Task N` or "— (root)".
Expressed purely in the `Task N` IDs already defined under `## Tasks` — never a phantom task.

**Structural invariant (this is what makes the derivation below deterministic and
hand-computable): a task's `Depends on` list may name only STRICTLY LOWER-numbered tasks.** The
plan's task numbering is therefore always already a valid topological order of the graph — a cycle
is unexpressible, and no topological sort is ever needed. `ff-plan` enforces the lower-numbered
rule when it writes the graph. Multiple roots are normal and are **not** an instruction to run
tasks concurrently — this is dependency *data*, not a scheduling directive.

### Critical-path derivation

`ff-plan` computes the critical path **after** writing the Dependency graph, **from** it — never
as an independent judgment call. Given tasks `1..N` (already topological, by the invariant above)
and each task's `Depends on` set:

1. For `i = 1..N` in increasing order, `depth(i)` = `0` if `Task i` is a root, else
   `1 + max(depth(j) for j in Depends-on(i))`; `chainLength(i) = depth(i) + 1`.
2. **Sink** = the task with the greatest `chainLength`. Deterministic tie-break, in order:
   (a) most `Step` items, then (b) lowest task number.
3. Walk backward from the sink: at each task, move to the dependency with the greatest
   `chainLength` (same tie-break) until a root is reached; reverse the walk.

Rendered `**Path:** Task a → … → Task sink`. Degenerate cases, stated literally (never invent an
edge to force a chain): **no edges at all** → "no gating chain — all tasks independent" (every
`chainLength` is 1; the tie-break names the single longest task); **fully linear** → the whole
task sequence. Because the path is derived, an edit that changes the graph invalidates a stale
path — re-derive, don't hand-patch.

### Critical-path check (ff-implement)

The **sole hard actuator**. `ff-implement` resolves the plan via `manifest.artifacts.plan` (full
tier only — feature full, or an escalated full-tier bugfix; lite tiers have no plan and skip it),
reads the `## Critical path`, and, before executing a task, compares the approach it is about to
take against that path exactly as **Decision recall**'s do-not-contradict STOP compares an
approach against a recalled decision — same shape, same unconditional-in-both-modes rule, reused
rather than reinvented. **Trigger:** the approach skips a task the critical path names, or executes
critical-path tasks out of the stated order. On trigger, **STOP unconditionally in both modes** —
autopilot does not auto-resolve or retry. Resolve **only** by realigning the work to the critical
path, or by the user replying with an explicit override recorded verbatim as
`Critical-path override by user (<date>): <reason>` in the plan's `## Critical path` section (the
plan, not the decision record — the critical path lives in the plan) — never self-authored. No
divergence, or no
critical path recorded (a pre-WS-2 plan) → one-line note, proceed. See the **Critical-path stop**
row in §Autopilot.

### Risk register (feeds ff-verify)

One row per identified risk: `| Risk | Likelihood | Impact | Mitigation |`, categorical
(`Low | Medium | High`) — **no numeric scores** (same doctrine as §Evidence's confidence ladder).
`ff-verify` reads it via `manifest.artifacts.plan` (full tier) and cross-references it into the
existing `verify.md` §Regression risk rather than deriving risk cold from the diff — any risk the
register named, and whether it materialized, folds into the verdict. A risk accepted without
mitigation is recorded as such (mirrors the Evidence waiver's "state it, don't hide it").

### Rollback plan (recovery on a failed Verify step)

Not an actuator — a **prescribed recovery**. One row per task that risks a half-applied state,
naming the concrete recovery action `ff-implement` takes when that task's `Step N: Verify` fails,
so a failure never leaves the tree silently half-applied. An **irreversible** step states so
explicitly and names a mitigation instead of a fake undo. No plan (lite tier) → recover ad hoc and
note it under the manifest's Blockers.

### v1 non-goals (honest deferral)

No automatic scheduling or parallel execution of independent (root) tasks — the dependency graph
is data, not a scheduling instruction. No numeric risk/priority scoring. No cross-run KB recall of
past risk registers or rollback plans. No machine/CI verification of the critical-path STOP
actually firing — a fresh-session self-run, exactly like the Decision-recall STOP's behavioral AC.

