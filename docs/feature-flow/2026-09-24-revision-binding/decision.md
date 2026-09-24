---
tags: [revision, assurance, enforcement, gate, verification, review]
referencedFiles:
  - hooks/lib/revision.sh
  - hooks/enforce-gate
  - docs/schema/enforcement.md
  - docs/schema/autopilot.md
  - commands/ff-review.md
  - commands/ff-verify.md
---

# Decision: Revision binding via one shared bash library with a byte-identical canonical recipe

**Spec:** `docs/feature-flow/2026-09-24-revision-binding/spec.md`
**Created:** 2026-09-24

## Decision

Review and verify stamp a working-tree fingerprint computed by `hooks/lib/revision.sh` (whose text
is reproduced byte-for-byte as the canonical recipe in `docs/schema/enforcement.md` §Revision
fingerprint); Gate B denies `done` on a revision-bound run unless each stamp equals the freshly
computed current fingerprint; a stale phase is re-run at most once, capped by a durable
`## Stale re-run` section in that phase's artifact.

## Context

F01 (Critical): a run could reach `done` on code that was not both reviewed and verified, because
repair / fix cycles and hand edits change code after the other assurance phase ran, and Feature Flow
never commits, so HEAD cannot tell. The hook (Claude Code) and the prose (Codex) must compute the
same value, but Codex ships no `hooks/` or `scripts/`, and CI forbids calling the Go kernel.

## Options considered

| Option | Why considered / rejected |
|--------|----------------------------|
| Pragmatic + grafts | chosen — see Chosen + rationale below |
| Minimal (hand-mirrored recipe, prose-only cap) | smallest diff; rejected for high drift risk and a cap that does not survive a dropped session |
| Clean (new topic + 3 byte-identical copies) | strongest structure; rejected as more obligations for the same guarantee |
| Pragmatic as proposed (fragment grep) | weaker drift protection, redundant fourth comparison |

## Trade-offs

| Option | Effort | Risk | Reversibility |
|--------|--------|------|----------------|
| Pragmatic + grafts | med | low | easy to undo (additive fields; `revisionBound` absent = old behaviour) |
| Minimal | low | med | easy to undo |
| Clean | high | low | easy to undo, but a topic file to retire |
| Pragmatic as proposed | med | med | easy to undo |

## Chosen + rationale

Pragmatic + grafts: one executable library shared by the hook, the tests and (on Claude Code) the
commands, with its full text as the canonical recipe for Codex, guarded for byte identity; the
simplified Gate B compares each stamp to the current tree. It follows house conventions (durable
cycle markers like `## Resolution` / `## Repair`, one structural guard per feature, contract text
referenced not restated) and respects the prior KB decision "Revision-derived assurance validity":
validity is derived from stamp == current, never from an invalidation flag — the `## Stale re-run`
section caps a cycle, it does not decide validity. The failure scenarios this choice must survive are
in `design.md` §Devil's advocate (FS1–FS4).

Reopen if WP4 merges (the kernel's `CodeRevision v1` / `Converge()` could supersede the bash
library), or if a second revision provider (non-git VCS) is needed.

**Related ACs:** AC1–AC15
**Related files:** hooks/lib/revision.sh, hooks/enforce-gate, docs/schema/enforcement.md, docs/schema/autopilot.md, commands/ff-review.md, commands/ff-verify.md

## Outcome

Held through implement, review and verify (2026-09-24): no divergence. Review added one refinement inside the decision — the `.git` walk-up now terminates on any path — and one prose dedup; neither changes the approach.

## Future considerations

- WP4 must preserve this behaviour or supersede it in kernel enforce mode — never observe-only.
- Per-evidence-record revision stamps, and gating `Bash`-tool manifest writes, were deferred (spec
  non-goals).
- If Assumption 3 fails in practice (untracked build outputs), consider narrowing the fingerprint to
  "tracked + untracked files present at review time".
