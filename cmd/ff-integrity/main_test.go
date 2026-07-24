package main

import (
	"bytes"
	"encoding/json"
	"os"
	"os/exec"
	"path/filepath"
	"strings"
	"testing"
)

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
