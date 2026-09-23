---
title: <one-line decision or convention name>
captureDate: <YYYY-MM-DD>
captureCommitSha: <git rev-parse HEAD at capture, or null>
runSlug: <slug of the run that captured this>
tags: [<topic-noun>, <topic-noun>]
referencedFiles:
  - <repo-relative path this entry depends on>
---

# <title>

## Decision / convention

<The architectural decision made or project convention established — stated so a future
run can apply it without re-deriving it.>

## Why

<The reasoning, trade-offs, and rejected alternatives that made this the choice. This is
what stops a later run from re-litigating a settled question.>

## Referenced artifacts

<Where this came from: the run's spec/design/verify/review and the code paths it touches
(the `referencedFiles` above are the staleness referents).>

## Scope

<When this applies and when it does NOT — boundaries so recall doesn't over-apply it.>
