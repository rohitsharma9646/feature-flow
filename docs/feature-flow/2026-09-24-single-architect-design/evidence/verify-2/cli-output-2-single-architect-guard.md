# cli-output-2-single-architect-guard.md

kind: cli-output
command: `bash scripts/checks/single-architect-guard.sh` (from /home/netzwelt/feature-flow)
exit status: 0 (PASS)
date: 2026-09-25

## Full output

```
ok:   AC1: commands/ff-design.md has 'dispatch **exactly ONE** `ff-code-architect`'
ok:   AC1: commands/ff-design.md has no /architectAgents/
ok:   AC1: commands/ff-design.md has no /\*\*minimal\*\* —/
ok:   AC2: agents/ff-code-architect.md has '## Weighing approaches'
ok:   AC2: agents/ff-code-architect.md has '## Report format'
ok:   AC2: agents/ff-code-architect.md has '`Recommended: <name of the chosen approach>`'
ok:   AC2: agents/ff-code-architect.md has 'complexity: low|med|high, risk: low|med|high, test effort: low|med|high'
ok:   AC2: agents/ff-code-architect.md has '`one obvious approach — <why>`'
ok:   AC2: agents/ff-code-architect.md has 'Develop **only the best approach in full**'
ok:   AC2: agents/ff-code-architect.md has 'never a strawman'
ok:   FS1: agents/ff-code-architect.md has 'A variant of a detail inside the chosen approach'
ok:   FS1: agents/ff-code-architect.md has '**Report budget.**'
ok:   FS1: agents/ff-code-architect.md has 'about **400 words**'
ok:   FS1: agents/ff-code-architect.md has '**Last check before returning.**'
ok:   FS1: commands/ff-design.md has 'suggest candidate approaches or design sub-choices'
ok:   AC3: agents/ff-code-architect.md has no /sibling/
ok:   AC4: commands/ff-design.md has '**Re-entry check.**'
ok:   AC4: commands/ff-design.md has 'or `<run dir>/architect.md` exists'
ok:   AC4: commands/ff-design.md has 'never re-dispatch for a report that is already on disk'
ok:   AC4: commands/ff-design.md has '**Write the report before the pause.**'
ok:   AC4: commands/ff-design.md has 'then its repo-relative path (`<base>/<slug>/architect.md`)'
ok:   AC4: commands/ff-design.md has 'manifest.artifacts.architect'
ok:   AC4: report written (88) before the choice pause (93), before the devil's-advocate pass (116)
ok:   AC4: docs/manifest-schema.md has '"architect": ".feature-flow/add-oauth/architect.md"'
ok:   AC4: docs/manifest-schema.md has '**`artifacts.architect`** (added v0.24.0)'
ok:   AC4: docs/manifest-schema.md has '`architect` (`ff-design`'s architect report)'
ok:   AC5: commands/ff-design.md has 'Re-dispatch the same `ff-code-architect` **once**'
ok:   AC5: commands/ff-design.md has '## Developed on request: <name>'
ok:   FS3: commands/ff-design.md has 'That appended report is the one the design and decision writes below derive from.'
ok:   AC5: commands/ff-design.md has 'ask the user only to confirm it'
ok:   AC5: commands/ff-design.md has 'if they do not, re-dispatch the same'
ok:   AC4: commands/ff-design.md has 'A confirmed re-run also discards the previous'
ok:   AC4: commands/ff-design.md has 'delete `<run dir>/architect.md` and clear `manifest.artifacts.architect`'
ok:   AC4: commands/ff-design.md has 'skip the pause and resume at the **Do-not-contradict'
ok:   AC7: docs/schema/knowledge-base.md has no /fan-out/
ok:   AC7: skills/feature-flow/SKILL.md has no /before each fan-out/
ok:   AC5: the autopilot design-choice row is unchanged
ok:   AC6: commands/ff-design.md has 'never a second, divergent scoring pass'
ok:   AC6: templates/design.md has 'Score **every option** the architect considered (chosen + rejected)'
ok:   AC6: docs/schema/design-tradeoffs.md has 'scores **every** option the architect considered'
ok:   AC6: templates/design.md has no /fan-out surfaced/
ok:   AC6: docs/schema/design-tradeoffs.md has no /fanned-out option/
ok:   AC7: config/defaults.json has no architectAgents
ok:   AC7: docs/manifest-schema.md has no /`architectAgents`/
ok:   AC7: README.md has no /architectAgents/
ok:   AC7: commands/ff-design.md has no /architects? fan[- ]?out/
ok:   AC7: README.md has no /architects? fan[- ]?out/
ok:   AC7: skills/feature-flow/SKILL.md has no /architects? fan[- ]?out/
ok:   AC7: templates/design.md has no /architects? fan[- ]?out/
ok:   AC7: docs/schema/design-tradeoffs.md has no /architects? fan[- ]?out/
ok:   dist parity: commands/ff-design.md
ok:   dist parity: agents/ff-code-architect.md
ok:   dist parity: docs/manifest-schema.md
ok:   dist parity: templates/design.md
ok:   dist parity: docs/schema/design-tradeoffs.md
ok:   dist parity: config/defaults.json
ok:   dist parity: README.md
ok:   dist parity: skills/feature-flow/SKILL.md
PASS: single-architect guard
EXIT_CODE=0
```
