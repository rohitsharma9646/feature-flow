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
prefixes_match "$want_all" "$(schema_joined 2>/dev/null | grep '^## ')" \
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

# --- L5: the Codex dist carries the core and every topic file byte-identically -------------------
DIST="dist/codex/feature-flow"
for rel in "$SCHEMA_CORE" docs/schema/*.md; do
  cmp -s "$rel" "$DIST/$rel" && ok "L5: dist parity: $rel" \
    || err "L5: dist parity: $rel differs from or is missing in $DIST/$rel (re-run scripts/package-codex-plugin.sh)"
done

if [ "$fail" -eq 0 ]; then echo "PASS: schema-layout guard"; else echo "RED: schema-layout guard failed"; fi
exit "$fail"
