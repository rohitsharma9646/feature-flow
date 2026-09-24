# Verify: Bind review and verify to the same code revision (v0.22.0)

**Track:** feature
**Tier:** full
**Date:** 2026-09-24
**Revision:** not recorded — this run's manifest predates `revisionBound` (the field is written only at creation)
**Verified by:** `ff-test-runner` (executed) — evidence below is real command output.

## Commands run

| Command | Kind | Status | Evidence |
|---------|------|--------|----------|
| `bash scripts/checks/enforce-gate-guard.sh` | executed-test | pass | exit 0 — `PASS: enforce-gate guard`, 79 ok (`evidence/executed-test-09-enforce-gate-guard.txt`) |
| `bash scripts/checks/revision-binding-guard.sh` | executed-test | pass | exit 0 — `PASS: revision-binding guard`, 24 ok (`evidence/executed-test-21-revision-binding-guard.txt`) |
| `bash scripts/checks/<each>.sh` (26 guards, individually) | executed-test | 25 pass, 1 fail | exit 0 ×25; `integrity-conformance-guard.sh` exit 1 — `FAIL: Go toolchain is required for WP1 conformance`, `which go` → not found; fails identically on master (pre-existing, local-only) (`evidence/executed-test-01..26-*.txt`) |
| `bash scripts/eval.sh` | executed-test | pass | exit 0 (`evidence/executed-test-27-eval-sh.txt`) |
| `grep -n "revision binding skipped" commands/ff-review.md commands/ff-verify.md` | executed-test (static) | pass | exit 0, both match (`evidence/executed-test-28-ac8-grep.txt`) |
| `bash scripts/package-codex-plugin.sh` | build/static-analysis | pass | exit 0 — "Codex package ready." (`evidence/build-01-package-codex-plugin.txt`) |
| `bash scripts/checks/dist-parity-guard.sh` | build/static-analysis | pass | exit 0 — 60 files in sync, 0 drifted (`evidence/build-02-dist-parity-guard.txt`) |
| `bash scripts/checks/version-sync-guard.sh` | build/static-analysis | pass | exit 0 — 0.22.0 everywhere (`evidence/build-03-version-sync-guard.txt`) |
| E2E: stale-review `done` payload → `bash hooks/run-hook.cmd enforce-gate` (scratch repo) | cli-output | pass | exit 0, deny JSON naming `review revision is stale … (changed: src/main.txt)` (`evidence/cli-output-01-e2e-deny.txt`) |
| E2E: re-stamped `done` payload → `bash hooks/run-hook.cmd enforce-gate` | cli-output | pass | exit 0, empty output = allow (`evidence/cli-output-02-e2e-allow.txt`) |
| FS2: `bash hooks/lib/revision.sh <repo>` vs `bash -s -- <repo> < <enforcement.md block>` | cli-output | pass | exit 0 both, identical id `2bcdee5505270603f09be0987c4df15ede8a289e`; extracted block `diff`-identical to the lib (`evidence/cli-output-03-fs2-crosscheck.txt`) |
| SM1: `time bash hooks/enforce-gate < payload` ×5 bound vs ×5 unbound, 20,000 tracked files | before/after | pass | exit 0 — bound 0.0995–0.1097 s, unbound 0.0333–0.0345 s, delta 0.0703 s (`evidence/before-after-01-sm1-timing.txt`) |

## Evidence coverage matrix

| Surface | Detected | Expected kind | Ran / result |
|---|---|---|---|
| `scripts/checks/*.sh` | yes (26) | executed-test | ran — 25 pass, 1 environment-only fail |
| `scripts/eval.sh` | yes | executed-test | ran — pass |
| Packaging (`scripts/package-codex-plugin.sh`) + parity / version guards | yes | build/static-analysis | ran — pass |
| The hook's production dispatch (`hooks/run-hook.cmd`) on a scratch repo | yes | cli-output | ran — E2E deny then allow |
| Large-repo timing | yes | before/after | ran — SM1 pass |
| e2e/browser | no | — | N/A — no `playwright.config.*`; a bash/Markdown plugin with no UI |
| http/api | no | — | N/A — no server or endpoints |
| db | no | — | N/A — no database |
| logs | no | — | N/A — no project log files; command output captured directly |
| **Agent execution of the workflow prose** (a fresh session running `ff-review` / `ff-verify` / `ff`) | yes (`scripts/forward-test.sh`, `evals/forward/`) | cli-output | **not run** — a paid, fresh-session forward test; needs your go-ahead (see gaps) |

