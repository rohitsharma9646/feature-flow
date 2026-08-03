package main

import (
	"bytes"
	"encoding/json"
	"os"
	"os/exec"
	"path/filepath"
	"strings"
	"testing"
	"time"

	"github.com/rohitsharma9646/feature-flow/integrity/assurance"
	"github.com/rohitsharma9646/feature-flow/integrity/classifier"
	"github.com/rohitsharma9646/feature-flow/integrity/preflight"
	"github.com/rohitsharma9646/feature-flow/integrity/revision/gitobserve"
	"github.com/rohitsharma9646/feature-flow/integrity/wp3"
)

func TestCapabilitiesReportsDirectEnforcementAndUnknownLifecycleTrust(t *testing.T) {
	for _, tc := range []struct {
		host        string
		exit        int
		enforceable bool
	}{
		{"direct", 0, true},
		{"claude", 1, false},
		{"codex", 1, false},
	} {
		var stdout, stderr bytes.Buffer
		exit := run([]string{"capabilities", "--host", tc.host, "--format", "json"}, &stdout, &stderr)
		if exit != tc.exit {
			t.Fatalf("%s exit=%d stderr=%s", tc.host, exit, stderr.String())
		}
		var report preflight.CapabilityReport
		if err := json.Unmarshal(stdout.Bytes(), &report); err != nil {
			t.Fatalf("%s decode: %v output=%s", tc.host, err, stdout.String())
		}
		if report.Enforceable != tc.enforceable {
			t.Fatalf("%s enforceable=%v", tc.host, report.Enforceable)
		}
	}
}

func TestPreflightCLIUnrelatedRequestIsSilentAllowDecision(t *testing.T) {
	request := preflight.Request{
		SchemaVersion: preflight.SchemaVersion,
		Host:          preflight.HostDirect,
		Event:         preflight.EventCommandPreflight,
		Operation:     preflight.OperationManifestMutation,
		ToolClass:     preflight.ToolClassFileWrite,
		Target:        "README.md",
		Context: preflight.TrustedContext{
			RepositoryRoot: t.TempDir(),
			RunRoot:        t.TempDir(),
		},
		RequiredCapabilities: []preflight.CapabilityName{
			preflight.CapabilityCommandPreflight,
			preflight.CapabilityKernel,
			preflight.CapabilitySchema,
			preflight.CapabilityJSONOutput,
		},
		EnforcementMode: preflight.EnforcementEnforce,
	}
	raw, _ := json.Marshal(request)
	input := filepath.Join(t.TempDir(), "request.json")
	if err := os.WriteFile(input, raw, 0o600); err != nil {
		t.Fatal(err)
	}
	var stdout, stderr bytes.Buffer
	if exit := run([]string{"preflight", "--input", input, "--format", "json"}, &stdout, &stderr); exit != 0 {
		t.Fatalf("exit=%d stdout=%s stderr=%s", exit, stdout.String(), stderr.String())
	}
	if stdout.String() != "{\"schemaVersion\":1,\"applicable\":false,\"allowed\":true}\n" {
		t.Fatalf("stdout=%q", stdout.String())
	}
}

func TestDoctorAndPreviewDoNotWrite(t *testing.T) {
	root := t.TempDir()
	runDir := filepath.Join(root, "legacy")
	if err := os.Mkdir(runDir, 0o755); err != nil {
		t.Fatal(err)
	}
	raw := []byte(`{"slug":"legacy","track":"feature","tier":"full","autopilot":false,"currentPhase":"implement","phases":{},"signOff":{"required":true,"signed":false,"date":null},"artifacts":{}}`)
	manifest := filepath.Join(runDir, "manifest.json")
	if err := os.WriteFile(manifest, raw, 0o600); err != nil {
		t.Fatal(err)
	}
	before, _ := os.Stat(manifest)
	for _, tc := range []struct {
		args []string
		exit int
	}{
		{[]string{"doctor", "--root", root, "--format", "json", "legacy"}, 1},
		{[]string{"migrate", "--root", root, "--to", "1", "--dry-run", "--format", "json", "legacy"}, 0},
	} {
		var stdout, stderr bytes.Buffer
		if exit := run(tc.args, &stdout, &stderr); exit != tc.exit {
			t.Fatalf("%v exit %d stderr=%s stdout=%s", tc.args, exit, stderr.String(), stdout.String())
		}
	}
	after, _ := os.Stat(manifest)
	if !before.ModTime().Equal(after.ModTime()) {
		t.Fatal("read-only command changed manifest mtime")
	}
	if _, err := os.Stat(filepath.Join(runDir, "migration")); !os.IsNotExist(err) {
		t.Fatal("read-only command created migration directory")
	}
}

