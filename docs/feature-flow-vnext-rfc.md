# Feature Flow vNext RFC: P0 Integrity Foundation

| Field | Value |
|---|---|
| Status | Proposed for P0 implementation |
| Date | 2026-07-23 |
| Owner | Feature Flow maintainers |
| Decision authority | Repository maintainers, with user sign-off for compatibility-policy changes |
| Framework baseline | Feature Flow v0.17.0 at repository commit `6c52d49` |
| Protocol baseline | Manifest Schema v1; Integrity Protocol v1 |
| Local signed specification | `docs/feature-flow/2026-07-23-p0-integrity-foundation-rfc/spec.md` |
| Architectural evidence | `docs/feature-flow-architectural-review-2026-07-23.md` |

## Document authority and relationship to prior work

This RFC is the canonical proposal for Feature Flow's P0 integrity semantics. It translates the
critical findings in the 2026-07-23 architectural review into executable contracts and an ordered
implementation program.

The existing `docs/feature-flow-v2-enhancement-plan.md` is preserved unchanged. It remains useful
historical context, but this RFC supersedes it wherever its assumptions conflict with:

- versioned executable manifest validation;
- explicit rather than silent legacy migration;
- deterministic code-revision identity;
- revision-bound assurance;
- mutation invalidation;
- one terminal convergence predicate;
- current Claude Code and Codex enforcement capabilities.

The signed specification controls **what** P0 must achieve. This RFC controls the proposed **how**.
If they conflict, the signed specification wins and this RFC must be amended. This repository
intentionally ignores `docs/feature-flow/` as author-local dogfood; consequently, this RFC is
self-contained and does not require the local signed artifact to be present in a packaged or
reviewed copy.

### Normative language

The terms **MUST**, **MUST NOT**, **SHOULD**, **SHOULD NOT**, and **MAY** are normative:

- **MUST / MUST NOT:** required for protocol conformance.
- **SHOULD / SHOULD NOT:** expected unless a documented, evidence-backed exception applies.
- **MAY:** optional behavior that cannot weaken a MUST.

Examples and suggested file paths are non-normative unless explicitly labelled normative.

## 1. Scope

P0 establishes the minimum deterministic integrity layer needed to trust Feature Flow completion.
It defines:

1. Manifest Schema v1 and state classification.
2. Validation before Feature Flow state-changing transitions.
3. Explicit, evidence-preserving migration of legacy manifests.
4. Deterministic code-revision identity over declared repository state.
5. Typed, revision-bound review and verification attestations.
6. Invalidation at every code-mutation boundary.
7. One terminal predicate shared by all feature and bugfix completion paths.
8. A strictly read-only `ff doctor`.
9. Host-neutral policy with Claude Code and Codex adapters.
10. Behavioral fixtures, staged rollout, rollback, and traceability.

### 1.1 Non-goals

P0 does not:

- replace `manifest.json` with an event log or a second canonical state file;
- implement the complete `ffctl` workflow engine;
- solve compare-and-swap writes, distributed locks, or multi-user coordination;
- redesign phase vocabulary;
- redesign the knowledge base, agent orchestration, telemetry, or run archival;
- build the Verification Loop Registry;
- choose the shared integrity runtime language in this RFC;
- retrospectively claim that legacy completion was revision-bound;
- automatically repair ambiguous or corrupt state.

The implementation MUST produce one shared integrity kernel. Runtime-language selection occurs at
the entry to WP1 using the supported-host capability matrix in section 17.

## 2. Normative glossary

This is the sole normative vocabulary for P0.

| Term | Definition |
|---|---|
| **Manifest** | `.feature-flow/<slug>/manifest.json`, the sole canonical mutable state object for one run. |
| **Manifest v1** | A manifest with `schemaVersion: 1` that passes structural and semantic validation. |
| **Legacy manifest** | A readable manifest with no `schemaVersion`; classified as version 0 for diagnosis only. |
| **Unsupported-future manifest** | A readable manifest whose `schemaVersion` is greater than the highest version understood by the running kernel. |
| **Corrupt manifest** | Bytes that cannot be decoded as a JSON object. |
| **Current-structural-invalid manifest** | A manifest claiming a supported schema version but failing its structural schema. Semantic and transition failures are separate diagnostics, not manifest classes. |
| **Transition** | A proposed change to Feature Flow canonical state, including phase, signoff, artifact, revision, assurance, migration, or terminal state. |
| **State-changing transition** | A transition that writes canonical run state. Status and doctor are not state-changing. |
| **Mutation boundary** | An operation allowed to change repository code: implementation, review repair, or verification repair. |
| **Declared revision scope** | The normalized set of tracked paths, explicitly admitted untracked paths, and declared exclusions whose classification is part of the revision descriptor. |
| **CodeRevision** | A deterministic, versioned digest of the repository identity, baseline, declared scope, and current scoped repository state. |
| **Attestation** | A typed review or verification result bound to exactly one CodeRevision and evidence set. |
| **Passing attestation** | A valid `passed` attestation whose revision equals the current supported CodeRevision. |
| **Stale attestation** | An attestation whose recorded revision differs from the observed current CodeRevision, regardless of its stored status. |
| **Invalidated attestation** | A prior result retained as evidence but explicitly disqualified after a changed mutation boundary. |
| **Convergence** | The state in which passing review and verification attestations reference the same current CodeRevision. |
| **Terminal predicate** | The single host-neutral policy deciding whether a transition into `done` is allowed. |
| **Doctor** | A read-only diagnostic operation that classifies and validates runs without changing contents, directory entries, mtimes, locks, index state, or implementation-controlled metadata. OS-induced atime changes are outside the portable guarantee. |
| **Migration** | An explicit state-changing operation that projects a known legacy manifest into Manifest v1 while preserving source evidence and provenance. |
| **Host adapter** | Thin Claude Code, Codex, CLI, or CI transport that invokes the shared integrity policy without reimplementing it. |

## 3. Authoritative P0 invariants

Every later contract references these IDs.

- **I1 — Single state authority.** `manifest.json` MUST remain the sole canonical run-state object.
  Derived status, doctor output, Markdown, and future events cannot compete with it in P0.
- **I2 — Single artifact authority.** `manifest.artifacts.<name>` MUST remain the sole locator for
  an artifact. `phases.<phase>.artifact` is a validated display mirror only.
- **I3 — Version before mutation.** Every newly created manifest and every manifest accepted for a
  state-changing transition MUST be a structurally and semantically valid Manifest v1.
- **I4 — Explicit migration.** A legacy manifest MAY be read by status and doctor but MUST NOT
  mutate until the user invokes explicit, evidence-preserving migration. Status and doctor MUST
  NOT trigger migration.
- **I5 — No guessed repair.** Corrupt, unsupported-future, current-invalid, or ambiguous legacy
  state MUST NOT be silently coerced into current state.
- **I6 — Deterministic revision.** The same algorithm version and declared repository inputs MUST
  produce the same non-empty CodeRevision; unsupported observation MUST never produce a constant
  or empty fallback digest.
- **I7 — Explicit ownership.** Pre-existing dirty state and untracked files MUST be classified as
  included or excluded before assurance. Feature Flow MUST NOT silently claim unrelated user work.
- **I8 — Revision-bound assurance.** Review and verification results MUST be typed attestations
  naming their exact CodeRevision, producer, time, and evidence.
- **I9 — Mutation invalidates assurance.** If any mutation boundary changes the CodeRevision, both
  review and verification attestations MUST become invalid before completion is reconsidered.
- **I10 — No-op stability.** A mutation boundary that produces the same CodeRevision MUST NOT
  manufacture a new revision or invalidate otherwise valid assurance solely because an attempt ran.
