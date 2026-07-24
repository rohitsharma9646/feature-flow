package storage

import (
	"crypto/sha256"
	"encoding/hex"
	"encoding/json"
	"errors"
	"os"
	"path/filepath"
	"time"

	"github.com/rohitsharma9646/feature-flow/integrity/classifier"
	"github.com/rohitsharma9646/feature-flow/integrity/diagnostics"
	"github.com/rohitsharma9646/feature-flow/integrity/migration"
	"github.com/rohitsharma9646/feature-flow/integrity/observe"
)

type Status string

const (
	Applied        Status = "applied"
	AlreadyCurrent Status = "already-current"
	Refused        Status = "refused"
	Failed         Status = "failed"
)

type Clock interface {
	Now() time.Time
}

type Options struct {
	ExpectedPlan          string
	ConfirmReopenTerminal bool
	Clock                 Clock
	Failpoint             func(string) error
}

type Result struct {
	Status      Status                   `json:"status"`
	PlanDigest  string                   `json:"planDigest,omitempty"`
	Snapshot    string                   `json:"snapshot,omitempty"`
	Orphan      string                   `json:"orphan,omitempty"`
	Diagnostics []diagnostics.Diagnostic `json:"diagnostics"`
}

func Apply(runDir string, request migration.Request, options Options) Result {
	result := Result{Diagnostics: []diagnostics.Diagnostic{}}
	files, err := openRunFS(runDir)
	if err != nil {
		if errors.Is(err, errUnsafeFilesystem) {
			result.Status = Refused
			result.Diagnostics = []diagnostics.Diagnostic{diagnostics.New("FFI_CAPABILITY_DEGRADED", "")}
			return result
		}
		return failed("FFI_OBSERVATION_FAILED")
	}
	defer files.Close()
	raw, err := files.ReadManifest(classifier.MaxManifestBytes)
	if err != nil {
		return failed("FFI_OBSERVATION_FAILED")
	}
	if err := hit(options, "after-read"); err != nil {
		return failed("FFI_MIGRATION_APPLY_FAILED")
	}
	if classifier.Classify(raw).Classification == classifier.CurrentStructuralValid {
		result.Status = AlreadyCurrent
		return result
	}
	request.Raw = raw
	repositoryRoot := request.RepositoryRoot
	if repositoryRoot == "" {
		repositoryRoot = filepath.Dir(filepath.Dir(runDir))
	}
	runRoot := request.RunRoot
	if runRoot == "" {
		runRoot = runDir
	}
	facts, pointerErr := observePointers(raw, observe.TrustedRoots{
		RepositoryRoot: repositoryRoot, RunRoot: runRoot, DurableRoot: request.DurableRoot,
	})
	if pointerErr != nil {
		result.Status = Refused
		result.Diagnostics = []diagnostics.Diagnostic{diagnostics.New("FFI_MIGRATION_POINTER_DRIFT", "")}
		return result
	}
	request.PointerFacts = facts
	fresh := migration.Plan(request)
	result.PlanDigest = fresh.PlanDigest
	if fresh.Status != migration.StatusReady || options.ExpectedPlan == "" ||
		options.ExpectedPlan != fresh.PlanDigest {
		result.Status = Refused
		result.Diagnostics = []diagnostics.Diagnostic{diagnostics.New("FFI_MIGRATION_PLAN_STALE", "")}
		return result
	}
	if err := hit(options, "after-plan"); err != nil {
		return withFailure(result, "FFI_MIGRATION_APPLY_FAILED")
	}
	if fresh.RequiresTerminalConfirmation && !options.ConfirmReopenTerminal {
		result.Status = Refused
		result.Diagnostics = []diagnostics.Diagnostic{diagnostics.New("FFI_TERMINAL_CONFIRMATION_REQUIRED", "")}
		return result
	}
	if err := hit(options, "after-preflight"); err != nil {
		return failed("FFI_MIGRATION_APPLY_FAILED")
	}
	clock := options.Clock
	if clock == nil {
		clock = wallClock{}
	}
	if err := hit(options, "before-clock"); err != nil {
		return withFailure(result, "FFI_MIGRATION_APPLY_FAILED")
	}
	migratedAt := clock.Now().UTC().Format(time.RFC3339Nano)
	snapshotRel := snapshotName(raw)
	final := clone(fresh.Proposed)
	final["updatedAt"] = migratedAt
	final["migration"] = map[string]any{
		"from": "legacy-unversioned", "to": 1,
		"sourceDigest": fresh.SourceDigest, "sourceSnapshot": snapshotRel,
		"migratorVersion": "ff-integrity-wp2",
		"migratedAt":      migratedAt, "legacyUnknownPointers": fresh.LegacyUnknownPointers,
		"legacyTerminal": fresh.RequiresTerminalConfirmation,
	}
	finalBytes, err := json.MarshalIndent(final, "", "  ")
	if err != nil {
		return failed("FFI_MIGRATION_APPLY_FAILED")
	}
	if classified := classifier.Classify(finalBytes); classified.Classification != classifier.CurrentStructuralValid {
		result.Status = Failed
		result.Diagnostics = diagnostics.Normalize(append(classified.Diagnostics,
			diagnostics.New("FFI_MIGRATION_APPLY_FAILED", "")))
		return result
	}
	finalBytes = append(finalBytes, '\n')
	if err := hit(options, "after-final-validation"); err != nil {
		return failed("FFI_MIGRATION_APPLY_FAILED")
	}
	if err := hit(options, "before-mkdir"); err != nil {
		return withFailure(result, "FFI_MIGRATION_APPLY_FAILED")
	}
	if err := files.ValidateLocation(); err != nil {
		return failed("FFI_ARTIFACT_PATH_ESCAPE")
	}
	if err := files.EnsureMigration(); err != nil {
		return failed("FFI_ARTIFACT_PATH_ESCAPE")
	}
	snapshotBase := filepath.Base(filepath.FromSlash(snapshotRel))
	if err := hit(options, "before-snapshot"); err != nil {
		return withFailure(result, "FFI_MIGRATION_APPLY_FAILED")
	}
	createdSnapshot, err := files.PublishSnapshot(snapshotBase, raw)
	if err != nil {
		if errors.Is(err, errCollision) {
			return failed("FFI_MIGRATION_SNAPSHOT_COLLISION")
		}
		return failed("FFI_MIGRATION_APPLY_FAILED")
	}
	result.Snapshot = snapshotRel
	if err := hit(options, "after-snapshot"); err != nil {
		cleanupSnapshot(&result, files, snapshotBase, createdSnapshot)
		return withFailure(result, "FFI_MIGRATION_APPLY_FAILED")
	}
	if err := hit(options, "before-manifest-temp"); err != nil {
		cleanupSnapshot(&result, files, snapshotBase, createdSnapshot)
		return withFailure(result, "FFI_MIGRATION_APPLY_FAILED")
	}
	temp, err := files.WriteManifestTemp(finalBytes)
	if err != nil {
		cleanupSnapshot(&result, files, snapshotBase, createdSnapshot)
		return withFailure(result, "FFI_MIGRATION_APPLY_FAILED")
	}
	defer files.RemoveManifestTemp(temp)
	if err := hit(options, "after-manifest-temp"); err != nil {
		cleanupSnapshot(&result, files, snapshotBase, createdSnapshot)
		return withFailure(result, "FFI_MIGRATION_APPLY_FAILED")
	}
	if err := files.ValidateLocation(); err != nil {
		cleanupSnapshot(&result, files, snapshotBase, createdSnapshot)
		return withFailure(result, "FFI_ARTIFACT_PATH_ESCAPE")
	}
	if err := hit(options, "before-replace"); err != nil || files.ReplaceManifest(temp) != nil {
		cleanupSnapshot(&result, files, snapshotBase, createdSnapshot)
		return withFailure(result, "FFI_MIGRATION_APPLY_FAILED")
	}
	_ = files.SyncRun()
	result.Status = Applied
	return result
}

