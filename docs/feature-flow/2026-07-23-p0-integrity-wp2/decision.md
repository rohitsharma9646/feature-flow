---
tags: [integrity, migration, doctor]
referencedFiles:
  - integrity/classifier/classifier.go
  - schemas/manifest-v1.schema.json
  - integrity/protocol/v1/diagnostics.json
  - release/targets.json
  - scripts/build-integrity-packages.sh
  - scripts/check-integrity-package-conformance.sh
---

# Decision: Use a pragmatic layered integrity application for WP2

**Spec:** `docs/feature-flow/2026-07-23-p0-integrity-wp2/spec.md`
**Created:** 2026-07-23

## Decision

Implement WP2 as one explicit native Go CLI over separate trusted-observation, path-policy,
doctor, pure migration-planning, and atomic-storage layers, with apply mechanically bound to the
reviewed canonical plan digest and no automatic Feature Flow lifecycle activation.

## Context

WP2 must add read-only diagnosis and evidence-preserving migration without weakening WP1's pure
classifier, fabricating WP3 revision authority, or exposing an unsafe write path. The architecture
must support exhaustive failure injection and six-target packaging while remaining proportionate
to a work package that is not yet integrated into status, resume, hooks, or phases.

## Options considered

| Option | Why considered / rejected |
|--------|----------------------------|
| Pragmatic layered architecture | chosen — explicit safety boundaries and extension seams without a premature full ports framework |
| Minimal CLI-centric extension | rejected — smaller diff but greater coupling and operational risk at observation/storage boundaries |
| Full hexagonal application | rejected — strongest isolation but excess application-service and adapter surface before WP3/WP4 consumers exist |

## Trade-offs

| Option | Effort | Risk | Reversibility |
|--------|--------|------|----------------|
| Pragmatic layered architecture | high | med | easy to extend |
| Minimal CLI-centric extension | med | high | hard to untangle |
| Full hexagonal application | high | low | easy to simplify |

## Chosen + rationale

The pragmatic layered option preserves the load-bearing architectural boundaries: raw-byte
classification remains pure; observation is trusted and read-only; planning is deterministic and
effect-free; and all writes are isolated behind explicit apply plus platform-specific atomic
publication. Requiring the reviewed plan digest prevents preview/apply drift. It provides enough
structure for the concrete failures in `design.md` §Devil's advocate (FS1–FS6) without committing
WP2 to abstractions whose first real consumers belong to later work packages.

Reopen this decision only if WP3 proves that more than one application adapter needs the same
orchestration service, or if a declared target cannot implement the storage capability contract.

**Related ACs:** AC1–AC17
**Related files:** `integrity/classifier/classifier.go`, `schemas/manifest-v1.schema.json`,
`integrity/protocol/v1/diagnostics.json`, `release/targets.json`,
`scripts/build-integrity-packages.sh`, `scripts/check-integrity-package-conformance.sh`

## Outcome

Pending implementation.

## Future considerations

- WP3 may lift composition into a formal application service when CodeRevision observation becomes
  authoritative.
- WP4 owns automatic command/hook integration, installed-host activation, signing, notarization,
  reputation, and marketplace delivery.
- Remote or network-backed run stores remain unsupported until their atomicity and identity
  contracts are explicitly designed and proven.
