# Feature Flow Architectural Review

**Review date:** 2026-07-23
**Repository baseline:** `6c52d49` (`v0.17.0`, `master`)
**Scope:** Framework source, commands, agents, templates, hooks, schema, evaluation harness, 170 Codex session logs, and 30 real Feature Flow run directories
**Assessment:** Strong workflow design; weak runtime guarantees

## 1. Executive Summary

Feature Flow is already better than a typical collection of coding-agent prompts. It has an explicit lifecycle, proportional `lite` and `full` modes, human signoff, durable artifacts, bounded repair loops, requirement traceability, evidence gaps, and role separation. These are the right primitives.

The principal weakness is architectural: **Feature Flow describes a state machine but does not actually implement one**. Its authoritative behavior is distributed across long Markdown commands, agent prompts, templates, shell guards, and conventions that the model is expected to interpret consistently. The current checks mostly prove that required phrases and headings exist in those files. They do not prove that a real run obeys phase ordering, uses a valid manifest, reviews and verifies the same code revision, or resumes safely.

Real-world evidence shows the consequence:

- All repository guard scripts and the evaluation harness pass.
- Yet 11 of 30 inspected real manifests violate current schema or terminal-state invariants.
- Several completed runs have verification artifacts that would fail the current Gate B contract.
- Some runs end conversationally while their manifests remain in `review`, `verify`, or another non-terminal phase.
- A hard-coded one-repair limit caused an agent to invent an undocumented `secondRepairWaiver` field after a user override.
- Long implementation sessions reached 332–426 tool calls and five context compactions, despite Feature Flow defining specialist roles intended to reduce context load.

The most serious correctness defect is a cross-phase assurance gap:

- Feature work runs `review` and then `verify`. If verification repairs code, review is not invalidated.
- Bugfix work runs `verify` and then `review`. If review repairs code, verification is not invalidated.

Feature Flow can therefore declare completion even though the final code revision was not both reviewed and verified. This is a release-integrity issue, not a documentation issue.

The vNext direction should be:

> Keep prompts for judgment; move workflow truth, transitions, locks, provenance, invalidation, and policy into a deterministic core.

The recommended target architecture is a small cross-platform `ffctl` runtime backed by a versioned schema, append-only event log, content-addressed artifacts, code-revision attestations, native Claude Code and Codex adapters, isolated phase workers, safe verification profiles, and a trajectory-based evaluation lab.

### Overall maturity assessment

| Dimension | Assessment | Rationale |
|---|---|---|
| Workflow conception | Strong | Clear lifecycle, gates, bounded repair, traceability |
| Prompt design | Good but over-distributed | Thoughtful individual prompts; duplicated policy and platform drift |
| Runtime enforcement | Weak | Most invariants are prose or shallow regex checks |
| Verification philosophy | Strong | Evidence-oriented, honest gap handling |
| Verification integrity | At risk | Review/verify can attest different code revisions |
| Multi-session continuity | Moderate | Durable artifacts exist; replay, migration, and checkpoint semantics do not |
| Multi-agent architecture | Moderate on paper, weak in practice | Roles exist, but portable isolation and orchestration are incomplete |
| Knowledge system | Early | Useful capture/retrieval concept; no robust indexing, provenance, or trust model |
| Scalability | Weak to moderate | Long prompts, large main-context sessions, linear Markdown artifacts |
| Security posture | Incomplete | Arbitrary project command execution, untrusted artifact ingestion, weak redaction |
| Evaluation maturity | Early | Good structural smoke tests; little behavioral or trajectory validation |

## 2. Strengths of the Current Framework

### 2.1 A coherent lifecycle rather than ad hoc prompting

The feature track—explore, clarify, design, plan, implement, review, verify—and the bugfix track—diagnose, implement with RED/GREEN, verify, review—give agents and humans a shared vocabulary. The distinction between feature and bugfix work is meaningful rather than cosmetic.

### 2.2 Proportional process

`lite` and `full` modes are a valuable answer to workflow ceremony. Small changes do not need the same artifacts and gates as architectural work. The concept should be retained, although tier selection should become policy-driven and observable.

### 2.3 Explicit human authority

The framework correctly prevents agents from silently inventing user approval. Clarification signoff, assumption acknowledgement, design choice, evidence-gap waivers, and delivery confirmation establish clear human authority boundaries.

### 2.4 Evidence-oriented verification

Feature Flow distinguishes contract evidence, behavioral evidence, coverage, and known limitations. It treats unverified conditions as gaps instead of automatically converting them into success. This is materially better than “tests passed” as a universal completion claim.

### 2.5 Durable artifacts and resumability

Manifests, phase artifacts, decisions, and knowledge-base captures provide better continuity than chat history alone. This aligns with current long-running-agent guidance: plans, state, and evaluator feedback should live in structured artifacts outside the context window.

### 2.6 Bounded repair and critique loops

The one-cycle repair and re-review concept protects against silent infinite loops and forces escalation. The fixed number is too rigid, but the underlying principle—explicit budgets with an audit trail—is sound.

### 2.7 Specialist-role intent

Explorer, reviewer, test runner, knowledge retriever, and knowledge capturer roles express useful separation of concerns and allow narrower tools and prompts. This is directionally aligned with subagent systems that use isolated contexts and role-specific permissions.

### 2.8 Good packaging discipline

Repository checks cover plugin parity, command presence, schema references, hook behavior, and fixture structure. The framework has a release process and CI rather than relying only on manual inspection.

### 2.9 Honest non-goals

The framework generally avoids pretending that all environments can be provisioned or all external behavior can be verified automatically. That honesty is a good base for a stronger policy system.

## 3. Weaknesses and Pain Points

The following register is the authoritative list of review findings. Later sections reference these IDs. Effort estimates assume one experienced maintainer and include implementation plus focused tests:

- **S:** 1–3 engineering days
- **M:** 1–2 weeks
- **L:** 3–6 weeks
- **XL:** 2–3 months

### F01 — Review and verification can attest different code revisions

- **Current behavior:** Feature runs review before verification; verification may repair code without re-review. Bugfix runs verification before review; review may repair code without re-verification.
- **Root cause:** Artifacts have no code-revision identity, dependency graph, or invalidation semantics. Repair loops are local to a phase.
- **Impact:** Feature Flow can mark a run complete while the final code has not passed both assurance gates. This undermines the central reliability claim.
- **Recommended improvement:** Define a code revision digest for every implementation state. Completion requires both `review_passed(revision)` and `verification_passed(revision)`. Any code mutation creates a new revision and invalidates both attestations. Run a bounded convergence loop until both pass on the same digest.
- **Expected benefits:** Release-grade assurance, deterministic completion criteria, clear audit history.
- **Priority:** **Critical**
- **Effort:** M
- **Risks/trade-offs:** More cycles and latency; requires reliable change-set hashing and mutation detection.

