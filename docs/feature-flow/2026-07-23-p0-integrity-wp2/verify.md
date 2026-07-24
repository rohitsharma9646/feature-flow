# Verify: P0 Integrity WP2 — read-only doctor and explicit legacy migration

**Track:** feature
**Tier:** full
**Date:** 2026-07-24
**Verified by:** `ff-test-runner` (executed)

## Commands run

| Command | Kind | Status | Evidence |
|---|---|---:|---|
| `go test ./...` in `golang:1.26.5` | executed-test | 0 | `evidence/executed-test-1-go-test.txt` |
| `go test -race ./...` | executed-test | 0 | `evidence/executed-test-2-go-race.txt` |
| `go vet ./...` | build/static-analysis | 0 | `evidence/build-static-analysis-1-go-vet.txt` |
| six `GOOS/GOARCH go build -buildvcs=false` runs | build/static-analysis | 0 each | `evidence/build-static-analysis-cross-*.txt` |
| all `scripts/checks/*-guard.sh` | executed-test | 1 initially | `evidence/executed-test-3c-shell-guards-complete-env.txt` |
| `scripts/checks/dist-parity-guard.sh` after package refresh | executed-test | 0 | `evidence/executed-test-7-dist-parity-repair.txt` |
| `scripts/eval.sh` | executed-test | 0 | `evidence/executed-test-4-eval.txt` |
| Linux package build/conformance | build + executed-test | 0 | `evidence/build-static-analysis-8-linux-package-build.txt`, `evidence/executed-test-5-linux-package-conformance.txt` |
| `scripts/check-integrity-wp2-conformance.sh` | executed-test | 0 | `evidence/executed-test-6-wp2-conformance.txt` |
| disposable doctor → preview → apply → doctor → second apply | cli-output + before/after | expected `1,0,0,0,0` | `evidence/cli-output-1-doctor-preview-apply-idempotence.txt` |

## Evidence coverage matrix

| Detected surface | Expected kind | Ran? | Result | Notes |
|---|---|---|---|---|
| Go packages and shell suites | executed-test | yes | pass after one repair | Tests, race, guards, eval, conformance |
| Six build targets | build/static-analysis | yes | pass | Cross-build only for five non-local targets |
| Native package/CLI execution | cli-output | partial | gap | Linux x86_64 passed; five native runners unavailable locally |
| CLI filesystem lifecycle | before/after | yes | pass | Exact source snapshot and idempotent second apply captured |
| Browser/UI | e2e/browser | — | N/A | No browser/UI surface detected |
| HTTP service | http/api | — | N/A | No HTTP/API surface detected |
| Database | db | — | N/A | No database surface detected |
| Runtime log files | logs | — | N/A | CLI stdout/stderr captured in command records; no independent log surface |

## Contract mapping

### AC1: Complete finite legacy-family inventory and registered mapping/rationale
- **Method:** executed-test
- **Evidence:** `go test ./...` and WP2 conformance exited 0; WP2 guard and regenerated inventory checks passed.
- **Confidence:** Verified (single-source)

### AC2: Deterministic doctor modes, conclusions, codes, ordering, and exit classes
- **Method:** executed-test; cli-output
- **Evidence:** Go tests exited 0; disposable doctor produced expected blocking exit 1 before migration and clean exit 0 after migration.
- **Confidence:** Verified (multi-source)

### AC3: Doctor is immutable across its complete corpus
- **Method:** executed-test
- **Evidence:** WP2 conformance exited 0 and verified no migration directory or working-tree change during doctor/preview.
- **Confidence:** Verified (single-source)

### AC4: Deterministic no-write migration preview
- **Method:** executed-test; cli-output
- **Evidence:** WP2 conformance exited 0; disposable preview exited 0 with `ready` before any migration entry existed.
- **Confidence:** Verified (multi-source)

### AC5: Apply is bound to reviewed plan and observed source/pointer facts
- **Method:** executed-test; cli-output
- **Evidence:** migration/storage tests exited 0; real apply accepted the captured digest and completed.
- **Confidence:** Verified (multi-source)

### AC6: Unknown, ambiguous, or unrepresentable legacy behavior is refused
- **Method:** executed-test
- **Evidence:** migration registry/refusal tests and WP2 corpus guard exited 0.
- **Confidence:** Verified (single-source)

### AC7: Pointer resolution is confined to trusted roots
- **Method:** executed-test
- **Evidence:** path-policy, observation, storage symlink, and deterministic directory-swap tests exited 0.
- **Confidence:** Verified (single-source)

### AC8: Accepted proposal validates as honest canonical v1 bootstrap state
- **Method:** executed-test; cli-output
- **Evidence:** schema/classifier/migration tests exited 0; post-apply doctor classified the real result `CURRENT_STRUCTURAL_VALID`.
- **Confidence:** Verified (multi-source)

