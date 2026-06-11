# feature-flow

Composable, durable, verifying Claude Code plugin for **feature development** and **bug fixing** — two tracks, one spine, real (executed) verification.

> **Status:** v0.1.0 (in development).

## What it is

Two gated, resumable workflows over on-disk artifacts, each verified by really-executed tests:

- **Feature track** — `explore → clarify → design → plan → implement → review → verify`.
  *clarify* challenges the premise, weighs problem-level solution approaches, and locks testable
  acceptance criteria (it owns the WHAT; *design* owns the HOW).
- **Bugfix track** (test-first) — `diagnose → implement (failing regression test → RED → fix →
  GREEN) → verify → review`.

All run state lives in a `.feature-flow/<slug>/` sandbox with a `manifest.json`, so work is
resumable and a dropped session is recoverable.

## Install (local dev)

```
claude plugin marketplace add ~/feature-flow
claude plugin install feature-flow@feature-flow-dev
```

> The install **copies** source into `~/.claude/plugins/cache/feature-flow-dev/feature-flow/<version>/`
> (not a symlink). After editing the source, refresh the cache with **uninstall + reinstall**
> (`claude plugin update` no-ops on an unchanged version), then **fully restart** your Claude
> session — plugins load at process startup, so a new conversation/`/clear` won't pick up changes.

## Usage

Start a run with the entry command, then proceed phase by phase (each phase is its own command):

```
/feature-flow:ff "<your feature or bug request>"
```

Commands are namespaced under `/feature-flow:` — e.g. `/feature-flow:ff-clarify`,
`/feature-flow:ff-design`, `/feature-flow:ff-status`, `/feature-flow:ff-resume`.

## License

MIT — see [LICENSE](LICENSE).
