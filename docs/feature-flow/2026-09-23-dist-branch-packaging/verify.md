# Verify: Ship only runtime files to Claude Code users (generated `dist` branch)

**Track:** feature
**Tier:** lite
**Date:** 2026-09-23
**Verified by:** the orchestrating session. The plugin's `ff-test-runner` agent isn't installed in
this session, so commands were executed directly with their real exit codes captured.

## Commands run

| Command | Kind | Status | Evidence |
|---------|------|--------|----------|
| `for g in scripts/checks/*.sh; do bash $g; done` | executed-test | pass | 21/21 exit **0** (incl. new `claude-dist-guard.sh`; Go on PATH for conformance) → `evidence/guards.log` |
| `bash scripts/eval.sh` | executed-test | pass | exit **0** → `evidence/eval.log` |
| `claude-dist-guard.sh` + 6 mutated packages | executed-test | pass | real package exit **0**; each mutation exit **1** → `evidence/ac8-guard-and-mutations.log` |
| `package-claude-plugin.sh` dry-run + 7 refused `--output` values + rebuild | executed-test | pass | → `evidence/ac5-packager-safety.log` |
| `claude plugin marketplace add <pkg>` + `claude plugin install` (isolated `CLAUDE_CONFIG_DIR`) | cli-output | pass | both succeed; cache holds exactly the allowlist, 46 files, 0 `.go` → `evidence/ac4-install.log` |
| `publish-claude-dist.sh --remote <local bare>` ×2 | executed-test | pass | creates orphan `dist`, second run "unchanged", 1 commit, 46 files → `evidence/ac7-publish-local.log` |
| `ci.yml` parsed (YAML) | build/static-analysis | pass | job gating/permissions → `evidence/ac7-workflow.log` |
| headless `/feature-flow:ff-status` loaded from the **package** (`--plugin-dir <pkg>`) | cli-output | pass | `is_error:false`, correct run status, $0.13 → `evidence/smoke-ff-status-from-package.json` |

## Evidence coverage matrix

| Detected surface | Expected kind | Ran? | Result | Notes |
|------------------|---------------|------|--------|-------|
| guard suite / eval harness | executed-test | yes | pass | |
| packager + publisher scripts | executed-test | yes | pass | local bare remote; no real push |
| plugin install (Claude CLI) | cli-output | yes | pass | isolated config |
| CI workflow | build/static-analysis | yes | pass | structure only; a live CI run is possible only after merge |
| e2e / http / db / logs | — | — | N/A | no such surface |

## Contract mapping

Lite tier: contract items are the spec's acceptance criteria. Confidence is per §Evidence, Confidence ladder.

### AC1: `scripts/package-claude-plugin.sh --output <dir>` produces a tree whose top-level entries are exactly `.claude-plugin`, `agents`, `commands`, `config`, `docs`, `hooks`, `skills`, `templates`, `README.md`, `LICENSE`; `docs/` contains exactly `manifest-schema.md` and `grilling-playbook.md`; `.claude-plugin/` contains exactly `plugin.json` and `marketplace.json`.
- **Method:** executed-test (guard) + cli-output (installed cache listing)
- **Evidence:** `claude-dist-guard.sh` exit 0, with its three exact-listing checks; mutations `extra-top`, `extra-doc` and `extra-plugin-file` each exit 1. `ac4-install.log` cache entries = exactly the 10 names.
- **Confidence:** Verified (multi-source)

### AC2: The produced tree contains no `*.go` file and none of `go.mod`, `go.sum`, `cmd/`, `integrity/`, `schemas/`, `scripts/`, `evals/`, `.github/`, `.codex-plugin/`, `release/`, `CHANGELOG.md`, `docs/feature-flow/`.
- **Method:** executed-test (guard + mutation) + cli-output
- **Evidence:** the guard's dev-only check passes; `stray-go` and `extra-top` (`evals/`) mutations exit 1; the installed cache and published `dist` tree both have 0 `.go` files and 46 files total.
- **Confidence:** Verified (multi-source)

### AC3: Every `${CLAUDE_PLUGIN_ROOT}/<path>` referenced from a shipped file resolves to an existing path inside the produced tree.
- **Method:** executed-test (guard + mutations) + cli-output (live smoke)
- **Evidence:** the guard's reference check passes. It covers braced and bare forms (the bare form was added by the review fix) and skips `ff-<next-phase>.md` placeholders. The `dangling-braced` and `dangling-bare` mutations exit 1. A live `ff-status` ran from the package.
- **Confidence:** Verified (multi-source)

### AC4: The produced tree's `.claude-plugin/marketplace.json` lists `feature-flow` with `"source": "./"` and a `version` equal to `plugin.json`'s; `claude plugin marketplace add <produced dir>` + `claude plugin install feature-flow@feature-flow` (isolated `CLAUDE_CONFIG_DIR`) succeed and the cached plugin contains only the AC1 entries.
- **Method:** executed-test (guard structural check) + cli-output (live install)
- **Evidence:** the guard's AC4 python assertion passes. `ac4-install.log`: "Successfully added marketplace", "Successfully installed plugin", and the cache entries are exactly the AC1 set.
- **Confidence:** Verified (multi-source)

### AC5: `--dry-run` writes nothing; `--output` equal to the repo root or `/` exits non-zero without writing.
- **Method:** executed-test
- **Evidence:** `ac5-packager-safety.log`: the dry run reports "nothing written"; `.`, `/`, `//`, `/..`, `$HOME`, `..` and a non-empty non-package dir are all refused with exit 1, and the non-package dir's contents stay intact; rebuilding over a previous package works. (First pass found `--output /` reaching `rm -rf "///"`, stopped only by GNU rm's preserve-root. Fixed with realpath resolution and refusal rules before this evidence was captured.)
- **Confidence:** Verified (single-source)

