package main

import (
	"bytes"
	"os"
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
