#!/usr/bin/env bash
# Comprehensive source<->dist parity guard.
#
# Every file packaged into dist/codex/feature-flow/ must be byte-identical to its source
# counterpart. The Codex build (scripts/package-codex-plugin.sh) is a verbatim COPY of the
# source — no transform — so any source edit that isn't re-packaged silently drifts the two,
# and Codex users get stale behavior. The other guards spot-check only a handful of files;
# this one checks the WHOLE packaged surface, so a future edit to any packaged file is caught.
#
# Fresh clone: dist/ is gitignored and absent on checkout, so run the packager first
# (CI does this before the guards; see .github/workflows/ci.yml).
set -u
cd "$(dirname "$0")/../.." || exit 2

DIST="dist/codex/feature-flow"
fail=0
err() { echo "FAIL: $1"; fail=1; }
ok()  { echo "ok:   $1"; }

if [ ! -d "$DIST" ]; then
  echo "RED: $DIST is missing — run scripts/package-codex-plugin.sh first"
  echo "     (the Codex package is gitignored; CI builds it before running the guards)."
  exit 1
fi

count=0 drift=0 orphan=0
while IFS= read -r distfile; do
  rel="${distfile#"$DIST"/}"
  count=$((count + 1))
  if [ ! -f "$rel" ]; then
    err "dist file has no source counterpart: $rel (a stale copy? re-run the packager)"
    orphan=$((orphan + 1))
  elif ! cmp -s "$rel" "$distfile"; then
    err "drift: $rel differs from $DIST/$rel (re-run scripts/package-codex-plugin.sh)"
    drift=$((drift + 1))
  fi
done < <(find "$DIST" -type f | sort)

ok "checked $count packaged files ($drift drifted, $orphan orphaned)"
if [ "$fail" -eq 0 ]; then
  echo "PASS: dist parity guard ($count files in sync)"
else
  echo "RED: dist parity guard failed"
  exit 1
fi
