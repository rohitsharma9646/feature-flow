package doctor

import (
	"encoding/json"
	"fmt"
	"sort"
	"strings"

	"github.com/rohitsharma9646/feature-flow/integrity/classifier"
	"github.com/rohitsharma9646/feature-flow/integrity/diagnostics"
	"github.com/rohitsharma9646/feature-flow/integrity/jsonstrict"
	"github.com/rohitsharma9646/feature-flow/integrity/migration"
	"github.com/rohitsharma9646/feature-flow/integrity/observe"
)

type RunResult struct {
	Slug              string                   `json:"slug"`
	LogicalPath       string                   `json:"logicalPath"`
	Classification    classifier.ManifestClass `json:"classification,omitempty"`
	MigrationStatus   migration.Status         `json:"migrationStatus,omitempty"`
	Diagnostics       []diagnostics.Diagnostic `json:"diagnostics"`
	ObservationFailed bool                     `json:"observationFailed,omitempty"`
}

type Report struct {
	SchemaVersion int         `json:"schemaVersion"`
	Status        string      `json:"status"`
	ExitCode      int         `json:"exitCode"`
	Runs          []RunResult `json:"runs"`
}

func Diagnose(runs []observe.Run) Report {
	sort.Slice(runs, func(i, j int) bool { return runs[i].Slug < runs[j].Slug })
	report := Report{SchemaVersion: 1, Status: "clean", Runs: make([]RunResult, 0, len(runs))}
	for _, run := range runs {
		item := RunResult{
			Slug: run.Slug, LogicalPath: run.LogicalPath,
			Diagnostics: []diagnostics.Diagnostic{},
		}
		if run.ReadError {
			item.ObservationFailed = true
			item.Diagnostics = []diagnostics.Diagnostic{
				diagnostics.AtPath("FFI_OBSERVATION_FAILED", "", run.LogicalPath),
			}
			report.ExitCode = 2
			report.Status = "observation-failure"
		} else {
			classified := classifier.Classify(run.Manifest)
			item.Classification = classified.Classification
			item.Diagnostics = classified.Diagnostics
			if classified.Classification == classifier.LegacyUnversioned {
				facts, pointerErr := observe.Pointers(run.Manifest, observe.TrustedRoots{
					RepositoryRoot: run.RepositoryRoot, RunRoot: run.RunDir,
				})
				if pointerErr != nil {
					item.Diagnostics = diagnostics.Normalize(append(item.Diagnostics,
						diagnostics.New("FFI_ARTIFACT_PATH_ESCAPE", "/artifacts")))
				}
				plan := migration.Plan(migration.Request{Raw: run.Manifest, LogicalRunPath: run.Slug, PointerFacts: facts})
				item.MigrationStatus = plan.Status
				if plan.Status == migration.StatusRefused {
					item.Diagnostics = diagnostics.Normalize(append(item.Diagnostics, plan.Diagnostics...))
				}
			} else if classified.Classification == classifier.CurrentStructuralValid {
				item.Diagnostics = diagnostics.Normalize(append(item.Diagnostics, semanticDiagnostics(run)...))
			}
			if len(item.Diagnostics) != 0 && report.ExitCode == 0 {
				report.ExitCode = 1
				report.Status = "blocking-integrity"
			}
		}
		report.Runs = append(report.Runs, item)
	}
	return report
}

func semanticDiagnostics(run observe.Run) []diagnostics.Diagnostic {
	var out []diagnostics.Diagnostic
	if _, err := observe.Pointers(run.Manifest, observe.TrustedRoots{
		RepositoryRoot: run.RepositoryRoot, RunRoot: run.RunDir,
	}); err != nil {
		out = append(out, diagnostics.New("FFI_ARTIFACT_PATH_ESCAPE", "/artifacts"))
	}
	value, err := jsonstrict.Decode(run.Manifest)
	if err != nil {
		return out
	}
	object := value.(map[string]any)
	artifacts, _ := object["artifacts"].(map[string]any)
	phases, _ := object["phases"].(map[string]any)
	for name, phaseValue := range phases {
		artifactName, defined := phaseArtifact[name]
		if !defined {
			continue
		}
		phase, _ := phaseValue.(map[string]any)
		mirror, mirrorOK := phase["artifact"].(string)
		canonical, canonicalOK := artifacts[artifactName].(string)
		if mirrorOK != canonicalOK || (mirrorOK && mirror != canonical) {
			out = append(out, diagnostics.New("FFI_ARTIFACT_MIRROR_MISMATCH", "/phases/"+name+"/artifact"))
		}
	}
	return out
}

var phaseArtifact = map[string]string{
	"explore": "explore", "clarify": "spec", "design": "design", "plan": "plan",
	"diagnose": "diagnosis", "review": "review", "verify": "verify", "deliver": "delivery", "retro": "retro",
}

func RenderJSON(report Report) []byte {
	raw, _ := json.MarshalIndent(report, "", "  ")
	return append(raw, '\n')
}

func RenderHuman(report Report) []byte {
	var out strings.Builder
	fmt.Fprintf(&out, "integrity: %s (exit %d)\n", report.Status, report.ExitCode)
	for _, run := range report.Runs {
		class := string(run.Classification)
		if class == "" {
			class = "OBSERVATION_FAILED"
		}
		fmt.Fprintf(&out, "%s: %s", run.Slug, class)
		if run.MigrationStatus != "" {
			fmt.Fprintf(&out, " migration=%s", run.MigrationStatus)
		}
		out.WriteByte('\n')
		for _, diagnostic := range run.Diagnostics {
			fmt.Fprintf(&out, "  %s %s", diagnostic.Code, diagnostic.JSONPointer)
			if diagnostic.LogicalPath != "" {
				fmt.Fprintf(&out, " %s", diagnostic.LogicalPath)
			}
			out.WriteByte('\n')
		}
	}
	return []byte(out.String())
}
