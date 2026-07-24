package storage

import (
	"os"
	"path/filepath"
	"strings"
	"testing"

	"github.com/rohitsharma9646/feature-flow/integrity/digest"
)

func TestPublishRevisionCASPublishesArtifactThenManifest(t *testing.T) {
	runDir := t.TempDir()
	manifest := []byte("{\"value\":\"before\"}\n")
	if err := os.WriteFile(filepath.Join(runDir, "manifest.json"), manifest, 0o600); err != nil {
		t.Fatal(err)
	}
	artifact := []byte("{\"facts\":[]}")
	artifactDigest := digest.RawSHA256(artifact)
	result := PublishRevisionCAS(runDir, RevisionCASRequest{
		ExpectedManifestDigest: digest.RawSHA256(manifest),
		ProposedManifest:       []byte("{\"value\":\"after\"}\n"),
		ArtifactName:           "baseline-v1-" + strings.TrimPrefix(artifactDigest, "sha256:") + ".json",
		Artifact:               artifact,
		ArtifactDigest:         artifactDigest,
	})
	if result.Status != CASApplied {
		t.Fatalf("unexpected result: %#v", result)
	}
	got, err := os.ReadFile(filepath.Join(runDir, filepath.FromSlash(result.Artifact)))
	if err != nil || string(got) != string(artifact) {
		t.Fatalf("artifact mismatch: %q %v", got, err)
	}
}

func TestPublishRevisionCASConflictLeavesManifestUntouched(t *testing.T) {
	runDir := t.TempDir()
	manifest := []byte("{\"value\":\"current\"}\n")
	if err := os.WriteFile(filepath.Join(runDir, "manifest.json"), manifest, 0o600); err != nil {
		t.Fatal(err)
	}
	artifact := []byte("{\"facts\":[]}")
	artifactDigest := digest.RawSHA256(artifact)
	result := PublishRevisionCAS(runDir, RevisionCASRequest{
		ExpectedManifestDigest: digest.RawSHA256([]byte("stale")),
		ProposedManifest:       []byte("{\"value\":\"proposed\"}\n"),
		ArtifactName:           "baseline-v1-" + strings.TrimPrefix(artifactDigest, "sha256:") + ".json",
		Artifact:               artifact,
		ArtifactDigest:         artifactDigest,
	})
	if result.Status != CASConflict {
		t.Fatalf("unexpected result: %#v", result)
	}
	got, _ := os.ReadFile(filepath.Join(runDir, "manifest.json"))
	if string(got) != string(manifest) {
		t.Fatal("conflict replaced manifest")
	}
}
