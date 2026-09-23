# Explore: Locale-aware timestamps

**Created:** 2026-09-22
**Track:** feature

## Summary

Timestamps are rendered by `src/render.js` straight from the upstream API string. The change lives
there; reuse `Intl.DateTimeFormat`.
