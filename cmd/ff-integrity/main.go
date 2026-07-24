package main

import (
	"encoding/json"
	"flag"
	"fmt"
	"io"
	"os"
	"path/filepath"
	"strings"
	"time"

	"github.com/rohitsharma9646/feature-flow/integrity/assurance"
	"github.com/rohitsharma9646/feature-flow/integrity/diagnostics"
	"github.com/rohitsharma9646/feature-flow/integrity/doctor"
	"github.com/rohitsharma9646/feature-flow/integrity/migration"
	"github.com/rohitsharma9646/feature-flow/integrity/observe"
	"github.com/rohitsharma9646/feature-flow/integrity/revision"
	"github.com/rohitsharma9646/feature-flow/integrity/revision/gitobserve"
	"github.com/rohitsharma9646/feature-flow/integrity/storage"
	"github.com/rohitsharma9646/feature-flow/integrity/wp3"
)

const maxRuns = 10000

func main() {
	os.Exit(run(os.Args[1:], os.Stdout, os.Stderr))
}

type writer interface {
	Write([]byte) (int, error)
}

func run(args []string, stdout, stderr writer) int {
	if len(args) == 0 {
		fmt.Fprintln(stderr, "usage: ff-integrity <doctor|migrate|baseline|observe|revision|attest|mutation|scope|converge> ...")
		return 2
	}
	switch args[0] {
	case "doctor":
		return runDoctor(args[1:], stdout, stderr)
	case "migrate":
		return runMigrate(args[1:], stdout, stderr)
	case "revision":
		return runJSONOperation(args[1:], stdout, stderr, computeRevision)
	case "baseline":
		return runRepositoryOperation(args[1:], stdout, stderr, captureBaseline)
	case "observe":
		return runRepositoryOperation(args[1:], stdout, stderr, observeRevision)
	case "attest":
		return runJSONOperation(args[1:], stdout, stderr, recordAttestation)
	case "mutation":
		return runJSONOperation(args[1:], stdout, stderr, reconcileMutation)
	case "scope":
		return runJSONOperation(args[1:], stdout, stderr, reconcileScope)
	case "converge":
		return runJSONOperation(args[1:], stdout, stderr, converge)
	default:
		fmt.Fprintln(stderr, "unknown command")
		return 2
	}
}

func runRepositoryOperation(args []string, stdout, stderr writer, operation func(string, []byte) (any, error)) int {
	flags := flag.NewFlagSet("repository integrity operation", flag.ContinueOnError)
	flags.SetOutput(stderr)
	input := flags.String("input", "", "bounded JSON request file")
	repository := flags.String("repo", "", "trusted Git worktree")
	format := flags.String("format", "json", "human or json")
	if err := flags.Parse(args); err != nil || *input == "" || *repository == "" ||
		(*format != "human" && *format != "json") || len(flags.Args()) != 0 {
		fmt.Fprintln(stderr, "operation requires --repo <worktree> --input <json-file>")
		return 2
	}
	info, err := os.Stat(*input)
	if err != nil || !info.Mode().IsRegular() || info.Size() > classifierLimit() {
		fmt.Fprintln(stderr, "input unavailable or exceeds limit")
		return 2
	}
	raw, err := os.ReadFile(*input)
	if err != nil {
		return 2
	}
	result, err := operation(*repository, raw)
	if err != nil {
		fmt.Fprintln(stderr, err)
		return 1
	}
	if err := renderDirect(stdout, result, *format); err != nil {
		return 2
	}
	return 0
}

func captureBaseline(repository string, raw []byte) (any, error) {
	var scope revision.Scope
	if err := strictUnmarshal(raw, &scope); err != nil {
		return nil, err
	}
	baseline, err := gitobserve.Capture(repository, scope, gitobserve.DefaultLimits())
	if err != nil {
		return nil, err
	}
	return struct {
		Baseline  gitobserve.Baseline `json:"baseline"`
		Canonical json.RawMessage     `json:"canonical"`
	}{
		Baseline: baseline, Canonical: baseline.Canonical,
	}, nil
}

