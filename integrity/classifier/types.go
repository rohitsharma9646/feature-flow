package classifier

type ManifestClass string

const (
	CurrentStructuralValid   ManifestClass = "CURRENT_STRUCTURAL_VALID"
	LegacyUnversioned        ManifestClass = "LEGACY_UNVERSIONED"
	UnsupportedFuture        ManifestClass = "UNSUPPORTED_FUTURE"
	Corrupt                  ManifestClass = "CORRUPT"
	CurrentStructuralInvalid ManifestClass = "CURRENT_STRUCTURAL_INVALID"
	UnsupportedOld           ManifestClass = "UNSUPPORTED_OLD"
)

type Diagnostic struct {
	Code        string `json:"code"`
	Severity    string `json:"severity"`
	JSONPointer string `json:"jsonPointer,omitempty"`
	Message     string `json:"message"`
	Remediation string `json:"remediation"`
}

type Result struct {
	ProtocolVersion int           `json:"protocolVersion"`
	Classification  ManifestClass `json:"classification"`
	Diagnostics     []Diagnostic  `json:"diagnostics"`
}