### F02 — Prompt text is acting as the workflow runtime

- **Current behavior:** Transition rules, retry policy, gates, artifact requirements, and platform behavior are spread across commands, agents, templates, schema prose, and shell checks.
- **Root cause:** Feature Flow evolved as a prompt/plugin package without a deterministic workflow engine.
- **Impact:** Policy drift, inconsistent interpretation, fragile updates, high context cost, and behavior that structural tests cannot validate.
- **Recommended improvement:** Introduce a declarative workflow definition and deterministic `ffctl` core for transitions, validation, invalidation, locks, checkpoints, and policy. Keep prompts responsible for analysis and judgment.
- **Expected benefits:** One source of truth, smaller prompts, portable adapters, testable invariants.
- **Priority:** **Critical**
- **Effort:** L
- **Risks/trade-offs:** Adds a runtime dependency and migration burden; over-engineering is possible if the core absorbs judgment that belongs in the model.

### F03 — The manifest is unversioned and weakly typed

- **Current behavior:** Compatibility relies on prose about absent fields. There is no `schemaVersion`, executable JSON Schema, or migration tool.
- **Root cause:** The manifest schema is documentation rather than a machine-enforced contract.
- **Impact:** In the inspected sample, manifests contain `completed` versus `complete`, `currentPhase: complete`, missing or null tier/mode values, missing slugs, and inconsistent terminal states.
- **Recommended improvement:** Add `schemaVersion`, publish JSON Schema, validate on every read/write, and provide explicit forward migrations plus a read-only `ff doctor`.
- **Expected benefits:** Reliable resume, actionable diagnostics, safe framework upgrades.
- **Priority:** **Critical**
- **Effort:** M
- **Risks/trade-offs:** Old runs will initially fail validation; migration must preserve evidence and user decisions.

### F04 — Concurrency, locking, and writes are not transaction-safe

- **Current behavior:** The schema describes whole-object atomic writes and an advisory lock with a 15-minute expiry. Agents perform read-modify-write operations through general file tools.
- **Root cause:** There is no compare-and-swap revision, OS-level lock, write transaction, or append-only event history.
- **Impact:** Two sessions can race, overwrite decisions, or misclassify a live long-running lock as stale. One real run retained a stale lock.
- **Recommended improvement:** Use a runtime-managed lock (`flock`, exclusive-create lease, or platform equivalent), manifest revision numbers, compare-and-swap writes, temporary-file plus fsync/rename, idempotency keys, and append-only events.
- **Expected benefits:** Safe parallel sessions, deterministic recovery, forensic traceability.
- **Priority:** **Critical**
- **Effort:** M–L
- **Risks/trade-offs:** Cross-platform locking is non-trivial; leases need clock-skew and crash semantics.

### F05 — Phase prerequisites and terminal invariants are not reliably enforced

- **Current behavior:** Individual phase commands can be invoked out of order. Terminal artifacts can be complete while `currentPhase` is not `done`; some conversationally completed runs remain in earlier phases.
- **Root cause:** Commands independently interpret the manifest; there is no centralized transition function.
- **Impact:** Stale or partial state, confusing resume behavior, and false completion.
- **Recommended improvement:** Encode allowed transitions, prerequisites, terminal invariants, and side effects in the deterministic core. Every command should request a transition rather than edit state directly.
- **Expected benefits:** Predictable lifecycle, easier recovery, simpler prompts.
- **Priority:** **High**
- **Effort:** M
- **Risks/trade-offs:** Strict enforcement can block legitimate recovery unless repair/admin transitions are designed explicitly.

### F06 — Review scope is not bound to the actual change set

- **Current behavior:** Review defaults to unstaged `git diff`, which can omit staged, untracked, generated, or committed changes made during the run.
- **Root cause:** A run does not capture its starting commit/tree, worktree identity, or patch digest.
- **Impact:** Review may inspect only part of the implementation and still pass.
- **Recommended improvement:** Record baseline commit, branch, worktree, dirty-state snapshot, and intended paths. Build a canonical change set from baseline to current revision, including staged/untracked files where policy permits.
- **Expected benefits:** Complete review coverage and reproducible handoff.
- **Priority:** **Critical**
- **Effort:** M
- **Risks/trade-offs:** Pre-existing dirty worktrees need ownership rules; large generated diffs need exclusion policy.

### F07 — Diagnosis can call a static hypothesis “reproduced”

- **Current behavior:** Bug diagnosis may establish a root-cause narrative before an executable reproduction. Full-mode signoff can lock that narrative early.
- **Root cause:** The diagnose phase conflates static evidence, causal confidence, and runtime reproduction.
- **Impact:** Teams can efficiently implement the wrong fix, especially for environment-, data-, timing-, or integration-dependent bugs.
- **Recommended improvement:** Separate `observed`, `statically_supported`, and `runtime_reproduced`. Require an executable failing check before RED/GREEN when safe; otherwise record why reproduction is unavailable and lower confidence.
- **Expected benefits:** Better causal accuracy, stronger regression tests, fewer speculative fixes.
- **Priority:** **High**
- **Effort:** S–M
- **Risks/trade-offs:** Runtime reproduction can be expensive or unsafe; the workflow must support justified exceptions.

### F08 — Verification commands have unmodeled side effects

- **Current behavior:** The test runner can detect and execute repository scripts and CLIs while being described as read-only.
- **Root cause:** Tool permission and filesystem mutation are treated as equivalent to command safety.
- **Impact:** A “verification” step can modify files, databases, queues, cloud resources, or external systems.
- **Recommended improvement:** Introduce named verification profiles with allowlisted commands, declared side effects, timeouts, network policy, environment requirements, and risk classes. Run risky profiles in disposable worktrees/containers with read-only credentials where possible.
- **Expected benefits:** Safer autonomy and repeatable validation.
- **Priority:** **Critical**
- **Effort:** L
- **Risks/trade-offs:** Sandboxing adds setup time and cannot fully model every project command.

### F09 — Evidence confidence overstates independence

- **Current behavior:** Confidence increases with distinct evidence “kinds,” even when multiple kinds derive from the same code path or environment.
- **Root cause:** Evidence is categorized but not modeled with provenance or dependency.
- **Impact:** Correlated signals can look like independent confirmation.
- **Recommended improvement:** Record evidence source, command, environment, revision, dependency group, freshness, and trust. Score orthogonal evidence rather than category count.
- **Expected benefits:** More calibrated confidence and clearer risk communication.
- **Priority:** **Medium**
- **Effort:** M
- **Risks/trade-offs:** Additional metadata and scoring complexity; numeric confidence can still create false precision.

