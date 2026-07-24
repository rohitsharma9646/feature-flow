package storage

import (
	"errors"
	"path/filepath"
	"strings"

	"github.com/rohitsharma9646/feature-flow/integrity/digest"
)

type CASStatus string

const (
	CASApplied  CASStatus = "applied"
	CASConflict CASStatus = "conflict"
	CASRefused  CASStatus = "refused"
	CASFailed   CASStatus = "failed"
)

type RevisionCASRequest struct {
	ExpectedManifestDigest string
	ProposedManifest       []byte
	ArtifactName           string
	Artifact               []byte
	ArtifactDigest         string
	ArtifactPrefix         string
}

type RevisionCASResult struct {
	Status   CASStatus `json:"status"`
	Artifact string    `json:"artifact,omitempty"`
	Orphan   bool      `json:"orphan,omitempty"`
}

// PublishRevisionCAS publishes immutable baseline facts before replacing the
// canonical manifest. A losing CAS can leave only a content-addressed,
// non-authoritative artifact.
func PublishRevisionCAS(runDir string, request RevisionCASRequest) RevisionCASResult {
	prefix := request.ArtifactPrefix
	if prefix == "" {
		prefix = "baseline-v1-"
	}
	if prefix != "baseline-v1-" && prefix != "assurance-v1-" {
		return RevisionCASResult{Status: CASRefused}
	}
	expectedName := prefix + strings.TrimPrefix(request.ArtifactDigest, "sha256:") + ".json"
	if !digest.Valid(request.ExpectedManifestDigest) || !digest.Valid(request.ArtifactDigest) ||
		digest.RawSHA256(request.Artifact) != request.ArtifactDigest ||
		request.ArtifactName != expectedName || filepath.Base(request.ArtifactName) != request.ArtifactName ||
		len(request.ProposedManifest) == 0 {
		return RevisionCASResult{Status: CASRefused}
	}
	files, err := openRunFS(runDir)
	if err != nil {
		return RevisionCASResult{Status: CASRefused}
	}
	defer files.Close()
	if err := files.ValidateLocation(); err != nil || files.EnsureRevision() != nil {
		return RevisionCASResult{Status: CASRefused}
	}
	created, err := files.PublishRevision(request.ArtifactName, request.Artifact)
	if err != nil {
		return RevisionCASResult{Status: CASFailed}
	}
	artifactPath := filepath.ToSlash(filepath.Join("revision", request.ArtifactName))
	current, err := files.ReadManifest(4 << 20)
	if err != nil {
		return RevisionCASResult{Status: CASFailed, Artifact: artifactPath, Orphan: created}
	}
	if digest.RawSHA256(current) != request.ExpectedManifestDigest {
		return RevisionCASResult{Status: CASConflict, Artifact: artifactPath, Orphan: created}
	}
	temp, err := files.WriteManifestTemp(request.ProposedManifest)
	if err != nil {
		return RevisionCASResult{Status: CASFailed, Artifact: artifactPath, Orphan: created}
	}
	defer files.RemoveManifestTemp(temp)
	current, err = files.ReadManifest(4 << 20)
	if err != nil || digest.RawSHA256(current) != request.ExpectedManifestDigest {
		return RevisionCASResult{Status: CASConflict, Artifact: artifactPath, Orphan: created}
	}
	if err := files.ValidateLocation(); err != nil || files.ReplaceManifest(temp) != nil {
		return RevisionCASResult{Status: CASFailed, Artifact: artifactPath, Orphan: created}
	}
	if err := files.SyncRun(); err != nil && !errors.Is(err, errUnsafeFilesystem) {
		return RevisionCASResult{Status: CASFailed, Artifact: artifactPath}
	}
	return RevisionCASResult{Status: CASApplied, Artifact: artifactPath}
}