func TestApplyRequiresPlanDigest(t *testing.T) {
	var stdout, stderr bytes.Buffer
	exit := run([]string{"migrate", "--to", "1", "--apply", "x"}, &stdout, &stderr)
	if exit != 2 || !strings.Contains(stderr.String(), "--expect-plan") {
		t.Fatalf("exit=%d stderr=%q", exit, stderr.String())
	}
}

func TestBaselineAndObserveDirectOperations(t *testing.T) {
	repository := t.TempDir()
	command := exec.Command("git", "-C", repository, "init", "-q")
	if output, err := command.CombinedOutput(); err != nil {
		t.Fatalf("git init: %v %s", err, output)
	}
	for _, args := range [][]string{
		{"config", "user.email", "test@example.test"},
		{"config", "user.name", "Test"},
	} {
		if output, err := exec.Command("git", append([]string{"-C", repository}, args...)...).CombinedOutput(); err != nil {
			t.Fatalf("git %v: %v %s", args, err, output)
		}
	}
	if err := os.WriteFile(filepath.Join(repository, "owned.txt"), []byte("base"), 0o600); err != nil {
		t.Fatal(err)
	}
	for _, args := range [][]string{{"add", "."}, {"commit", "-qm", "base"}} {
		if output, err := exec.Command("git", append([]string{"-C", repository}, args...)...).CombinedOutput(); err != nil {
			t.Fatalf("git %v: %v %s", args, err, output)
		}
	}
	scope := filepath.Join(t.TempDir(), "scope.json")
	if err := os.WriteFile(scope, []byte(`{"trackedPaths":["owned.txt"],"includedUntrackedPaths":[],"exclusions":[]}`), 0o600); err != nil {
		t.Fatal(err)
	}
	var baselineOut, stderr bytes.Buffer
	if exit := run([]string{"baseline", "--repo", repository, "--input", scope}, &baselineOut, &stderr); exit != 0 {
		t.Fatalf("baseline exit=%d stderr=%s", exit, stderr.String())
	}
	var response struct {
		Baseline json.RawMessage `json:"baseline"`
	}
	if err := json.Unmarshal(baselineOut.Bytes(), &response); err != nil {
		t.Fatal(err)
	}
	baseline := filepath.Join(t.TempDir(), "baseline.json")
	if err := os.WriteFile(baseline, response.Baseline, 0o600); err != nil {
		t.Fatal(err)
	}
	var observed bytes.Buffer
	stderr.Reset()
	if exit := run([]string{"observe", "--repo", repository, "--input", baseline}, &observed, &stderr); exit != 0 ||
		!strings.Contains(observed.String(), `"status": "ready"`) ||
		!strings.Contains(observed.String(), `"ffr1:`) {
		t.Fatalf("observe exit=%d stdout=%s stderr=%s", exit, observed.String(), stderr.String())
	}
}

