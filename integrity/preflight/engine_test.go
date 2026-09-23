package preflight

import (
	"bytes"
	"errors"
	"testing"
)

func TestEngineUnrelatedEventDoesNotObserveCapabilitiesOrAuthority(t *testing.T) {
	request := validRequest()
	request.Target = "docs/manifest.json"
	capabilityCalls, authorityCalls := 0, 0
	engine := Engine{
		Capabilities: func(Request) (CapabilityReport, error) {
			capabilityCalls++
			return enforceableReport(), nil
		},
		Authority: func(Request) ([]string, error) {
			authorityCalls++
			return nil, nil
		},
	}
	decision := engine.Decide(request)
	if decision.Applicable || !decision.Allowed {
		t.Fatalf("decision = %#v, want unrelated allow", decision)
	}
	if capabilityCalls != 0 || authorityCalls != 0 {
		t.Fatalf("observation occurred: capability=%d authority=%d", capabilityCalls, authorityCalls)
	}
}

func TestEngineFailsClosedForDegradedRecognizedMutation(t *testing.T) {
	request := validRequest()
	report := enforceableReport()
	report.Capabilities[1].State = CapabilityUnavailable
	report.Enforceable = false
	engine := Engine{
		Capabilities: func(Request) (CapabilityReport, error) { return report, nil },
		Authority:    func(Request) ([]string, error) { t.Fatal("authority called under degradation"); return nil, nil },
	}
	decision := engine.Decide(request)
	if !decision.Applicable || decision.Allowed {
		t.Fatalf("decision = %#v, want applicable deny", decision)
	}
	if got := diagnosticCodes(decision.Diagnostics); len(got) != 1 || got[0] != "FFI_CAPABILITY_DEGRADED" {
		t.Fatalf("diagnostics = %v", got)
	}
}

func TestEngineObserveModeIsVisiblyDegradedButDoesNotBlock(t *testing.T) {
	request := validRequest()
	request.EnforcementMode = EnforcementObserve
	report := enforceableReport()
	report.Mode = EnforcementObserve
	report.Enforceable = false
	engine := Engine{
		Capabilities: func(Request) (CapabilityReport, error) { return report, nil },
		Authority:    func(Request) ([]string, error) { return []string{"FFI_SCHEMA_INVALID"}, nil },
	}
	decision := engine.Decide(request)
	if !decision.Applicable || !decision.Allowed {
		t.Fatalf("decision = %#v, want applicable observe allow", decision)
	}
	if got := diagnosticCodes(decision.Diagnostics); len(got) != 2 ||
		got[0] != "FFI_CAPABILITY_DEGRADED" || got[1] != "FFI_SCHEMA_INVALID" {
		t.Fatalf("diagnostics = %v", got)
	}
	if decision.Capabilities == nil || decision.Capabilities.Enforceable {
		t.Fatalf("capabilities = %#v", decision.Capabilities)
	}
}

func TestEngineObserveModeReportsAuthorityDenialWithoutBlocking(t *testing.T) {
	request := validRequest()
	request.EnforcementMode = EnforcementObserve
	report := enforceableReport()
	report.Mode = EnforcementObserve
	report.Enforceable = false
	engine := Engine{
		Capabilities: func(Request) (CapabilityReport, error) { return report, nil },
		Authority: func(Request) ([]string, error) {
			return []string{"FFI_REVISION_MISMATCH"}, nil
		},
	}
	decision := engine.Decide(request)
	if !decision.Applicable || !decision.Allowed {
		t.Fatalf("decision = %#v, want applicable observe allow", decision)
	}
	if got := diagnosticCodes(decision.Diagnostics); len(got) != 2 ||
		got[0] != "FFI_CAPABILITY_DEGRADED" || got[1] != "FFI_REVISION_MISMATCH" {
		t.Fatalf("diagnostics = %v", got)
	}
}

