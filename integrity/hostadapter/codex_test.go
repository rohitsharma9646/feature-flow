package hostadapter

import (
	"encoding/json"
	"fmt"
	"os"
	"path/filepath"
	"strings"
	"testing"

	"github.com/rohitsharma9646/feature-flow/integrity/preflight"
)

func TestWP4HostDecisionParity(t *testing.T) {
	repository := t.TempDir()
	runRoot := filepath.Join(repository, ".feature-flow", "run")
	if err := os.MkdirAll(runRoot, 0o700); err != nil {
		t.Fatal(err)
	}
	current, err := os.ReadFile("../testdata/manifests/current-feature.json")
	if err != nil {
		t.Fatal(err)
	}
	if err := os.WriteFile(filepath.Join(runRoot, "manifest.json"), current, 0o600); err != nil {
		t.Fatal(err)
	}
	var document map[string]any
	if err := json.Unmarshal(current, &document); err != nil {
		t.Fatal(err)
	}
	document["currentPhase"] = "implement"
	document["phases"].(map[string]any)["implement"] =
		map[string]any{"status": "in_progress", "artifact": nil}
	proposed, _ := json.Marshal(document)

	direct := preflight.Request{
		SchemaVersion: preflight.SchemaVersion,
		Host:          preflight.HostDirect,
		Event:         preflight.EventCommandPreflight,
		Operation:     preflight.OperationManifestMutation,
		ToolClass:     preflight.ToolClassFileWrite,
		Target:        ".feature-flow/run/manifest.json",
		Context: preflight.TrustedContext{
			RepositoryRoot: repository, RunRoot: runRoot,
		},
		ProposedManifest: proposed,
		RequiredCapabilities: []preflight.CapabilityName{
			preflight.CapabilityCommandPreflight, preflight.CapabilityKernel,
			preflight.CapabilitySchema, preflight.CapabilityJSONOutput,
		},
		EnforcementMode: preflight.EnforcementEnforce,
	}
	claudeRaw := []byte(`{"hook_event_name":"PreToolUse","cwd":` + quote(repository) +
		`,"tool_name":"Write","tool_input":{"file_path":` +
		quote(filepath.Join(runRoot, "manifest.json")) + `,"content":` + quote(string(proposed)) + `}}`)
	claude, err := DecodeClaude(claudeRaw)
	if err != nil {
		t.Fatal(err)
	}
	patch := "*** Begin Patch\n*** Update File: .feature-flow/run/manifest.json\n@@\n-" +
		strings.TrimSuffix(string(current), "\n") + "\n+" + string(proposed) + "\n*** End Patch\n"
	codexRaw := []byte(`{"hook_event_name":"PreToolUse","cwd":` + quote(repository) +
		`,"tool_name":"apply_patch","tool_input":{"command":` + quote(patch) + `}}`)
	codex, err := DecodeCodex(codexRaw)
	if err != nil {
		t.Fatal(err)
	}

	var projections []string
	for _, request := range []preflight.Request{direct, claude.Request, codex.Request} {
		engine := preflight.Engine{
			Capabilities: func(current preflight.Request) (preflight.CapabilityReport, error) {
				return testCapabilityReport(current), nil
			},
			Authority: preflight.RuntimeAuthority,
		}
		decision := engine.Decide(request)
		projections = append(projections, projection(decision))
	}
	if projections[0] != projections[1] || projections[0] != projections[2] {
		t.Fatalf("decision drift: %#v", projections)
	}
	if projections[0] != "true|false|FFI_TERMINAL_INCONSISTENT" {
		t.Fatalf("unexpected projection %q", projections[0])
	}
}

