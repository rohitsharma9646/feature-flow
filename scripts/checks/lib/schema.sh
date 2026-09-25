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
Task controller|task-controller
Assumption records|assumption-records
Design trade-offs & devil's advocate|design-tradeoffs
Critic|critic
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
