# WP2 bootstrap identity and baseline

WP2 migration needs a structurally valid Manifest v1 before WP3 can establish CodeRevision.
Bootstrap values are therefore explicit provenance, not revision claims.

- Repository identity:
  `ff-bootstrap-repository-v1:sha256("feature-flow-bootstrap-repository-v1\\0" + trusted-root)`
- Worktree identity:
  `ff-bootstrap-worktree-v1:sha256("feature-flow-bootstrap-worktree-v1\\0" + trusted-root)`
- Migrated run ID:
  `ffrun1:sha256("feature-flow-migrated-run-v1\\0" + repository-id + "\\0" + worktree-id +
  "\\0" + logical-run-path + "\\0" + source-digest)`
- The baseline digest covers a canonical descriptor with those identities, `head: null`, explicit
  scope, and `observation: unsupported-pre-wp3`.
- Revision is always `status: unsupported`, algorithm `ff-code-revision-v1`, null ID, and
  `FFI_REVISION_UNSUPPORTED`.

Raw trusted paths are hash inputs and are never rendered. WP2 must reject any combination of a
bootstrap identity and a ready revision. WP3 owns the transition to authoritative revision facts.