- **I11 — One terminal predicate.** Feature terminal verification, normal bugfix terminal review,
  and reverse-order bugfix convergence MUST all invoke the same terminal predicate.
- **I12 — Evidence is not presence.** Artifact existence, a Markdown heading, or a textual status
  token MUST NOT substitute for a valid attestation and its evidence references.
- **I13 — Doctor never writes.** Doctor MUST be observationally read-only, including on legacy,
  corrupt, unsupported, locked, or migratable runs.
- **I14 — One policy, thin adapters.** Every supported host MUST consume the same integrity
  decisions and diagnostic codes. Unrelated host writes MUST remain outside Feature Flow policy.

## 4. Contract-first integrity kernel

P0 defines one logical kernel boundary without choosing its implementation language.

### 4.1 Required policy operations

```text
classifyManifest(rawBytes) -> ManifestClass

validateManifest(
  manifest,
  observedArtifactFacts?,
  observedRepositoryFacts?
) -> ValidationResult

planMigration(
  legacyBytes,
  observedArtifactFacts
) -> MigrationPlan | Diagnostics

computeCodeRevision(
  repositoryFacts,
  declaredScope
) -> RevisionResult

recordAttestation(
  manifest,
  kind,
  revision,
  result,
  producer,
  evidenceRefs
) -> ProposedManifest | Diagnostics

afterMutation(
  manifestBefore,
  revisionBefore,
  revisionAfter,
  reason
) -> ProposedManifest | Diagnostics

authorizeTransition(
  currentManifestBytes,
  proposedManifestBytes,
  observedFacts
) -> Allow | Deny(diagnostics)

diagnose(
  rawManifestBytes,
  observedFacts
) -> DoctorRunResult
```

The actual function names MAY differ. Their behavior and shared fixture results MUST not.

### 4.2 Purity boundary

Classification, structural validation, semantic predicates, invalidation rules, terminal policy,
and diagnostic generation SHOULD be pure functions.

Repository observation, artifact resolution, migration writes, and host transport are effectful
adapters. An adapter MUST NOT recreate a policy rule already owned by the kernel.

### 4.3 Structural versus semantic validation

JSON Schema validates:

- object shape;
- required fields;
- field types;
- enums;
- format-constrained strings;
- conditional track/tier fields;
- closed integrity-owned objects where compatibility allows.

Kernel semantic validation handles facts JSON Schema cannot prove:

- canonical artifact pointer resolution;
- pointer/display-mirror equality;
- artifact existence and evidence references;
- repository and worktree observation;
- current revision recomputation;
- attestation freshness;
- terminal convergence;
- migration pointer equivalence;
- lock freshness warnings;
- transition legality.

Passing structural validation alone is never sufficient for a state-changing transition.

## 5. Manifest state classification

Classification occurs before any state-changing Feature Flow action. It depends only on JSON
parseability, the schema-version discriminator, and structural schema validity. It MUST NOT depend
on the requested operation, repository facts, artifact facts, terminal policy, or another semantic
validator. This keeps classification stable and non-recursive.

| Class | Recognition | Status/doctor | Migration | State-changing transition |
|---|---|---|---|---|
| `CURRENT_STRUCTURAL_VALID` | `schemaVersion: 1`; structural schema passes | allowed, with separate semantic diagnostics | no-op | allowed only when semantic and transition policy also pass |
| `LEGACY_UNVERSIONED` | JSON object; `schemaVersion` absent | allowed with diagnostic | explicit only | denied |
| `UNSUPPORTED_FUTURE` | integer `schemaVersion > 1` | allowed for raw metadata and diagnostics | denied by older kernel | denied |
| `CORRUPT` | invalid JSON or non-object JSON | diagnostic only | denied | denied |
| `CURRENT_STRUCTURAL_INVALID` | `schemaVersion: 1` but structural checks fail | allowed with diagnostics | repair requires a separately authorized recovery procedure | denied |
| `UNSUPPORTED_OLD` | explicit version lower than 1 with no registered migration | allowed with diagnostic | denied until a migration exists | denied |

Classification MUST be stable and MUST NOT mutate bytes, timestamps, locks, or artifacts.
Semantic validation and transition authorization consume a structurally valid class and return
their own diagnostics without reclassifying it.

## 6. Manifest Schema v1

### 6.1 Normative outline

The implementation MUST publish an executable JSON Schema, expected at
`schemas/manifest-v1.schema.json`. The following is its normative semantic outline; exact `$defs`
layout is an implementation detail.

```json
{
  "schemaVersion": 1,
  "slug": "p0-integrity-foundation-rfc",
  "runId": "stable globally unique run identifier",
  "track": "feature",
  "tier": "full",
  "createdAt": "2026-07-23T09:54:19Z",
  "updatedAt": "2026-07-23T10:00:00Z",
  "closedAt": null,
  "autopilot": true,
  "currentPhase": "review",
  "phases": {
    "explore": {
      "status": "complete",
      "artifact": "explore.md"
    }
  },
  "signOff": {
    "required": true,
    "signed": true,
    "date": "2026-07-23",
    "actor": {
      "kind": "user",
      "id": "conversation-local identity or null"
    },
    "evidenceRef": "artifact:spec"
  },
  "lock": null,
  "artifacts": {
    "spec": "docs/feature-flow/.../spec.md",
    "review": "docs/feature-flow/.../review.md",
    "verify": "docs/feature-flow/.../verify.md"
  },
  "code": {
    "baseline": {
      "repositoryKind": "git",
      "repositoryIdentity": "stable repository identity",
      "worktreeIdentity": "stable worktree identity",
      "head": "commit sha",
      "startSnapshotDigest": "sha256:..."
    },
    "scope": {
      "trackedPaths": ["commands/ff-review.md"],
      "includedUntrackedPaths": [],
      "exclusions": [
        {
          "path": "unrelated-user-file.md",
          "reason": "pre-existing user work",
          "baselineStateDigest": "sha256:..."
        }
      ]
    },
    "revision": {
      "status": "ready",
      "algorithm": "ff-code-revision-v1",
      "id": "ffr1:<hex>",
      "computedAt": "2026-07-23T10:00:00Z"
    }
  },
  "assurance": {
    "review": null,
    "verification": null
  },
  "migration": null
}
```

### 6.2 Existing field rules retained

- `track`: `feature | bugfix`.
- `tier`: `full | lite`.
- `currentPhase`: existing phase vocabulary plus `done | abandoned`.
- phase status: `pending | in_progress | complete`.
- `artifacts.<name>` remains authoritative under I2.
- `phases.<phase>.artifact` remains a display mirror.
- existing signoff and autopilot behavior remains unless this RFC explicitly strengthens it.
- the existing advisory lock shape remains valid but P0 does not make it transactional.

### 6.3 New required identity

- `schemaVersion` MUST equal `1`.
- `runId` MUST be stable and globally unique after creation.
- `slug` remains human-readable and MAY collide across repositories; `runId` cannot.
- a migrated run receives one new stable `runId`, recorded in migration provenance.

### 6.4 Artifact pointer containment

Artifact and evidence pointers are untrusted manifest data. Before existence checks, reads,
migration comparison, doctor inspection, or attestation validation, the resolver MUST:

1. reject an empty pointer;
2. reject a pointer containing a `..` path component;
3. reject absolute pointers unless they are produced from an explicitly trusted configured root
   and represented through that root's logical identifier;
4. normalize separators and resolve the pointer relative to its approved logical root;
5. verify lexical containment under the approved root;
6. for an existing target or parent, verify realpath containment so a repository symlink cannot
   escape the root;
7. refuse to follow a final symlink when the artifact type does not explicitly permit one.

