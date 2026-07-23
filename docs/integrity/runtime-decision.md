# Runtime decision: Go 1.26 for Integrity Protocol v1

**Date:** 2026-07-23
**Status:** accepted for WP1 implementation

## Decision

Use Go 1.26 with `github.com/santhosh-tekuri/jsonschema/v6` v6.0.2 to build one pure,
read-only classifier and separate native packages for each declared target.

## Comparison

| Runtime | External prerequisite | Offline native package | Draft 2020-12 | Burden | Decision |
|---------|-----------------------|------------------------|---------------|--------|----------|
| Bash + `jq` | yes | no | unsuitable | low | rejected |
| Node | yes unless bundled | possible but large | strong | high | rejected |
| Python | yes unless bundled | possible but large | strong | high | rejected |
| Go | no | direct native executable | pinned pure-Go library | medium | chosen |
| Rust | no | direct native executable | library-dependent | high | rejected |

## Evidence and pins

- Go 1.26.5 is the current stable security/bug-fix release used for the implementation spike.
- The Linux x86-64 toolchain matched official SHA-256
  `5c2c3b16caefa1d968a94c1daca04a7ca301a496d9b086e17ad77bb81393f053`.
- `jsonschema/v6` v6.0.2 supports draft 2020-12, exact JSON numbers, and introspectable errors.
- `go.mod` and `go.sum` pin inputs; releases also produce inventory, checksums, and provenance.

## Distribution

Build one executable per declared target. Claude and Codex package layouts receive the same binary
and canonical assets. No installation-time download is allowed. Native target execution and
package-content parity are WP1; installed-host adapter activation is WP4.

## Security and operations

- Stdin-only classifier; no filename or write API.
- Public diagnostics are catalogue-owned, never validator-native.
- WP1 records unsigned native execution explicitly. Marketplace signing, notarization, and
  reputation behavior are installed-host release concerns owned by WP4.
- Every toolchain or dependency upgrade replays byte-golden vectors.

## Reopen conditions

Reopen WP1 if the validator fails conformance, a declared target cannot execute, or package layouts
cannot preserve assets. WP4 must reopen release readiness if signing or installed-host offline
distribution is infeasible.
