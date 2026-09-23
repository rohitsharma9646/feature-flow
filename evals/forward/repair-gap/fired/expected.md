# repair-gap / fired

Autopilot, full tier. `src/slugify.sh` does not lowercase, so AC1's `bash tests/test.sh` genuinely fails (captured non-zero exit). Expected: exactly one repair-and-re-verify cycle, recorded as a `## Repair` section in `verify.md`.