Approved roots are the repository root, the run directory, and configured durable/evidence roots
resolved from trusted project configuration. A raw manifest cannot add an approved root.

Any escape emits `FFI_ARTIFACT_PATH_ESCAPE`. Doctor reports the diagnostic without reading the
escaped target. Migration and transitions fail closed. Fixtures MUST cover absolute paths, `..`,
intermediate symlink escape, final symlink escape, and a valid in-root symlink policy case.

### 6.5 Artifact mirror invariant

When a phase has a logical output:

```text
phases.<phase>.artifact == artifacts.<logicalName>
```

after path normalization. If one side is absent when the phase is incomplete, no mismatch exists.
If a complete phase has both and they differ, emit `FFI_ARTIFACT_MIRROR_MISMATCH` and deny mutation.

The mirror never becomes a fallback locator.

### 6.6 Structural conditional rules

The executable schema MUST encode all conditions expressible without repository observation,
including:

- feature/full signoff fields;
- bugfix RED/GREEN fields where retained;
- allowed phase sets by track/tier;
- attestation shape;
- revision ready/unsupported alternatives;
- migration provenance shape;
- no unknown fields inside `code`, `assurance`, and `migration` unless a schema version allows them.

### 6.7 Semantic terminal consistency

A proposed transition into `currentPhase: done` MUST satisfy section 12. A current Manifest v1
persisted with `done` but lacking that predicate remains structurally classified as
`CURRENT_STRUCTURAL_VALID`; semantic validation diagnoses `FFI_TERMINAL_INCONSISTENT` and denies
every further state-changing transition. Classification never invokes the terminal predicate.

## 7. Legacy compatibility and explicit migration

### 7.1 Compatibility policy

Missing `schemaVersion` means legacy version 0 for classification only. It does not mean v1.

Status and doctor MAY:

- show existing fields;
- resolve known artifact pointers read-only;
- report inferred legacy phase information;
- identify whether a registered migration appears possible;
- produce a migration preview.

They MUST NOT:

- add `schemaVersion`;
- normalize statuses;
- repair mirrors;
- acquire or release a lock;
- update timestamps;
- rewrite an artifact;
- invoke migration.

Any state-changing phase on a legacy run is denied with
`FFI_LEGACY_MIGRATION_REQUIRED`.

### 7.2 Explicit interface

The RFC reserves this semantic operation:

```text
ff migrate <run> --to 1 [--dry-run | --apply]
```

Host spelling MAY differ, but dry-run and explicit apply MUST remain distinct. Apply requires user
authority because it changes canonical state.

### 7.3 Migration planning and validation

Dry-run and apply MUST begin with the same pure, no-write planning procedure:

1. Read the original bytes once.
2. Compute `sourceDigest = sha256(original bytes)`.
3. Classify the legacy shape against a registered v0 profile.
4. Refuse corrupt or ambiguous values rather than guessing.
5. Resolve every existing artifact pointer to a normalized target before transformation.
6. Project known fields into a proposed in-memory v1 object without changing user decisions,
   signoffs, waivers, evidence,
   timestamps, or canonical pointer meaning. Every behavior-affecting legacy field MUST have a
   registered typed v1 mapping.
7. Classify unknown legacy content:
   - an unknown field that can affect signoff, waiver, phase routing, evidence eligibility,
     completion, artifact selection, retry authority, or user decision semantics makes migration
     ambiguous and MUST abort with `FFI_MIGRATION_AMBIGUOUS`;
   - only demonstrably inert metadata MAY remain solely in the immutable source snapshot, with its
     JSON pointer listed in migration provenance.
8. Resolve every proposed artifact pointer and prove target equivalence with step 5.
9. Validate the proposed v1 manifest structurally and semantically.
10. Return the full plan, diagnostics, proposed manifest, source digest, and pointer comparison.

Dry-run ends here. It MUST create no snapshot, directory, temporary file, lock, or timestamp
change.

### 7.4 Migration apply

Only after the no-write plan succeeds and the user explicitly authorizes apply may the migrator:

1. Re-read the original bytes and require the same `sourceDigest`; otherwise abort because the
   plan is stale.
2. Create a lossless source snapshot under the run's migration evidence directory using a
   temporary name.
3. Add migration provenance to the already-validated proposed manifest:

```json
{
  "migration": {
    "from": "legacy-unversioned",
    "to": 1,
    "sourceDigest": "sha256:...",
    "sourceSnapshot": "migration/manifest-v0-<digest>.json",
    "migratorVersion": "integrity-protocol-v1",
    "migratedAt": "ISO8601",
    "legacyUnknownPointers": [],
    "legacyTerminal": false
  }
}
```

4. Revalidate the final proposed manifest including provenance.
5. Write the proposed manifest to a temporary file and sync where supported.
6. Atomically publish the source snapshot.
7. Atomically replace the canonical manifest.
8. If canonical replacement fails, remove any newly published snapshot when safe; otherwise report
   the orphan explicitly without changing canonical state.

If any apply step before canonical replacement fails, canonical bytes MUST remain unchanged.
Planning failure leaves no filesystem residue.

Registered migration profiles MUST explicitly map at least signoff, autopilot, phase status,
closed/abandoned state, locks, bugfix RED/GREEN evidence, artifact pointers, decisions, retry
extensions, and every recognized waiver representation. Migration tests MUST prove that the same
post-migration policy decision is produced for each behavior-affecting fixture, not merely that
the original bytes remain archived.

### 7.5 Idempotence

Running the same migration again on the resulting v1 manifest MUST:

- return `already-current`;
- perform no write;
- leave all file contents and modification times unchanged;
- retain the original source digest and migration time;
- never create a second source snapshot.

### 7.6 Legacy terminal runs

A legacy `done` claim cannot become a fresh v1 `done` claim without current revision-bound
assurance.

Migration of a legacy terminal run MUST:

- identify `migration.legacyTerminal: true`;
- preserve the original terminal claim in the source snapshot and migration report;
- preview that the active run will reopen at its track's first assurance phase;
- require explicit confirmation of that semantic change;
- create empty current assurance records;
- require fresh review and verification convergence before v1 `done`.

Migration MUST NOT fabricate attestations from historical Markdown.

## 8. Declared revision scope

### 8.1 Goal

CodeRevision identifies exactly the repository state Feature Flow reviewed and verified without
silently claiming unrelated dirty user work.

### 8.2 Baseline

At run start, or before the first P0-aware mutation on a migrated run, capture:

- repository kind;
- stable repository identity;
- stable worktree identity;
- baseline HEAD;
- branch as informational metadata;
- normalized status and per-path baseline fingerprints of tracked, staged, unstaged, deleted,
  renamed, symlink, and untracked paths;
- `startSnapshotDigest` of that classification.

Branch name and capture timestamps are not revision-hash inputs.

The baseline MUST retain enough per-path state to detect a second change to a path that was already
dirty when the run started: mode/type, index identity, worktree content digest or deletion marker,
and symlink target digest where applicable. An aggregate status or aggregate snapshot digest alone
is insufficient.

### 8.3 Scope classification

Every path changed relative to the baseline MUST be classified:

1. `trackedPaths`: run-owned tracked paths, including additions, modifications, deletions, and
   rename endpoints.
2. `includedUntrackedPaths`: untracked paths explicitly admitted as run-owned.
3. `exclusions`: paths deliberately excluded with a reason and their exact captured baseline-state
   fingerprint, normally pre-existing unrelated user work.

A changed path that is neither included nor excluded is scope drift. Scope drift:

- emits `FFI_REVISION_SCOPE_DRIFT`;
- blocks passing review, verification, and terminal transitions;
- requires explicit classification;
- cannot be waived by silently ignoring the file.

