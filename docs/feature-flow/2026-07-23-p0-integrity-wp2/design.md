# Design: P0 Integrity WP2 — read-only doctor and explicit legacy migration

**Spec:** `docs/feature-flow/2026-07-23-p0-integrity-wp2/spec.md`
**Created:** 2026-07-23

## Chosen approach

Use a pragmatic layered Go architecture with one directly invocable `ff-integrity` CLI and
separate packages for trusted observation, path policy, doctor policy/rendering, pure migration
planning, and the sole effectful storage/apply boundary.

The unchanged `classifier.Classify([]byte)` remains the first structural gate. Doctor and preview
can depend only on read-only observers and pure policy. Apply must recompute the preview, require
the reviewed canonical plan digest, re-observe all mutable facts, bind the one declared apply-time
timestamp, validate the final v1 bytes, and then enter the storage boundary.

This keeps the safety-critical seams explicit without introducing a full application-service and
ports framework before WP3/WP4 have demonstrated the need for it.

### Normative design choices

- **Reviewed-plan binding:** canonical JSON plans carry `planDigest =
  sha256(canonical-plan-without-planDigest)`. Apply requires `--expect-plan <digest>`, recomputes
  the plan from fresh bytes and observations, and refuses before constructing a writer when it
  differs.
- **Stable migrated run identity:** derive `runId` as
  `ffrun1:<sha256("feature-flow-migrated-run-v1\0" + repositoryBootstrapIdentity + "\0" +
  worktreeBootstrapIdentity + "\0" + logicalRunPath + "\0" + sourceDigest)>`. Inputs are trusted,
  canonical, and contain no rendered absolute path.
- **Honest migration time:** preview declares `/migration/migratedAt` as an
  `apply-commit-clock` finalizer. Apply obtains one injected UTC timestamp only after all
  revalidation succeeds, completes provenance, and validates final bytes. Already-current paths
  never read the clock.
- **Pre-WP3 bootstrap:** use namespaced hashed repository/worktree identities, a canonical
  bootstrap baseline descriptor, an explicit scope supported by the matched legacy profile, and
  `revision.status: unsupported`. No WP2 path may emit a ready revision or assurance attestation.
- **Atomic publication:** capability preflight occurs before run mutation. Unix uses synced
  same-directory files plus atomic rename and directory sync. Windows uses native replacement
  APIs with flushed handles and write-through behavior. No copy/delete or remove-then-rename
  fallback exists; unavailable guarantees block apply.
- **Snapshot semantics:** exact original bytes publish to
  `<run>/migration/manifest-v0-<source-sha256>.json`. Existing same-name/same-bytes evidence is
  reusable; different bytes are an integrity error.
- **Legacy registry:** a generated, committed inventory fingerprints behavioral families found
  in Git history and committed dogfood fixtures. Every family has exactly one typed profile or an
  explicit unsupported rationale; there is no best-effort catch-all.
- **Diagnostics:** a shared immutable catalogue package owns codes, safe messages, severity, and
  stable ordering. Raw OS errors and absolute paths never enter public reports.

## Rejected alternatives

| Alternative | Why rejected |
|-------------|--------------|
| Minimal CLI-centric extension | Smaller initial diff, but insufficiently durable separation between observation, policy, rendering, and storage for the failure-injection and WP3 extension requirements. |
| Full hexagonal application with formal ports for every effect | Strongest long-term isolation, but adds application-service and adapter ceremony before WP3/WP4 consumers exist and increases WP2 delivery surface without improving its observable contract. |

## Trade-off matrix

| Option | Complexity | Risk / operational impact | Test effort | Maintainability |
|--------|------------|----------------------------|-------------|-----------------|
| Pragmatic layered architecture | med | med | high | high |
| Minimal CLI-centric extension | med | high | med | med |
| Full hexagonal application | high | low | high | high |

## Component map

| File / module | Responsibility | New or modified |
|---------------|----------------|-----------------|
| `cmd/ff-integrity/**` | Strict `doctor`/`migrate` argument parsing, trusted composition, rendering, and exit mapping | new |
| `cmd/ff-integrity-inventory/**` | Development/CI-only Git-history and fixture family inventory | new |
| `integrity/jsonstrict/**` | Shared bounded strict JSON decoding while preserving classifier byte behavior | new |
| `integrity/diagnostics/**` | Catalogue lookup, safe diagnostic construction, deduplication, and deterministic ordering | new |
| `integrity/classifier/diagnostics.go` | Compatibility adapter to shared catalogue primitives | modified |
| `integrity/observe/**` | Immediate-run discovery and immutable filesystem/repository observations from trusted roots | new |
| `integrity/pathpolicy/**` | Cross-platform containment, symlink policy, pointer facts, and equivalence | new |
| `integrity/semantic/**` | WP2-owned current/legacy semantic checks without revision or assurance policy | new |
| `integrity/doctor/**` | Typed single/all reports, diagnosis policy, human/JSON renderers, and exit classes | new |
| `integrity/migration/**` | Pure plan model, canonical digest, deterministic bootstrap, validation, and finalizer declaration | new |
| `integrity/migration/v0/**` | Closed registry and typed mappings for inventoried legacy families | new |
| `integrity/storage/**` | Apply coordinator, capability preflight, atomic publication, cleanup, and recovery results | new |
| `integrity/storage/replace_unix.go` | Same-filesystem atomic replacement and directory sync | new |
| `integrity/storage/replace_windows.go` | Native Windows atomic replacement with flushed/write-through handles | new |
| `schemas/doctor-result-v1.schema.json` | Machine-readable doctor envelope | new |
| `schemas/migration-plan-v1.schema.json` | Canonical preview/apply contract | new |
| `integrity/testdata/doctor/**` | Versioned diagnosis and immutability corpus | new |
| `integrity/testdata/migration/**` | Required X-* migration and failure corpus | new |
| `integrity/testdata/legacy/inventory-v1.json` | Auditable family disposition inventory | new |
| `integrity/protocol/v1/diagnostics.json` | Stable WP2 observation/migration/storage codes | modified |
| `scripts/build-integrity-packages.sh` | Build and compose the new native CLI/assets | modified |
| `scripts/package-codex-plugin.sh` | Add only approved WP2 runtime assets to the complete Codex package | modified |
| `scripts/check-integrity-package-conformance.sh` | Exercise classifier, doctor, preview, and disposable apply through complete packages | modified |
| `scripts/checks/integrity-boundary-guard.sh` | Permit the explicit CLI while continuing to forbid existing command/hook activation | modified |
| `.github/workflows/integrity.yml` | Fresh native WP2 evidence across all declared targets | modified |