func observeRevision(repository string, raw []byte) (any, error) {
	var baseline gitobserve.Baseline
	if err := strictUnmarshal(raw, &baseline); err != nil {
		return nil, err
	}
	result := gitobserve.Observe(repository, baseline, gitobserve.DefaultLimits())
	if result.Err != nil {
		return struct {
			Status     gitobserve.Status `json:"status"`
			Diagnostic string            `json:"diagnostic"`
			DriftPaths []string          `json:"driftPaths"`
		}{Status: result.Status, Diagnostic: result.Err.Error(), DriftPaths: result.DriftPaths}, nil
	}
	return struct {
		Status   gitobserve.Status `json:"status"`
		Revision revision.Result   `json:"revision"`
	}{Status: result.Status, Revision: result.Revision}, nil
}

func runJSONOperation(args []string, stdout, stderr writer, operation func([]byte) (any, error)) int {
	flags := flag.NewFlagSet("integrity operation", flag.ContinueOnError)
	flags.SetOutput(stderr)
	input := flags.String("input", "", "bounded JSON request file")
	format := flags.String("format", "json", "human or json")
	if err := flags.Parse(args); err != nil || *input == "" ||
		(*format != "human" && *format != "json") || len(flags.Args()) != 0 {
		fmt.Fprintln(stderr, "operation requires --input <json-file>")
		return 2
	}
	info, err := os.Stat(*input)
	if err != nil || !info.Mode().IsRegular() || info.Size() > classifierLimit() {
		fmt.Fprintln(stderr, "input unavailable or exceeds limit")
		return 2
	}
	raw, err := os.ReadFile(*input)
	if err != nil {
		fmt.Fprintln(stderr, "input read failed")
		return 2
	}
	result, err := operation(raw)
	if err != nil {
		fmt.Fprintln(stderr, err)
		return 1
	}
	if err := renderDirect(stdout, result, *format); err != nil {
		fmt.Fprintln(stderr, "output write failed")
		return 2
	}
	return 0
}

func renderDirect(output writer, value any, format string) error {
	var raw []byte
	var err error
	if format == "human" {
		raw, err = json.Marshal(value)
	} else {
		raw, err = json.MarshalIndent(value, "", "  ")
	}
	if err != nil {
		return err
	}
	return writeOutput(output, append(raw, '\n'))
}

func computeRevision(raw []byte) (any, error) {
	var request revision.Descriptor
	if err := strictUnmarshal(raw, &request); err != nil {
		return nil, err
	}
	result, err := revision.Compute(request)
	if err != nil {
		return nil, err
	}
	return struct {
		Status     string          `json:"status"`
		Algorithm  string          `json:"algorithm"`
		ID         string          `json:"id"`
		Descriptor json.RawMessage `json:"descriptor"`
	}{
		Status: result.Status, Algorithm: result.Algorithm, ID: result.ID,
		Descriptor: result.Canonical,
	}, nil
}

func recordAttestation(raw []byte) (any, error) {
	var request struct {
		Existing *assurance.Attestation  `json:"existing"`
		Request  assurance.RecordRequest `json:"request"`
	}
	if err := strictUnmarshal(raw, &request); err != nil {
		return nil, err
	}
	return assurance.Record(request.Existing, request.Request)
}

func reconcileMutation(raw []byte) (any, error) {
	var request struct {
		State      wp3.State `json:"state"`
		Before     string    `json:"before"`
		After      string    `json:"after"`
		Reason     string    `json:"reason"`
		DetectedAt time.Time `json:"detectedAt"`
	}
	if err := strictUnmarshal(raw, &request); err != nil {
		return nil, err
	}
	return wp3.ReconcileMutation(request.State, request.Before, request.After, request.Reason, request.DetectedAt)
}

func reconcileScope(raw []byte) (any, error) {
	var request struct {
		State   wp3.State        `json:"state"`
		Request wp3.ScopeRequest `json:"request"`
	}
	if err := strictUnmarshal(raw, &request); err != nil {
		return nil, err
	}
	return wp3.ReconcileScope(request.State, request.Request)
}

func converge(raw []byte) (any, error) {
	var request assurance.ConvergenceInput
	if err := strictUnmarshal(raw, &request); err != nil {
		return nil, err
	}
	return assurance.Converge(request), nil
}

func strictUnmarshal(raw []byte, output any) error {
	decoder := json.NewDecoder(strings.NewReader(string(raw)))
	decoder.DisallowUnknownFields()
	if err := decoder.Decode(output); err != nil {
		return err
	}
	if err := decoder.Decode(new(any)); err != io.EOF {
		return fmt.Errorf("trailing JSON")
	}
	return nil
}