Every observation compares an excluded path to its captured baseline-state fingerprint. If it
changes again for any reason, it is scope drift until explicitly reclassified. If Feature Flow
itself changes an excluded path, the path MUST leave exclusions and enter scope.

### 8.4 Scope disclosure

Review and verification artifacts MUST display:

- included paths;
- included untracked paths;
- exclusions and reasons;
- any scope changes since the previous attestation.

An exclusion is a coverage limitation, not evidence that the excluded file is safe.

## 9. CodeRevision v1

### 9.1 Result shape

Ready result:

```json
{
  "status": "ready",
  "algorithm": "ff-code-revision-v1",
  "id": "ffr1:<64 lowercase hex characters>",
  "computedAt": "ISO8601"
}
```

Unsupported result:

```json
{
  "status": "unsupported",
  "algorithm": "ff-code-revision-v1",
  "id": null,
  "diagnostic": "FFI_REVISION_UNSUPPORTED"
}
```

An unsupported result cannot receive a passing attestation in P0.

### 9.2 Canonical descriptor

The digest input is a canonical UTF-8 serialization of:

```json
{
  "domain": "feature-flow-code-revision",
  "version": 1,
  "repositoryIdentity": "...",
  "worktreeIdentity": "...",
  "baselineHead": "...",
  "startSnapshotDigest": "...",
  "scope": {
    "trackedPaths": ["sorted"],
    "includedUntrackedPaths": ["sorted"],
    "exclusions": [
      {
        "path": "sorted",
        "reason": "normalized text",
        "baselineStateDigest": "sha256:..."
      }
    ]
  },
  "entries": [
    {
      "path": "repo/relative/posix/path",
      "kind": "file|symlink|deletion",
      "mode": "git-compatible mode",
      "baselineBlob": "git blob id or null",
      "indexBlob": "git blob id or null",
      "worktreeDigest": "sha256 of bytes or null",
      "symlinkTargetDigest": "sha256 or null"
    }
  ]
}
```

Serialization MUST define deterministic object-key ordering, array ordering, string encoding, and
path normalization. An implementation MAY use RFC 8785 canonical JSON or an equivalently specified
format, but golden vectors MUST pin the bytes.

`computedAt`, branch display name, absolute checkout path, and the final `id` MUST NOT enter the
digest.

### 9.3 Path and content rules

- Paths use normalized repository-relative POSIX separators.
- Entries sort bytewise by normalized path.
- File bytes are hashed without newline normalization.
- Symlink target bytes and mode are included; the target file's content is not followed.
- Deletion uses an explicit deletion marker.
- Rename is represented as deletion of the old path plus addition of the new path.
- Index and worktree states are both represented, so staged content differing from working-tree
  content cannot disappear.
- Explicit untracked content uses `worktreeDigest` and a null baseline/index blob.
- Manifest, run evidence, generated package output, and durable workflow artifacts are excluded
  only when the declared scope classifies them as workflow metadata rather than deliverable code.
  A documentation deliverable such as this RFC is run-owned and therefore included.

### 9.4 Pseudocode

```text
function computeCodeRevision(repo, scope):
    facts = observeGit(repo)
    if facts.gitUnavailable or facts.headUnavailable:
        return Unsupported(FFI_REVISION_UNSUPPORTED)

    changed = facts.changedPathsRelativeToPerPathBaseline(scope.baseline)
    stableExclusions = {
        p in scope.excludedPaths
        where facts.currentStateDigest(p) == scope.exclusionBaselineDigest(p)
    }
    unclassified = changed - scope.includedPaths - stableExclusions
    if unclassified is not empty:
        return Error(FFI_REVISION_SCOPE_DRIFT, sorted(unclassified))

    descriptor = {
        domain: "feature-flow-code-revision",
        version: 1,
        repositoryIdentity: facts.repositoryIdentity,
        worktreeIdentity: facts.worktreeIdentity,
        baselineHead: scope.baseline.head,
        startSnapshotDigest: scope.baseline.startSnapshotDigest,
        scope: canonicalScope(scope),
        entries: observeEntries(scope.includedPaths)
    }

    bytes = canonicalSerialize(descriptor)
    return Ready("ffr1:" + sha256(bytes))
```

### 9.5 Determinism

The behavioral corpus MUST prove:

- same repository, worktree, baseline, scope, index, and bytes produce the same ID;
- timestamps do not change the ID;
- a content, mode, index, symlink target, deletion, rename, untracked admission, exclusion, or
  scope change produces a different ID;
- a no-op repair preserves the ID;
- unclassified changes produce an error, not a digest;
- non-Git or missing identity produces unsupported, not an empty or constant digest.

## 10. Assurance attestations

### 10.1 Shape

`assurance.review` and `assurance.verification` are either `null` or:

```json
{
  "attestationId": "stable unique identifier",
  "kind": "review",
  "status": "passed",
  "codeRevision": "ffr1:...",
  "producer": {
    "kind": "agent|human|ci",
    "host": "claude-code|codex|ci|other",
    "id": "session, job, or actor identifier",
    "version": "optional producer version"
  },
  "recordedAt": "ISO8601",
  "artifact": "review",
  "evidenceRefs": ["evidence:review-finding-set"],
  "invalidation": null,
  "supersedes": null
}
```

Allowed statuses:

- `passed`
- `failed`
- `unavailable`

The stored status is the immutable result originally produced. It MUST NOT be rewritten from
`passed` to `invalidated`.

### 10.2 Pointer authority

`artifact` is a logical name such as `review` or `verify`. It resolves only through
`manifest.artifacts`. An attestation MUST NOT introduce a second filesystem path authority.

Evidence references MUST resolve through a registered evidence namespace or typed artifact
metadata defined by the implementation. Raw prose is not an attestation.

### 10.3 Recording authority

Only the shared integrity operation may record or replace an attestation in an authorized Feature
Flow transition. Host prompts propose inputs; they do not mint arbitrary passing state.

A passing attestation requires:

- a ready current CodeRevision;
- producer identity;
- recorded time;
- valid logical artifact reference;
- required evidence references;
- result-specific semantic validation;
- no unresolved scope drift;
- no blocking evidence gap under existing policy.

### 10.4 Invalidation

Effective validity has exactly one definition:

```text
effectivePass(attestation, observedRevision) =
    attestation.status == passed
    AND attestation.codeRevision == observedRevision.id
```

An optional invalidation annotation retains the immutable original status, revision, producer,
artifact, and evidence for audit:

```json
{
  "status": "passed",
  "codeRevision": "ffr1:old",
  "invalidation": {
    "reason": "implementation_change|review_repair|verification_repair|scope_change|observed_mismatch",
    "detectedAt": "ISO8601",
    "fromRevision": "ffr1:old",
    "toRevision": "ffr1:new"
  }
}
```

The annotation is not a second authorization state and MUST NOT be read to decide effective pass.
Even if it is absent after a crash, revision inequality makes the attestation stale. P0 stores the
latest attestation for each kind. Replaced artifacts and evidence MUST NOT be deleted as a side
effect of invalidation. Full event history and retention policy are deferred.

### 10.5 Freshness rule

An attestation is stale whenever:

```text
attestation.codeRevision != observedCurrentRevision.id
```

Stored `status: passed` cannot override this rule. Doctor and transition policy treat the result as
invalidated even if a crash prevented the manifest from being updated.

## 11. Mutation boundaries and invalidation

P0 recognizes exactly three mutation boundaries:

| Boundary | Current location | Required reason |
|---|---|---|
| Implementation | `commands/ff-implement.md` | `implementation_change` |
| Review repair | `commands/ff-review.md` | `review_repair` |
| Verification repair | `commands/ff-verify.md` | `verification_repair` |

