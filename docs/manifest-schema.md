# Manifest contract — `.feature-flow/<slug>/manifest.json`

Every feature-flow command reads and writes this file. It is the single shared,
durable state object for a run. Defining it here once means every phase command
obeys the same contract instead of inventing its own state shape — this is what
makes phases composable, standalone-runnable, and resumable from disk.

## Schema

```json
{
  "slug": "add-oauth",
  "track": "feature | bugfix",
  "tier": "full | lite",
  "createdAt": "<ISO8601>",
  "updatedAt": "<ISO8601>",
  "currentPhase": "explore|clarify|design|plan|diagnose|implement|review|verify|done",
  "phases": {
    "<phase>": { "status": "pending|in_progress|complete", "artifact": "<relative path or null>" }
  },
  "signOff": { "required": true, "signed": false, "date": null },
  "bugfix": {
    "red":   { "command": "<test cmd>", "exit": 1, "evidence": "<failing output, pre-fix>" },
    "green": { "command": "<test cmd>", "exit": 0, "evidence": "<passing output, post-fix>" }
  },
  "artifacts": {
    "spec": "spec.md",
    "design": "design.md",
    "diagnosis": "diagnosis.md",
    "plan": "plan.md",
    "review": "review.md",
    "verify": "verify.md"
  }
}
```

## Field notes

- **`track`** and **`tier`** are set by `/ff` at classification time, or by the first
  standalone command run if a phase command is invoked directly with no manifest yet.
  - `track: feature` → phases: explore → clarify → design → plan → implement → review → verify.
  - `track: bugfix` → phases: diagnose → implement (test-first) → verify → review.
- **`tier`**: `full` (larger work; requires a signed-off `spec.md`/`diagnosis.md` and a `plan.md`)
  vs `lite` (trivial/obvious bug; a confirmed `diagnosis.md` is the gate, no separate signed spec).
- **`currentPhase`** is the phase most recently entered; `done` when the run is complete.
- **`phases.<phase>.artifact`** is the relative path (within the run dir) of the artifact that
  phase produced, or `null` if it writes no file (e.g. explore may summarize inline).
- **`signOff`**: feature track and escalated (`full`) bugfixes require sign-off before
  `/ff-implement` may write code. Lite bugfixes set `required: false`.
- **`bugfix`** (bugfix track only): the test-first evidence. `/ff-implement` writes
  `red` when the regression test fails pre-fix and `green` after the fix passes;
  `/ff-verify` cites both for the RED→GREEN contract (AC11). A run with no `bugfix.red`
  recorded was not done test-first and `/ff-verify` reports it incomplete.
- **`artifacts`** maps logical names to the file path each phase wrote.
  - **Default:** artifacts live in the run sandbox — `<base>/<slug>/<name>.md`.
  - **`paths.spec` / `paths.plan`** (in `.feature-flow.json`) relocate the spec and plan out
    of the sandbox. **Each value is a directory** (relative to the repo root), never a full
    file path; the file written is **`<dir>/<slug>.md`** (e.g. `paths.spec: "specs"` + slug
    `add-oauth` → `specs/add-oauth.md`). Create the directory if it doesn't exist. Only
    `spec` and `plan` are relocatable; `design`/`diagnosis`/`review`/`verify` always stay in
    the sandbox.
  - Whichever location is used, record the **resolved actual path** in `artifacts.<name>` so
    resume and status read the real file.

## Run resolution (how every command finds the run before reading the manifest)

All commands resolve the target run the **same way** — this is the canonical rule; phase
commands reference it instead of restating their own:

1. **Resolve the base.** Read config (`.feature-flow.json` →
   `${CLAUDE_PLUGIN_ROOT}/config/defaults.json`); use `paths.base` (default `.feature-flow`)
   as the sandbox root.
2. **Named run wins.** If `$ARGUMENTS` names a slug (or a run dir), use `<base>/<slug>/`.
3. **Single run.** Otherwise, if exactly one run exists under `<base>/`, use it.
4. **Several runs → most recent, but disambiguate when unclear.** If more than one run
   exists, use the **most recently updated** (`updatedAt`). If that is genuinely ambiguous
   (e.g. two updated at nearly the same time, or the request clearly points at a different
   run), **ask the user which run** rather than guessing.
5. **Cold-start / new run.** An entry or first-phase command starting fresh work instead
   derives a new kebab `slug` from `$ARGUMENTS` and **creates** `<base>/<slug>/`.

## Rules every command MUST follow

1. **Read the manifest first.** If absent, create it (set `slug`, `track`, `tier`,
   `createdAt`, empty `phases`, `signOff`).
2. **Check the gate** for this phase (e.g. `/ff-implement` requires `signOff.signed`
   on the feature/full track; a confirmed `diagnosis.md` on the lite bugfix track).
3. **Do the phase work**, reading any required upstream artifacts.
4. **Write the artifact** to the run dir (or the configured override path).
5. **Update the manifest**: set this phase's `status` + `artifact`, bump `updatedAt`
   and `currentPhase`.

Resume (`/ff-resume`) and status (`/ff-status`) read this file. If the manifest is
missing or corrupt, resume infers the phase from which artifacts exist on disk.
