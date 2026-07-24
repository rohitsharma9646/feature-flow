# Integrity doctor and legacy migration

WP2 exposes a native CLI directly; existing Feature Flow commands and hooks do not invoke it.

## Doctor

```sh
ff-integrity doctor <slug> [--format human|json]
ff-integrity doctor --all [--format human|json]
```

The default trusted run root is `.feature-flow`; `--root` exists for package conformance and
isolated tooling. Doctor is read-only: it creates no directories or locks, executes no project
commands, performs no network access, and does not mutate Git/index state. Exit codes are 0 clean,
1 completed diagnosis with blocking integrity, and 2 invocation/I/O/required-observation failure.

## Migration

Preview first:

```sh
ff-integrity migrate <slug> --to 1 --dry-run --format json
```

Review and retain the returned `planDigest`, then apply that exact plan:

```sh
ff-integrity migrate <slug> --to 1 --apply --expect-plan sha256:<digest>
```

A terminal legacy run additionally requires `--confirm-reopen-terminal`. Apply re-reads the
source, recomputes the profile and plan, re-observes artifact pointers, and refuses before writing
if anything differs. It retains exact source bytes at
`<run>/migration/manifest-v0-<source-sha256>.json`, binds the honest apply-time `migratedAt`, and
publishes only a validated v1 manifest through the platform atomic replacement capability.

Corrupt, future-version, current-invalid, unsupported-old, ambiguous, and unknown-profile inputs
are diagnosis-only. A current valid v1 manifest returns already-current without reading the clock
or changing files.

If snapshot publication succeeds but canonical replacement fails, the legacy manifest remains
authoritative. The operation removes its snapshot when safe or reports
`FFI_MIGRATION_ORPHAN_SNAPSHOT`; it never treats the orphan as successful migration.