## Contract mapping

Confidence per item — exactly one of `Verified (multi-source)` | `Verified (single-source)`
| `Partially verified` | `Unverified`, derived per `docs/schema/evidence.md` §Evidence,
Confidence ladder.

### AC1: When `ff-review` completes on a revision-bound run in a git repo — including after an autopilot fix-and-re-review cycle — the manifest records the working-tree revision the review covered, and `review.md` states that revision in its header.
- **Method:** executed-test (the instruction and its placement); no agent run.
- **Evidence:**
  - `bash scripts/checks/revision-binding-guard.sh` — exit 0 — `## Stamp the revision` present in `commands/ff-review.md`, before its manifest update, with the verbatim-recipe rule; `templates/review.md` has the `**Revision:**` line
  - `bash scripts/checks/enforce-gate-guard.sh` — exit 0 — the stamped value, once written, is what Gate B checks (GateB/AC5–AC7)
- **Confidence:** Partially verified
- **Gap:** no executed check has an agent run `ff-review` on a revision-bound run and write the stamp (including after a fix cycle). Needs a forward test in a fresh session.

### AC2: When `ff-verify` completes on a revision-bound run in a git repo — including after an autopilot repair-and-re-verify cycle — the manifest records the revision of the tree as verified (post-repair), and `verify.md` states it in its header.
- **Method:** executed-test (instruction and placement); no agent run.
- **Evidence:**
  - `bash scripts/checks/revision-binding-guard.sh` — exit 0 — `## Stamp the revision` in `commands/ff-verify.md`, after the repair section and before its manifest update; `templates/verify.md` `**Revision:**` line
- **Confidence:** Partially verified
- **Gap:** as AC1 — an agent actually stamping after a repair cycle is not exercised. Needs a forward test.

### AC3: The revision is unchanged by writes confined to `paths.base`, `paths.durable` and `paths.kb`, and by changes inside nested git repositories.
- **Method:** executed-test (real temporary git repositories)
- **Evidence:**
  - `bash scripts/checks/enforce-gate-guard.sh` — exit 0 — `rev lib/AC3: writes under paths.base, paths.durable, paths.kb don't change it`; `rev lib/AC3: nested git repository doesn't change it`
- **Confidence:** Verified (single-source)

### AC4: The revision changes when a tracked file is modified or deleted, or an untracked non-ignored file is added, outside those paths; reverting the change restores the original value.
- **Method:** executed-test
- **Evidence:**
  - `bash scripts/checks/enforce-gate-guard.sh` — exit 0 — `rev lib/AC4` ×4 (tracked edit, tracked delete, untracked add, revert restores)
- **Confidence:** Verified (single-source)

### AC5: On a revision-bound run in a git repo, `hooks/enforce-gate` **denies** a manifest write that sets `currentPhase: "done"` when the review revision is missing, the verify revision is missing, the two differ, or either differs from the current working-tree revision — with a `Gate B` reason naming which condition failed.
- **Method:** executed-test + cli-output
- **Evidence:**
  - `bash scripts/checks/enforce-gate-guard.sh` — exit 0 — `GateB/AC5` ×5 (review missing, verify missing, review stale, verify stale, reasons name the phase)
  - `bash hooks/run-hook.cmd enforce-gate` (E2E step 1) — exit 0 — deny, `review revision is stale` (`evidence/cli-output-01-e2e-deny.txt`)
- **Confidence:** Verified (multi-source)

### AC6: The same write is **allowed** when both recorded revisions equal the current revision and the existing Gate B conditions hold.
- **Method:** executed-test + cli-output
- **Evidence:**
  - `bash scripts/checks/enforce-gate-guard.sh` — exit 0 — `GateB/AC6` ×2
  - `bash hooks/run-hook.cmd enforce-gate` (E2E step 2) — exit 0 — empty output = allow (`evidence/cli-output-02-e2e-allow.txt`)
- **Confidence:** Verified (multi-source)

