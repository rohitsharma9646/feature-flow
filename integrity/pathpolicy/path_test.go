package pathpolicy

import (
	"os"
	"path/filepath"
	"runtime"
	"testing"
)

func TestResolveRejectsEscapeSyntax(t *testing.T) {
	root := t.TempDir()
	for _, pointer := range []string{"", "../x", "/etc/passwd", `C:\x`, `C:x`, `\\server\share\x`, `\\?\C:\x`} {
		if _, err := Resolve(root, pointer); err == nil {
			t.Errorf("Resolve(%q) succeeded", pointer)
		}
	}
}

func TestResolveContainedAndEquivalent(t *testing.T) {
	root := t.TempDir()
	if err := os.MkdirAll(filepath.Join(root, "docs"), 0o755); err != nil {
		t.Fatal(err)
	}
	if err := os.WriteFile(filepath.Join(root, "docs", "a.md"), []byte("x"), 0o600); err != nil {
		t.Fatal(err)
	}
	a, err := Resolve(root, "docs/a.md")
	if err != nil {
		t.Fatal(err)
	}
	b, err := Resolve(root, `docs\a.md`)
	if err != nil {
		t.Fatal(err)
	}
	if !Equivalent(a, b) {
		t.Fatalf("facts not equivalent: %#v %#v", a, b)
	}
}

func TestResolveRejectsSymlinkEscape(t *testing.T) {
	if runtime.GOOS == "windows" {
		t.Skip("symlink privilege is not guaranteed")
	}
	root := t.TempDir()
	outside := t.TempDir()
	if err := os.Symlink(outside, filepath.Join(root, "escape")); err != nil {
		t.Fatal(err)
	}
	if _, err := Resolve(root, "escape/secret"); err == nil {
		t.Fatal("symlink escape accepted")
	}
}

func TestIdentityChangesWhenTargetChanges(t *testing.T) {
	root := t.TempDir()
	path := filepath.Join(root, "artifact")
	if err := os.WriteFile(path, []byte("one"), 0o600); err != nil {
		t.Fatal(err)
	}
	first, err := Resolve(root, "artifact")
	if err != nil {
		t.Fatal(err)
	}
	if err := os.WriteFile(path, []byte("different-size"), 0o600); err != nil {
		t.Fatal(err)
	}
	second, err := Resolve(root, "artifact")
	if err != nil {
		t.Fatal(err)
	}
	if Equivalent(first, second) || first.Identity == second.Identity {
		t.Fatal("target replacement retained identity")
	}
}
