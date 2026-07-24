//go:build windows

package observe

import (
	"bytes"
	"os"
	"path/filepath"
	"testing"
)

func TestWindowsReadAnchoredReadsRegularManifest(t *testing.T) {
	base := t.TempDir()
	run := filepath.Join(base, "legacy")
	if err := os.Mkdir(run, 0o700); err != nil {
		t.Fatal(err)
	}
	want := []byte(`{"slug":"legacy"}`)
	if err := os.WriteFile(filepath.Join(run, "manifest.json"), want, 0o600); err != nil {
		t.Fatal(err)
	}
	got, err := readAnchored(base, "legacy", 1024, nil)
	if err != nil {
		t.Fatal(err)
	}
	if !bytes.Equal(got, want) {
		t.Fatalf("got %q, want %q", got, want)
	}
}
