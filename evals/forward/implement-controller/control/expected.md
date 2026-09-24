# implement-controller / control

Identical sandbox, except the plan has **no** `## Global Constraints` section — a plan written before
v0.23.0. `ff-implement` must implement **inline**, as before, and say so.

Expected: implement complete; no `artifacts.ledger`, no `.feature-flow/text-tools/tasks/`
directory; `bash tests/test.sh` exits 0; the final message carries the `Implement path: inline — <reason>` line; no commit made.
Its `run.json` is SM1's denominator (`sm1-ratio.sh`).
