# cli-output-4-version-dist-parity.md

kind: cli-output
commands run (from /home/netzwelt/feature-flow):
1. `jq -r .version .claude-plugin/plugin.json`
2. `jq -r .version .codex-plugin/plugin.json`
3. `jq -r '.plugins[] | select(.name=="feature-flow") | .version' .claude-plugin/marketplace.json`
4. `diff -r commands dist/codex/feature-flow/commands`
5. `diff agents/ff-code-architect.md dist/codex/feature-flow/agents/ff-code-architect.md`
date: 2026-09-25

## Versions

| File | Version | Expected |
|---|---|---|
| .claude-plugin/plugin.json | 0.24.0 | 0.24.0 |
| .codex-plugin/plugin.json | 0.24.0 | 0.24.0 |
| .claude-plugin/marketplace.json (plugins[].version, name=feature-flow) | 0.24.0 | 0.24.0 |

All three match the expected 0.24.0. marketplace.json full plugin entry:

```json
{
  "name": "feature-flow",
  "source": {
    "source": "url",
    "url": "https://github.com/rohitsharma9646/feature-flow.git",
    "ref": "dist"
  },
  "version": "0.24.0",
  "description": "Gated, resumable feature-development and test-first bugfix workflow with on-disk run state and real executed verification."
}
```

## `diff -r commands dist/codex/feature-flow/commands`

Exit status: 0 (no output — directories identical)

## `diff agents/ff-code-architect.md dist/codex/feature-flow/agents/ff-code-architect.md`

Exit status: 0 (no output — files identical)

## Verdict

Version and dist parity confirmed: all three version sources report 0.24.0, and both diffs
(commands directory, ff-code-architect.md) are empty with exit 0.
