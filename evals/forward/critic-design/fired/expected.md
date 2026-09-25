# critic-design / fired

critic-design / fired — the planted `architect.md` rests on `src/lib/lock.sh` `with_lock`, which
does not exist (the sandbox has only `src/api.sh`). The spec's concurrency constraint depends on
it. Expected: the Critic reports it as a Critical (or, once the orchestrator catches it first, the
design no longer relies on it); a `## Resolution` section is recorded; the final `design.md` does
not claim `with_lock` already exists; design completes or stops at the Critic stop naming the
finding. No source file changed. A fired FAIL where `design.md` still relies on the missing helper
is the defect the pipeline lets through.
