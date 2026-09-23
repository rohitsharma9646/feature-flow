# Spec: Ship only runtime files to Claude Code users (generated `dist` branch)

**Created:** 2026-09-23
**Track:** feature
**Status:** signed-off

## Problem

Installing feature-flow from its marketplace copies the **whole repository** onto the user's machine:
Claude Code copies the entire plugin directory into the cache (no ignore/allowlist exists), and the
marketplace repo itself is cloned too. The user's own `0.17.0` cache holds `.github/`, `scripts/`,
`evals/`, `CHANGELOG.md` and every past run's docs; a `0.18.0` install would add 73 Go source files,
`go.mod`, `cmd/`, `integrity/`, 145 eval files and 241 run-evidence files. None of it runs for users
(they need only bash + `jq`); it is dead weight the maintainer does not want deployed.

## Expected outcome

A user who adds the marketplace and installs the plugin gets **only runtime files** on disk — in both
the marketplace clone and the plugin cache — and feature-flow works exactly as before. The dev repo's
`master` keeps its full layout; a CI job publishes the runtime-only tree to a `dist` branch on every
push to `master`.

## Solution approaches considered

lite tier — single obvious approach; alternatives not weighed here. (The approach was chosen in
conversation: generated `dist` branch **over** a separate plugin repo **and over** restructuring into a
subfolder — the latter leaves the full repo on disk via the marketplace clone.) Mechanics validated
empirically (see Assumptions): the `dist` branch holds **both** `marketplace.json` and the plugin
(`"source": "./"`), users add `rohitsharma9646/feature-flow#dist`; `master`'s `marketplace.json` points
its plugin at the `dist` branch too, so existing users' plugin cache becomes clean on their next update.

## Assumptions (WHAT-changing)

| Statement | Confidence | Basis / evidence | If-wrong impact | Validation-required |
|---|---|---|---|---|
| `claude plugin marketplace add owner/repo#<branch>` clones that branch, single-branch, depth 1 | high | Probe 2026-09-23 on a public repo, non-default branch `add-adlc`: checked-out branch `add-adlc`, `rev-list --all` = 1, `.git` 276K; `owner/repo@branch` also works (undocumented but observed on CLI 2.1.280) | install command changes (fallback: master marketplace + `--sparse .claude-plugin`, which still leaves root files like `go.mod`) | n |
| A plugin `source` `{"source":"url","url":…,"ref":<branch>}` installs exactly that branch's tree, without `.git` | high | Probe 2026-09-23 via a local bare remote: cache held `ff-retro.md` from the ref'd branch, no `.git` | AC6 changes | n |
| The `"source":"github"` form clones over **SSH**; the maintainer's machine has no GitHub SSH key and the repo is **private** | high | Probe: `git@github.com: Permission denied (publickey)`; `gh repo view` → PRIVATE; so master's pointer must use the HTTPS `url` form | none if HTTPS used | n |

## Constraints

- No change to how the plugin behaves at runtime; commands/hooks resolve paths via `${CLAUDE_PLUGIN_ROOT}` unchanged.
- `master` keeps its current layout; all existing guards keep passing. Codex packaging is unchanged.
- Repo is private: installs need the user's GitHub HTTPS credentials exactly as today (not a new requirement).
- Stacked on PR #10 (v0.18.0, unreleased): document under the existing `[0.18.0]` CHANGELOG entry, no separate version bump.
- CI write access is job-scoped (`contents: write` only on the publish job), never on PR runs.

## Edge cases

