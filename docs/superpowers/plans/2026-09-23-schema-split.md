# Split `docs/manifest-schema.md` into a core + topic files — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Move 13 of the 21 `## ` topics of `docs/manifest-schema.md` verbatim into `docs/schema/<topic>.md`. Each phase then reads the core plus only the topics it names, with no rule text changed. Ship as v0.21.0.

**Architecture:**
- A one-off Python split script moves the sections and adds a `## Topic index` to the core.
- A shared bash library, `scripts/checks/lib/schema.sh`, holds the layout: every topic in contract order, with the file that holds it. It rebuilds the joined contract, which is byte-identical to the old single file.
  - Existing guards read that joined file, so their assertions stay unchanged.
  - A new `schema-layout-guard.sh` pins what joining hides: file layout, core contents, the index, reference integrity, and dist parity.
- A one-off Python rewrite script points each command/template/agent/SKILL/README reference at the file that now holds the named topic.

**Tech Stack:** bash + POSIX awk (mawk-safe) for everything committed; Python 3 only for the two one-off migration scripts (run from a scratch dir, never committed).

**Spec:** `docs/superpowers/specs/2026-09-23-schema-split-design.md`

## Global Constraints

- **Pure move.** No rule-text rewrites, merges or clarifications. The only additions are the core's `## Topic index` and each topic file's two-line header.
- Topic file header, exactly:
  ```
  # <Topic> — feature-flow manifest contract
  > Part of the manifest contract. Core rules and the topic index: `docs/manifest-schema.md`.

  ```
  `<Topic>` is the layout name in the table below.
- **Core keeps, in order:**
  - intro
  - `## Topic index` (new)
  - `## Schema`
  - `## Field notes`
  - `## Config resolution & validation`
  - `## Run resolution …`
  - `## Rules every command MUST follow`
  - `## Manifest write safety`
  - `## Re-run guard`
  - `## Progress strip`
- **Topic files.** Each file holds one topic, and each topic's `## ` heading is unchanged:

  | File | Topic (layout name) |
  |---|---|
  | `docs/schema/evidence.md` | Evidence |
  | `docs/schema/enforcement.md` | Enforcement (Claude Code) |
  | `docs/schema/disk-inference.md` | Disk inference procedure |
  | `docs/schema/sign-off-rendering.md` | Sign-off rendering |
  | `docs/schema/terminal-convergence.md` | Terminal convergence |
  | `docs/schema/knowledge-base.md` | Knowledge base |
  | `docs/schema/planning-intelligence.md` | Planning intelligence |
  | `docs/schema/assumption-records.md` | Assumption records |
  | `docs/schema/design-tradeoffs.md` | Design trade-offs & devil's advocate |
  | `docs/schema/discovery-fields.md` | Discovery fields |
  | `docs/schema/autopilot.md` | Autopilot |
  | `docs/schema/delivery.md` | Delivery |
  | `docs/schema/retrospective.md` | Retrospective |
- `§Name` cross-references **inside** schema files are never rewritten. They resolve through the Topic index.
- Historical run artifacts under `docs/feature-flow/`, `docs/superpowers/` and past `CHANGELOG.md` entries are never edited.
- No compatibility stubs. No Go code change.
- Headings with `&`, `'`, parentheses or backticks are matched as fixed strings (awk `index()`), never as regex.
- Guard failure messages name the schema as `docs/manifest-schema.md + docs/schema/` (`$SCHEMA_LABEL`), never the temp path.
- `SCRATCH` means one fixed directory outside the repo, created once (the session scratchpad, or `/tmp/ff-schema-split`). Shell state does not persist between tool calls, so every command or script below that uses it starts with `SCRATCH=<that dir>`. One-off migration scripts live there and are never committed.
- In a Claude Code worktree session, complex compound bash commands are refused. Write multi-step shell to a file under `$SCRATCH` and run it with `bash`.
- Target version **0.21.0**. `integrity-conformance-guard.sh` needs Go and is exempt locally (it passes in CI).

## Review Focus

1. **A reference line-wrapped inside a blockquote.** Example: `see **Autopilot** in` / `` > `${CLAUDE_PLUGIN_ROOT}/docs/…` ``. It must be rewritten and integrity-checked like a one-line reference. Pinned by the L4 self-test fixture F1/F3 (Task 3).
2. **A sub-topic that is *mentioned* bold in several files but *defined* in one.** Example: `**Durable artifact resolution**`, defined in core Field notes and mentioned in Disk inference. It must resolve to the defining file. Pinned by fixture F2 (Task 3) and the label-definition rule in both the rewrite script and `defines()`.
3. **Generic references that name no topic.** Examples: `(schema: …manifest-schema.md)`, `per the contract (…)`, and the codex-tools mapping. They stay pointing at the core and are never guessed. Pinned by the Task 3 assertion that `commands/ff.md` and `commands/ff-explore.md` keep their generic core references.
4. **A guard failure message that prints the temp file path instead of a readable label.** The temp file must also not be left behind. Pinned by the Task 1 grep for raw `$SCHEMA` in messages and the leftover `ff-schema.*` check.
5. **The Claude `#dist` package missing `docs/schema/`.** A user installing from the dist branch would get commands pointing at files that don't exist. Pinned by the `claude-dist-guard.sh` `docs/schema/` listing check (Task 2).

---

### Task 1: Layout library, layout guard, the split, and guards on the joined contract

**Files:**
- Create: `scripts/checks/lib/schema.sh`
- Create: `scripts/checks/schema-layout-guard.sh`
- Create (by script): `docs/schema/*.md` (13 files)
- Modify (by script): `docs/manifest-schema.md`
- Modify: the 12 guards with `SCHEMA="docs/manifest-schema.md"`: `assumption-guard.sh`, `decision-record-guard.sh`, `delivery-guard.sh`, `design-tradeoff-guard.sh`, `discovery-fields-guard.sh`, `durable-paths-guard.sh`, `evidence-guard.sh`, `fresh-context-interview-guard.sh`, `kb-guard.sh`, `planning-intelligence-guard.sh`, `repair-loop-guard.sh`, `retro-guard.sh`
- Modify: `scripts/checks/lite-tier-guard.sh:10,34` and `scripts/checks/run-start-ask-guard.sh:45,50,58`