func TestBaselineAndObserveAuthoritativeRunOperations(t *testing.T) {
	repository := t.TempDir()
	for _, args := range [][]string{
		{"init", "-q"},
		{"config", "user.email", "test@example.test"},
		{"config", "user.name", "Test"},
	} {
		if output, err := exec.Command("git", append([]string{"-C", repository}, args...)...).CombinedOutput(); err != nil {
			t.Fatalf("git %v: %v %s", args, err, output)
		}
	}
	if err := os.WriteFile(filepath.Join(repository, "owned.txt"), []byte("base"), 0o600); err != nil {
		t.Fatal(err)
	}
	for _, args := range [][]string{{"add", "."}, {"commit", "-qm", "base"}} {
		if output, err := exec.Command("git", append([]string{"-C", repository}, args...)...).CombinedOutput(); err != nil {
			t.Fatalf("git %v: %v %s", args, err, output)
		}
	}
	runDir := filepath.Join(t.TempDir(), "run")
	if err := os.Mkdir(runDir, 0o700); err != nil {
		t.Fatal(err)
	}
	manifest, err := os.ReadFile("../../integrity/testdata/manifests/current-feature.json")
	if err != nil {
		t.Fatal(err)
	}
	var initial map[string]any
	if err := json.Unmarshal(manifest, &initial); err != nil {
		t.Fatal(err)
	}
	initial["artifacts"].(map[string]any)["review"] = "review.md"
	initial["artifacts"].(map[string]any)["verify"] = "verify.md"
	initial["artifacts"].(map[string]any)["reviewEvidence"] = "review-evidence.txt"
	initial["artifacts"].(map[string]any)["verificationEvidence"] = "verification-evidence.txt"
	manifest, _ = json.Marshal(initial)
	if err := os.WriteFile(filepath.Join(runDir, "manifest.json"), manifest, 0o600); err != nil {
		t.Fatal(err)
	}
	for name, content := range map[string]string{
		"review.md": "review artifact", "verify.md": "verification artifact",
		"review-evidence.txt": "review evidence", "verification-evidence.txt": "verification evidence",
	} {
		if err := os.WriteFile(filepath.Join(runDir, name), []byte(content), 0o600); err != nil {
			t.Fatal(err)
		}
		if err := os.WriteFile(filepath.Join(repository, name), []byte("repository decoy"), 0o600); err != nil {
			t.Fatal(err)
		}
	}
	scope := filepath.Join(t.TempDir(), "scope.json")
	if err := os.WriteFile(scope, []byte(`{"trackedPaths":["owned.txt"],"includedUntrackedPaths":[],"exclusions":[]}`), 0o600); err != nil {
		t.Fatal(err)
	}
	var stdout, stderr bytes.Buffer
	if exit := run([]string{"baseline", "--repo", repository, "--run", runDir, "--input", scope}, &stdout, &stderr); exit != 0 {
		t.Fatalf("baseline exit=%d stdout=%s stderr=%s", exit, stdout.String(), stderr.String())
	}
	var state map[string]any
	raw, _ := os.ReadFile(filepath.Join(runDir, "manifest.json"))
	if err := json.Unmarshal(raw, &state); err != nil {
		t.Fatal(err)
	}
	artifacts := state["artifacts"].(map[string]any)
	if !strings.HasPrefix(artifacts["revisionBaseline"].(string), "revision/baseline-v1-") {
		t.Fatalf("baseline pointer not registered: %#v", artifacts)
	}
	stdout.Reset()
	stderr.Reset()
	if exit := run([]string{"baseline", "--repo", repository, "--run", runDir, "--input", scope}, &stdout, &stderr); exit != 1 {
		t.Fatalf("repeated baseline should be refused, exit=%d stdout=%s stderr=%s", exit, stdout.String(), stderr.String())
	}
	stdout.Reset()
	stderr.Reset()
	if exit := run([]string{"observe", "--repo", repository, "--run", runDir}, &stdout, &stderr); exit != 0 ||
		!strings.Contains(stdout.String(), `"status": "ready"`) {
		t.Fatalf("observe exit=%d stdout=%s stderr=%s", exit, stdout.String(), stderr.String())
	}
	if err := os.WriteFile(filepath.Join(repository, "owned.txt"), []byte("unbracketed"), 0o600); err != nil {
		t.Fatal(err)
	}
	staleRequest := writeRunAttestationRequest(t, "review", "review-0", nil)
	stdout.Reset()
	stderr.Reset()
	if exit := run([]string{"attest", "--run", runDir, "--repo", repository, "--input", staleRequest}, &stdout, &stderr); exit != 1 {
		t.Fatalf("stale attest should be refused, exit=%d stdout=%s stderr=%s", exit, stdout.String(), stderr.String())
	}
	if err := os.WriteFile(filepath.Join(repository, "owned.txt"), []byte("base"), 0o600); err != nil {
		t.Fatal(err)
	}
	attestationIDs := map[string]string{}
	for _, kind := range []string{"review", "verification"} {
		request := writeRunAttestationRequest(t, kind, kind+"-1", nil)
		stdout.Reset()
		stderr.Reset()
		if exit := run([]string{"attest", "--run", runDir, "--repo", repository, "--input", request}, &stdout, &stderr); exit != 0 {
			current, _ := os.ReadFile(filepath.Join(runDir, "manifest.json"))
			t.Fatalf("%s attest exit=%d stdout=%s stderr=%s classification=%#v manifest=%s", kind, exit, stdout.String(), stderr.String(), classifier.Classify(current), current)
		}
		var recorded struct {
			Attestation struct {
				ID string `json:"attestationId"`
			} `json:"Attestation"`
		}
		if err := json.Unmarshal(stdout.Bytes(), &recorded); err != nil || recorded.Attestation.ID == "" {
			t.Fatalf("decode attestation: %v %s", err, stdout.String())
		}
		attestationIDs[kind] = recorded.Attestation.ID
	}
	stdout.Reset()
	stderr.Reset()
	if exit := run([]string{"converge", "--run", runDir, "--repo", repository, "--propose-done"}, &stdout, &stderr); exit != 0 ||
		!strings.Contains(stdout.String(), `"allowed": false`) {
		t.Fatalf("incomplete run should not converge, exit=%d stdout=%s stderr=%s", exit, stdout.String(), stderr.String())
	}
	raw, _ = os.ReadFile(filepath.Join(runDir, "manifest.json"))
	if err := json.Unmarshal(raw, &state); err != nil {
		t.Fatal(err)
	}
	state["currentPhase"] = "verify"
	state["signOff"].(map[string]any)["signed"] = true
	state["signOff"].(map[string]any)["date"] = "2026-07-24"
	for _, phase := range []string{"explore", "clarify", "design", "plan", "implement", "review", "verify"} {
		artifact := any(nil)
		if phase == "review" {
			artifact = "review.md"
		}
		if phase == "verify" {
			artifact = "verify.md"
		}
		state["phases"].(map[string]any)[phase] = map[string]any{"status": "complete", "artifact": artifact}
	}
	raw, _ = json.Marshal(state)
	if err := os.WriteFile(filepath.Join(runDir, "manifest.json"), raw, 0o600); err != nil {
		t.Fatal(err)
	}
	stdout.Reset()
	stderr.Reset()
	if exit := run([]string{"converge", "--run", runDir, "--repo", repository, "--propose-done"}, &stdout, &stderr); exit != 0 ||
		!strings.Contains(stdout.String(), `"allowed": true`) {
		t.Fatalf("complete run should converge, exit=%d stdout=%s stderr=%s", exit, stdout.String(), stderr.String())
	}
	reviewArtifact := filepath.Join(runDir, "review.md")
	reviewRaw, err := os.ReadFile(reviewArtifact)
	if err != nil {
		t.Fatal(err)
	}
	if err := os.WriteFile(reviewArtifact, []byte("tampered artifact"), 0o600); err != nil {
		t.Fatal(err)
	}
	stdout.Reset()
	stderr.Reset()
	if exit := run([]string{"converge", "--run", runDir, "--repo", repository, "--propose-done"}, &stdout, &stderr); exit != 0 ||
		!strings.Contains(stdout.String(), `"allowed": false`) {
		t.Fatalf("tampered artifact should deny convergence, exit=%d stdout=%s stderr=%s", exit, stdout.String(), stderr.String())
	}
	if err := os.WriteFile(reviewArtifact, reviewRaw, 0o600); err != nil {
		t.Fatal(err)
	}
	raw, _ = os.ReadFile(filepath.Join(runDir, "manifest.json"))
	if err := json.Unmarshal(raw, &state); err != nil {
		t.Fatal(err)
	}
	registry := state["assuranceRegistry"].(map[string]any)["artifacts"].(map[string]any)
	var bundlePath string
	for _, value := range registry {
		bundlePath = value.(map[string]any)["bundle"].(string)
		break
	}
	bundleFile := filepath.Join(runDir, filepath.FromSlash(bundlePath))
	bundleRaw, err := os.ReadFile(bundleFile)
	if err != nil {
		t.Fatal(err)
	}
	if err := os.WriteFile(bundleFile, []byte("tampered"), 0o600); err != nil {
		t.Fatal(err)
	}
	stdout.Reset()
	stderr.Reset()
	if exit := run([]string{"converge", "--run", runDir, "--repo", repository, "--propose-done"}, &stdout, &stderr); exit != 0 ||
		!strings.Contains(stdout.String(), `"allowed": false`) {
		t.Fatalf("tampered evidence should deny convergence, exit=%d stdout=%s stderr=%s", exit, stdout.String(), stderr.String())
	}
	if err := os.WriteFile(bundleFile, bundleRaw, 0o600); err != nil {
		t.Fatal(err)
	}
	if _, err := wp3.RunMutationRun(
		runDir, repository, "implementation_change", gitobserve.DefaultLimits(),
		time.Date(2026, 7, 24, 1, 0, 0, 0, time.UTC),
		func() error {
			return os.WriteFile(filepath.Join(repository, "owned.txt"), []byte("changed"), 0o600)
		},
	); err != nil {
		t.Fatal(err)
	}
	stdout.Reset()
	stderr.Reset()
	if exit := run([]string{"converge", "--run", runDir, "--repo", repository, "--propose-done"}, &stdout, &stderr); exit != 0 ||
		!strings.Contains(stdout.String(), `"allowed": false`) {
		t.Fatalf("stale converge exit=%d stdout=%s stderr=%s", exit, stdout.String(), stderr.String())
	}
	for _, kind := range []string{"review", "verification"} {
		previous := attestationIDs[kind]
		self := writeRunAttestationRequest(t, kind, kind+"-1", &previous)
		stdout.Reset()
		stderr.Reset()
		if exit := run([]string{"attest", "--run", runDir, "--repo", repository, "--input", self}, &stdout, &stderr); exit != 1 {
			t.Fatalf("self-superseding %s attest should fail, exit=%d stdout=%s stderr=%s", kind, exit, stdout.String(), stderr.String())
		}
		request := writeRunAttestationRequest(t, kind, kind+"-2", &previous)
		stdout.Reset()
		stderr.Reset()
		if exit := run([]string{"attest", "--run", runDir, "--repo", repository, "--input", request}, &stdout, &stderr); exit != 0 {
			t.Fatalf("superseding %s attest exit=%d stdout=%s stderr=%s", kind, exit, stdout.String(), stderr.String())
		}
	}
	stdout.Reset()
	stderr.Reset()
	if exit := run([]string{"converge", "--run", runDir, "--repo", repository, "--propose-done"}, &stdout, &stderr); exit != 0 ||
		!strings.Contains(stdout.String(), `"allowed": true`) {
		t.Fatalf("superseded assurances should converge, exit=%d stdout=%s stderr=%s", exit, stdout.String(), stderr.String())
	}
}

