package doctor

import (
	"strings"
	"testing"

	"github.com/rohitsharma9646/feature-flow/integrity/observe"
	"github.com/rohitsharma9646/feature-flow/integrity/preflight"
)

func TestWithCapabilitiesSurfacesDegradedEnforcement(t *testing.T) {
	report := Report{SchemaVersion: 1, Status: "clean", Runs: []RunResult{}}
	capabilities := preflight.CapabilityReport{
		SchemaVersion:     1,
		Host:              preflight.HostCodex,
		Mode:              preflight.EnforcementEnforce,
		KernelVersion:     "1.0.0",
		SchemaVersionName: "manifest-v1",
		Capabilities: []preflight.CapabilityState{
			{Name: preflight.CapabilityLifecycleHook, State: preflight.CapabilityUnknown, Required: true, Evidence: "trust unknown"},
		},
		Lifecycle: &preflight.LifecycleState{
			Supported: preflight.TruthYes, Packaged: preflight.TruthYes,
			Enabled: preflight.TruthUnknown, Trusted: preflight.TruthUnknown,
			Executable: preflight.TruthUnknown, Enforceable: false,
		},
		Enforceable: false,
	}
	report = WithCapabilities(report, capabilities)
	if report.ExitCode != 1 || report.Status != "blocking-integrity" || report.Capabilities == nil {
		t.Fatalf("report = %#v", report)
	}
}

func TestDiagnoseClassificationAndRendererParity(t *testing.T) {
	report := Diagnose([]observe.Run{
		{Slug: "b", LogicalPath: "b/manifest.json", Manifest: []byte(`{`)},
		{Slug: "a", LogicalPath: "a/manifest.json", Manifest: []byte(`{"slug":"a"}`)},
	})
	if report.ExitCode != 1 || report.Runs[0].Slug != "a" {
		t.Fatalf("report = %#v", report)
	}
	human := string(RenderHuman(report))
	jsonOut := string(RenderJSON(report))
	for _, code := range []string{"FFI_INVALID_JSON", "FFI_LEGACY_MIGRATION_REQUIRED"} {
		if !strings.Contains(human, code) || !strings.Contains(jsonOut, code) {
			t.Fatalf("%s missing from renderers", code)
		}
	}
}

func TestObservationFailureExitsTwoWithoutRawError(t *testing.T) {
	report := Diagnose([]observe.Run{{Slug: "x", LogicalPath: "x/manifest.json", ReadError: true}})
	if report.ExitCode != 2 {
		t.Fatalf("exit = %d", report.ExitCode)
	}
	if strings.Contains(string(RenderJSON(report)), "/home/") {
		t.Fatal("absolute path leaked")
	}
}