func TestDecodeCodexApplyPatchReconstructsProposedManifest(t *testing.T) {
	repository := t.TempDir()
	runRoot := filepath.Join(repository, ".feature-flow", "run")
	if err := os.MkdirAll(runRoot, 0o700); err != nil {
		t.Fatal(err)
	}
	current := "{\n  \"schemaVersion\": 1,\n  \"currentPhase\": \"plan\"\n}\n"
	if err := os.WriteFile(filepath.Join(runRoot, "manifest.json"), []byte(current), 0o600); err != nil {
		t.Fatal(err)
	}
	patch := "*** Begin Patch\n*** Update File: .feature-flow/run/manifest.json\n@@\n-  \"currentPhase\": \"plan\"\n+  \"currentPhase\": \"implement\"\n*** End Patch\n"
	raw := []byte(`{"hook_event_name":"PreToolUse","cwd":` + quote(repository) +
		`,"tool_name":"apply_patch","tool_input":{"command":` + quote(patch) + `}}`)
	decoded, err := DecodeCodex(raw)
	if err != nil {
		t.Fatal(err)
	}
	if !decoded.Recognized || decoded.Request.Host != preflight.HostCodex {
		t.Fatalf("decoded = %#v", decoded)
	}
	if !strings.Contains(string(decoded.Request.ProposedManifest), `"currentPhase": "implement"`) {
		t.Fatalf("proposed = %s", decoded.Request.ProposedManifest)
	}
}

func TestDecodeCodexUnrelatedPatchIsSilentWithoutReadingTarget(t *testing.T) {
	repository := t.TempDir()
	patch := "*** Begin Patch\n*** Update File: missing.txt\n@@\n-old\n+.feature-flow/run/manifest.json\n*** End Patch\n"
	raw := []byte(`{"hook_event_name":"PreToolUse","cwd":` + quote(repository) +
		`,"tool_name":"apply_patch","tool_input":{"command":` + quote(patch) + `}}`)
	decoded, err := DecodeCodex(raw)
	if err != nil {
		t.Fatal(err)
	}
	if decoded.Recognized {
		t.Fatalf("decoded = %#v", decoded)
	}
}

func TestEncodeCodexUsesSupportedDenyShape(t *testing.T) {
	raw, err := EncodeCodex(preflight.Decision{
		SchemaVersion: 1, Applicable: true, Allowed: false,
		Diagnostics: []preflight.Diagnostic{
			{Code: "FFI_SCHEMA_INVALID", Severity: preflight.SeverityError},
		},
	})
	if err != nil {
		t.Fatal(err)
	}
	if !strings.Contains(string(raw), `"hookEventName":"PreToolUse"`) ||
		!strings.Contains(string(raw), `"permissionDecision":"deny"`) {
		t.Fatalf("response = %s", raw)
	}
}

func testCapabilityReport(request preflight.Request) preflight.CapabilityReport {
	capabilities := make([]preflight.CapabilityState, 0, len(request.RequiredCapabilities))
	for _, name := range request.RequiredCapabilities {
		capabilities = append(capabilities, preflight.CapabilityState{
			Name: name, State: preflight.CapabilityAvailable, Required: true, Evidence: "test",
		})
	}
	report := preflight.CapabilityReport{
		SchemaVersion: 1, Host: request.Host, Mode: preflight.EnforcementEnforce,
		KernelVersion: "test", SchemaVersionName: "manifest-v1",
		Capabilities: capabilities, Enforceable: true,
	}
	if request.Host != preflight.HostDirect {
		report.Lifecycle = &preflight.LifecycleState{
			Supported: preflight.TruthYes, Packaged: preflight.TruthYes,
			Enabled: preflight.TruthYes, Trusted: preflight.TruthYes,
			Executable: preflight.TruthYes, Enforceable: true,
		}
	}
	return report
}

func projection(decision preflight.Decision) string {
	codes := make([]string, len(decision.Diagnostics))
	for i, diagnostic := range decision.Diagnostics {
		codes[i] = diagnostic.Code
	}
	return fmt.Sprintf("%t|%t|%s", decision.Applicable, decision.Allowed, strings.Join(codes, ","))
}
