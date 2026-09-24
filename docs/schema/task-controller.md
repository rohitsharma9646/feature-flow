# Task controller — feature-flow manifest contract
> Part of the manifest contract. Core rules and the topic index: `docs/manifest-schema.md`.

## Task controller

How `ff-implement` builds a full-tier plan one task at a time: a fresh implementer subagent per task,
working from a brief that holds only that task; a per-task review of that task's diff; a capped fix
loop; and a ledger on disk that makes the phase resumable at task granularity. `ff-plan`,
`ff-implement`, `ff-review`, `ff-status` and `ff-resume` reference the subsections below by name and
never restate them. **No toggle:** the controller runs whenever its activation test holds. **No new
manifest field** beyond the `artifacts.ledger` pointer — caps, rounds and rulings live in the ledger.

### Executable plans

A full-tier plan (`templates/plan.md`, `templates/plan-bugfix.md`) is written so that one task can be
handed to a fresh agent that has read nothing else:

- **Global Constraints.** A `## Global Constraints` section between `## Outcome gate` and `## Tasks`,
  copied verbatim from the spec's `## Constraints` and the design's binding decisions (bugfix: the
  diagnosis). Every task brief carries it unedited. Empty → "no additional constraints", never
  omitted. Its presence is also what switches the controller on (§Controller activation).
- **Interfaces.** Each task has an `**Interfaces:**` block: `Consumes:` (exact names and signatures
  this task uses from earlier tasks or the codebase) and `Produces:` (exact names and signatures later
  tasks rely on), or `none`. An implementer sees only its own task; this block is how it learns its
  neighbours' names.
- **Step shape.** A step that writes a test carries the complete test code in a fenced block. An
  implementation step names the exact change — files, functions, signatures, behaviour — and includes
  the code when it is short or subtle. Every step that runs something carries `**Run:**` and
  `**Expected:**`. `Step N: Verify` (and `Verify RED` / `Verify GREEN` on the bugfix template) keep
  their labels.
- **No Placeholders.** The `## Tasks` blockquote of `templates/plan.md` / `templates/plan-bugfix.md`
  is the one canonical list of what a plan may not contain — this section does not repeat it. `ff-plan`
  checks every task against it before it completes, fixes every hit and records it on the
  `**Self-check ran:**` line; `ff-implement`'s pre-flight re-checks it (§Controller activation).

### Controller activation

`ff-implement` uses the controller when the run is **full tier** (feature, or escalated bugfix) **and**
the plan resolved via `manifest.artifacts.plan` has a `## Global Constraints` heading. Otherwise —
lite tier, or a plan written before v0.23.0 — it implements inline exactly as before. Either way it
states the path as one line, `Implement path: controller — <reason>` or
`Implement path: inline — <reason>`, repeated in the phase's final summary. Every existing gate (sign-off, cold-start routing, Decision recall, Critical-path
check) runs first, unchanged.

**Pre-flight.** Before the first dispatch the controller re-checks every task against the
No Placeholders list. Any hit is the **Plan placeholder stop**: the phase stops in both modes, naming
the task and the offending text, and routes to `/feature-flow:ff-plan`. No task is dispatched from a
plan with placeholders.

### Task packaging

Two mechanics must be exact on every platform, so they live in one shared file, reproduced here
byte-for-byte: `task_section` extracts one section of the plan (fence-aware — a heading-shaped line
inside a fenced code block never starts or ends a section), and `task_diff` packages the change between
two tree ids. The ids themselves come from **Revision fingerprint** in
`${CLAUDE_PLUGIN_ROOT}/docs/schema/enforcement.md` — the working-tree fingerprint, or (with `head`)
HEAD's tree minus the same bookkeeping paths, which `ff-review` uses as the base of the whole change. Claude Code runs the shipped file:

    bash "${CLAUDE_PLUGIN_ROOT}/hooks/lib/task.sh" section <plan> '^### Task <N>:'
    bash "${CLAUDE_PLUGIN_ROOT}/hooks/lib/task.sh" diff <project dir> <base> <head> > <task dir>/diff.patch

Where `hooks/` is not shipped (Codex), pipe the block below unchanged:
`bash -s -- section <plan> '^### Task <N>:' <<'FF_TASK'` … `FF_TASK`. Never re-type or paraphrase it.
Neither function writes the index, the working tree or the history.

```bash
#!/usr/bin/env bash
# Feature Flow task packaging (v0.23.0) — docs/schema/task-controller.md §Task packaging.
# That section reproduces this file byte-for-byte; scripts/checks/implement-controller-guard.sh
# fails CI if the two ever differ. Edit both together.
#
# Run:    bash task.sh section <file> <heading-ERE>        -> prints that section of a markdown file
#         bash task.sh diff <project-dir> <tree-a> <tree-b> -> prints --stat, then the unified diff
# Source: . task.sh                                         -> defines task_section, task_diff
#
# task_section finds headings only OUTSIDE fenced code blocks (``` or ~~~, any length >= 3, closed
# by the same character repeated at least as many times), so a plan step whose code contains a
# heading-shaped line never cuts or starts a task brief. The section runs from the matching heading
# to the next heading of the same or a higher level; trailing blank lines are dropped.
# task_diff compares two tree ids (from revision_fingerprint in revision.sh) at the git top level;
# it reads existing objects only — the real index, the working tree and the history are never
# modified. Any failure prints nothing and returns non-zero.