func runDoctor(args []string, stdout, stderr writer) int {
	flags := flag.NewFlagSet("doctor", flag.ContinueOnError)
	flags.SetOutput(stderr)
	all := flags.Bool("all", false, "inspect every immediate run")
	format := flags.String("format", "human", "human or json")
	root := flags.String("root", ".feature-flow", "trusted run root")
	args = flagsFirst(args, map[string]bool{"--format": true, "--root": true})
	if err := flags.Parse(args); err != nil || (*format != "human" && *format != "json") {
		return 2
	}
	positionals := flags.Args()
	if (*all && len(positionals) != 0) || (!*all && len(positionals) != 1) {
		fmt.Fprintln(stderr, "doctor requires exactly one slug or --all")
		return 2
	}
	var runs []observe.Run
	var err error
	if *all {
		runs, err = observe.All(*root, maxRuns, classifierLimit())
	} else {
		var single observe.Run
		single, err = observe.One(*root, positionals[0], classifierLimit())
		if err != nil {
			single.Slug = positionals[0]
			single.LogicalPath = positionals[0] + "/manifest.json"
			single.ReadError = true
		}
		runs = []observe.Run{single}
	}
	if err != nil && *all {
		fmt.Fprintln(stderr, "run root observation failed")
		return 2
	}
	report := doctor.Diagnose(runs)
	var rendered []byte
	if *format == "json" {
		rendered = doctor.RenderJSON(report)
	} else {
		rendered = doctor.RenderHuman(report)
	}
	if writeOutput(stdout, rendered) != nil {
		fmt.Fprintln(stderr, "output write failed")
		return 2
	}
	return report.ExitCode
}

func runMigrate(args []string, stdout, stderr writer) int {
	flags := flag.NewFlagSet("migrate", flag.ContinueOnError)
	flags.SetOutput(stderr)
	to := flags.Int("to", 0, "target schema version")
	dryRun := flags.Bool("dry-run", false, "preview without writes")
	apply := flags.Bool("apply", false, "apply reviewed migration")
	expect := flags.String("expect-plan", "", "reviewed plan digest")
	confirm := flags.Bool("confirm-reopen-terminal", false, "confirm terminal run reopening")
	format := flags.String("format", "human", "human or json")
	root := flags.String("root", ".feature-flow", "trusted run root")
	args = flagsFirst(args, map[string]bool{
		"--to": true, "--expect-plan": true, "--format": true, "--root": true,
	})
	if err := flags.Parse(args); err != nil || *to != 1 || *dryRun == *apply ||
		(*format != "human" && *format != "json") || len(flags.Args()) != 1 {
		fmt.Fprintln(stderr, "migrate requires <slug> --to 1 and exactly one of --dry-run or --apply")
		return 2
	}
	slug := flags.Args()[0]
	if *apply && *expect == "" {
		fmt.Fprintln(stderr, "--apply requires --expect-plan from a reviewed preview")
		return 2
	}
	run, err := observe.One(*root, slug, classifierLimit())
	if err != nil {
		fmt.Fprintln(stderr, "run observation failed")
		return 2
	}
	request, pointerErr := migrationRequest(run, *root)
	if pointerErr != nil {
		refused := migration.PlanResult{
			SchemaVersion: 1, Status: migration.StatusRefused,
			LegacyUnknownPointers: []string{}, ApplyFinalizers: []migration.Finalizer{},
			Diagnostics: []diagnostics.Diagnostic{
				diagnostics.New("FFI_ARTIFACT_PATH_ESCAPE", "/artifacts"),
			},
		}
		if renderMigration(stdout, refused, *format) != nil {
			return 2
		}
		return 1
	}
	plan := migration.Plan(request)
	if *dryRun {
		if renderMigration(stdout, plan, *format) != nil {
			return 2
		}
		if plan.Status == migration.StatusReady || plan.Status == migration.StatusAlreadyCurrent {
			return 0
		}
		return 1
	}
	result := storage.Apply(filepath.Join(*root, slug), request, storage.Options{
		ExpectedPlan: *expect, ConfirmReopenTerminal: *confirm,
	})
	if renderMigration(stdout, result, *format) != nil {
		return 2
	}
	switch result.Status {
	case storage.Applied, storage.AlreadyCurrent:
		return 0
	case storage.Refused:
		return 1
	default:
		return 2
	}
}

