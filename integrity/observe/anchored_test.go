//go:build !windows

package observe

import (
	"bytes"
	"os"
	"path/filepath"
	"testing"
)

func TestReadAnchoredDoesNotFollowRunDirectorySwap(t *testing.T) {
	base := t.TempDir()
	run := filepath.Join(base, "legacy")
	outside := t.TempDir()
	if err := os.Mkdir(run, 0o700); err != nil {
		t.Fatal(err)
	}
	original := []byte(`{"slug":"original"}`)
	external := []byte(`{"slug":"external"}`)
	if err := os.WriteFile(filepath.Join(run, "manifest.json"), original, 0o600); err != nil {
		t.Fatal(err)
	}
	if err := os.WriteFile(filepath.Join(outside, "manifest.json"), external, 0o600); err != nil {
		t.Fatal(err)
	}
	raw, err := readAnchored(base, "legacy", 1024, func() {
		if renameErr := os.Rename(run, run+".parked"); renameErr != nil {
			t.Fatal(renameErr)
		}
		if symlinkErr := os.Symlink(outside, run); symlinkErr != nil {
			t.Fatal(symlinkErr)
		}
	})
	if err != nil {
		t.Fatal(err)
	}
	if !bytes.Equal(raw, original) {
		t.Fatalf("read redirected bytes: %s", raw)
	}
}
