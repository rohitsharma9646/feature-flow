# Spec: text-tools — trim, word count and a small CLI

**Created:** 2026-09-24
**Track:** feature
**Status:** signed-off

## Problem

Scripts in this repo repeatedly re-implement trimming and word counting. We want three small,
tested bash utilities instead.

## Expected outcome

`src/trim.sh`, `src/words.sh` and `src/cli.sh` exist, are covered by `tests/test.sh`, and behave as
the acceptance criteria say.

## Solution approaches considered

One obvious approach: three plain bash scripts, one per utility — no alternatives worth weighing.

## Assumptions (WHAT-changing)

| Statement | Confidence | Basis / evidence | If-wrong impact | Validation-required |
|---|---|---|---|---|
| none | | | | n |

## Constraints

- Plain bash; each script reads its input from `$1` and prints its result on stdout.
- A usage error prints a line starting with `usage:` on **stderr** and exits **2**.

## Touchpoints

- `src/trim.sh`, `src/words.sh`, `src/cli.sh` — new.
- `tests/test.sh` — new checks.

## Edge cases

- Empty input: `trim` prints an empty line; `words` prints `0`.
- Tabs count as whitespace everywhere.

## Non-goals

- Unicode whitespace other than space and tab.

## Acceptance criteria

- [ ] AC1: `bash src/trim.sh "<text>"` prints the text with leading and trailing spaces and tabs removed.
- [ ] AC2: `bash src/words.sh "<text>"` prints the number of words, where words are separated by any
  run of spaces **or tabs** — e.g. `"one two"` → `2`, `"a<TAB>b"` → `2`, `""` → `0`.
- [ ] AC3: `bash src/cli.sh trim|words "<text>"` runs the matching utility; any other first argument
  prints `usage: cli.sh trim|words <text>` on stderr and exits 2.

## End-to-end check

- [ ] E2E: `bash tests/test.sh` exits 0.

## Sign-off

**User signed off:** yes (2026-09-24)
