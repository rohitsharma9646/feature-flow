# Terminal convergence — feature-flow manifest contract
> Part of the manifest contract. Core rules and the topic index: `docs/manifest-schema.md`.

## Terminal convergence (which command marks a run `done`)

Independent of the KB — this governs **every** run, including KB-off ones. A run reaches
`currentPhase = "done"` at its **done-transition**: the single command that completes the run's
**last** required phase. By track:

- **Feature:** review runs **before** verify, so **verify is terminal** — `ff-verify` is always
  the done-transition (it sets `done` once every acceptance criterion passes).
- **Bugfix:** verify and review may run in **either order**; the done-transition is **whichever
  runs second**. The command that finds the other phase already `complete` is the one that sets
  `done`; the command that runs first hands off instead (or, in autopilot, chains). This is
  enforced by each command reading the other's status — `ff-verify` checks
  `phases.review.status`, `ff-review` checks `phases.verify.status` — so neither sets `done` early.

The done-transition is the **single** point where the KB **capture** gate fires (exactly once —
see **Knowledge base** §Capture rule below), which is why the bugfix track never double- or
zero-captures. This section is the canonical statement of the rule; §Capture rule and the two
terminal commands (`ff-verify`, `ff-review`) **reference** it rather than restating it.

> **Delivery is post-terminal.** The optional `deliver` phase (§Delivery) runs *after* the
> done-transition and does **not** change it: `ff-deliver` never sets `done` (the run is already
> there) and never fires KB capture. `currentPhase` stays `done` throughout delivery.

