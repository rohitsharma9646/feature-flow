# critic-plan / fired

critic-plan / fired — the plan consumes `with_lock` from a `src/lib/lock.sh` that does not exist.
Expected: a Critical naming it and a `## Resolution`. The final `plan.md` either creates the
helper in a task (`Produces:` `with_lock`) or no longer consumes it — **or** the run stops routing
to `/feature-flow:ff-design` (a design-level fix, §Critic Screen). No source file changed.
