# Plan: P0 Integrity WP2 — read-only doctor and explicit legacy migration

**Goal:** Deliver a packaged, strictly read-only integrity doctor and an explicit,
evidence-preserving, reviewed-plan-bound legacy migration path.

## Outcome gate

**Spec:** `docs/feature-flow/2026-07-23-p0-integrity-wp2/spec.md`
**Acceptance criteria:** see spec §Acceptance criteria (AC1–AC17). Each task below maps
to specific ACs; the final task verifies all of them.
**User signed off:** yes (2026-07-23)

No unvalidated `validation-required: y` assumptions → no validation task.

Requirement-graph gaps caused by same-task coverage:

- `AC8 depends-on AC4`: both are implemented across Task 3 and Task 4; the edge is represented as
  Task 4 depending on Task 3.
- No other spec edge is collapsed into one task.

## Tasks

### Task 1: Inventory and register every known legacy family

**Files:**
- Create: `cmd/ff-integrity-inventory/**`
- Create: `integrity/testdata/legacy/inventory-v1.json`
- Create: `integrity/migration/v0/registry.go`
- Create: `docs/integrity/legacy-profile-inventory.md`

**Covers:** AC1

- [x] **Step 1:** Implement a development-only inventory over Git history and committed dogfood
  fixtures using a versioned behavior-aware family fingerprint.
- [x] **Step 2:** Record each discovered family with sanitized provenance, digest, profile ID, or
  explicit unsupported rationale.
- [x] **Step 3:** Add a guard proving every inventoried family has exactly one disposition and no
  supported input matches multiple profiles.
- [x] **Step 4: Verify** — run the inventory tests and coverage guard; expect 100% disposition and
  zero ambiguous registered matches.

### Task 2: Establish shared strict diagnostics and trusted path observation

**Files:**
- Create: `integrity/jsonstrict/**`
- Create: `integrity/diagnostics/**`
- Create: `integrity/observe/**`
- Create: `integrity/pathpolicy/**`
- Modify: `integrity/classifier/diagnostics.go`
- Modify: `integrity/protocol/v1/diagnostics.json`

**Covers:** AC7

- [x] **Step 1:** Extract only reusable strict-JSON and catalogue/normalization primitives while
  retaining classifier-specific schema traversal and exact output behavior.
- [x] **Step 2:** Implement trusted immediate-run discovery with bounded reads, deterministic
  ordering, and run-directory symlink refusal.
- [x] **Step 3:** Implement cross-platform lexical containment for POSIX, drive-relative/absolute,
  UNC/device, traversal, and mixed separators.
- [x] **Step 4:** Implement real-parent/target symlink containment and logical pointer equivalence
  without accepting roots from manifest bytes.
- [x] **Step 5: Verify** — run unchanged WP1 classifier vectors plus path-policy unit/property tests;
  expect byte-identical WP1 output and all containment/equivalence cases passing.

### Task 3: Build the pure legacy profile and migration planner

**Files:**
- Create: `integrity/migration/types.go`
- Create: `integrity/migration/plan.go`
- Create: `integrity/migration/canonical.go`
- Create: `integrity/migration/v0/profiles.go`
- Create: `schemas/migration-plan-v1.schema.json`

**Covers:** AC4, AC6, AC13

- [x] **Step 1:** Implement disjoint typed mappings for registered profiles and fail-closed
  classification of unknown behavior fields, ambiguous profiles, and unsupported semantics.
- [x] **Step 2:** Define canonical deterministic plan encoding, source digest, transformations,
  pointer facts, preserved inert metadata, validation result, confirmations, and plan digest.
- [x] **Step 3:** Ensure corrupt/future/current-invalid/unsupported-old are diagnosis-only and
  current valid v1 returns an already-current no-write result.
- [x] **Step 4: Verify** — run pure planner/schema/property tests twice per input; expect identical
  plans and no filesystem, clock, random, lock, or writer capability.

### Task 4: Add honest pre-WP3 bootstrap and final validation

**Files:**
- Create: `integrity/migration/bootstrap.go`
- Create: `integrity/migration/validate.go`
- Create: `docs/integrity/bootstrap-v1.md`
- Modify: `schemas/embed.go`

**Covers:** AC8

- [x] **Step 1:** Implement namespaced hashed repository/worktree bootstrap identities and the
  deterministic `ffrun1:` run ID algorithm from trusted facts.
- [x] **Step 2:** Build a canonical baseline/scope descriptor supported by each profile and always
  emit `revision.status: unsupported`.
- [x] **Step 3:** Model `/migration/migratedAt` as the sole apply-time finalizer and reject
  bootstrap state combined with ready revision or fabricated assurance.
