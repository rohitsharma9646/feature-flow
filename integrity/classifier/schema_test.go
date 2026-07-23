package classifier

import (
	"encoding/json"
	"os"
	"path/filepath"
	"testing"
)

func fixture(t testing.TB, name string) []byte {
	t.Helper()
	raw, err := os.ReadFile(filepath.Join("..", "testdata", "manifests", name))
	if err != nil {
		t.Fatal(err)
	}
	return raw
}

func TestValidFeatureManifest(t *testing.T) {
	got := Classify(fixture(t, "current-feature.json"))
	if got.Classification != CurrentStructuralValid {
		t.Fatalf("got %#v", got)
	}
}

func TestTrackTierPhaseConditionals(t *testing.T) {
	tests := [][]byte{
		validFeatureWith(t, func(manifest map[string]any) {
			manifest["tier"] = "lite"
			manifest["currentPhase"] = "design"
			manifest["phases"] = map[string]any{
				"design": map[string]any{"status": "complete", "artifact": "design.md"},
			}
		}),
		validFeatureWith(t, func(manifest map[string]any) {
			manifest["track"] = "bugfix"
			manifest["tier"] = "lite"
			manifest["currentPhase"] = "explore"
			manifest["phases"] = map[string]any{
				"explore": map[string]any{"status": "complete", "artifact": "explore.md"},
			}
			manifest["signOff"].(map[string]any)["required"] = false
		}),
	}
	for _, raw := range tests {
		if got := Classify(raw).Classification; got != CurrentStructuralInvalid {
			t.Fatalf("got %s", got)
		}
	}
}

func TestIntegrityOwnedObjectsAreClosed(t *testing.T) {
	raw := validFeatureWith(t, func(manifest map[string]any) {
		manifest["code"].(map[string]any)["unknown"] = true
	})
	if got := Classify(raw).Classification; got != CurrentStructuralInvalid {
		t.Fatalf("got %s", got)
	}
}

func validFeatureWith(t *testing.T, mutate func(map[string]any)) []byte {
	t.Helper()
	var manifest map[string]any
	if err := json.Unmarshal(fixture(t, "current-feature.json"), &manifest); err != nil {
		t.Fatal(err)
	}
	mutate(manifest)
	raw, err := json.Marshal(manifest)
	if err != nil {
		t.Fatal(err)
	}
	return raw
}

func TestCanonicalAssuranceAndMigrationShapes(t *testing.T) {
	attestation := map[string]any{
		"attestationId": "attestation-1",
		"kind":          "review",
		"status":        "passed",
		"codeRevision":  "ffr1:0000000000000000000000000000000000000000000000000000000000000000",
		"producer": map[string]any{
			"kind": "ci", "host": "ci", "id": "job-1", "version": "1",
		},
		"recordedAt":   "2026-07-23T00:00:00Z",
		"artifact":     "review",
		"evidenceRefs": []any{"evidence:review"},
		"invalidation": nil,
		"supersedes":   nil,
	}
	raw := validFeatureWith(t, func(manifest map[string]any) {
		manifest["assurance"] = map[string]any{"review": attestation, "verification": nil}
		manifest["migration"] = map[string]any{
			"from":                  "legacy-unversioned",
			"to":                    float64(1),
			"sourceDigest":          "sha256:0000000000000000000000000000000000000000000000000000000000000000",
			"sourceSnapshot":        "migration/source.json",
			"migratorVersion":       "integrity-protocol-v1",
			"migratedAt":            "2026-07-23T00:00:00Z",
			"legacyUnknownPointers": []any{},
			"legacyTerminal":        false,
		}
	})
	if got := Classify(raw).Classification; got != CurrentStructuralValid {
		t.Fatalf("canonical assurance/migration classified %s", got)
	}

	attestation["kind"] = "verification"
	swapped := validFeatureWith(t, func(manifest map[string]any) {
		manifest["assurance"] = map[string]any{"review": attestation, "verification": nil}
		manifest["migration"] = nil
	})
	if got := Classify(swapped).Classification; got != CurrentStructuralInvalid {
		t.Fatalf("swapped review kind classified %s", got)
	}
}

func TestBugfixTierSignOffAndArtifactPointerShapes(t *testing.T) {
	for _, tc := range []struct {
		name     string
		tier     string
		required bool
		want     ManifestClass
	}{
		{"lite-no-signoff", "lite", false, CurrentStructuralValid},
		{"lite-signoff", "lite", true, CurrentStructuralInvalid},
		{"full-signoff", "full", true, CurrentStructuralValid},
		{"full-no-signoff", "full", false, CurrentStructuralInvalid},
	} {
		t.Run(tc.name, func(t *testing.T) {
			raw := validFeatureWith(t, func(manifest map[string]any) {
				manifest["track"] = "bugfix"
				manifest["tier"] = tc.tier
				manifest["currentPhase"] = "diagnose"
				manifest["phases"] = map[string]any{
					"diagnose": map[string]any{"status": "in_progress", "artifact": nil},
				}
				manifest["signOff"].(map[string]any)["required"] = tc.required
			})
			if got := Classify(raw).Classification; got != tc.want {
				t.Fatalf("got %s want %s", got, tc.want)
			}
		})
	}

	raw := validFeatureWith(t, func(manifest map[string]any) {
		manifest["phases"].(map[string]any)["explore"].(map[string]any)["artifact"] = ""
	})
	if got := Classify(raw).Classification; got != CurrentStructuralInvalid {
		t.Fatalf("empty phase artifact classified %s", got)
	}
}
