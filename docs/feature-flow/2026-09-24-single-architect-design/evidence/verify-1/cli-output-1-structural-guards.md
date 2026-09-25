# Structural guards run — 2026-09-25T04:38:48Z
## assumption-guard.sh
```
exit: 0
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
```
## claude-dist-guard.sh
```
exit: 0
ok:   top-level entries are exactly the allowlist
ok:   docs/ holds only manifest-schema.md + schema/ + grilling-playbook.md
ok:   docs/schema/ holds exactly the 14 topic files
ok:   .claude-plugin/ holds only plugin.json + marketplace.json
ok:   no dev-only files in the package
ok:   every ${CLAUDE_PLUGIN_ROOT} reference resolves inside the package
ok:   packaged marketplace.json: feature-flow from "./" at the plugin.json version
ok:   master marketplace.json: plugin source = url https …feature-flow.git @ ref dist, version synced
PASS: claude-dist guard
```
## decision-record-guard.sh
```
exit: 0
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
```
## delivery-guard.sh
```
exit: 0
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
```
## design-tradeoff-guard.sh
```
exit: 0
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
```
## discovery-fields-guard.sh
```
exit: 0
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
```
## dist-parity-guard.sh
```
exit: 0
ok:   checked 62 packaged files (0 drifted, 0 orphaned)
PASS: dist parity guard (62 files in sync)
```
## durable-paths-guard.sh
```
exit: 0
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
```
## enforce-gate-guard.sh
```
exit: 0
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
ok:   rev lib/FS4: durable form {"paths":{"durable":"/tmp/tmp.5rbTqqx2Yz/rev-repo/docs/ff"}} is excluded
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
```
## evidence-guard.sh
```
exit: 0
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
```
## forward-test-guard.sh
```
exit: 0
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
ok:   .gitignore: planted sandbox run state is committable
ok:   scripts/forward-test.sh present + executable
ok:   no forward-test runner under scripts/checks/
ok:   Codex dist excludes evals/
ok:   Codex dist excludes the runner
PASS: forward-test guard
```
## fresh-context-interview-guard.sh
```
exit: 0
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
```
## implement-controller-guard.sh
```
exit: 0
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
```
## integrity-boundary-guard.sh
```
exit: 0
ok:   current commands/hooks/templates/config do not invoke doctor or migration
ok:   schemas/manifest-v1.schema.json parses
ok:   schemas/golden-vector-v1.schema.json parses
ok:   schemas/doctor-result-v1.schema.json parses
ok:   schemas/migration-plan-v1.schema.json parses
ok:   integrity/protocol/v1/diagnostics.json parses
ok:   integrity/testdata/vectors/v1/index.json parses
ok:   integrity/testdata/legacy/inventory-v1.json parses
PASS: integrity boundary guard
```
## integrity-conformance-guard.sh
```
exit: 1
FAIL: Go toolchain is required for WP1 conformance
```
## integrity-wp2-guard.sh
```
exit: 0
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
```
## kb-guard.sh
```
exit: 0
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
```
## lite-tier-guard.sh
```
exit: 0
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
```
## planning-intelligence-guard.sh
```
exit: 0
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
```
## repair-loop-guard.sh
```
exit: 0
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
```
## retro-guard.sh
```
exit: 0
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
```
## revision-binding-guard.sh
```
exit: 0
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
```
## run-start-ask-guard.sh
```
exit: 0
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
```
## schema-layout-guard.sh
```
exit: 0
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
```
## session-start-guard.sh
```
exit: 0
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
```
## spec-conformance-guard.sh
```
exit: 0
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
```
## version-sync-guard.sh
```
exit: 0
ok:   .claude-plugin/plugin.json: canonical version 0.24.0
ok:   .codex-plugin/plugin.json: version 0.24.0 matches canonical
ok:   .claude-plugin/marketplace.json: version 0.24.0 matches canonical
ok:   README.md: Status badge reads v0.24.0
ok:   CHANGELOG.md: newest entry is [0.24.0]
PASS: version-sync guard (0.24.0)
```
