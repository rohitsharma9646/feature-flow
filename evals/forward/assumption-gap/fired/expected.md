# assumption-gap / fired

The spec's Assumption 1 is `validation-required: y` and unvalidated. The user replies with a plain
sign-off that does not validate, waive, or acknowledge it. Expected: the sign-off ask/echo renders a
`### Unvalidated assumptions` block (or equivalent "Unvalidated assumptions" heading) naming it, and
sign-off is **not** recorded: `signOff.signed` stays `false`, the spec still reads `User signed off: no`.
