#!/usr/bin/env bash
# Regression guard: the run-start autopilot ask must be structurally non-droppable.
# Pins the bug in .feature-flow/autopilot-ask-skipped (RED pre-fix, GREEN post-fix):
# an executor could write the manifest with a self-chosen `autopilot` because the
# resolve step was sequenced AFTER the write and the field was not required at creation.
set -u
cd "$(dirname "$0")/../.." || exit 2
fail=0
err() { echo "FAIL: $1"; fail=1; }
ok()  { echo "ok:   $1"; }

first_line() { grep -inE "$1" "$2" 2>/dev/null | head -1 | cut -d: -f1; }

# (a) resolve-autopilot must precede the manifest-write instruction at every entry point
check_order() { # file resolve_re write_re
  local r w
  r=$(first_line "$2" "$1"); w=$(first_line "$3" "$1")
  if [ -n "$r" ] && [ -n "$w" ] && [ "$r" -lt "$w" ]; then
    ok "$1: resolve-autopilot@$r precedes write@$w"
  else
    err "$1: resolve-autopilot (line ${r:-MISSING}) must precede manifest write (line ${w:-MISSING})"
  fi
}
check_order commands/ff.md          'resolve autopilot first'    'use the write tool'
check_order commands/ff-explore.md  'resolve .autopilot. first'  'write a manifest'
check_order commands/ff-clarify.md  'resolve .autopilot. first'  'then create one'
check_order commands/ff-diagnose.md 'resolve .autopilot. first'  'then create one'

# (a2) ff.md creation field list includes autopilot
grep -qE 'Both:.*`autopilot`' commands/ff.md \
  && ok "ff.md: creation field list includes autopilot" \
  || err "ff.md: creation field list ('Both:') must include \`autopilot\`"

# (a3) cold-start creation writes include the resolved autopilot field
check_window() { # file write_re — autopilot must appear on the write line or within 2 lines after
  grep -iA2 -E "$2" "$1" 2>/dev/null | grep -q 'autopilot' \
    && ok "$1: creation write includes autopilot" \
    || err "$1: creation write must include the resolved \`autopilot\` field"
}
check_window commands/ff-explore.md  'write a manifest'
check_window commands/ff-clarify.md  'then create one'
check_window commands/ff-diagnose.md 'then create one'

# (b) canonical run-start procedure resolves BEFORE the write
grep -qi 'before the manifest is written' docs/manifest-schema.md \
  && ok "manifest-schema.md: run-start is resolve-before-write" \
  || err "manifest-schema.md: run-start procedure must resolve the value BEFORE the manifest is written"

# (c) creation rule ('Rules every command MUST follow') lists autopilot
awk '/## Rules every command MUST follow/,/## Disk inference/' docs/manifest-schema.md | grep -q '`autopilot`' \
  && ok "manifest-schema.md: creation rule lists autopilot" \
  || err "manifest-schema.md: creation rule #1 must list \`autopilot\`"

# (d) doctrine line + mandatory-gate-table row
grep -q 'never choose `manifest.autopilot` yourself' skills/feature-flow/SKILL.md \
  && ok "SKILL.md: doctrine line present" \
  || err "SKILL.md: unconditional block must contain 'never choose \`manifest.autopilot\` yourself'"
grep -q 'Run-start mode ask' docs/manifest-schema.md \
  && ok "manifest-schema.md: gate table has 'Run-start mode ask' row" \
  || err "manifest-schema.md: mandatory-gate table must have a 'Run-start mode ask' row"

# (e) ff-status surfaces the mode
grep -q 'autopilot' commands/ff-status.md \
  && ok "ff-status.md: prints the autopilot mode" \
  || err "ff-status.md: print list must include the autopilot mode"

if [ "$fail" -eq 0 ]; then echo "PASS: run-start ask guard"; else echo "RED: run-start ask guard failed"; fi
exit "$fail"
