---
tags: [<topic-noun>, <topic-noun>]
referencedFiles:
  - <repo-relative path this decision constrains>
---

# Decision: <decision title>

**Spec:** `<path to spec.md>`
**Created:** <date>

## Decision

<One-line statement of the architecture/approach settled on — stated so a later phase (or a
later run) can check its own approach against it without re-deriving the whole record.>

## Context

<Why this decision was needed now — the problem or tension that forced a choice.>

## Options considered

| Option | Why considered / rejected |
|--------|----------------------------|
| <chosen option> | chosen — see Chosen + rationale below |
| <alternative> | <why it lost> |

> If genuinely one obvious option, say so and why no alternatives applied — mirrors the spec's
> "one obvious approach" convention.

## Trade-offs

| Option | Effort | Risk | Reversibility |
|--------|--------|------|----------------|
| <option> | <low / med / high> | <low / med / high> | <easy / hard to undo> |

## Chosen + rationale

<The option picked and why it wins the trade-offs above — the detail a later phase needs to
tell whether its own approach still agrees with this one, and what would have to change for a
later run to reopen it (the re-litigation bar).>

**Related ACs:** <AC list from spec.md this decision bears on>
**Related files:** <repo-relative paths this decision constrains — same set as referencedFiles>

> If a do-not-contradict STOP against this decision is overridden, append the user's own words
> here verbatim: `Decision override by user (<date>): <reason>` — never self-authored.

## Outcome

<Filled if revisited during implement/review: did the decision hold, or was it explicitly
overridden? "Pending implementation" until a later phase updates it. A diverging outcome is a
new decision, not a silent edit of this one.>

## Future considerations

<What this decision deliberately deferred, and what would trigger revisiting it — so a later
run's recall doesn't over-apply it forever, and a deferral doesn't calcify as forgotten.>
