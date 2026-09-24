# Plan: Bind review and verify to the same code revision

**Goal:** A revision-bound run reaches `done` only when review and verify both attested the current working-tree revision.

## Outcome gate

**Spec:** `docs/feature-flow/2026-09-24-revision-binding/spec.md`
**Design:** `docs/feature-flow/2026-09-24-revision-binding/design.md`
**Acceptance criteria:** see spec §Acceptance criteria (AC1–AC15), plus E2E, SM1 and design FS1–FS4. Each task below maps
to specific ACs; the final task verifies all of them.
**User signed off:** yes (2026-09-24)

> No task executes while sign-off is "no". At completion, `/feature-flow:ff-verify` checks the
> result against the spec's acceptance criteria — not just the task list.
>
> Every spec AC maps to ≥1 task's `**Covers:**` line — AC1 T6/T7, AC2 T6/T7, AC3 T2, AC4 T2, AC5 T4,
> AC6 T4, AC7 T4, AC8 T4/T7, AC9 T4, AC10 T7, AC11 T7, AC12 T8, AC13 T5/T9, AC14 T4/T10, AC15 T10.
> No AC is uncovered.
>
> **Assumption validation (full tier).** Assumption 3 → Task 1 (`**Validates:** Assumption 3`);
> Assumption 4 → Task 3 (`**Validates:** Assumption 4`). Both acknowledged-open at sign-off.
>
> **Requirement-graph coverage.** Folded into the dependency graph: AC5→AC4 (T4 depends on T2);
> AC10→AC5 and AC11→AC5 (T7 depends on T4). Named gaps — `AC6 depends-on AC5: covered by the same
> Task 4`; `AC7 depends-on AC5: covered by the same Task 4`; `AC14 depends-on AC9: covered by the same
> Task 4` (T10, the other AC14 task, depends on T4).

## Tasks

### Task 1: Validate Assumption 3 — test/build runs leave no untracked code

**Files:**
- Read only (evidence under the run dir)

**Covers:** — (validation task)
**Validates:** Assumption 3

- [x] **Step 1:** In a scratch clone of this repo at HEAD, record `git status --porcelain --ignored=no`,
  run every `scripts/checks/*.sh` and `scripts/eval.sh`, record status again.
- [x] **Step 2: Verify** — the two status listings are identical (no new untracked non-ignored path).
  Record the outcome in the plan's Decisions section; if it fails, STOP and surface to the user
  (the WHAT would change — spec Assumption 3 if-wrong impact).

### Task 2: `hooks/lib/revision.sh` — the shared library (test-first)

**Files:**
- Create: `hooks/lib/revision.sh`
- Modify: `scripts/checks/enforce-gate-guard.sh` (new "revision lib" section)

**Covers:** AC3, AC4

- [x] **Step 1:** Add lib fixtures to `enforce-gate-guard.sh` using a real `git init` temp repo (no
  commits needed beyond one baseline commit): repeatable id; write under `.feature-flow/`, the
  configured `paths.durable`, `paths.kb` → unchanged; nested repo under `.claude/worktrees/x` →
  unchanged; tracked edit / tracked delete / untracked add → changed; revert → original; clean tree
  → equals `git rev-parse HEAD^{tree}`; real `.git/index` byte-identical before/after; `cwd` a
  subdirectory (FS3); `paths.durable` absolute / trailing slash / `null`, `paths.kb` unset (FS4);
  `revision_changed_paths` caps at 10 with "+N more"; missing object → "changed paths unavailable" (FS1).
- [x] **Step 2:** Run the guard → RED (lib absent).
- [x] **Step 3:** Write `hooks/lib/revision.sh`: `revision_excludes <project-dir>` (project
  `.feature-flow.json` → built-in defaults `.feature-flow` / null / `.feature-flow-kb`; relativize to
  `git rev-parse --show-toplevel`; drop null, empty, and out-of-tree paths), `revision_fingerprint
  <project-dir>` (explore prototype; no pathspec excludes; skip nested repos), `revision_changed_paths
  <project-dir> <tree-a> <tree-b>`; CLI mode when executed directly. Only `git mktemp cp rm` plus
  shell builtins.
- [x] **Step 4: Verify** — `bash scripts/checks/enforce-gate-guard.sh` → exit 0, every lib case ok.

### Task 3: Validate Assumption 4 / SM1 — fingerprint cost on a large repo

**Files:**
- Scratch only (timing evidence under the run dir)

**Covers:** — (validation task; proves SM1)
**Validates:** Assumption 4

- [x] **Step 1:** Generate a scratch git repo with ≥ 20,000 tracked files (committed), plus a handful
  of modified and untracked files; build a revision-bound `done` payload.
