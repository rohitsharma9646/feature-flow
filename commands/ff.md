---
description: "Entry point: classify the request (feature vs bugfix), set up a durable run, start the first phase, then hand off phase-by-phase."
argument-hint: "\"<feature request or bug report>\""
---

# /feature-flow:ff — classify, set up a run, and start it

`$ARGUMENTS` is the request. This command **classifies the request, initializes a durable
run, and starts only the first phase**, then STOPS and hands you to the next phase. In
**step-by-step mode** it does **not** chain the whole workflow — each later phase is its
own command you invoke, so every human gate is honored and a dropped session is
recoverable. In **autopilot mode** (`manifest.autopilot: true`), ceremonial phase-end
STOPs become continuations — see **Autopilot** in
`${CLAUDE_PLUGIN_ROOT}/docs/manifest-schema.md`; human gates pause in both modes.

> **Precedence — read before doing anything.** You are executing the feature-flow
> workflow. Its phases REPLACE any generic brainstorming / writing-plans / make-plan /
> docs-first planning in your environment: do **not** invoke those skills, and do **not**
> write to `~/.claude/plans/`, `docs/plans/`, or a separate brainstorm doc. Every artifact
> lives in the `.feature-flow/<slug>/` sandbox recorded by its `manifest.json`. Follow the
> steps below literally and in order, creating files with the Write tool. Run only the
> current phase, then STOP. In autopilot mode, ceremonial phase-end STOPs become
> continuations — see **Autopilot** in
> `${CLAUDE_PLUGIN_ROOT}/docs/manifest-schema.md`.

## Step 1 — Classify the track (feature vs bugfix)

Judge `$ARGUMENTS` (soft judgment — no rigid keyword rule):

- **bugfix** — restore *intended* behavior in existing code: something is broken, throws,
  regressed, or misbehaves ("fix:", "crashes", "wrong result", "broke after…").
- **feature** — add *new* behavior or capability that doesn't exist yet.

- **Ambiguous?** Ask the user **once** which it is, then proceed. Don't guess silently.
- **Genuinely both** (e.g. "fix the parser and add CSV export")? Do **not** run a hybrid —
  tell the user you'll **split** it: handle the **bug fix first** (its own run), then the
  feature as a separate run. Set up only the first (bugfix) run now.

## Step 2 — Set up the run (do this now)

0. **If you are in plan mode, leave it before writing anything.** feature-flow's first real
   action is writing `manifest.json` to disk, and **plan mode forbids non-plan writes** — a
   session that stays in plan mode falls back to a generic native plan (e.g. a file under
   `~/.claude/plans/`) instead of starting a run. Classifying (Step 1) and reading config
   below are read-only and fine in plan mode, but **before the first Write you MUST exit plan
   mode**: call **`ExitPlanMode`** with a one-line plan — *"Start a feature-flow `<track>`
   run: write the manifest, run the `<first phase>` phase, then stop at the next gate."* —
   and once the user approves, continue with the writes below. The feature-flow workflow **is**
   the plan (its own explore/clarify/design/plan phases and sign-off gate provide the review),
   so do **not** also present a generic native plan or write to `~/.claude/plans/`. (If
   `ExitPlanMode` is unavailable in your environment, **STOP** and tell the user to exit plan
   mode — shift+tab — then re-run `/feature-flow:ff`.)
1. **Read config:** a repo-root `.feature-flow.json` overrides
   `${CLAUDE_PLUGIN_ROOT}/config/defaults.json`. Resolve `paths.base` (default
   `.feature-flow`), agent counts, models, `reviewThreshold`, and toggles.
