# architect-pick / fired

Turn 1 runs `ff-design` on the `rate-limit` spec (several viable approaches) and stops at the choice
pause with `architect.md` on disk. Turn 2 (`followup.txt`) picks the first alternative offered (the first `Rejected:` line — never a `Dropped` one).

Expected: the architect is re-dispatched once — `architect.md` gains exactly one
`## Developed on request: <name>` section, the first report kept above it — and `design.md` is derived
from the picked approach: its `## Chosen approach` names the picked approach, and the architect's
original recommendation moves to `## Rejected alternatives`. No source file changed.
