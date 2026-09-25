# single-architect-guard.sh and forward-test-guard.sh (full outputs)

## bash scripts/checks/single-architect-guard.sh
Command: bash scripts/checks/single-architect-guard.sh
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
ok:   FS1: agents/ff-code-architect.md has 'mentions the spec, a requirement, a constraint or a non-goal at all'
ok:   AC2: agents/ff-code-architect.md has 'one physical line — never wrap it'
ok:   FS1: commands/ff-design.md has 'suggest candidate approaches or design sub-choices'
ok:   FS1: commands/ff-design.md has 'Name `<run dir>/architect.md` as its **report path**'
ok:   FS1: commands/ff-design.md has '**do not re-emit it**'
ok:   FS1: commands/ff-design.md has 'only if it does not (the write failed'
ok:   FS1: commands/ff-design.md has '**Screen the rejected list.**'
ok:   FS1: commands/ff-design.md has 'Dropped (contradicts the spec): <name> — <the clause it breaks>'
ok:   AC5: commands/ff-design.md has 'and **no report path**, to develop that'
ok:   AC5: commands/ff-design.md has 'naming no report path'
ok:   FS1: agents/ff-code-architect.md has '**When the caller names a report path**'
ok:   FS1: agents/ff-code-architect.md has 'never create or change any other file'
ok:   FS1: architect has the Write tool for its report
ok:   FS1: architect has no Edit or Bash
ok:   AC3: agents/ff-code-architect.md has no /sibling/
ok:   AC4: commands/ff-design.md has '**Re-entry check.**'
ok:   AC4: commands/ff-design.md has 'or `<run dir>/architect.md` exists'
ok:   AC4: commands/ff-design.md has 'never re-dispatch for a report that is already on disk'
ok:   AC4: commands/ff-design.md has '**Write the report before the pause.**'
ok:   AC4: commands/ff-design.md has 'Then write its repo-relative path (`<base>/<slug>/architect.md`)'
ok:   AC4: commands/ff-design.md has 'manifest.artifacts.architect'
ok:   AC4: report written (89) before the choice pause (102), before the devil's-advocate pass (126)
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
EXIT: 0
```

## bash scripts/checks/forward-test-guard.sh
Command: bash scripts/checks/forward-test-guard.sh
```
ok:   evals/forward/README.md present
ok:   evals/forward/lib.sh present
ok:   evals/forward/decision-conflict/fired: sandbox/ non-empty
ok:   evals/forward/decision-conflict/fired: prompt.txt
ok:   evals/forward/decision-conflict/fired: expected.md
ok:   evals/forward/decision-conflict/fired: assert.sh executable
ok:   evals/forward/decision-conflict/fired: prompt.txt is blind
ok:   evals/forward/decision-conflict/fired/sandbox/.feature-flow/rate-limit/manifest.json: autopilot explicit
ok:   evals/forward/decision-conflict/control: sandbox/ non-empty
ok:   evals/forward/decision-conflict/control: prompt.txt
ok:   evals/forward/decision-conflict/control: expected.md
ok:   evals/forward/decision-conflict/control: assert.sh executable
ok:   evals/forward/decision-conflict/control: prompt.txt is blind
ok:   evals/forward/decision-conflict/control/sandbox/.feature-flow/rate-limit/manifest.json: autopilot explicit
ok:   evals/forward/planning-gap/fired: sandbox/ non-empty
ok:   evals/forward/planning-gap/fired: prompt.txt
ok:   evals/forward/planning-gap/fired: expected.md
ok:   evals/forward/planning-gap/fired: assert.sh executable
ok:   evals/forward/planning-gap/fired: prompt.txt is blind
ok:   evals/forward/planning-gap/fired/sandbox/.feature-flow/csv-export/manifest.json: autopilot explicit
ok:   evals/forward/planning-gap/control: sandbox/ non-empty
ok:   evals/forward/planning-gap/control: prompt.txt
ok:   evals/forward/planning-gap/control: expected.md
ok:   evals/forward/planning-gap/control: assert.sh executable
ok:   evals/forward/planning-gap/control: prompt.txt is blind
ok:   evals/forward/planning-gap/control/sandbox/.feature-flow/csv-export/manifest.json: autopilot explicit
ok:   evals/forward/delivery-gap/fired: sandbox/ non-empty
ok:   evals/forward/delivery-gap/fired: prompt.txt
ok:   evals/forward/delivery-gap/fired: expected.md
ok:   evals/forward/delivery-gap/fired: assert.sh executable
ok:   evals/forward/delivery-gap/fired: prompt.txt is blind
ok:   evals/forward/delivery-gap/fired/sandbox/.feature-flow/greeting-release/manifest.json: autopilot explicit
ok:   evals/forward/delivery-gap/control: sandbox/ non-empty
ok:   evals/forward/delivery-gap/control: prompt.txt
ok:   evals/forward/delivery-gap/control: expected.md
ok:   evals/forward/delivery-gap/control: assert.sh executable
ok:   evals/forward/delivery-gap/control: prompt.txt is blind
ok:   evals/forward/delivery-gap/control/sandbox/.feature-flow/greeting-release/manifest.json: autopilot explicit
ok:   evals/forward/assumption-gap/fired: sandbox/ non-empty
ok:   evals/forward/assumption-gap/fired: prompt.txt
ok:   evals/forward/assumption-gap/fired: expected.md
ok:   evals/forward/assumption-gap/fired: assert.sh executable
ok:   evals/forward/assumption-gap/fired: prompt.txt is blind
ok:   evals/forward/assumption-gap/fired/sandbox/.feature-flow/ts-locale/manifest.json: autopilot explicit
ok:   evals/forward/assumption-gap/control: sandbox/ non-empty
ok:   evals/forward/assumption-gap/control: prompt.txt
ok:   evals/forward/assumption-gap/control: expected.md
ok:   evals/forward/assumption-gap/control: assert.sh executable
ok:   evals/forward/assumption-gap/control: prompt.txt is blind
ok:   evals/forward/assumption-gap/control/sandbox/.feature-flow/ts-locale/manifest.json: autopilot explicit
ok:   evals/forward/design-gap/fired: sandbox/ non-empty
ok:   evals/forward/design-gap/fired: prompt.txt
ok:   evals/forward/design-gap/fired: expected.md
ok:   evals/forward/design-gap/fired: assert.sh executable
ok:   evals/forward/design-gap/fired: prompt.txt is blind
ok:   evals/forward/design-gap/fired/sandbox/.feature-flow/url-slugs/manifest.json: autopilot explicit
ok:   evals/forward/design-gap/control: sandbox/ non-empty
ok:   evals/forward/design-gap/control: prompt.txt
ok:   evals/forward/design-gap/control: expected.md
ok:   evals/forward/design-gap/control: assert.sh executable
ok:   evals/forward/design-gap/control: prompt.txt is blind
ok:   evals/forward/design-gap/control/sandbox/.feature-flow/url-slugs/manifest.json: autopilot explicit
ok:   evals/forward/repair-gap/fired: sandbox/ non-empty
ok:   evals/forward/repair-gap/fired: prompt.txt
ok:   evals/forward/repair-gap/fired: expected.md
ok:   evals/forward/repair-gap/fired: assert.sh executable
ok:   evals/forward/repair-gap/fired: prompt.txt is blind
ok:   evals/forward/repair-gap/fired/sandbox/.feature-flow/url-slugs/manifest.json: autopilot explicit
ok:   evals/forward/repair-gap/control: sandbox/ non-empty
ok:   evals/forward/repair-gap/control: prompt.txt
ok:   evals/forward/repair-gap/control: expected.md
ok:   evals/forward/repair-gap/control: assert.sh executable
ok:   evals/forward/repair-gap/control: prompt.txt is blind
ok:   evals/forward/repair-gap/control/sandbox/.feature-flow/url-slugs/manifest.json: autopilot explicit
ok:   evals/forward/discovery-gap/fired: sandbox/ non-empty
ok:   evals/forward/discovery-gap/fired: prompt.txt
ok:   evals/forward/discovery-gap/fired: expected.md
ok:   evals/forward/discovery-gap/fired: assert.sh executable
ok:   evals/forward/discovery-gap/fired: prompt.txt is blind
ok:   evals/forward/discovery-gap/fired/sandbox/.feature-flow/url-slugs/manifest.json: autopilot explicit
ok:   evals/forward/discovery-gap/control: sandbox/ non-empty
ok:   evals/forward/discovery-gap/control: prompt.txt
ok:   evals/forward/discovery-gap/control: expected.md
ok:   evals/forward/discovery-gap/control: assert.sh executable
ok:   evals/forward/discovery-gap/control: prompt.txt is blind
ok:   evals/forward/discovery-gap/control/sandbox/.feature-flow/url-slugs/manifest.json: autopilot explicit
ok:   evals/forward/implement-controller/fired: sandbox/ non-empty
ok:   evals/forward/implement-controller/fired: prompt.txt
ok:   evals/forward/implement-controller/fired: expected.md
ok:   evals/forward/implement-controller/fired: assert.sh executable
ok:   evals/forward/implement-controller/fired: prompt.txt is blind
ok:   evals/forward/implement-controller/fired/sandbox/.feature-flow/text-tools/manifest.json: autopilot explicit
ok:   evals/forward/implement-controller/control: sandbox/ non-empty
ok:   evals/forward/implement-controller/control: prompt.txt
ok:   evals/forward/implement-controller/control: expected.md
ok:   evals/forward/implement-controller/control: assert.sh executable
ok:   evals/forward/implement-controller/control: prompt.txt is blind
ok:   evals/forward/implement-controller/control/sandbox/.feature-flow/text-tools/manifest.json: autopilot explicit
ok:   evals/forward/single-architect/fired: sandbox/ non-empty
ok:   evals/forward/single-architect/fired: prompt.txt
ok:   evals/forward/single-architect/fired: expected.md
ok:   evals/forward/single-architect/fired: assert.sh executable
ok:   evals/forward/single-architect/fired: prompt.txt is blind
ok:   evals/forward/single-architect/fired/sandbox/.feature-flow/rate-limit/manifest.json: autopilot explicit
ok:   evals/forward/single-architect/control: sandbox/ non-empty
ok:   evals/forward/single-architect/control: prompt.txt
ok:   evals/forward/single-architect/control: expected.md
ok:   evals/forward/single-architect/control: assert.sh executable
ok:   evals/forward/single-architect/control: prompt.txt is blind
ok:   evals/forward/single-architect/control/sandbox/.feature-flow/version-flag/manifest.json: autopilot explicit
ok:   evals/forward/architect-pick/fired: sandbox/ non-empty
ok:   evals/forward/architect-pick/fired: prompt.txt
ok:   evals/forward/architect-pick/fired: expected.md
ok:   evals/forward/architect-pick/fired: assert.sh executable
ok:   evals/forward/architect-pick/fired: prompt.txt is blind
ok:   evals/forward/architect-pick/fired/sandbox/.feature-flow/rate-limit/manifest.json: autopilot explicit
ok:   evals/forward/architect-pick/control: sandbox/ non-empty
ok:   evals/forward/architect-pick/control: prompt.txt
ok:   evals/forward/architect-pick/control: expected.md
ok:   evals/forward/architect-pick/control: assert.sh executable
ok:   evals/forward/architect-pick/control: prompt.txt is blind
ok:   evals/forward/architect-pick/control/sandbox/.feature-flow/rate-limit/manifest.json: autopilot explicit
ok:   evals/forward/architect-decline/fired: sandbox/ non-empty
ok:   evals/forward/architect-decline/fired: prompt.txt
ok:   evals/forward/architect-decline/fired: expected.md
ok:   evals/forward/architect-decline/fired: assert.sh executable
ok:   evals/forward/architect-decline/fired: prompt.txt is blind
ok:   evals/forward/architect-decline/fired/sandbox/.feature-flow/version-flag/manifest.json: autopilot explicit
ok:   evals/forward/architect-decline/control: sandbox/ non-empty
ok:   evals/forward/architect-decline/control: prompt.txt
ok:   evals/forward/architect-decline/control: expected.md
ok:   evals/forward/architect-decline/control: assert.sh executable
ok:   evals/forward/architect-decline/control: prompt.txt is blind
ok:   evals/forward/architect-decline/control/sandbox/.feature-flow/version-flag/manifest.json: autopilot explicit
ok:   .gitignore: planted sandbox run state is committable
ok:   scripts/forward-test.sh present + executable
ok:   no forward-test runner under scripts/checks/
ok:   Codex dist excludes evals/
ok:   Codex dist excludes the runner
PASS: forward-test guard
EXIT: 0
```
