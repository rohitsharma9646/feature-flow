# Spec: Localized greeting

**Created:** 2026-09-20
**Track:** feature
**Status:** signed-off

## Problem

The CLI greets every user in English, and user records have no locale to choose a language from.

## Expected outcome

`--greeting` prints a greeting; each user row stores a locale.

## Acceptance criteria

- [x] AC1: `node src/cli.js --greeting hi` prints `hi`.
- [x] AC2: the `users` table has a NOT NULL `locale` column after migrations run.

## Sign-off

**User signed off:** yes (2026-09-20)
