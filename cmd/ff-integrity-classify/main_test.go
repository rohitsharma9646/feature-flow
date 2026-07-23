package main

import (
	"bytes"
	"os"
	"path/filepath"
	"strings"
	"testing"
)

func TestRunReadsStdinOnly(t *testing.T) {
	temp := t.TempDir()
	before, err := os.ReadDir(temp)
	if err != nil {
		t.Fatal(err)
	}
	var stdout, stderr bytes.Buffer
	if code := run(strings.NewReader(`{"schemaVersion":2}`), &stdout, &stderr, nil); code != 0 {
		t.Fatalf("exit=%d stderr=%s", code, stderr.String())
	}
	if !strings.Contains(stdout.String(), `"UNSUPPORTED_FUTURE"`) || stderr.Len() != 0 {
		t.Fatalf("stdout=%s stderr=%s", stdout.String(), stderr.String())
	}
	after, err := os.ReadDir(temp)
	if err != nil {
		t.Fatal(err)
	}
	if len(before) != len(after) {
		t.Fatalf("CLI wrote under %s", filepath.Clean(temp))
	}
}

func TestRunRejectsArguments(t *testing.T) {
	var stdout, stderr bytes.Buffer
	if code := run(strings.NewReader(`{}`), &stdout, &stderr, []string{"manifest.json"}); code != 2 {
		t.Fatalf("exit=%d", code)
	}
	if stdout.Len() != 0 || !strings.Contains(stderr.String(), "stdin only") {
		t.Fatalf("stdout=%s stderr=%s", stdout.String(), stderr.String())
	}
}
