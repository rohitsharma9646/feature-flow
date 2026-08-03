#!/usr/bin/env bash
set -euo pipefail

cd "$(dirname "$0")/.."

target="${1:?usage: $0 <target>}"
case "$target" in
  windows-*) exe=ff-integrity-classify.exe; integrity_exe=ff-integrity.exe ;;
  *) exe=ff-integrity-classify; integrity_exe=ff-integrity ;;
esac

integrity_dist_root="${FF_INTEGRITY_DIST_ROOT:-dist/integrity}"
package_root="$integrity_dist_root/$target"
source_exe="$package_root/source/$exe"
claude_exe="$package_root/claude/bin/$exe"
codex_exe="$package_root/codex/bin/$exe"
source_integrity="$package_root/source/$integrity_exe"
claude_integrity="$package_root/claude/bin/$integrity_exe"
codex_integrity="$package_root/codex/bin/$integrity_exe"

mkdir -p "$package_root/source"
go build -trimpath -ldflags='-s -w -buildid=' -o "$source_exe" ./cmd/ff-integrity-classify
go build -trimpath -ldflags='-s -w -buildid=' -o "$source_integrity" ./cmd/ff-integrity

for candidate in "$source_exe" "$claude_exe" "$codex_exe" \
  "$source_integrity" "$claude_integrity" "$codex_integrity"; do
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

fixture_root="$package_root/wp2-fixture"
rm -rf "$fixture_root"
mkdir -p "$fixture_root/legacy"
cp integrity/testdata/manifests/legacy.json "$fixture_root/legacy/manifest.json"
for format in human json; do
  "$source_integrity" doctor --root "$fixture_root" --format "$format" legacy > "$package_root/source-doctor.out" || test "$?" -eq 1
  "$claude_integrity" doctor --root "$fixture_root" --format "$format" legacy > "$package_root/claude-doctor.out" || test "$?" -eq 1
  "$codex_integrity" doctor --root "$fixture_root" --format "$format" legacy > "$package_root/codex-doctor.out" || test "$?" -eq 1
  cmp "$package_root/source-doctor.out" "$package_root/claude-doctor.out"
  cmp "$package_root/source-doctor.out" "$package_root/codex-doctor.out"
done
"$source_integrity" migrate --root "$fixture_root" --to 1 --dry-run --format json legacy > "$package_root/source-plan.out"
"$claude_integrity" migrate --root "$fixture_root" --to 1 --dry-run --format json legacy > "$package_root/claude-plan.out"
"$codex_integrity" migrate --root "$fixture_root" --to 1 --dry-run --format json legacy > "$package_root/codex-plan.out"
cmp "$package_root/source-plan.out" "$package_root/claude-plan.out"
cmp "$package_root/source-plan.out" "$package_root/codex-plan.out"

for operation in revision converge; do
  case "$operation" in
    revision) input="integrity/testdata/revision/v1/canonical/basic.json" ;;
    converge) input="integrity/testdata/revision/v1/convergence/ready.json" ;;
  esac
  "$source_integrity" "$operation" --input "$input" > "$package_root/source-wp3-$operation.out"
  "$claude_integrity" "$operation" --input "$input" > "$package_root/claude-wp3-$operation.out"
  "$codex_integrity" "$operation" --input "$input" > "$package_root/codex-wp3-$operation.out"
  cmp "$package_root/source-wp3-$operation.out" "$package_root/claude-wp3-$operation.out"
  cmp "$package_root/source-wp3-$operation.out" "$package_root/codex-wp3-$operation.out"
done

for host in direct claude codex; do
  set +e
  "$source_integrity" capabilities --host "$host" --format json > "$package_root/source-capabilities-$host.out"
  source_status=$?
  "$claude_integrity" capabilities --host "$host" --format json > "$package_root/claude-capabilities-$host.out"
  claude_status=$?
  "$codex_integrity" capabilities --host "$host" --format json > "$package_root/codex-capabilities-$host.out"
  codex_status=$?
  set -e
  test "$source_status" -eq "$claude_status"
  test "$source_status" -eq "$codex_status"
  cmp "$package_root/source-capabilities-$host.out" "$package_root/claude-capabilities-$host.out"
  cmp "$package_root/source-capabilities-$host.out" "$package_root/codex-capabilities-$host.out"
done

wp4_fixture="$package_root/wp4-fixture"
rm -rf "$wp4_fixture"
mkdir -p "$wp4_fixture"
bash scripts/check-integrity-wp4-five-path.sh \
  "$wp4_fixture" \
  "$source_integrity" "$source_integrity" "$source_integrity" \
  "$claude_integrity" "$codex_integrity"