### F10 — The evaluation harness validates prompt structure, not workflow outcomes

- **Current behavior:** Guards primarily search for headings, phrases, and fixture structure. Comments in `scripts/eval.sh` still describe the harness as non-blocking even though CI now treats it as blocking.
- **Root cause:** Evaluation was designed as a fast regression smoke test, but it has become the primary assurance mechanism.
- **Impact:** Every check passes while real manifests and artifacts violate current contracts and F01 remains undetected.
- **Recommended improvement:** Retain fast structural checks, then add disposable-repository behavioral trials, trajectory graders, property tests for the state machine, failure injection, upgrade/resume tests, and repeated trials for nondeterministic agent behavior.
- **Expected benefits:** Measures real compliance, catches interaction defects, and reduces false confidence.
- **Priority:** **Critical**
- **Effort:** L
- **Risks/trade-offs:** Agent evals are slower, costlier, and variable; they need budgets and stable graders.

### F11 — Main-context orchestration does not scale

- **Current behavior:** Long commands and phase procedures remain in the main thread. Real sessions reached 332–426 tool calls and five compactions; specialist roles are not consistently isolated on Codex.
- **Root cause:** Roles are defined primarily as Claude-oriented prompt files, while Codex mapping is narrative and orchestration is not enforced.
- **Impact:** Context rot, repeated rediscovery, higher token cost, and poorer long-horizon consistency.
- **Recommended improvement:** Make the main agent an orchestrator. Run exploration, review, and verification in isolated workers that return bounded typed packets. Add per-phase context budgets and prohibit raw worker logs from entering the main context by default.
- **Expected benefits:** Better focus, parallel read-heavy work, cheaper resume, lower compaction risk.
- **Priority:** **High**
- **Effort:** M–L
- **Risks/trade-offs:** Summaries can omit crucial nuance; parallel work can duplicate effort or race without a strong state core.

### F12 — Platform adapters have drifted; Codex enforcement is outdated

- **Current behavior:** Claude Code gets a hook-based gate. Documentation says Codex lacks equivalent hook enforcement, but current Codex supports lifecycle hooks and project configuration.
- **Root cause:** Platform capability assumptions are frozen in prose and adapters are maintained separately.
- **Impact:** Codex runs depend on model compliance for gates that can now be machine-enforced; behavior differs by host.
- **Recommended improvement:** Define host-neutral policy once, generate Claude and Codex adapters, and add a Codex hook adapter. Add capability detection so unsupported features degrade explicitly.
- **Expected benefits:** Cross-host parity and stronger Codex guarantees.
- **Priority:** **Critical**
- **Effort:** S–M
- **Risks/trade-offs:** Hook lifecycle semantics differ; project hooks require trust and careful failure behavior.

### F13 — Activation and human gates create avoidable ceremony

- **Current behavior:** Autopilot mode is often asked on every run; signoff and open-assumption acknowledgement can require separate turns. Some repositories explicitly request manual-only Feature Flow, yet sessions repeatedly begin by correcting auto-activation.
- **Root cause:** Activation, mode preference, and repository policy are not a coherent persisted configuration.
- **Impact:** Repetitive interaction, user frustration, and wasted tokens before work starts.
- **Recommended improvement:** Add repository-authoritative `activation: auto | manual | off`, persisted mode defaults, risk-based gate policy, and one transactional approval request containing signoff, assumptions, and selected design where appropriate.
- **Expected benefits:** Less ceremony without weakening authority boundaries.
- **Priority:** **High**
- **Effort:** S–M
- **Risks/trade-offs:** Fewer gates can surprise users unless the final approval packet is clear.

### F14 — Knowledge retrieval is a file search, not a memory system

- **Current behavior:** Knowledge entries are retrieved mainly through tags and text. Staleness focuses on age or missing paths; capture SHA is not used to detect changed source content. There is no deduplication, supersession, or trust ranking.
- **Root cause:** The knowledge base stores Markdown but lacks an index and lifecycle model.
- **Impact:** Low recall, stale guidance, duplicate entries, and prompt-injection risk from historical repository text.
- **Recommended improvement:** Build hybrid lexical/semantic retrieval with content hashes, source revision, ownership, confidence, supersession links, decision status, and trust labels. Retrieve small cited excerpts, not entire files.
- **Expected benefits:** Higher recall, less context, safer and more current reuse.
- **Priority:** **High**
- **Effort:** L
- **Risks/trade-offs:** Embeddings add cost and infrastructure; semantic retrieval can return plausible but irrelevant material.

### F15 — Markdown artifacts lack strong provenance

- **Current behavior:** Canonical truth is embedded in human-readable files parsed by heading and token conventions. IDs can be positional; artifact fields have evolved shapes; checksums and producer metadata are absent.
- **Root cause:** Documents serve simultaneously as database, UI, and interchange format.
- **Impact:** Fragile parsing, difficult migrations, accidental drift, and weak auditability.
- **Recommended improvement:** Store canonical typed artifact metadata and claims in JSON, including producer, timestamps, schema version, source revision, inputs, checksums, and dependencies. Generate or retain Markdown as the human view.
- **Expected benefits:** Reliable automation while preserving readable reports.
- **Priority:** **High**
- **Effort:** L
- **Risks/trade-offs:** Dual representations need one-way generation rules to avoid split-brain state.

### F16 — Run lifecycle management does not scale

- **Current behavior:** Run directories accumulate; close and abandon behavior is manual; stale locks and incomplete runs remain mixed with active work.
- **Root cause:** There is no run registry, status dashboard, retention policy, or archival command.
- **Impact:** Discovery slows, stale runs confuse resume, and repository-local state grows indefinitely.
- **Recommended improvement:** Add `ff list`, `ff status`, `ff abandon`, `ff archive`, stale-run detection, configurable retention, and a compact run index. Never delete evidence silently.
- **Expected benefits:** Manageable long-running projects and clearer ownership.
- **Priority:** **Medium**
- **Effort:** M
- **Risks/trade-offs:** Archival can break links unless IDs and locations remain resolvable.

### F17 — Retry budgets and waivers are rigid and under-specified

- **Current behavior:** Review and verification generally permit one repair. A real run required a second repair, and the agent added an undocumented manifest field after explicit user permission.
- **Root cause:** Retry policy is a hard-coded procedural rule without typed extension or escalation events.
- **Impact:** Correct recovery requires schema improvisation, while repeated low-value retries may still consume time.
- **Recommended improvement:** Use a policy-driven retry budget based on risk, failure class, and phase. Represent extensions, human evidence, waived evidence, and abort decisions as distinct typed events.
- **Expected benefits:** Flexible but auditable recovery.
- **Priority:** **High**
- **Effort:** M
- **Risks/trade-offs:** Dynamic budgets can enable runaway loops unless ceilings and cost limits remain explicit.

