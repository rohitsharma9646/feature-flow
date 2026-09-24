# Assumption 3 — executable plans stay authorable and briefs stay small

**Date:** 2026-09-24 · **Kind:** cli-output (measured with `hooks/lib/task.sh section … | wc -l`)

Rewrote Task 2 of `docs/feature-flow/2026-09-24-revision-binding/plan.md` (the revision lib, test-first)
in the new format, embedding the real code from commit `269d302` (`evidence/a3-task2-executable.md`).

| Variant | Task lines | Growth vs old | Brief (task + Global Constraints + paths) |
|---|---|---|---|
| Old format (prose steps) | 23 | 1× | — |
| Full code everywhere (lib 109 lines + fixture code 114 lines) | 242 | ~10.5× | ~250 lines, ~14 KB |
| Full test code + Interfaces; implementation step names the exact change | 130 | ~5.7× | ~140 lines |

Plan Task 4's pre-set bar was brief ≤ 400 lines **and** growth ≤ 5×. The brief bar holds for both
variants (far below a subagent's context); growth fails for full code (a 10-task plan ≈ 2,000–2,500
lines, i.e. `ff-plan` writing all the code during planning).

**Decision (user, 2026-09-24):** "Tests + interfaces in full" — every test step carries the complete
test code, Interfaces give exact signatures, implementation steps name the exact change and include
code only where it is short or subtle. AC1 amended in the spec; templates and `ff-plan` updated.
Assumption 3 marked validated (`n`) under that rule.
