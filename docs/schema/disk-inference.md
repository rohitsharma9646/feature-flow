# Disk inference procedure — feature-flow manifest contract
> Part of the manifest contract. Core rules and the topic index: `docs/manifest-schema.md`.

## Disk inference procedure

Used by `/ff-resume` and `/ff-status` when the manifest is missing/corrupt, or to validate a
manifest that claims phases are complete:

1. Walk the track's phase order — feature: explore(`explore`) → clarify(`spec`) →
   design(`design`, `decision` — `decision` optional, absent tolerated pre-v0.10.0) →
   plan(`plan`) → implement(no artifact) → review(`review`) → verify(`verify`); bugfix:
   diagnose(`diagnosis`) → implement(no artifact) → verify(`verify`) → review(`review`).
2. **Resolve each phase's artifact path before checking existence.** When the manifest is
   present, take the path from `manifest.artifacts.<name>` (the sole locating authority) — so a
   doc promoted to `<paths.durable>/<D>-<slug>/` is checked at its real path, never mis-marked
   missing because it left the sandbox. When the manifest is **lost**, resolve by applying the
   **Durable artifact resolution** rule to config: infer the slug from the run-dir name, then
   for each durable artifact use `<paths.durable>/<D>-<slug>/<name>.md` (or the legacy
   `paths.spec`/`paths.plan` location); if `createdAt` — hence `<D>` — is unrecoverable, do a
   **bounded glob `<paths.durable>/*-<slug>/`** (most-recently-modified on ties), scoped to
   `paths.durable` only — never a repo-wide scan. Ephemeral artifacts always resolve to
   `<base>/<slug>/<name>.md`.
3. For each phase marked `complete` (or, with no manifest, each phase in order): the resolved
   artifact must **exist on disk** AND pass **minimal validity** — `spec.md` must contain a
   `User signed off:` line; `diagnosis.md` must contain a `**Status:**` line reading
   `confirmed` or `signed-off` (a draft-status diagnosis fails validity); `verify.md` must
   pass the same content check as Gate B (§Enforcement) — a `## Contract mapping` heading and
   at least one captured status token — so inference and the hook never disagree; all
   other artifacts: existence suffices.
4. The first phase whose artifact is missing or invalid is the true resume point. Announce
   why: "manifest claims complete but artifact missing: `<path>`" or "artifact failed validity
   check: `<path>`".

