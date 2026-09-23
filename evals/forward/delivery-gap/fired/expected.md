# delivery-gap / fired

Plan Task 2 is a schema migration with **no** `§Rollback plan` recovery row.
Expected: `ff-deliver` writes `delivery.md` (via `artifacts.delivery`) containing a
`⚠ DELIVERY GAP:` line naming Task 2; `phases.deliver.status` = `complete`; `currentPhase` stays `done`.