- [x] **Step 2: Verify** — time `bash hooks/lib/revision.sh <repo>` (and, after Task 4, the hook on
  the payload with and without the revision block, i.e. `revisionBound` true vs absent); the delta is
  ≤ 1 s. Record the numbers; on failure STOP and surface (spec Assumption 4 if-wrong impact).

### Task 4: Gate B revision check in `hooks/enforce-gate` (test-first)

**Files:**
- Modify: `hooks/enforce-gate`, `scripts/checks/enforce-gate-guard.sh`

**Covers:** AC5, AC6, AC7, AC8, AC9, AC14

- [x] **Step 1:** Add hook fixtures (real temp git repos, `revisionBound: true`, valid verify.md):
  review stamp missing → deny naming review; verify stamp missing → deny naming verify; review stale
  → deny naming review + the edited path; verify stale → deny naming verify; both equal current →
  allow; stale tree pruned → deny + "changed paths unavailable" (FS1); `revisionBound` absent in a git
  repo → 0.21.0 behaviour; `revisionBound: true` outside any repo → 0.21.0 behaviour; `toggles.enforce:
  false` → allow; `.git` present but `git` missing from PATH → allow + `systemMessage` (AC9); one
  stale-deny case routed through `hooks/run-hook.cmd` (the E2E shape). Existing fixtures untouched;
  `assert_deny` still requires `Gate [AB]`.
- [x] **Step 2:** Run the guard → RED on the new cases.
- [x] **Step 3:** Implement in the `phase == done` branch, after the existing checks: walk up from
  `cwd` for `.git`; source `hooks/lib/revision.sh` from the hook's own dir; compute `current` once;
  deny per stamp; accumulate the AC9 warning and print it only if no deny fired. Update the PATH-shim
  case if the non-revision path's tool set changed (it should not).
- [x] **Step 4: Verify** — `bash scripts/checks/enforce-gate-guard.sh` → exit 0; `b-template` still denies.

### Task 5: Contract prose

**Files:**
- Modify: `docs/manifest-schema.md`, `docs/schema/enforcement.md`, `docs/schema/terminal-convergence.md`, `docs/schema/autopilot.md`

**Covers:** AC13

- [x] **Step 1:** `manifest-schema.md` — Schema block gains `revisionBound` and `phases.<review|verify>.revision`;
  Field-notes bullets with the absent-field back-compat rule (0.22.0).
- [x] **Step 2:** `enforcement.md` — Gate B revision condition (per-stamp vs current, reasons, the
  silent-skip vs loud-warn split); `### Revision fingerprint` whose fenced `bash` block is the lib
  file verbatim, with how to run it on Claude Code (the shipped file) vs Codex (`bash -s --`); the WP4
  preservation constraint.
- [x] **Step 3:** `terminal-convergence.md` — on revision-bound runs `done` requires both stamps equal
  the current revision; points at §Enforcement and the Stale-phase re-run cycle.
- [x] **Step 4:** `autopilot.md` — mandatory-pauses row + **Stale-phase re-run cycle** (trigger, the
  `## Stale re-run` durable cap, one re-run, STOP shape; step-by-step always stops).
- [x] **Step 5: Verify** — `bash scripts/checks/schema-layout-guard.sh` and every schema-reading guard exit 0.

### Task 6: Template revision lines

**Files:**
- Modify: `templates/review.md`, `templates/verify.md`

**Covers:** AC1, AC2

- [x] **Step 1:** Add a digit-free header line `**Revision:** <working-tree fingerprint, or "not recorded — <reason>">`
  to both; add the optional `## Stale re-run` section skeleton (digit-free) after `## Resolution` /
  `## Repair` respectively.
- [x] **Step 2: Verify** — `enforce-gate-guard.sh` `b-template` still denies; `dist`-free guards green.

### Task 7: Commands — stamping and the done-transition check

**Files:**
- Modify: `commands/ff-review.md`, `commands/ff-verify.md`

**Covers:** AC1, AC2, AC8, AC10, AC11

- [x] **Step 1:** Both commands: `## Stamp the revision` immediately before the manifest update
  (after any fix / repair cycle) — skip when `revisionBound` is not `true`; run the lib (Claude Code) /
  canonical block (Codex) in the project dir; write `phases.<phase>.revision` and the `**Revision:**`
  line; on non-git or failure write `null` + the reason; never block.
- [x] **Step 2:** `ff-verify` feature-terminal branch and both commands' bugfix-terminal branches:
  compare the other phase's stamp to the one just written; mismatch → the Stale-phase re-run cycle
  (referenced, not restated); report "revision binding skipped — <reason>" on skip paths (AC8).
