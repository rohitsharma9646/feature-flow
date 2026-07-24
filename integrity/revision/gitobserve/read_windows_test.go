//go:build windows

package gitobserve

import (
	"os"
	"path/filepath"
	"testing"

	"golang.org/x/sys/windows"
)

func TestWindowsRelativeHandlesBlockAncestorSwap(t *testing.T) {
	root := t.TempDir()
	parentPath := filepath.Join(root, "dir")
	if err := os.Mkdir(parentPath, 0o700); err != nil {
		t.Fatal(err)
	}
	if err := os.WriteFile(filepath.Join(parentPath, "owned.txt"), []byte("inside"), 0o600); err != nil {
		t.Fatal(err)
	}
	rootHandle, err := openDirectoryNoReparse(root)
	if err != nil {
		t.Fatal(err)
	}
	defer windows.CloseHandle(rootHandle)
	parentHandle, err := openRelativeNoReparse(rootHandle, "dir", true)
	if err != nil {
		t.Fatal(err)
	}
	defer windows.CloseHandle(parentHandle)
	if err := os.Rename(parentPath, filepath.Join(root, "moved")); err == nil {
		t.Fatal("ancestor rename succeeded while the no-delete-share parent handle was held")
	}
	fileHandle, err := openRelativeNoReparse(parentHandle, "owned.txt", false)
	if err != nil {
		t.Fatal(err)
	}
	windows.CloseHandle(fileHandle)
}

func TestWindowsMissingRelativeTargetIsDeletion(t *testing.T) {
	root := t.TempDir()
	kind, mode, content, target, size, err := observeWorktree(root, "missing.txt", 1024)
	if err != nil {
		t.Fatalf("missing target must be represented as a deletion: %v", err)
	}
	if kind != "" || mode != "" || content != nil || target != nil || size != 0 {
		t.Fatalf("unexpected missing-target facts: kind=%q mode=%q content=%v target=%v size=%d",
			kind, mode, content, target, size)
	}
}