### AC6: `master`'s `.claude-plugin/marketplace.json` plugin `source` is `{"source": "url", "url": "https://github.com/rohitsharma9646/feature-flow.git", "ref": "dist"}` with `version` equal to `plugin.json`'s, and `version-sync-guard.sh` passes.
- **Method:** executed-test (guards)
- **Evidence:** the `claude-dist-guard.sh` AC6 assertion passes; `version-sync-guard` exit 0 at 0.18.0 (`guards.log`).
- **Confidence:** Verified (single-source)

### AC7: A CI job runs **only** on `push` to `master`, **after** the guard job succeeds, builds the package and updates the `dist` branch to exactly that tree — creating it if absent, committing only when the tree changed — with `contents: write` scoped to that job alone.
- **Method:** build/static-analysis (workflow) + executed-test (publisher against a local remote)
- **Evidence:** `ac7-workflow.log`: top-level `contents: read`, job `contents: write`, `if: push && refs/heads/master`, `needs: guards`, concurrency `publish-dist`. `ac7-publish-local.log`: branch created with orphan history, re-run "unchanged" (1 commit), and `dist` = the package tree (46 files, 0 `.go`). The reviewer confirmed PRs and forks can't reach the job.
- **Confidence:** Verified (multi-source)
- **Named gap:** the job has never run on GitHub. Its first real run happens on the merge push to `master`. Repo-level Actions settings could still deny `contents: write`; check that run.

### AC8: `scripts/checks/claude-dist-guard.sh` (run by the CI guard loop) builds the package into a temp dir and fails if AC1, AC2 or AC3 is violated; a mutated package (a stray `.go` file, or a dangling `${CLAUDE_PLUGIN_ROOT}` reference) makes it exit non-zero.
- **Method:** executed-test
- **Evidence:** `ac8-guard-and-mutations.log`: the real package exits 0, and all 6 mutations exit 1. It lives in `scripts/checks/`, so the CI loop runs it.
- **Confidence:** Verified (single-source)

### AC9: README's install section uses `claude plugin marketplace add rohitsharma9646/feature-flow#dist`; it carries a migration note for existing users (`claude plugin marketplace remove feature-flow`, then re-add from `#dist`); the "Native integrity operations" paragraph states the `ff-integrity` binary is not part of the marketplace install; the `[0.18.0]` CHANGELOG entry describes the change.
- **Method:** cli-output (grep)
- **Evidence:** `ac9-ac10-greps.log`: README lines 38, 53–54 and 237, and the CHANGELOG "Runtime-only install (`#dist`)" paragraph. The conventions reviewer checked the README/CHANGELOG claims against the code and the CLI verbs against the docs.
- **Confidence:** Verified (single-source)

### AC10: `commands/ff-retro.md` and `docs/manifest-schema.md` §Retrospective no longer imply `evals/forward/README.md` exists in an installed plugin (the case shape stays stated inline; the file is referenced as living in the feature-flow repository).
- **Method:** cli-output (grep) + executed-test (retro-guard still pins the inline shape)
- **Evidence:** `ac9-ac10-greps.log` shows all three references (command, schema and template) now say "feature-flow repository … not shipped with the plugin". `retro-guard.sh` exit 0.
- **Confidence:** Verified (multi-source)

**Overall confidence:** Verified (single-source).

## Evidence artifacts index

| File | Kind | Backs |
|------|------|-------|
| `evidence/guards.log` | executed-test | AC1–AC3, AC6, AC8, AC10 |
| `evidence/eval.log` | executed-test | regression |
| `evidence/ac8-guard-and-mutations.log` | executed-test | AC1, AC2, AC3, AC8 |
| `evidence/ac5-packager-safety.log` | executed-test | AC5 |
| `evidence/ac4-install.log` | cli-output | AC1, AC2, AC4 |
| `evidence/ac7-publish-local.log`, `evidence/ac7-workflow.log` | executed-test / static | AC7 |
| `evidence/smoke-ff-status-from-package.json` | cli-output | AC3 (runtime works from the package) |
| `evidence/ac9-ac10-greps.log` | cli-output | AC9, AC10 |

## Regression risk

**Medium.** This changes how every user installs. Mitigations: the plugin's runtime content is untouched (the package is a subset copy), all 21 guards stay green, and a live command ran from the package. The main risk is a runtime path missed by the allowlist: the guard catches every `${CLAUDE_PLUGIN_ROOT}`/`$CLAUDE_PLUGIN_ROOT` reference, but not a file read through some other path form. None exist today, per the reviewer's walk of hooks, skills and commands.

## Limitations & remaining risks

- **First live publish is untested on GitHub** (AC7 gap above). Until it runs, `dist` doesn't exist, and `#dist` installs and master-marketplace updates will fail. Merge order matters: the publish job runs on the same push that lands this change.
- **`owner/repo#branch` is undocumented** (observed on CLI 2.1.280). If a future CLI drops it, the fallback is master's marketplace (already pointed at `dist`) plus `--sparse .claude-plugin`.
- **Private repo:** the HTTPS `url` source needs the user's git credentials for github.com, exactly as today's install does.
- **Existing installs** keep a full marketplace clone until the user re-adds it (documented).
- **Pre-existing, out of scope:** `scripts/package-codex-plugin.sh` resolves `--output /` the same unsafe way the new packager originally did (`abs_path "/"` → `//`, which bypasses its root check before `rm -rf`). Worth a follow-up fix.

## Verdict

**Ready for done.** All 10 ACs are at `Verified (single-source)` or better. The AC7 live CI run is a named gap that can only close after merge.
