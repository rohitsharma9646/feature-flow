#!/usr/bin/env bash
set -euo pipefail

cd "$(dirname "$0")/.."

target="${1:?usage: $0 <target>}"
case "$target" in
  windows-*) exe=ff-integrity-classify.exe ;;
  *) exe=ff-integrity-classify ;;
esac

package_root="dist/integrity/$target"
source_exe="$package_root/source/$exe"
claude_exe="$package_root/claude/bin/$exe"
codex_exe="$package_root/codex/bin/$exe"

mkdir -p "$package_root/source"
go build -trimpath -ldflags='-s -w -buildid=' -o "$source_exe" ./cmd/ff-integrity-classify

for candidate in "$source_exe" "$claude_exe" "$codex_exe"; do
  [[ -f "$candidate" ]] || { echo "FAIL: missing executable $candidate" >&2; exit 1; }
  chmod +x "$candidate" 2>/dev/null || true
done

for input in integrity/testdata/manifests/*; do
  vector="$(basename "$input")"
  "$source_exe" < "$input" > "$package_root/source.out"
  "$claude_exe" < "$input" > "$package_root/claude.out"
  "$codex_exe" < "$input" > "$package_root/codex.out"
  cmp "$package_root/source.out" "$package_root/claude.out" ||
    { echo "FAIL: source/Claude output drift for $vector on $target" >&2; exit 1; }
  cmp "$package_root/source.out" "$package_root/codex.out" ||
    { echo "FAIL: source/Codex output drift for $vector on $target" >&2; exit 1; }
done

echo "PASS: source, Claude package, and Codex package match for every WP1 vector on $target"
