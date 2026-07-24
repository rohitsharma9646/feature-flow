package main

import (
	"encoding/json"
	"flag"
	"fmt"
	"io"
	"os"
	"path/filepath"
	"strings"

	"github.com/rohitsharma9646/feature-flow/integrity/diagnostics"
	"github.com/rohitsharma9646/feature-flow/integrity/doctor"
	"github.com/rohitsharma9646/feature-flow/integrity/migration"
	"github.com/rohitsharma9646/feature-flow/integrity/observe"
	"github.com/rohitsharma9646/feature-flow/integrity/storage"
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
		fmt.Fprintln(stderr, "usage: ff-integrity <doctor|migrate> ...")
		return 2
	}
	switch args[0] {
	case "doctor":
		return runDoctor(args[1:], stdout, stderr)
	case "migrate":
		return runMigrate(args[1:], stdout, stderr)
	default:
		fmt.Fprintln(stderr, "unknown command")
		return 2
	}
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
