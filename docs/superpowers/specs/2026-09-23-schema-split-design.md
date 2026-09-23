# Split `docs/manifest-schema.md` into a core + topic files — design

**Date:** 2026-09-23 · **Target release:** v0.21.0 · **Status:** approved in conversation (layout,
references, guards, scope); written spec awaiting review

## Why

Every feature-flow phase command points into `docs/manifest-schema.md` for its rules. The file is
~92 KB (~23k tokens) across 21 `## ` topics. A phase reads the whole file, but uses only 13–43 KB of it:

| Command | Bytes of schema it uses today (of 92 KB) |
|---|---|
| ff-list / ff-status | 3–5 KB |
| ff / ff-resume / ff-deliver / ff-retro | 13–21 KB |
| ff-explore / ff-review / ff-design / ff-implement | 25–31 KB |
| ff-plan / ff-verify / ff-diagnose / ff-clarify | 36–43 KB |

(Measured by which `## ` topic names each command mentions, an upper bound.) With v0.20.0's
fresh-context hint, each step-by-step phase starts in a clean context and re-reads these rules, so
the cost is paid once per phase. **Goal:** a phase reads only the core plus the topics it names,
expected **~40–60% less** schema text per phase (≈9–14k tokens), with **no change to any rule's
wording**.

## Non-goals

- No rule-text rewrites, merges, or clarifications. This is a pure move. Any wording fix goes in a
  separate change.
- No edits to historical run artifacts under `docs/feature-flow/<date>-<slug>/`, which keep their
  old references as history.
- No compatibility stub (e.g. anchors that redirect old references). The plugin ships commands and
  schema together, so old and new never mix at runtime.
- No change to Go integrity code behaviour. Only its package file list changes.

## Layout

`docs/manifest-schema.md` becomes the **core**. It keeps, verbatim and in their current order, the
topics nearly every command uses:

`## Schema` · `## Field notes` · `## Config resolution & validation` · `## Run resolution …` ·
`## Rules every command MUST follow` · `## Manifest write safety` · `## Re-run guard` ·
`## Progress strip`   (~19 KB)

plus a new `## Topic index` (after the intro, before `## Schema`): one row per topic file, with
topic, path, and a one-line purpose. The index is how `§Name` cross-references inside the rules
resolve.

Each other topic moves **verbatim** (its `## ` heading and everything to the next `## `) to its own
file under `docs/schema/`:

| File | Topic (`## ` heading, unchanged) |
|---|---|
| `evidence.md` | Evidence |
| `enforcement.md` | Enforcement (Claude Code), incl. `### Session re-anchor` |
| `disk-inference.md` | Disk inference procedure |
| `sign-off-rendering.md` | Sign-off rendering |
| `terminal-convergence.md` | Terminal convergence (which command marks a run `done`) |
| `knowledge-base.md` | Knowledge base |
| `planning-intelligence.md` | Planning intelligence |
| `assumption-records.md` | Assumption records |
| `design-tradeoffs.md` | Design trade-offs & devil's advocate |
| `discovery-fields.md` | Discovery fields |
| `autopilot.md` | Autopilot |
| `delivery.md` | Delivery |
| `retrospective.md` | Retrospective |

Each topic file starts with a two-line header, then the moved section:

```
# <Topic> — feature-flow manifest contract
> Part of the manifest contract. Core rules and the topic index: `docs/manifest-schema.md`.

## <Topic heading, unchanged>
…
```

**Byte-identity check (migration):** the concatenation of the moved sections, taken out of the new
files in their original order and joined with the core's retained sections, must equal the original
file's sections byte for byte. The only additions are the index and the per-file headers.

## References

- **Command / template / agent / SKILL.md references** are rewritten by a one-off script to point at
  the file that now holds the named topic. The bold name is kept:
  `see **Autopilot** in ${CLAUDE_PLUGIN_ROOT}/docs/manifest-schema.md` →
  `see **Autopilot** in ${CLAUDE_PLUGIN_ROOT}/docs/schema/autopilot.md`. The same applies to the
  `…/manifest-schema.md §Name` form and to un-prefixed `docs/manifest-schema.md §Name` in SKILL.md
  and templates. References to core topics keep pointing at `manifest-schema.md`.