### F18 — Untrusted content, secrets, and sensitive evidence are insufficiently controlled

- **Current behavior:** Repository files, logs, screenshots, response bodies, and knowledge entries can be copied into durable artifacts and potentially committed. Analysis roles can have web access.
- **Root cause:** The framework lacks a data-classification, redaction, and prompt-injection trust boundary.
- **Impact:** Secret leakage, PII retention, hostile instruction ingestion, source-code disclosure, or unsafe network behavior.
- **Recommended improvement:** Treat all retrieved content as untrusted data; add secret/PII scanning, artifact size limits, redaction, safe excerpts, network-deny defaults for roles that do not need it, and explicit retention/commit policy.
- **Expected benefits:** Safer enterprise use and more defensible artifacts.
- **Priority:** **Critical**
- **Effort:** M–L
- **Risks/trade-offs:** Redaction can remove debugging evidence; scanners produce false positives.

### F19 — Planning graphs are brittle and semantically misleading

- **Current behavior:** Dependencies use lower-numbered assumptions, making cycles “unexpressible”; critical path is essentially longest edge/step count and acts as an implementation gate.
- **Root cause:** The graph is optimized for prompt simplicity rather than stable identity and scheduling semantics.
- **Impact:** Reordering breaks references, meaningful cycles are not diagnosed, and “critical path” implies duration analysis that is not performed.
- **Recommended improvement:** Use stable IDs and real DAG validation. Rename the current construct to `gating chain`, or add optional duration/risk weights before calling it critical path. Use the graph primarily for invalidation, scheduling, and impact analysis.
- **Expected benefits:** Stable plans and more truthful reasoning.
- **Priority:** **Medium**
- **Effort:** M
- **Risks/trade-offs:** More formal planning can become ceremony for small tasks; keep lite mode minimal.

### F20 — Feature TDD is weaker than bugfix RED/GREEN evidence

- **Current behavior:** Bugfix implementation records RED/GREEN explicitly; feature acceptance criteria do not consistently receive equivalent pre/post evidence.
- **Root cause:** Test-first discipline is modeled as a bugfix-specific procedure.
- **Impact:** New behavior can be implemented without demonstrating that its acceptance test would have failed before the change.
- **Recommended improvement:** For testable feature criteria, capture criterion-level failing or absent-behavior evidence and subsequent passing evidence. Permit justified non-TDD categories such as pure refactors or generated code.
- **Expected benefits:** Stronger regression protection and traceability from spec to test.
- **Priority:** **Medium**
- **Effort:** S–M
- **Risks/trade-offs:** Forced TDD can produce artificial tests; policy must distinguish behavior from implementation details.

### F21 — Feature Flow does not measure its own effectiveness

- **Current behavior:** Runs do not systematically record elapsed time, token/context pressure, retries, gate waits, overrides, verification gaps, resume success, or escaped defects.
- **Root cause:** The manifest is task-focused and there is no privacy-conscious telemetry model.
- **Impact:** Maintainers cannot tell whether changes improve productivity or just add ceremony.
- **Recommended improvement:** Emit a local run summary with phase duration, tool calls, context compactions where available, retries, human interventions, evidence quality, and outcome. Aggregate only with opt-in and redaction.
- **Expected benefits:** Evidence-based framework evolution and better tier policies.
- **Priority:** **High**
- **Effort:** M
- **Risks/trade-offs:** Metrics can be gamed and may collect sensitive metadata; define purpose and retention narrowly.

## 4. Missing Capabilities

Feature Flow is missing several capabilities that modern agent harnesses increasingly treat as foundational:

1. **An executable state machine.** A prompt should not be able to create an invalid transition or terminal state.
2. **Assurance convergence.** Review and verification must pass on the same immutable code revision.
3. **Versioned schemas and migrations.** Long-running projects need framework upgrades without abandoning old runs.
4. **Append-only event history.** Current state alone cannot explain exactly how a run reached it.
5. **Idempotent recovery.** Re-running a phase after interruption should not duplicate decisions or corrupt artifacts.
6. **Change-set identity.** Every review, verification result, and artifact should name the code revision it covers.
7. **Native multi-host adapters.** Claude Code and Codex should consume a shared policy and role specification.
8. **Isolated phase contexts.** Workers should return bounded artifacts rather than growing one main conversation.
9. **Verification profiles and sandboxes.** Commands need declared effects and controlled environments.
10. **Trajectory-level evaluation.** Test real runs, failures, resumes, and upgrades—not only prompt text.
11. **Hybrid knowledge retrieval.** Memory needs indexing, provenance, staleness, supersession, and trust.
12. **Operational visibility.** Active/stale/blocked runs and framework effectiveness need measurable status.
13. **Security classification and redaction.** Durable evidence must be safe to store and share.
14. **Environment recipes.** Repositories need declarative ways to establish reproducible verification environments.
15. **Policy profiles.** Risk, gates, retry budgets, network access, and artifact durability should be configurable without editing prompts.

## 5. Workflow Bottlenecks

### 5.1 Repeated startup negotiation

Heuristic analysis of the session corpus found 27 session files containing a Feature Flow mode question and 42 containing explicit discussion that Feature Flow was manual-only or opt-in for the repository. This indicates that activation policy is consuming real interaction bandwidth.

**Resolution:** persist repository activation and preferred tier/autopilot settings; ask only when risk or scope exceeds policy.

### 5.2 Serial work where isolation would be more valuable

Exploration, convention discovery, review, and verification are often read-heavy and independently bounded. Keeping them in the main session increases context load. Several inspected sessions ran for hours, accumulated hundreds of tool calls, and compacted five times.

**Resolution:** isolate these phases and return typed packets:

```text
PhaseResult {
  run_id
  phase
  input_revision
  findings[]
  decisions_required[]
  evidence[]
  artifact_refs[]
  confidence
  limits[]
}
```

### 5.3 Human gates are fragmented

Clarification signoff, assumption acknowledgement, design choice, mode selection, retry extension, and evidence waiver can become multiple back-to-back interruptions.

**Resolution:** preserve distinct semantics but combine compatible decisions into one approval packet. Never combine a waiver with ordinary signoff in a way that obscures the risk.

### 5.4 End-of-run knowledge capture blocks closure

Knowledge capture is useful, but making it part of the done transition can leave implementation finished while state remains incomplete.

**Resolution:** create a durable capture candidate synchronously, then allow indexing/enrichment to run asynchronously. Only block closure if the user or repository policy explicitly requires knowledge publication.

