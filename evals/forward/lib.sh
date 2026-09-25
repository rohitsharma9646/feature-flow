# Shared helpers for evals/forward/*/*/assert.sh — sourced, never run directly.
# Every assert.sh is called as: assert.sh <tmpdir> <run.json>
# and must exit 0 (behaved as expected) or 1 (did not). Anything else is reported ERROR.
set -u
T="${1:?usage: assert.sh <tmpdir> <run.json>}"
RUN="${2:?usage: assert.sh <tmpdir> <run.json>}"
fail=0
ok()  { echo "  ok:   $1"; }
bad() { echo "  FAIL: $1"; fail=1; }
done_() { [ "$fail" -eq 0 ] && exit 0 || exit 1; }

# m <slug> <jq-filter> — query the run's manifest
m() { jq -r "$2" "$T/.feature-flow/$1/manifest.json" 2>/dev/null; }
# artifact <slug> <name> — absolute path of manifest.artifacts.<name> ("" if unset)
artifact() {
  local p; p="$(m "$1" ".artifacts.$2 // empty")"
  [ -n "$p" ] || return 0
  case "$p" in /*) echo "$p" ;; *) echo "$T/$p" ;; esac
}
# result_text — the session's final message
result_text() { jq -r '.result // ""' "$RUN" 2>/dev/null; }
# changed_outside_ff — tracked/untracked changes outside .feature-flow/ (source writes)
changed_outside_ff() { git -C "$T" status --porcelain -uall | grep -v ' \.feature-flow/' | grep -v ' \.feature-flow\.json$' || true; }
# section <file> <heading-regex> — body of one markdown section (heading line included)
section() { awk -v h="$2" '$0 ~ "^#+ " && f {exit} $0 ~ h {f=1} f' "$1"; }
# keywords <name> — the distinctive words of an approach name (lowercase, >= 5 chars, no filler),
# one per line. distinct <a> <b> — keywords of <a> that <b> lacks (what tells a from b).
# mentions_any <text-file> <words...> — true when the file mentions any of the words.
keywords() {
  printf '%s\n' "$1" | tr 'A-Z' 'a-z' | tr -c 'a-z0-9' '\n' | awk 'length($0) >= 5' \
    | grep -vxE 'approach|based|using|instead|single|simple|simpler|write|writes|files|caller|guarded|atomic|script|dedicated|branch|lookup|small|plain' \
    | sort -u || true
}
distinct() { comm -23 <(keywords "$1") <(keywords "$2"); }
mentions_any() { local f="$1" w; shift; for w in "$@"; do grep -qiF -- "$w" "$f" && return 0; done; return 1; }
