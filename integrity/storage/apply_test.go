//go:build !windows

package storage

import (
	"bytes"
	"os"
	"path/filepath"
	"testing"
	"time"

	"github.com/rohitsharma9646/feature-flow/integrity/migration"
)

type fixedClock struct{ value time.Time }

func (f fixedClock) Now() time.Time { return f.value }

func TestApplyIsLosslessAndIdempotent(t *testing.T) {
	run := t.TempDir()
	raw := []byte(`{"slug":"legacy","track":"feature","tier":"full","autopilot":false,"currentPhase":"implement","phases":{},"signOff":{"required":true,"signed":false,"date":null},"artifacts":{}}`)
	manifest := filepath.Join(run, "manifest.json")
	if err := os.WriteFile(manifest, raw, 0o600); err != nil {
		t.Fatal(err)
	}
	request := migration.Request{Raw: raw, LogicalRunPath: "legacy", RepositoryIdentity: filepath.Dir(run), WorktreeIdentity: filepath.Dir(run)}
	plan := migration.Plan(request)
	result := Apply(run, request, Options{
		ExpectedPlan: plan.PlanDigest,
		Clock:        fixedClock{time.Date(2026, 7, 23, 0, 0, 0, 0, time.UTC)},
	})
	if result.Status != Applied {
		t.Fatalf("apply = %#v", result)
	}
	snapshot, err := os.ReadFile(filepath.Join(run, result.Snapshot))
	if err != nil || !bytes.Equal(snapshot, raw) {
		t.Fatalf("snapshot mismatch: %v", err)
	}
	before, _ := os.Stat(manifest)
	second := Apply(run, request, Options{ExpectedPlan: plan.PlanDigest, Clock: fixedClock{time.Now()}})
	after, _ := os.Stat(manifest)
	if second.Status != AlreadyCurrent || !before.ModTime().Equal(after.ModTime()) {
		t.Fatalf("second apply mutated: %#v", second)
	}
}

func TestApplyRequiresReviewedPlanAndTerminalConfirmation(t *testing.T) {
	run := t.TempDir()
	raw := []byte(`{"slug":"legacy","track":"feature","tier":"full","autopilot":false,"currentPhase":"done","phases":{},"signOff":{"required":true,"signed":true,"date":"2026-01-01"},"artifacts":{}}`)
	if err := os.WriteFile(filepath.Join(run, "manifest.json"), raw, 0o600); err != nil {
		t.Fatal(err)
	}
	request := migration.Request{Raw: raw, LogicalRunPath: "legacy", RepositoryIdentity: filepath.Dir(run)}
	plan := migration.Plan(request)
	for _, options := range []Options{
		{ExpectedPlan: "sha256:bad", Clock: fixedClock{time.Now()}},
		{ExpectedPlan: plan.PlanDigest, Clock: fixedClock{time.Now()}},
	} {
		result := Apply(run, request, options)
		if result.Status != Refused {
			t.Fatalf("apply accepted %#v: %#v", options, result)
		}
		current, _ := os.ReadFile(filepath.Join(run, "manifest.json"))
		if !bytes.Equal(current, raw) {
			t.Fatal("refusal changed source")
		}
	}
}

func TestApplyRejectsManifestAndMigrationSymlinks(t *testing.T) {
	raw := []byte(`{"slug":"legacy","track":"feature","currentPhase":"implement"}`)
	for _, target := range []string{"manifest", "migration"} {
		t.Run(target, func(t *testing.T) {
			run := t.TempDir()
			outside := t.TempDir()
			if target == "manifest" {
				external := filepath.Join(outside, "manifest.json")
				if err := os.WriteFile(external, raw, 0o600); err != nil {
					t.Fatal(err)
				}
				if err := os.Symlink(external, filepath.Join(run, "manifest.json")); err != nil {
					t.Fatal(err)
				}
			} else {
				if err := os.WriteFile(filepath.Join(run, "manifest.json"), raw, 0o600); err != nil {
					t.Fatal(err)
				}
				if err := os.Symlink(outside, filepath.Join(run, "migration")); err != nil {
					t.Fatal(err)
				}
			}
			request := migration.Request{Raw: raw, LogicalRunPath: "legacy", RepositoryRoot: filepath.Dir(run)}
			plan := migration.Plan(request)
			result := Apply(run, request, Options{ExpectedPlan: plan.PlanDigest, Clock: fixedClock{time.Now()}})
			if result.Status == Applied {
				t.Fatal("symlink-controlled path was applied")
			}
			entries, err := os.ReadDir(outside)
			if err != nil {
				t.Fatal(err)
			}
			if target == "migration" && len(entries) != 0 {
				t.Fatalf("external directory changed: %v", entries)
			}
		})
	}
}

func TestApplyDoesNotFollowRunDirectorySwap(t *testing.T) {
	parent := t.TempDir()
	run := filepath.Join(parent, "legacy")
	outside := t.TempDir()
	if err := os.Mkdir(run, 0o700); err != nil {
		t.Fatal(err)
	}
	raw := []byte(`{"slug":"legacy","track":"feature","currentPhase":"implement"}`)
	if err := os.WriteFile(filepath.Join(run, "manifest.json"), raw, 0o600); err != nil {
		t.Fatal(err)
	}
	request := migration.Request{
		Raw: raw, LogicalRunPath: "legacy", RepositoryRoot: filepath.Dir(parent), RunRoot: run,
	}
	plan := migration.Plan(request)
	swapped := false
	result := Apply(run, request, Options{
		ExpectedPlan: plan.PlanDigest,
		Clock:        fixedClock{time.Now()},
		Failpoint: func(name string) error {
			if name != "before-mkdir" {
				return nil
			}
			swapped = true
			if err := os.Rename(run, run+".parked"); err != nil {
				return err
			}
			return os.Symlink(outside, run)
		},
	})
	if !swapped {
		t.Fatal("swap failpoint was not reached")
	}
	if result.Status == Applied {
		t.Fatalf("swapped run was applied: %#v", result)
	}
	entries, err := os.ReadDir(outside)
	if err != nil {
		t.Fatal(err)
	}
	if len(entries) != 0 {
		t.Fatalf("outside directory changed after run swap: %v", entries)
	}
}