### AC7: A mismatch reason lists the paths that differ between the stale revision and the current tree (capped, with a count of the rest), so a spurious mismatch is diagnosable.
- **Method:** executed-test + cli-output
- **Evidence:**
  - `bash scripts/checks/enforce-gate-guard.sh` — exit 0 — `rev lib/AC7: changed paths listed, capped at 10 with '+N more'`; `GateB/AC7: stale reason names the phase and the changed path`
  - E2E step 1 — exit 0 — reason contains `(changed: src/main.txt)`
- **Confidence:** Verified (multi-source)

### AC8: A run created before this version (not revision-bound), a project that is not a git repository, and `toggles.enforce: false` all leave Gate B's behaviour exactly as in 0.21.0; the terminal command's report says revision binding was skipped and why.
- **Method:** executed-test (hook half); executed-test static (report-line instruction present); no agent run for the report half.
- **Evidence:**
  - `bash scripts/checks/enforce-gate-guard.sh` — exit 0 — `GateB/AC8` ×3 (no `revisionBound` in a git repo; outside git; kill switch)
  - `grep -n "revision binding skipped" …` — exit 0 — both commands carry the report line
- **Confidence:** Partially verified
- **Gap:** the hook half is verified; a terminal command actually *emitting* the skipped line in its completion report is agent behaviour, not exercised. Needs a forward test.

### AC9: If the fingerprint cannot be computed inside a git repo on a revision-bound run, the hook allows the write and emits a `systemMessage` warning; it never allows silently.
- **Method:** executed-test (PATH shim without git)
- **Evidence:**
  - `bash scripts/checks/enforce-gate-guard.sh` — exit 0 — `GateB/AC9: git unavailable in a git repo → allowed with a systemMessage warning`; `GateB/AC9: no deny when the revision cannot be computed`
- **Confidence:** Verified (single-source)

### AC10: Feature track: when verify's done-transition finds the review revision stale, autopilot re-runs the full review dispatch (focus + spec-conformance reviewers) exactly once and re-stamps; if review is then clean and all revisions agree, the run reaches `done`; otherwise it stops with a report naming the stale phase. Step-by-step stops and tells the user to re-run `/feature-flow:ff-review` then `/feature-flow:ff-verify`.
- **Method:** executed-test (instruction text); no agent run.
- **Evidence:**
  - `bash scripts/checks/revision-binding-guard.sh` — exit 0 — Stale-phase re-run cycle defined with its `## Stale re-run` one-cycle cap; mandatory-pauses row capped-then-stop; `ff-verify` routes to it
- **Confidence:** Partially verified
- **Gap:** the cycle firing exactly once and then stopping is agent behaviour. Needs a fired/control forward test (same posture as the repair and fix cycles in earlier releases).

### AC11: Bugfix track: when the done-transition (whichever of verify/review runs second) finds the other phase's revision stale, autopilot re-runs that phase exactly once and re-stamps, then reaches `done` only if all revisions agree; otherwise it stops with a report. Step-by-step stops and names the phase to re-run.
- **Method:** executed-test (instruction text); no agent run.
- **Evidence:**
  - `bash scripts/checks/revision-binding-guard.sh` — exit 0 — both commands carry the agreement check routing to the cycle
- **Confidence:** Partially verified
- **Gap:** as AC10, for the bugfix track.

### AC12: New runs are marked revision-bound at manifest creation (by `/feature-flow:ff` and by every cold-start path that creates a manifest).
- **Method:** executed-test (instruction text); no agent run.
- **Evidence:**
  - `bash scripts/checks/revision-binding-guard.sh` — exit 0 — `AC12` ×4 (`ff`, `ff-explore`, `ff-clarify`, `ff-diagnose`)
- **Confidence:** Partially verified
- **Gap:** an agent creating a manifest that actually carries `revisionBound: true` is not exercised. Needs a forward test.

### AC13: The rule is stated in prose in `ff-review`, `ff-verify`, `docs/schema/enforcement.md` and `docs/schema/terminal-convergence.md`, so Codex follows it without the hook; the WP4 constraint is stated in `docs/schema/enforcement.md` and the CHANGELOG.
- **Method:** executed-test
- **Evidence:**
  - `bash scripts/checks/revision-binding-guard.sh` — exit 0 — `AC13` ×15 lines; `bash scripts/checks/schema-layout-guard.sh` — exit 0 — every new reference resolves