# task_section <file> <heading-ERE>: print the first section whose heading line matches.
task_section() {
  local file=$1 re=$2
  [ -f "$file" ] || return 1
  awk -v re="$re" '
    function run(s, c,   n) { n = 0; while (substr(s, n + 1, 1) == c) n++; return n }
    {
      line = $0; t = line; sub(/^[ \t]*/, "", t)
      if (fc != "") {
        if (substr(t, 1, 1) == fc && run(t, fc) >= fl && substr(t, run(t, fc) + 1) ~ /^[ \t]*$/) fc = ""
        if (on) buf[++n] = line
        next
      }
      c = substr(t, 1, 1)
      if ((c == "`" || c == "~") && run(t, c) >= 3) {
        fc = c; fl = run(t, c)
        if (on) buf[++n] = line
        next
      }
      if (line ~ /^#+[ \t]/) {
        lvl = match(line, /[^#]/) - 1
        if (on && lvl <= level) exit
        if (!on && line ~ re) { on = 1; level = lvl }
      }
      if (on) buf[++n] = line
    }
    END {
      while (n > 0 && buf[n] ~ /^[ \t]*$/) n--
      for (i = 1; i <= n; i++) print buf[i]
      exit(on ? 0 : 1)
    }' "$file"
}

# task_diff <project-dir> <tree-a> <tree-b>: print `git diff --stat` then `git diff -U10`.
task_diff() {
  local proj=$1 a=$2 b=$3 top id stat body
  command -v git >/dev/null 2>&1 || return 1
  for id in "$a" "$b"; do
    case ${#id} in 40|64) ;; *) return 1 ;; esac
    case $id in *[!0-9a-f]*) return 1 ;; esac
  done
  top=$(git -C "$proj" rev-parse --show-toplevel 2>/dev/null) || return 1
  git -C "$top" cat-file -e "$a^{tree}" 2>/dev/null || return 1
  git -C "$top" cat-file -e "$b^{tree}" 2>/dev/null || return 1
  stat=$(git -C "$top" diff --no-color --no-ext-diff --stat "$a" "$b" 2>/dev/null) || return 1
  body=$(git -C "$top" diff --no-color --no-ext-diff -U10 "$a" "$b" 2>/dev/null) || return 1
  printf '%s\n\n%s\n' "$stat" "$body"
}

if [ -z "${BASH_SOURCE[0]:-}" ] || [ "${BASH_SOURCE[0]}" = "$0" ]; then
  case ${1:-} in
    section) shift; task_section "$@" ;;
    diff) shift; task_diff "$@" ;;
    *) echo "usage: task.sh section <file> <heading-ERE> | diff <project-dir> <tree-a> <tree-b>" >&2; exit 2 ;;
  esac
  exit
fi
```

### Ledger

`<run dir>/tasks/ledger.md` — ephemeral (sandbox only, never promoted), located via
`manifest.artifacts.ledger`, which the controller writes — as the resolved repo-relative path
`<base>/<slug>/tasks/ledger.md` — when it creates the ledger, **before** the first dispatch. Per-task files live beside it in `<run dir>/tasks/task-<N>/`: `brief.md`, `report.md`,
`diff.patch` (or `files.txt`), `review.md`, and per fix round `fix-<R>.patch` and `rereview-<R>.md`.

- **Identity line.** The first line is `# Ledger — plan: <plan path>`. A ledger whose plan path differs
  from `manifest.artifacts.plan` belongs to another plan: it is left untouched and a new ledger is
  started (`tasks/ledger-<n>.md`), with the pointer moved and the switch noted in the summary.
- **Entry.** One `## Task <N>: <title>` block per task, with these lines as they become known:
  `**Status:**` (`in-progress` · `complete (clean)` · `complete (<n> rulings)` · `blocked — <reason>` ·
  `stopped — Critical after cap`), `**Base:**` and `**Head:**` (tree ids, or
  `not recorded — <reason>`), `**Implementer:**` (status — model — agent id — report path),
  `**Review:**` (path — conformance and quality verdicts with counts), one `**Fix round <R>/3:**` line
  per round, `**TDD:**`, `**Ruling:**` lines, and `**Drift:**` when the tree changed before the task.
- **Two writes per step.** The ledger is rewritten after every state change and before every
  dispatch. A round line is written `— pending` before its dispatch and rewritten with its outcome
  after the re-review, so an interrupted round is distinguishable from a finished one.
- **Resume.** The first entry whose status is not `complete (…)` is the next task; `blocked` and
  `stopped` entries are re-entered only after the user has acted. **Keep the recorded Base:** a task
  that already has a Base keeps it — never recompute it on resume, or edits made before the
  interruption fall out of the task's diff. A `— pending` round is redone from its recorded base; a
  finished round moves to the next round number; a round already used is never repeated.