Every boundary MUST use the same protocol:

```text
before = computeCodeRevision()
announce mutation boundary
perform scoped mutation
after = computeCodeRevision()

if after is error/unsupported:
    deny completion and emit diagnostic
else if before.id == after.id:
    preserve revision and otherwise-valid attestations
    record no-op outcome in the human artifact
else:
    set manifest.code.revision = after
    preserve each immutable attestation result
    derive assurance.review as stale and optionally annotate invalidation when present
    derive assurance.verification as stale and optionally annotate invalidation when present
    persist the new revision and audit annotations before attempting another completion transition
```

### 11.1 Crash reconciliation

Transactional mutation is not solved in P0. Safety comes from recomputation:

- before any attestation;
- before any transition into `done`;
- during doctor;
- on resume before a state-changing phase.

If observed revision and stored revision differ, emit `FFI_REVISION_MISMATCH`, treat both
attestations as stale, and deny completion. This fails safe after a crash between code mutation and
manifest update.

### 11.2 Scope change

Changing included or excluded paths changes the revision descriptor even if file bytes do not.
Scope changes therefore invalidate both attestations.

## 12. One terminal convergence predicate

Every requested transition into `done` invokes:

```text
isDoneEligible(currentManifest, proposedManifest, observedFacts):
    require class(proposedManifest) == CURRENT_STRUCTURAL_VALID
    require baseSemanticValidate(proposedManifest, observedFacts, excludingTerminalRule) passes
    require proposedManifest.currentPhase == done
    require proposed signoff and track/tier phase prerequisites satisfied
    require proposed artifact pointers, containment, and mirrors valid
    require revision observation status == ready
    require proposedManifest.code.revision.id == observedRevision.id
    require proposedManifest.assurance.review.status == passed
    require proposedManifest.assurance.verification.status == passed
    require proposedManifest.assurance.review.codeRevision == observedRevision.id
    require proposedManifest.assurance.verification.codeRevision == observedRevision.id
    require both attestation artifact/evidence references valid
    require no blocking unwaived evidence gaps
    return allow
```

Anything else returns deny with stable diagnostics.

`baseSemanticValidate` MUST NOT invoke `isDoneEligible`; it validates every semantic invariant
except the terminal rule exactly once. When doctor inspects an already-persisted `done` manifest,
it invokes the terminal predicate as a consistency check over that persisted manifest without
re-entering classification.

### 12.1 Route matrix

| Track/order | Current orchestration | Required P0 decision |
|---|---|---|
| Feature | implement → review → verify → done | terminal verify calls `isDoneEligible` |
| Bugfix normal | implement → verify → review → done | terminal review calls `isDoneEligible` |
| Bugfix reverse/recovery | implement → review → verify → done | terminal verify calls `isDoneEligible` |
| Any repaired route | either assurance phase mutates | changed revision invalidates both; fresh convergence required |

No route may implement a local substitute for the terminal predicate.

### 12.2 Relationship to existing Gate B

The current Gate B checks phase status, Markdown presence, a heading, and a textual status token.
Under P0:

- those checks MAY remain as diagnostic quality hints;
- they MUST NOT authorize `done`;
- the host hook MUST delegate terminal authorization to the shared predicate;
- source and packaged adapters MUST replay identical terminal vectors.

## 13. Read-only doctor

### 13.1 Interface

```text
ff doctor <slug> [--format human|json]
ff doctor --all [--format human|json]
```

`--json` MAY alias `--format json`.

### 13.2 Read-only guarantee

Doctor MUST NOT:

- write, rename, delete, migrate, normalize, or format any file;
- acquire, refresh, or release a lock;
- change file contents, directory entries, modification times, or implementation-controlled
  metadata;
- modify the Git index or worktree;
- execute project verification commands;
- fetch network content.

Access time (`atime`) changes caused solely by operating-system read semantics are outside the
portable contract; implementations SHOULD suppress them where the platform supports no-atime
reads. Tests MUST hash file contents and capture directory entries, modification times, locks,
migration snapshots, and Git/index state before and after doctor.

### 13.3 JSON envelope

```json
{
  "protocolVersion": 1,
  "scope": {"kind": "all"},
  "summary": {
    "runs": 1,
    "errors": 1,
    "warnings": 0,
    "info": 0
  },
  "runs": [
    {
      "slug": "legacy-run",
      "path": ".feature-flow/legacy-run/manifest.json",
      "schemaClass": "LEGACY_UNVERSIONED",
      "diagnostics": [
        {
          "code": "FFI_LEGACY_MIGRATION_REQUIRED",
          "severity": "error",
          "path": ".feature-flow/legacy-run/manifest.json",
          "jsonPointer": "",
          "message": "Legacy manifest is readable but cannot mutate.",
          "remediation": "Preview explicit migration to Manifest v1."
        }
      ]
    }
  ]
}
```

Human output MUST contain the same codes and conclusions.

### 13.4 Exit classes

| Exit | Meaning |
|---|---|
| `0` | Diagnosis completed; no integrity errors. Warnings/info may exist. |
| `1` | Diagnosis completed; one or more blocking integrity errors, unsupported states, or required migrations found. |
| `2` | Doctor could not complete diagnosis because of invocation, I/O, or required observation failure. |

Exit classes are interface behavior, not severity counts.

### 13.5 Diagnostic catalogue

P0 MUST define at least:

| Code | Default severity | Meaning |
|---|---|---|
| `FFI_INVALID_JSON` | error | Manifest cannot be parsed as a JSON object |
| `FFI_LEGACY_MIGRATION_REQUIRED` | error | Unversioned manifest cannot mutate |
| `FFI_SCHEMA_VERSION_UNSUPPORTED` | error | Manifest version is newer/unsupported |
| `FFI_SCHEMA_INVALID` | error | Manifest fails v1 structural validation |
| `FFI_IDENTITY_MISSING` | error | Required run/repository identity absent |
| `FFI_ENUM_INVALID` | error | Invalid phase/status/track/tier value |
| `FFI_ARTIFACT_POINTER_MISSING` | error | Required canonical pointer absent or unresolved |
| `FFI_ARTIFACT_PATH_ESCAPE` | error | Artifact/evidence pointer escapes an approved root |
| `FFI_ARTIFACT_MIRROR_MISMATCH` | error | Display mirror disagrees with canonical pointer |
| `FFI_MIGRATION_AMBIGUOUS` | error | Legacy intent cannot be safely projected |
| `FFI_MIGRATION_POINTER_DRIFT` | error | Pointer target changes during migration |
| `FFI_REVISION_UNSUPPORTED` | error | Code revision cannot be established |
| `FFI_REVISION_SCOPE_DRIFT` | error | Changed path is unclassified |
| `FFI_REVISION_MISMATCH` | error | Stored and observed revisions differ |
| `FFI_ATTESTATION_STALE` | error | Assurance result covers another revision |
| `FFI_TERMINAL_INCONSISTENT` | error | `done` is claimed without convergence |
| `FFI_LOCK_STALE` | warning | Advisory lock exceeds freshness policy |
| `FFI_CAPABILITY_DEGRADED` | warning/error | Required host capability unavailable; error if mutation needs it |

Implementations MAY add diagnostics but MUST NOT change the meaning of existing codes within
Integrity Protocol v1.

## 14. Fail-closed boundary and host adapters

### 14.1 Feature Flow transitions

The following deny state-changing Feature Flow transitions:

- legacy migration required;
- corrupt/current-invalid/unsupported schema;
- invalid track, tier, phase, signoff, or artifact state;
- pointer mirror mismatch;
- unsupported or mismatched revision;
- scope drift;
- stale or invalid attestations where the transition depends on them;
- false terminal predicate;
- unavailable capability required to enforce the requested transition.

