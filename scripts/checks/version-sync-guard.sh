#!/usr/bin/env bash
# Regression guard: the release version must be identical across every place that states it.
# The repo has hit "version drift across files" before (commit ede368b "fix version drift");
# this makes the invariant enforced, not manual. Canonical source: .claude-plugin/plugin.json.
# Pinned references: .codex-plugin/plugin.json, .claude-plugin/marketplace.json, the README
# Status badge, and the newest CHANGELOG entry header.
set -u
cd "$(dirname "$0")/../.." || exit 2
fail=0
err() { echo "FAIL: $1"; fail=1; }
ok()  { echo "ok:   $1"; }

ver_of() { grep -oE '"version"[[:space:]]*:[[:space:]]*"[0-9]+\.[0-9]+\.[0-9]+"' "$1" | head -1 | grep -oE '[0-9]+\.[0-9]+\.[0-9]+'; }

VER="$(ver_of .claude-plugin/plugin.json)"
if [ -z "$VER" ]; then
  err ".claude-plugin/plugin.json: could not read a canonical \"version\""
  echo "RED: version-sync guard failed"; exit 1
fi
ok ".claude-plugin/plugin.json: canonical version $VER"

# --- other JSON version strings must match --------------------------------
for f in .codex-plugin/plugin.json .claude-plugin/marketplace.json; do
  v="$(ver_of "$f")"
  [ "$v" = "$VER" ] \
    && ok "$f: version $v matches canonical" \
    || err "$f: version '${v:-MISSING}' != canonical $VER (version drift)"
done

# --- README status badge must match ---------------------------------------
grep -qE "Status:\*\*[[:space:]]*v$VER([^0-9]|$)" README.md \
  && ok "README.md: Status badge reads v$VER" \
  || err "README.md: Status badge must read v$VER (found: $(grep -oE 'Status:\*\*[^·]*' README.md | head -1))"

# --- newest CHANGELOG entry must be this version --------------------------
newest="$(grep -oE '^## \[[0-9]+\.[0-9]+\.[0-9]+\]' CHANGELOG.md | head -1 | grep -oE '[0-9]+\.[0-9]+\.[0-9]+')"
[ "$newest" = "$VER" ] \
  && ok "CHANGELOG.md: newest entry is [$newest]" \
  || err "CHANGELOG.md: newest entry '[${newest:-none}]' != canonical $VER (add/rename the release entry)"

if [ "$fail" -eq 0 ]; then echo "PASS: version-sync guard ($VER)"; else echo "RED: version-sync guard failed"; fi
exit "$fail"
