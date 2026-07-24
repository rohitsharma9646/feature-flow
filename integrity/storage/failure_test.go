//go:build !windows

package storage

import (
	"bytes"
	"errors"
	"os"
	"path/filepath"
	"testing"
	"time"

	"github.com/rohitsharma9646/feature-flow/integrity/migration"
)

func TestFailureMatrixPreservesCanonicalSource(t *testing.T) {
	points := []string{
		"after-read", "after-plan", "after-preflight", "before-clock",
		"after-final-validation", "before-mkdir", "before-snapshot", "after-snapshot",
		"before-manifest-temp", "after-manifest-temp", "before-replace",
	}
	raw := []byte(`{"slug":"legacy","track":"feature","tier":"full","autopilot":false,"currentPhase":"implement","phases":{},"signOff":{"required":true,"signed":false,"date":null},"artifacts":{}}`)
	for _, point := range points {
		t.Run(point, func(t *testing.T) {
			run := t.TempDir()
			if err := os.WriteFile(filepath.Join(run, "manifest.json"), raw, 0o600); err != nil {
				t.Fatal(err)
			}
			request := migration.Request{
				Raw: raw, LogicalRunPath: "legacy",
				RepositoryIdentity: filepath.Dir(run), WorktreeIdentity: filepath.Dir(run),
			}
			plan := migration.Plan(request)
			result := Apply(run, request, Options{
				ExpectedPlan: plan.PlanDigest,
				Clock:        fixedClock{time.Date(2026, 7, 23, 0, 0, 0, 0, time.UTC)},
				Failpoint: func(name string) error {
					if name == point {
						return errors.New("injected")
					}
					return nil
				},
			})
			if result.Status != Failed {
				t.Fatalf("status = %s", result.Status)
			}
			current, err := os.ReadFile(filepath.Join(run, "manifest.json"))
			if err != nil || !bytes.Equal(current, raw) {
				t.Fatalf("canonical changed: %v", err)
			}
			entries, err := filepath.Glob(filepath.Join(run, ".manifest-v1-*"))
			if err != nil || len(entries) != 0 {
				t.Fatalf("manifest temp leaked: %v", entries)
			}
		})
	}
}
