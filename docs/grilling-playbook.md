# Requirements grilling playbook

Technique detail behind `/feature-flow:ff-clarify`'s 4-beat interrogation. The command names the
beats and the invariant; this file carries the *how*. **Refining a technique happens here.
Adding a new concern does NOT** — concerns are routed by the WHAT/HOW/HOW-WELL table in the
command (new concern → `ff-design` or `ff-review`, never appended here).

## Beat 1 — Premise (The Mom Test + Five Whys)
Anchor to the real underlying need, not the feature as phrased.
- The requested feature is one candidate solution, not the requirement. Ask about the concrete
  problem behind it: "What are you doing today that makes you want this?" "What breaks if it
  doesn't exist?" — past behaviour and real friction, not hypotheticals or opinions.
- Avoid leading / validation-seeking questions ("wouldn't it be nice if…"). Ask what actually
  happened last time, not what they imagine they'd do.
- When an answer is shallow or just restates the request, probe with one "why" (up to ~3) until it
  bottoms out at a concrete need. Stop when another "why" stops changing the answer.
- Output: a one-line problem statement phrased as the *need*, not the requested feature.

## Beat 2 — Solution options (problem-level, NOT architecture)
Surface 2–3 genuinely distinct *whats* that satisfy the need; let the user choose.
- Each option is a different way to solve the problem (e.g. for a stale cache: a disable flag, a
  configurable TTL, auto-invalidate-on-write, or don't-cache-this-path). NOT different
  implementations of one option — that is `ff-design`.
- Give a one-line trade-off per option (cost, blast radius, fit with the codebase from
  `explore.md`) and a recommendation. Enough to choose; not a deep analysis.
- Ask the user to pick (or confirm the recommendation). Record chosen + rejected with a one-line
  rationale each → the spec's "Solution approaches considered" section.
- If there is genuinely one sane approach, say so ("one obvious approach: X") and move on. Never
  manufacture fake alternatives.

## Beat 3 — Scope + examples→ACs (Example Mapping)
Turn the chosen approach into concrete, testable behaviour.
- State scope and explicit non-goals for the chosen approach.
- For each rule/behaviour, write a concrete input→output example. Edge cases emerge as you try to
  example each rule: empty/zero input, the boundary, the input that includes the feature itself,
  repeated/duplicate input, the error path.
- Each example becomes a binary acceptance criterion: "When <input>, <observable output>" — no
  judgement words ("good", "clean", "intuitive"); each checkable by a named action.

## Beat 4 — Assumptions that change the WHAT
Surface only the assumptions that, if wrong, would change the spec.
- Ask "what are we taking for granted about the need or the chosen approach?" Record only those
  that would alter scope/ACs if false.
- Deep risk, pre-mortem, security/UX/accessibility/cost/performance are NOT here — they belong to
  `ff-design` (HOW) and `ff-review` (HOW-WELL). If one surfaces, note it for that phase and move on.

## The red-team pass (before sign-off — one discipline, not a technique pile)
After drafting `spec.md`, re-read your own draft adversarially against the invariant:
- Is the stated problem the real need, or did I accept the request at face value?
- Is the chosen approach actually the best of the options I surfaced — or did I rationalise the
  first one?
- Is every acceptance criterion binary and checkable? Any "it should work well" hiding in there?
- Any WHAT-changing assumption still implicit?
Revise the spec, or ask the user the questions that survive. Then present for sign-off.
