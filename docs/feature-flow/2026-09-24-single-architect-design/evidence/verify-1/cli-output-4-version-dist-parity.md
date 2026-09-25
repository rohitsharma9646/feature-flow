# Version sync + dist parity — 2026-09-25T04:39:18Z

## command: jq -r .version .claude-plugin/plugin.json .codex-plugin/plugin.json
0.24.0
0.24.0
exit: 0

## command: jq -r '.plugins[0].version' .claude-plugin/marketplace.json
0.24.0
exit: 0

## command: diff -r commands dist/codex/feature-flow/commands
exit: 0

## command: diff agents/ff-code-architect.md dist/codex/feature-flow/agents/ff-code-architect.md
exit: 0