func migrationRequest(run observe.Run, root string) (migration.Request, error) {
	repo, _ := filepath.Abs(filepath.Dir(root))
	worktree := repo
	kind := "non-git"
	if info, err := os.Stat(filepath.Join(repo, ".git")); err == nil && (info.IsDir() || info.Mode().IsRegular()) {
		kind = "git"
	}
	request := migration.Request{
		Raw: run.Manifest, LogicalRunPath: run.Slug, RepositoryKind: kind,
		RepositoryRoot: repo, RunRoot: filepath.Join(root, run.Slug),
		DurableRoot:        configuredDurableRoot(repo),
		RepositoryIdentity: filepath.Clean(repo), WorktreeIdentity: filepath.Clean(worktree),
	}
	facts, err := observe.Pointers(run.Manifest, observe.TrustedRoots{
		RepositoryRoot: request.RepositoryRoot, RunRoot: request.RunRoot, DurableRoot: request.DurableRoot,
	})
	if err != nil {
		return migration.Request{}, err
	}
	request.PointerFacts = facts
	return request, nil
}

func configuredDurableRoot(repositoryRoot string) string {
	raw, err := os.ReadFile(filepath.Join(repositoryRoot, ".feature-flow.json"))
	if err != nil {
		return ""
	}
	var config struct {
		Paths struct {
			Durable string `json:"durable"`
		} `json:"paths"`
	}
	if json.Unmarshal(raw, &config) != nil || config.Paths.Durable == "" {
		return ""
	}
	return filepath.Join(repositoryRoot, filepath.FromSlash(config.Paths.Durable))
}

func renderMigration(output writer, value any, format string) error {
	if format == "json" {
		raw, err := json.MarshalIndent(value, "", "  ")
		if err != nil {
			return err
		}
		return writeOutput(output, append(raw, '\n'))
	}
	raw, err := json.Marshal(value)
	if err != nil {
		return err
	}
	var status struct {
		Status       string `json:"status"`
		PlanDigest   string `json:"planDigest"`
		SourceDigest string `json:"sourceDigest"`
		Diagnostics  []struct {
			Code        string `json:"code"`
			JSONPointer string `json:"jsonPointer"`
			LogicalPath string `json:"logicalPath"`
		} `json:"diagnostics"`
	}
	_ = json.Unmarshal(raw, &status)
	var line strings.Builder
	fmt.Fprintf(&line, "migration: %s", status.Status)
	if status.PlanDigest != "" {
		fmt.Fprintf(&line, " plan=%s", status.PlanDigest)
	}
	if status.SourceDigest != "" {
		fmt.Fprintf(&line, " source=%s", status.SourceDigest)
	}
	line.WriteByte('\n')
	for _, item := range status.Diagnostics {
		fmt.Fprintf(&line, "  %s %s", item.Code, item.JSONPointer)
		if item.LogicalPath != "" {
			fmt.Fprintf(&line, " %s", item.LogicalPath)
		}
		line.WriteByte('\n')
	}
	return writeOutput(output, []byte(line.String()))
}

func classifierLimit() int64 { return 4 << 20 }

func writeOutput(output writer, raw []byte) error {
	for len(raw) != 0 {
		written, err := output.Write(raw)
		if err != nil {
			return err
		}
		if written <= 0 {
			return io.ErrShortWrite
		}
		raw = raw[written:]
	}
	return nil
}

// flagsFirst preserves the documented "command <slug> --flag" shape while
// using flag.FlagSet, which otherwise stops at the first positional argument.
func flagsFirst(args []string, takesValue map[string]bool) []string {
	var flags, positional []string
	for index := 0; index < len(args); index++ {
		arg := args[index]
		if strings.HasPrefix(arg, "-") {
			flags = append(flags, arg)
			name := strings.SplitN(arg, "=", 2)[0]
			if takesValue[name] && !strings.Contains(arg, "=") && index+1 < len(args) {
				index++
				flags = append(flags, args[index])
			}
			continue
		}
		positional = append(positional, arg)
	}
	return append(flags, positional...)
}
