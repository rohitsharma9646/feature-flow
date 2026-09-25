# single-architect / fired

Full tier, `autopilot: false`, explore + clarify already complete, `design` not yet started.
`ff-design` dispatches **exactly one** `ff-code-architect` (`docs/schema/design-tradeoffs.md` /
v0.24.0 single-architect spec) against the `rate-limit` spec, whose acceptance criteria force a
persistence choice (`src/api.sh` is a fresh process per request, so a per-caller counter must
survive across invocations) — a genuine fork between an in-memory counter (dies with the process),
a lock-file counter, and a token-bucket file.

Expected: `architect.md` is written (`manifest.artifacts.architect`) with a `Recommended:` line and
at least one `Rejected:` line, each rejected line carrying `complexity:`, `risk:` and
`test effort:` scores; no `one obvious approach —` line; no source file changed (the architect is
read-only, and `ff-design` pauses for the user's choice before writing `design.md`/`decision.md`).
