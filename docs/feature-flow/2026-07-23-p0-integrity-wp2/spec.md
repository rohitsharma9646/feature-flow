# Spec: P0 Integrity WP2 — read-only doctor and explicit legacy migration

**Created:** 2026-07-23
**Track:** feature
**Status:** signed-off

## Problem

Feature Flow can classify manifest bytes, but users still lack a safe way to inspect the integrity
of one run or an entire run root and to convert supported legacy manifests into the canonical v1
shape. Existing prose-level recovery can infer and rewrite state, which risks changing evidence,
guessing behavior, or turning an ambiguous legacy run into an apparently valid one.

The underlying need is an evidence-preserving operational boundary: diagnosis must be provably
read-only, and migration must be explicit, reviewable before mutation, lossless, deterministic, and
safe to retry or recover after failure.

## Expected outcome

Users can invoke a packaged native integrity CLI to diagnose one run or all runs in human or JSON
form without changing the workspace. They can preview migration of every explicitly registered
legacy family and apply the exact reviewed plan only through an explicit command. Ambiguous,
corrupt, unsupported, or changed inputs are refused without altering the source. Successful
migration retains the original bytes, produces a structurally and semantically valid v1 manifest,
and is idempotent.

## Solution approaches considered

- **Chosen — explicit native doctor plus preview/apply migration in WP2:** directly satisfies the
  inspection and evidence-preserving conversion need while keeping all automatic lifecycle
  integration deferred until the integrity boundary is proven.
- **Rejected — doctor only, migration in a later work package:** lowers immediate implementation
  scope but leaves users with diagnosis and no safe, supported recovery path.
- **Rejected — internal libraries without a user-invocable CLI:** creates reusable internals but
  does not provide the explicit operational interface needed to inspect and migrate real runs.

## Assumptions (WHAT-changing)

| Statement | Confidence | Basis / evidence | If-wrong impact | Validation-required |
|---|---|---|---|---|
| WP2 is intentionally user-invocable only; automatic status, resume, phase, and hook integration remains WP4 scope. | high | Accepted recommendation and the approved WP2 RFC boundary. | WP2 scope and its compatibility contract would expand to lifecycle mutation and activation behavior. | n |
| “Every known legacy family” means every distinct pre-v1 family discovered by an explicit inventory of repository history and committed dogfood fixtures during this work package. | high | Accepted recommendation converted into a finite, auditable discovery boundary. | The migration support matrix and corpus would need a broader external source of historical manifests. | n |

## Constraints

- Preserve the WP1 raw-bytes classifier as a pure, operation-independent structural boundary with
  unchanged classifications and diagnostics.
- Doctor is strictly read-only: no file or directory writes, lock creation, timestamp changes,
  Git/index mutation, project-command execution, or network access.
- Migration is opt-in only. Preview performs no writes; apply requires an explicit `--apply`.
- A legacy terminal run requires both `--apply` and `--confirm-reopen-terminal`.
- Unknown behavior-affecting fields must cause refusal. No field that could alter run behavior may
  be guessed, dropped, or silently defaulted.
- Original manifest bytes are retained in a content-addressed snapshot under the run's
  `migration/` area, with restrictive permissions wherever the platform supports them.
- WP2 may create an honest pre-WP3 bootstrap state but must not fabricate a ready or authoritative
  code revision.
- Human and JSON output are two renderings of the same typed result and must not expose raw host
  errors or untrusted absolute paths.
- The CLI must ship in complete Claude and Codex packages across every declared native target.
- Existing Feature Flow commands and hooks must retain their current behavior; automatic doctor or
  migration activation is out of scope.

## Edge cases

- An empty run root produces a clean, deterministic `doctor --all` result and no filesystem change.
- A current valid v1 manifest is diagnosed as current and migration is a zero-write no-op.
- A corrupt, future-version, current-invalid, or unsupported-old manifest is diagnosis-only and is
  never treated as a migration candidate.
- An unversioned object matching no registered profile, or matching ambiguously, is refused.
- Repeated preview calls produce the same plan for unchanged source bytes.
- Repeated apply after a successful migration changes no bytes, entries, timestamps, or migration
  inventory.
- A manifest or referenced pointer that changes between planning and apply is refused.
- Absolute, traversal, drive/UNC, and symlink-escaping pointers are refused; equivalent contained
  pointer spellings resolve consistently.
- Apply failure before publication preserves the source and reports whether cleanup succeeded; it
  never exposes a partially written canonical manifest.
- A legacy `done` run without the dedicated reopen confirmation is refused without writes.
- Duplicate or conflicting CLI modes are invocation errors and perform no observation-side
  mutation.

## Non-goals

- Automatic invocation from status, list, resume, phase transitions, hooks, or session start.
- Silent, opportunistic, or on-read migration.
- Repair of corrupt, future-version, current-invalid, or unknown legacy manifests.
- Authoritative CodeRevision observation or target promotion, which belongs to WP3.
- Changing WP1 classifier corpus semantics or reclassifying operation-specific policy as structural
  byte classification.
- Remote migration, network-backed run storage, recursive run discovery, or following run-directory
  symlinks.
- Deleting legacy snapshots or providing migration rollback automation beyond retaining evidence and
  reporting recovery information.

## Acceptance criteria

