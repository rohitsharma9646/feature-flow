# WP1 capability matrix

**Captured:** 2026-07-23
**Scope:** Native protocol targets on Linux, macOS, and Windows plus byte-identical Claude and
Codex package layouts; exhaustive installed-host adapter invocation is deferred to WP4.
**Decision rule:** native target execution plus package-content parity promotes a declared WP1
target to `supported`.

## State model

| State | Meaning |
|-------|---------|
| `candidate` | In the intended scope, but evidence collection is not complete. |
| `supported` | Native target execution and both host-package content checks pass. |
| `unsupported` | Authoritative evidence establishes that the cell is unavailable. |
| `evidence-gap` | Required authoritative or executed evidence is unavailable; the cell blocks WP1. |

Cross-compilation, emulation, direct source execution, and generic CI runner availability are
supplemental only. They cannot promote a cell to `supported`.

## Authoritative evidence found

1. Anthropic's Claude Code plugin reference documents plugin-root `bin/` executables, says those
   executables are added to the Bash tool's `PATH`, and documents `${CLAUDE_PLUGIN_ROOT}` for
   bundled scripts and binaries:
   <https://code.claude.com/docs/en/plugins-reference>.
2. Anthropic's hooks reference documents exec-form hooks, including direct real-executable
   invocation on Windows, and states that shell-form hooks use Git Bash on Windows or PowerShell
   when Git Bash is absent:
   <https://code.claude.com/docs/en/hooks>.
3. OpenAI's current plugin documentation describes Codex plugins as containers for skills, apps,
   and app templates, but does not establish a marketplace contract for target-selected bundled
   native executables, signing, executable path resolution, or automatic/preflight invocation:
   <https://help.openai.com/en/articles/20001256-plugins-in-codex/>.
4. The locally installed official Codex plugin-creator skill supports optional `scripts/` and
   `assets/` folders. This establishes that arbitrary companion files can exist in a local plugin,
   but it does not establish cross-platform marketplace distribution, target selection, signing,
   or installed-package native execution.
5. GitHub documents x86-64 and ARM64 hosted/larger runner offerings across Linux, macOS, and
   Windows, with some ARM64 offerings in public preview:
   <https://docs.github.com/en/actions/reference/runners/github-hosted-runners> and
   <https://docs.github.com/en/actions/reference/runners/larger-runners>.
   Runner availability is not host-plugin execution evidence.

## Target matrix

| OS | Architecture | Native package run | Claude package content | Codex package content | State |
|----|--------------|--------------------|------------------------|-----------------------|-------|
| Linux | x86-64 | pass (`490b5097…157945`) | pass | pass | supported |
| Linux | ARM64 | pass (`6814f41a…b6b2cb`) | pass | pass | supported |
| macOS | x86-64 | pass (`e5e375bd…d03cac`) | pass | pass | supported |
| macOS | ARM64 | pass (`702f497f…279573`) | pass | pass | supported |
| Windows | x86-64 | pass (`dcb09c9e…1f5ed`) | pass | pass | supported |
| Windows | ARM64 | pass (`eb532b74…b6844`) | pass | pass | supported |

## Assumption outcomes

- **Assumption 1 — validation path established.** Claude and local Codex plugin tooling allow
  companion executable assets; package-content parity will validate both non-activating layouts.
  Installed-host Codex activation is explicitly a WP4 question.
- **Assumption 2 — validation path established.** GitHub documents native runner capacity for the
  intended target families. Each target remains candidate until its package executes natively.

## Native matrix evidence

GitHub Actions run
[`30004115045`](https://github.com/rohitsharma9646/feature-flow/actions/runs/30004115045)
executed commit `e98546d60e3cea184fa6b90b909a8e0915836120` on all six declared runner
families. Every job passed unit and conformance tests, complete target plugin-package assembly,
and native byte comparison of source, Claude package, and Codex package outputs for all 12 WP1
vectors. The uploaded package artifacts record the SHA-256 digests shown above.

The packages are self-contained and their invocation performs no download or dependency
installation. The matrix does not claim marketplace installation, host activation, signing, or
notarization; those installed-host adapter concerns remain assigned to WP4 under the approved
scope revision.

## Gate result

**SUPPORTED MATRIX COMPLETE.** All six declared WP1 targets satisfy native execution and both
package-content checks. No candidate, unsupported, or evidence-gap cell remains.

No runtime, schema, classifier, package, command, hook, or manifest behavior was changed while
performing this assessment.
