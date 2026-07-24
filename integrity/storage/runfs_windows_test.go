//go:build windows

package storage

import (
	"bytes"
	"os"
	"path/filepath"
	"testing"
	"time"

	"github.com/rohitsharma9646/feature-flow/integrity/migration"
)

type windowsFixedClock struct{ value time.Time }

func (f windowsFixedClock) Now() time.Time { return f.value }

func TestWindowsApplyUsesLockedReparseSafeRun(t *testing.T) {
	run := t.TempDir()
	raw := []byte(`{"slug":"legacy","track":"feature","tier":"full","autopilot":false,"currentPhase":"implement","phases":{},"signOff":{"required":true,"signed":false,"date":null},"artifacts":{}}`)
	manifest := filepath.Join(run, "manifest.json")
	if err := os.WriteFile(manifest, raw, 0o600); err != nil {
		t.Fatal(err)
	}
	request := migration.Request{
		Raw: raw, LogicalRunPath: "legacy",
		RepositoryRoot: filepath.Dir(filepath.Dir(run)), RunRoot: run,
		RepositoryIdentity: filepath.Dir(run), WorktreeIdentity: filepath.Dir(run),
	}
	plan := migration.Plan(request)
	result := Apply(run, request, Options{
		ExpectedPlan: plan.PlanDigest,
		Clock:        windowsFixedClock{time.Date(2026, 7, 24, 0, 0, 0, 0, time.UTC)},
	})
	if result.Status != Applied {
		t.Fatalf("apply = %#v", result)
	}
	snapshot, err := os.ReadFile(filepath.Join(run, result.Snapshot))
	if err != nil || !bytes.Equal(snapshot, raw) {
		t.Fatalf("snapshot mismatch: %v", err)
	}
}