- [x] **Step 4:** Validate every accepted proposal against Manifest v1 plus WP2 semantic rules.
- [x] **Step 5: Verify** — run bootstrap golden/property tests; expect stable IDs, no rendered host
  paths, valid v1 proposals, and rejection of every fabricated-ready combination.

### Task 5: Implement typed doctor diagnosis and exit classification

**Files:**
- Create: `integrity/semantic/**`
- Create: `integrity/doctor/types.go`
- Create: `integrity/doctor/doctor.go`
- Create: `integrity/doctor/exit.go`
- Create: `schemas/doctor-result-v1.schema.json`

**Covers:** AC2

- [x] **Step 1:** Compose raw-byte classification with only WP2-owned pointer, mirror, lock, and
  migration-provenance checks.
- [x] **Step 2:** Implement deterministic single/all reporting over immediate runs, including
  abandoned, closed, missing, and corrupt cases.
- [x] **Step 3:** Implement the single exit classifier: 0 clean, 1 completed diagnosis with blocking
  integrity, 2 invocation/I/O/required-observation failure.
- [x] **Step 4: Verify** — run doctor typed-result and exit-matrix tests; expect stable run/code
  ordering and schema-valid reports.

### Task 6: Render doctor and migration results safely

**Files:**
- Create: `integrity/doctor/render_json.go`
- Create: `integrity/doctor/render_human.go`
- Create: `integrity/migration/render.go`

**Covers:** AC14

- [x] **Step 1:** Render JSON and human output only from immutable typed results.
- [x] **Step 2:** Map internal failures to catalogue diagnostics and safe logical path tokens;
  prevent raw OS errors and absolute paths from serialization.
- [x] **Step 3: Verify** — replay renderer parity and hostile-error fixtures; expect identical
  conclusions/codes and zero leaked host path or raw platform-error substrings.

### Task 7: Prove doctor and preview immutability

**Files:**
- Create: `integrity/testdata/doctor/**`
- Create: `integrity/doctor/immutability_test.go`
- Create: `scripts/check-integrity-doctor-immutability.sh`

**Covers:** AC3

- [x] **Step 1:** Capture byte, entry, modification-time, lock, migration-inventory, and Git/index
  snapshots before every doctor and preview case.
- [x] **Step 2:** Add subprocess/network/project-command sentinels and exclude only OS access time.
- [x] **Step 3:** Cover empty/all/current/legacy/corrupt/future/current-invalid/unsupported/error
  cases in human and JSON modes.
- [x] **Step 4: Verify** — run the immutability harness; expect zero changed dimensions and zero
  forbidden invocation events across the corpus.

### Task 8: Bind apply to the reviewed plan and re-observed facts

**Files:**
- Create: `integrity/storage/store.go`
- Create: `integrity/storage/preflight.go`
- Create: `integrity/storage/revalidate.go`
- Modify: `integrity/migration/types.go`

**Covers:** AC5

- [x] **Step 1:** Require `--expect-plan` semantics in the apply request before writer construction.
- [x] **Step 2:** Re-read source, reselect the profile, recompute the canonical plan, and compare its
  digest to the reviewed digest.
- [x] **Step 3:** Re-observe pointer identity/equivalence immediately before mutation and reject
  source, profile, plan, or pointer drift.
- [x] **Step 4: Verify** — run source/profile/plan/pointer/symlink drift races; expect stable refusal
  and zero writes in every mismatch case.

### Task 9: Implement evidence-preserving atomic apply

**Files:**
- Create: `integrity/storage/apply.go`
- Create: `integrity/storage/publisher.go`
- Create: `integrity/storage/replace_unix.go`
- Create: `integrity/storage/replace_windows.go`
- Create: `integrity/storage/replace_other.go`
- Modify: `go.mod`
- Modify: `go.sum`

**Covers:** AC9

- [x] **Step 1:** Preflight atomic replacement/sync/restrictive-storage capability before run-local
  writes and fail closed when guarantees are unavailable.
- [x] **Step 2:** Bind one injected UTC migration time, finalize provenance, and revalidate canonical
  v1 bytes.
- [x] **Step 3:** Publish exact original bytes to a content-addressed restrictive snapshot, then
  replace the canonical manifest from a synced same-directory temporary file.
- [x] **Step 4:** Implement Unix rename/directory-sync and native Windows replacement with no
  copy/delete or remove-then-rename fallback.
- [x] **Step 5: Verify** — run native publisher and permission/capability tests; expect either fully
  published canonical v1 plus exact snapshot or a pre-write capability refusal.

### Task 10: Add failure injection and recovery semantics

**Files:**
- Create: `integrity/storage/failure.go`
- Create: `integrity/storage/apply_failure_test.go`
- Create: `integrity/testdata/migration/failures/**`