- `dist` branch does not exist yet → the first publish creates it (orphan history), no manual bootstrap.
- A push to `master` that changes no runtime file → publish makes no new commit on `dist`.
- A shipped file references `${CLAUDE_PLUGIN_ROOT}/<path>` not in the allowlist → the guard fails CI (so the allowlist can't silently break the plugin).
- A dev-only file lands inside an allowlisted dir (e.g. a `.go` file under `commands/`) → the guard fails CI.
- Push to a feature branch or a PR run → no publish.
- Existing users added the marketplace from `master` → their **plugin cache** is clean after `claude plugin update` (master points at `dist`); their **marketplace clone** stays full until they re-add from `#dist` (documented).

## Non-goals

- Shipping the native `ff-integrity` binaries in `dist` (not in the marketplace install today either).
- Serving Codex from `dist`; making the repo public; a separate plugin repository.
- Rewriting history or deleting old caches on users' machines.

## Acceptance criteria

- [ ] AC1: `scripts/package-claude-plugin.sh --output <dir>` produces a tree whose top-level entries are exactly `.claude-plugin`, `agents`, `commands`, `config`, `docs`, `hooks`, `skills`, `templates`, `README.md`, `LICENSE`; `docs/` contains exactly `manifest-schema.md` and `grilling-playbook.md`; `.claude-plugin/` contains exactly `plugin.json` and `marketplace.json`.
- [ ] AC2: The produced tree contains no `*.go` file and none of `go.mod`, `go.sum`, `cmd/`, `integrity/`, `schemas/`, `scripts/`, `evals/`, `.github/`, `.codex-plugin/`, `release/`, `CHANGELOG.md`, `docs/feature-flow/`.
- [ ] AC3: Every `${CLAUDE_PLUGIN_ROOT}/<path>` referenced from a shipped file resolves to an existing path inside the produced tree.
- [ ] AC4: The produced tree's `.claude-plugin/marketplace.json` lists `feature-flow` with `"source": "./"` and a `version` equal to `plugin.json`'s; `claude plugin marketplace add <produced dir>` + `claude plugin install feature-flow@feature-flow` (isolated `CLAUDE_CONFIG_DIR`) succeed and the cached plugin contains only the AC1 entries.
- [ ] AC5: `--dry-run` writes nothing; `--output` equal to the repo root or `/` exits non-zero without writing.
- [ ] AC6: `master`'s `.claude-plugin/marketplace.json` plugin `source` is `{"source": "url", "url": "https://github.com/rohitsharma9646/feature-flow.git", "ref": "dist"}` with `version` equal to `plugin.json`'s, and `version-sync-guard.sh` passes.
- [ ] AC7: A CI job runs **only** on `push` to `master`, **after** the guard job succeeds, builds the package and updates the `dist` branch to exactly that tree — creating it if absent, committing only when the tree changed — with `contents: write` scoped to that job alone.
- [ ] AC8: `scripts/checks/claude-dist-guard.sh` (run by the CI guard loop) builds the package into a temp dir and fails if AC1, AC2 or AC3 is violated; a mutated package (a stray `.go` file, or a dangling `${CLAUDE_PLUGIN_ROOT}` reference) makes it exit non-zero.
- [ ] AC9: README's install section uses `claude plugin marketplace add rohitsharma9646/feature-flow#dist`; it carries a migration note for existing users (`claude plugin marketplace remove feature-flow`, then re-add from `#dist`); the "Native integrity operations" paragraph states the `ff-integrity` binary is not part of the marketplace install; the `[0.18.0]` CHANGELOG entry describes the change.
- [ ] AC10: `commands/ff-retro.md` and `docs/manifest-schema.md` §Retrospective no longer imply `evals/forward/README.md` exists in an installed plugin (the case shape stays stated inline; the file is referenced as living in the feature-flow repository).

## Sign-off

**User signed off:** yes (2026-09-23)

> A spec without sign-off does not proceed to **design, planning, or implementation** —
> `/feature-flow:ff-design`, `/feature-flow:ff-plan`, and `/feature-flow:ff-implement` each stop and
> route back to `/feature-flow:ff-clarify` if this reads `no` (implement is the hard backstop). A
> waived review is recorded explicitly: "sign-off waived by user (date)" — never assumed.
