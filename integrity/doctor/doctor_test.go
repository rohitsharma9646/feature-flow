package doctor

import (
	"strings"
	"testing"

	"github.com/rohitsharma9646/feature-flow/integrity/observe"
)

func TestDiagnoseClassificationAndRendererParity(t *testing.T) {
	report := Diagnose([]observe.Run{
		{Slug: "b", LogicalPath: "b/manifest.json", Manifest: []byte(`{`)},
		{Slug: "a", LogicalPath: "a/manifest.json", Manifest: []byte(`{"slug":"a"}`)},
	})
	if report.ExitCode != 1 || report.Runs[0].Slug != "a" {
		t.Fatalf("report = %#v", report)
	}
	human := string(RenderHuman(report))
	jsonOut := string(RenderJSON(report))
	for _, code := range []string{"FFI_INVALID_JSON", "FFI_LEGACY_MIGRATION_REQUIRED"} {
		if !strings.Contains(human, code) || !strings.Contains(jsonOut, code) {
			t.Fatalf("%s missing from renderers", code)
		}
	}
}

func TestObservationFailureExitsTwoWithoutRawError(t *testing.T) {
	report := Diagnose([]observe.Run{{Slug: "x", LogicalPath: "x/manifest.json", ReadError: true}})
	if report.ExitCode != 2 {
		t.Fatalf("exit = %d", report.ExitCode)
	}
	if strings.Contains(string(RenderJSON(report)), "/home/") {
		t.Fatal("absolute path leaked")
	}
}
