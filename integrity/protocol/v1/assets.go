package protocolv1

import _ "embed"

// DiagnosticsJSON is the canonical diagnostic catalogue.
//
//go:embed diagnostics.json
var DiagnosticsJSON []byte