### 5.5 Fixed repair counts do not match failure complexity

One retry can be too many for an obviously environmental failure and too few for a legitimate multi-layer defect.

**Resolution:** use a bounded budget such as:

- deterministic code failure: up to two autonomous repair cycles;
- destructive/environmental failure: stop immediately for approval;
- flaky or unchanged failure: one retry, then classify;
- budget extension: explicit user event with reason and maximum.

## 6. Architecture Improvement Recommendations

### 6.1 Target architecture

```text
┌───────────────────────────────────────────────────────────────┐
│ Host adapters: Claude Code │ Codex │ future IDE/CI adapters  │
└───────────────────────────────┬───────────────────────────────┘
                                │ capability + policy requests
┌───────────────────────────────▼───────────────────────────────┐
│                    Deterministic FF Core                       │
│ state machine │ policy │ CAS/locks │ invalidation │ migration │
└─────────────┬──────────────────┬───────────────────┬──────────┘
              │                  │                   │
      ┌───────▼────────┐ ┌──────▼─────────┐ ┌──────▼──────────┐
      │ Phase workers   │ │ Verification   │ │ Human approvals │
      │ isolated context│ │ sandbox/profiles│ │ typed decisions │
      └───────┬────────┘ └──────┬─────────┘ └──────┬──────────┘
              │                  │                   │
┌─────────────▼──────────────────▼───────────────────▼──────────┐
│ run.json │ events.jsonl │ artifact metadata │ Markdown views │
│ knowledge index │ local telemetry │ content-addressed blobs   │
└───────────────────────────────────────────────────────────────┘
```

### 6.2 Separate four architectural layers

1. **Core state layer**
   - workflow definition;
   - schema validation and migration;
   - transition prerequisites;
   - event log and checkpoints;
   - leases and compare-and-swap revisions;
   - artifact and code-revision hashes.

2. **Policy layer**
   - tier selection;
   - activation;
   - human gates;
   - retry budgets;
   - risk and command classes;
   - network and sandbox permissions;
   - durability and retention.

3. **Agent layer**
   - role goal and bounded inputs;
   - host-native tool permissions;
   - structured result schema;
   - context and cost budget;
   - no direct manifest mutation.

4. **Presentation layer**
   - readable Markdown artifacts;
   - CLI status;
   - approval packets;
   - reports and dashboards.

### 6.3 Make the run event-sourced

Recommended canonical files:

```text
.feature-flow/
  config.json
  index.json
  runs/<run-id>/
    run.json
    events.jsonl
    artifacts/
      <artifact-id>.json
      <artifact-id>.md
    evidence/
    attachments/
```

`run.json` is a derived checkpoint for fast reads. `events.jsonl` is the audit source:

```json
{
  "eventId": "01J...",
  "idempotencyKey": "verify:revision-7:attempt-1",
  "runId": "01J...",
  "type": "verification.passed",
  "actor": {"kind": "agent", "host": "codex", "sessionId": "..."},
  "codeRevision": "sha256:...",
  "inputs": ["artifact:contract-v3"],
  "timestamp": "2026-07-23T10:00:00Z"
}
```

This model supports replay, recovery, auditing, and migrations while keeping a compact current-state view.

### 6.4 Use one workflow definition

Define phases, prerequisites, outputs, and invalidation declaratively. Generate command instructions and host adapters from that definition. Avoid hand-maintaining the same rule in a command, skill, schema, hook, template, and guard.

### 6.5 Treat code revision as a first-class artifact

A revision should include:

- repository identity and worktree;
- baseline commit/tree;
- current commit where applicable;
- staged, unstaged, and included untracked change hashes;
- declared exclusions;
- dependency lockfile/environment fingerprint where relevant.

Every review and verification claim must reference it.

## 7. AI Agent Enhancement Opportunities

### 7.1 Use the main agent as an orchestrator

