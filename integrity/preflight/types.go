// Package preflight defines the host-neutral Feature Flow mutation preflight
// contract. Host lifecycle envelope syntax belongs in host adapters, not here.
package preflight

import (
	"bytes"
	"encoding/json"
	"errors"
	"fmt"
	"io"
	"path"
	"path/filepath"
	"regexp"
	"strings"

	"github.com/rohitsharma9646/feature-flow/integrity/jsonstrict"
)

const (
	SchemaVersion    = 1
	MaxRequestBytes  = 1 << 20
	MaxManifestBytes = 512 << 10
)

type Host string
type Event string
type Operation string
type ToolClass string
type EnforcementMode string
type CapabilityName string
type Severity string

const (
	HostDirect Host = "direct"
	HostClaude Host = "claude"
	HostCodex  Host = "codex"

	EventCommandPreflight Event = "command_preflight"
	EventPreToolUse       Event = "pre_tool_use"

	OperationManifestMutation Operation = "manifest_mutation"
	OperationCodeMutation     Operation = "code_mutation"
	OperationTerminal         Operation = "terminal_transition"
	OperationAssurance        Operation = "assurance_recording"

	ToolClassFileWrite ToolClass = "file_write"
	ToolClassShell     ToolClass = "shell"
	ToolClassCommand   ToolClass = "command"

	EnforcementEnforce EnforcementMode = "enforce"
	EnforcementObserve EnforcementMode = "observe"

	CapabilityLifecycleHook    CapabilityName = "lifecycle_hook"
	CapabilityCommandPreflight CapabilityName = "command_preflight"
	CapabilityKernel           CapabilityName = "kernel"
	CapabilitySchema           CapabilityName = "schema"
	CapabilityGitObservation   CapabilityName = "git_observation"
	CapabilityAtomicReplace    CapabilityName = "atomic_replacement"
	CapabilityJSONOutput       CapabilityName = "json_output"

	SeverityInfo    Severity = "info"
	SeverityWarning Severity = "warning"
	SeverityError   Severity = "error"
)

var diagnosticCodePattern = regexp.MustCompile(`^[A-Z][A-Z0-9_]{2,63}$`)

type TrustedContext struct {
	RepositoryRoot string `json:"repositoryRoot"`
	RunRoot        string `json:"runRoot"`
	DurableRoot    string `json:"durableRoot,omitempty"`
}

type Request struct {
	SchemaVersion        int              `json:"schemaVersion"`
	Host                 Host             `json:"host"`
	Event                Event            `json:"event"`
	Operation            Operation        `json:"operation"`
	ToolClass            ToolClass        `json:"toolClass"`
	Target               string           `json:"target"`
	Context              TrustedContext   `json:"context"`
	CurrentManifest      json.RawMessage  `json:"currentManifest,omitempty"`
	ProposedManifest     json.RawMessage  `json:"proposedManifest,omitempty"`
	ExpectedRevision     string           `json:"expectedRevision,omitempty"`
	RequiredCapabilities []CapabilityName `json:"requiredCapabilities"`
	EnforcementMode      EnforcementMode  `json:"enforcementMode"`
}

type Diagnostic struct {
	Code     string   `json:"code"`
	Severity Severity `json:"severity"`
}

type Decision struct {
	SchemaVersion int               `json:"schemaVersion"`
	Applicable    bool              `json:"applicable"`
	Allowed       bool              `json:"allowed"`
	Diagnostics   []Diagnostic      `json:"diagnostics,omitempty"`
	Capabilities  *CapabilityReport `json:"capabilities,omitempty"`
}

func DecodeRequest(raw []byte) (Request, error) {
	if len(raw) == 0 || len(raw) > MaxRequestBytes {
		return Request{}, fmt.Errorf("preflight request size must be between 1 and %d bytes", MaxRequestBytes)
	}
	if _, err := jsonstrict.Decode(raw); err != nil {
		return Request{}, fmt.Errorf("invalid preflight request: %w", err)
	}
	decoder := json.NewDecoder(bytes.NewReader(raw))
	decoder.DisallowUnknownFields()
	var request Request
	if err := decoder.Decode(&request); err != nil {
		return Request{}, fmt.Errorf("invalid preflight request: %w", err)
	}
	if err := decoder.Decode(new(any)); err != io.EOF {
		return Request{}, errors.New("invalid preflight request: trailing JSON")
	}
	if err := request.Validate(); err != nil {
		return Request{}, err
	}
	return request, nil
}