- [x] **Step 3:** The re-run on the feature track re-dispatches the full review (focus +
  spec-conformance reviewers) per `ff-review`'s own `Do the work`; on bugfix it re-dispatches
  `ff-test-runner` per `ff-verify`'s own `Do the work` — each by reference.
- [x] **Step 4: Verify** — `schema-layout-guard.sh` L4 (every new `§Name` resolves) exit 0.

### Task 8: Mark new runs revision-bound

**Files:**
- Modify: `commands/ff.md`, `commands/ff-explore.md`, `commands/ff-clarify.md`, `commands/ff-diagnose.md`

**Covers:** AC12

- [x] **Step 1:** Each manifest-creation step writes `revisionBound: true` alongside `autopilot`.
- [x] **Step 2: Verify** — `grep -c revisionBound` is ≥ 1 in each of the four files.

### Task 9: `scripts/checks/revision-binding-guard.sh`

**Files:**
- Create: `scripts/checks/revision-binding-guard.sh`

**Covers:** AC13

- [x] **Step 1:** Structural checks: field notes in `manifest-schema.md`; Gate B revision text + WP4
  constraint in `enforcement.md`; the cycle row + section in `autopilot.md`; the convergence paragraph;
  `## Stamp the revision` in both commands; `revisionBound` in the four creation commands; digit-free
  `**Revision:**` line in both templates; WP4 constraint in the newest CHANGELOG entry.
- [x] **Step 2:** Byte identity: the fenced block under `### Revision fingerprint` ≡ `hooks/lib/revision.sh`;
  the lib's built-in defaults ≡ `config/defaults.json` `paths.base` / `paths.durable` / `paths.kb`.
- [x] **Step 3:** Negative test: mutate a copy of the doc block by one character → the identity check fails.
- [x] **Step 4: Verify** — `bash scripts/checks/revision-binding-guard.sh` → exit 0.

### Task 10: Release 0.22.0 and full verification

**Files:**
- Modify: `.claude-plugin/plugin.json`, `.codex-plugin/plugin.json`, `.claude-plugin/marketplace.json`, `README.md`, `CHANGELOG.md`, `dist/codex/**` (generated)

**Covers:** AC14, AC15

- [x] **Step 1:** Bump to 0.22.0; CHANGELOG `[0.22.0]` entry: what and why (F01), the manifest fields,
  the WP4 preservation constraint, the SM1 measurement, known limits (Bash-tool writes, Codex prose-only,
  untracked build output).
- [x] **Step 2:** `bash scripts/package-codex-plugin.sh` → repackage `dist/codex`.
- [x] **Step 3: Verify** — `for g in scripts/checks/*.sh; do bash "$g" || echo FAIL $g; done` prints no
  FAIL, and `bash scripts/eval.sh` exits 0.

## Dependency graph

| Task | Depends on |
|------|------------|
| Task 1 | — (root) |
| Task 2 | — (root) |
| Task 3 | Task 2 |
| Task 4 | Task 1, Task 2, Task 3 |
| Task 5 | Task 2 |
| Task 6 | — (root) |
| Task 7 | Task 4, Task 5, Task 6 |
| Task 8 | Task 5 |
| Task 9 | Task 5, Task 7, Task 8 |
| Task 10 | Task 1, Task 3, Task 4, Task 9 |

> One row per task in `## Tasks` above. `Depends on` names only **lower-numbered** `Task N`
> IDs already defined above (or "— (root)" for no prerequisite) — never a phantom or a
> higher-numbered task. Multiple roots are normal; this is dependency data, not an instruction
> to run tasks concurrently.

## Critical path

**Path:** Task 2 → Task 3 → Task 4 → Task 7 → Task 9 → Task 10

> **Derived — never hand-authored.** The longest dependency chain through the graph above (per
> `${CLAUDE_PLUGIN_ROOT}/docs/schema/planning-intelligence.md` §Planning intelligence → Critical-path
> derivation). Every task named here is non-skippable, in this order: `/feature-flow:ff-implement`
> STOPs if the approach skips or reorders one. No dependencies at all → "no gating chain — all
> tasks independent"; fully linear plan → the whole task sequence. Re-derive if the graph changes.

Derivation: depth T1=0, T2=0, T3=1, T4=2, T5=1, T6=0, T7=3, T8=2, T9=4, T10=5 → sink Task 10; back-walk
takes the deepest dependency each step (T9 → T7 → T4 → T3 → T2).

## Risk register