**Covers:** AC10

- [x] **Step 1:** Inject failure before and after every read, validation, temp write, sync, snapshot
  publish, canonical replace, directory sync, and cleanup boundary.
- [x] **Step 2:** Guarantee original canonical bytes until successful replacement and prevent
  partial canonical visibility.
- [x] **Step 3:** Remove invocation-owned snapshot evidence when safe; otherwise return stable
  orphan metadata and recovery diagnostics.
- [x] **Step 4: Verify** — execute the full failpoint matrix; expect zero original-byte loss, zero
  partial canonical publication, and deterministic cleanup/orphan outcomes.

### Task 11: Enforce idempotence and terminal-run reopening

**Files:**
- Modify: `integrity/storage/apply.go`
- Create: `integrity/storage/idempotence_test.go`
- Create: `integrity/migration/terminal_test.go`

**Covers:** AC11, AC12

- [x] **Step 1:** Branch current valid v1 to already-current before clock, migration-directory, or
  writer access.
- [x] **Step 2:** Require the dedicated terminal confirmation in addition to apply authority.
- [x] **Step 3:** Reopen confirmed legacy terminal runs at first assurance with empty assurance
  evidence and no inferred attestation.
- [x] **Step 4: Verify** — compare complete filesystem snapshots across second apply and terminal
  refusal/confirmation cases; expect zero second-apply changes and exact reopen semantics.

### Task 12: Complete the versioned doctor/migration corpus

**Files:**
- Create: `integrity/testdata/migration/v1/**`
- Create: `scripts/check-integrity-wp2-conformance.sh`

**Covers:** AC16

- [x] **Step 1:** Add X-LOSSLESS, X-IDEMPOTENT, X-AMBIGUOUS, X-POINTER, X-POINTER-DRIFT,
  X-LEGACY-DONE, X-PREVIEW-NOWRITE, and X-POLICY-EQUIVALENCE.
- [x] **Step 2:** Add Unix/Windows lexical, capability, publication, and recovery expectations.
- [x] **Step 3:** Validate every typed JSON output against its schema and every expected result
  against catalogue codes.
- [x] **Step 4: Verify** — run the full WP2 conformance script; expect all required scenario IDs,
  platform variants, and policy-equivalence assertions to pass.

### Task 13: Expose and package the explicit native CLI

**Files:**
- Create: `cmd/ff-integrity/main.go`
- Create: `cmd/ff-integrity/main_test.go`
- Modify: `scripts/build-integrity-packages.sh`
- Modify: `scripts/package-codex-plugin.sh`
- Modify: `scripts/check-integrity-package-conformance.sh`
- Modify: `scripts/checks/integrity-boundary-guard.sh`
- Modify: `.github/workflows/integrity.yml`

**Covers:** AC15

- [x] **Step 1:** Implement strict doctor/migrate subcommands, mutually exclusive modes, formats,
  plan-digest binding, terminal confirmation, and 0/1/2 exits.
- [x] **Step 2:** Compose `ff-integrity` and approved schemas/catalogue/smoke corpus into complete
  Claude and Codex packages without Go/test leakage.
- [x] **Step 3:** Extend the boundary guard to allow explicit invocation while proving no current
  command, hook, status, resume, or phase activation.
- [→] **Step 4:** Run source/Claude/Codex package parity natively for every declared target and
  refresh support evidence only from the exact commit.
- [→] **Step 5: Verify** — run package conformance and the native matrix; expect all six targets to
  execute complete packages with identical classifications, diagnoses, and preview/apply results.

### Task 14: Run compatibility and full regression validation

**Files:**
- Modify: `docs/integrity-protocol-v1.md`
- Create: `docs/integrity/wp2-operations.md`
- Modify: `README.md`
- Verify: all existing classifier, command/hook, guard, evaluation, and manifest compatibility
  surfaces

**Covers:** AC17

- [x] **Step 1:** Document explicit doctor/preview/apply behavior, reviewed-plan binding, bootstrap
  limits, retention, recovery, and stable exit classes without suggesting automatic activation.
- [x] **Step 2:** Run all Go tests, schema/catalogue checks, shell guards, evaluations, package
  checks, and unchanged WP1 vectors.
- [x] **Step 3:** Verify the user-owned `docs/feature-flow-v2-enhancement-plan.md` remains
  byte-identical and no unrelated working-tree file changed.
- [x] **Step 4: Verify** — execute the repository's complete detected validation surface; expect
  all commands to exit 0 and every authorized write to remain confined to disposable apply fixtures.

## Dependency graph