- A reference that names a **sub-topic** (a `###` heading or a bold paragraph label, such as
  `**Decision recall**` or `**Durable artifact resolution**`) resolves to the file whose section
  contains it.
- References the script can't resolve with certainty are listed for manual handling, never guessed.
- **`§Name` cross-references inside the rule text are not rewritten** (a pure move). They resolve
  through the core's `## Topic index`.
- **Reading instruction:** SKILL.md's "The manifest is the shared state" paragraph states the rule:
  read `docs/manifest-schema.md` (core), plus only the topic files the current command names.
  Commands already name their topics, so no per-command prose changes beyond the path rewrite.
- `skills/feature-flow/references/codex-tools.md` gains the `docs/schema/` path mapping next to the
  existing `manifest-schema.md` one.

## Guards and packaging

- **Existing guards (the 15 that read the schema today): least change.** Wherever a guard reads the schema (its `SCHEMA` variable or
  a literal `docs/manifest-schema.md` path), it reads a joined file instead: the core plus
  `docs/schema/*.md` in index order, built once per guard run into a temp file. Its greps, `section`
  helpers and line-order comparisons keep working unchanged. Failure messages keep a
  human-readable label (`docs/manifest-schema.md + docs/schema/`), not the temp path. Each guard's
  dist-parity list gains the topic files it covered before.
- **New `scripts/checks/schema-layout-guard.sh`** covers what joining would hide. It is written
  first and must fail against today's single file:
  1. every topic file in the layout table exists and holds exactly its `## ` heading, and no `## `
     heading appears in more than one schema file;
  2. the core holds exactly the core topics (plus `## Topic index`);
  3. the index lists every topic file, and every listed path exists;
  4. **reference integrity:** every `**Name** in …/docs/<file>.md` and `…/docs/<file>.md §Name`
     reference in `commands/`, `templates/`, `agents/`, and `skills/` points at a file that exists
     and contains `Name`, as a `##`/`###` heading prefix or a bold paragraph label. This is new
     protection: today a reference can point at a topic that has been moved or renamed without
     anything failing;
  5. dist parity for `docs/schema/` in the Codex package.
- **Packaging:** `package-claude-plugin.sh`, `package-codex-plugin.sh`, and
  `build-integrity-packages.sh` ship `docs/schema/`. `claude-dist-guard.sh`'s "docs/ holds only …"
  assertion allows the `schema/` directory.

## Error handling / edge cases

- A heading whose text contains characters awk/grep treat specially (`&`, parentheses, backticks)
  is matched as a fixed string in the new guard (the mawk parenthesis lesson in
  `discovery-fields-guard.sh`).
- A reference split across a line break is matched on line-joined text, the same `flat` approach
  as the existing guards.
- A topic referenced by nothing still ships (the index lists it). No dead-file pruning.

## Testing / success criteria

1. `schema-layout-guard.sh` fails before the split and passes after it.
2. The byte-identity check passes: no rule text changed.
3. All 24 existing check scripts pass, except `integrity-conformance-guard.sh`, which needs Go and
   passes in CI. `scripts/eval.sh` passes.
4. The Codex and Claude packages contain `docs/schema/` with all 13 files. CI's `claude-dist-guard`
   and `dist-parity-guard` pass.
5. **Measured win:** a before/after table of schema bytes each command must read (the same
   measurement as above, now per file) goes in the CHANGELOG. Expected a 40–60% reduction for the
   heavy phases. If the measured number is far below that, report it as is.

## Risks

- **Large mechanical diff**: ~130 reference rewrites plus 15 guard edits. Mitigated by the
  byte-identity check, the reference-integrity check, and the unchanged guard assertions.
- **Model follow-through**: the win depends on the model reading only named files instead of
  opening every schema file. SKILL.md states the rule. The worst case costs what today's single
  file costs.
- **Forward-test sandboxes** run with `--plugin-dir <repo>` and pick up the new layout
  automatically. They aren't run in CI; run the local forward-test suite once before release.