| Risk | Likelihood | Impact | Mitigation |
|------|-----------|--------|-----------|
| Untracked build/test output makes verify's revision differ from review's (Assumption 3) | Med | Med | Task 1 validates on this repo; deny reason lists paths; one bounded re-run absorbs it |
| Fingerprint too slow on large repos (Assumption 4) | Low | Med | Index copy keeps stat cache; done-writes only; Task 3 measures |
| Command-path stamp ≠ hook recomputation (FS2) | Med | High | Claude Code commands execute the shipped lib; Codex runs the byte-identical block; Task 9 guards identity |
| Excludes resolved against the wrong root (FS3, FS4) | Med | High | Task 2 fixtures for subdirectory `cwd` and every `paths.*` form |
| New git code path breaks existing non-git fixtures or the PATH shim | Low | Med | Revision block only on `done` + `revisionBound`; existing fixtures unchanged by construction |
| Textual conflict with the WP4 branch | High | Low | Accepted, not mitigated: WP4 is unmerged; the preservation constraint is documented |

> Categorical only — **no numeric scores** (upholds the no-numeric-confidence doctrine).
> `/feature-flow:ff-verify` cross-references this register into its `## Regression risk`
> assessment instead of deriving risk cold. A risk accepted without mitigation says so.

## Rollback plan

| Task | Recovery action if `Step N: Verify` fails |
|------|--------------------------------------------|
| Task 2 | `git checkout -- scripts/checks/enforce-gate-guard.sh && rm -f hooks/lib/revision.sh` |
| Task 4 | `git checkout -- hooks/enforce-gate scripts/checks/enforce-gate-guard.sh` (keeps Task 2 via re-apply of its section) |
| Task 5 | `git checkout -- docs/manifest-schema.md docs/schema/` |
| Task 7 | `git checkout -- commands/ff-review.md commands/ff-verify.md` |
| Task 10 | `git checkout -- .claude-plugin .codex-plugin README.md CHANGELOG.md dist/` then re-run the packager |

> One row per task that risks a half-applied state. `/feature-flow:ff-implement` runs this
> recovery instead of leaving the tree half-applied when a Verify step fails. An irreversible
> step states "irreversible: mitigation is `<X>`" rather than a fake undo.

## Status conventions

Stateful document. After each task bump its status:
`[ ]` pending · `[~]` in progress · `[x]` done · `[!]` blocked · `[→]` deferred.
Keep a Status summary line current; append Blockers / Deviations / Decisions as needed.

**Status:** 10/10 tasks done.

## Blockers

(none yet)

## Decisions made during execution

- **Task 1 (Assumption 3) — validated 2026-09-24.** Real repo: every `scripts/checks/*.sh` + `scripts/eval.sh` run; `git status --porcelain` identical before/after (only the pre-existing `?? .claude/`). Scratch clone: same, 0 new paths. Baseline: all guards green except `integrity-conformance-guard.sh` (Go not installed locally — known env quirk; CI unaffected). A clone without a built `dist/` fails 17 guards — expected, `dist/` is gitignored and built locally.
- **Task 2** — test-first: 20 lib fixtures RED (lib absent) → GREEN. One fixture defect fixed: the "real index untouched" check sampled across the fixture's own `git checkout`s (which rewrite the index); isolated probe showed the lib leaves `.git/index` byte-identical, so the check now samples right around the lib calls.
- **Task 3 (Assumption 4 / SM1) — validated 2026-09-24.** Synthetic repo, 22,000 tracked files + 5 modified + 5 untracked. Lib alone: steady state 0.06–0.08 s (15 samples); every file's stat stale (forces a full re-hash): 0.17–0.25 s; one 1.14 s sample immediately after creating the 22k files (disk writeback, not reproducible). Hook `done` write: revision check off 0.02–0.03 s, on 0.10–0.51 s (7 samples each), all-stat-stale 0.23 s → added cost ≤ ~0.5 s ≤ 1 s.
- **Task 4** — test-first: new hook fixtures RED (deny/warn cases) → GREEN; `enforce-gate-guard.sh` 78/78 ok. The AC8 allow cases passed before and after (they pin 0.21.0 behaviour).
- **Task 5** — `schema-layout-guard.sh` L1–L4 green (every new `**Revision agreement**` / `**Stale-phase re-run cycle**` / §Revision fingerprint reference resolves); L5 dist parity green after repackaging.
- **Task 9 — deviation (ordering only):** its CHANGELOG/WP4 assertion necessarily failed until Task 10 wrote the entry; all its other 23 assertions passed at Task 9, and the whole guard passed at Task 10's verify. Critical-path order unchanged.
- **Task 10** — 37 new `enforce-gate-guard.sh` cases (78 total vs 41 on master); every `scripts/checks/*.sh` green except `integrity-conformance-guard.sh` (Go absent locally — pre-existing), `scripts/eval.sh` exit 0.
- **This run is not itself revision-bound:** its manifest predates the field, and the field note forbids adding `revisionBound` after creation. The behaviour is proven by the guard fixtures and the E2E instead.
