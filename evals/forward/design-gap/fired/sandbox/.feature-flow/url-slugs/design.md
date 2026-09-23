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

- **FS1:** After a title is edited, the CDN in front of the production site keeps serving the old slug's page for up to 24 h, so shared links to the new slug 404 until the cache expires. Trigger: any title rename on the live site. Blast radius: every link shared in the first day.

### Edge cases & operational risk

- Non-ASCII titles lose their accented letters.
