# Design: Bind review and verify to the same code revision

**Spec:** `docs/feature-flow/2026-09-24-revision-binding/spec.md`
**Created:** 2026-09-24

## Chosen approach

**Pragmatic, with two grafts from the clean option** (user choice, 2026-09-24).

1. **One shared library, one canonical text.** `hooks/lib/revision.sh` holds the whole mechanism:
   `revision_excludes` (resolve `paths.base` / `paths.durable` / `paths.kb` from the project's
   `.feature-flow.json`, falling back to built-in defaults equal to `config/defaults.json`, and
   relativize them to the git top level), `revision_fingerprint` (the explore prototype: copy the
   real index to a throwaway `GIT_INDEX_FILE`; `git add -u`; add untracked non-ignored entries from
   `ls-files --others --exclude-standard --directory`, skipping nested repositories; `git rm -r
   --cached --ignore-unmatch` each exclude; `git write-tree`), and `revision_changed_paths` (capped
   `git diff-tree --name-only -r` between two tree ids, "+N more", or "changed paths unavailable"
   when an object is missing). Sourced, it only defines functions; executed as
   `bash revision.sh <project-dir>` it prints the current fingerprint (exit 0) or nothing (non-zero).
   The fingerprint always covers the **whole git top level**, whatever subdirectory the session runs in.
2. **Canonical recipe = byte-identical copy.** `docs/schema/enforcement.md` gains `### Revision
   fingerprint`, whose fenced ```bash block is the lib file verbatim. **Graft 1:** the new guard
   extracts that block and requires it to be byte-identical to `hooks/lib/revision.sh` (not a
   fragment grep). Claude Code commands run the shipped lib file
   (`bash "${CLAUDE_PLUGIN_ROOT}/hooks/lib/revision.sh" "$PWD"`); Codex, which ships `docs/schema/`
   but no `hooks/`, runs the same text via `bash -s -- "$PWD" <<'EOF' … EOF`. One algorithm, two
   byte-identical carriers, zero hand-paraphrase.
3. **Manifest.** Top-level `revisionBound: true`, written once at manifest creation by `ff`,
   `ff-explore`, `ff-clarify` and `ff-diagnose` (same posture as `autopilot`; absent = pre-0.22 run,
   behaves as 0.21.0). Per phase: `phases.review.revision` / `phases.verify.revision` = the tree id,
   or `null` when not a git repository / not computable.
4. **Stamping.** `ff-review` and `ff-verify` gain a `## Stamp the revision` step immediately before
   their manifest update — i.e. after any in-phase fix / repair cycle — recording the value in both
   the manifest and the artifact's `**Revision:**` header line. It never blocks the phase.
5. **Gate B (hook), graft 2 — each stamp against the current tree.** Only when a write proposes
   `currentPhase: "done"`, only after the existing Gate B checks pass, only when `revisionBound` is
   `true`: locate a `.git` by walking up from `cwd`. None → skip silently (AC8). Found but `git`
   missing or the fingerprint fails → allow + `systemMessage` warning (AC9). Otherwise compute
   `current` once; for review then verify: stamp missing → deny naming the phase; stamp ≠ `current`
   → deny naming the stale phase and `revision_changed_paths(stamp, current)`. (If both stamps equal
   `current` they equal each other, so "the two differ" needs no separate branch.)
6. **Convergence (commands, both platforms).** At each done-transition the terminal command compares
   the other phase's stamp to the value it just stamped. Mismatch → the new **Stale-phase re-run
   cycle** in `docs/schema/autopilot.md`: autopilot, and no `## Stale re-run` section already in the
   stale phase's artifact → re-run that phase's full `Do the work` once (review: focus +
   spec-conformance reviewers), append `## Stale re-run` (old / new revision, changed paths, outcome)
   to that phase's artifact, re-stamp, re-check. Still stale, a prior section exists, or step-by-step
   → STOP naming the phase to re-run. The durable section caps the cycle across dropped sessions,
   exactly like `## Resolution` / `## Repair`.

## Rejected alternatives

| Alternative | Why rejected |
|-------------|--------------|
| Minimal — prose recipe in `terminal-convergence.md`, hand-mirrored in the hook, `--revision` argv dev branch, prose-only "once per attempt" cap | Two hand-kept copies with only a marker check (high drift risk); a test-only code path in the production hook; the re-run cap does not survive a dropped session |
| Clean — new `docs/schema/revision-binding.md` topic + `scripts/checks/lib` copy + hook copy, 3-way byte identity | Most structure (new topic → Topic index + `SCHEMA_LAYOUT` + L1–L4 obligations, three copies) for the same guarantee the chosen option gets with two copies; its best ideas (byte identity, per-stamp-vs-current Gate B) were grafted in |
| Pragmatic as proposed — fragment-grep drift check, four-comparison Gate B | A fragment grep can miss a changed line between the canonical text and the lib; the fourth comparison is logically subsumed |

## Trade-off matrix

| Option | Complexity | Risk / operational impact | Test effort | Recipe drift risk |
|--------|------------|----------------------------|--------------|-------------------|
| **Pragmatic + grafts (chosen)** | med | low | med | low |
| Minimal | low | med | low | high |
| Clean | high | low | high | low |
| Pragmatic as proposed | med | med | med | med |

## Component map