func writeRunAttestationRequest(t *testing.T, kind, key string, supersedes *string) string {
	t.Helper()
	request := wp3.RunAttestationRequest{
		Kind: assurance.Kind(kind), Status: assurance.StatusPassed,
		Producer: wp3TestProducer(), RecordedAt: time.Date(2026, 7, 24, 0, 0, 0, 0, time.UTC),
		ArtifactKey: map[string]string{"review": "review", "verification": "verify"}[kind],
		Evidence: []wp3.RunEvidence{{
			ArtifactKey: kind + "Evidence", Kind: "executed-test", Status: "passed",
		}},
		Supersedes: supersedes, SemanticValid: true, IdempotencyKey: key,
	}
	raw, err := json.Marshal(request)
	if err != nil {
		t.Fatal(err)
	}
	path := filepath.Join(t.TempDir(), kind+".json")
	if err := os.WriteFile(path, raw, 0o600); err != nil {
		t.Fatal(err)
	}
	return path
}

func wp3TestProducer() assurance.Producer {
	return assurance.Producer{Kind: "ci", Host: "ci", ID: "test"}
}

func TestHostPreflightObserveReportsDecodeFailureWithoutDenying(t *testing.T) {
	for _, host := range []string{"claude", "codex"} {
		var stdout, stderr bytes.Buffer
		exit := runHostPreflight(
			[]string{"--host", host, "--mode", "observe"},
			strings.NewReader(`{"hook_event_name":"PreToolUse"`),
			&stdout,
			&stderr,
		)
		if exit != 0 || !strings.Contains(stdout.String(), `"systemMessage"`) ||
			!strings.Contains(stdout.String(), "FFI_SCHEMA_INVALID") ||
			strings.Contains(stdout.String(), `"permissionDecision":"deny"`) {
			t.Fatalf("%s exit=%d stdout=%s stderr=%s", host, exit, stdout.String(), stderr.String())
		}
	}
}