func TestEngineNormalizesAuthorityDiagnosticsAndIsByteStable(t *testing.T) {
	request := validRequest()
	report := enforceableReport()
	report.Host = HostDirect
	report.Lifecycle = nil
	report.Capabilities[0] = CapabilityState{
		Name: CapabilityCommandPreflight, State: CapabilityAvailable, Required: true,
		Evidence: "direct command",
	}
	engine := Engine{
		Capabilities: func(Request) (CapabilityReport, error) { return report, nil },
		Authority: func(Request) ([]string, error) {
			return []string{"FFI_REVISION_MISMATCH", "FFI_ATTESTATION_STALE", "FFI_REVISION_MISMATCH"}, nil
		},
	}
	first := engine.Decide(request)
	second := engine.Decide(request)
	if first.Allowed {
		t.Fatal("Allowed = true, want deny")
	}
	if got := diagnosticCodes(first.Diagnostics); len(got) != 2 ||
		got[0] != "FFI_ATTESTATION_STALE" || got[1] != "FFI_REVISION_MISMATCH" {
		t.Fatalf("diagnostics = %v", got)
	}
	firstRaw, _ := MarshalDecision(first)
	secondRaw, _ := MarshalDecision(second)
	if !bytes.Equal(firstRaw, secondRaw) {
		t.Fatalf("unstable decisions:\n%s\n%s", firstRaw, secondRaw)
	}
}

func TestEngineMapsIndeterminateAuthorityToStableDenial(t *testing.T) {
	request := validRequest()
	report := enforceableReport()
	report.Host = HostDirect
	report.Lifecycle = nil
	report.Capabilities[0] = CapabilityState{
		Name: CapabilityCommandPreflight, State: CapabilityAvailable, Required: true,
		Evidence: "direct command",
	}
	engine := Engine{
		Capabilities: func(Request) (CapabilityReport, error) { return report, nil },
		Authority:    func(Request) ([]string, error) { return nil, errors.New("unsafe raw detail") },
	}
	decision := engine.Decide(request)
	if decision.Allowed || diagnosticCodes(decision.Diagnostics)[0] != "FFI_OBSERVATION_FAILED" {
		t.Fatalf("decision = %#v", decision)
	}
}

func TestApplicableUsesDecodedTargetNotManifestText(t *testing.T) {
	request := validRequest()
	request.Target = "notes/example.txt"
	request.ProposedManifest = []byte(`{"text":".feature-flow/x/manifest.json"}`)
	if Applicable(request) {
		t.Fatal("Applicable() = true for unrelated decoded target")
	}
	request.Target = ".feature-flow/x/manifest.json"
	if !Applicable(request) {
		t.Fatal("Applicable() = false for canonical manifest target")
	}
	request.Operation = OperationCodeMutation
	request.Target = "internal/service.go"
	if !Applicable(request) {
		t.Fatal("Applicable() = false for declared code-mutation boundary")
	}
}

func diagnosticCodes(diagnostics []Diagnostic) []string {
	out := make([]string, len(diagnostics))
	for i, diagnostic := range diagnostics {
		out[i] = diagnostic.Code
	}
	return out
}

func TestEngineObserveModeDoesNotBlockInvalidRequest(t *testing.T) {
	request := validRequest()
	request.EnforcementMode = EnforcementObserve
	request.ProposedManifest = []byte(`[]`)
	engine := Engine{
		Capabilities: func(Request) (CapabilityReport, error) { return enforceableReport(), nil },
		Authority:    func(Request) ([]string, error) { return nil, nil },
	}
	decision := engine.Decide(request)
	if !decision.Applicable || !decision.Allowed {
		t.Fatalf("decision = %#v, want observe allow", decision)
	}
	if got := diagnosticCodes(decision.Diagnostics); len(got) != 1 || got[0] != "FFI_SCHEMA_INVALID" {
		t.Fatalf("diagnostics = %v", got)
	}
	request.EnforcementMode = EnforcementEnforce
	if decision := engine.Decide(request); decision.Allowed {
		t.Fatalf("enforce decision = %#v, want deny", decision)
	}
}
