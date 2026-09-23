#!/usr/bin/env bash
# Regression guard: Claude runtime-only package (v0.18.0, run dist-branch-packaging). Pins:
#   AC1  the package's top-level entries, docs/ and .claude-plugin/ are EXACTLY the allowlist.
#   AC2  no dev-only file anywhere in it (Go source, go.mod/sum, cmd/, integrity/, schemas/,
#        scripts/, evals/, .github/, .codex-plugin/, release/, CHANGELOG.md, docs/feature-flow/).
#   AC3  every ${CLAUDE_PLUGIN_ROOT}/<path> (or bare $CLAUDE_PLUGIN_ROOT/<path>, as hooks use) referenced
#        from a shipped file exists in the package.
#   AC4  (structural half) the package's marketplace.json serves the plugin from "./" at the
#        plugin.json version. The live install half is verified by hand, not in CI.
#   AC6  master's marketplace.json points its plugin at the dist branch over HTTPS.
#
# Builds the package with scripts/package-claude-plugin.sh into a temp dir. To check an existing
# tree instead (e.g. a deliberately broken one), set CLAUDE_DIST_DIR=<dir>.
set -u
cd "$(dirname "$0")/../.." || exit 2
fail=0
err() { echo "FAIL: $1"; fail=1; }
ok()  { echo "ok:   $1"; }

if [ -n "${CLAUDE_DIST_DIR:-}" ]; then
  PKG="$CLAUDE_DIST_DIR"
else
  tmp="$(mktemp -d)"; trap 'rm -rf "$tmp"' EXIT
  PKG="$tmp/feature-flow"
  if ! bash scripts/package-claude-plugin.sh --output "$PKG" >/dev/null 2>&1; then
    err "scripts/package-claude-plugin.sh failed to build a package"
    echo "RED: claude-dist guard failed"; exit 1
  fi
fi
[ -d "$PKG" ] || { err "package dir $PKG missing"; echo "RED: claude-dist guard failed"; exit 1; }

# --- AC1: exact allowlist --------------------------------------------------------------------
listing() { ( cd "$1" && ls -A | LC_ALL=C sort | tr '\n' ' ' ); }
want_top=".claude-plugin LICENSE README.md agents commands config docs hooks skills templates "
got_top="$(listing "$PKG")"
[ "$got_top" = "$want_top" ] && ok "top-level entries are exactly the allowlist" \
  || err "top-level entries differ — want [$want_top] got [$got_top]"
[ "$(listing "$PKG/docs")" = "grilling-playbook.md manifest-schema.md " ] \
  && ok "docs/ holds only manifest-schema.md + grilling-playbook.md" \
  || err "docs/ must hold exactly manifest-schema.md + grilling-playbook.md (got [$(listing "$PKG/docs")])"
[ "$(listing "$PKG/.claude-plugin")" = "marketplace.json plugin.json " ] \
  && ok ".claude-plugin/ holds only plugin.json + marketplace.json" \
  || err ".claude-plugin/ must hold exactly plugin.json + marketplace.json (got [$(listing "$PKG/.claude-plugin")])"

# --- AC2: no dev-only content anywhere --------------------------------------------------------
stray="$(cd "$PKG" && find . \( -name '*.go' -o -name 'go.mod' -o -name 'go.sum' -o -name 'CHANGELOG.md' \
  -o -path './cmd' -o -path './integrity' -o -path './schemas' -o -path './scripts' -o -path './evals' \
  -o -path './.github' -o -path './.codex-plugin' -o -path './release' -o -path './docs/feature-flow' \
  -o -name '.git' -o -name '.feature-flow' -o -name '.feature-flow.json' \) -print | head -5)"
[ -z "$stray" ] && ok "no dev-only files in the package" || err "dev-only content shipped: $(echo $stray)"

# --- AC3: every ${CLAUDE_PLUGIN_ROOT}/<path> resolves inside the package ---------------------
missing=""
while IFS= read -r ref; do
  rel="${ref#\$\{CLAUDE_PLUGIN_ROOT\}/}"; rel="${rel#\$CLAUDE_PLUGIN_ROOT/}"
  rel="${rel%%[\`\'\"),;:]*}"; rel="${rel%.}"
  [ -z "$rel" ] && continue
  case "$rel" in *'<'*) continue ;; esac   # a `ff-<next-phase>.md` placeholder, not a real path
  [ -e "$PKG/$rel" ] || missing="$missing $rel"
done < <(grep -rhoE '\$\{?CLAUDE_PLUGIN_ROOT\}?/[A-Za-z0-9_./<>-]+' "$PKG" | sort -u)   # braced and bare forms
[ -z "$missing" ] && ok "every \${CLAUDE_PLUGIN_ROOT} reference resolves inside the package" \
  || err "dangling \${CLAUDE_PLUGIN_ROOT} references:$missing"

# --- AC4 (structural): packaged marketplace serves "./" at the plugin version ----------------
python3 - "$PKG" <<'PY' && ok "packaged marketplace.json: feature-flow from \"./\" at the plugin.json version" || err "packaged marketplace.json must list feature-flow with source \"./\" and the plugin.json version"
import json, sys
p = sys.argv[1]
ver = json.load(open(f"{p}/.claude-plugin/plugin.json"))["version"]
mk = json.load(open(f"{p}/.claude-plugin/marketplace.json"))
ent = [e for e in mk["plugins"] if e["name"] == "feature-flow"]
assert len(ent) == 1 and ent[0]["source"] == "./" and ent[0]["version"] == ver, ent
PY

# --- AC6: master's marketplace points its plugin at the dist branch over HTTPS ----------------
python3 - <<'PY' && ok "master marketplace.json: plugin source = url https …feature-flow.git @ ref dist, version synced" || err "master .claude-plugin/marketplace.json must source the plugin from the dist branch over HTTPS at the plugin.json version"
import json
ver = json.load(open(".claude-plugin/plugin.json"))["version"]
ent = [e for e in json.load(open(".claude-plugin/marketplace.json"))["plugins"] if e["name"] == "feature-flow"]
assert len(ent) == 1 and ent[0]["version"] == ver, ent
assert ent[0]["source"] == {"source": "url", "url": "https://github.com/rohitsharma9646/feature-flow.git", "ref": "dist"}, ent[0]["source"]
PY

if [ "$fail" -eq 0 ]; then echo "PASS: claude-dist guard"; else echo "RED: claude-dist guard failed"; fi
exit "$fail"
