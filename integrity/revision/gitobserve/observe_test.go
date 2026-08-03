package gitobserve

import (
	"os"
	"os/exec"
	"path/filepath"
	"strings"
	"testing"

	"github.com/rohitsharma9646/feature-flow/integrity/revision"
)

func TestCaptureAndObserveDetectSecondDirtyChange(t *testing.T) {
	root := t.TempDir()
	git(t, root, "init", "-q")
	git(t, root, "config", "user.email", "test@example.test")
	git(t, root, "config", "user.name", "Test")
	write(t, root, "owned.txt", "base")
	write(t, root, "excluded.txt", "base")
	git(t, root, "add", ".")
	git(t, root, "commit", "-qm", "base")
	write(t, root, "excluded.txt", "dirty-one")

	baseline, err := Capture(root, revision.Scope{
		TrackedPaths: []string{"owned.txt"},
		Exclusions: []revision.Exclusion{{
			Path: "excluded.txt", Reason: "user work",
		}},
	}, DefaultLimits())
	if err != nil {
		t.Fatal(err)
	}
	write(t, root, "excluded.txt", "dirty-two")
	result := Observe(root, baseline, DefaultLimits())
	if result.Status != StatusScopeDrift || len(result.DriftPaths) != 1 ||
		result.DriftPaths[0] != "excluded.txt" {
		t.Fatalf("second dirty change not detected: %#v", result)
	}
}

func TestCaptureAndObserveNoOpIsStable(t *testing.T) {
	root := t.TempDir()
	git(t, root, "init", "-q")
	git(t, root, "config", "user.email", "test@example.test")
	git(t, root, "config", "user.name", "Test")
	write(t, root, "owned.txt", "base")
	git(t, root, "add", ".")
	git(t, root, "commit", "-qm", "base")
	baseline, err := Capture(root, revision.Scope{TrackedPaths: []string{"owned.txt"}}, DefaultLimits())
	if err != nil {
		t.Fatal(err)
	}
	first := Observe(root, baseline, DefaultLimits())
	second := Observe(root, baseline, DefaultLimits())
	if first.Status != StatusReady || second.Status != StatusReady || first.Revision.ID != second.Revision.ID {
		t.Fatalf("no-op was unstable: %#v %#v", first, second)
	}
}

func TestObserveRejectsTamperedBaseline(t *testing.T) {
	root := t.TempDir()
	git(t, root, "init", "-q")
	git(t, root, "config", "user.email", "test@example.test")
	git(t, root, "config", "user.name", "Test")
	write(t, root, "owned.txt", "base")
	git(t, root, "add", ".")
	git(t, root, "commit", "-qm", "base")
	baseline, err := Capture(root, revision.Scope{TrackedPaths: []string{"owned.txt"}}, DefaultLimits())
	if err != nil {
		t.Fatal(err)
	}
	baseline.Facts[0].Mode = "100755"
	if got := Observe(root, baseline, DefaultLimits()); got.Status != StatusUnsupported {
		t.Fatalf("tampered baseline was accepted: %#v", got)
	}
}

func TestStableSnapshotRejectsMidObservationMutation(t *testing.T) {
	root := t.TempDir()
	git(t, root, "init", "-q")
	git(t, root, "config", "user.email", "test@example.test")
	git(t, root, "config", "user.name", "Test")
	write(t, root, "owned.txt", "base")
	git(t, root, "add", ".")
	git(t, root, "commit", "-qm", "base")
	head := strings.TrimSpace(gitOutput(t, root, "rev-parse", "HEAD"))
	if _, err := stableSnapshot(root, head, DefaultLimits(), func() {
		write(t, root, "owned.txt", "changed-between-snapshots")
	}); err == nil {
		t.Fatal("mid-observation mutation was accepted")
	}
}

func TestCaptureRefusesResourceLimitsAndConflictingScope(t *testing.T) {
	root := t.TempDir()
	git(t, root, "init", "-q")
	git(t, root, "config", "user.email", "test@example.test")
	git(t, root, "config", "user.name", "Test")
	write(t, root, "owned.txt", "content")
	git(t, root, "add", ".")
	git(t, root, "commit", "-qm", "base")

	limits := DefaultLimits()
	limits.MaxPaths = 0
	if _, err := Capture(root, revision.Scope{TrackedPaths: []string{"owned.txt"}}, limits); err == nil {
		t.Fatal("path limit was not enforced")
	}
	limits = DefaultLimits()
	limits.MaxFileBytes = 1
	if _, err := Capture(root, revision.Scope{TrackedPaths: []string{"owned.txt"}}, limits); err == nil {
		t.Fatal("file limit was not enforced")
	}
	if _, err := Capture(root, revision.Scope{
		TrackedPaths:           []string{"owned.txt"},
		IncludedUntrackedPaths: []string{"owned.txt"},
	}, DefaultLimits()); err == nil {
		t.Fatal("conflicting scope classes were not refused")
	}
}