### 14.2 Warnings

The following are warnings when they do not invalidate the requested operation:

- stale advisory lock during doctor;
- optional artifact absent;
- declared exclusions;
- legacy terminal provenance during read-only inspection;
- capability unavailable for a read-only enhancement.

A condition that prevents required integrity observation becomes an error for mutation.

### 14.3 Unrelated writes

Host adapters MUST fast-exit without policy output for writes outside Feature Flow canonical state
or declared code-mutation boundaries. The kernel does not become a general filesystem policy.

### 14.4 Adapter responsibilities

Adapters may:

- normalize host event payloads;
- locate the repository and run;
- provide current/proposed manifest bytes;
- invoke repository/artifact observers;
- map allow/deny/diagnostics into host response formats.

Adapters MUST NOT:

- reimplement schema, revision, invalidation, or terminal rules;
- downgrade an error to a pass;
- fabricate a revision or attestation;
- claim enforcement when the kernel cannot execute.

### 14.5 Capability detection

Each host reports:

- lifecycle hook support;
- command preflight support;
- shared kernel availability/version;
- schema availability/version;
- Git/repository observation;
- atomic-replace support;
- JSON output support.

Status and doctor display capability state. A mutation requiring an unavailable capability fails
with `FFI_CAPABILITY_DEGRADED`.

### 14.6 Parity

One golden vector contains:

- current manifest;
- proposed manifest;
- repository facts;
- artifact facts;
- expected allow/deny;
- expected diagnostic codes.

Claude Code, Codex, direct CLI, and packaged-distribution adapters MUST return the same policy
decision and diagnostic codes for every vector.

## 15. Executable behavioral scenarios

### 15.1 Feature verification repair

```text
Given implementation revision R1
And review(R1) is passed
When verification(R1) fails
And verification repair changes code to R2
Then review(R1) becomes invalidated
And verification(R1) becomes invalidated
And done(R2) is denied with FFI_ATTESTATION_STALE

When verification(R2) passes
And review(R2) passes
Then both attestations reference R2
And done(R2) is allowed
```

Mandatory negative assertion: `done` after the repair but before re-review is denied.

### 15.2 Bugfix review repair

```text
Given implementation revision R1
And verification(R1) is passed with RED/GREEN evidence
When review(R1) fails
And review repair changes code to R2
Then verification(R1) becomes invalidated
And review(R1) becomes invalidated
And done(R2) is denied with FFI_ATTESTATION_STALE

When review(R2) passes
And verification(R2) passes
Then both attestations reference R2
And done(R2) is allowed through the same terminal predicate
```

Mandatory negative assertion: `done` after the repair but before re-verification is denied.

### 15.3 No-op repair

```text
Given current revision R1 and valid attestations
When a repair attempt produces identical declared inputs
Then the recomputed revision remains R1
And no artificial R2 is created
And valid attestations are not invalidated solely by the no-op attempt
```

### 15.4 FS1 — undeclared mutation

```text
Given declared scope S and revision R1
When a repair changes tracked path P outside S
Then revision computation returns FFI_REVISION_SCOPE_DRIFT
And no passing attestation may be recorded
And done is denied

When P is explicitly classified as included
Then scope changes
And the new revision differs from R1
And both old attestations are invalidated
```

The corpus MUST repeat this for an undeclared untracked path.

### 15.5 FS2 — migration pointer drift

```text
Given a legacy artifact pointer resolving to normalized target T1
When migration projects a v1 pointer resolving to T2
And T1 != T2
Then migration fails with FFI_MIGRATION_POINTER_DRIFT
And canonical manifest bytes remain unchanged
And the original artifact is not moved or rewritten
```

### 15.6 Crash reconciliation

```text
Given manifest revision R1 and passing attestations
And code bytes are changed to observed revision R2
And the session crashes before manifest invalidation
When doctor, resume, attestation, or done preflight runs
Then observed R2 != stored R1
And both stored attestations are treated as stale
And completion is denied
```

## 16. Fixture and evaluation strategy

### 16.1 Manifest fixtures

| Fixture ID | Initial state | Operation | Expected result |
|---|---|---|---|
| `M-CURRENT-FEATURE` | valid feature v1 | validate | clean |
| `M-CURRENT-BUGFIX` | valid bugfix v1 | validate | clean |
| `M-LEGACY` | unversioned known shape | doctor | migration-required; no write |
| `M-CORRUPT` | invalid JSON | doctor | `FFI_INVALID_JSON`; no write |
| `M-FUTURE` | `schemaVersion: 2` | doctor | unsupported; no write |
| `M-ENUM` | invalid phase/status | transition | deny |
| `M-MIRROR` | pointer/mirror mismatch | transition | deny |
| `M-TERMINAL` | done without convergence | validate | terminal inconsistent |
| `M-LOCKED` | current manifest with fresh/stale lock variants | doctor | diagnostic only; lock unchanged |
| `M-OLD-UNSUPPORTED` | explicit unsupported old schema | doctor | unsupported-old; no write |
| `M-CURRENT-SEMANTIC` | structurally valid with semantic inconsistency | doctor | semantic error; no write |
| `M-PATH-TRAVERSAL` | pointer contains absolute/`..`/symlink escape | doctor | path-escape; escaped target unread |

### 16.2 Migration fixtures

| Fixture ID | Assertion |
|---|---|
| `X-LOSSLESS` | source snapshot digest matches original bytes; decisions/evidence preserved |
| `X-IDEMPOTENT` | second migration invocation performs no write |
| `X-AMBIGUOUS` | ambiguous legacy status refuses migration |
| `X-POINTER` | normalized artifact targets identical before/after |
| `X-POINTER-DRIFT` | differing target aborts with canonical bytes unchanged |
| `X-LEGACY-DONE` | migration preview explicitly reopens for fresh assurance |
| `X-PREVIEW-NOWRITE` | dry-run creates no snapshot, directory, lock, timestamp, or canonical change |
| `X-POLICY-EQUIVALENCE` | every mapped signoff/waiver/decision/evidence state keeps the same policy meaning |

### 16.3 Revision fixtures

- clean tracked file;
- staged-only change;
- unstaged-only change;
- staged and working-tree content differ;
- explicit untracked inclusion;
- unrelated untracked exclusion;
- tracked file already dirty and excluded at baseline, then changed again with the same Git status
  label: scope drift, followed by explicit inclusion and revision change;
- untracked file already present and excluded at baseline, then content/mode/symlink/deletion state
  changes: scope drift, followed by explicit inclusion and revision change;
- deletion;
- rename;
- executable-mode change;
- symlink target change;
- no-op repair;
- scope expansion;
- undeclared tracked change;
- undeclared untracked change;
- non-Git repository;
- Git repository without resolvable HEAD;
- Windows/macOS/Linux path normalization golden vectors.

### 16.4 Policy and transition fixtures

- Gate A signed/unsigned parity;
- feature and bugfix terminal convergence;
- stale review;
- stale verification;
- both stale;
- current revision mismatch after crash;
- artifact/evidence reference failure;
- unresolved evidence gap;
- capability unavailable for read-only versus mutation;
- unrelated host write fast exit.

### 16.5 Doctor immutability

For every doctor fixture:

1. capture recursive file content hashes;
2. capture directory entries, modification times, locks, and migration-snapshot inventory;
3. capture Git index/tree state;
4. run doctor in human mode;
5. run doctor in JSON mode;
6. assert all captured state is unchanged.