- **Drift.** When a task's Base differs from the previous task's Head (the tree changed between
  tasks), write one `**Drift:**` line naming the changed paths (`revision_changed_paths`), and keep
  the current tree as the Base — the task's diff then holds only its own change.
- **Not a git repository** (or the fingerprint fails): Base and Head read `not recorded — <reason>`;
  the task's `files.txt` (the implementer's reported changed files) replaces `diff.patch`, and the
  reviewer reads those files.

### Status contract

The implementer (`agents/ff-implementer.md`) ends with exactly one status and returns a summary of at
most 15 lines; everything else goes to `task-<N>/report.md` (sections `Status`, `Summary`,
`Files changed`, `TDD`, `Verify`, `Concerns`, `Needed context`).

- `DONE` — the task is implemented and its Verify step passed.
- `DONE_WITH_CONCERNS` — done, with doubts; the concerns become items the task reviewer must check.
- `NEEDS_CONTEXT` — the controller answers from the spec, design and plan into the brief's
  `## Added context` and re-dispatches — at most twice per task; a third `NEEDS_CONTEXT` is `BLOCKED`.
- `BLOCKED` — the **Task blocked stop**: the phase stops in both modes naming the task and the
  blocker (ledger `blocked — <reason>`). It resumes when the user supplies the missing decision or
  context and re-runs `/feature-flow:ff-implement`.

With `toggles.tdd` on, every code task's report gives the RED run (command, non-zero exit, failing
assertion) captured before the implementation and the GREEN run (exit 0) after; the ledger's
`**TDD:**` line records both. A task with no testable contract records `TDD: exempt — <reason>`;
`toggles.tdd: false` records `TDD: off (config)`.

### Task review

One `ff-code-reviewer` per task, on `models.reviewer`, given **paths only** — the brief, the report and
`diff.patch` (never the diff pasted into a prompt) — plus `reviewThreshold`, told not to spawn
subagents. It returns two verdicts into `task-<N>/review.md`, findings rated Critical or Important at
or above the threshold:

- **Conformance** — the task's `**Covers:**` ACs are met, its `Produces:` interfaces exist as stated,
  the Global Constraints hold, and nothing outside the task's `**Files:**` changed.
- **Quality** — bugs, edge cases, simplicity, project conventions, scoped to this diff.

The controller adds two Critical conformance findings itself: a `DONE` whose report shows its Verify
step failing, and (tdd on) a code task with neither RED/GREEN evidence nor an exemption.

A **scoped re-review** after a fix round gets the open findings and `fix-<R>.patch`, marks each
finding `ADDRESSED` or `NOT ADDRESSED`, and reports only new breakage inside the fix diff
(`rereview-<R>.md`) — never a full re-review.

### Fix loop

Runs when a review or re-review leaves a finding open; at most **3 rounds** per task, one ledger line
each. Rounds 1 and 2 **resume the same implementer** (its recorded agent id) with the open findings;
where resume is unavailable, a fresh `ff-implementer` gets the brief, the previous report and the
findings. Round 3 dispatches a **fresh** `ff-implementer` on `models.escalation`, told that earlier
attempts failed and given all previous reports; if that model cannot be dispatched, it runs on
`models.implementer` and the round line says `escalation unavailable — used <model>`. After each round:
a new Head, `fix-<R>.patch` (previous Head → new Head), and the scoped re-review. This is a
capped-then-stop cycle, like review's fix-and-re-review cycle and verify's repair cycle; the cap lives
in the ledger, not in the manifest or config.

### Rulings

After round 3:
- **Any open Critical** is the **Critical-after-cap stop**: the phase stops in both modes naming the
  task and the findings (ledger `stopped — Critical after cap`). It clears when the user fixes the code
  and re-runs `/feature-flow:ff-implement` — the task then gets one fresh review of Base → current
  tree, with no further rounds — or writes, in the ledger, the user-authored line
  `Task <N> finding accepted by user (<date>): <reason>`. The controller never writes that line.
- **Only Important findings open** → one ruling per finding,
  `**Ruling:** <decision> — <why> — <cost if wrong>`; the task is `complete (<n> rulings)` and the loop
  moves on.

At the end of the phase the summary lists every ruling and drift line. `ff-review` gives its
reviewers the ledger's rulings as context — decisions already taken, to be judged on their merits.

### Bugfix under the controller

On an escalated full-tier bugfix the RED→GREEN order is kept by task order: when the task whose
Verify step is `Verify RED` completes, its RED run is written to `manifest.bugfix.red` **before** the
next task is dispatched; when the final task completes, its GREEN run is written to
`manifest.bugfix.green`. A RED task whose test passes pre-fix is a Critical conformance finding.

### Inline fallback (Codex)

Without multi-agent tooling the same loop runs inline, with the same files, in the same order, keeping
the role boundaries: write the brief, implement it as the implementer would (no git index or history
changes, only the task's files), write the report, then review the diff as the reviewer would, then
fix. The ledger, diffs, reviews and RED→GREEN evidence are produced exactly as on Claude Code; only the
fresh context per task is lost.