- **Confidence:** Verified (single-source)

### AC14: `scripts/checks/enforce-gate-guard.sh` exercises AC3–AC9 against real temporary git repositories, the verbatim `templates/verify.md` still denies (b-template), every existing fixture passes unchanged, and every `scripts/checks/*.sh` plus `scripts/eval.sh` exits 0.
- **Method:** executed-test
- **Evidence:**
  - `bash scripts/checks/enforce-gate-guard.sh` — exit 0 — 79 ok incl. `GateB/AC10: verbatim unfilled template → denied`
  - 26 guards — exit 0 ×25; `integrity-conformance-guard.sh` exit 1 (Go toolchain absent — identical on master, not caused by this change); `bash scripts/eval.sh` — exit 0
- **Confidence:** Verified (single-source)
- **Note:** "every guard exits 0" holds in CI, where Go is installed; locally one pre-existing guard cannot run. Not a gap introduced by this change.

### AC15: Version is 0.22.0 across the synced manifests, README badge and CHANGELOG head, and `dist/codex` is repackaged (dist-parity green).
- **Method:** build/static-analysis
- **Evidence:**
  - `bash scripts/package-codex-plugin.sh` — exit 0; `bash scripts/checks/dist-parity-guard.sh` — exit 0 (60 in sync); `bash scripts/checks/version-sync-guard.sh` — exit 0
- **Confidence:** Verified (single-source)

### E2E: in a scratch git repo with a revision-bound feature manifest, pipe a `done` write through `hooks/run-hook.cmd enforce-gate` after (1) stamping review, editing a source file, then stamping verify → **denied**, reason names the stale review and the edited path; then (2) re-stamping review on the current tree → **allowed**.
- **Method:** cli-output (run exactly as stated)
- **Evidence:**
  - step 1 — exit 0 — deny, `review revision is stale — the code changed after review ran (changed: src/main.txt)` (`evidence/cli-output-01-e2e-deny.txt`)
  - step 2 — exit 0 — allow (`evidence/cli-output-02-e2e-allow.txt`)
- **Confidence:** Verified (single-source)

### SM1: The Gate B revision check adds ≤ 1 s to a `done` write on a repository of ≥ 20,000 tracked files, measured by timing the hook on a `done` payload with and without the check.
- **Method:** before/after
- **Evidence:**
  - `time bash hooks/enforce-gate < payload` — exit 0 — delta 0.0703 s (bound 0.0995–0.1097 s vs unbound 0.0333–0.0345 s, 5 samples each; `evidence/before-after-01-sm1-timing.txt`). Consistent with implement-time Task 3 (22,000 files: ≤ ~0.5 s added, 0.23 s with every stat stale).
- **Confidence:** Verified (single-source)

### FS1: Between a phase's stamp and the `done` write, the stamped tree object is pruned (e.g. a `git gc --prune=now`), so `git diff-tree` cannot list changed paths. If the hook treats that failure as "cannot compute", it would allow a stale `done` (warn path) or emit a garbled reason — the gate must still **deny** on id inequality and print "changed paths unavailable".
- **Method:** executed-test
- **Evidence:**
  - `bash scripts/checks/enforce-gate-guard.sh` — exit 0 — `rev lib/FS1: missing tree object → 'changed paths unavailable'`; `GateB/FS1: stamped tree object missing → still denied`; `GateB/FS1: reason says changed paths unavailable`
- **Confidence:** Verified (single-source)

### FS2: The agent runs a paraphrase of the recipe instead of the lib / verbatim block (drops the nested-repo skip, adds a `:(exclude)` pathspec, hashes a different root). Its stamp never equals the hook's recomputation, so every revision-bound run is denied at `done` and loops into the stale re-run. The stamp produced by the command path must equal the hook's value on the same tree.
- **Method:** executed-test + cli-output
- **Evidence:**
  - `bash scripts/checks/revision-binding-guard.sh` — exit 0 — `FS2: … block is hooks/lib/revision.sh byte-for-byte`; `FS2 self-test: a one-character drift is caught`
  - Claude path vs Codex path on one scratch repo — exit 0 — identical fingerprints (`evidence/cli-output-03-fs2-crosscheck.txt`)
