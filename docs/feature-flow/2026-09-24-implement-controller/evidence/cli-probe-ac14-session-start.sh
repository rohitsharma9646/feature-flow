#!/usr/bin/env bash
# AC14 probe: feed hooks/session-start a compact payload for a temp project with a manifest
# in implement + a ledger (shape per scripts/checks/session-start-guard.sh S11), capture the
# re-anchor naming "task: Task 2 (round 2)".
set -u
cd "$(dirname "$0")/../../.." || exit 2   # evidence -> implement-controller -> .feature-flow -> repo root
HOOK="hooks/session-start"
TMP="$(mktemp -d)"; trap 'rm -rf "$TMP"' EXIT
export CLAUDE_PLUGIN_ROOT="$PWD"
unset CURSOR_PLUGIN_ROOT COPILOT_CLI

d="$TMP/p/.feature-flow/ctl"; mkdir -p "$d"
printf '%s\n' '{"slug":"ctl","track":"feature","tier":"full","currentPhase":"implement","updatedAt":"2026-09-24T10:00:00Z","phases":{"implement":{"status":"in_progress"}},"signOff":{"signed":true},"artifacts":{"ledger":".feature-flow/ctl/tasks/ledger.md"}}' > "$d/manifest.json"
mkdir -p "$TMP/p/.feature-flow/ctl/tasks"
printf '%s\n' '# Ledger — plan: docs/ff/plan.md' '' '## Task 1: First' '**Status:** complete (clean)' '' \
  '## Task 2: Second' '**Status:** in-progress' '**Fix round 1/3:** resumed a1 (sonnet) — 0 ADDRESSED' \
  '**Fix round 2/3:** resumed a1 (sonnet) — pending' '' '## Task 3: Third' > "$TMP/p/.feature-flow/ctl/tasks/ledger.md"

out="$(jq -cn --arg s "compact" --arg c "$TMP/p" '{hook_event_name:"SessionStart", source:$s, cwd:$c}' | bash "$HOOK")"
echo "=== raw hook JSON output ==="
echo "$out"
ctxval="$(printf '%s' "$out" | jq -er '.hookSpecificOutput.additionalContext' 2>/dev/null)"
echo
echo "=== additionalContext ==="
echo "$ctxval"
echo
case "$ctxval" in
  *"task: Task 2 (round 2)"*) echo "FOUND: 'task: Task 2 (round 2)'" ;;
  *) echo "NOT FOUND: 'task: Task 2 (round 2)'" ;;
esac
