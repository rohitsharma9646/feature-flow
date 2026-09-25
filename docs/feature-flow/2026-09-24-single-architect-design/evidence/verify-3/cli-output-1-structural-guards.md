# cli-output-1-structural-guards.md

kind: cli-output
command: `for f in scripts/checks/*.sh; do bash "$f"; echo EXIT_CODE=$?; done` (run from repo root /home/netzwelt/feature-flow), integrity-conformance-guard.sh run separately
date: 2026-09-25 (third pass / after user-directed gap fix, tier: full)

## Summary of exit codes

| Guard | Exit |
|---|---|
| assumption-guard.sh | 0 |
| claude-dist-guard.sh | 0 |
| decision-record-guard.sh | 0 |
| delivery-guard.sh | 0 |
| design-tradeoff-guard.sh | 0 |
| discovery-fields-guard.sh | 0 |
| dist-parity-guard.sh | 0 |
| durable-paths-guard.sh | 0 |
| enforce-gate-guard.sh | 0 |
| evidence-guard.sh | 0 |
| forward-test-guard.sh | 0 |
| fresh-context-interview-guard.sh | 0 |
| implement-controller-guard.sh | 0 |
| integrity-boundary-guard.sh | 0 |
| integrity-conformance-guard.sh | **1 (FAIL, expected — requires Go)** |
| integrity-wp2-guard.sh | 0 |
| kb-guard.sh | 0 |
| lite-tier-guard.sh | 0 |
| planning-intelligence-guard.sh | 0 |
| repair-loop-guard.sh | 0 |
| retro-guard.sh | 0 |
| revision-binding-guard.sh | 0 |
| run-start-ask-guard.sh | 0 |
| schema-layout-guard.sh | 0 |
| session-start-guard.sh | 0 |
| single-architect-guard.sh | 0 |
| spec-conformance-guard.sh | 0 |
| version-sync-guard.sh | 0 |

All 27 guards pass with exit 0 except `integrity-conformance-guard.sh`, which fails with exit 1
because the Go toolchain is not installed in this environment.

## `command -v go`

```
$ command -v go; echo "go_exit=$?"
go_exit=1
```
`go` is not on PATH (exit 1 — command not found), confirming the guard's failure is the expected
environment limitation, not a regression.

## Full output (all guards, in glob order)

