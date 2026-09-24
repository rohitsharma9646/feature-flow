# Design: <feature title>

**Spec:** `<path to spec.md>`
**Created:** <date>

## Chosen approach

<The approach selected, in enough detail to plan against. Why this one.>

## Rejected alternatives

| Alternative | Why rejected |
|-------------|--------------|
| <approach B (e.g. minimal)> | <trade-off that lost> |
| <approach C (e.g. pragmatic)> | <trade-off that lost> |

> The architects fan out with differentiated focuses (e.g. minimal / clean /
> pragmatic). Record the real trade-offs so the choice is auditable.

## Trade-off matrix

Score **every option** the fan-out surfaced (chosen + rejected) on the fixed core — every time,
categorical only (`low / med / high`, no numeric totals):

| Option | Complexity | Risk / operational impact | Test effort |
|--------|------------|----------------------------|--------------|
| <chosen option> | low / med / high | low / med / high | low / med / high |
| <rejected option> | low / med / high | low / med / high | low / med / high |

> Core columns are scored every time. Add another axis (performance, maintainability,
> scalability, security, cost) as an extra column **only when it actually differentiates** the
> options — drop it if every option scores the same. Don't pad the matrix for uniformity; this is
> the lean/adaptive shape. See `docs/schema/design-tradeoffs.md` §Design trade-offs & devil's advocate.

## Component map

| File / module | Responsibility | New or modified |
|---------------|----------------|-----------------|
| <path> | <what it does> | new / modified |

## Data flow

<Entry point → transformations → output / persistence. A short narrative or diagram.>

## Risks

- <Risk and how the design mitigates or accepts it.>

## Devil's advocate

> Stress-test the **chosen** option only (not the rejected ones — this is not a re-litigation of
> the pick). **At least one failure scenario is required**, even for a design with a single obvious
> option. See `docs/schema/design-tradeoffs.md` §Design trade-offs & devil's advocate.

### Failure scenarios

- **FS1:** <a concrete way the chosen approach fails in production — the trigger and the blast radius>

> Numbered `FS<n>` in write order, explicit inline label (not positional). `ff-verify` quotes each
> verbatim into its own `### FS<n>` contract item — exactly as an acceptance criterion — and blocks
> `done` until it is proven or waived. Append-only once verify has run: renumbering breaks the
> mapping, same discipline as spec ACs.

### Edge cases & operational risk

- <A boundary condition, migration, or operational risk the chosen option introduces — context,
  **not** itself a verify contract item. "None" is a valid, stated answer.>
