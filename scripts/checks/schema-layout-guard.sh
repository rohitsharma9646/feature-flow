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
# (Plain read loop, not mapfile, so it runs on macOS's bash 3.2.)
prefixes_match() {
  local w g
  [ "$(printf '%s\n' "$1" | wc -l)" -eq "$(printf '%s\n' "$2" | wc -l)" ] || return 1
  while IFS= read -r w <&3 && IFS= read -r g <&4; do
    [ "${g#"$w"}" != "$g" ] || return 1
  done 3<<EOF3 4<<EOF4
$1
EOF3
$2
EOF4
}

# --- L1: every topic file exists, carries the two-line header, and holds exactly its one section --
HDR2='> Part of the manifest contract. Core rules and the topic index: `docs/manifest-schema.md`.'
# topic_layout_ok <file> <name>: header on lines 1-2, a blank line 3, '## <name>' on line 4, and no
# other '## ' heading — so no text sits outside the one section the joined contract carries.
topic_layout_ok() {
  [ "$(sed -n 1p "$1")" = "# $2 — feature-flow manifest contract" ] && [ "$(sed -n 2p "$1")" = "$HDR2" ] \
    && [ -z "$(sed -n 3p "$1")" ] && prefixes_match "## $2" "$(sed -n 4p "$1")" \
    && prefixes_match "## $2" "$(grep '^## ' "$1")"
}
want_core="## Topic index"; want_all=""
while IFS='|' read -r name slug; do
  want_all="${want_all:+$want_all
}## $name"
  if [ "$slug" = core ]; then want_core="$want_core
## $name"; continue; fi
  f="$(schema_file "$slug")"
  if [ ! -f "$f" ]; then err "L1: $f missing (topic '$name')"; continue; fi
  topic_layout_ok "$f" "$name" \
    && ok "L1: $f is the topic header, a blank line, then exactly '## $name'" \
    || err "L1: $f must be '# $name — feature-flow manifest contract', the '> Part of the manifest contract…' line, a blank line, then '## $name' as its only '## ' heading"
done <<EOF
$SCHEMA_LAYOUT
EOF
# Self-test: a rule line between the header and the heading is outside every section, so the joined
# contract (and every guard reading it) would never see it.
FX="$(mktemp "${TMPDIR:-/tmp}/ff-layout.XXXXXX")"
printf '# Evidence — feature-flow manifest contract\n%s\n\nA stray rule.\n## Evidence\nbody\n' "$HDR2" > "$FX"
topic_layout_ok "$FX" Evidence && err "L1 self-test: text above the '## ' heading must be rejected" \
  || ok "L1 self-test: text above the '## ' heading is rejected"