| Task | Depends on |
|------|------------|
| Task 1 | — (root) |
| Task 2 | — (root) |
| Task 3 | Task 1, Task 2 |
| Task 4 | Task 3 |
| Task 5 | — (root) |
| Task 6 | Task 5 |
| Task 7 | Task 5 |
| Task 8 | Task 3 |
| Task 9 | Task 2, Task 4, Task 8 |
| Task 10 | Task 9 |
| Task 11 | Task 9 |
| Task 12 | Task 3, Task 10, Task 11 |
| Task 13 | Task 3, Task 5 |
| Task 14 | Task 12, Task 13 |

## Critical path

**Path:** Task 2 → Task 3 → Task 4 → Task 9 → Task 10 → Task 12 → Task 14

The path is derived from the dependency graph. At equal-depth forks, the deterministic tie-break
selects Task 4 over Task 8 and Task 10 over Task 11; Task 2 has more step items than Task 1.

## Risk register

| Risk | Likelihood | Impact | Mitigation |
|------|-----------|--------|-----------|
| An inventoried family hides a behavior-significant variant | Med | High | Behavior-aware fingerprints, disjoint matchers, explicit unsupported outcomes, ambiguity refusal |
| Shared parsing/diagnostic extraction changes WP1 bytes | Med | High | Run unchanged byte-golden source/package vectors immediately after extraction and at final regression |
| Pointer identity changes after review | Med | High | Canonical plan digest plus immediate apply-time pointer re-observation |
| Bootstrap state is mistaken for revision authority | Low | High | Namespaced bootstrap algorithms, unsupported revision, semantic ready-state rejection |
| Platform/filesystem atomicity is weaker than assumed | Med | High | Native capability preflight, platform-specific implementation, no unsafe fallback |
| Snapshot contains sensitive legacy content | Med | High | Exact evidence retained locally, restrictive creation where supported, no bytes/absolute paths in reports |
| Snapshot publishes but manifest replace/cleanup fails | Low | Med | Preserve canonical legacy bytes, owned cleanup, stable orphan recovery diagnostic |
| Package support evidence becomes stale after binary changes | High | Med | Fresh exact-commit complete-package native execution on every declared target |
| WP2 is accidentally activated by existing lifecycle commands | Low | High | Negative boundary guard and explicit no-command/hook modifications |

## Rollback plan

| Task | Recovery action if `Step N: Verify` fails |
|------|--------------------------------------------|
| Task 1 | Revert only new inventory/registry files to the prior task checkpoint; retain generated evidence outside tracked output for diagnosis. |
| Task 2 | Restore the classifier compatibility adapter and shared packages to the prior task checkpoint; rerun WP1 goldens before continuing. |
| Task 3 | Revert planner/profile/schema additions to the prior task checkpoint; no runtime write path exists yet. |
| Task 4 | Revert bootstrap/validation additions; keep Task 3 pure planner state. |
| Task 5 | Revert doctor typed-policy additions; classifier remains independently usable. |
| Task 6 | Revert renderers only; retain typed result tests for repair. |
| Task 7 | Revert harness/fixtures only; doctor production code remains untouched. |
| Task 8 | Revert storage preflight/revalidation additions; no publisher is available yet. |
| Task 9 | Disable/remove the new CLI apply composition and revert publisher files to the prior task checkpoint; never repair a failed fixture in place. |
| Task 10 | Revert failure/recovery changes to the Task 9 checkpoint and discard only disposable test roots. |
| Task 11 | Revert idempotence/terminal policy changes to the Task 10 checkpoint; discard only disposable test roots. |
| Task 12 | Revert corpus/runner additions only; retain production code for focused diagnosis. |
| Task 13 | Restore prior package scripts/workflow and remove only generated package output, not source artifacts. |
| Task 14 | Revert documentation-only changes; production rollback follows the first failing task's recovery row. |

## Status conventions

Stateful document. After each task bump its status:
`[ ]` pending · `[~]` in progress · `[x]` done · `[!]` blocked · `[→]` deferred.

**Status summary:** 14/14 implementation tasks complete. Task 13 native-matrix evidence and
exact-commit support refresh are deferred to `/feature-flow:ff-verify`; Linux x86_64 complete-package
execution is already captured locally, and all six runner cells remain configured.

## Blockers

- Verification handoff: five non-local native target executions and exact-commit support-evidence
  refresh require the configured GitHub Actions runners.

## Decisions made during execution

- Option C selected by user: pragmatic layered architecture with mandatory reviewed-plan digest
  binding.
- The host had no Go toolchain, so implementation tests ran in the official `golang:1.26.5`
  container. Linux x86_64 complete packages executed natively; Windows amd64/arm64 were
  cross-compiled only and were not treated as support evidence.