The matrix MUST cover every classification plus fresh/stale locks, migratable preview,
unsupported-old state, structural-current-invalid state, and semantic-current-invalid state.
Portable tests do not assert atime equality.

### 16.6 Evaluation pyramid

1. **Schema tests:** valid/invalid fixtures and generated boundary values.
2. **Pure kernel tests:** classification, migration plan, revision vectors, invalidation, terminal
   predicate, diagnostics.
3. **Property tests:** determinism, migration idempotence, mutation invalidation, no-op stability.
4. **Adapter parity tests:** identical golden vectors through every host adapter.
5. **Disposable-repository behavioral tests:** real staged/unstaged/untracked and repair flows.
6. **Packaged smoke tests:** invoke doctor and transition policy from built Claude/Codex packages.
7. **Agent trajectory tests:** verify actual phase procedures request the required kernel operations
   and cannot close stale assurance.

Structural phrase guards MAY remain as fast smoke tests but cannot stand in for these layers.

## 17. Implementation work packages

Effort assumes one experienced maintainer:

- **S:** 1–3 days
- **M:** 1–2 weeks
- **L:** 3–6 weeks

### WP1 — Runtime decision, schema, and fixture corpus

**Effort:** M
**Dependencies:** none

Deliver:

- supported-host capability matrix covering Claude Code, Codex, Linux, macOS, Windows;
- one runtime-language/package decision;
- executable Manifest v1 JSON Schema;
- state classifier and diagnostic types;
- static manifest fixture corpus;
- protocol-version and golden-vector format.

Exit criteria:

- all fixture manifests classify deterministically;
- schema checks are executable from source and packaged contexts;
- chosen runtime has a tested distribution strategy for every supported host;
- no command mutation behavior changes yet.

Rollback:

- remove schema/doctor exposure;
- manifests remain untouched because WP1 performs no migration.

### WP2 — Read-only doctor and explicit migration

**Effort:** M
**Dependencies:** WP1

Deliver:

- doctor human/JSON rendering;
- stable diagnostic catalogue and exit classes;
- single/all-run scope;
- migration dry-run and explicit apply;
- source snapshot, provenance, pointer-equivalence, ambiguity refusal, atomic replacement, and
  idempotence;
- historical manifest compatibility corpus.

Exit criteria:

- doctor immutability passes across every class;
- known legacy fixtures migrate losslessly;
- duplicate migration is a byte-for-byte no-op;
- pointer drift and ambiguous state abort without canonical writes;
- status remains readable for legacy runs.

Rollback:

- remove command exposure;
- restore from source snapshot if a migration implementation defect is found;
- never silently downgrade v1 manifests.

### WP3 — Revision identity and assurance convergence

**Effort:** M
**Dependencies:** WP1, WP2

Deliver:

- baseline and declared-scope capture;
- CodeRevision v1 implementation and golden vectors;
- typed review/verification attestations;
- all three mutation-boundary integrations;
- scope-drift reconciliation;
- crash mismatch detection;
- single terminal predicate;
- feature and bugfix convergence scenarios.

Exit criteria:

- all determinism and dirty-worktree fixtures pass;
- no-op repairs preserve revision;
- every changed mutation invalidates both attestations;
- every completion route calls the same predicate;
- stale review or verification can never reach done.

Rollback:

- put transition enforcement into explicit observe-only mode;
- retain recorded revision/evidence fields;
- do not fabricate legacy completion or delete evidence.

### WP4 — Host adapters and package parity

**Effort:** M
**Dependencies:** WP3

Deliver:

- Claude Code lifecycle-hook adapter;
- Codex lifecycle/command-preflight adapter;
- shared-kernel packaging in both distributions;
- capability reporting;
- source/package and host decision parity;
- removal of duplicated terminal logic from adapters.

Exit criteria:

- every golden transition vector returns identical decisions and codes;
- built packages invoke doctor and convergence fixtures successfully;
- unavailable integrity capability is loud and blocks Feature Flow mutation;
- unrelated host writes remain unaffected.

Rollback:

- adapters return to observe-only with a prominent degraded status;
- the schema, doctor, and recorded evidence remain readable.

### WP5 — Behavioral CI and staged enforcement

**Effort:** M
**Dependencies:** WP4

Deliver:

- disposable Git repository tests;
- migration campaign tooling/reporting;
- agent trajectory tests;
- observe → warn → enforce rollout;
- release documentation and operator rollback;
- current-run conformance report.

Exit criteria:

- no active current run remains invalid or unknowingly legacy;
- representative feature and bugfix trajectories converge on one revision;
- CI tests both source and packaged distributions;
- enforcement telemetry shows no unexplained denial class;
- maintainers explicitly approve fail-closed activation.

Rollback:

- return adapters to warn-only;
- retain diagnosis and v1 state;
- never downgrade migrated manifests or weaken terminal claims silently.

## 18. Rollout policy

### Stage 0 — RFC approval

Approve this RFC and close unresolved runtime capability questions.

### Stage 1 — Observe

- package schema, classifier, and doctor;
- run diagnostic observation before Integrity Protocol v1 transition enforcement is activated;
- inventory real manifests and diagnostic classes;
- test runtime/package availability.

Stage 1 is explicitly pre-activation and makes no P0-conformance claim for legacy mutation. Once
Stage 2 activates Manifest v1 for new runs, legacy state-changing transitions are denied until
explicit migration.

### Stage 2 — Warn

- new runs write v1;
- legacy mutation produces a visible migration-required denial and migration preview;
- revision and assurance fields are recorded;
- terminal policy reports would-deny results.

Legacy mutation remains blocked until explicit migration in every rollout stage from Stage 2
onward.

### Stage 3 — Enforce new runs

- new v1 runs fail closed for invalid state, scope drift, stale assurance, and false terminal
  predicates;
- legacy runs remain readable and require explicit migration.

### Stage 4 — Enforce migrated active runs

- active legacy runs are migrated explicitly;
- all supported completion paths use one predicate;
- adapter parity is release-blocking.

### Stage 5 — Remove transitional compatibility

Remove temporary observe/would-deny reporting and migration-window warnings only after the
conformance inventory is clean. Preserve `FFI_LEGACY_MIGRATION_REQUIRED` denial until each legacy
run is explicitly migrated.

## 19. Verification Loop Registry extension seam

The Verification Loop Registry is a follow-on capability inspired by the standalone, embedded,
chained, and PR-wide loop model. It MUST consume the P0 integrity contract rather than create a
parallel pass bit.

Future provider interface:

```text
AssuranceProvider.run(
  kind,
  codeRevision,
  declaredScope,
  contractItems,
  permissions,
  budget
) -> EvidenceResult
```

Rules:

- every loop declares its input CodeRevision;
- deterministic commands, skills, browser workflows, and rubric graders emit typed evidence;
- loops cannot set `done`;
- only the integrity kernel records attestations;
- a mutating loop triggers the mutation protocol and invalidates both assurance kinds;
- chained loops must re-evaluate after mutation;
- PR-wide loops use the same revision and evidence contracts;
- promotion from local to PR enforcement requires behavioral tests and measured stability.

The registry, trigger language, permissions model, loop telemetry, and organization catalogue are
explicitly deferred.

## 20. Security and reliability considerations

### 20.1 Trust boundaries

- Repository content and retrieved knowledge are untrusted inputs, not policy.
- Host adapters are transport, not authority.
- Producer identity is provenance, not proof of correctness.
- Artifact prose is a human view, not terminal authority.
- Migration source snapshots are immutable evidence.
- Excluded paths are disclosed limitations.

### 20.2 Command and capability safety

This RFC does not authorize arbitrary project commands. The future kernel observes repository and
artifact facts only. Verification-command profiles remain a separate workstream.

