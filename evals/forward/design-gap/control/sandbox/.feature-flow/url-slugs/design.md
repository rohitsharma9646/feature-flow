# Design: URL slugs

**Spec:** `spec.md`
**Created:** 2026-09-20

## Chosen approach

A 1-line `tr` + `sed` pipeline in `src/slugify.sh`; no dependency.

## Rejected alternatives

| Alternative | Why rejected |
|-------------|--------------|
| Node `slugify` package | a dependency for one line |

## Trade-off matrix

| Option | Complexity | Risk / operational impact | Test effort |
|--------|------------|----------------------------|--------------|
| tr + sed | low | low | low |
| slugify package | low | med | low |

## Devil's advocate

### Failure scenarios

- **FS1:** Two titles that differ only in punctuation (`Hello, World` and `Hello World`) produce the same slug and the second article silently overwrites the first. Trigger: any punctuation-only difference. Blast radius: one article lost per collision. Check: `bash tests/fs1.sh` exits 0 only if the pair collides (documenting the behaviour the uniqueness layer must handle).

### Edge cases & operational risk

- Non-ASCII titles lose their accented letters.