- [ ] AC1: An executed legacy-profile inventory identifies every distinct pre-v1 manifest family present in repository history and committed dogfood fixtures, and each identified family has exactly one registered typed mapping or an explicit unsupported rationale.
- [ ] AC2: `ff-integrity doctor <slug>` and `ff-integrity doctor --all`, each with `--format human` or `--format json`, render the same typed conclusions and diagnostic codes in deterministic run and diagnostic order, with exit 0 for clean results, exit 1 for diagnosed blocking integrity, and exit 2 for invocation, I/O, or observation failure.
- [ ] AC3: For every doctor classification and error fixture, an executed immutability check confirms unchanged file bytes, directory entries, modification times, lock inventory, migration inventory, and Git/index state, and confirms no project command or network invocation.
- [ ] AC4: For a registered legacy manifest, migration preview emits a deterministic plan containing the source digest, selected profile, proposed transformations, preserved evidence, validation outcome, and required confirmations, while creating or changing no filesystem entry.
- [ ] AC5: Preview and apply use the same plan semantics, and apply refuses before writing when the source digest, selected legacy profile, or any observed pointer fact differs from the reviewed plan.
- [ ] AC6: A legacy object with an unknown behavior-affecting field, ambiguous profile match, or unrepresentable behavior is refused with a stable diagnostic; allowlisted inert metadata is retained through migration provenance rather than silently discarded.
- [ ] AC7: Artifact pointers are resolved only from trusted roots; absolute, traversal, drive/UNC, and symlink-escaping paths are refused, while equivalent contained pointer spellings produce the same observation and migration decision.
- [ ] AC8: Every accepted migration proposal is validated as a canonical v1 manifest, carries honest repository/worktree and baseline/scope facts, records revision status as unsupported until WP3 can establish it, and never represents revision readiness without evidence.
- [ ] AC9: `migrate --apply` revalidates the reviewed plan, retains the exact original manifest bytes in a content-addressed snapshot under `<run>/migration/`, applies restrictive snapshot permissions where supported, and publishes only a fully validated canonical manifest through an atomic replacement capability.
- [ ] AC10: Under injected failure at every apply boundary, the original manifest remains readable and unchanged until successful publication, no partial canonical manifest is visible, and temporary or orphaned artifacts are either removed or reported with stable recovery diagnostics.
- [ ] AC11: Applying migration a second time to an already migrated run is a successful zero-write no-op that changes no bytes, directory entries, modification times, or migration inventory and retains the original provenance.
- [ ] AC12: Migrating a legacy terminal run without `--confirm-reopen-terminal` is refused without writes; with `--apply --confirm-reopen-terminal`, the v1 result reopens at the first assurance phase with empty assurance evidence and no fabricated attestations.
- [ ] AC13: Corrupt, future-version, current-invalid, unsupported-old, and unknown-profile manifests are diagnosis-only and produce no migration writes; a valid current v1 manifest reports an already-current zero-write result.
- [ ] AC14: Human and JSON renderers expose stable catalogue diagnostics from one typed result, exclude raw OS error strings and untrusted absolute paths, and preserve machine-readable distinctions among clean, blocking-integrity, invocation, I/O, and observation outcomes.
- [ ] AC15: Complete Claude and Codex packages contain the directly invocable native doctor/migrate CLI for all six declared native targets, pass package-conformance and native execution checks, and do not activate doctor or migration through existing commands, hooks, status, or resume behavior.
- [ ] AC16: Versioned doctor and migration corpora cover `X-LOSSLESS`, `X-IDEMPOTENT`, `X-AMBIGUOUS`, `X-POINTER`, `X-POINTER-DRIFT`, `X-LEGACY-DONE`, `X-PREVIEW-NOWRITE`, and `X-POLICY-EQUIVALENCE`, including Unix and Windows replacement-capability behavior.
- [ ] AC17: Existing classifier vectors, command/hook behavior, guard suites, evaluation suites, and manifest compatibility tests pass unchanged except for writes performed inside explicit disposable `migrate --apply` fixtures.

## Success metrics

- [ ] SM1: Registered mapping or explicit unsupported rationale coverage = 100% of legacy families found by the AC1 inventory, measured by the generated legacy-profile inventory check.
- [ ] SM2: Doctor mutation count = 0 across 100% of doctor corpus cases, measured by the AC3 before/after immutability harness.
- [ ] SM3: Original-byte loss and partial canonical publication count = 0 across 100% of injected apply-failure points, measured by the storage failure-injection suite.
- [ ] SM4: Second-apply filesystem changes = 0 across 100% of successful migration corpus cases, measured by byte, entry, modification-time, and migration-inventory snapshots.
- [ ] SM5: Native package execution pass rate = 100% across all six targets declared in `release/targets.json`, measured by the native package matrix.

## Requirement graph

| AC | Depends on |
|----|------------|
| AC1 | — (root) |
| AC2 | — (root) |
| AC3 | AC2 |
| AC4 | AC1 |
| AC5 | AC4 |
| AC6 | AC1 |
| AC7 | — (root) |
| AC8 | AC4 |
| AC9 | AC5, AC7, AC8 |
| AC10 | AC9 |
| AC11 | AC9 |
| AC12 | AC9 |
| AC13 | AC1 |
| AC14 | AC2 |
| AC15 | AC2, AC4 |
| AC16 | AC10, AC11, AC12, AC13 |
| AC17 | AC15, AC16 |

## Sign-off

**User signed off:** yes (2026-07-23)

> A spec without sign-off does not proceed to **design, planning, or implementation** —
> `/feature-flow:ff-design`, `/feature-flow:ff-plan`, and `/feature-flow:ff-implement` each stop and
> route back to `/feature-flow:ff-clarify` if this reads `no` (implement is the hard backstop). A
> waived review is recorded explicitly: "sign-off waived by user (date)" — never assumed.
