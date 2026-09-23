# Spec: Login rate limit

**Created:** 2026-09-20
**Track:** feature
**Status:** signed-off

## Problem

The login endpoint accepts unlimited attempts per client, which invites credential stuffing.

## Expected outcome

`src/limiter.sh <client-id>` prints `allow` or `deny`, allowing at most 5 attempts per client per minute.

## Acceptance criteria

- [ ] AC1: The 6th call for the same client within one minute prints `deny`; the first 5 print `allow`.

## Sign-off

**User signed off:** yes (2026-09-20)
