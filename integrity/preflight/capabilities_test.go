package preflight

import (
	"bytes"
	"testing"
)

func enforceableReport() CapabilityReport {
	return CapabilityReport{
		SchemaVersion:     SchemaVersion,
		Host:              HostClaude,
		Mode:              EnforcementEnforce,
		KernelVersion:     "1.0.0",
		SchemaVersionName: "manifest-v1",
		Capabilities: []CapabilityState{
			{Name: CapabilityLifecycleHook, State: CapabilityAvailable, Required: true, Evidence: "active trusted invocation"},
			{Name: CapabilityKernel, State: CapabilityAvailable, Required: true, Version: "1.0.0", Evidence: "packaged binary"},
			{Name: CapabilitySchema, State: CapabilityAvailable, Required: true, Version: "manifest-v1", Evidence: "embedded asset"},
		},
		Lifecycle: &LifecycleState{
			Supported:   TruthYes,
			Packaged:    TruthYes,
			Enabled:     TruthYes,
			Trusted:     TruthYes,
			Executable:  TruthYes,
			Enforceable: true,
		},
		Enforceable: true,
	}
}

func TestCapabilityReportTruthTable(t *testing.T) {
	report := enforceableReport()
	if err := report.Validate(); err != nil {
		t.Fatalf("Validate() error = %v", err)
	}

	for _, mutate := range []func(*CapabilityReport){
		func(r *CapabilityReport) { r.Lifecycle.Trusted = TruthUnknown },
		func(r *CapabilityReport) { r.Lifecycle.Enabled = TruthNo },
		func(r *CapabilityReport) { r.Lifecycle.Executable = TruthNo },
		func(r *CapabilityReport) { r.Capabilities[1].State = CapabilityUnavailable },
		func(r *CapabilityReport) { r.Mode = EnforcementObserve },
	} {
		candidate := enforceableReport()
		mutate(&candidate)
		if err := candidate.Validate(); err == nil {
			t.Fatalf("Validate() accepted false enforcement claim: %#v", candidate)
		}
	}
}

func TestEvaluateCapabilitiesDegradesUnknownRequiredState(t *testing.T) {
	report := enforceableReport()
	report.Capabilities[0].State = CapabilityUnknown
	report.Lifecycle.Trusted = TruthUnknown
	report.Lifecycle.Enforceable = false
	report.Enforceable = false

	result := EvaluateCapabilities(report, []CapabilityName{CapabilityLifecycleHook, CapabilityKernel})
	if result.Available {
		t.Fatal("Available = true, want false")
	}
	if len(result.Diagnostics) != 1 || result.Diagnostics[0].Code != "FFI_CAPABILITY_DEGRADED" {
		t.Fatalf("Diagnostics = %#v", result.Diagnostics)
	}
}

func TestMarshalCapabilityReportIsStable(t *testing.T) {
	report := enforceableReport()
	first, err := MarshalCapabilityReport(report)
	if err != nil {
		t.Fatal(err)
	}
	second, err := MarshalCapabilityReport(report)
	if err != nil {
		t.Fatal(err)
	}
	if !bytes.Equal(first, second) {
		t.Fatalf("unstable capability JSON:\n%s\n%s", first, second)
	}
}