### AC9: Apply snapshots exact bytes and atomically publishes validated canonical state
- **Method:** executed-test; cli-output; before/after
- **Evidence:** storage tests exited 0; real snapshot SHA-256 matched the source digest and the canonical result was clean.
- **Confidence:** Verified (multi-source)

### AC10: Failure boundaries preserve readable original state and report cleanup
- **Method:** executed-test
- **Evidence:** storage failure-injection suite exited 0.
- **Confidence:** Verified (single-source)

### AC11: Second apply is a zero-write already-current operation
- **Method:** executed-test; cli-output; before/after
- **Evidence:** idempotence tests exited 0; real second apply exited 0 with `already-current` and unchanged hashes/inventory.
- **Confidence:** Verified (multi-source)

### AC12: Terminal migration requires confirmation and reopens without fabricated assurance
- **Method:** executed-test
- **Evidence:** terminal confirmation and assurance-reset tests exited 0.
- **Confidence:** Verified (single-source)

### AC13: Diagnosis-only classes never migrate; valid v1 is already-current
- **Method:** executed-test; cli-output
- **Evidence:** classifier/migration refusal tests exited 0; real second apply returned `already-current`.
- **Confidence:** Verified (multi-source)

### AC14: Human/JSON use stable typed diagnostics and exit distinctions
- **Method:** executed-test; cli-output
- **Evidence:** renderer tests and Linux package conformance exited 0; real JSON lifecycle produced expected statuses/exits.
- **Confidence:** Verified (multi-source)

### AC15: Complete native Claude/Codex packages pass on all six targets without activation
- **Method:** build/static-analysis; executed-test; cli-output
- **Evidence:** all six cross-builds exited 0; Linux x86_64 package assembly/conformance and boundary guard passed.
- **Confidence:** Partially verified
- **Gap:** Linux arm64, both macOS targets, and both Windows targets lack native execution evidence. Cross-builds cannot satisfy this native requirement.

### AC16: Versioned corpora cover all named cases, including Unix and Windows replacement behavior
- **Method:** executed-test; build/static-analysis
- **Evidence:** WP2 guard/conformance and Go tests exited 0; Windows-tagged tests cross-compile.
- **Confidence:** Partially verified
- **Gap:** Windows replacement tests were not executed natively.

### AC17: Existing vectors, commands/hooks, guards, evals, and compatibility tests remain green
- **Method:** executed-test; build/static-analysis
- **Evidence:** Go tests/race/vet/evals passed. The full guard run found stale distribution inventory; package refresh plus scoped parity re-run passed with 45 files synchronized.
- **Confidence:** Verified (multi-source)

## Failure-scenario mapping

### FS1: Pointer target changes after reviewed planning
- **Method:** executed-test
- **Evidence:** pointer-drift/path-policy tests exited 0.
- **Confidence:** Verified (single-source)

### FS2: Snapshot succeeds, replace/cleanup fails
- **Method:** executed-test
- **Evidence:** storage failpoint suite exited 0.
- **Confidence:** Verified (single-source)

### FS3: Windows/filesystem replacement capability is weaker than assumed
- **Method:** build/static-analysis
- **Evidence:** Windows implementation and native tests cross-compile for both architectures.
- **Confidence:** Partially verified
- **Gap:** No native Windows filesystem execution was available.

### FS4: Same shallow shape carries behaviorally distinct legacy semantics
- **Method:** executed-test
- **Evidence:** finite registry ambiguity/refusal tests and inventory guard exited 0.
- **Confidence:** Verified (single-source)

### FS5: Shared primitives regress WP1 bytes or ordering
- **Method:** executed-test
- **Evidence:** Go classifier vectors and Linux package source/Claude/Codex conformance exited 0.
- **Confidence:** Verified (single-source)

### FS6: Second apply changes clock, evidence, or timestamps
- **Method:** executed-test; cli-output; before/after
- **Evidence:** storage idempotence test and disposable second apply passed with unchanged hashes/inventory.
- **Confidence:** Verified (multi-source)

## Success metrics

### SM1: 100% legacy-family mapping/rationale coverage
- **Method:** executed-test
- **Evidence:** inventory guard exited 0 for all eleven unique sources and five profiles.
- **Confidence:** Verified (single-source)

### SM2: Zero doctor mutations across doctor cases
- **Method:** executed-test
- **Evidence:** WP2 conformance immutability check exited 0.
- **Confidence:** Verified (single-source)

### SM3: Zero original-byte loss/partial canonical publication across injected failures
- **Method:** executed-test
- **Evidence:** storage failure suite exited 0.
- **Confidence:** Verified (single-source)

