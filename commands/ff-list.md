---
description: "List all feature-flow runs: slug, track, tier, currentPhase, createdAt, updatedAt — including abandoned and closed runs."
argument-hint: "(no arguments)"
---

# /feature-flow:ff-list — list runs

Read-only visibility tool. Unlike automatic run resolution (which excludes abandoned and
closed runs — see **Run resolution** in `${CLAUDE_PLUGIN_ROOT}/docs/manifest-schema.md`),
this command shows **every** run, by design.

## Do the work

1. Resolve `paths.base` from config (`.feature-flow.json` →
   `${CLAUDE_PLUGIN_ROOT}/config/defaults.json`, default `.feature-flow`).
2. Enumerate every run directory under `<base>/` and read each `manifest.json`.
3. **Zero runs:** print exactly — "No feature-flow runs found under `<base>/`." — and stop.
4. Otherwise print one row per run, most recently updated first:

   | slug | track | tier | currentPhase | createdAt | updatedAt |

   Mark runs with `currentPhase: "abandoned"` as `[abandoned]` and runs with a non-null
   `closedAt` as `[closed]` in the currentPhase column. A run whose manifest is missing or
   unparsable is still listed, with `currentPhase` shown as `[manifest missing/corrupt]`.
5. Do not modify anything — list is read-only.
