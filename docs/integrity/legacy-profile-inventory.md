# Legacy profile inventory

WP2 uses a closed, generated inventory. Run:

```sh
go run ./cmd/ff-integrity-inventory --history \
  --output integrity/testdata/legacy/inventory-v1.json
```

The development-only command scans every Git commit plus explicitly supplied committed dogfood
roots. It records sanitized source references, source digests, behavior-aware structural
fingerprints, and exactly one disposition: a registered profile or an explicit unsupported
rationale. It may invoke Git; the packaged `ff-integrity doctor` and `migrate` runtime cannot.

`feature-flow-pre-v1` recognizes only the enumerated top-level fields in the inventory. Any
unknown top-level field is behavior-affecting by default and migration refuses with
`FFI_MIGRATION_AMBIGUOUS`. There is no catch-all mapper.

Ignored `.feature-flow` directories are never silently treated as CI authority. To incorporate
dogfood, first sanitize and commit its fixture root, then pass that root to the inventory command.