| File / module | Responsibility | New or modified |
|---------------|----------------|-----------------|
| `hooks/lib/revision.sh` | `revision_excludes`, `revision_fingerprint`, `revision_changed_paths`; CLI mode prints the fingerprint | new |
| `hooks/enforce-gate` | Gate B revision block (done + revisionBound only), loud-warn path | modified |
| `docs/schema/enforcement.md` | Gate B revision condition; `### Revision fingerprint` (verbatim lib); fail-open cases; WP4 constraint | modified |
| `docs/manifest-schema.md` | Schema block + Field notes for `revisionBound`, `phases.<review\|verify>.revision` | modified |
| `docs/schema/terminal-convergence.md` | `done` requires both stamps equal to the current revision on revision-bound runs | modified |
| `docs/schema/autopilot.md` | Mandatory-pauses row + **Stale-phase re-run cycle** | modified |
| `commands/ff-review.md`, `commands/ff-verify.md` | `## Stamp the revision`; stale check at each done-transition | modified |
| `commands/ff.md`, `ff-explore.md`, `ff-clarify.md`, `ff-diagnose.md` | `revisionBound: true` at manifest creation | modified |
| `templates/review.md`, `templates/verify.md` | digit-free `**Revision:**` header line | modified |
| `scripts/checks/enforce-gate-guard.sh` | real-git-repo fixtures for AC3–AC9 (+FS1, FS3, FS4); PATH-shim update | modified |
| `scripts/checks/revision-binding-guard.sh` | structural wiring + byte identity (doc block ≡ lib) + built-in defaults ≡ `config/defaults.json` | new |
| `.claude-plugin/*`, `.codex-plugin/plugin.json`, `README.md`, `CHANGELOG.md`, `dist/codex/**` | 0.22.0 + repackage | modified |

## Data flow

1. Run creation writes `revisionBound: true`.
2. `ff-review` finishes its work (incl. any fix cycle) → runs the lib (Claude) / canonical block
   (Codex) in the project dir → `phases.review.revision` + `review.md` `**Revision:**`.
3. `ff-verify` finishes (incl. any repair cycle) → same → `phases.verify.revision` + `verify.md`.
4. The done-transition command compares the two stamps (no extra git work) → equal: KB capture,
   promotion, then the `done` write; unequal: Stale-phase re-run cycle or STOP.
5. The `done` write hits `enforce-gate` (Claude Code): recompute `current` independently; deny a
   missing or stale stamp with the changed paths; allow otherwise. Bookkeeping writes between stamp
   and `done` (manifest, `verify.md`, evidence, KB entries, promoted docs) sit under excluded paths.

## Risks

- **Build/test outputs not gitignored** (spec Assumption 3, open): verify's stamp includes them,
  review's does not → one spurious review re-run per run (the re-run's stamp then matches). The deny
  reason lists the paths so the user can ignore them. Validated by a plan task on this repo.
- **Large repositories** (spec Assumption 4, open; SM1): the index copy keeps the stat cache; the
  check runs only on `done` writes. Validated by a plan task on a ≥20k-file synthetic repo.
- **WP4 conflict:** WP4's branch rewrites `hooks/enforce-gate`. Accepted; the constraint that WP4 must
  preserve Gates A/B and revision binding is written into `enforcement.md` and the CHANGELOG.
- **Unreferenced tree objects** accumulate in `.git/objects` (one per stamp); `git gc` reaps them.
  Accepted — inert, no refs, no index or history change.

## Devil's advocate

### Failure scenarios

- **FS1:** Between a phase's stamp and the `done` write, the stamped tree object is pruned (e.g. a
  `git gc --prune=now`), so `git diff-tree` cannot list changed paths. If the hook treats that
  failure as "cannot compute", it would allow a stale `done` (warn path) or emit a garbled reason —
  the gate must still **deny** on id inequality and print "changed paths unavailable".
- **FS2:** The agent runs a paraphrase of the recipe instead of the lib / verbatim block (drops the
  nested-repo skip, adds a `:(exclude)` pathspec, hashes a different root). Its stamp never equals
  the hook's recomputation, so every revision-bound run is denied at `done` and loops into the
  stale re-run. The stamp produced by the command path must equal the hook's value on the same tree.
- **FS3:** The session's `cwd` is a subdirectory of the git top level (monorepo package). If excludes
  are applied relative to the top level instead of `cwd`, `.feature-flow/` writes change the
  fingerprint (every `done` denied); if the fingerprint only hashes the `cwd` subtree, edits elsewhere
  in the repo slip through. Excludes must resolve from `cwd` and the fingerprint must cover the top level.
- **FS4:** `.feature-flow.json` sets `paths.durable` to an absolute path, a trailing-slash form, or
  `null`, or leaves `paths.kb` unset. A naive `git rm --cached "$path"` then misses the directory (or
  errors), so promoted docs / KB capture between the verify stamp and `done` flip the fingerprint and
  every run is denied.

### Edge cases & operational risk

- Submodules: a tracked gitlink counts as code; a submodule HEAD move changes the revision. Accepted.
- Windows (Git Bash via `hooks/run-hook.cmd`): `mktemp`, `cp` and `git` exist in Git Bash; path
  relativization must not assume `/`-rooted `cwd` forms only — covered by the existing dispatch-seam
  test, not a new platform matrix.
- A user editing code while verify runs: the hook denies `done` — a true positive, not a defect.
- Runs in flight at upgrade have no `revisionBound` → unaffected (AC8); no migration.
