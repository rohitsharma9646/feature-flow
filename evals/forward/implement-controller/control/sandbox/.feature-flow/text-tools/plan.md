# Plan: text-tools — trim, word count and a small CLI

**Goal:** Three tested bash utilities: `src/trim.sh`, `src/words.sh`, `src/cli.sh`.

## Outcome gate

**Spec:** `.feature-flow/text-tools/spec.md`
**Acceptance criteria:** see spec §Acceptance criteria (AC1–AC3). Task 1 covers AC1, Task 2 AC2,
Task 3 AC3. No AC is uncovered. No unvalidated assumptions → no validation task.
**User signed off:** yes (2026-09-24)

## Tasks

> **No Placeholders.** Every task is executable from this task and the
> spec/design paths.

**Self-check ran:** yes — no hits

### Task 1: `src/trim.sh`

**Files:**
- Create: `src/trim.sh`
- Modify: `tests/test.sh`

**Covers:** AC1
**Interfaces:**
- Consumes: none
- Produces: `bash src/trim.sh "<text>"` prints the trimmed text

- [ ] **Step 1:** Add the checks to `tests/test.sh`, just above `exit $fail`:
  ```bash
  check src/trim.sh "  padded  " "padded"
  check src/trim.sh "none" "none"
  check src/trim.sh "$(printf '\tx\t')" "x"
  ```
  **Run:** `bash tests/test.sh` **Expected:** exit 1 — the three `src/trim.sh` checks FAIL
- [ ] **Step 2:** Create `src/trim.sh`: strip leading and trailing spaces and tabs from `$1` with a
  single `sed -E 's/^[[:blank:]]+//; s/[[:blank:]]+$//'` over `printf '%s\n' "$1"`.
- [ ] **Step 3: Verify** — **Run:** `bash tests/test.sh` **Expected:** exit 0

### Task 2: `src/words.sh`

**Files:**
- Create: `src/words.sh`
- Modify: `tests/test.sh`

**Covers:** AC2
**Interfaces:**
- Consumes: none
- Produces: `bash src/words.sh "<text>"` prints the word count

- [ ] **Step 1:** Add the checks to `tests/test.sh`, just above `exit $fail`:
  ```bash
  check src/words.sh "one two three" "3"
  check src/words.sh "  padded  words " "2"
  ```
  **Run:** `bash tests/test.sh` **Expected:** exit 1 — the two `src/words.sh` checks FAIL
- [ ] **Step 2:** Create `src/words.sh`:
  ```bash
  #!/usr/bin/env bash
  # words "<text>" -> number of words
  printf '%s\n' "$1" | tr -s ' ' '\n' | grep -c .
  ```
- [ ] **Step 3: Verify** — **Run:** `bash tests/test.sh` **Expected:** exit 0

### Task 3: `src/cli.sh`

**Files:**
- Create: `src/cli.sh`
- Modify: `tests/test.sh`

**Covers:** AC3
**Interfaces:**
- Consumes: `bash src/trim.sh "<text>"`, `bash src/words.sh "<text>"`
- Produces: `bash src/cli.sh trim|words "<text>"`

- [ ] **Step 1:** Add the checks to `tests/test.sh`, just above `exit $fail`:
  ```bash
  check src/cli.sh "trim" ""
  got="$(bash src/cli.sh bogus x 2>&1 >/dev/null)"; rc=$?
  if [ "$rc" = 2 ] && [ "${got#usage:}" != "$got" ]; then echo "ok   cli usage error"; else echo "FAIL cli usage error (rc=$rc, stderr='$got')"; fail=1; fi
  ```
  **Run:** `bash tests/test.sh` **Expected:** exit 1 — the `cli usage error` check FAILs
- [ ] **Step 2:** Create `src/cli.sh`: `case "$1" in trim|words) bash "$(dirname "$0")/$1.sh" "$2" ;;`
  otherwise print `usage: cli.sh trim|words <text>` on stderr and `exit 2`.
- [ ] **Step 3: Verify** — **Run:** `bash tests/test.sh` **Expected:** exit 0

## Dependency graph

| Task | Depends on |
|------|------------|
| Task 1 | — (root) |
| Task 2 | — (root) |
| Task 3 | Task 1, Task 2 |

## Critical path

**Path:** Task 1 → Task 3

## Risk register

| Risk | Likelihood | Impact | Mitigation |
|------|-----------|--------|-----------|
| Word splitting misses tabs | Med | Med | the task review checks AC2 against the spec |

## Rollback plan

| Task | Recovery action if `Step N: Verify` fails |
|------|--------------------------------------------|
| Task 1 | `rm -f src/trim.sh` and restore `tests/test.sh` |

## Status conventions

`[ ]` pending · `[~]` in progress · `[x]` done · `[!]` blocked · `[→]` deferred.

## Blockers

(none yet)

## Decisions made during execution

(none yet)