func TestRevisionChangesForGitDimensions(t *testing.T) {
	tests := map[string]func(*testing.T, string){
		"worktree-content": func(t *testing.T, root string) {
			write(t, root, "owned.txt", "changed")
		},
		"index-content": func(t *testing.T, root string) {
			write(t, root, "owned.txt", "staged")
			git(t, root, "add", "owned.txt")
			write(t, root, "owned.txt", "worktree")
		},
		"executable-mode": func(t *testing.T, root string) {
			if os.PathSeparator == '\\' {
				t.Skip("Windows worktrees do not expose Unix executable permission changes")
			}
			if err := os.Chmod(filepath.Join(root, "owned.txt"), 0o700); err != nil {
				t.Fatal(err)
			}
		},
		"deletion": func(t *testing.T, root string) {
			if err := os.Remove(filepath.Join(root, "owned.txt")); err != nil {
				t.Fatal(err)
			}
		},
		"rename-delete-add": func(t *testing.T, root string) {
			if err := os.Rename(filepath.Join(root, "owned.txt"), filepath.Join(root, "renamed.txt")); err != nil {
				t.Fatal(err)
			}
			git(t, root, "add", "-A")
		},
	}
	for name, mutate := range tests {
		t.Run(name, func(t *testing.T) {
			root := t.TempDir()
			git(t, root, "init", "-q")
			git(t, root, "config", "user.email", "test@example.test")
			git(t, root, "config", "user.name", "Test")
			write(t, root, "owned.txt", "base")
			git(t, root, "add", ".")
			git(t, root, "commit", "-qm", "base")
			scope := revision.Scope{TrackedPaths: []string{"owned.txt"}}
			if name == "rename-delete-add" {
				scope.TrackedPaths = append(scope.TrackedPaths, "renamed.txt")
			}
			baseline, err := Capture(root, scope, DefaultLimits())
			if err != nil {
				t.Fatal(err)
			}
			before := Observe(root, baseline, DefaultLimits())
			if before.Status != StatusReady {
				t.Fatalf("initial observation: %#v", before)
			}
			mutate(t, root)
			after := Observe(root, baseline, DefaultLimits())
			if after.Status != StatusReady || after.Revision.ID == before.Revision.ID {
				t.Fatalf("dimension did not alter revision: %#v %#v", before, after)
			}
		})
	}
}

func TestUnsupportedConflictAndSparseStatesFailClosed(t *testing.T) {
	if _, err := parseIndex([]byte("100644 aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa 2\tconflict.txt\x00")); err == nil {
		t.Fatal("conflict stage was accepted")
	}
	root := t.TempDir()
	git(t, root, "init", "-q")
	git(t, root, "config", "user.email", "test@example.test")
	git(t, root, "config", "user.name", "Test")
	write(t, root, "owned.txt", "base")
	git(t, root, "add", ".")
	git(t, root, "commit", "-qm", "base")
	git(t, root, "config", "core.sparseCheckout", "true")
	if _, err := Capture(root, revision.Scope{TrackedPaths: []string{"owned.txt"}}, DefaultLimits()); err == nil {
		t.Fatal("sparse checkout capability was accepted")
	}
}

func TestAncestorSymlinkSwapCannotRedirectObservation(t *testing.T) {
	if os.PathSeparator == '\\' {
		t.Skip("Windows reparse behavior is covered by native capability tests")
	}
	root := t.TempDir()
	git(t, root, "init", "-q")
	git(t, root, "config", "user.email", "test@example.test")
	git(t, root, "config", "user.name", "Test")
	if err := os.Mkdir(filepath.Join(root, "dir"), 0o700); err != nil {
		t.Fatal(err)
	}
	write(t, root, "dir/owned.txt", "inside")
	git(t, root, "add", ".")
	git(t, root, "commit", "-qm", "base")
	baseline, err := Capture(root, revision.Scope{TrackedPaths: []string{"dir/owned.txt"}}, DefaultLimits())
	if err != nil {
		t.Fatal(err)
	}
	outside := t.TempDir()
	write(t, outside, "owned.txt", "outside")
	if err := os.RemoveAll(filepath.Join(root, "dir")); err != nil {
		t.Fatal(err)
	}
	if err := os.Symlink(outside, filepath.Join(root, "dir")); err != nil {
		t.Fatal(err)
	}
	got := Observe(root, baseline, DefaultLimits())
	if got.Status != StatusUnsupported {
		t.Fatalf("ancestor swap was observed as supported: %#v", got)
	}
}

func git(t *testing.T, root string, args ...string) {
	t.Helper()
	command := exec.Command("git", append([]string{"-C", root}, args...)...)
	if output, err := command.CombinedOutput(); err != nil {
		t.Fatalf("git %v: %v\n%s", args, err, output)
	}
}

func gitOutput(t *testing.T, root string, args ...string) string {
	t.Helper()
	command := exec.Command("git", append([]string{"-C", root}, args...)...)
	output, err := command.CombinedOutput()
	if err != nil {
		t.Fatalf("git %v: %v\n%s", args, err, output)
	}
	return string(output)
}

func write(t *testing.T, root, name, value string) {
	t.Helper()
	if err := os.WriteFile(filepath.Join(root, name), []byte(value), 0o600); err != nil {
		t.Fatal(err)
	}
}
