# Spec: URL slugs

**Created:** 2026-09-20
**Track:** feature
**Status:** signed-off

## Problem

Article URLs are built from raw titles, so they contain spaces and capitals and break when shared.

## Expected outcome

`src/slugify.sh` turns a title into a URL-safe slug.

## Acceptance criteria

- [x] AC1: `bash tests/test.sh` exits 0 (lowercases, collapses non-alphanumerics to `-`, trims).

## Success metrics

- [ ] SM1: p95 slug-page load time on the production site ≤ 300 ms, measured by `the production Grafana dashboard "article-latency" (7-day p95)`.

## Sign-off

**User signed off:** yes (2026-09-20)