func (r Request) Validate() error {
	if r.SchemaVersion != SchemaVersion {
		return fmt.Errorf("unsupported preflight request schemaVersion %d", r.SchemaVersion)
	}
	if !oneOf(string(r.Host), string(HostDirect), string(HostClaude), string(HostCodex)) {
		return errors.New("invalid preflight host")
	}
	if !oneOf(string(r.Event), string(EventCommandPreflight), string(EventPreToolUse)) {
		return errors.New("invalid preflight event")
	}
	if !oneOf(string(r.Operation),
		string(OperationManifestMutation), string(OperationCodeMutation),
		string(OperationTerminal), string(OperationAssurance)) {
		return errors.New("invalid preflight operation")
	}
	if !oneOf(string(r.ToolClass), string(ToolClassFileWrite), string(ToolClassShell), string(ToolClassCommand)) {
		return errors.New("invalid preflight toolClass")
	}
	if r.Target == "" || path.IsAbs(r.Target) || filepath.IsAbs(r.Target) ||
		path.Clean(r.Target) != r.Target || r.Target == "." || strings.HasPrefix(r.Target, "../") {
		return errors.New("target must be a canonical repository-relative path")
	}
	if !filepath.IsAbs(r.Context.RepositoryRoot) || !filepath.IsAbs(r.Context.RunRoot) {
		return errors.New("trusted repositoryRoot and runRoot must be absolute")
	}
	if r.Context.DurableRoot != "" && !filepath.IsAbs(r.Context.DurableRoot) {
		return errors.New("trusted durableRoot must be absolute when present")
	}
	if len(r.CurrentManifest) > MaxManifestBytes || len(r.ProposedManifest) > MaxManifestBytes {
		return fmt.Errorf("manifest input exceeds %d bytes", MaxManifestBytes)
	}
	for name, raw := range map[string]json.RawMessage{
		"currentManifest": r.CurrentManifest, "proposedManifest": r.ProposedManifest,
	} {
		if len(raw) != 0 {
			value, err := jsonstrict.Decode(raw)
			if err != nil {
				return fmt.Errorf("%s is invalid JSON: %w", name, err)
			}
			if _, ok := value.(map[string]any); !ok {
				return fmt.Errorf("%s must be a JSON object", name)
			}
		}
	}
	if len(r.RequiredCapabilities) == 0 {
		return errors.New("requiredCapabilities must not be empty")
	}
	seen := make(map[CapabilityName]struct{}, len(r.RequiredCapabilities))
	for _, capability := range r.RequiredCapabilities {
		if !validCapability(capability) {
			return fmt.Errorf("invalid required capability %q", capability)
		}
		if _, exists := seen[capability]; exists {
			return fmt.Errorf("duplicate required capability %q", capability)
		}
		seen[capability] = struct{}{}
	}
	if !oneOf(string(r.EnforcementMode), string(EnforcementEnforce), string(EnforcementObserve)) {
		return errors.New("invalid enforcementMode")
	}
	return nil
}

func (d Decision) Validate() error {
	if d.SchemaVersion != SchemaVersion {
		return fmt.Errorf("unsupported preflight decision schemaVersion %d", d.SchemaVersion)
	}
	if !d.Applicable && !d.Allowed {
		return errors.New("a non-applicable decision must allow the unrelated operation")
	}
	seen := make(map[string]struct{}, len(d.Diagnostics))
	for _, diagnostic := range d.Diagnostics {
		if !diagnosticCodePattern.MatchString(diagnostic.Code) {
			return fmt.Errorf("invalid diagnostic code %q", diagnostic.Code)
		}
		if !oneOf(string(diagnostic.Severity), string(SeverityInfo), string(SeverityWarning), string(SeverityError)) {
			return fmt.Errorf("invalid diagnostic severity %q", diagnostic.Severity)
		}
		if _, exists := seen[diagnostic.Code]; exists {
			return fmt.Errorf("duplicate diagnostic code %q", diagnostic.Code)
		}
		seen[diagnostic.Code] = struct{}{}
	}
	if d.Capabilities != nil {
		if err := d.Capabilities.Validate(); err != nil {
			return fmt.Errorf("invalid capability report: %w", err)
		}
	}
	return nil
}

func MarshalDecision(decision Decision) ([]byte, error) {
	if err := decision.Validate(); err != nil {
		return nil, err
	}
	raw, err := json.Marshal(decision)
	if err != nil {
		return nil, err
	}
	return append(raw, '\n'), nil
}

func validCapability(capability CapabilityName) bool {
	return oneOf(string(capability),
		string(CapabilityLifecycleHook), string(CapabilityCommandPreflight),
		string(CapabilityKernel), string(CapabilitySchema),
		string(CapabilityGitObservation), string(CapabilityAtomicReplace),
		string(CapabilityJSONOutput))
}

func oneOf(value string, allowed ...string) bool {
	for _, candidate := range allowed {
		if value == candidate {
			return true
		}
	}
	return false
}