rm -f "$FX"

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
# A reference with a trailing §Name is checked by form B only — the § names the file's topic, and
# the bold before it may be prose ("the **Covers:** map (…§Discovery fields").
# (The grep -o runs outside the heredocs: its patterns hold backticks.)
ref_problems() {
  local text refs_a refs_b refs_c m name path
  text="$(sed 's/^[[:space:]]*>[[:space:]]\{0,1\}//' | tr '\n' ' ' | tr -s ' ')"
  refs_a="$(printf '%s' "$text" | grep -oE '\*\*[^*]+\*\*( [a-z-]+){0,2} (in|\() ?>? ?`?(\$\{CLAUDE_PLUGIN_ROOT\}/)?docs/[a-z/-]+\.md(`? ?\**§)?')"
  refs_b="$(printf '%s' "$text" | grep -oE 'docs/[a-z/-]+\.md`? ?\**§[^`*,.;:)(>—→]+')"
  # Form C: §Name, `…/docs/<file>.md`  (e.g. "the **Evidence gap stop** row in §Autopilot, `…`")
  refs_c="$(printf '%s' "$text" | grep -oE '§[A-Z][^`*,.;:)]*, ?`?(\$\{CLAUDE_PLUGIN_ROOT\}/)?docs/[a-z/-]+\.md')"
  # Every schema path, named or not, must exist.
  for path in $(printf '%s' "$text" | grep -oE 'docs/(manifest-schema|schema/[a-z-]+)\.md' | sort -u); do
    [ -f "$path" ] || echo "$1: $path (no such file)"
  done
  while IFS= read -r m; do
    [ -n "$m" ] || continue
    [ "${m%§}" = "$m" ] || continue
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
  while IFS= read -r m; do
    [ -n "$m" ] || continue
    name="${m#§}"; name="${name%%,*}"
    path="$(printf '%s' "$m" | grep -oE 'docs/[a-z/-]+\.md' | tail -1)"
    check_ref "$1" "$path" "$name"
  done <<EOF
$refs_c
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
F4="$(printf 'the **Evidence gap stop** row in §Autopilot, `${CLAUDE_PLUGIN_ROOT}/docs/schema/evidence.md`\n' | ref_problems F4)"
[ -n "$F4" ] && ok "L4 self-test: a '§Name, path' reference to the wrong file is caught" \
  || err "L4 self-test: F4 (§Autopilot, …/evidence.md) must be reported"
F5="$(printf 'see `${CLAUDE_PLUGIN_ROOT}/docs/schema/no-such-topic.md` for the rules\n' | ref_problems F5)"
[ -n "$F5" ] && ok "L4 self-test: an unnamed path to a missing schema file is caught" \
  || err "L4 self-test: F5 (…/docs/schema/no-such-topic.md) must be reported"

for f in commands/*.md templates/*.md agents/*.md skills/feature-flow/SKILL.md skills/feature-flow/references/*.md README.md; do
  probs="$(ref_problems "$f" < "$f")"
  [ -z "$probs" ] && ok "L4: $f schema references resolve" || { while IFS= read -r p; do err "L4: $p"; done <<EOF
$probs
EOF
  }
done

# Generic references (no topic named) stay on the core — never guessed onto a topic file.
tr '\n' ' ' < commands/ff-explore.md | tr -s ' ' | grep -qF '(schema: `${CLAUDE_PLUGIN_ROOT}/docs/manifest-schema.md`)' \
  && ok "L4: ff-explore's generic (schema: …) reference stays on the core" \
  || err "L4: commands/ff-explore.md '(schema: …manifest-schema.md)' must stay on the core"
tr '\n' ' ' < commands/ff.md | tr -s ' ' | grep -qF 'per the contract (`${CLAUDE_PLUGIN_ROOT}/docs/manifest-schema.md`)' \
  && ok "L4: ff.md's generic 'per the contract' reference stays on the core" \
  || err "L4: commands/ff.md 'per the contract (…manifest-schema.md)' must stay on the core"

# The reading rule: SKILL.md tells the model to read the core plus only the named topic files.
flat_skill="$(tr '\n' ' ' < skills/feature-flow/SKILL.md | tr -s ' ')"
printf '%s' "$flat_skill" | grep -qF 'docs/schema/' && printf '%s' "$flat_skill" | grep -qF 'Topic index' \
  && ok "L4: SKILL.md states the core + named-topic-files reading rule" \
  || err "L4: SKILL.md 'The manifest is the shared state' must name docs/schema/ and the core's Topic index"
# A topic named only by a bare §Name / **Name** counts as named — the rule must say so, or a literal
# reading skips topic files a command depends on.
printf '%s' "$flat_skill" | grep -qF 'by path or by `§Name`' \
  && ok "L4: SKILL.md reading rule counts a bare §Name / **Name** mention as naming the topic" \
  || err "L4: SKILL.md reading rule must say a command names a topic 'by path or by \`§Name\`/\`**Name**\`'"
# The index's paths are relative to the plugin root, not the user's project (which may have its own docs/schema/).
printf '%s\n' "$idx" | tr '\n' ' ' | grep -qF 'relative to the plugin root' \
  && ok "L3: Topic index says its paths are relative to the plugin root" \
  || err "L3: Topic index intro must say its paths are relative to the plugin root"

# --- L5: the Codex dist carries the core and every topic file byte-identically -------------------
DIST="dist/codex/feature-flow"
for rel in "$SCHEMA_CORE" docs/schema/*.md; do
  cmp -s "$rel" "$DIST/$rel" && ok "L5: dist parity: $rel" \
    || err "L5: dist parity: $rel differs from or is missing in $DIST/$rel (re-run scripts/package-codex-plugin.sh)"
done

if [ "$fail" -eq 0 ]; then echo "PASS: schema-layout guard"; else echo "RED: schema-layout guard failed"; fi
exit "$fail"