```
=== assumption-guard.sh ===
ok:   templates/spec.md: Assumptions is the 5-column table
ok:   templates/diagnosis.md: Assumptions is the identical 5-column table
ok:   templates/diagnosis.md: Assumptions carries the full-tier-only banner
ok:   templates/diagnosis.md: '## Assumptions' sits after '## Fix approach' and before '## Fix surface'
ok:   commands/ff-clarify.md: Beat 4 writes each assumption as a table row
ok:   commands/ff-clarify.md: names the Validation-required field
ok:   commands/ff-diagnose.md: full-tier fix-approach step surfaces assumption rows
ok:   commands/ff-diagnose.md: lite tier explicitly skips the assumptions table
ok:   docs/manifest-schema.md + docs/schema/ §Sign-off rendering: is 'Three rules'
ok:   docs/manifest-schema.md + docs/schema/ §Sign-off rendering: rule 3 echo is a distinct block, never folded into the AC checkboxes
ok:   docs/manifest-schema.md + docs/schema/ §Sign-off rendering: carries a worked '### Unvalidated assumptions' example
ok:   docs/manifest-schema.md + docs/schema/: carries the verbatim waiver line
ok:   commands/ff-clarify.md: carries the verbatim waiver line
ok:   commands/ff-diagnose.md: carries the verbatim waiver line
ok:   docs/manifest-schema.md + docs/schema/ §Autopilot: has the 'Assumption validation stop' row
ok:   docs/manifest-schema.md + docs/schema/: '## Assumption records' canonical section present
ok:   docs/manifest-schema.md + docs/schema/ §Assumption records: '### Row schema' present
ok:   docs/manifest-schema.md + docs/schema/ §Assumption records: '### Tier / track scope' present
ok:   docs/manifest-schema.md + docs/schema/ §Assumption records: '### Trigger' present
ok:   docs/manifest-schema.md + docs/schema/ §Assumption records: '### Actuation 1' present
ok:   docs/manifest-schema.md + docs/schema/ §Assumption records: '### Actuation 2' present
ok:   docs/manifest-schema.md + docs/schema/ §Assumption records: '### Waiver' present
ok:   docs/manifest-schema.md + docs/schema/ §Assumption records: '### v1 non-goals' present
ok:   docs/manifest-schema.md + docs/schema/ §Assumption records: Actuation 1 names the third gate exit (acknowledge-open)
ok:   docs/manifest-schema.md + docs/schema/ §Assumption records: Waiver marks the row `n` (waived vs acknowledged-open disambiguated on disk)
ok:   templates/plan.md: documents the '**Validates:** Assumption N' mapping rule
ok:   templates/plan.md: carries a '**Validates:** Assumption <n>' task example
ok:   commands/ff-plan.md: emits a '**Validates:** Assumption N' validation task
ok:   commands/ff-plan.md: assumption-mapping bullet sits between AC-map (75) and Derive planning intelligence (104)
ok:   dist parity: templates/spec.md
ok:   dist parity: templates/diagnosis.md
ok:   dist parity: templates/plan.md
ok:   dist parity: docs/manifest-schema.md
ok:   dist parity: docs/schema/assumption-records.md
ok:   dist parity: docs/schema/autopilot.md
ok:   dist parity: docs/schema/delivery.md
ok:   dist parity: docs/schema/design-tradeoffs.md
ok:   dist parity: docs/schema/discovery-fields.md
ok:   dist parity: docs/schema/disk-inference.md
ok:   dist parity: docs/schema/enforcement.md
ok:   dist parity: docs/schema/evidence.md
ok:   dist parity: docs/schema/knowledge-base.md
ok:   dist parity: docs/schema/planning-intelligence.md
ok:   dist parity: docs/schema/retrospective.md
ok:   dist parity: docs/schema/sign-off-rendering.md
ok:   dist parity: docs/schema/task-controller.md
ok:   dist parity: docs/schema/terminal-convergence.md
ok:   dist parity: commands/ff-clarify.md
ok:   dist parity: commands/ff-diagnose.md
ok:   dist parity: commands/ff-plan.md
PASS: assumption-records guard
EXIT_CODE=0
=== claude-dist-guard.sh ===
ok:   top-level entries are exactly the allowlist
ok:   docs/ holds only manifest-schema.md + schema/ + grilling-playbook.md
ok:   docs/schema/ holds exactly the 14 topic files
ok:   .claude-plugin/ holds only plugin.json + marketplace.json
ok:   no dev-only files in the package
ok:   every ${CLAUDE_PLUGIN_ROOT} reference resolves inside the package
ok:   packaged marketplace.json: feature-flow from "./" at the plugin.json version
ok:   master marketplace.json: plugin source = url https …feature-flow.git @ ref dist, version synced
PASS: claude-dist guard
EXIT_CODE=0
=== decision-record-guard.sh ===
ok:   templates/decision.md: present
ok:   templates/decision.md: section '## Decision' present
ok:   templates/decision.md: section '## Context' present
ok:   templates/decision.md: section '## Options considered' present
ok:   templates/decision.md: section '## Trade-offs' present
ok:   templates/decision.md: section '## Chosen \+ rationale' present
ok:   templates/decision.md: section '## Outcome' present
ok:   templates/decision.md: section '## Future considerations' present
ok:   templates/decision.md: carries '**Related ACs:**'
ok:   templates/decision.md: carries '**Related files:**'
ok:   templates/decision.md: carries '| Option | Effort | Risk | Reversibility |'
ok:   templates/decision.md: frontmatter field tags present
ok:   templates/decision.md: frontmatter field referencedFiles present
ok:   docs/manifest-schema.md + docs/schema/: durable-artifacts list present
ok:   docs/manifest-schema.md + docs/schema/: durable list includes decision
ok:   docs/manifest-schema.md + docs/schema/: disk-inference tuple includes decision
ok:   docs/manifest-schema.md + docs/schema/: documents artifacts.decision
ok:   docs/manifest-schema.md + docs/schema/: artifacts.decision absent-field default documented
ok:   docs/manifest-schema.md + docs/schema/: '### Decision recall' canonical subsection present
ok:   docs/manifest-schema.md + docs/schema/: names the Decision override by user (<date>) recording
ok:   commands/ff-design.md: records artifacts.decision
ok:   commands/ff-design.md: writes the decision from templates/decision.md
ok:   commands/ff-design.md: do-not-contradict STOP instruction present (AC4/AC8)
ok:   commands/ff-implement.md: do-not-contradict STOP instruction present (AC5/AC8)
ok:   commands/ff-implement.md: has a '## Decision recall' section
ok:   commands/ff-implement.md §Decision recall: resolves via artifacts.decision
ok:   commands/ff-implement.md §Decision recall: cross-run half gates on toggles.kb
ok:   commands/ff-implement.md §Decision recall: STOP is unconditional in both modes
ok:   commands/ff-implement.md: '## Decision recall' (78) sits between Cold-start (52) and Do the work (244)
ok:   commands/ff-clarify.md: lite branch sets artifacts.decision
ok:   docs/manifest-schema.md + docs/schema/ §Autopilot: has the Decision conflict stop row
ok:   docs/manifest-schema.md + docs/schema/ §Autopilot: Decision conflict stop is unconditional
ok:   dist parity: templates/decision.md
ok:   dist parity: docs/manifest-schema.md
ok:   dist parity: docs/schema/assumption-records.md
ok:   dist parity: docs/schema/autopilot.md
ok:   dist parity: docs/schema/delivery.md
ok:   dist parity: docs/schema/design-tradeoffs.md
ok:   dist parity: docs/schema/discovery-fields.md
ok:   dist parity: docs/schema/disk-inference.md
ok:   dist parity: docs/schema/enforcement.md
ok:   dist parity: docs/schema/evidence.md
ok:   dist parity: docs/schema/knowledge-base.md
ok:   dist parity: docs/schema/planning-intelligence.md
ok:   dist parity: docs/schema/retrospective.md
ok:   dist parity: docs/schema/sign-off-rendering.md
ok:   dist parity: docs/schema/task-controller.md
ok:   dist parity: docs/schema/terminal-convergence.md
ok:   dist parity: commands/ff-design.md
ok:   dist parity: commands/ff-implement.md
ok:   dist parity: commands/ff-clarify.md
PASS: decision-record guard
EXIT_CODE=0
=== delivery-guard.sh ===
ok:   templates/delivery.md: six sections present, in order
ok:   templates/delivery.md: 'Release notes' carries a '> ' source blockquote
ok:   templates/delivery.md: 'Rollback checklist' carries a '> ' source blockquote
ok:   templates/delivery.md: 'Known issues' carries a '> ' source blockquote
ok:   templates/delivery.md: 'Release validation steps' carries a '> ' source blockquote
ok:   commands/ff-deliver.md: resolves via artifacts.spec
ok:   commands/ff-deliver.md: resolves via artifacts.plan
ok:   commands/ff-deliver.md: resolves via artifacts.verify
ok:   commands/ff-deliver.md: writes phases.deliver
ok:   commands/ff-deliver.md: records artifacts.delivery
ok:   commands/ff-deliver.md: leaves currentPhase = "done"
ok:   commands/ff-deliver.md: manual / non-gated (autopilot never chains it)
ok:   commands/ff-deliver.md: gates off tier: lite unless requested
ok:   commands/ff-deliver.md: states it never blocks done
ok:   commands/ff-deliver.md: carries the DELIVERY GAP detection
ok:   commands/ff-deliver.md: excludes an irreversible-with-mitigation task from the gap
ok:   docs/manifest-schema.md + docs/schema/: '## Delivery' section present
ok:   docs/manifest-schema.md + docs/schema/ §Delivery: documents phases.deliver
ok:   docs/manifest-schema.md + docs/schema/ §Delivery: documents artifacts.delivery
ok:   docs/manifest-schema.md + docs/schema/ §Delivery: states the absent-field default
ok:   docs/manifest-schema.md + docs/schema/: currentPhase enum correctly omits 'deliver'
ok:   docs/manifest-schema.md + docs/schema/: durable-eligible set includes 'delivery'
ok:   SKILL.md references ff-deliver
ok:   README.md references ff-deliver
ok:   delivery-gap eval fixture present
ok:   dist parity: commands/ff-deliver.md
ok:   dist parity: templates/delivery.md
ok:   dist parity: docs/manifest-schema.md
ok:   dist parity: docs/schema/assumption-records.md
ok:   dist parity: docs/schema/autopilot.md
ok:   dist parity: docs/schema/delivery.md
ok:   dist parity: docs/schema/design-tradeoffs.md
ok:   dist parity: docs/schema/discovery-fields.md
ok:   dist parity: docs/schema/disk-inference.md
ok:   dist parity: docs/schema/enforcement.md
ok:   dist parity: docs/schema/evidence.md
ok:   dist parity: docs/schema/knowledge-base.md
ok:   dist parity: docs/schema/planning-intelligence.md
ok:   dist parity: docs/schema/retrospective.md
ok:   dist parity: docs/schema/sign-off-rendering.md
ok:   dist parity: docs/schema/task-controller.md
ok:   dist parity: docs/schema/terminal-convergence.md
ok:   dist parity: skills/feature-flow/SKILL.md
ok:   dist parity: README.md
PASS: delivery guard
EXIT_CODE=0
=== design-tradeoff-guard.sh ===
ok:   templates/design.md: Trade-off matrix carries the core 3-axis header
ok:   templates/design.md: Trade-off matrix states the adaptive-axis rule
ok:   templates/design.md: has the '## Devil's advocate' section
ok:   templates/design.md: Devil's advocate carries '### Failure scenarios'
ok:   templates/design.md: Devil's advocate carries '### Edge cases & operational risk'
ok:   templates/design.md: Failure scenarios carries a labeled '- **FS1:**' example row
ok:   templates/design.md: states >=1 failure scenario required even for a single obvious option
ok:   commands/ff-design.md: carries the Devil's-advocate pass
ok:   commands/ff-design.md: requires >=1 concrete failure scenario
ok:   commands/ff-design.md: adversarial beat (120) sits between the do-not-contradict STOP (118) and '## Write the artifact' (144)
ok:   commands/ff-design.md: states the derive-not-diverge rule for decision.md's Trade-offs
ok:   commands/ff-design.md: failure scenarios named in decision.md by reference
ok:   templates/decision.md: Trade-offs schema untouched (decision-record-guard.sh stays green)
ok:   commands/ff-verify.md: resolves artifacts.design
ok:   commands/ff-verify.md: maps each failure scenario into its own FS<n> contract item
ok:   commands/ff-verify.md: FS mapping reuses the AC mapping discipline
ok:   templates/verify.md: FS1 contract-mapping block present
ok:   templates/verify.md: FS block carries \*\*Method:\*\*
ok:   templates/verify.md: FS block carries \*\*Evidence:\*\*
ok:   templates/verify.md: FS block carries \*\*Confidence:\*\*
ok:   templates/verify.md: FS block carries \*\*Gap
ok:   docs/manifest-schema.md + docs/schema/: '## Design trade-offs & devil's advocate' canonical section present
ok:   docs/manifest-schema.md + docs/schema/ §Design trade-offs: '### Trade-off matrix' present
ok:   docs/manifest-schema.md + docs/schema/ §Design trade-offs: '### Devil' present
ok:   docs/manifest-schema.md + docs/schema/ §Design trade-offs: '### Actuation' present
ok:   docs/manifest-schema.md + docs/schema/ §Design trade-offs: '### decision.md reconciliation' present
ok:   docs/manifest-schema.md + docs/schema/ §Design trade-offs: '### v1 non-goals' present
ok:   docs/manifest-schema.md + docs/schema/ §Design trade-offs: states no new §Autopilot row (reuses Evidence gap stop)
ok:   docs/manifest-schema.md + docs/schema/ §Evidence: Confidence ladder names the design-time-failure-scenario class
ok:   config/defaults.json: no new config key (always-on, as required)
ok:   docs/manifest-schema.md + docs/schema/: no new top-level manifest field
ok:   dist parity: templates/design.md
ok:   dist parity: templates/verify.md
ok:   dist parity: docs/manifest-schema.md
ok:   dist parity: docs/schema/assumption-records.md
ok:   dist parity: docs/schema/autopilot.md
ok:   dist parity: docs/schema/delivery.md
ok:   dist parity: docs/schema/design-tradeoffs.md
ok:   dist parity: docs/schema/discovery-fields.md
ok:   dist parity: docs/schema/disk-inference.md
ok:   dist parity: docs/schema/enforcement.md
ok:   dist parity: docs/schema/evidence.md
ok:   dist parity: docs/schema/knowledge-base.md
ok:   dist parity: docs/schema/planning-intelligence.md
ok:   dist parity: docs/schema/retrospective.md
ok:   dist parity: docs/schema/sign-off-rendering.md
ok:   dist parity: docs/schema/task-controller.md
ok:   dist parity: docs/schema/terminal-convergence.md
ok:   dist parity: commands/ff-design.md
ok:   dist parity: commands/ff-verify.md
PASS: design-tradeoff guard
EXIT_CODE=0
=== discovery-fields-guard.sh ===
ok:   templates/spec.md: '## Success metrics' present
ok:   templates/spec.md: '## Requirement graph' present
ok:   templates/spec.md: 'Success metrics' carries the full-tier-only banner
ok:   templates/spec.md: 'Requirement graph' carries the full-tier-only banner
ok:   templates/spec.md: no Stakeholders section (as required)
ok:   templates/spec.md: Success metrics states the binary-threshold-with-measurement discipline
ok:   templates/spec.md: Success metrics cross-references (not diverges from) the binary-AC discipline
ok:   templates/spec.md: Requirement graph carries the '| AC | Depends on |' header
ok:   templates/spec.md: Requirement graph names its reuse of §Planning intelligence's notation
ok:   commands/ff-clarify.md: names the Success metrics field
ok:   commands/ff-clarify.md: names the Requirement graph field
ok:   commands/ff-clarify.md: lite branch explicitly skips the two fields
ok:   commands/ff-verify.md: maps each Success-metrics row into its own '### SM<n>'
ok:   commands/ff-verify.md: states presence-not-tier gating for SM
ok:   templates/verify.md: SM1 contract-mapping block present
ok:   templates/verify.md: SM block carries \*\*Method:\*\*
ok:   templates/verify.md: SM block carries \*\*Evidence:\*\*
ok:   templates/verify.md: SM block carries \*\*Confidence:\*\*
ok:   templates/verify.md: SM block carries \*\*Gap
ok:   commands/ff-plan.md: carries the requirement-graph derivation bullet
ok:   commands/ff-plan.md: requirement-graph bullet (91) sits between 'Map every AC' (75) and 'Derive planning intelligence' (104)
ok:   templates/plan.md: Dependency graph header UNCHANGED (no new column — derive-don't-widen)
ok:   templates/plan.md: Outcome gate carries the requirement-graph coverage/gap rule
ok:   templates/plan.md: names the un-derivable same-task-covers-both-ACs gap format
ok:   docs/manifest-schema.md + docs/schema/: '## Discovery fields' canonical section present
ok:   docs/manifest-schema.md + docs/schema/ §Discovery fields: '### Success metrics' present
ok:   docs/manifest-schema.md + docs/schema/ §Discovery fields: '### Requirement graph' present
ok:   docs/manifest-schema.md + docs/schema/ §Discovery fields: '### Actuation 1' present
ok:   docs/manifest-schema.md + docs/schema/ §Discovery fields: '### Actuation 2' present
ok:   docs/manifest-schema.md + docs/schema/ §Discovery fields: '### Tier / track scope' present
ok:   docs/manifest-schema.md + docs/schema/ §Discovery fields: '### v1 non-goals' present
ok:   docs/manifest-schema.md + docs/schema/ §Evidence: Confidence ladder names 'success metric' as a fourth contract-item class
ok:   config/defaults.json: no new config key (always-on, as required)
ok:   docs/manifest-schema.md + docs/schema/: no new top-level manifest field
ok:   docs/manifest-schema.md + docs/schema/ §Autopilot: no new discovery-fields row (as required)
ok:   dist parity: templates/spec.md
ok:   dist parity: templates/verify.md
ok:   dist parity: templates/plan.md
ok:   dist parity: docs/manifest-schema.md
ok:   dist parity: docs/schema/assumption-records.md
ok:   dist parity: docs/schema/autopilot.md
ok:   dist parity: docs/schema/delivery.md
ok:   dist parity: docs/schema/design-tradeoffs.md
ok:   dist parity: docs/schema/discovery-fields.md
ok:   dist parity: docs/schema/disk-inference.md
ok:   dist parity: docs/schema/enforcement.md
ok:   dist parity: docs/schema/evidence.md
ok:   dist parity: docs/schema/knowledge-base.md
ok:   dist parity: docs/schema/planning-intelligence.md
ok:   dist parity: docs/schema/retrospective.md
ok:   dist parity: docs/schema/sign-off-rendering.md
ok:   dist parity: docs/schema/task-controller.md
ok:   dist parity: docs/schema/terminal-convergence.md
ok:   dist parity: commands/ff-clarify.md
ok:   dist parity: commands/ff-verify.md
ok:   dist parity: commands/ff-plan.md
ok:   dist parity: skills/feature-flow/SKILL.md
ok:   dist parity: README.md
PASS: discovery-fields guard
EXIT_CODE=0
=== dist-parity-guard.sh ===
ok:   checked 62 packaged files (0 drifted, 0 orphaned)
PASS: dist parity guard (62 files in sync)
EXIT_CODE=0
=== durable-paths-guard.sh ===
ok:   config/defaults.json: paths.durable present, default null
ok:   docs/manifest-schema.md + docs/schema/: 'Durable artifact resolution' rule present
ok:   docs/manifest-schema.md + docs/schema/: rule names paths.durable
ok:   docs/manifest-schema.md + docs/schema/: rule states the <date>-<slug>/<artifact> scheme
ok:   docs/manifest-schema.md + docs/schema/: phases.<phase>.artifact described as a display mirror
ok:   docs/manifest-schema.md + docs/schema/: stale 'only spec/plan relocatable' claim absent
ok:   docs/manifest-schema.md + docs/schema/: Disk-inference references artifacts.<name>
ok:   docs/manifest-schema.md + docs/schema/: Disk-inference has the paths.durable manifest-lost fallback
ok:   docs/manifest-schema.md + docs/schema/: artifacts note carries the resolution rule
ok:   commands/ff-clarify.md: references the Durable artifact resolution rule
ok:   commands/ff-clarify.md: records the resolved path in artifacts.spec
ok:   commands/ff-plan.md: references the Durable artifact resolution rule
ok:   commands/ff-plan.md: records the resolved path in artifacts.plan
ok:   commands/ff-design.md: references the Durable artifact resolution rule
ok:   commands/ff-design.md: records the resolved path in artifacts.design
ok:   commands/ff-design.md: references the Durable artifact resolution rule
ok:   commands/ff-design.md: records the resolved path in artifacts.decision
ok:   commands/ff-diagnose.md: references the Durable artifact resolution rule
ok:   commands/ff-diagnose.md: records the resolved path in artifacts.diagnosis
ok:   commands/ff-verify.md: references the Durable artifact resolution rule
ok:   commands/ff-verify.md: records the resolved path in artifacts.verify
ok:   commands/ff-deliver.md: references the Durable artifact resolution rule
ok:   commands/ff-deliver.md: records the resolved path in artifacts.delivery
ok:   commands/ff-retro.md: references the Durable artifact resolution rule
ok:   commands/ff-retro.md: records the resolved path in artifacts.retro
ok:   commands/ff-implement.md: resolves the plan via artifacts.plan
ok:   commands/ff-implement.md: Cold-start reads artifacts.plan (rel@5) before the sandbox fallback (rel@7)
ok:   commands/ff-implement.md: bugfix work resolves the diagnosis via artifacts.diagnosis
ok:   commands/ff-status.md: resolves artifact existence via artifacts.<name>
ok:   README.md: has a paths.durable config row
ok:   SKILL.md: notes durable promotion
ok:   dist parity: config/defaults.json
ok:   dist parity: docs/manifest-schema.md
ok:   dist parity: docs/schema/assumption-records.md
ok:   dist parity: docs/schema/autopilot.md
ok:   dist parity: docs/schema/delivery.md
ok:   dist parity: docs/schema/design-tradeoffs.md
ok:   dist parity: docs/schema/discovery-fields.md
ok:   dist parity: docs/schema/disk-inference.md
ok:   dist parity: docs/schema/enforcement.md
ok:   dist parity: docs/schema/evidence.md
ok:   dist parity: docs/schema/knowledge-base.md
ok:   dist parity: docs/schema/planning-intelligence.md
ok:   dist parity: docs/schema/retrospective.md
ok:   dist parity: docs/schema/sign-off-rendering.md
ok:   dist parity: docs/schema/task-controller.md
ok:   dist parity: docs/schema/terminal-convergence.md
ok:   dist parity: commands/ff.md
ok:   dist parity: commands/ff-clarify.md
ok:   dist parity: commands/ff-plan.md
ok:   dist parity: commands/ff-design.md
ok:   dist parity: commands/ff-diagnose.md
ok:   dist parity: commands/ff-implement.md
ok:   dist parity: commands/ff-verify.md
ok:   dist parity: commands/ff-status.md
ok:   dist parity: commands/ff-resume.md
ok:   dist parity: README.md
ok:   dist parity: skills/feature-flow/SKILL.md
ok:   read-site completeness (AC13): no bare-name durable-artifact reader/gate in any command body
PASS: durable-paths guard
EXIT_CODE=0
=== enforce-gate-guard.sh ===
ok:   GateA: feature unsigned → implement
ok:   GateA: feature signed → implement
ok:   GateA: bugfix-lite diagnose incomplete → implement
ok:   GateA: bugfix-lite diagnose complete → implement (no sign-off needed)
ok:   GateA: bugfix-full unsigned → implement
ok:   GateA: feature-lite unsigned → implement (feature/* arm covers lite)
ok:   GateA: feature-lite signed → implement
ok:   GateB/AC10: legacy stub verify.md (no Contract mapping) → denied
ok:   GateB/AC10: filled report (Contract mapping + status token) → allowed
ok:   GateB/AC10: Contract mapping without a captured status token → denied
ok:   GateB/AC10: verbatim unfilled template → denied
ok:   GateB: feature done, verify.md absent
ok:   GateB: feature done, verify.md empty
ok:   GateB: feature done, verify.md has no heading
ok:   GateB: feature done but verify.status != complete
ok:   GateB/AC5: honors renamed artifacts.verify pointer
ok:   GateB: bugfix done + verify + review
ok:   GateB: bugfix done, review.md absent
ok:   non-manifest write → fast-exit allow
ok:   unparseable proposed content → fail-open
ok:   missing track → fail-open
ok:   kill switch: toggles.enforce=false → allow
ok:   jq absent → systemMessage warning (fail-open)
ok:   dispatch seam: run-hook.cmd → enforce-gate denies
ok:   Edit: currentPhase verify→done without verify.md → Gate B
ok:   Edit: currentPhase verify→done with valid verify.md → allowed
ok:   Edit: currentPhase plan→implement unsigned → Gate A
ok:   MultiEdit: enter implement, sign-off untouched → Gate A
ok:   MultiEdit: sign off + enter implement → allowed
ok:   Edit: unrelated field change on a legal manifest → allowed
ok:   Edit: replace_all=false rewrites only the first occurrence → allowed
ok:   Edit: replace_all=true rewrites currentPhase too → Gate B
ok:   Edit: old_string not found → fail-open
ok:   Edit: manifest file missing on disk → fail-open
ok:   Edit: non-manifest file → fast-exit allow
ok:   Edit create (empty old_string, file missing) unsigned implement → Gate A
ok:   Edit create (empty old_string, empty file) unsigned implement → Gate A
ok:   Edit: empty old_string on a non-empty file → fail-open (tool rejects it)
ok:   hooks.json PreToolUse matcher routes Write to enforce-gate
ok:   hooks.json PreToolUse matcher routes Edit to enforce-gate
ok:   hooks.json PreToolUse matcher routes MultiEdit to enforce-gate
ok:   rev lib: fingerprint is repeatable
ok:   rev lib: clean tree equals HEAD's tree
ok:   rev lib/AC3: writes under paths.base, paths.durable, paths.kb don't change it
ok:   rev lib/AC3: nested git repository doesn't change it
ok:   rev lib/AC4: tracked edit changes it
ok:   rev lib/AC4: tracked delete changes it
ok:   rev lib/AC4: untracked non-ignored file changes it
ok:   rev lib: the real .git/index is never modified
ok:   rev lib/AC4: revert restores the original value
ok:   rev lib/FS3: subdir project — its own bookkeeping paths are excluded
ok:   rev lib/FS3: subdir project — edits elsewhere in the repo are still detected
ok:   rev lib/FS4: durable form {"paths":{"durable":"/tmp/tmp.lF34QiEXKL/rev-repo/docs/ff"}} is excluded
ok:   rev lib/FS4: durable form {"paths":{"durable":"docs/ff/"}} is excluded
ok:   rev lib/FS4: durable form {"paths":{"durable":"./docs/ff"}} is excluded
ok:   rev lib/FS4: durable null + kb unset → default kb still excluded
ok:   rev lib/FS4: durable null → docs/ff counts as code
ok:   rev lib/AC7: changed paths listed, capped at 10 with '+N more'
ok:   rev lib/FS1: missing tree object → 'changed paths unavailable'
ok:   rev lib: a non-hex revision is never passed to git
ok:   rev lib: fingerprint outside a git repo returns non-zero
ok:   GateB/AC6: both revisions equal the current tree → allowed
ok:   GateB/AC5: review revision missing → denied
ok:   GateB/AC5: reason names the missing review revision
ok:   GateB/AC5: verify revision missing → denied
ok:   GateB/AC5: reason names the missing verify revision
ok:   GateB/AC5: review revision stale (code changed after review) → denied
ok:   GateB/AC7: stale reason names the phase and the changed path
ok:   GateB/AC5: verify revision stale → denied, naming verify
ok:   GateB/AC6: after re-stamping both on the current tree → allowed
ok:   GateB/FS1: stamped tree object missing → still denied
ok:   GateB/FS1: reason says changed paths unavailable
ok:   GateB/AC8: revisionBound absent in a git repo → 0.21.0 behaviour (allowed)
ok:   GateB/AC8: revisionBound outside any git repo → 0.21.0 behaviour (allowed)
ok:   GateB/AC8: toggles.enforce=false → no revision check
ok:   GateB/AC9: git unavailable in a git repo → allowed with a systemMessage warning
ok:   GateB/AC9: no deny when the revision cannot be computed
ok:   GateB: .git walk-up terminates on a relative project path
ok:   GateB/E2E: stale review through run-hook.cmd → denied
PASS: enforce-gate guard
EXIT_CODE=0
=== evidence-guard.sh ===
ok:   templates/plan.md: task template has a **Covers:** field
ok:   templates/plan.md: Outcome gate requires every AC mapped/flagged
ok:   commands/ff-plan.md: AC-mapping instruction present, feature-scoped
ok:   templates/verify.md: '## Regression risk' section present
ok:   commands/ff-verify.md: regression-risk instruction present
ok:   templates/diagnosis.md: '## Root cause candidates' section present
ok:   templates/diagnosis.md: '## Confirmed root cause' section present
ok:   commands/ff-diagnose.md: full-tier candidate instruction present
ok:   commands/ff-diagnose.md: sign-off echo still lists 'root cause' (AC4)
ok:   dist parity: templates/plan.md
ok:   dist parity: templates/verify.md
ok:   dist parity: templates/diagnosis.md
ok:   docs/manifest-schema.md + docs/schema/: '## Evidence' canonical section present
ok:   docs/manifest-schema.md + docs/schema/ §Evidence: '### Evidence-kind taxonomy' subsection present
ok:   docs/manifest-schema.md + docs/schema/ §Evidence: '### Evidence record shape' subsection present
ok:   docs/manifest-schema.md + docs/schema/ §Evidence: '### Evidence directory' subsection present
ok:   docs/manifest-schema.md + docs/schema/ §Evidence: '### Confidence ladder' subsection present
ok:   docs/manifest-schema.md + docs/schema/ §Evidence: '### Detection and N/A rule' subsection present
ok:   docs/manifest-schema.md + docs/schema/ §Evidence: '### Evidence waiver' subsection present
ok:   docs/manifest-schema.md + docs/schema/ §Evidence: '### Tier scaling' subsection present
ok:   docs/manifest-schema.md + docs/schema/ §Evidence: '### Adding an evidence kind' subsection present
ok:   docs/manifest-schema.md + docs/schema/ §Evidence: '### v1 non-goals' subsection present
ok:   docs/manifest-schema.md + docs/schema/ §Evidence: evidence record shape stated literally
ok:   docs/manifest-schema.md + docs/schema/ §Evidence: taxonomy names 'executed-test'
ok:   docs/manifest-schema.md + docs/schema/ §Evidence: taxonomy names 'build/static-analysis'
ok:   docs/manifest-schema.md + docs/schema/ §Evidence: taxonomy names 'e2e/browser'
ok:   docs/manifest-schema.md + docs/schema/ §Evidence: taxonomy names 'http/api'
ok:   docs/manifest-schema.md + docs/schema/ §Evidence: taxonomy names 'db'
ok:   docs/manifest-schema.md + docs/schema/ §Evidence: taxonomy names 'cli-output'
ok:   docs/manifest-schema.md + docs/schema/ §Evidence: taxonomy names 'logs'
ok:   docs/manifest-schema.md + docs/schema/ §Evidence: taxonomy names 'before/after'
ok:   docs/manifest-schema.md + docs/schema/ §Evidence: confidence token 'Verified (multi-source)' present
ok:   templates/verify.md: confidence token 'Verified (multi-source)' present
ok:   docs/manifest-schema.md + docs/schema/ §Evidence: confidence token 'Verified (single-source)' present
ok:   templates/verify.md: confidence token 'Verified (single-source)' present
ok:   docs/manifest-schema.md + docs/schema/ §Evidence: confidence token 'Partially verified' present
ok:   templates/verify.md: confidence token 'Partially verified' present
ok:   docs/manifest-schema.md + docs/schema/ §Evidence: confidence token 'Unverified' present
ok:   templates/verify.md: confidence token 'Unverified' present
ok:   templates/verify.md: '## Evidence coverage matrix' section present
ok:   templates/verify.md: '## Evidence artifacts index' section present
ok:   templates/verify.md: '## Limitations & remaining risks' section present
ok:   templates/verify.md: '## Contract mapping' section present
ok:   templates/verify.md: lite-tier skip note present on the coverage matrix
ok:   agents/ff-test-runner.md: detects 'composer.json'
ok:   agents/ff-test-runner.md: detects 'phpunit.xml'
ok:   agents/ff-test-runner.md: detects 'playwright.config'
ok:   agents/ff-test-runner.md: detects 'bin/magento'
ok:   agents/ff-test-runner.md: detects 'MFTF'
ok:   agents/ff-test-runner.md: evidence-dir write scope stated
ok:   agents/ff-test-runner.md: clears evidence/ before writing (re-run hygiene)
ok:   docs/manifest-schema.md + docs/schema/ §Autopilot: 'Evidence gap stop' pause row present
ok:   commands/ff-verify.md: references the Evidence contract by name
ok:   commands/ff-verify.md: waiver line format stated
ok:   docs/manifest-schema.md + docs/schema/: waiver line format stated
ok:   dist parity: agents/ff-test-runner.md
GREEN: evidence guard passed
EXIT_CODE=0
=== forward-test-guard.sh ===
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
EXIT_CODE=0
=== fresh-context-interview-guard.sh ===
ok:   FC1: §Progress strip carries the fresh-context hint
ok:   FC1: hint names the on-disk state
ok:   FC1: hint is step-by-step phase-end hand-offs only
ok:   FC1: never in autopilot
ok:   FC1: never at a sign-off / decision / blocking pause
ok:   FC2: commands/ff.md ends its hand-off via §Progress strip
ok:   FC2: commands/ff-explore.md ends its hand-off via §Progress strip
ok:   FC2: commands/ff-clarify.md ends its hand-off via §Progress strip
ok:   FC2: commands/ff-design.md ends its hand-off via §Progress strip
ok:   FC2: commands/ff-plan.md ends its hand-off via §Progress strip
ok:   FC2: commands/ff-diagnose.md ends its hand-off via §Progress strip
ok:   FC2: commands/ff-implement.md ends its hand-off via §Progress strip
ok:   FC2: commands/ff-review.md ends its hand-off via §Progress strip
ok:   FC2: commands/ff-verify.md ends its hand-off via §Progress strip
ok:   FC2: commands/ff-resume.md ends its hand-off via §Progress strip
ok:   IV1: ff-clarify asks closed-choice questions via AskUserQuestion in both modes
ok:   IV1: open-ended probes stay plain text
ok:   TP1: templates/spec.md has '## Touchpoints'
ok:   TP1: '## Touchpoints' applies to both tiers
ok:   TP1: templates/spec.md has '## End-to-end check'
ok:   TP1: '## End-to-end check' applies to both tiers
ok:   TP1: End-to-end check sits between Acceptance criteria and Success metrics
ok:   TP2: ff-clarify fill-list names Touchpoints
ok:   TP2: ff-clarify fill-list names End-to-end check
ok:   TP2: lite tier still fills the End-to-end check
ok:   TP3: ff-verify maps the End-to-end check into '### E2E'
ok:   TP3: E2E mapped exactly as an acceptance criterion
ok:   TP3: E2E gated by a presence check on the section
ok:   TP3: E2E block carries \*\*Method:\*\*
ok:   TP3: E2E block carries \*\*Evidence:\*\*
ok:   TP3: E2E block carries \*\*Confidence:\*\*
ok:   TP3: E2E block carries \*\*Gap
ok:   TP3b: ff-verify passes the End-to-end check row to ff-test-runner
ok:   TP3b: ff-test-runner runs a provided end-to-end check
ok:   TP3b: …on a lite dispatch too (carve-out from floor-only)
ok:   TP3b: ff-test-runner maps the end-to-end check as a contract item
ok:   TP3c: spec template allows an explicit none
ok:   TP3c: ff-verify treats E2E: none as absent
ok:   TP3d: retro signal list names E2E
ok:   TP3d: repair-cycle trigger decides E2E/SM
ok:   TP4: spec-conformance reviewer reads Touchpoints
ok:   TP5: §Discovery fields has '### Touchpoints'
ok:   TP5: §Discovery fields has '### End-to-end check'
ok:   TP5: §Discovery fields has '### Actuation 3'
ok:   TP5: Confidence ladder names the end-to-end check as a contract-item class
ok:   dist parity: docs/manifest-schema.md
ok:   dist parity: docs/schema/assumption-records.md
ok:   dist parity: docs/schema/autopilot.md
ok:   dist parity: docs/schema/delivery.md
ok:   dist parity: docs/schema/design-tradeoffs.md
ok:   dist parity: docs/schema/discovery-fields.md
ok:   dist parity: docs/schema/disk-inference.md
ok:   dist parity: docs/schema/enforcement.md
ok:   dist parity: docs/schema/evidence.md
ok:   dist parity: docs/schema/knowledge-base.md
ok:   dist parity: docs/schema/planning-intelligence.md
ok:   dist parity: docs/schema/retrospective.md
ok:   dist parity: docs/schema/sign-off-rendering.md
ok:   dist parity: docs/schema/task-controller.md
ok:   dist parity: docs/schema/terminal-convergence.md
ok:   dist parity: templates/spec.md
ok:   dist parity: templates/verify.md
ok:   dist parity: commands/ff-clarify.md
ok:   dist parity: commands/ff-verify.md
ok:   dist parity: commands/ff-review.md
PASS: fresh-context-interview guard
EXIT_CODE=0
=== implement-controller-guard.sh ===
ok:   AC1: templates/plan.md has ## Global Constraints (34) before ## Tasks (45)
ok:   AC1: templates/plan.md has '**No Placeholders.**'
ok:   AC1: templates/plan.md has 'TBD'
ok:   AC1: templates/plan.md has 'add appropriate error handling'
ok:   AC1: templates/plan.md has 'similar to Task N'
ok:   AC1: templates/plan.md has 'unfilled `<…>` template placeholder'
ok:   AC1: templates/plan.md has 'complete test code in a fenced block'
ok:   AC1: templates/plan.md has 'does not name the exact change'
ok:   AC1: templates/plan.md has '**Self-check ran:**'
ok:   AC1: templates/plan.md has '**Interfaces:**'
ok:   AC1: templates/plan.md has '- Consumes:'
ok:   AC1: templates/plan.md has '- Produces:'
ok:   AC1: templates/plan.md has '**Run:**'
ok:   AC1: templates/plan.md has '**Expected:**'
ok:   AC1: templates/plan-bugfix.md has ## Global Constraints (17) before ## Tasks (27)
ok:   AC1: templates/plan-bugfix.md has '**No Placeholders.**'
ok:   AC1: templates/plan-bugfix.md has 'TBD'
ok:   AC1: templates/plan-bugfix.md has 'add appropriate error handling'
ok:   AC1: templates/plan-bugfix.md has 'similar to Task N'
ok:   AC1: templates/plan-bugfix.md has 'unfilled `<…>` template placeholder'
ok:   AC1: templates/plan-bugfix.md has 'complete test code in a fenced block'
ok:   AC1: templates/plan-bugfix.md has 'does not name the exact change'
ok:   AC1: templates/plan-bugfix.md has '**Self-check ran:**'
ok:   AC1: templates/plan-bugfix.md has '**Interfaces:**'
ok:   AC1: templates/plan-bugfix.md has '- Consumes:'
ok:   AC1: templates/plan-bugfix.md has '- Produces:'
ok:   AC1: templates/plan-bugfix.md has '**Run:**'
ok:   AC1: templates/plan-bugfix.md has '**Expected:**'
ok:   AC1/AC13: plan-bugfix.md keeps the Verify RED / Verify GREEN anchors
ok:   AC2: commands/ff-plan.md has '**Write an executable plan (full tier, both tracks):**'
ok:   AC2: commands/ff-plan.md has '**No Placeholders self-check (full tier):**'
ok:   AC2: the self-check (119) runs before the Outcome gate (124)
ok:   AC3: Critical-path check < Controller activation < Controller loop < inline Do the work
ok:   AC3/AC4: activation has '**full tier**'
ok:   AC3/AC4: activation has '## Global Constraints'
ok:   AC3/AC4: activation has 'implement **inline**'
ok:   AC3/AC4: activation has '`Implement path: controller — <reason>`'
ok:   AC3/AC4: activation has '`Implement path: inline — <reason>`'
ok:   AC3/AC4: activation has '**Plan placeholder stop**'
ok:   AC3/AC4: activation has 'in both modes'
ok:   AC3/AC4: activation has '/feature-flow:ff-plan'
ok:   AC3/AC4: activation has 'no task is dispatched'
ok:   AC3: both Do the work sections are marked as the inline path
ok:   AC5: docs/manifest-schema.md Schema + field note for artifacts.ledger
ok:   AC5: ledger listed as ephemeral
ok:   AC5: loop has '# Ledger — plan:'
ok:   AC5: loop has 'before the first dispatch'
ok:   AC5: loop has 'Rewrite the ledger after every step below, before the next dispatch'
ok:   AC5: docs/schema/task-controller.md has '**Two writes per step.**'
ok:   AC5: docs/schema/task-controller.md has '**Identity line.**'
ok:   AC6: loop has '^### Task <N>:'
ok:   AC6: loop has '(never the whole plan)'
ok:   AC6: loop has '**`ff-implementer`** with `model` = `models.implementer`'
ok:   AC7: loop has '`DONE`'
ok:   AC7: loop has '`DONE_WITH_CONCERNS`'
ok:   AC7: loop has '`NEEDS_CONTEXT`'
ok:   AC7: loop has '`BLOCKED`'
ok:   AC7: loop has 'at most twice per task'
ok:   AC7: loop has '**Task blocked stop**'
ok:   AC8: loop has 'diff.patch'
ok:   AC8: loop has 'No step below runs `git add`'
ok:   AC9: loop has '**paths only**'
ok:   AC9: loop has 'never paste the diff into the prompt'
ok:   AC9: loop has 'two verdicts — conformance'
ok:   AC9: loop has 'do not spawn subagents'
ok:   AC10: loop has '**never more than 3 rounds**'
ok:   AC10: loop has '**Rounds 1 and 2** resume the same implementer'
ok:   AC10: loop has '**Round 3** dispatches a fresh `ff-implementer` on `models.escalation`'
ok:   AC10: loop has '`ADDRESSED` or `NOT ADDRESSED`'
ok:   AC11: loop has '**Critical-after-cap stop**'
ok:   AC11: loop has '**Ruling:** <decision> — <why> — <cost if wrong>'
ok:   AC12: loop has 'TDD: exempt — <reason>'
ok:   AC12: loop has 'TDD: off (config)'
ok:   AC13: loop has 'manifest.bugfix.red'
ok:   AC13: loop has 'manifest.bugfix.green'
ok:   FS2: loop has '**keep the recorded Base**'
ok:   FS4: loop has 'escalation unavailable — used <model>'
ok:   AC7: docs/schema/task-controller.md has 'at most 15 lines'
ok:   AC14: commands/ff-resume.md has '**Resuming implement with a task ledger**'
ok:   AC14: commands/ff-status.md has '**task progress**'
ok:   AC14: hooks/session-start names the current task
ok:   AC15: the paste instruction is gone
ok:   AC15: commands/ff-review.md has 'never pasted into the prompt'
ok:   AC15: commands/ff-review.md has '<run dir>/review.diff'
ok:   AC15: commands/ff-review.md has '**Rulings from implement.**'
ok:   AC15: commands/ff-review.md has 'hooks/lib/revision.sh" "<project dir>" head'
ok:   AC15: commands/ff-review.md has 'Never diff against the raw `HEAD^{tree}`'
ok:   AC15: revision.sh defines revision_head_tree (the review base)
ok:   AC16: ff-implementer has Write
ok:   AC16: ff-implementer has Edit
ok:   AC16: ff-implementer has Bash
ok:   AC16: ff-implementer has no agent-dispatch tool
ok:   AC16: agents/ff-implementer.md has 'Do **not** spawn subagents'
ok:   AC16: agents/ff-implementer.md has '`git add`, `git commit`, `git stash`, `git reset`'
ok:   AC16: agents/ff-implementer.md has 'except your own report file'
ok:   AC16: agents/ff-implementer.md has 'at most 15 lines'
ok:   AC17: defaults.json models.implementer=sonnet, models.escalation=opus
ok:   AC17: docs/manifest-schema.md has 'models.{explorer,architect,reviewer,diagnostician,testRunner,implementer,escalation}'
ok:   AC18: skills/feature-flow/references/codex-tools.md has '`ff-implementer`: the one editing role'
ok:   AC18: skills/feature-flow/references/codex-tools.md has 'the same loop runs inline, with the same files, in the same order, preserving role boundaries'
ok:   AC19: docs/schema/task-controller.md defines '## Task controller'
ok:   AC19: docs/schema/task-controller.md defines '### Executable plans'
ok:   AC19: docs/schema/task-controller.md defines '### Controller activation'
ok:   AC19: docs/schema/task-controller.md defines '### Task packaging'
ok:   AC19: docs/schema/task-controller.md defines '### Ledger'
ok:   AC19: docs/schema/task-controller.md defines '### Status contract'
ok:   AC19: docs/schema/task-controller.md defines '### Task review'
ok:   AC19: docs/schema/task-controller.md defines '### Fix loop'
ok:   AC19: docs/schema/task-controller.md defines '### Rulings'
ok:   AC19: docs/schema/task-controller.md defines '### Bugfix under the controller'
ok:   AC19: docs/schema/task-controller.md defines '### Inline fallback (Codex)'
ok:   AC19: 'Plan placeholder stop' row present, not unconditional
ok:   AC19: 'Task blocked stop' row present, not unconditional
ok:   AC19: 'Critical-after-cap stop' row present, not unconditional
ok:   AC19: 'Task blocked stop' is capped-then-stop
ok:   AC19: 'Critical-after-cap stop' is capped-then-stop
ok:   AC19: docs/schema/autopilot.md has '**Per-task fix loop (`ff-implement` controller, both modes).**'
ok:   pkg: docs/schema/task-controller.md §Task packaging block is hooks/lib/task.sh byte-for-byte
ok:   pkg self-test: a one-character drift is caught
ok:   dist parity: commands/ff-implement.md
ok:   dist parity: commands/ff-plan.md
ok:   dist parity: commands/ff-review.md
ok:   dist parity: commands/ff-resume.md
ok:   dist parity: commands/ff-status.md
ok:   dist parity: templates/plan.md
ok:   dist parity: templates/plan-bugfix.md
ok:   dist parity: docs/schema/task-controller.md
ok:   dist parity: docs/schema/autopilot.md
ok:   dist parity: docs/manifest-schema.md
ok:   dist parity: agents/ff-implementer.md
ok:   dist parity: skills/feature-flow/references/codex-tools.md
ok:   dist parity: skills/feature-flow/SKILL.md
ok:   dist parity: config/defaults.json
PASS: implement-controller guard
EXIT_CODE=0
=== integrity-boundary-guard.sh ===
ok:   current commands/hooks/templates/config do not invoke doctor or migration
ok:   schemas/manifest-v1.schema.json parses
ok:   schemas/golden-vector-v1.schema.json parses
ok:   schemas/doctor-result-v1.schema.json parses
ok:   schemas/migration-plan-v1.schema.json parses
ok:   integrity/protocol/v1/diagnostics.json parses
ok:   integrity/testdata/vectors/v1/index.json parses
ok:   integrity/testdata/legacy/inventory-v1.json parses
PASS: integrity boundary guard
EXIT_CODE=0
=== integrity-wp2-guard.sh ===
ok:   every inventoried legacy source has one registered profile or explicit rationale
ok:   legacy inventory source identities are unique
ok:   migration corpus contains X-LOSSLESS
ok:   migration corpus contains X-IDEMPOTENT
ok:   migration corpus contains X-AMBIGUOUS
ok:   migration corpus contains X-POINTER
ok:   migration corpus contains X-POINTER-DRIFT
ok:   migration corpus contains X-LEGACY-DONE
ok:   migration corpus contains X-PREVIEW-NOWRITE
ok:   migration corpus contains X-POLICY-EQUIVALENCE
ok:   WP2 remains directly invocable only
PASS: WP2 integrity guard
EXIT_CODE=0
=== kb-guard.sh ===
ok:   config/defaults.json: toggles.kb present, default true
ok:   config/defaults.json: paths.kb present, default ".feature-flow-kb"
ok:   config/defaults.json: kb.freshnessWindowDays + kb.maxRecallEntries present
ok:   docs/manifest-schema.md + docs/schema/: '## Knowledge base' contract section present
ok:   docs/manifest-schema.md + docs/schema/ §Knowledge base: names freshnessWindowDays
ok:   docs/manifest-schema.md + docs/schema/ §Knowledge base: names referencedFiles
ok:   docs/manifest-schema.md + docs/schema/ §Knowledge base: names captureCommitSha
ok:   docs/manifest-schema.md + docs/schema/ §Knowledge base: names maxRecallEntries
ok:   docs/manifest-schema.md + docs/schema/ §Knowledge base: names paths.kb
ok:   docs/manifest-schema.md + docs/schema/ §Knowledge base: documents the Codex degrade path (AC11)
ok:   docs/manifest-schema.md + docs/schema/ §Knowledge base: states dedup + supersession non-goals (AC13)
ok:   docs/manifest-schema.md + docs/schema/ §Autopilot: has the KB capture confirm-gate row
ok:   docs/manifest-schema.md + docs/schema/: '## Terminal convergence' section present (canonical done-transition rule)
ok:   docs/manifest-schema.md + docs/schema/ §Knowledge base: capture rule references Terminal convergence (single-source)
ok:   templates/kb-entry.md: provenance field title
ok:   templates/kb-entry.md: provenance field captureDate
ok:   templates/kb-entry.md: provenance field captureCommitSha
ok:   templates/kb-entry.md: provenance field runSlug
ok:   templates/kb-entry.md: provenance field tags
ok:   templates/kb-entry.md: provenance field referencedFiles
ok:   commands/ff-verify.md: has a '## KB capture' section
ok:   commands/ff-verify.md §KB capture: gates on toggles.kb
ok:   commands/ff-verify.md §KB capture: references the §Knowledge base contract
ok:   commands/ff-verify.md §KB capture: reads run artifacts via artifacts.<name> pointers
ok:   commands/ff-review.md: has a '## KB capture' section
ok:   commands/ff-review.md §KB capture: gates on toggles.kb
ok:   commands/ff-review.md §KB capture: references the §Knowledge base contract
ok:   commands/ff-review.md §KB capture: reads run artifacts via artifacts.<name> pointers
ok:   commands/ff-review.md §KB capture: has the feature-track guard
ok:   commands/ff-verify.md §Update manifest: both done-transitions invoke KB capture (2)
ok:   commands/ff-review.md §Update manifest: bugfix done-transition invokes KB capture (1)
ok:   commands/ff-explore.md: has a '## KB recall' section
ok:   commands/ff-explore.md §## KB recall: gates on toggles.kb
ok:   commands/ff-explore.md §## KB recall: references the §Knowledge base contract
ok:   commands/ff-explore.md §## KB recall: applies the staleness flag (flag-not-suppress)
ok:   commands/ff-design.md: has a '## KB recall' section
ok:   commands/ff-design.md §## KB recall: gates on toggles.kb
ok:   commands/ff-design.md §## KB recall: references the §Knowledge base contract
ok:   commands/ff-design.md §## KB recall: applies the staleness flag (flag-not-suppress)
ok:   commands/ff-diagnose.md: has a '## KB recall' section
ok:   commands/ff-diagnose.md §## KB recall: gates on toggles.kb
ok:   commands/ff-diagnose.md §## KB recall: references the §Knowledge base contract
ok:   commands/ff-diagnose.md §## KB recall: applies the staleness flag (flag-not-suppress)
ok:   commands/ff-implement.md: has a '## Decision recall' section
ok:   commands/ff-implement.md §## Decision recall: gates on toggles.kb
ok:   commands/ff-implement.md §## Decision recall: references the §Knowledge base contract
ok:   commands/ff-implement.md §## Decision recall: applies the staleness flag (flag-not-suppress)
ok:   skills/feature-flow/SKILL.md: documents dedup + supersession as v1 non-goals
ok:   README.md: documents dedup + supersession as v1 non-goals
ok:   commands/ff-verify.md: KB section reads are pointer-form (no bare durable reader)
ok:   commands/ff-review.md: KB section reads are pointer-form (no bare durable reader)
ok:   commands/ff-explore.md: KB section reads are pointer-form (no bare durable reader)
ok:   commands/ff-design.md: KB section reads are pointer-form (no bare durable reader)
ok:   commands/ff-diagnose.md: KB section reads are pointer-form (no bare durable reader)
ok:   commands/ff-implement.md: KB section reads are pointer-form (no bare durable reader)
ok:   dist parity: config/defaults.json
ok:   dist parity: docs/manifest-schema.md
ok:   dist parity: docs/schema/assumption-records.md
ok:   dist parity: docs/schema/autopilot.md
ok:   dist parity: docs/schema/delivery.md
ok:   dist parity: docs/schema/design-tradeoffs.md
ok:   dist parity: docs/schema/discovery-fields.md
ok:   dist parity: docs/schema/disk-inference.md
ok:   dist parity: docs/schema/enforcement.md
ok:   dist parity: docs/schema/evidence.md
ok:   dist parity: docs/schema/knowledge-base.md
ok:   dist parity: docs/schema/planning-intelligence.md
ok:   dist parity: docs/schema/retrospective.md
ok:   dist parity: docs/schema/sign-off-rendering.md
ok:   dist parity: docs/schema/task-controller.md
ok:   dist parity: docs/schema/terminal-convergence.md
ok:   dist parity: templates/kb-entry.md
ok:   dist parity: commands/ff-verify.md
ok:   dist parity: commands/ff-review.md
ok:   dist parity: commands/ff-explore.md
ok:   dist parity: commands/ff-design.md
ok:   dist parity: commands/ff-diagnose.md
ok:   dist parity: commands/ff-implement.md
ok:   dist parity: skills/feature-flow/SKILL.md
ok:   dist parity: README.md
PASS: kb guard
EXIT_CODE=0
=== lite-tier-guard.sh ===
ok:   ff.md judges feature tier
ok:   ff.md defaults full on doubt
ok:   ff.md writes resolved tier (not hardcoded full)
ok:   ff-explore writes resolved tier
ok:   ff-explore dispatches 1 explorer when lite
ok:   ff-explore branches on tier == lite
ok:   ff-clarify has a lite-tier mode
ok:   ff-clarify lite skips premise+approach beats
ok:   ff-clarify routes lite to implement
ok:   ff-clarify has lite->full escalation
ok:   ff-implement has a feature-lite cold-start branch
ok:   ff-implement lite requires only spec
ok:   ff-implement lite never routes to design/plan
ok:   schema documents feature lite tier
ok:   SKILL documents feature lite tier
PASS: lite-tier guard
EXIT_CODE=0
=== planning-intelligence-guard.sh ===
ok:   templates/plan.md: four sections present, in order, between '## Tasks' and '## Status conventions'
ok:   templates/plan.md: 'Dependency graph' carries a '> ' guidance blockquote
ok:   templates/plan.md: 'Critical path' carries a '> ' guidance blockquote
ok:   templates/plan.md: 'Risk register' carries a '> ' guidance blockquote
ok:   templates/plan.md: 'Rollback plan' carries a '> ' guidance blockquote
ok:   templates/plan.md: Risk register has the categorical table header
ok:   templates/plan.md: Risk register states the no-numeric-score doctrine
ok:   templates/plan.md: Dependency graph rows reference Task N IDs
ok:   templates/plan-bugfix.md: four sections present, in order, between '## Tasks' and '## Status conventions'
ok:   templates/plan-bugfix.md: 'Dependency graph' carries a '> ' guidance blockquote
ok:   templates/plan-bugfix.md: 'Critical path' carries a '> ' guidance blockquote
ok:   templates/plan-bugfix.md: 'Risk register' carries a '> ' guidance blockquote
ok:   templates/plan-bugfix.md: 'Rollback plan' carries a '> ' guidance blockquote
ok:   templates/plan-bugfix.md: Risk register has the categorical table header
ok:   templates/plan-bugfix.md: Risk register states the no-numeric-score doctrine
ok:   templates/plan-bugfix.md: Dependency graph rows reference Task N IDs
ok:   docs/manifest-schema.md + docs/schema/: '## Planning intelligence' canonical section present
ok:   docs/manifest-schema.md + docs/schema/ §Planning intelligence: '### Dependency graph notation' present
ok:   docs/manifest-schema.md + docs/schema/ §Planning intelligence: '### Critical-path derivation' present
ok:   docs/manifest-schema.md + docs/schema/ §Planning intelligence: '### Critical-path check' present
ok:   docs/manifest-schema.md + docs/schema/ §Planning intelligence: '### Risk register' present
ok:   docs/manifest-schema.md + docs/schema/ §Planning intelligence: '### Rollback plan' present
ok:   docs/manifest-schema.md + docs/schema/ §Planning intelligence: derivation names the longest chain
ok:   docs/manifest-schema.md + docs/schema/ §Planning intelligence: states the lower-numbered dependency invariant
ok:   docs/manifest-schema.md + docs/schema/ §Planning intelligence: names the Critical-path override recording
ok:   docs/manifest-schema.md + docs/schema/ §Autopilot: has the Critical-path stop row
ok:   docs/manifest-schema.md + docs/schema/ §Autopilot: Critical-path stop is unconditional
ok:   commands/ff-plan.md: has the derive-planning-intelligence instruction
ok:   commands/ff-plan.md: states the critical path is derived, not hand-authored
ok:   commands/ff-plan.md: derive instruction sits between AC-mapping (75) and Outcome-gate population (124)
ok:   commands/ff-implement.md: has a '## Critical-path check' section
ok:   commands/ff-implement.md §Critical-path check: resolves via artifacts.plan
ok:   commands/ff-implement.md §Critical-path check: STOP is unconditional in both modes
ok:   commands/ff-implement.md §Critical-path check: override recorded verbatim
ok:   commands/ff-implement.md §Critical-path check: names the Rollback plan as recovery
ok:   commands/ff-implement.md: '## Critical-path check' sits between Decision recall and Do the work — feature track
ok:   commands/ff-verify.md: cross-references the plan's Risk register
ok:   commands/ff-verify.md: resolves the plan via artifacts.plan
ok:   config/defaults.json: no planning-intelligence config key (always-on, as required)
ok:   docs/manifest-schema.md + docs/schema/: no new top-level manifest field for planning intelligence
ok:   dist parity: templates/plan.md
ok:   dist parity: templates/plan-bugfix.md
ok:   dist parity: docs/manifest-schema.md
ok:   dist parity: docs/schema/assumption-records.md
ok:   dist parity: docs/schema/autopilot.md
ok:   dist parity: docs/schema/delivery.md
ok:   dist parity: docs/schema/design-tradeoffs.md
ok:   dist parity: docs/schema/discovery-fields.md
ok:   dist parity: docs/schema/disk-inference.md
ok:   dist parity: docs/schema/enforcement.md
ok:   dist parity: docs/schema/evidence.md
ok:   dist parity: docs/schema/knowledge-base.md
ok:   dist parity: docs/schema/planning-intelligence.md
ok:   dist parity: docs/schema/retrospective.md
ok:   dist parity: docs/schema/sign-off-rendering.md
ok:   dist parity: docs/schema/task-controller.md
ok:   dist parity: docs/schema/terminal-convergence.md
ok:   dist parity: commands/ff-plan.md
ok:   dist parity: commands/ff-implement.md
ok:   dist parity: commands/ff-verify.md
PASS: planning-intelligence guard
EXIT_CODE=0
=== repair-loop-guard.sh ===
ok:   docs/manifest-schema.md + docs/schema/ §Autopilot: 'Verify repair-and-re-verify cycle' mandatory-pause row present
ok:   docs/manifest-schema.md + docs/schema/ §Autopilot: repair-cycle row correctly avoids 'unconditional'
ok:   docs/manifest-schema.md + docs/schema/: 'Repair-and-re-verify cycle' subsection present (mirrors Fix-and-re-review cycle)
ok:   commands/ff-verify.md: repair branch (132) sits inside 'Refuse premature done' (126), before the fall-through STOP (152)
ok:   commands/ff-verify.md: repair branch names the full-tier-only precondition
ok:   commands/ff-verify.md: re-verify is scoped to only the named re-touched ACs
ok:   commands/ff-verify.md: names the 'scoped repair re-verify' the runner keys off
ok:   commands/ff-verify.md: states the evidence-preservation exception
ok:   agents/ff-test-runner.md: carries the scoped-repair carve-out (do not clear evidence/)
ok:   templates/verify.md: '## Repair' section present
ok:   templates/verify.md: '## Repair' carries \*\*Triggering item:\*\*
ok:   templates/verify.md: '## Repair' carries \*\*Captured failure:\*\*
ok:   templates/verify.md: '## Repair' carries \*\*Diagnosis:\*\*
ok:   templates/verify.md: '## Repair' carries \*\*Fix applied:\*\*
ok:   templates/verify.md: '## Repair' carries \*\*Re-touched items
ok:   templates/verify.md: '## Repair' carries \*\*Re-verify outcome:\*\*
ok:   templates/verify.md: '## Repair' Re-touched line names the bugfix track too (not AC-only)
ok:   config/defaults.json: no new repair config key
ok:   docs/manifest-schema.md + docs/schema/: no new top-level manifest field for repair cycles
ok:   dist parity: commands/ff-verify.md
ok:   dist parity: templates/verify.md
ok:   dist parity: agents/ff-test-runner.md
ok:   dist parity: docs/manifest-schema.md
ok:   dist parity: docs/schema/assumption-records.md
ok:   dist parity: docs/schema/autopilot.md
ok:   dist parity: docs/schema/delivery.md
ok:   dist parity: docs/schema/design-tradeoffs.md
ok:   dist parity: docs/schema/discovery-fields.md
ok:   dist parity: docs/schema/disk-inference.md
ok:   dist parity: docs/schema/enforcement.md
ok:   dist parity: docs/schema/evidence.md
ok:   dist parity: docs/schema/knowledge-base.md
ok:   dist parity: docs/schema/planning-intelligence.md
ok:   dist parity: docs/schema/retrospective.md
ok:   dist parity: docs/schema/sign-off-rendering.md
ok:   dist parity: docs/schema/task-controller.md
ok:   dist parity: docs/schema/terminal-convergence.md
ok:   dist parity: skills/feature-flow/SKILL.md
ok:   dist parity: README.md
PASS: repair-loop guard
EXIT_CODE=0
=== retro-guard.sh ===
ok:   docs/manifest-schema.md + docs/schema/: '## Retrospective' section present
ok:   §Retrospective: ### Materiality test
ok:   §Retrospective: ### Candidate schema
ok:   §Retrospective: ### Confirm gate
ok:   §Retrospective: ### Signals
ok:   §Retrospective: worked` · `failed` · `missing` · `ambiguous` · `bypassed
ok:   §Retrospective: one-off` · `repo-specific` · `reusable
ok:   §Retrospective: regression/forward test
ok:   §Retrospective: Fired input / Expected outcome / Control input
ok:   §Retrospective: nothing is written until the user accepts, edits, or rejects
ok:   §Retrospective: NOT extended with `retro`
ok:   §Retrospective: _No material events._
ok:   §Retrospective: no numeric scores
ok:   docs/manifest-schema.md + docs/schema/: durable-eligible set includes 'retro'
ok:   docs/manifest-schema.md + docs/schema/: field note for phases.retro/artifacts.retro
ok:   docs/manifest-schema.md + docs/schema/: 'Retro is never chained'
ok:   docs/manifest-schema.md + docs/schema/: §Autopilot mandatory-pauses row for the retro confirm-gate
ok:   docs/manifest-schema.md + docs/schema/: retro confirm-gate row is not 'unconditional' (passive confirm-gate shape)
ok:   schemas/manifest-v1.schema.json: phases.retro + all four track enums; currentPhase enum omits retro
ok:   commands/ff-retro.md: references §Retrospective by name
ok:   commands/ff-retro.md: done gate
ok:   commands/ff-retro.md: done gate writes nothing (AC1)
ok:   commands/ff-retro.md: no tier gate (lite allowed)
ok:   commands/ff-retro.md: re-run guard (AC9)
ok:   commands/ff-retro.md: resolves artifacts.spec by pointer
ok:   commands/ff-retro.md: resolves artifacts.diagnosis by pointer
ok:   commands/ff-retro.md: resolves artifacts.design by pointer
ok:   commands/ff-retro.md: resolves artifacts.decision by pointer
ok:   commands/ff-retro.md: resolves artifacts.plan by pointer
ok:   commands/ff-retro.md: resolves artifacts.review by pointer
ok:   commands/ff-retro.md: resolves artifacts.verify by pointer
ok:   commands/ff-retro.md: resolves artifacts.delivery by pointer
ok:   commands/ff-retro.md: confirm gate (AC5)
ok:   commands/ff-retro.md: gate never self-answered
ok:   commands/ff-retro.md: never autopilot-chained (AC8)
ok:   commands/ff-retro.md: durable write (AC6)
ok:   commands/ff-retro.md: records artifacts.retro
ok:   commands/ff-retro.md: records phases.retro
ok:   commands/ff-retro.md: currentPhase stays done
ok:   commands/ff-retro.md: writes nothing else (AC6)
ok:   commands/ff-retro.md: forward-test case shape (AC10)
ok:   templates/retro.md: field 'Event'
ok:   templates/retro.md: field 'Expected'
ok:   templates/retro.md: field 'Observed evidence'
ok:   templates/retro.md: field 'Impact'
ok:   templates/retro.md: field 'Safeguard'
ok:   templates/retro.md: field 'Safeguard result'
ok:   templates/retro.md: field 'Generalizability'
ok:   templates/retro.md: field 'Recommended owner'
ok:   templates/retro.md: field 'Proposed validation'
ok:   templates/retro.md: safeguard-result enum
ok:   templates/retro.md: generalizability enum
ok:   templates/retro.md: owner enum includes regression/forward test
ok:   templates/retro.md: zero-candidate sentinel (AC7)
ok:   templates/retro.md: all-rejected sentinel (never 'no material events')
ok:   commands/ff-retro.md: all-rejected sentinel in the command
ok:   templates/retro.md: rejected count section
ok:   templates/retro.md: forward-test case shape (AC10)
ok:   commands/ff-verify.md: completion names ff-deliver + ff-retro as optional next steps
ok:   commands/ff-review.md: completion names ff-deliver + ff-retro as optional next steps
ok:   SKILL.md references ff-retro
ok:   README.md references ff-retro
ok:   dist parity: commands/ff-retro.md
ok:   dist parity: templates/retro.md
ok:   dist parity: docs/manifest-schema.md
ok:   dist parity: docs/schema/assumption-records.md
ok:   dist parity: docs/schema/autopilot.md
ok:   dist parity: docs/schema/delivery.md
ok:   dist parity: docs/schema/design-tradeoffs.md
ok:   dist parity: docs/schema/discovery-fields.md
ok:   dist parity: docs/schema/disk-inference.md
ok:   dist parity: docs/schema/enforcement.md
ok:   dist parity: docs/schema/evidence.md
ok:   dist parity: docs/schema/knowledge-base.md
ok:   dist parity: docs/schema/planning-intelligence.md
ok:   dist parity: docs/schema/retrospective.md
ok:   dist parity: docs/schema/sign-off-rendering.md
ok:   dist parity: docs/schema/task-controller.md
ok:   dist parity: docs/schema/terminal-convergence.md
ok:   dist parity: commands/ff-verify.md
ok:   dist parity: commands/ff-review.md
ok:   dist parity: skills/feature-flow/SKILL.md
ok:   dist parity: README.md
PASS: retro guard
EXIT_CODE=0
=== revision-binding-guard.sh ===
ok:   AC12: commands/ff.md writes revisionBound: true at creation
ok:   AC12: commands/ff-explore.md writes revisionBound: true at creation
ok:   AC12: commands/ff-clarify.md writes revisionBound: true at creation
ok:   AC12: commands/ff-diagnose.md writes revisionBound: true at creation
ok:   AC13: docs/manifest-schema.md Schema + field note for revisionBound
ok:   AC13: docs/manifest-schema.md Schema + field note for phases.<review|verify>.revision
ok:   AC13: docs/manifest-schema.md states the absent-field back-compat rule
ok:   AC13: docs/schema/enforcement.md Gate B states the revision condition and both reasons
ok:   AC13: docs/schema/enforcement.md separates the silent skip from the loud allow
ok:   AC13: docs/schema/enforcement.md defines ### Revision fingerprint
ok:   AC13: docs/schema/enforcement.md states the WP4 preservation constraint
ok:   AC13: docs/schema/terminal-convergence.md defines Revision agreement and routes to the stale-phase cycle
ok:   AC13: docs/schema/autopilot.md defines the Stale-phase re-run cycle with its durable one-cycle cap
ok:   AC13: docs/schema/autopilot.md mandatory-pauses row is capped-then-stop (not 'unconditional')
ok:   AC13: commands/ff-review.md stamps the revision (verbatim recipe) and checks Revision agreement
ok:   AC13: commands/ff-verify.md stamps the revision (verbatim recipe) and checks Revision agreement
ok:   AC13: commands/ff-review.md stamps before its manifest update
ok:   AC13: commands/ff-verify.md stamps before its manifest update
ok:   AC13: templates/review.md has a digit-free **Revision:** line and a ## Stale re-run skeleton
ok:   AC13: templates/verify.md has a digit-free **Revision:** line and a ## Stale re-run skeleton
ok:   AC13: newest CHANGELOG entry states the WP4 constraint
ok:   FS2: docs/schema/enforcement.md §Revision fingerprint block is hooks/lib/revision.sh byte-for-byte
ok:   FS2 self-test: a one-character drift is caught
ok:   dflt: lib defaults (.feature-flow .feature-flow-kb) = config/defaults.json paths
PASS: revision-binding guard
EXIT_CODE=0
=== run-start-ask-guard.sh ===
ok:   commands/ff.md: resolve-autopilot@67 precedes write@79
ok:   commands/ff-explore.md: resolve-autopilot@28 precedes write@31
ok:   commands/ff-clarify.md: resolve-autopilot@25 precedes write@28
ok:   commands/ff-diagnose.md: resolve-autopilot@28 precedes write@31
ok:   ff.md: creation field list includes autopilot
ok:   commands/ff-explore.md: creation write includes autopilot
ok:   commands/ff-clarify.md: creation write includes autopilot
ok:   commands/ff-diagnose.md: creation write includes autopilot
ok:   manifest-schema.md: run-start is resolve-before-write
ok:   manifest-schema.md: creation rule lists autopilot
ok:   SKILL.md: doctrine line present
ok:   manifest-schema.md: gate table has 'Run-start mode ask' row
ok:   ff-status.md: prints the autopilot mode
PASS: run-start ask guard
EXIT_CODE=0
=== schema-layout-guard.sh ===
ok:   L1: docs/schema/evidence.md is the topic header, a blank line, then exactly '## Evidence'
ok:   L1: docs/schema/enforcement.md is the topic header, a blank line, then exactly '## Enforcement (Claude Code)'
ok:   L1: docs/schema/disk-inference.md is the topic header, a blank line, then exactly '## Disk inference procedure'
ok:   L1: docs/schema/sign-off-rendering.md is the topic header, a blank line, then exactly '## Sign-off rendering'
ok:   L1: docs/schema/terminal-convergence.md is the topic header, a blank line, then exactly '## Terminal convergence'
ok:   L1: docs/schema/knowledge-base.md is the topic header, a blank line, then exactly '## Knowledge base'
ok:   L1: docs/schema/planning-intelligence.md is the topic header, a blank line, then exactly '## Planning intelligence'
ok:   L1: docs/schema/task-controller.md is the topic header, a blank line, then exactly '## Task controller'
ok:   L1: docs/schema/assumption-records.md is the topic header, a blank line, then exactly '## Assumption records'
ok:   L1: docs/schema/design-tradeoffs.md is the topic header, a blank line, then exactly '## Design trade-offs & devil's advocate'
ok:   L1: docs/schema/discovery-fields.md is the topic header, a blank line, then exactly '## Discovery fields'
ok:   L1: docs/schema/autopilot.md is the topic header, a blank line, then exactly '## Autopilot'
ok:   L1: docs/schema/delivery.md is the topic header, a blank line, then exactly '## Delivery'
ok:   L1: docs/schema/retrospective.md is the topic header, a blank line, then exactly '## Retrospective'
ok:   L1 self-test: text above the '## ' heading is rejected
ok:   L2: docs/manifest-schema.md holds exactly the Topic index + the core topics, in order
ok:   L2: joined contract holds every layout topic exactly once, in contract order
ok:   L3: Topic index lists docs/schema/evidence.md
ok:   L3: Topic index lists docs/schema/enforcement.md
ok:   L3: Topic index lists docs/schema/disk-inference.md
ok:   L3: Topic index lists docs/schema/sign-off-rendering.md
ok:   L3: Topic index lists docs/schema/terminal-convergence.md
ok:   L3: Topic index lists docs/schema/knowledge-base.md
ok:   L3: Topic index lists docs/schema/planning-intelligence.md
ok:   L3: Topic index lists docs/schema/task-controller.md
ok:   L3: Topic index lists docs/schema/assumption-records.md
ok:   L3: Topic index lists docs/schema/design-tradeoffs.md
ok:   L3: Topic index lists docs/schema/discovery-fields.md
ok:   L3: Topic index lists docs/schema/autopilot.md
ok:   L3: Topic index lists docs/schema/delivery.md
ok:   L3: Topic index lists docs/schema/retrospective.md
ok:   L3: indexed path docs/schema/assumption-records.md exists
ok:   L3: indexed path docs/schema/autopilot.md exists
ok:   L3: indexed path docs/schema/delivery.md exists
ok:   L3: indexed path docs/schema/design-tradeoffs.md exists
ok:   L3: indexed path docs/schema/discovery-fields.md exists
ok:   L3: indexed path docs/schema/disk-inference.md exists
ok:   L3: indexed path docs/schema/enforcement.md exists
ok:   L3: indexed path docs/schema/evidence.md exists
ok:   L3: indexed path docs/schema/knowledge-base.md exists
ok:   L3: indexed path docs/schema/planning-intelligence.md exists
ok:   L3: indexed path docs/schema/retrospective.md exists
ok:   L3: indexed path docs/schema/sign-off-rendering.md exists
ok:   L3: indexed path docs/schema/task-controller.md exists
ok:   L3: indexed path docs/schema/terminal-convergence.md exists
ok:   L4 self-test: blockquote-wrapped reference to a moved topic is caught
ok:   L4 self-test: a mention is not a definition
ok:   L4 self-test: a correct wrapped reference passes
ok:   L4 self-test: a '§Name, path' reference to the wrong file is caught
ok:   L4 self-test: an unnamed path to a missing schema file is caught
ok:   L4: commands/ff-abandon.md schema references resolve
ok:   L4: commands/ff-clarify.md schema references resolve
ok:   L4: commands/ff-close.md schema references resolve
ok:   L4: commands/ff-deliver.md schema references resolve
ok:   L4: commands/ff-design.md schema references resolve
ok:   L4: commands/ff-diagnose.md schema references resolve
ok:   L4: commands/ff-explore.md schema references resolve
ok:   L4: commands/ff-implement.md schema references resolve
ok:   L4: commands/ff-list.md schema references resolve
ok:   L4: commands/ff.md schema references resolve
ok:   L4: commands/ff-plan.md schema references resolve
ok:   L4: commands/ff-resume.md schema references resolve
ok:   L4: commands/ff-retro.md schema references resolve
ok:   L4: commands/ff-review.md schema references resolve
ok:   L4: commands/ff-status.md schema references resolve
ok:   L4: commands/ff-verify.md schema references resolve
ok:   L4: templates/decision.md schema references resolve
ok:   L4: templates/delivery.md schema references resolve
ok:   L4: templates/design.md schema references resolve
ok:   L4: templates/diagnosis.md schema references resolve
ok:   L4: templates/explore.md schema references resolve
ok:   L4: templates/kb-entry.md schema references resolve
ok:   L4: templates/plan-bugfix.md schema references resolve
ok:   L4: templates/plan.md schema references resolve
ok:   L4: templates/retro.md schema references resolve
ok:   L4: templates/review.md schema references resolve
ok:   L4: templates/spec.md schema references resolve
ok:   L4: templates/verify.md schema references resolve
ok:   L4: agents/ff-code-architect.md schema references resolve
ok:   L4: agents/ff-code-explorer.md schema references resolve
ok:   L4: agents/ff-code-reviewer.md schema references resolve
ok:   L4: agents/ff-diagnostician.md schema references resolve
ok:   L4: agents/ff-implementer.md schema references resolve
ok:   L4: agents/ff-test-runner.md schema references resolve
ok:   L4: skills/feature-flow/SKILL.md schema references resolve
ok:   L4: skills/feature-flow/references/codex-tools.md schema references resolve
ok:   L4: README.md schema references resolve
ok:   L4: ff-explore's generic (schema: …) reference stays on the core
ok:   L4: ff.md's generic 'per the contract' reference stays on the core
ok:   L4: SKILL.md states the core + named-topic-files reading rule
ok:   L4: SKILL.md reading rule counts a bare §Name / **Name** mention as naming the topic
ok:   L3: Topic index says its paths are relative to the plugin root
ok:   L5: dist parity: docs/manifest-schema.md
ok:   L5: dist parity: docs/schema/assumption-records.md
ok:   L5: dist parity: docs/schema/autopilot.md
ok:   L5: dist parity: docs/schema/delivery.md
ok:   L5: dist parity: docs/schema/design-tradeoffs.md
ok:   L5: dist parity: docs/schema/discovery-fields.md
ok:   L5: dist parity: docs/schema/disk-inference.md
ok:   L5: dist parity: docs/schema/enforcement.md
ok:   L5: dist parity: docs/schema/evidence.md
ok:   L5: dist parity: docs/schema/knowledge-base.md
ok:   L5: dist parity: docs/schema/planning-intelligence.md
ok:   L5: dist parity: docs/schema/retrospective.md
ok:   L5: dist parity: docs/schema/sign-off-rendering.md
ok:   L5: dist parity: docs/schema/task-controller.md
ok:   L5: dist parity: docs/schema/terminal-convergence.md
PASS: schema-layout guard
EXIT_CODE=0
=== session-start-guard.sh ===
ok:   no runs: pointer present
ok:   no runs: no active-run block
ok:   compact: pointer still present
ok:   compact: active-run block
ok:   compact: slug
ok:   compact: track/tier
ok:   compact: phase + status
ok:   compact: autopilot
ok:   compact: sign-off
ok:   compact: resume command
ok:   compact: bare artifact → run-dir path
ok:   compact: slashed artifact → as-is
ok:   compact: mid-run wording
ok:   compact: re-read-from-disk directive
ok:   startup: active-run block
ok:   startup: conditional wording
ok:   startup: no mid-run assertion
ok:   clear: active-run block
ok:   clear: conditional wording
ok:   clear: no mid-run assertion
ok:   terminal runs only: no active-run block
ok:   corrupt sibling: valid run listed
ok:   corrupt sibling: broken run skipped
ok:   bugfix lite: signed-off n/a
ok:   cap: oldest run dropped
ok:   cap: overflow noted
ok:   cap: newest run listed first
ok:   paths.base: run found
ok:   paths.base: path uses custom base
ok:   unsigned feature: signed off: no
ok:   control chars (compact): output is valid JSON with the run block
ok:   control chars (startup): output is valid JSON with the run block
ok:   jq absent: pointer present, valid JSON
ok:   jq absent: no active-run block
ok:   empty stdin: valid JSON pointer
ok:   hooks.json SessionStart matcher covers startup
ok:   hooks.json SessionStart matcher covers clear
ok:   hooks.json SessionStart matcher covers compact
ok:   ledger: current task + fix round named
ok:   ledger: pointer listed as-is
ok:   ledger: every task complete → no task
ok:   ledger: missing file → no task, no error
ok:   ledger: missing file → run still listed
PASS: session-start guard
EXIT_CODE=0
=== single-architect-guard.sh ===
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
ok:   FS1: commands/ff-design.md has 'Name `<run dir>/architect.md` as its **report path**'
ok:   FS1: commands/ff-design.md has '**do not re-emit it**'
ok:   FS1: commands/ff-design.md has 'only if it does not (the write failed'
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
ok:   AC4: report written (89) before the choice pause (96), before the devil's-advocate pass (120)
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
=== spec-conformance-guard.sh ===
ok:   commands/ff-review.md: has a '## Spec conformance' section
ok:   SC1: dispatches a dedicated ff-code-reviewer for spec conformance
ok:   SC1: not counted against reviewerAgents
ok:   SC2: resolves the contract via manifest.artifacts\.spec
ok:   SC2: resolves the contract via manifest.artifacts\.plan
ok:   SC2: resolves the contract via manifest.artifacts\.diagnosis
ok:   SC2: passes the same diff the focus reviewers get
ok:   SC3: unimplemented / partial criterion → Critical
ok:   SC3: out-of-scope change → Important
ok:   SC3: unrealized plan task → Important
ok:   SC4: commands/ff-review.md carries the over-engineering guard
ok:   SC4: agents/ff-code-reviewer.md carries the over-engineering guard
ok:   SC4: agents/ff-code-reviewer.md says style / speculative hardening is never Critical
ok:   SC5: templates/review.md has '## Spec conformance' before '## Critical'
ok:   SC6: skills/feature-flow/SKILL.md mentions spec conformance
ok:   SC6: README.md mentions spec conformance
ok:   dist parity: commands/ff-review.md
ok:   dist parity: agents/ff-code-reviewer.md
ok:   dist parity: templates/review.md
ok:   dist parity: skills/feature-flow/SKILL.md
ok:   dist parity: README.md
PASS: spec-conformance guard
EXIT_CODE=0
=== version-sync-guard.sh ===
ok:   .claude-plugin/plugin.json: canonical version 0.24.0
ok:   .codex-plugin/plugin.json: version 0.24.0 matches canonical
ok:   .claude-plugin/marketplace.json: version 0.24.0 matches canonical
ok:   README.md: Status badge reads v0.24.0
ok:   CHANGELOG.md: newest entry is [0.24.0]
PASS: version-sync guard (0.24.0)
EXIT_CODE=0
=== integrity-conformance-guard.sh (run separately) ===
FAIL: Go toolchain is required for WP1 conformance
EXIT_CODE=1
---go check---
go_exit=1
```