- **Confidence:** Verified (multi-source)
- **Note:** proves the two sanctioned carriers agree; an agent choosing to paraphrase anyway is mitigated by the "never re-type or paraphrase" instruction and caught by Gate B (a mismatched stamp denies), not prevented.

### FS3: The session's `cwd` is a subdirectory of the git top level (monorepo package). If excludes are applied relative to the top level instead of `cwd`, `.feature-flow/` writes change the fingerprint (every `done` denied); if the fingerprint only hashes the `cwd` subtree, edits elsewhere in the repo slip through. Excludes must resolve from `cwd` and the fingerprint must cover the top level.
- **Method:** executed-test
- **Evidence:**
  - `bash scripts/checks/enforce-gate-guard.sh` — exit 0 — `rev lib/FS3` ×2 (subdir bookkeeping excluded; edits elsewhere detected)
- **Confidence:** Verified (single-source)

### FS4: `.feature-flow.json` sets `paths.durable` to an absolute path, a trailing-slash form, or `null`, or leaves `paths.kb` unset. A naive `git rm --cached "$path"` then misses the directory (or errors), so promoted docs / KB capture between the verify stamp and `done` flip the fingerprint and every run is denied.
- **Method:** executed-test
- **Evidence:**
  - `bash scripts/checks/enforce-gate-guard.sh` — exit 0 — `rev lib/FS4` ×5 (absolute, trailing slash, `./` form, null + default kb, null makes `docs/ff` code)
- **Confidence:** Verified (single-source)

## Evidence artifacts index

All under `evidence/` (copied beside this report): `executed-test-01..28-*.txt`, `build-01..03-*.txt`,
`cli-output-00..04-*` (E2E payloads + hook outputs, FS2 cross-check + extracted block),
`before-after-01..03-*` (SM1 timing + payloads).

## Regression risk

**Low–Medium.** Cross-referencing the plan's Risk register:
- *Untracked build/test output* (Med/Med) — did not materialize here: Task 1 showed the full suite
  leaves no untracked files. Still a real risk in other repos; mitigated by the path list in the deny
  reason and the one bounded re-run.
- *Large-repo cost* (Low/Med) — did not materialize: 0.07 s added at 20,000 files (0.23 s worst case).
- *Command stamp ≠ hook recomputation* (FS2, Med/High) — mitigated and proven for the two sanctioned
  carriers; residual risk is an agent paraphrasing despite the instruction (Gate B then denies — a
  false stop, not a false pass).
- *Wrong-root excludes* (FS3/FS4) — did not materialize; fixtures cover every form.
- *Breaking existing fixtures* — did not materialize: all 41 pre-existing enforce-gate cases pass.
- *WP4 conflict* (High/Low) — accepted; unchanged.
Not anticipated by the register: the `.git` walk-up could spin on a relative path (found in review,
fixed, RED→GREEN fixture). The change touches the shared `enforce-gate` hook, but only on `done`
writes of runs created on 0.22.0+, so existing in-flight runs are unaffected.

## Limitations & remaining risks

- Agent-behaviour ACs (AC1, AC2, AC8 report half, AC10, AC11, AC12) have not been exercised by an
  agent — see the gap report.
- `integrity-conformance-guard.sh` cannot run locally (no Go); CI runs it.
- Codex follows revision binding as prose only (no hook).

## Verdict

**Overall confidence:** Partially verified

> Not "done" unless every contract item is `Verified (single-source)` or better. A
> `Partially verified` or `Unverified` item blocks the done transition — the run ends with
> a gap report instead — unless the user records the explicit waiver line below. On the
> bugfix track, a fix without RED→GREEN regression evidence is **incomplete**, not done.

**Waiver (only if user-recorded):** `Evidence gap accepted by user (2026-09-24): go with recommendation` — the user's reply to the gap report, adopting its recommended waiver: AC1, AC2, AC8 (report half), AC10, AC11, AC12 — agent-behaviour ACs; the hook backstop is verified; a fired/control forward test to follow.

> The waiver does not raise any item's confidence: AC1, AC2, AC8, AC10, AC11, AC12 stay `Partially verified`.

**Revision agreement:** revision binding skipped — run predates v0.22.0 (this run's manifest has no `revisionBound`).

**Verdict:** Ready for done (with the recorded waiver)