2. **Resolve autopilot first (run-start procedure — BEFORE the manifest write):** if this
   run's manifest already exists with an `autopilot` field, skip this entirely — never
   re-ask. Otherwise read `toggles.autopilot` from config (`.feature-flow.json` →
   `${CLAUDE_PLUGIN_ROOT}/config/defaults.json`; default `"ask"`):
   `"ask"` → ask the user once (AskUserQuestion) — **autopilot** (phases chain
   automatically, pausing only at sign-offs, the design choice, and Critical review
   findings) vs **step-by-step** (each phase stops; current behavior); `true`/`false` →
   use that value directly, no question. **Never choose the value yourself:** when config
   is `"ask"`, the boolean may come ONLY from the user's in-conversation answer — if you
   have no answer, you MUST ask before writing the manifest. Writing a manifest with a
   self-chosen `autopilot` is a defect. See **Autopilot** in
   `${CLAUDE_PLUGIN_ROOT}/docs/manifest-schema.md`.
3. **Create the run:** derive a short kebab `slug` from `$ARGUMENTS`. **Use the Write tool
   now** to create `<base>/<slug>/manifest.json` per the contract
   (`${CLAUDE_PLUGIN_ROOT}/docs/manifest-schema.md`):
   - **feature:** `track: "feature"`, `tier: "full"`, `currentPhase: "explore"`,
     `signOff: { required: true, signed: false }`.
   - **bugfix:** `track: "bugfix"`, `currentPhase: "diagnose"`, `signOff: { required:
     false, signed: false }` (tier is decided during diagnose).
   - Both: `createdAt`, `autopilot` (the value resolved in step 2 — the manifest is
     written **with** it), empty `phases`. Confirm the file exists before continuing — if
     you have not written a manifest to disk, you have not started a run.

## Step 3 — Start the first phase, by track

### Feature → run the explore phase now (only this phase)

The manifest is set up; now run the explore phase **exactly as specified in
`${CLAUDE_PLUGIN_ROOT}/commands/ff-explore.md`** — that file is the single canonical
write-up of the explore procedure (read `models.explorer` from config, dispatch
`explorerAgents` differentiated `ff-code-explorer` agents, synthesize, write
`<run dir>/explore.md` from `${CLAUDE_PLUGIN_ROOT}/templates/explore.md`, update the
manifest). Do not restate or improvise the procedure here. Then **STOP (step-by-step) /
continue (autopilot):** if `manifest.autopilot` is `true`, emit the progress strip and
proceed directly into the clarify phase per
`${CLAUDE_PLUGIN_ROOT}/commands/ff-clarify.md` — see **Autopilot** in
`${CLAUDE_PLUGIN_ROOT}/docs/manifest-schema.md`. If `false` or absent, **STOP and hand off:**

   > Explore complete — findings in `<run dir>/explore.md`. The next phase (**clarify**)
   > will ask a few clarifying questions and produce a `spec.md` for your **sign-off**. Run
   > `/feature-flow:ff-clarify` to continue.

   End the message with the one-line progress strip — see **Progress strip** in
   `${CLAUDE_PLUGIN_ROOT}/docs/manifest-schema.md`.

### Bugfix → hand off to the diagnose phase (do NOT run it here)

The bugfix track's first phase is **diagnose**, which is a *gated* analysis phase (it can
STOP to ask for repro detail, and may require sign-off). It lives in its own command. The
manifest is set up; if `manifest.autopilot` is `true`, emit the progress strip and proceed
directly into the diagnose phase per `${CLAUDE_PLUGIN_ROOT}/commands/ff-diagnose.md` — see
**Autopilot** in `${CLAUDE_PLUGIN_ROOT}/docs/manifest-schema.md` (diagnose's own gates
still apply). If `false` or absent, **STOP and hand off:**

> This is a **bug fix** — run set up (`<run dir>/manifest.json`, `track: bugfix`). The next
> phase (**diagnose**) will reproduce the bug, find the root cause, and decide the fix
> approach (writing `diagnosis.md`). Run `/feature-flow:ff-diagnose` to continue.

End the message with the one-line progress strip (bugfix order: `diagnose[NEXT] → implement
→ verify → review`) — see **Progress strip** in `${CLAUDE_PLUGIN_ROOT}/docs/manifest-schema.md`.
Then **end your turn.** In step-by-step mode the user drives the next phase.