## Data flow

### Doctor

```text
trusted config/run selection
  → immediate non-symlink run discovery
  → immutable observation
  → Classify(raw bytes)
  → eligible WP2 semantic/path checks
  → stable typed report
  → human or JSON renderer
  → exit 0 / 1 / 2
```

Doctor composition has no storage, clock, subprocess, network, or project-command capability.
Corrupt, future, current-invalid, and unsupported-old inputs stop after safe classification.

### Preview

```text
trusted legacy run observation
  → Classify = LEGACY_UNVERSIONED
  → exactly one registered profile
  → contained pointer facts
  → typed projection and unknown-field policy
  → deterministic bootstrap/runId
  → structural + WP2 semantic validation
  → canonical plan + plan digest + apply-time finalizer
  → stdout only
```

The planner has no filesystem, clock, random source, lock, or writer interface.

### Apply

```text
--apply + --expect-plan (+ terminal confirmation when required)
  → fresh source/profile/pointer plan
  → expected digest equality
  → atomic capability preflight
  → immediate source and pointer re-observation
  → bind one migratedAt value
  → final structural + semantic validation
  → exact source snapshot publication
  → atomic manifest replacement
  → sync + cleanup/recovery result
```

Current v1 branches to `already-current` before clock capture or filesystem mutation.

## Risks

- Bootstrap identifiers could be mistaken for authoritative WP3 revision facts. Namespaced
  algorithms, mandatory unsupported revision, and semantic rejection of bootstrap-plus-ready
  states prevent that interpretation.
- Shape fingerprints can hide behavior variants. Fingerprints include behavior-significant
  values, profile matchers are disjoint, and ambiguity is fatal.
- Windows or unusual filesystems may not provide the claimed atomic semantics. Capability
  preflight fails closed for apply while doctor and preview remain available.
- Exact snapshots may contain sensitive legacy data. Reports omit bytes and host paths; Unix
  storage uses restrictive creation modes and other platforms report their actual capability.
- Pointer facts can drift after planning. Apply recomputes the complete plan and re-observes facts
  immediately before publication; drift aborts.
- Adding the WP2 binary invalidates prior package support evidence. All targets require fresh
  native execution before support remains claimed.

## Devil's advocate

### Failure scenarios

- **FS1:** A legacy manifest and reviewed plan remain byte-identical, but an artifact pointer's symlink target is exchanged before apply; if pointer identity is not re-observed at the final mutation boundary, migration publishes a v1 manifest whose behavior differs from the reviewed run.
- **FS2:** Snapshot publication succeeds but canonical manifest replacement fails and cleanup is denied; the legacy manifest must remain exact and readable while the owned orphan snapshot is reported deterministically rather than mistaken for successful migration.
- **FS3:** A Windows or network-backed filesystem reports ordinary rename support but cannot guarantee atomic replacement of an existing file; apply must fail before creating run-local files rather than fall back to a partial copy/delete sequence.
- **FS4:** Two historical legacy families share the same shallow key/type shape but encode different sign-off or waiver behavior; inventory or matching must refuse the ambiguity rather than select a lossy profile.
- **FS5:** The new shared diagnostic/strict-JSON primitives change ordering, normalization, or bytes emitted by the WP1 classifier; unchanged source and packaged classifier vectors must detect the regression.
- **FS6:** A successful second apply reads the clock or republishes evidence, changing `migratedAt`, snapshot inventory, or filesystem timestamps despite reporting already-current.

### Edge cases & operational risk

- Crash after snapshot publication but before canonical replacement is safely retryable; the
  content-addressed snapshot is reused only after exact-byte verification.
- An existing snapshot path with different bytes is treated as corruption, never overwritten.
- Run roots and immediate child runs that are symlinks are refused before discovery traversal.
- Windows drive-relative, UNC, device, and mixed-separator inputs are normalized for rejection,
  not interpreted relative to the process working directory.
- OS access times are outside the portable immutability contract; bytes, entries, modification
  times, locks, migration inventory, and Git/index state remain enforced.
