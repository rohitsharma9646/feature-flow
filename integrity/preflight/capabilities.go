package preflight

import (
	"encoding/json"
	"errors"
	"fmt"
)

type CapabilityAvailability string
type TruthState string

const (
	CapabilityAvailable   CapabilityAvailability = "available"
	CapabilityUnavailable CapabilityAvailability = "unavailable"
	CapabilityUnknown     CapabilityAvailability = "unknown"

	TruthYes     TruthState = "yes"
	TruthNo      TruthState = "no"
	TruthUnknown TruthState = "unknown"
)

type CapabilityState struct {
	Name       CapabilityName         `json:"name"`
	State      CapabilityAvailability `json:"state"`
	Required   bool                   `json:"required"`
	Version    string                 `json:"version,omitempty"`
	Evidence   string                 `json:"evidence"`
	Diagnostic string                 `json:"diagnostic,omitempty"`
}

type LifecycleState struct {
	Supported   TruthState `json:"supported"`
	Packaged    TruthState `json:"packaged"`
	Enabled     TruthState `json:"enabled"`
	Trusted     TruthState `json:"trusted"`
	Executable  TruthState `json:"executable"`
	Enforceable bool       `json:"enforceable"`
}

type CapabilityReport struct {
	SchemaVersion     int               `json:"schemaVersion"`
	Host              Host              `json:"host"`
	Mode              EnforcementMode   `json:"mode"`
	KernelVersion     string            `json:"kernelVersion"`
	SchemaVersionName string            `json:"schemaVersionName"`
	Capabilities      []CapabilityState `json:"capabilities"`
	Lifecycle         *LifecycleState   `json:"lifecycle,omitempty"`
	Enforceable       bool              `json:"enforceable"`
}

type CapabilityEvaluation struct {
	Available   bool
	Diagnostics []Diagnostic
}

func (r CapabilityReport) Validate() error {
	if r.SchemaVersion != SchemaVersion {
		return fmt.Errorf("unsupported capability schemaVersion %d", r.SchemaVersion)
	}
	if !oneOf(string(r.Host), string(HostDirect), string(HostClaude), string(HostCodex)) {
		return errors.New("invalid capability host")
	}
	if !oneOf(string(r.Mode), string(EnforcementEnforce), string(EnforcementObserve)) {
		return errors.New("invalid capability mode")
	}
	if r.KernelVersion == "" || r.SchemaVersionName == "" || len(r.Capabilities) == 0 {
		return errors.New("capability report lacks version or capability evidence")
	}
	seen := make(map[CapabilityName]struct{}, len(r.Capabilities))
	requiredAvailable := true
	for _, capability := range r.Capabilities {
		if !validCapability(capability.Name) {
			return fmt.Errorf("invalid capability %q", capability.Name)
		}
		if !oneOf(string(capability.State),
			string(CapabilityAvailable), string(CapabilityUnavailable), string(CapabilityUnknown)) {
			return fmt.Errorf("invalid state for capability %q", capability.Name)
		}
		if capability.Evidence == "" {
			return fmt.Errorf("capability %q lacks evidence", capability.Name)
		}
		if _, exists := seen[capability.Name]; exists {
			return fmt.Errorf("duplicate capability %q", capability.Name)
		}
		seen[capability.Name] = struct{}{}
		if capability.Required && capability.State != CapabilityAvailable {
			requiredAvailable = false
		}
	}
	lifecycleEnforceable := true
	if r.Lifecycle != nil {
		for name, state := range map[string]TruthState{
			"supported":  r.Lifecycle.Supported,
			"packaged":   r.Lifecycle.Packaged,
			"enabled":    r.Lifecycle.Enabled,
			"trusted":    r.Lifecycle.Trusted,
			"executable": r.Lifecycle.Executable,
		} {
			if !oneOf(string(state), string(TruthYes), string(TruthNo), string(TruthUnknown)) {
				return fmt.Errorf("invalid lifecycle %s state", name)
			}
			if state != TruthYes {
				lifecycleEnforceable = false
			}
		}
		if r.Lifecycle.Enforceable != lifecycleEnforceable {
			return errors.New("lifecycle enforceable claim does not match evidence")
		}
	}
	expectedEnforceable := r.Mode == EnforcementEnforce && requiredAvailable && lifecycleEnforceable
	if r.Enforceable != expectedEnforceable {
		return errors.New("effective enforceable claim does not match capability evidence")
	}
	return nil
}

func EvaluateCapabilities(report CapabilityReport, required []CapabilityName) CapabilityEvaluation {
	states := make(map[CapabilityName]CapabilityAvailability, len(report.Capabilities))
	for _, capability := range report.Capabilities {
		states[capability.Name] = capability.State
	}
	available := report.Enforceable
	for _, name := range required {
		if states[name] != CapabilityAvailable {
			available = false
		}
	}
	if available {
		return CapabilityEvaluation{Available: true}
	}
	return CapabilityEvaluation{
		Diagnostics: []Diagnostic{{Code: "FFI_CAPABILITY_DEGRADED", Severity: SeverityError}},
	}
}

func MarshalCapabilityReport(report CapabilityReport) ([]byte, error) {
	if err := report.Validate(); err != nil {
		return nil, err
	}
	raw, err := json.Marshal(report)
	if err != nil {
		return nil, err
	}
	return append(raw, '\n'), nil
}
