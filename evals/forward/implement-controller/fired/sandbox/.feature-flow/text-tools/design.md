# Design: text-tools

**Spec:** `.feature-flow/text-tools/spec.md`
**Created:** 2026-09-24

## Chosen approach

Three standalone bash scripts under `src/`, each taking its input as `$1`; `src/cli.sh` dispatches on
its first argument. Checks are appended to the existing `tests/test.sh` harness.

## Rejected alternatives

| Alternative | Why rejected |
|-------------|--------------|
| One script with subcommands only | the utilities are also called directly by other scripts |

## Trade-off matrix

| Option | Complexity | Risk / operational impact | Test effort |
|--------|------------|----------------------------|--------------|
| Three scripts (chosen) | low | low | low |
| One script | low | low | low |

## Devil's advocate

### Failure scenarios

- **FS1:** Word counting splits on spaces only, so tab-separated input is miscounted.

### Edge cases & operational risk

- None beyond the spec's edge cases.
