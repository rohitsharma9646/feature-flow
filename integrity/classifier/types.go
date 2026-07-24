package classifier

import "github.com/rohitsharma9646/feature-flow/integrity/diagnostics"

type ManifestClass string

const (
	CurrentStructuralValid   ManifestClass = "CURRENT_STRUCTURAL_VALID"
	LegacyUnversioned        ManifestClass = "LEGACY_UNVERSIONED"
	UnsupportedFuture        ManifestClass = "UNSUPPORTED_FUTURE"
	Corrupt                  ManifestClass = "CORRUPT"
	CurrentStructuralInvalid ManifestClass = "CURRENT_STRUCTURAL_INVALID"
	UnsupportedOld           ManifestClass = "UNSUPPORTED_OLD"
)

type Diagnostic = diagnostics.Diagnostic

type Result struct {
	ProtocolVersion int           `json:"protocolVersion"`
	Classification  ManifestClass `json:"classification"`
	Diagnostics     []Diagnostic  `json:"diagnostics"`
}
