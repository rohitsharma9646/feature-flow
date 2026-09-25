# Explore: rate-limit

**Created:** 2026-09-24
**Track:** feature

## Summary

`src/api.sh` is a short bash script invoked once per request (no long-running daemon in this
repo). It currently has no per-caller state at all. Nothing under `src/` persists data between
invocations today — a rate limiter is the first feature here that needs cross-invocation state.
