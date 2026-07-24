# Integrity Protocol v1

Integrity Protocol v1 defines the stable byte-level contract shared by Feature Flow integrity
implementations and host adapters.

## Independent versions

- Manifest Schema: `1`
- Integrity Protocol result envelope: `1`
- Diagnostic catalogue: `1`
- Golden-vector format: `1`

These versions advance independently. Consumers must reject unsupported major versions rather
than infer compatibility.

## Classifier

Input is raw manifest bytes only. Output is one compact UTF-8 JSON object followed by one LF:

```json
{"protocolVersion":1,"classification":"LEGACY_UNVERSIONED","diagnostics":[]}
```

Classification depends only on JSON parseability, the exact integer `schemaVersion`
discriminator, and Manifest v1 structural validity. It must not observe a path, repository,
artifact, operation, clock, locale, environment, or host state.

Diagnostics are deduplicated and ordered by JSON Pointer then code. Public messages and
remediation come from `integrity/protocol/v1/diagnostics.json`; validator-native messages and
stack traces are not protocol data.

## Compatibility

- Existing Manifest v1 fixture outcomes cannot change within protocol v1.
- Backward-compatible top-level extension fields may be added because Manifest v1 deliberately
  leaves the top level open.
- Integrity-owned `code`, `assurance`, and `migration` objects remain closed.
- A breaking structural change requires Manifest Schema v2.
- Diagnostic catalogue v1 may add codes but may not remove or redefine an existing code, default
  severity, meaning, or remediation contract.
- Adding a diagnostic to an existing vector is a behavior change requiring explicit compatibility
  review; it is never a silent catalogue update.
- Golden-vector IDs are immutable. Changed input or expected behavior receives a new ID. Optional
  supersession metadata may identify the older vector without rewriting it.
- Vector-format changes that invalidate a v1 index require vector format v2.

## Work-package ownership

WP1 vectors assert parsing, version discrimination, structural schema, diagnostics, and exact
output. Later-WP vectors may already be present with their structural WP1 expectation, but WP1
must not emit migration, repository, artifact, assurance, terminal, or host-adapter policy.

## Input bound

WP1 accepts at most 4 MiB of manifest bytes. Oversized input is classified as corrupt with
`FFI_INVALID_JSON`. The limit is deterministic and independent of host memory. A later protocol
major may replace this rule only with new golden vectors and an explicit compatibility note.

## WP2 operation envelopes

Doctor result and migration-plan envelopes are independently versioned at `schemaVersion: 1` and
validated by `schemas/doctor-result-v1.schema.json` and
`schemas/migration-plan-v1.schema.json`. They consume but do not extend the classifier contract.

Doctor human and JSON output are renderings of the same typed result. Public diagnostics come from
the v1 catalogue; logical run paths may be emitted, but raw host errors and untrusted absolute
paths are not protocol data.

Migration plans are canonical JSON. Their `planDigest` is SHA-256 over the complete plan with the
digest field empty. The only value intentionally finalized during apply is
`/migration/migratedAt`, declared in `applyFinalizers` as `apply-commit-clock`. Apply must require
the reviewed digest, recompute the plan from fresh source and pointer observations, and refuse any
drift before writing.

WP2 bootstrap identity and revision limitations are normative in
`docs/integrity/bootstrap-v1.md`. Doctor/migration invocation, retention, and recovery behavior are
documented in `docs/integrity/wp2-operations.md`.
