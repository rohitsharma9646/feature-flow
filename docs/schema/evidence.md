# Evidence — feature-flow manifest contract
> Part of the manifest contract. Core rules and the topic index: `docs/manifest-schema.md`.

## Evidence

The single canonical contract for **evidence-based verification**: what counts as evidence,
how confidence is derived, and when a run may not reach `done`. `commands/ff-verify.md`,
`agents/ff-test-runner.md`, and `templates/verify.md` reference this section by name and never
restate it — same house style as **Durable artifact resolution** above. Unlike the Knowledge
base there is **no activation toggle**: evidence collection runs whenever `ff-verify` runs. The
**floor** — executed test/build/lint commands mapped per contract item with real exit codes —
is mandatory and tier-invariant; **breadth** (the widened kinds below) is detection-driven,
never configured.

### Evidence-kind taxonomy

| Kind | Detection surface(s) | Capture |
|---|---|---|
| `executed-test` | `package.json` test script, Makefile test target, pyproject/tox, `composer.json` test script, `phpunit.xml(.dist)`, MFTF acceptance suite | run it; exit code authoritative |
| `build/static-analysis` | build/lint/analyse scripts (tsc, eslint, phpcs, phpstan, `composer.json` lint), Makefile targets | run it; exit code authoritative |
| `e2e/browser` | `playwright.config.*`, MFTF | Playwright CLI under Bash only (`npx playwright test` / `screenshot`); no MCP browser tools |
| `http/api` | a running dev server / documented endpoint | `curl` with the real HTTP status captured (e.g. `-w '%{http_code}'`) |
| `db` | the project's **own** CLI (`bin/magento`, `artisan`, `manage.py`, a documented db script) — never raw driver credentials, never provisioning | command output + exit code |
| `cli-output` | project CLI commands (e.g. `bin/magento setup:di:compile`) | stdout/stderr excerpt + exit code |
| `logs` | project log files (`var/log/*.log`, `storage/logs/*.log`, …) | excerpt proving an expected line present / forbidden line absent |
| `before/after` | any kind above, captured pre- and post-change | paired records, saved with `-before` / `-after` suffixes |

### Evidence record shape

Every piece of evidence is one record:
`{kind, command, actual exit/HTTP status, excerpt, artifact paths}`
— every field literal, never narrated. `artifact paths` are relative to
`<run dir>/evidence/`; an empty list is valid when the kind produces no file (e.g.
`cli-output` with only a stdout excerpt). A record without a captured status can never back
a `pass` — it is `manual-unverified` at best.

### Evidence directory

All captured files (screenshots, traces, logs, response bodies) live under
`<run dir>/evidence/`, named `<kind>-<n>-<short-desc>.<ext>` (e.g. `e2e-1-checkout.png`,
`http-1-login.json`). It is the **only** path `ff-test-runner` may write. It is **cleared at
the start of each verify run** so stale artifacts never mix with fresh evidence. On durable
promotion it is copied alongside `verify.md` — see **Evidence companion copy** in the
Durable-artifact bullet above. Every file must be referenced from `verify.md` by relative
path — no orphaned or unreferenced evidence claims.

### Confidence ladder

Four levels, applied **per contract item** (acceptance criterion, bugfix item,
a design-time failure scenario — full tier, §Design trade-offs & devil's advocate —
a full-tier success metric, or the spec's end-to-end check — both §Discovery fields), derived
**mechanically** — anyone can recount them from the report; no numeric scores anywhere
(the v0.5.0 rejection of numeric confidence as unfalsifiable LLM output is upheld):

1. `Verified (multi-source)` — ≥2 **independent kinds** passed for this item.
2. `Verified (single-source)` — exactly 1 kind passed.
3. `Partially verified` — some evidence exists, but an **expected** (detected) kind failed
   or is missing for this item.
4. `Unverified` — no captured evidence for this item at all.

**Independence:** two records are independent iff their `kind` differs. Duplicates of one
kind collapse to a single source (two `http/api` calls are still one source). **Overall run
confidence = the minimum across all contract items** (order: `Unverified` < `Partially
verified` < `Verified (single-source)` < `Verified (multi-source)`).

### Detection and N/A rule

- Detected surface + ran + passed → cite it.
- Detected surface + not run / failed / tool unavailable (e.g. `playwright.config.ts` exists
  but `npx playwright` is missing) → an explicit **gap** (attempt + reason). **N/A is never
  valid for a detected surface.**
- Undetected surface → `N/A` **with a reason** in the coverage matrix — never silently absent.
- Codex degrade: none — all kinds run via Bash CLI on both platforms; tool availability is a
  property of the *target project*, not the coding platform. (Gate B's content check remains
  Claude-Code-only per §Enforcement; Codex keeps prose gates.)

### Evidence waiver

Exact line, verbatim, in `verify.md`: `Evidence gap accepted by user (<date>): <reason>`.
It may be recorded **only from the user's own in-conversation words** — never authored,
inferred, or dated by the assistant, and never on autopilot's behalf (see the **Evidence gap
stop** row in §Autopilot). A waiver **does not upgrade confidence** — it only unblocks the
`done` transition while the report keeps stating the true confidence levels.

### Tier scaling

The floor (executed test/build/lint mapped per contract item, real exit codes) is
**tier-invariant** — a lite run never skips it, mirroring the bugfix track's never-skipped
RED→GREEN. The **Evidence coverage matrix** and detected-breadth expectations
(e2e/http/db/cli/logs/before-after) apply on **full**-tier runs; **lite** runs render the
floor-only report (single template; the matrix section carries the lite skip note).

### Adding an evidence kind

Two edits, in lockstep: a row in the taxonomy table above (kind, detection surface, capture)
and a matching capture bullet in `agents/ff-test-runner.md`. The confidence ladder, waiver
rule, and `templates/verify.md` are kind-agnostic — they iterate the record list — so nothing
else changes.

### v1 non-goals

Stated, not silent: no MCP/interactive browser automation (Playwright CLI via Bash only);
no numeric confidence or readiness scores (v0.5.0 upheld); no separate client report
artifact — `verify.md` **is** the report (v0.5.0 upheld); no new phase, agent, or config
keys; no environment provisioning (no docker orchestration or test-DB seeding — an app that
cannot run is a recorded gap); no CI-pipeline integration; no perf-benchmark framework (a
project's existing perf command is just `cli-output`); no retroactive re-verification of
past runs.

