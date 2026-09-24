# Sign-off rendering — feature-flow manifest contract
> Part of the manifest contract. Core rules and the topic index: `docs/manifest-schema.md`.

## Sign-off rendering

How `ff-clarify` (spec sign-off) and `ff-diagnose` (full-tier diagnosis sign-off) present
the contract in the sign-off ask. Three rules, all mandatory:

1. **Verbatim.** The ask quotes the contract items exactly as written in the artifact —
   the spec's acceptance criteria / the diagnosis's fix approach, root cause, fix surface,
   and regression-test plan. The user reviews exactly what they are signing without opening
   the file; a summary is not a substitute.
2. **Grouped checklist, never a blockquote wall.** Render the items as a plain-markdown
   checklist grouped under short theme headings — **not** inside a `>` blockquote:
   - 3–6 theme headings (`### <Theme>`), chosen by subject-matter clustering at ask time;
     aim for ≤ ~5 items per group.
   - Each item: `- [ ] **AC<n> — <short label>**: <criterion text verbatim>` (diagnosis
     contracts use `**<item name>**` instead of an AC number).
   - The label is additive; the criterion text after the colon stays verbatim (rule 1).
3. **Unvalidated-assumptions echo, as a distinct trailing block.** Every still-unvalidated
   `validation-required: y` assumption (§Assumption records — that section owns the trigger,
   actuation, and waiver; this rule owns only the *rendering shape*) is echoed **after** the
   AC/contract checklist as its own `### Unvalidated assumptions` block — **never folded into the
   `- [ ] AC<n>` checkboxes** (a "please confirm" checkbox ≠ a "still unvalidated" flag). The block
   **always states the true status**: a clean `_None unvalidated._` when there are none (it never
   false-fires a block). Its presence with entries **blocks a clean sign-off** — the run cannot reach
   `signOff.signed = true` until each is **resolved** (validated, waived via the verbatim `Assumption
   validation waived by user (<date>): <reason>` line, or acknowledged-open — §Assumption records →
   Actuation 1 owns the three exits). This is the Evidence-gap-stop shape, **not** the
   do-not-contradict STOP — so the §Autopilot row for it must **not** say "unconditional".

Example shape:

    ### Switch & defaults
    - [ ] **AC1 — config key**: `config/defaults.json` contains `toggles.autopilot` …
    - [ ] **AC2 — run-start ask**: When a new run starts and resolved `toggles.autopilot` …

    ### Chaining behavior
    - [ ] **AC6 — boundaries chain**: With `autopilot: true`, every ceremonial phase …

    ### Unvalidated assumptions
    These `validation-required: y` assumptions are not yet validated — validate each, or reply
    with `Assumption validation waived by user (<date>): <reason>`. Sign-off cannot complete until
    then:
    - **Assumption 2**: <the assumption statement, verbatim from the table> (if-wrong: <impact>)

    (When none are outstanding this block reads `### Unvalidated assumptions` / `_None unvalidated._`
    — always shown, never a false-firing block.)