### SM4: Zero second-apply filesystem changes
- **Method:** executed-test; before/after
- **Evidence:** idempotence test and real second apply both passed.
- **Confidence:** Verified (multi-source)

### SM5: 100% native package execution across all six targets
- **Method:** executed-test; build/static-analysis
- **Evidence:** Linux x86_64 native package execution passed; all six targets cross-built.
- **Confidence:** Partially verified
- **Gap:** Five target-native executions require the configured CI runners.

## Evidence artifacts index

| Files | Kind | Backs |
|---|---|---|
| `evidence/executed-test-1-go-test.txt`, `evidence/executed-test-2-go-race.txt` | executed-test | AC1–AC14, AC16–AC17, FS1–FS6, SM1–SM4 |
| `evidence/build-static-analysis-1-go-vet.txt` | build/static-analysis | AC17 |
| `evidence/build-static-analysis-cross-linux-x86_64.txt`, `evidence/build-static-analysis-cross-linux-arm64.txt`, `evidence/build-static-analysis-cross-macos-x86_64.txt`, `evidence/build-static-analysis-cross-macos-arm64.txt`, `evidence/build-static-analysis-cross-windows-x86_64.txt`, `evidence/build-static-analysis-cross-windows-arm64.txt` | build/static-analysis | AC15–AC17, FS3, SM5 |
| `evidence/executed-test-3a-shell-guards-host.txt`, `evidence/executed-test-3b-shell-guards-docker.txt` | executed-test environment attempts | Coverage limitations; superseded by complete environment |
| `evidence/executed-test-3c-shell-guards-complete-env.txt`, `evidence/executed-test-7-dist-parity-repair.txt` | executed-test | AC1, AC15–AC17, SM1, Repair |
| `evidence/executed-test-4-eval.txt` | executed-test | AC17 |
| `evidence/build-static-analysis-8-linux-package-build.txt`, `evidence/executed-test-5-linux-package-conformance.txt` | build/static-analysis; executed-test | AC14–AC15, AC17, FS5, SM5 |
| `evidence/executed-test-6-wp2-conformance.txt` | executed-test | AC1–AC16, SM1–SM4 |
| `evidence/cli-output-1-doctor-preview-apply-idempotence.txt`, `evidence/cli-execution-wrapper.txt`, `evidence/cli-run.sh` | cli-output | AC2, AC4–AC5, AC8–AC9, AC11, AC13–AC14, FS6 |
| `evidence/cli-1-doctor-before.json`, `evidence/cli-2-preview.json`, `evidence/cli-3-apply.json`, `evidence/cli-4-doctor-after.json`, `evidence/cli-5-apply-again.json` | cli-output | AC2, AC4–AC5, AC8–AC9, AC11, AC13–AC14 |
| `evidence/before-1-legacy-manifest.json`, `evidence/after-1-canonical-manifest.json`, `evidence/after-2-source-snapshot.json` | before/after | AC9, AC11, FS6, SM4 |
| `evidence/detection-1-surfaces.txt`, `evidence/detection-2-docker.txt`, `evidence/coverage-matrix.txt` | detection | Evidence coverage matrix and native gaps |

## Regression risk

**Level:** High

WP2 touches classifier-adjacent diagnostics, manifest observation, filesystem publication,
packaging, and six target contracts. The plan anticipated legacy-family ambiguity, shared-byte
regression, pointer drift, weak atomicity, and stale package evidence. The finite registry,
unchanged vectors, handle-anchored boundaries, and refreshed distribution directly exercised those
risks. Native non-Linux execution and post-commit durability remain outstanding.

## Limitations & remaining risks

- Five target-native executions require the configured GitHub Actions runners.
- Cross-build success proves compilation only.
- Reviewer-retained Important items include canonical-manifest CAS, post-publication run identity,
  Windows child-temp substitution resistance, and explicit durability/cleanup outcomes.

## Verdict

**Overall confidence:** Partially verified

**Verdict:** Gap report (blocking)

## Repair

**Triggering item:** AC17 — distribution parity guard failed.
**Captured failure:** `scripts/checks/dist-parity-guard.sh` — exit 1 —
`integrity/testdata/legacy/inventory-v1.json differs from dist/codex/feature-flow/...`.
**Diagnosis:** The generated source inventory was refreshed without rebuilding the committed Codex
distribution mirror.
**Fix applied:** Ran `scripts/package-codex-plugin.sh` to refresh the mirror.
**Re-touched items:** AC1, AC15, AC17, SM1.
**Re-verify outcome:** AC1, AC15, AC17, and SM1 — parity guard exit 0, 45 packaged files in sync.
AC15 remains Partially verified for the independent native-target gap, not for the repaired parity
failure.
