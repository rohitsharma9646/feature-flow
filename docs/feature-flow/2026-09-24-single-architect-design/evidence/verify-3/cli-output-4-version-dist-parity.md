# cli-output-4-version-dist-parity.md

kind: cli-output
date: 2026-09-25 (third pass)

## Plugin versions

```
$ grep -h version .claude-plugin/plugin.json .codex-plugin/plugin.json .claude-plugin/marketplace.json
      "version": "0.24.0",
  "version": "0.24.0",
  "version": "0.24.0",
```

All three read `0.24.0` — matches the expected version.

## dist parity diffs

```
$ diff -r commands dist/codex/feature-flow/commands; echo "exit=$?"
exit=0

$ diff agents/ff-code-architect.md dist/codex/feature-flow/agents/ff-code-architect.md; echo "exit=$?"
exit=0

$ diff skills/feature-flow/references/codex-tools.md dist/codex/feature-flow/skills/feature-flow/references/codex-tools.md; echo "exit=$?"
exit=0
```

All three diffs are empty (exit 0) — commands/, ff-code-architect.md, and codex-tools.md are byte-identical between the Claude source and the dist/codex mirror.