wp4_vectors=(
  allowed-feature denied-feature allowed-bugfix denied-bugfix legacy malformed-current
  terminal-incomplete duplicate payload-spoof unrelated
)

case "$target" in
  windows-*)
    command -v cmd.exe >/dev/null 2>&1 ||
      { echo "FAIL: native Windows cmd.exe is unavailable" >&2; exit 1; }
    command -v cygpath >/dev/null 2>&1 ||
      { echo "FAIL: native Windows path conversion is unavailable" >&2; exit 1; }
    jq -e '
      .hooks.PreToolUse[0].hooks[0].commandWindows ==
      "\"%PLUGIN_ROOT%\\adapters\\codex\\hooks\\run-integrity.cmd\""
    ' "$package_root/codex/adapters/codex/hooks/hooks.json" >/dev/null
    jq -e '
      .hooks.PreToolUse[0].hooks[0].command |
      contains("/hooks/run-hook.cmd")
    ' "$package_root/claude/hooks/hooks.json" >/dev/null
    claude_launcher="$(cygpath -aw "$package_root/claude/hooks/run-hook.cmd")"
    codex_launcher="$(cygpath -aw "$package_root/codex/adapters/codex/hooks/run-integrity.cmd")"
    codex_root="$(cygpath -aw "$package_root/codex")"
    for vector in "${wp4_vectors[@]}"; do
      if [[ "$vector" == "legacy" ]]; then
        cp "$wp4_fixture/legacy.json" "$wp4_fixture/repo/.feature-flow/run/manifest.json"
      elif [[ "$vector" == *bugfix ]]; then
        cp "$wp4_fixture/current-bugfix.json" "$wp4_fixture/repo/.feature-flow/run/manifest.json"
      else
        cp "$wp4_fixture/current.json" "$wp4_fixture/repo/.feature-flow/run/manifest.json"
      fi
      cmd.exe //d //c call "$claude_launcher" enforce-gate \
        < "$wp4_fixture/$vector-claude.json" \
        > "$wp4_fixture/$vector-installed-claude.out"
      PLUGIN_ROOT="$codex_root" \
        cmd.exe //d //c call "$codex_launcher" \
        < "$wp4_fixture/$vector-codex.json" \
        > "$wp4_fixture/$vector-installed-codex.out"
      cmp "$wp4_fixture/$vector-packaged-claude.out" \
        "$wp4_fixture/$vector-installed-claude.out"
      cmp "$wp4_fixture/$vector-packaged-codex.out" \
        "$wp4_fixture/$vector-installed-codex.out"
    done
    ;;
  *)
    jq -e '
      .hooks.PreToolUse[0].hooks[0].command |
      contains("/hooks/run-hook.cmd")
    ' "$package_root/claude/hooks/hooks.json" >/dev/null
    jq -e '
      .hooks.PreToolUse[0].hooks[0].command |
      contains("/adapters/codex/hooks/run-integrity")
    ' "$package_root/codex/adapters/codex/hooks/hooks.json" >/dev/null
    chmod +x "$package_root/claude/hooks/enforce-gate" "$package_root/claude/hooks/run-hook.cmd" \
      "$package_root/codex/adapters/codex/hooks/run-integrity"
    for vector in "${wp4_vectors[@]}"; do
      if [[ "$vector" == "legacy" ]]; then
        cp "$wp4_fixture/legacy.json" "$wp4_fixture/repo/.feature-flow/run/manifest.json"
      elif [[ "$vector" == *bugfix ]]; then
        cp "$wp4_fixture/current-bugfix.json" "$wp4_fixture/repo/.feature-flow/run/manifest.json"
      else
        cp "$wp4_fixture/current.json" "$wp4_fixture/repo/.feature-flow/run/manifest.json"
      fi
      "$package_root/claude/hooks/run-hook.cmd" enforce-gate \
        < "$wp4_fixture/$vector-claude.json" \
        > "$wp4_fixture/$vector-installed-claude.out"
      PLUGIN_ROOT="$package_root/codex" \
        "$package_root/codex/adapters/codex/hooks/run-integrity" \
        < "$wp4_fixture/$vector-codex.json" \
        > "$wp4_fixture/$vector-installed-codex.out"
      cmp "$wp4_fixture/$vector-packaged-claude.out" \
        "$wp4_fixture/$vector-installed-claude.out"
      cmp "$wp4_fixture/$vector-packaged-codex.out" \
        "$wp4_fixture/$vector-installed-codex.out"
    done
    ;;
esac

echo "PASS: source, Claude package, and Codex package match for WP1-WP4 vectors on $target"
