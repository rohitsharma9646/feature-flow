# Design: Localized greeting

**Spec:** `.feature-flow/greeting-release/spec.md`
**Created:** 2026-09-20

## Chosen approach

Parse a `--greeting` flag in the CLI; add a `locale` column via a numbered SQL migration.
