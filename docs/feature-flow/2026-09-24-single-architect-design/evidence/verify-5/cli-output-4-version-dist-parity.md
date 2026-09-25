# Version + dist parity

## Plugin versions
Command: grep version in .claude-plugin/plugin.json, .codex-plugin/plugin.json, .claude-plugin/marketplace.json
```
=== plugin versions ===
-- .claude-plugin/plugin.json --
  "version": "0.24.0",
-- .codex-plugin/plugin.json --
  "version": "0.24.0",
-- .claude-plugin/marketplace.json --
      "version": "0.24.0",
```
All three report 0.24.0 (matches version-sync-guard.sh PASS in cli-output-1).

## diff -r commands dist/codex/feature-flow/commands
Command: diff -r commands dist/codex/feature-flow/commands
Exit: 0 (no output — trees identical)

## diff agents/ff-code-architect.md dist/codex/feature-flow/agents/ff-code-architect.md
Exit: 0 (no output — files identical)

## diff skills/feature-flow/references/codex-tools.md dist/codex/feature-flow/skills/feature-flow/references/codex-tools.md
Exit: 0 (no output — files identical)

## diff docs/manifest-schema.md dist/codex/feature-flow/docs/manifest-schema.md
Exit: 0 (no output — files identical)

## Full raw output
```
=== plugin versions ===
-- .claude-plugin/plugin.json --
  "version": "0.24.0",
-- .codex-plugin/plugin.json --
  "version": "0.24.0",
-- .claude-plugin/marketplace.json --
      "version": "0.24.0",

=== diff -r commands dist/codex/feature-flow/commands ===
diff exit: 0

=== diff agents/ff-code-architect.md vs dist ===
diff exit: 0

=== diff skills/feature-flow/references/codex-tools.md vs dist ===
diff exit: 0

=== diff docs/manifest-schema.md vs dist ===
diff exit: 0
```