type wallClock struct{}

func (wallClock) Now() time.Time { return time.Now() }

func snapshotName(raw []byte) string {
	sum := sha256.Sum256(raw)
	return "migration/manifest-v0-" + hex.EncodeToString(sum[:]) + ".json"
}

var errCollision = errors.New("snapshot collision")

func writeAll(file *os.File, raw []byte) error {
	for len(raw) != 0 {
		n, err := file.Write(raw)
		if err != nil {
			return err
		}
		raw = raw[n:]
	}
	return nil
}

func cleanupSnapshot(result *Result, files runFS, name string, owned bool) {
	if !owned {
		return
	}
	if err := files.RemoveSnapshot(name); err != nil {
		result.Orphan = filepath.ToSlash(filepath.Join("migration", name))
		result.Diagnostics = append(result.Diagnostics, diagnostics.New("FFI_MIGRATION_ORPHAN_SNAPSHOT", ""))
	}
}

func failed(code string) Result {
	return Result{Status: Failed, Diagnostics: []diagnostics.Diagnostic{diagnostics.New(code, "")}}
}

func withFailure(result Result, code string) Result {
	result.Status = Failed
	result.Diagnostics = append(result.Diagnostics, diagnostics.New(code, ""))
	result.Diagnostics = diagnostics.Normalize(result.Diagnostics)
	return result
}

func hit(options Options, name string) error {
	if options.Failpoint == nil {
		return nil
	}
	return options.Failpoint(name)
}

func clone(source map[string]any) map[string]any {
	out := make(map[string]any, len(source))
	for key, value := range source {
		out[key] = value
	}
	return out
}
