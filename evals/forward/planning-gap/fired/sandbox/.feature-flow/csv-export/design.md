# Design: CSV export

**Spec:** `spec.md`
**Created:** 2026-09-20

## Chosen approach

Three small scripts piped together: `rows.sh` (data) → `csv.sh` (encoding) → `export.sh` (header + pipeline).

## Rejected alternatives

| Alternative | Why rejected |
|-------------|--------------|
| one script | mixes data access with encoding; harder to test |

## Trade-off matrix

| Option | Complexity | Risk / operational impact | Test effort |
|--------|------------|----------------------------|--------------|
| three scripts | low | low | low |
| one script | low | low | med |

## Devil's advocate

### Failure scenarios

- **FS1:** A name containing a double quote breaks the CSV row. Covered by csv.sh quoting.

### Edge cases & operational risk

- Empty report → header only.
