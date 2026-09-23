# delivery-gap / control

Identical run, but Task 2 has a rollback row. Expected: `delivery.md` written with **no**
`⚠ DELIVERY GAP:` line; `phases.deliver.status` = `complete`; `currentPhase` stays `done`.