### 20.3 Hash limitations

CodeRevision proves equality of declared inputs, not semantic correctness, authorship, or absence
of malicious content. Its value comes from binding assurance to a reproducible state.

### 20.4 Migration sensitivity

Source snapshots can contain user-authored decisions or sensitive data. Implementations MUST keep
them under the run's existing data boundary, apply existing repository permissions, avoid network
transfer, and document retention.

### 20.5 Denial-of-service resistance

Revision observation SHOULD bound file sizes and path counts, surface unsupported inputs, and avoid
following symlinks. It MUST not silently skip an oversized run-owned file and continue with a pass.

## 21. Risks and trade-offs

| Risk | Likelihood | Impact | Required response |
|---|---|---|---|
| Contract remains unimplemented prose | Med | High | WP1 runtime decision and executable fixture corpus are mandatory before claiming progress |
| Revision scope omits run-owned files | Med | High | Scope reconciliation and `FFI_REVISION_SCOPE_DRIFT` fail closed |
| Unrelated dirty work creates friction | High | Med | Explicit inclusion/exclusion with ownership disclosure |
| Legacy migration strands active runs | Med | High | Observe inventory, dry-run, evidence snapshot, staged enforcement |
| Legacy done appears freshly certified | Med | High | Reopen explicitly and require fresh convergence |
| Host adapters diverge | Med | High | Shared golden vectors and package parity |
| Runtime unavailable on a supported host | Med | High | Capability matrix before language selection |
| Repair convergence increases cost | High | Med | Correctness is P0; later use affected-test selection without weakening same-revision assurance |
| Latest-only attestations limit audit history | Med | Low | Preserve referenced evidence; defer event history |
| Advisory locking remains racy | Med | Med | Diagnose honestly; CAS/event log remains a later workstream |

## 22. Traceability

### 22.1 Normative acceptance contract

The following definitions are copied into this tracked RFC so its traceability remains
self-contained when the author-local signed specification is absent:

- **AC1:** `docs/feature-flow-vnext-rfc.md` exists and identifies status, owner/decision
  authority, baseline version, scope, and its relationship to the architectural review and
  preserved v2 enhancement plan.
- **AC2:** The RFC contains one normative glossary and one authoritative P0 invariant list; later
  sections reference those definitions rather than creating divergent terminology.
- **AC3:** The RFC defines required `schemaVersion` behavior for new, legacy/missing, and
  unsupported-future manifests, with validation before every state-changing transition.
- **AC4:** The RFC defines explicit, evidence-preserving, idempotent legacy migration and keeps
  status/doctor read-only while mutation remains blocked until migration.
- **AC5:** The RFC provides a machine-checkable schema outline covering identity, track, tier,
  phases/statuses, signoff, canonical pointers, display mirrors, locks, revision, assurance, and
  terminal invariants.
- **AC6:** The RFC defines deterministic code-revision identity, inputs/exclusions,
  dirty-worktree handling, non-Git degradation, and same-input stability.
- **AC7:** The RFC defines typed review and verification attestations naming their code revision,
  status, producer, timestamp, artifact/evidence reference, and invalidation reason.
- **AC8:** The RFC defines one terminal predicate allowing `done` only for a schema- and
  semantic-valid manifest whose passing review and verification attestations reference the same
  current revision.
- **AC9:** The RFC defines implementation, review-repair, and verification-repair mutation
  boundaries; a changed revision makes both prior assurances ineffective before completion is
  reconsidered.
- **AC10:** The RFC defines read-only `ff doctor` human/JSON output, stable diagnostics, severity,
  exit classes, single/all-run scope, and a no-mutation guarantee.
- **AC11:** The RFC identifies fail-closed Feature Flow transition errors, warnings, and the
  unrelated-host-write boundary.
- **AC12:** The RFC defines one host-neutral policy with Claude Code and Codex adapter capability
  detection and parity tests.
- **AC13:** The RFC contains executable feature review→verification-repair and bugfix
  verification→review-repair scenarios that converge assurance on the final revision.
- **AC14:** The RFC defines fixtures for current, legacy, corrupt, unsupported-future,
  migration-idempotence, revision-mismatch, stale-attestation, terminal-inconsistency, and
  doctor-read-only behavior.
- **AC15:** The RFC divides implementation into ordered, independently releasable work packages
  with dependencies, effort, risks, rollback/compatibility strategy, and exit criteria.
- **AC16:** The RFC defines the Verification Loop Registry as a follow-on extension whose
  standalone, embedded, chained, and PR-wide loops consume revision-bound assurance rather than
  bypassing it.

### 22.2 Critical findings

| Finding | Acceptance criteria | Invariants/contracts | Behavioral proof | Work packages |
|---|---|---|---|---|
| F01: assurance can cover different revisions | AC7, AC8, AC9, AC13 | I8–I11; sections 10–12 | feature and bugfix repair convergence | WP3, WP5 |
| F03: manifest unversioned and weakly typed | AC3, AC4, AC5, AC10, AC14 | I3–I5; sections 5–7, 13 | manifest and migration fixtures | WP1, WP2 |
| F05: prerequisites/terminal invariants unenforced | AC5, AC8, AC11, AC14 | I3, I11, I12; sections 6, 12, 14 | terminal and transition vectors | WP1, WP3, WP5 |
| F06: review scope not bound to change set | AC6, AC7, AC13 | I6–I8; sections 8–10 | dirty/scope-drift fixtures | WP3, WP5 |
| F10: evaluations test structure, not outcomes | AC13, AC14, AC15 | sections 15–17 | behavioral/property/package tests | WP1, WP3–WP5 |
| F12: host enforcement divergence | AC11, AC12, AC15 | I14; section 14 | adapter parity vectors | WP4, WP5 |

### 22.3 Acceptance criteria

| AC | RFC section |
|---|---|
| AC1 | Header; Document authority; sections 1 and 18 |
| AC2 | Sections 2 and 3 |
| AC3 | Sections 5–7 |
| AC4 | Section 7 |
| AC5 | Section 6 |
| AC6 | Sections 8 and 9 |
| AC7 | Section 10 |
| AC8 | Section 12 |
| AC9 | Section 11 |
| AC10 | Section 13 |
| AC11 | Section 14 |
| AC12 | Sections 4 and 14 |
| AC13 | Section 15 |
| AC14 | Section 16 |
| AC15 | Sections 17, 18, and 21 |
| AC16 | Section 19 |

### 22.4 Success metrics

| Metric | Proof in this RFC |
|---|---|
| SM1: critical findings map to an AC and work package | section 22.2 maps F01, F03, F05, F06, F10, and F12 |
| SM2: every mutation path has invalidation coverage | section 11 lists implementation, review repair, and verification repair; section 16 requires parameterized tests |
| SM3: every completion path uses one predicate | section 12.1 maps feature, normal bugfix, reverse bugfix, and repaired routes |

## 23. Open implementation decisions

These decisions are intentionally deferred to WP1 and MUST be resolved before code implementation:

1. Which runtime is guaranteed or can be safely packaged across every supported Claude Code and
   Codex environment?
2. Which canonical JSON implementation will pin cross-platform CodeRevision bytes?
3. How will host adapters invoke the kernel without permitting a prompt to bypass preflight?
4. What maximum file/path limits preserve safety without silently excluding run-owned changes?
5. What actor/session identifiers are available consistently without exposing sensitive data?

Resolving these questions MAY change implementation file paths. It MUST NOT weaken the invariants,
diagnostic meanings, migration policy, or behavioral vectors defined here.

## 24. Decision request

Approve this RFC to begin WP1: runtime compatibility decision, executable Manifest v1 schema, and
the shared behavioral fixture corpus.