**Interfaces:**
- Produces, in `scripts/checks/lib/schema.sh` (sourced from the repo root):
  - `SCHEMA_CORE` = `docs/manifest-schema.md`.
  - `SCHEMA_LABEL` = `docs/manifest-schema.md + docs/schema/`.
  - `SCHEMA_LAYOUT`: newline-separated `Name|slug` rows in contract order; slug `core` means the core file.
  - `schema_file <slug>`: prints the repo-relative path.
  - `schema_section <file> <heading-prefix>`: prints that `## ` section.
  - `schema_joined`: prints the joined contract.
  - `schema_join`: sets `SCHEMA` to a temp file holding the joined contract and removes it on exit.
  - `bash scripts/checks/lib/schema.sh` prints the joined contract.
- Produces `scripts/checks/schema-layout-guard.sh` with checks L1–L3. Task 2 adds L5 and Task 3 adds L4.

- [ ] **Step 1: Write the layout library**

Create `scripts/checks/lib/schema.sh`:

```bash
# Shared by the schema-reading guards. Source it from the repo root; `bash scripts/checks/lib/schema.sh`
# prints the joined contract. The manifest contract is split: docs/manifest-schema.md (the core) plus
# one file per topic under docs/schema/. SCHEMA_LAYOUT lists every '## ' topic in contract order with
# the file that holds it ("core" = docs/manifest-schema.md). Lives in lib/ so CI's
# `for g in scripts/checks/*.sh` loop does not run it as a guard.

SCHEMA_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../.." && pwd)"
SCHEMA_CORE="docs/manifest-schema.md"
SCHEMA_LABEL="docs/manifest-schema.md + docs/schema/"
SCHEMA_LAYOUT="Schema|core
Field notes|core
Evidence|evidence
Config resolution & validation|core
Run resolution|core
Rules every command MUST follow|core
Manifest write safety|core
Enforcement (Claude Code)|enforcement
Disk inference procedure|disk-inference
Re-run guard|core
Progress strip|core
Sign-off rendering|sign-off-rendering
Terminal convergence|terminal-convergence
Knowledge base|knowledge-base
Planning intelligence|planning-intelligence
Assumption records|assumption-records
Design trade-offs & devil's advocate|design-tradeoffs
Discovery fields|discovery-fields
Autopilot|autopilot
Delivery|delivery
Retrospective|retrospective"

# schema_file <slug>: repo-relative path of a layout row's file.
schema_file() { if [ "$1" = core ]; then echo "$SCHEMA_CORE"; else echo "docs/schema/$1.md"; fi; }

# schema_section <file> <heading-prefix>: the '## ' section whose heading starts with the prefix, up
# to the next '## '. Fixed-string match: headings hold '&', parentheses and backticks.
schema_section() { awk -v h="## $2" 'index($0, "## ") == 1 { on = (index($0, h) == 1) } on' "$SCHEMA_ROOT/$1"; }

# schema_joined: the whole contract as one document — the core's intro, then every layout topic in
# contract order. It leaves out the core's '## Topic index' and the topic files' headers, so it is
# byte-identical to the pre-split single file for as long as no rule text changes.
schema_joined() {
  local name slug
  awk 'index($0, "## ") == 1 { exit } { print }' "$SCHEMA_ROOT/$SCHEMA_CORE"
  while IFS='|' read -r name slug; do
    schema_section "$(schema_file "$slug")" "$name"
  done <<EOF
$SCHEMA_LAYOUT
EOF
}

# schema_join: build the joined contract into a temp file (removed on exit) and point SCHEMA at it,
# so a guard's greps, section() scopes and line-order checks read the whole contract unchanged.
schema_join() {
  SCHEMA="$(mktemp "${TMPDIR:-/tmp}/ff-schema.XXXXXX")" || { echo "FAIL: mktemp"; exit 2; }
  trap 'rm -f "$SCHEMA"' EXIT
  schema_joined > "$SCHEMA"
}

if [ "${BASH_SOURCE[0]}" = "$0" ]; then schema_joined; fi
```

- [ ] **Step 2: Write the layout guard (L1–L3)**

Create `scripts/checks/schema-layout-guard.sh` (then `chmod +x`):

```bash
#!/usr/bin/env bash
# Regression guard for the split manifest contract (v0.21.0): docs/manifest-schema.md is the core
# and every other '## ' topic lives in its own docs/schema/<topic>.md. The schema-reading guards
# read the joined contract (scripts/checks/lib/schema.sh), which hides where a section lives —
# this guard pins the layout itself: topic files and headers (L1), the core's contents and the
# joined order (L2), the Topic index (L3), reference integrity (L4) and Codex dist parity (L5).
set -u
cd "$(dirname "$0")/../.." || exit 2
fail=0
err() { echo "FAIL: $1"; fail=1; }
ok()  { echo "ok:   $1"; }
. scripts/checks/lib/schema.sh

# prefixes_match <want-lines> <got-lines>: same line count, and each got line starts with its want line.
prefixes_match() {
  local -a w g; local i
  mapfile -t w <<<"$1"; mapfile -t g <<<"$2"
  [ "${#w[@]}" -eq "${#g[@]}" ] || return 1
  for i in "${!w[@]}"; do [ "${g[$i]#"${w[$i]}"}" != "${g[$i]}" ] || return 1; done
}

# --- L1: every topic file exists, carries the two-line header, and holds exactly its one section --
HDR2='> Part of the manifest contract. Core rules and the topic index: `docs/manifest-schema.md`.'
want_core="## Topic index"; want_all=""
while IFS='|' read -r name slug; do
  want_all="${want_all:+$want_all
}## $name"
  if [ "$slug" = core ]; then want_core="$want_core
## $name"; continue; fi
  f="$(schema_file "$slug")"
  if [ ! -f "$f" ]; then err "L1: $f missing (topic '$name')"; continue; fi
  [ "$(sed -n 1p "$f")" = "# $name — feature-flow manifest contract" ] && [ "$(sed -n 2p "$f")" = "$HDR2" ] \
    && ok "L1: $f has the topic header" \
    || err "L1: $f must start with '# $name — feature-flow manifest contract' and the '> Part of the manifest contract…' line"
  prefixes_match "## $name" "$(grep '^## ' "$f")" \
    && ok "L1: $f holds exactly '## $name'" \
    || err "L1: $f must hold exactly one '## ' heading, starting '## $name'"
done <<EOF
$SCHEMA_LAYOUT
EOF

# --- L2: the core holds exactly the core topics; the joined contract has every topic once, in order --
prefixes_match "$want_core" "$(grep '^## ' "$SCHEMA_CORE")" \
  && ok "L2: $SCHEMA_CORE holds exactly the Topic index + the core topics, in order" \
  || err "L2: $SCHEMA_CORE '## ' headings must be exactly: $(printf '%s' "$want_core" | tr '\n' ';')"
prefixes_match "$want_all" "$(schema_joined | grep '^## ')" \
  && ok "L2: joined contract holds every layout topic exactly once, in contract order" \
  || err "L2: joined contract headings differ from SCHEMA_LAYOUT (a topic missing, duplicated or in two files)"

# --- L3: the Topic index lists every topic file, and every path it lists exists ------------------
idx="$(awk 'index($0, "## ") == 1 { on = ($0 == "## Topic index") } on' "$SCHEMA_CORE")"
while IFS='|' read -r name slug; do
  [ "$slug" = core ] && continue
  printf '%s\n' "$idx" | grep -qF "\`$(schema_file "$slug")\`" \
    && ok "L3: Topic index lists $(schema_file "$slug")" \
    || err "L3: Topic index must list \`$(schema_file "$slug")\` ($name)"
done <<EOF
$SCHEMA_LAYOUT
EOF
for p in $(printf '%s\n' "$idx" | grep -oE 'docs/schema/[a-z-]+\.md' | sort -u); do
  [ -f "$p" ] && ok "L3: indexed path $p exists" || err "L3: Topic index lists $p, which does not exist"
done

if [ "$fail" -eq 0 ]; then echo "PASS: schema-layout guard"; else echo "RED: schema-layout guard failed"; fi
exit "$fail"
```

- [ ] **Step 3: Run the guard to verify it fails**

Run: `bash scripts/checks/schema-layout-guard.sh`
Expected: `RED`, with `FAIL: L1: docs/schema/evidence.md missing` (and the other 12), `FAIL: L2: …`, and `FAIL: L3: Topic index must list …`.

- [ ] **Step 4: Write the one-off split script**

Save as `$SCRATCH/split_schema.py`:

```python
#!/usr/bin/env python3
"""One-off (v0.21.0): split docs/manifest-schema.md into the core + docs/schema/<topic>.md, verbatim."""
import pathlib, re

LAYOUT = [  # (heading prefix, slug or None for core) — contract order; must match scripts/checks/lib/schema.sh
    ("Schema", None), ("Field notes", None), ("Evidence", "evidence"),
    ("Config resolution & validation", None), ("Run resolution", None),
    ("Rules every command MUST follow", None), ("Manifest write safety", None),
    ("Enforcement (Claude Code)", "enforcement"), ("Disk inference procedure", "disk-inference"),
    ("Re-run guard", None), ("Progress strip", None), ("Sign-off rendering", "sign-off-rendering"),
    ("Terminal convergence", "terminal-convergence"), ("Knowledge base", "knowledge-base"),
    ("Planning intelligence", "planning-intelligence"), ("Assumption records", "assumption-records"),
    ("Design trade-offs & devil's advocate", "design-tradeoffs"), ("Discovery fields", "discovery-fields"),
    ("Autopilot", "autopilot"), ("Delivery", "delivery"), ("Retrospective", "retrospective"),
]
PURPOSE = {
    "evidence": "Evidence kinds, record shape, Confidence ladder, tier scaling, evidence-gap stop and waiver.",
    "enforcement": "Claude Code hooks: the PreToolUse gates (A: implement needs sign-off, B: done needs evidence) and the SessionStart re-anchor.",
    "disk-inference": "Rebuilding phase state from artifacts on disk when the manifest is missing or corrupt.",
    "sign-off-rendering": "How a sign-off gate shows the contract: grouped checklists, the assumptions echo.",
    "terminal-convergence": "Which command marks a run `done`, per track.",
    "knowledge-base": "KB capture and recall, staleness, decision recall.",
    "planning-intelligence": "Plan dependency graph, critical path, risk register.",
    "assumption-records": "Assumption tables, the validation stop, waivers, actuations.",
    "design-tradeoffs": "Trade-off matrix, failure scenarios, devil's advocate.",
    "discovery-fields": "Success metrics, AC dependencies, touchpoints, the end-to-end check.",
    "autopilot": "Run-start ask, chaining, mandatory pauses, fix and repair cycles.",
    "delivery": "The optional delivery report.",
    "retrospective": "The optional post-done retrospective.",
}
HDR2 = "> Part of the manifest contract. Core rules and the topic index: `docs/manifest-schema.md`.\n"

core_path = pathlib.Path("docs/manifest-schema.md")
src = core_path.read_bytes().decode("utf-8")
parts = re.split(r"(?m)^(?=## )", src)
intro, sections = parts[0], parts[1:]
assert len(sections) == len(LAYOUT), f"expected {len(LAYOUT)} sections, got {len(sections)}"

index = ["## Topic index\n", "\n",
         "The core (this file) holds the rules every command uses. Each other topic lives in its own file\n",
         "under `docs/schema/`; a `§Name` reference in any rule resolves through this table. Read the core\n",
         "plus only the topic files the current command names.\n", "\n",
         "| Topic | File | What it covers |\n", "|---|---|---|\n"]
core = [intro, None]
outdir = pathlib.Path("docs/schema"); outdir.mkdir(exist_ok=True)
for (name, slug), sec in zip(LAYOUT, sections):
    assert sec.startswith("## " + name), (name, sec[:80])
    if slug is None:
        core.append(sec)
        continue
    index.append(f"| {name} | `docs/schema/{slug}.md` | {PURPOSE[slug]} |\n")
    body = f"# {name} — feature-flow manifest contract\n{HDR2}\n{sec}"
    (outdir / f"{slug}.md").write_bytes(body.encode("utf-8"))
index.append("\n")
core[1] = "".join(index)
core_path.write_bytes("".join(core).encode("utf-8"))
print(f"core {core_path.stat().st_size} bytes; {sum(1 for _, s in LAYOUT if s)} topic files written")
```

- [ ] **Step 5: Save the original, run the split, and check byte identity**

Save as `$SCRATCH/split_and_check.sh` (first line `SCRATCH=<the scratch dir>`) and run `bash "$SCRATCH/split_and_check.sh"` from the repo root:

```bash
git show HEAD:docs/manifest-schema.md > "$SCRATCH/orig.md"
python3 "$SCRATCH/split_schema.py"
bash scripts/checks/lib/schema.sh > "$SCRATCH/joined.md"
cmp "$SCRATCH/orig.md" "$SCRATCH/joined.md" && echo BYTE-IDENTICAL
```
Expected:
- `core <n> bytes; 13 topic files written`, where n is about 21,000.
- `BYTE-IDENTICAL`.

If `cmp` reports a difference, stop. Use `git checkout docs/manifest-schema.md && rm -rf docs/schema` and fix the script. Never hand-patch the output.

- [ ] **Step 6: Run the layout guard to verify it passes**

Run: `bash scripts/checks/schema-layout-guard.sh`
Expected: `PASS: schema-layout guard`

- [ ] **Step 7: Switch the 12 `SCHEMA=` guards to the joined contract**

Save as `$SCRATCH/switch_guards.sh` and run it with `bash "$SCRATCH/switch_guards.sh"` from the repo root:

```bash
set -eu
for g in assumption decision-record delivery design-tradeoff discovery-fields durable-paths evidence \
         fresh-context-interview kb planning-intelligence repair-loop retro; do
  f="scripts/checks/$g-guard.sh"
  grep -q '^SCHEMA="docs/manifest-schema.md"$' "$f"
  sed -i 's|^SCHEMA="docs/manifest-schema.md"$|. scripts/checks/lib/schema.sh\nschema_join  # SCHEMA = the joined contract (temp file); SCHEMA_LABEL names it in messages|' "$f"
  # Messages ("$SCHEMA: …", "$SCHEMA §…") get the readable label; bare "$SCHEMA" file operands stay.
  sed -i 's/"\$SCHEMA\([^"]\)/"$SCHEMA_LABEL\1/g' "$f"
done
```

- [ ] **Step 8: Hand-edit the four spots that use the schema as a path or label outside the pattern**

1. In `scripts/checks/fresh-context-interview-guard.sh`, the dist-parity loop:
   - old: `for rel in "$SCHEMA" "$TPL_S" "$TPL_V" commands/ff-clarify.md commands/ff-verify.md commands/ff-review.md; do`
   - new: `for rel in docs/manifest-schema.md "$TPL_S" "$TPL_V" commands/ff-clarify.md commands/ff-verify.md commands/ff-review.md; do`
2. In `scripts/checks/repair-loop-guard.sh`, the dist loop:
   - old: `for rel in "$CMD" "$TPL" "$RUNNER" "$SCHEMA" skills/feature-flow/SKILL.md README.md; do`
   - new: `for rel in "$CMD" "$TPL" "$RUNNER" docs/manifest-schema.md skills/feature-flow/SKILL.md README.md; do`
3. In `scripts/checks/assumption-guard.sh`, the waiver loop becomes:
   ```bash
   for f in "$SCHEMA" commands/ff-clarify.md commands/ff-diagnose.md; do
     l="$f"; [ "$f" = "$SCHEMA" ] && l="$SCHEMA_LABEL"
     flat < "$f" | grep -qF "$WAIVER" \
       && ok "$l: carries the verbatim waiver line" \
       || err "$l: must carry the verbatim '$WAIVER' line"
   done
   ```
4. In `scripts/checks/lite-tier-guard.sh`:
   - Replace the `has()` line with:
     `has() { grep -qiE "$2" "$1" && ok "$3" || err "$3 (missing /$2/ in ${4:-$1})"; }`
   - Insert after it:
     ```bash
     . scripts/checks/lib/schema.sh
     schema_join  # SCHEMA = the joined contract (temp file); SCHEMA_LABEL names it in messages
     ```
   - Replace line 34 with:
     `has "$SCHEMA" 'feature lite: explore|tier: lite. → phases: explore' "schema documents feature lite tier" "$SCHEMA_LABEL"`

   In `scripts/checks/run-start-ask-guard.sh`:
   - Insert the same two `. scripts/checks/lib/schema.sh` / `schema_join …` lines after the `ok()` line.
   - Replace the file operand `docs/manifest-schema.md` with `"$SCHEMA"` on three lines, leaving their `manifest-schema.md:` messages as they are:
     - `grep -qi 'before the manifest is written' "$SCHEMA" \`
     - `awk '/## Rules every command MUST follow/,/## Disk inference/' "$SCHEMA" | grep -q '`autopilot`' \`
     - `grep -q 'Run-start mode ask' "$SCHEMA" \`

- [ ] **Step 9: Check no message prints the temp path**

Run: `grep -nE '\$SCHEMA([^_"]|$)|[^"]\$SCHEMA"' scripts/checks/*.sh`
Expected: no output. The first alternative catches `$SCHEMA` followed by message text; the second catches a message ending in `…$SCHEMA"`. Every `$SCHEMA` left is a bare `"$SCHEMA"` file operand.

Then review by eye: `grep -n '"\$SCHEMA"' scripts/checks/*.sh`. Each hit must be a file operand (`grep … "$SCHEMA"`, `section "$SCHEMA"`, `awk … "$SCHEMA"`, `< "$SCHEMA"`, `for f in "$SCHEMA"` in the assumption waiver loop). None may be in a dist-parity `for rel in` list.

- [ ] **Step 10: Re-package the Codex dist and run every guard**

Save as `$SCRATCH/all_guards.sh`:

```bash
bash scripts/package-codex-plugin.sh >/dev/null
for g in scripts/checks/*.sh; do
  out="$(bash "$g" 2>&1)"; rc=$?
  printf '%-45s %s\n' "$g" "$([ $rc -eq 0 ] && echo PASS || echo "FAIL rc=$rc")"
  [ $rc -eq 0 ] || printf '%s\n' "$out" | grep -E '^(FAIL|RED)' | head -5
done
bash scripts/eval.sh >/dev/null 2>&1 && echo "eval PASS" || echo "eval FAIL"
ls "${TMPDIR:-/tmp}"/ff-schema.* 2>/dev/null | wc -l
```
Run: `bash "$SCRATCH/all_guards.sh"`
Expected:
- Every guard PASS, except `integrity-conformance-guard.sh` (Go missing locally).
- `eval PASS`.
- A final `0`, meaning no leftover temp files.

- [ ] **Step 11: Commit**

```bash
git add scripts/checks/lib/schema.sh scripts/checks/schema-layout-guard.sh docs/manifest-schema.md docs/schema \
        scripts/checks/*-guard.sh
git commit -m "refactor: split manifest-schema.md into a core + 13 topic files (verbatim move)

Guards read the joined contract via scripts/checks/lib/schema.sh (byte-identical to the
pre-split file); new schema-layout-guard pins files, headers, core contents and the index."
```

---

### Task 2: Ship `docs/schema/` in every package

**Files:**
- Modify: `scripts/package-claude-plugin.sh:32,67`
- Modify: `scripts/package-codex-plugin.sh:88`
- Modify: `scripts/build-integrity-packages.sh:64`
- Modify: `scripts/checks/claude-dist-guard.sh:38-40`
- Modify: `scripts/checks/schema-layout-guard.sh` (add L5)
- Modify: `skills/feature-flow/references/codex-tools.md:43`
- Modify: the dist-parity lists of the 11 guards that list `docs/manifest-schema.md`: `assumption`, `decision-record`, `delivery`, `design-tradeoff`, `discovery-fields`, `durable-paths`, `fresh-context-interview`, `kb`, `planning-intelligence`, `repair-loop`, `retro`

**Interfaces:**
- Consumes: `SCHEMA_LAYOUT` and `schema_file` from `scripts/checks/lib/schema.sh`.
- Produces: packages whose `docs/` holds `grilling-playbook.md`, `manifest-schema.md` and `schema/` (the 13 files).

- [ ] **Step 1: Add the failing checks**

In `scripts/checks/claude-dist-guard.sh`, replace the `docs/` assertion (lines 38–40) with:

```bash
[ "$(listing "$PKG/docs")" = "grilling-playbook.md manifest-schema.md schema " ] \
  && ok "docs/ holds only manifest-schema.md + schema/ + grilling-playbook.md" \
  || err "docs/ must hold exactly manifest-schema.md + schema/ + grilling-playbook.md (got [$(listing "$PKG/docs")])"
want_schema="assumption-records.md autopilot.md delivery.md design-tradeoffs.md discovery-fields.md disk-inference.md enforcement.md evidence.md knowledge-base.md planning-intelligence.md retrospective.md sign-off-rendering.md terminal-convergence.md "
[ "$(listing "$PKG/docs/schema" 2>/dev/null)" = "$want_schema" ] \
  && ok "docs/schema/ holds exactly the 13 topic files" \
  || err "docs/schema/ must hold exactly the 13 topic files (got [$(listing "$PKG/docs/schema" 2>/dev/null)])"
```

In `scripts/checks/schema-layout-guard.sh`, insert before the final `if [ "$fail" …`:

```bash
# --- L5: the Codex dist carries the core and every topic file byte-identically -------------------
DIST="dist/codex/feature-flow"
for rel in "$SCHEMA_CORE" docs/schema/*.md; do
  cmp -s "$rel" "$DIST/$rel" && ok "L5: dist parity: $rel" \
    || err "L5: dist parity: $rel differs from or is missing in $DIST/$rel (re-run scripts/package-codex-plugin.sh)"
done
```

- [ ] **Step 2: Run both to verify they fail**

Run: `bash scripts/package-codex-plugin.sh >/dev/null; bash scripts/checks/claude-dist-guard.sh | tail -3; bash scripts/checks/schema-layout-guard.sh | tail -3`
Expected:
- claude-dist: `FAIL: docs/ must hold exactly … (got [grilling-playbook.md manifest-schema.md ])`, then `RED`.
- layout: `FAIL: L5: dist parity: docs/schema/… missing`, then `RED`.

- [ ] **Step 3: Ship `docs/schema/`**

1. `scripts/package-claude-plugin.sh`:
   - In `RUNTIME_PATHS`, add `"docs/schema"` right after `"docs/manifest-schema.md"`.
   - In the usage text (line 32), change `docs/manifest-schema.md, docs/grilling-playbook.md, README.md, LICENSE.` to `docs/manifest-schema.md, docs/schema/, docs/grilling-playbook.md, README.md, LICENSE.`
2. `scripts/package-codex-plugin.sh`: in `REQUIRED_PATHS`, add `"docs/schema"` right after `"docs/manifest-schema.md"`.
3. `scripts/build-integrity-packages.sh`: in `claude_paths`, add `"docs/schema"` right after `"docs/manifest-schema.md"`.
4. `skills/feature-flow/references/codex-tools.md`: after the line
   ``- `${CLAUDE_PLUGIN_ROOT}/docs/manifest-schema.md` -> `docs/manifest-schema.md` ``
   add
   ``- `${CLAUDE_PLUGIN_ROOT}/docs/schema/*.md` -> `docs/schema/*.md` ``

- [ ] **Step 4: Widen each guard's dist-parity list to the topic files**

In each of the 11 guards, find the dist-parity `for rel in …` list that names `docs/manifest-schema.md`. Add ` docs/schema/*.md` right after it. The glob is unquoted, so it expands from the repo root.

For example, in `kb-guard.sh` the line holding `  docs/manifest-schema.md \` becomes `  docs/manifest-schema.md docs/schema/*.md \`.

Afterwards, this must list exactly the 11 guards:
`grep -l 'docs/manifest-schema.md docs/schema/\*.md' scripts/checks/*.sh`

- [ ] **Step 5: Run to verify all pass**

Run: `bash "$SCRATCH/all_guards.sh"`
Expected:
- Every guard PASS, including `claude-dist-guard.sh`, `dist-parity-guard.sh` and `schema-layout-guard.sh` (L5 ok for 14 files). `integrity-conformance-guard.sh` is the exception (Go missing locally).
- `eval PASS`.
- A final `0`.

Also run `bash scripts/build-integrity-packages.sh --help >/dev/null 2>&1; echo $?`. This is only a syntax sanity check; the full integrity build needs Go.

- [ ] **Step 6: Commit**

```bash
git add scripts/package-claude-plugin.sh scripts/package-codex-plugin.sh scripts/build-integrity-packages.sh \
        scripts/checks/*.sh skills/feature-flow/references/codex-tools.md
git commit -m "build: ship docs/schema/ in the Claude, Codex and integrity packages"
```

---

### Task 3: Point every reference at the file that holds its topic (+ reference-integrity check)

**Files:**
- Modify: `scripts/checks/schema-layout-guard.sh` (add L4 + self-tests + the SKILL reading-rule check)
- Modify (by script): `commands/*.md`, `templates/*.md`, `agents/ff-test-runner.md`, `skills/feature-flow/SKILL.md`, `README.md`
- Modify: `skills/feature-flow/SKILL.md` ("The manifest is the shared state" paragraph)
- Modify: `README.md:29-31`
- Modify: `hooks/enforce-gate:7,122` (comments)
- Modify: `scripts/checks/evidence-guard.sh:142` (message)

**Interfaces:**
- Consumes: the topic files from Task 1.
- Produces, in `schema-layout-guard.sh`:
  - `defines <file> <name>`: exit 0 if the file defines Name as a `##`/`###` heading prefix or a bold paragraph label (`**Name.`, `**Name:`, `**Name(`, `**Name (`).
  - `ref_problems <label>`: reads markdown on stdin and prints one line per broken reference.

- [ ] **Step 1: Add L4 (reference integrity), its self-tests, and the reading-rule check**

In `scripts/checks/schema-layout-guard.sh`, insert before the `# --- L5` block:

```bash
# --- L4: reference integrity ---------------------------------------------------------------------
# Every `**Name** in …/docs/<file>.md` and `…/docs/<file>.md §Name` reference must point at a file
# that exists and DEFINES Name — as a '##'/'###' heading prefix or a bold paragraph label
# ('**Name.', '**Name:', '**Name(', '**Name ('). A bold mention elsewhere is not a definition.
# Matching runs on line-joined text with blockquote markers removed, so a reference wrapped
# across a '> ' line still counts.

# defines <file> <name>
defines() {
  awk -v n="$2" '
    index($0, "## " n) == 1 || index($0, "### " n) == 1 { hit = 1 }
    { l = $0; sub(/^[ \t]*(>[ \t]*)?(- |[0-9]+\. )?/, "", l)
      if (index(l, "**" n) == 1) { c = substr(l, length(n) + 3, 2); if (c ~ /^[.:(]/ || c == " (") hit = 1 } }
    END { exit !hit }' "$1"
}
# check_ref <source-label> <path> <name>
check_ref() {
  if [ ! -f "$2" ]; then echo "$1: '$3' -> $2 (no such file)"
  elif ! defines "$2" "$3"; then echo "$1: '$3' -> $2 (not defined there)"; fi
}
# ref_problems <source-label>: markdown on stdin -> one line per broken schema reference.
# Form A: **Name** [one or two words] in|( `…/docs/<file>.md    Form B: …/docs/<file>.md[`] [**]§Name
# (The grep -o runs outside the heredocs: its patterns hold backticks.)
ref_problems() {
  local text refs_a refs_b m name path
  text="$(sed 's/^[[:space:]]*>[[:space:]]\{0,1\}//' | tr '\n' ' ' | tr -s ' ')"
  refs_a="$(printf '%s' "$text" | grep -oE '\*\*[^*]+\*\*( [a-z-]+){0,2} (in|\() ?>? ?`?(\$\{CLAUDE_PLUGIN_ROOT\}/)?docs/[a-z/-]+\.md')"
  refs_b="$(printf '%s' "$text" | grep -oE 'docs/[a-z/-]+\.md`? ?\**§[^`*,.;:)(>—→]+')"
  while IFS= read -r m; do
    [ -n "$m" ] || continue
    name="${m#\*\*}"; name="${name%%\*\**}"; name="${name%% → *}"
    path="$(printf '%s' "$m" | grep -oE 'docs/[a-z/-]+\.md' | tail -1)"
    check_ref "$1" "$path" "$name"
  done <<EOF
$refs_a
EOF
  while IFS= read -r m; do
    [ -n "$m" ] || continue
    name="${m##*§}"; name="${name%"${name##*[! ]}"}"
    path="$(printf '%s' "$m" | grep -oE 'docs/[a-z/-]+\.md' | head -1)"
    check_ref "$1" "$path" "$name"
  done <<EOF
$refs_b
EOF
}

# Self-tests: the three shapes most likely to slip past a line-based matcher.
F1="$(printf 'see **Autopilot** in\n> `${CLAUDE_PLUGIN_ROOT}/docs/manifest-schema.md`.\n' | ref_problems F1)"
[ -n "$F1" ] && ok "L4 self-test: blockquote-wrapped reference to a moved topic is caught" \
  || err "L4 self-test: F1 (blockquote-wrapped **Autopilot** -> core) must be reported"
F2="$(printf 'per the **Durable artifact resolution** rule in `${CLAUDE_PLUGIN_ROOT}/docs/schema/disk-inference.md`\n' | ref_problems F2)"
[ -n "$F2" ] && ok "L4 self-test: a mention is not a definition" \
  || err "L4 self-test: F2 (**Durable artifact resolution** -> disk-inference.md, which only mentions it) must be reported"
F3="$(printf 'see **Autopilot** in\n> `${CLAUDE_PLUGIN_ROOT}/docs/schema/autopilot.md`.\n' | ref_problems F3)"
[ -z "$F3" ] && ok "L4 self-test: a correct wrapped reference passes" \
  || err "L4 self-test: F3 (correct reference) must not be reported: $F3"

for f in commands/*.md templates/*.md agents/*.md skills/feature-flow/SKILL.md skills/feature-flow/references/*.md README.md; do
  probs="$(ref_problems "$f" < "$f")"
  [ -z "$probs" ] && ok "L4: $f schema references resolve" || { while IFS= read -r p; do err "L4: $p"; done <<EOF
$probs
EOF
  }
done

# The reading rule: SKILL.md tells the model to read the core plus only the named topic files.
flat_skill="$(tr '\n' ' ' < skills/feature-flow/SKILL.md | tr -s ' ')"
printf '%s' "$flat_skill" | grep -qF 'docs/schema/' && printf '%s' "$flat_skill" | grep -qF 'Topic index' \
  && ok "L4: SKILL.md states the core + named-topic-files reading rule" \
  || err "L4: SKILL.md 'The manifest is the shared state' must name docs/schema/ and the core's Topic index"
```

- [ ] **Step 2: Run to verify it fails for the right reason**

Run: `bash scripts/checks/schema-layout-guard.sh | grep -E '^(FAIL|ok:   L4 self)' | head -30`
Expected:
- The three `ok:   L4 self-test` lines.
- `FAIL: L4: commands/…: 'Autopilot' -> docs/manifest-schema.md (not defined there)` and similar lines. There are roughly 70 of them.
- The SKILL.md reading-rule FAIL.

If a self-test fails, fix `ref_problems`/`defines` before going on.

- [ ] **Step 3: Write the one-off rewrite script**

Save as `$SCRATCH/rewrite_refs.py`:

```python
#!/usr/bin/env python3
"""One-off (v0.21.0): point each docs/manifest-schema.md reference at the file that now holds the
topic it names. Name = a following §Name, else a preceding '§Name, `', else a preceding
'**Name** [one or two words] in|('. References that name nothing stay on the core. Names that
don't resolve to exactly one defining file are listed and left unchanged (exit 1)."""
import pathlib, re, sys

CORE = "docs/manifest-schema.md"
SCHEMA_FILES = [CORE] + sorted(str(p) for p in pathlib.Path("docs/schema").glob("*.md"))
LINES = {f: pathlib.Path(f).read_text(encoding="utf-8").splitlines() for f in SCHEMA_FILES}
TARGETS = sorted(set(
    [str(p) for d in ("commands", "templates", "agents") for p in pathlib.Path(d).glob("*.md")]
    + [str(p) for p in pathlib.Path("skills").rglob("*.md")] + ["README.md"]))

PATH = re.compile(r"(?:\$\{CLAUDE_PLUGIN_ROOT\}/)?docs/manifest-schema\.md")
FOLLOW = re.compile(r"^`?\s*\**§([^`*,.;:)(>—→]+)")
PRE_SECT = re.compile(r"§([A-Z][^`*,.;:)]*?),\s*`$")
PRE_BOLD = re.compile(r"\*\*([^*]+)\*\*(?: [a-z-]+){0,2} (?:in|\() ?>? ?`?$")
LABEL_LEAD = re.compile(r"^\s*(?:>\s*)?(?:- |\d+\. )?")

def flat(s):
    return re.sub(r"[ \t]*\n[ \t]*(?:>[ \t]?)?[ \t]*", " ", s)

def heading_files(name, level):
    return [f for f in SCHEMA_FILES if any(l.startswith(f"{level} {name}") for l in LINES[f])]

def label_files(name):
    out = []
    for f in SCHEMA_FILES:
        for l in LINES[f]:
            body = LABEL_LEAD.sub("", l, count=1)
            rest = body[len(name) + 2:]
            if body.startswith("**" + name) and (rest[:1] in (".", ":", "(") or rest.startswith(" (")):
                out.append(f)
                break
    return out

def resolve(name):
    name = name.split(" → ")[0].strip()
    for hits in (heading_files(name, "##"), heading_files(name, "###"), label_files(name)):
        if len(hits) == 1:
            return hits[0]
        if len(hits) > 1:
            return None
    return None

changed, unresolved = 0, []
for t in TARGETS:
    raw = pathlib.Path(t).read_text(encoding="utf-8")
    edits = []
    for m in PATH.finditer(raw):
        pre = flat(raw[max(0, m.start() - 240):m.start()])
        post = flat(raw[m.end():m.end() + 160])
        line = raw.count("\n", 0, m.start()) + 1
        name = None
        for rx, s in ((FOLLOW, post), (PRE_SECT, pre), (PRE_BOLD, pre)):
            hit = rx.search(s)
            if hit:
                name = hit.group(1).strip()
                break
        if name is None:
            print(f"unnamed, kept on core: {t}:{line}")
            continue
        target = resolve(name)
        if target is None:
            unresolved.append(f"{t}:{line}: {name!r}")
        elif target != CORE:
            edits.append((m.start(), m.end(), m.group(0).replace(CORE, target)))
            print(f"{t}:{line}: {name!r} -> {target}")
    for s, e, new in reversed(edits):
        raw = raw[:s] + new + raw[e:]
    if edits:
        pathlib.Path(t).write_text(raw, encoding="utf-8")
        changed += len(edits)
print(f"rewrote {changed} references")
for u in unresolved:
    print("UNRESOLVED (left unchanged):", u)
sys.exit(1 if unresolved else 0)
```

- [ ] **Step 4: Run it and review the output**

Run: `python3 "$SCRATCH/rewrite_refs.py" | tee "$SCRATCH/rewrite.log"`

Expected:
- About 70 `-> docs/schema/…` lines. Spot-check that every `'Autopilot'` goes to `autopilot.md` and every `'Evidence'` to `evidence.md`.
- `unnamed, kept on core` lines. Expect at least:
  - `commands/ff-explore.md` `(schema: …)`
  - `commands/ff.md` `per the contract (…)`
  - both `codex-tools.md` mapping entries
  - `README.md` lines 31 (twice) and 240
- Names that resolve to the core are not rewritten and print nothing. These are Run resolution, Re-run guard, Progress strip, Config resolution & validation, and Durable artifact resolution.
- No `UNRESOLVED` lines. If any appear, pick the target by reading the named topic in the schema files. Edit that reference by hand, keeping the bold name, and note it in the commit message.

Then check that nothing outside the reference paths changed:
Save as `$SCRATCH/diffcheck.sh` and run it:

```bash
git diff --stat -- commands templates agents skills README.md
git diff -U0 -- commands templates agents skills README.md | grep -E '^[-+]' | grep -vE '^(\+\+\+|---) ' | grep -vc 'docs/'
```
Expected: the last line is `0`. Every changed line contains a `docs/` path, so only references moved.

- [ ] **Step 5: Hand edits**

1. **`skills/feature-flow/SKILL.md`, "The manifest is the shared state".** The paragraph ends with the sentence "…see **Durable artifact resolution** in `docs/manifest-schema.md`." Insert this new sentence right after it, before "Every command:":

   > The contract is split: `docs/manifest-schema.md` is the core every command reads (its **Topic index** lists the rest), and each other topic lives in `docs/schema/<topic>.md` — read the core plus only the topic files the current command names.

2. **`README.md`, lines 29–31.** Replace
   ```
   [skills/feature-flow/SKILL.md](skills/feature-flow/SKILL.md); the on-disk state format in
   [docs/manifest-schema.md](docs/manifest-schema.md).
   ```
   with
   ```
   [skills/feature-flow/SKILL.md](skills/feature-flow/SKILL.md); the on-disk state format in
   [docs/manifest-schema.md](docs/manifest-schema.md) (the core; its topic index points at the
   per-topic files in [docs/schema/](docs/schema/)).
   ```

3. **`hooks/enforce-gate` comments.** These are not in the rewrite scope, but they must stay accurate.
   - Line 7: `# Gates (see docs/manifest-schema.md §Enforcement):` → `# Gates (see docs/schema/enforcement.md §Enforcement):`
   - Line 122: `# (see docs/manifest-schema.md §Enforcement + §Evidence).` → `# (see docs/schema/enforcement.md §Enforcement + docs/schema/evidence.md §Evidence).`

   Keep the rest of each line as it is.

4. **`scripts/checks/evidence-guard.sh:142`.** Change the message `must reference docs/manifest-schema.md §Evidence by name` to `must reference docs/schema/evidence.md §Evidence by name`.

- [ ] **Step 6: Pin the generic references (Review Focus 3)**

Add to `scripts/checks/schema-layout-guard.sh`, right after the L4 file loop:

```bash
# Generic references (no topic named) stay on the core — never guessed onto a topic file.
grep -qF '(schema: `${CLAUDE_PLUGIN_ROOT}/docs/manifest-schema.md`)' commands/ff-explore.md \
  && ok "L4: ff-explore's generic (schema: …) reference stays on the core" \
  || err "L4: commands/ff-explore.md '(schema: …manifest-schema.md)' must stay on the core"
tr '\n' ' ' < commands/ff.md | tr -s ' ' | grep -qF 'per the contract (`${CLAUDE_PLUGIN_ROOT}/docs/manifest-schema.md`)' \
  && ok "L4: ff.md's generic 'per the contract' reference stays on the core" \
  || err "L4: commands/ff.md 'per the contract (…manifest-schema.md)' must stay on the core"
```

- [ ] **Step 7: Re-package and run everything**

Run: `bash "$SCRATCH/all_guards.sh"`
Expected:
- Every guard PASS, except `integrity-conformance-guard.sh`. This includes `schema-layout-guard.sh` with L4 all `ok` and `dist-parity-guard.sh`, since commands changed and the dist was re-packaged.
- `eval PASS`.
- A final `0`.

- [ ] **Step 8: Commit**

```bash
git add commands templates agents skills README.md hooks/enforce-gate scripts/checks/schema-layout-guard.sh \
        scripts/checks/evidence-guard.sh
git commit -m "refactor: point schema references at the topic file that holds each topic

Rewritten by a one-off script (bold names kept; references that name no topic stay on the
core). schema-layout-guard L4 now checks every reference resolves to a file that defines it."
```

---

### Task 4: Measure, document, release v0.21.0

**Files:**
- Modify: `CHANGELOG.md` (new `[0.21.0]` entry at the top)
- Modify: `.claude-plugin/plugin.json:4`, `.claude-plugin/marketplace.json:8`, `.codex-plugin/plugin.json:3`, `README.md:6`

**Interfaces:**
- Consumes: the rewritten references from Task 3 (the measurement reads which `docs/schema/*.md` paths each command names).

- [ ] **Step 1: Write the measurement script**

Save as `$SCRATCH/measure.py`:

```python
#!/usr/bin/env python3
"""Schema bytes each command must read: before = the whole pre-split file; after = the core plus
every docs/schema/*.md the command names (direct references only)."""
import pathlib, re, sys

before = int(sys.argv[1])
core = pathlib.Path("docs/manifest-schema.md").stat().st_size
print("| Command | Before (bytes) | After (bytes) | Topic files named | Reduction |")
print("|---|---|---|---|---|")
for cmd in sorted(pathlib.Path("commands").glob("*.md")):
    named = sorted(set(re.findall(r"docs/schema/[a-z-]+\.md", cmd.read_text(encoding="utf-8"))))
    after = core + sum(pathlib.Path(p).stat().st_size for p in named)
    topics = ", ".join(pathlib.Path(p).stem for p in named) or "—"
    print(f"| {cmd.stem} | {before:,} | {after:,} | {topics} | {100 * (before - after) // before}% |")
```

- [ ] **Step 2: Run it**

Run: `python3 "$SCRATCH/measure.py" "$(git show 77b51ae:docs/manifest-schema.md | wc -c)"`
Expected:
- A 16-row table.
- For the heavy phases (ff-plan, ff-verify, ff-diagnose, ff-clarify), about a 40–60% reduction.

If a heavy phase measures well under 40%, keep the real number and say so in the CHANGELOG (spec: "report it as is").

- [ ] **Step 3: Write the CHANGELOG entry**

Insert above `## [0.20.0]` in `CHANGELOG.md`:

```markdown
## [0.21.0] — 2026-09-24 — Manifest contract split into a core + topic files

From Claude Code's best-practices guide ("keep context lean"). Every phase re-reads the manifest
contract, and with v0.20.0's fresh-context hand-offs it does so once per phase. The contract was
one ~93 KB file; a phase used a fraction of it.

- **`docs/manifest-schema.md` is now the core** — Schema, Field notes, Config resolution &
  validation, Run resolution, Rules every command MUST follow, Manifest write safety, Re-run guard,
  Progress strip — plus a new **Topic index**. The other 13 topics moved **verbatim** to
  `docs/schema/<topic>.md` (evidence, enforcement, disk-inference, sign-off-rendering,
  terminal-convergence, knowledge-base, planning-intelligence, assumption-records,
  design-tradeoffs, discovery-fields, autopilot, delivery, retrospective). No rule text changed:
  the core and topic files rejoin byte-identically to the old file.
- **References point at the topic's file** (`see **Autopilot** in …/docs/schema/autopilot.md`);
  SKILL.md states the reading rule — the core plus only the topic files the command names.
  `§Name` cross-references inside the rules resolve through the Topic index.
- **Guards:** the schema-reading guards read the joined contract (`scripts/checks/lib/schema.sh`),
  so every assertion is unchanged. New `schema-layout-guard.sh` pins the layout, the core's
  contents, the index, **reference integrity** (every `**Name** in …/docs/<file>.md` and
  `…/docs/<file>.md §Name` must point at a file that defines Name — new protection against a
  moved or renamed topic) and dist parity.
- **Packaging:** the Claude, Codex and integrity packages ship `docs/schema/`.

Schema bytes each command must read (direct references; a topic file's own `§` cross-references
may lead further):

<paste the table printed by Step 2 here, verbatim>
```

Replace the last line with the actual table output. That is the only generated content in this entry.

- [ ] **Step 4: Bump the version to 0.21.0**

Change `0.20.0` to `0.21.0` in:
- `.claude-plugin/plugin.json` (`"version"`)
- `.claude-plugin/marketplace.json` (`"version"`)
- `.codex-plugin/plugin.json` (`"version"`)
- `README.md` line 6 (`> **Status:** v0.21.0 · MIT licensed`)

- [ ] **Step 5: Re-package and run everything**

Run: `bash "$SCRATCH/all_guards.sh"`
Expected:
- Every guard PASS, including `version-sync-guard.sh`, except `integrity-conformance-guard.sh`.
- `eval PASS`.
- A final `0`.

- [ ] **Step 6: Commit**

```bash
git add CHANGELOG.md .claude-plugin/plugin.json .claude-plugin/marketplace.json .codex-plugin/plugin.json README.md
git commit -m "docs: v0.21.0 changelog with measured per-command schema reduction; bump version"
```

- [ ] **Step 7: Forward tests (manual, needs the user's go-ahead)**

`scripts/forward-test.sh` runs paid Claude sessions and never runs in CI. Ask the user before running it; the spec asks for one local run before release. Report its result as is.
