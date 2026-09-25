# Knowledge base — feature-flow manifest contract
> Part of the manifest contract. Core rules and the topic index: `docs/manifest-schema.md`.

## Knowledge base

The Knowledge base (KB) closes feature-flow's learning loop: it **captures** each finished run's
architectural decisions / project conventions as committed, project-local markdown entries, and
**recalls** matching entries into the `explore`, `design`, and `diagnose` agent dispatches of later runs
(and, via **Decision recall** below, into `implement`) — stale ones flagged, never silently
presented as fresh. This is the single canonical contract; the six hooked commands (`ff-verify`,
`ff-review`, `ff-explore`, `ff-design`, `ff-diagnose`, `ff-implement`) reference this section by
name and never restate it inline. It is the same house style as **Durable artifact resolution** above.

### Activation (on by default; opt out with `toggles.kb: false`)

The KB is **active iff `toggles.kb === true` AND `paths.kb` is non-null** (defense-in-depth: a
half-configuration skips cleanly, never errors). Both ship active since v0.8.0; setting either
off in `.feature-flow.json` — `toggles.kb: false` or `paths.kb: null` — cleanly deactivates the
KB: capture and recall become skipped no-ops and every hooked phase behaves as if the KB did not
exist. Config keys (`config/defaults.json`, overridable in `.feature-flow.json`):

- `toggles.kb` (default `true`) — master switch; set `false` to opt out.
- `paths.kb` (default `".feature-flow-kb"`) — store directory, **relative to repo root**;
  `null` also deactivates. The KB is **cross-run**:
  it is resolved from config, NOT under `paths.durable`, and NOT added to `manifest.artifacts`
  (which is per-run only).
- `kb.freshnessWindowDays` (default `90`) — age-based staleness window.
- `kb.maxRecallEntries` (default `5`) — recall surfacing cap.

### Store layout + path resolution

When active, each accepted entry is written **one file per entry** at
`<paths.kb>/<YYYY-MM-DD>-<runSlug>-<short-title>.md` (`<YYYY-MM-DD>` = capture date; `<short-title>`
= a kebab slug of the entry title). **No index file in v1** — recall `Glob`s the store directory and
reads each entry's frontmatter. (The index's only real payoff is the dedup/supersession seam, which
is deferred — see v1 non-goals; the fast-follow adds the index when it adds dedup.) The store
directory is `mkdir -p`'d on first write.

### Entry schema

Entries are written from `templates/kb-entry.md`. Frontmatter fields (all required; provenance is
the point):

- `title` — one-line decision/convention name.
- `captureDate` — `YYYY-MM-DD`, the date the entry was captured.
- `captureCommitSha` — `git rev-parse HEAD` at capture, or `null` (not a git repo / `git rev-parse`
  fails / Codex degrade). Recorded for provenance and a future commit-distance refinement; v1's
  staleness trigger does **not** use it.
- `runSlug` — the capturing run's slug.
- `tags` — 1–3-word topic nouns (user-editable at the capture gate); the recall match key.
- `referencedFiles` — repo-relative paths this entry depends on; the staleness referent set.

Body sections: **Decision/convention**, **Why**, **Referenced artifacts**, **Scope**.

### Capture rule (confirm-gated, at the done-transition)

Capture fires **once per run, at whichever command sets `currentPhase="done"`** (the run-completion
convergence), sequenced **after** that phase's artifact + manifest update but **before**
`currentPhase="done"`, so a dropped session stays recoverable (the command re-runs and re-fires the
gate). Capture fires at the run's **done-transition** — defined once in **Terminal convergence**
above. The only capture-specific detail: `ff-review` carries a **feature-track guard** — on the
feature track review precedes verify, so `ff-review` skips capture and it happens at `ff-verify`.
Firing only at the done-transition guarantees capture happens exactly once and never
double-captures.

When active, the command reaching the done-transition:

1. Reads the run's artifacts via **`manifest.artifacts.<name>`** pointers (`spec`/`diagnosis`,
   `design`, `decision`, and `plan` if present, `verify`, `review`) — never bare filenames. When
   a `decision` record is present, it is the **preferred** distillation source for the run's
   architectural decision (already structured — options, trade-offs, chosen rationale), so
   capture lifts it rather than re-deriving the decision from `design` prose.
2. Captures `git rev-parse HEAD` inline → `captureCommitSha` or `null` on failure (never blocks).
3. Distills **1–3 candidate entries**, biased to architectural decisions + project conventions
   (lessons/pitfalls are opt-in), auto-proposing `tags` + `referencedFiles`.
4. **CONFIRM GATE (cross-turn, mandatory in both modes):** presents the candidates; the user
   accepts / edits / rejects each. **Nothing is written until the user confirms.**
5. For each accepted entry: `mkdir -p <paths.kb>` and `Write` the file from the template.
   **feature-flow performs no `git add` / `git commit`** (write-only doctrine — the user commits).
6. Reject-all / none proposed → write nothing; the run completes without error → `currentPhase="done"`.

### Recall rule (wired into explore, design, and diagnose)

Recall runs **before the agent dispatch** in `ff-explore` (before the explorer dispatch),
`ff-design` (after the sign-off gate, before the architect dispatch), and `ff-diagnose`
(before the diagnostician dispatch). When active:

