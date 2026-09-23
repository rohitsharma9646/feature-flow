# Spec: CSV export

**Created:** 2026-09-20
**Track:** feature
**Status:** signed-off

## Problem

Users copy report rows by hand; they need a CSV file.

## Expected outcome

`bash src/export.sh > out.csv` writes the report as CSV with a header row.

## Acceptance criteria

- [ ] AC1: `bash src/rows.sh` prints the report rows as `name|count` lines.
- [ ] AC2: `bash src/rows.sh | bash src/csv.sh` prints `name,count` lines with fields containing commas quoted.
- [ ] AC3: `bash src/export.sh` prints a `name,count` header followed by the CSV rows.

## Sign-off

**User signed off:** yes (2026-09-20)