Current Codex guidance recommends subagents for parallel, read-heavy work and context isolation, while keeping write-heavy tasks carefully coordinated. Claude Code likewise describes subagents as fresh, isolated contexts with role-specific permissions. Feature Flow should adopt this pattern directly rather than merely describing specialist personas. See [Codex subagents](https://learn.chatgpt.com/docs/agent-configuration/subagents) and [Claude Code subagents](https://code.claude.com/docs/en/sub-agents).

Recommended execution model:

- **Main orchestrator:** owns user interaction and transition requests; does not ingest raw logs.
- **Explorer:** read-only repository mapping with bounded output.
- **Planner:** converts approved specification into stable-ID DAG.
- **Implementer:** owns a declared path set or worktree.
- **Reviewer:** read-only, receives canonical diff and contract.
- **Verifier:** executes only an approved verification profile.
- **Critic:** challenges high-risk plans or inconclusive evidence, not every trivial change.

### 7.2 Generate host-native roles

Maintain a common role specification and generate:

- Claude `.claude/agents/*.md`;
- Codex `.codex/agents/*.toml`;
- matching tool/network/sandbox policy;
- shared structured output schemas.

This prevents the current situation where Claude has concrete agent files and Codex receives prose mappings that may be simulated inline.

### 7.3 Use adaptive critique, not universal reflection

Reflection loops are useful when uncertainty or risk is high, but automatic self-critique on every phase adds correlated tokens rather than independent assurance.

Trigger a critic when:

- architecture or data migration risk is high;
- the plan has unresolved assumptions;
- review and verification disagree;
- evidence is correlated or incomplete;
- a repair repeats the same failure;
- security-sensitive surfaces change.

### 7.4 Increase reviewer diversity by role and evidence

Multiple generic reviewers using the same context and model are correlated. Prefer distinct threat models:

- correctness and regressions;
- security and trust boundaries;
- maintainability and convention fit;
- test adequacy and observability.

Only invoke the roles justified by change risk. Findings should cite code and failure paths, not confidence alone.

### 7.5 Add budgets and stop conditions

Every worker request should specify:

- scope;
- allowed tools and paths;
- maximum elapsed/tool budget;
- required output schema;
- code revision;
- stop conditions;
- escalation conditions.

This makes autonomy bounded and reviewable.

## 8. Verification Loop Improvements

### 8.1 Replace phase ordering with assurance convergence

The final gate should be revision-based:

```text
implementation produces R1
  ├─ review(R1) ── pass
  └─ verify(R1) ─ fail ─ repair → R2

R1 attestations are invalidated

R2
  ├─ review(R2) ── pass
  └─ verify(R2) ─ pass

done(R2)
```

Review and verify may run in either order or in parallel if they are read-only and reference the same immutable revision. A repair always begins a new convergence round.

### 8.2 Add a verification ladder

Use the cheapest high-signal checks first:

1. schema/static checks;
2. targeted unit/regression tests;
3. component/integration tests;
4. full relevant suite;
5. UI/API behavioral checks;
6. environment-specific or human evidence.

Failure classification should distinguish code failure, environment failure, flaky behavior, unavailable dependency, permission denial, and destructive-risk stop.

### 8.3 Make contract traceability executable

Each acceptance criterion should have:

- stable ID;
- test/evidence claim;
- code revision;
- command or observation;
- result;
- freshness;
- limitation or waiver event.

Gate B should validate this structure, not search Markdown for section names.

### 8.4 Continuous validation after mutations

Run a small affected check set after each meaningful implementation batch. Do not wait until the end to discover formatting, type, schema, or targeted regression failures. Full verification still occurs at the convergence gate.

### 8.5 Improve autonomous code review

Review should receive:

- exact canonical diff;
- approved specification and plan;
- changed dependency/config summary;
- test changes;
- prior findings and their disposition;
- current code revision.

Block on severity plus evidence and policy—not merely a subjective confidence threshold. A high-severity, low-confidence finding should trigger targeted validation, not disappear.

### 8.6 Build a real evaluation pyramid

Anthropic’s current evaluation guidance recommends examining full trajectories, using code/model/human graders, and running multiple trials because agent outcomes vary. Feature Flow should implement:

- **Fast deterministic tests:** schemas, state transitions, migration, locks, invalidation.
- **Fixture integration tests:** command-to-runtime behavior in disposable repositories.
- **Trajectory tests:** complete feature and bugfix runs, including interruption and resume.
- **Mutation tests:** deliberately remove signoff, alter revisions, race writers, corrupt artifacts, and force repair loops.
- **Model-graded checks:** artifact clarity, plan quality, evidence relevance.
- **Periodic human review:** false-positive/false-negative and DX sampling.

References: [Anthropic on agent evaluations](https://www.anthropic.com/engineering/demystifying-evals-for-ai-agents) and [OpenAI on coding-evaluation validity](https://openai.com/index/separating-signal-from-noise-coding-evaluations/).

## 9. Knowledge & Memory Improvements

### 9.1 Distinguish four memory types

1. **Run memory:** exact current task state and event history.
2. **Project knowledge:** conventions, architecture, commands, and verified constraints.
3. **Decision records:** accepted decisions, supersession, rationale, and scope.
4. **User/team preferences:** activation, approval style, durability, risk tolerance.

These have different lifetimes and trust requirements. They should not share one undifferentiated Markdown pool.

### 9.2 Retrieval pipeline

Recommended pipeline:

```text
query + repository context
  → lexical candidates
  → semantic candidates
  → filter by path/revision/status/trust
  → rerank
  → return small cited excerpts
  → agent confirms applicability
```

Each entry should include:

- stable ID and schema version;
- source repository, paths, and content hashes;
- source revision and capture date;
- owner or producer;
- claim type and confidence;
- active, deprecated, or superseded status;
- sensitivity/trust classification;
- citations to source evidence.

### 9.3 Staleness should be content-aware

Age alone is weak. Mark knowledge stale when:

- referenced path content hash changes;
- dependency version or configuration changes;
- a decision is superseded;
- verification supporting the claim expires;
- the repository branch diverges materially.

### 9.4 Knowledge capture should propose, not silently canonize

Agents should produce capture candidates. High-impact architectural or security claims require review or stronger evidence before becoming trusted project knowledge. Duplicate and contradictory entries should be merged or linked.

### 9.5 Defend against memory poisoning

Retrieved documents are data, not instructions. Preserve source labels, quote only necessary excerpts, ignore embedded commands, and prevent knowledge retrieval from expanding tool permissions. Sensitive content should be redacted before indexing.

## 10. Developer Experience Improvements

### 10.1 Add a small, predictable CLI

Suggested commands:

```text
ff start
ff status [run]
ff approve [decision]
ff next
ff verify [profile]
ff resume [run]
ff doctor [run|--all]
ff list
ff diff
ff abandon [run]
ff archive [run]
```

The CLI should emit both concise human output and machine-readable JSON.

### 10.2 Add repository configuration

Example:

```yaml
schemaVersion: 1
activation: manual
defaultTier: lite
autopilot: proceed
artifactStore: local
gates:
  clarification: risk-based
  evidenceWaiver: always
verificationProfiles:
  safe:
    commands:
      - npm test -- --runInBand
    network: deny
    timeoutSeconds: 900
```

Configuration should be discoverable with `ff config explain`, including which user/project policy won.

### 10.3 Improve approval UX

Present one compact packet:

- what was learned;
- decisions requested;
- unresolved assumptions;
- risk;
- what will happen after approval.

Use stable decision IDs so “approve D2 and D4; reject D3” is unambiguous.

### 10.4 Make status immediately legible

`ff status` should answer:

- What is the current code revision?
- What is blocked and why?
- What user decision is needed?
- Which assurance results are valid for this revision?
- What became stale after the last mutation?
- What is the next safe action?

### 10.5 Clean up documentation drift

Immediate documentation fixes:

- remove the assertion that Codex has no hook mechanism;
- reconcile `eval.sh` “non-blocking” comments with blocking CI;
- mark the untracked v2 enhancement plan with its baseline/status or supersede it;
- generate phase and schema reference tables from canonical definitions.

## 11. Scalability Recommendations

### 11.1 Large repositories

- Build a repository map/index once and invalidate it incrementally.
- Retrieve relevant conventions by path and dependency graph rather than loading global guidance.
- Limit workers to declared path scopes.
- Use sparse worktrees or isolated worktrees for independent implementation units.
- Cache deterministic checks by revision and environment fingerprint.

### 11.2 Long-running projects

- Use globally unique run and artifact IDs.
- Link runs to ticket, branch, commit, worktree, session/thread, and parent run.
- Checkpoint after every event, not only after prose artifact completion.
- Make migrations reversible or preserve the original event log.
- Support pause, blocked, abandoned, superseded, and archived as distinct states.

### 11.3 Multi-session continuity

Resume should load a compact packet derived from durable state:

- approved contract;
- active decisions;
- code revision and dirty-state delta;
- valid/stale assurance results;
- unresolved blockers;
- next allowed transitions.

Do not replay full prior conversations unless specifically needed. Current long-running-agent guidance similarly favors structured artifacts and clear planner/evaluator handoffs over trusting context alone; see [Anthropic on long-running agent harnesses](https://www.anthropic.com/engineering/harness-design-long-running-apps).

### 11.4 Team and CI operation

- Allow a CI verifier to attach evidence to a revision without taking over the run.
- Support signed/identified human and agent actors.
- Resolve concurrent decisions through revision checks, not last-write-wins.
- Publish a portable run summary with the pull request, while keeping secrets and raw logs out.
- Support policy profiles by repository risk class.

## 12. Security and Reliability Considerations

### 12.1 Threat model

Important trust boundaries include:

- user instructions versus repository instructions;
- trusted framework policy versus untrusted source/docs/logs;
- read-only model tools versus effectful executed commands;
- local artifacts versus commit/publish boundaries;
- worker outputs versus core state transitions;
- external web content versus private source context;
- human evidence versus waived evidence.

### 12.2 Required controls

1. **Least privilege:** default analysis and review workers to no network and read-only filesystem.
2. **Command policy:** verification commands require a named profile and side-effect declaration.
3. **Sandboxing:** use disposable worktrees/containers for effectful or unknown commands.
4. **Secret handling:** scan and redact artifacts before durable storage or publication.
5. **Prompt-injection resistance:** label retrieved content as untrusted and never allow it to alter policy.
6. **Integrity:** hash code revisions and artifacts; record producers and inputs.
7. **Availability:** timeouts, cancellation, retry ceilings, and recoverable checkpoints.
8. **Authorization:** only humans can grant scope-expanding waivers; store them as typed events.
9. **Audit:** append-only events and explicit actor identity.
10. **Supply chain:** pin framework/plugin versions and verify migration compatibility.

Current Codex and Claude Code both support deterministic hooks, which are better suited to non-negotiable guardrails than natural-language skills. See [Codex hooks](https://learn.chatgpt.com/docs/hooks), [Claude Code hooks](https://code.claude.com/docs/en/hooks), and [Claude Code feature guidance](https://code.claude.com/docs/en/features-overview).

### 12.3 Reliability principles

- Never infer success from artifact presence alone.
- Never reuse an assurance result after its input revision changes.
- Never silently coerce invalid old state into current state.
- Never call an unavailable check “passed.”
- Never mix human observation with evidence waiver.
- Never let a worker mutate canonical state directly.
- Never allow a failed hook to leave ambiguous partial writes.

## 13. Prioritized Roadmap

### Short term: 0–6 weeks

| Order | Initiative | Findings | Outcome |
|---|---|---|---|
| P0 | Revision-bound assurance convergence | F01, F06 | Final code is both reviewed and verified |
| P0 | JSON Schema, `schemaVersion`, and `ff doctor` | F03, F05 | Existing state becomes diagnosable and validatable |
| P0 | Codex hook adapter and capability detection | F12 | Gate parity on current Codex |
| P0 | Verification command safety baseline | F08, F18 | No arbitrary “read-only” command execution |
| P0 | Typed retry extension and waiver events | F17 | Recovery no longer invents schema |
| P1 | Activation/mode configuration | F13 | Removes repeated startup ceremony |
| P1 | Fix documentation/eval drift | F10, F12 | Public behavior matches implementation |
| P1 | Record baseline/worktree/session metadata | F06, F15 | Reproducible change scope and resume |

**Exit criteria:** No run can reach done unless schema-valid and both assurance gates pass on the same revision. All supported hosts enforce the same machine-readable gate policy.

### Medium term: 6–16 weeks

| Order | Initiative | Findings | Outcome |
|---|---|---|---|
| P1 | Deterministic `ffctl` transition core | F02–F05 | Prompts stop owning state |
| P1 | Append-only event log, CAS, and leases | F04, F15, F17 | Safe concurrency and exact recovery |
| P1 | Native isolated phase workers | F11, F12 | Lower context pressure and portable orchestration |
| P1 | Behavioral and trajectory evaluation lab | F10 | Tests measure real workflow outcomes |
| P1 | Verification profiles and disposable environments | F08 | Safer, repeatable execution |
| P2 | Run lifecycle CLI and index | F16 | Scalable status, archive, and stale-run handling |
| P2 | Local effectiveness metrics | F21 | Evidence-based process tuning |
| P2 | Stable planning IDs and graph validation | F19 | Durable plans and dependency semantics |

**Exit criteria:** State transitions are deterministic, recoverable, and host-independent; representative end-to-end fixture runs pass repeatedly, including interruption, repair, and resume.

### Long term: 4–9 months

| Order | Initiative | Findings | Outcome |
|---|---|---|---|
| P2 | Hybrid project knowledge and decision index | F14 | High-recall, provenance-aware memory |
| P2 | Content-addressed artifact/evidence store | F09, F15 | Strong provenance and deduplication |
| P2 | Team/CI coordination and signed actors | F04, F16 | Multi-user and automation-safe runs |
| P2 | Repository environment recipes | F08 | Reproducible high-fidelity verification |
| P3 | Risk-adaptive policies and reviewer selection | F09, F11, F21 | Proportional rigor based on measured outcomes |
| P3 | Privacy-preserving aggregate analytics | F21 | Cross-project learning without raw-source collection |

**Exit criteria:** Feature Flow can support multi-month, multi-contributor initiatives with reliable retrieval, reproducible evidence, measurable outcomes, and no dependence on one conversation history.

## 14. Quick Wins

These changes have high impact relative to effort:

1. **Add `schemaVersion` and a read-only manifest linter.** Do not wait for the full runtime.
2. **Store `baselineCommit`, `worktree`, `branch`, and `sessionId`.**
3. **Add `codeRevision` to review and verification artifacts.**
4. **Block done when review and verification revisions differ.**
5. **Invalidate review and verification after any repair.**
6. **Add current Codex hook support.**
7. **Introduce `activation: auto | manual | off` and persist mode preference.**
8. **Fix the stale “non-blocking eval” and “Codex has no hooks” documentation.**
9. **Add `ff doctor --all` checks for stale locks, invalid statuses, missing pointers, and terminal inconsistencies.**
10. **Replace default unstaged diff with an explicit baseline-to-current change-set summary.**
11. **Differentiate `human_observation`, `evidence_gap`, and `waiver` in the manifest.**
12. **Scan durable artifacts for secrets and cap copied log/response size.**
13. **Make knowledge capture asynchronous by default after recording a durable candidate.**
14. **Add one end-to-end fixture that repairs during verification and asserts review invalidation.**
15. **Add the inverse bugfix fixture: review repair must invalidate verification.**

## 15. Vision for Feature Flow vNext

Feature Flow vNext should be an **evidence-bearing engineering control plane for coding agents**, not a larger prompt library.

Its defining properties should be:

- **Deterministic where correctness demands it.** State, gates, locks, schemas, revisions, and invalidation are code.
- **Agentic where judgment helps.** Exploration, design, implementation, critique, and evidence interpretation remain model-driven.
- **Revision-bound.** Every claim says exactly which code and environment it covers.
- **Portable.** Claude Code, Codex, CI, and future hosts share one workflow and policy definition.
- **Context-efficient.** Isolated workers exchange typed, bounded artifacts.
- **Recoverable.** Every meaningful action is idempotent, checkpointed, and replayable.
- **Risk-adaptive.** Small work stays light; high-risk work adds critique, evidence, and human gates.
- **Knowledge-aware.** Project memory is retrieved with provenance, freshness, trust, and supersession.
- **Secure by default.** Commands, networks, secrets, and untrusted content have explicit boundaries.
- **Measurable.** The framework can demonstrate whether it improves cycle time, defect rate, and review quality.

The best vNext experience would feel simpler than the current framework even though its internals are stronger:

```text
User states goal
  → Feature Flow resolves policy and existing knowledge
  → agent produces a concise contract/decision packet
  → isolated workers plan and implement against a tracked revision
  → review and verification converge on the same revision
  → user sees evidence, limits, and a clean delivery summary
  → run closes with replayable state and reusable, provenance-aware knowledge
```

That evolution preserves Feature Flow’s strongest idea—disciplined, evidence-driven development—while replacing its weakest assumption: that sufficiently careful prompt prose can serve as a reliable workflow engine.

## Appendix A — Evidence from Real Usage

The review inspected 170 JSONL session files under the supplied Codex directory and 30 Feature Flow run directories referenced by those sessions. Transcript counts are heuristic pattern matches used to identify recurring behavior, not controlled experimental measurements.

### Framework evidence map

| Observation | Primary framework evidence |
|---|---|
| Feature completion is review → verify; bugfix completion is verify → review | `commands/ff-review.md`, `commands/ff-verify.md` |
| A repair is local to the active phase and capped at one cycle | `commands/ff-review.md`, `commands/ff-verify.md`, `docs/manifest-schema.md` |
| Review defaults to the unstaged diff | `agents/ff-code-reviewer.md` |
| Locking is advisory with a 15-minute stale threshold | `docs/manifest-schema.md` |
| Claude has machine gates while Codex is documented as prose-only | `docs/manifest-schema.md`, `hooks/enforce-gate`, `hooks/hooks.json` |
| Evaluation checks mechanical preconditions and leaves semantic catches manual | `scripts/eval.sh` |
| CI now treats the evaluation harness as blocking | `.github/workflows/ci.yml` |
| Planning dependencies must point to lower-numbered tasks and critical path is derived by longest chain | `commands/ff-plan.md`, `commands/ff-implement.md`, `docs/manifest-schema.md` |
| Confidence depends on recountable distinct evidence kinds | `agents/ff-test-runner.md`, `commands/ff-verify.md` |

### Observed state quality

- 11 of 30 manifests violated one or more current schema or terminal invariants.
- Violations included invalid phase/status tokens, missing tier or slug, terminal phase completion without `currentPhase: done`, closed-but-not-done states, and a retained lock.
- Multiple verification artifacts lacked the current contract mapping or status structure.
- Some phase artifacts used older formats without a recorded schema version, making correct migration ambiguous.

### Observed runtime pressure

- Several implementation sessions reached 332–426 tool calls.
- Several compacted five times.
- Long runs lasted roughly two to more than three hours.
- Specialist activities were sometimes performed inline under a role label rather than in a verifiably isolated context.

### Observed failure recovery

One UI verification run:

1. encountered an environment/authentication limitation;
2. later found an actual behavioral failure through screenshot evidence;
3. repaired the code;
4. encountered another delayed failure;
5. exhausted the fixed repair budget;
6. requested explicit user permission for another repair;
7. added an undocumented manifest field to represent that permission;
8. eventually relied partly on manual confirmation.

This demonstrates useful persistence and human control, but also exposes the absence of typed retry extensions, evidence provenance, and revision-bound assurance.

### Interpretation

The evidence does not mean Feature Flow is ineffective. It means the current repository tests are measuring the presence of intended policy more strongly than adherence to that policy in real runs. That is the core gap the vNext architecture should close.

## Appendix B — Industry Benchmark

| Practice | Current industry direction | Feature Flow today | Recommended integration |
|---|---|---|---|
| Skills | On-demand procedural knowledge; interpreted by agents | Strong packaging and clear procedures | Keep skills thin; route mutations through core |
| Hooks | Deterministic lifecycle guardrails | Claude-only gate; outdated Codex assumption | Generate native hooks for both hosts |
| Subagents | Fresh isolated contexts and role permissions | Roles exist, isolation inconsistent | Native workers with typed packets |
| Planning-first | Goal, constraints, done criteria, staged plan | Strong full feature track | Stable IDs, executable dependencies, risk policy |
| Spec-driven development | Acceptance contract drives implementation and tests | Good clarification artifacts | Typed contract and criterion-level evidence |
| Context engineering | Small relevant context, delegation, compaction-aware design | Large main-thread procedures | Retrieval plus per-phase context budgets |
| Memory/RAG | Indexed, cited, provenance-aware retrieval | Tag/text Markdown knowledge | Hybrid retrieval, freshness, trust, supersession |
| Autonomous review | Exact diff, specialized review, evidence-backed findings | Review roles and confidence threshold | Canonical diff, risk-selected roles, targeted validation |
| Self-verification | Iterate against tests/evaluators | Bounded local repair | Revision-bound convergence loop |
| Continuous validation | Fast checks throughout implementation | Mostly phase-end | Affected checks after each mutation batch |
| Checkpoint/recovery | Externalized state, durable execution, replay | Manifest and artifacts | Event log, idempotency, CAS, migrations |
| Agent evaluation | Full trajectories, repeated trials, mixed graders | Structural fixtures and grep checks | Behavioral trials and trajectory grading |

Useful current references:

- [Claude Code: features overview](https://code.claude.com/docs/en/features-overview)
- [Claude Code: hooks](https://code.claude.com/docs/en/hooks)
- [Claude Code: subagents](https://code.claude.com/docs/en/sub-agents)
- [Claude Code: how context and compaction work](https://code.claude.com/docs/en/how-claude-code-works)
- [Codex: subagents](https://learn.chatgpt.com/docs/agent-configuration/subagents)
- [Codex: hooks](https://learn.chatgpt.com/docs/hooks)
- [Codex best practices](https://learn.chatgpt.com/guides/best-practices)
- [OpenAI: harness engineering](https://openai.com/index/harness-engineering/)
- [Anthropic: long-running agent harnesses](https://www.anthropic.com/engineering/harness-design-long-running-apps)
- [Anthropic: evaluating AI agents](https://www.anthropic.com/engineering/demystifying-evals-for-ai-agents)