1. `Glob <paths.kb>/*.md`. **Empty store** → print a one-line note and proceed normally (no error).
2. Extract keywords from `$ARGUMENTS` (for diagnose that is the bug report; for design, also the
   spec's `## Problem` resolved via `manifest.artifacts.spec`) and **tag-match** them against each
   entry's `tags` frontmatter.
3. Run the staleness check (below) on each match.
4. Surface up to `kb.maxRecallEntries` matches (recency-ordered by `captureDate`) to the dispatched
   agents as appended context — fresh entries plain, stale entries decorated (never dropped).
   **No match** → one-line note, proceed.

### Decision recall (ff-design, ff-implement)

Closes feature-flow's actuation gap: a run's decision record does not just get filed — it
**constrains** later phases of the same run, and (once captured to the KB) later runs. This is
the single canonical contract; `ff-design` and `ff-implement` reference this subsection by name
and never restate its steps inline. Two sources feed the **do-not-contradict** STOP, resolved
differently and **never conflated**:

1. **This run's own decision — `manifest.artifacts.decision`, unconditional (no KB needed).**
   The sole locating authority (never a hardcoded filename). The read is unconditional — it
   costs nothing and applies identically on full tier (resolves to the promoted decision record)
   and lite tier (resolves to the `spec` — `ff-clarify` set the pointer there, since the spec's
   inline `## Solution approaches considered` *is* the lite decision record). **No tier branch in
   the locating logic** — the same pointer read serves both. Absent `artifacts.decision`
   (pre-v0.10.0 manifest) → "no decision recorded"; proceed, no error. `ff-design` does **not**
   read this source (a run cannot contradict a decision it has not made yet) — it reads only
   source 2.
2. **Prior decisions from other runs — KB-gated, reuses the Recall rule above verbatim.**
   Gated on `toggles.kb` + `paths.kb`. Every KB entry already records a settled decision or
   convention (`templates/kb-entry.md` §Decision / convention), so the generic recall surface
   **is** the prior-decision surface — glob, tag-match, apply the **Staleness rule** below
   (stale entries flagged `[STALE — <reason>]`, never dropped). `ff-design` tag-matches the
   spec's `## Problem` before the architecture pick; `ff-implement` tag-matches this run's
   decision content alongside its source-1 read. KB off → source 2 is skipped; source 1 still fires.

**Do-not-contradict STOP (the refuse).** A **prose gate only** — no hook can diff semantic
contradiction, so this is honorable by instruction (Codex-safe), not machine-enforced. If the
architecture about to be chosen (`ff-design`, vs source 2) or the approach about to be coded
(`ff-implement`, vs source 1 or 2) **diverges** from a recalled decision, **STOP unconditionally
in both modes** — never self-resolved, never autopilot-retried (unlike a Critical review
finding). Surface the conflict, shaped:

> Decision conflict detected — not proceeding on the current approach:
> - **Recalled decision:** `<prior KB entry path | this run's decision>` — `<title>` (`<date>`):
>   `<the settled decision statement>`
> - **Diverges because:** `<the specific way the current pick/approach contradicts it>`
> To proceed: (a) realign the approach with the settled decision, or (b) reply with an explicit
> override — recorded verbatim as `Decision override by user (<date>): <reason>` in the resolved
> `artifacts.decision` record, and the run continues.

The override is **never self-authored** — record only the user's own in-conversation words,
exactly like the evidence waiver (§Evidence). No prior decision recalled / no conflict →
one-line note, proceed (mirrors empty-store recall). See the **Decision conflict stop** row in
§Autopilot.

### Staleness rule

An entry is **stale** if **any** of its `referencedFiles` is missing/moved **OR** the entry is
older than `kb.freshnessWindowDays` (default 90, measured from `captureDate`). Staleness is computed
inline (no agent). A stale entry is **flagged, not suppressed**: surfaced to the agents decorated
`[STALE — <reason>]` (e.g. `[STALE — referenced file src/foo.ts missing]` / `[STALE — 120d old,
window 90d]`) — never silently dropped and never presented as current truth. `captureCommitSha` is
**not** part of the v1 trigger (provenance only).

### Codex degrade table

| Capability | Claude Code | Codex / non-git degrade |
|---|---|---|
| `captureCommitSha` (`git rev-parse HEAD` via inline `Bash`) | recorded | `null`; entry still written |
| Staleness referent check (`Read`/`Glob`) | file-existence + age | falls back to **referent-existence only** if `Glob`/`Read` unavailable; age check always applies |
| Tag-match recall + confirm gate | native | **platform-neutral** — no degrade |

### v1 non-goals (honest deferral)

Deferred to a fast-follow run, stated here, in the SKILL, and the README so the gap is explicit
(not silent): **dedup** of new entries against existing, **supersession** (newer marks older
superseded), an **`index.json`** query surface, a standalone ad-hoc **`ff-learn`** command,
**content-similarity / referenced-file-overlap relevance** (v1 is tag-match only), **mid-run /
continuous capture** (capture fires once, at run completion), **auto-committing** entries, and a
**cross-project / global KB** (v1 is project-scoped). Duplicate insights across runs therefore
persist — accepted v1 limitation, surfaced not silently dropped.

