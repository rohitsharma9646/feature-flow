package storage

import (
	"path/filepath"

	"github.com/rohitsharma9646/feature-flow/integrity/digest"
)

const maxManifestBytes = 4 << 20

// ReadManifest reads canonical run state through the platform's anchored run
// filesystem implementation and returns the bytes plus their CAS digest.
func ReadManifest(runDir string) ([]byte, string, error) {
	files, err := openRunFS(runDir)
	if err != nil {
		return nil, "", err
	}
	defer files.Close()
	if err := files.ValidateLocation(); err != nil {
		return nil, "", err
	}
	raw, err := files.ReadManifest(maxManifestBytes)
	if err != nil {
		return nil, "", err
	}
	return raw, digest.RawSHA256(raw), nil
}

// ReplaceManifestCAS atomically replaces manifest.json only when the currently
// anchored bytes still match expectedDigest.
func ReplaceManifestCAS(runDir, expectedDigest string, proposed []byte) CASStatus {
	if !digest.Valid(expectedDigest) || len(proposed) == 0 || len(proposed) > maxManifestBytes {
		return CASRefused
	}
	files, err := openRunFS(runDir)
	if err != nil {
		return CASRefused
	}
	defer files.Close()
	if err := files.ValidateLocation(); err != nil {
		return CASRefused
	}
	current, err := files.ReadManifest(maxManifestBytes)
	if err != nil {
		return CASFailed
	}
	if digest.RawSHA256(current) != expectedDigest {
		return CASConflict
	}
	temp, err := files.WriteManifestTemp(proposed)
	if err != nil {
		return CASFailed
	}
	defer files.RemoveManifestTemp(temp)
	current, err = files.ReadManifest(maxManifestBytes)
	if err != nil || digest.RawSHA256(current) != expectedDigest {
		return CASConflict
	}
	if err := files.ValidateLocation(); err != nil || files.ReplaceManifest(temp) != nil {
		return CASFailed
	}
	if err := files.SyncRun(); err != nil {
		return CASFailed
	}
	return CASApplied
}

// ReadRevisionArtifact resolves only the schema-defined revision namespace and
// verifies the exact content-addressed bytes before returning them.
func ReadRevisionArtifact(runDir, logicalPath, expectedDigest string, max int64) ([]byte, error) {
	if !digest.Valid(expectedDigest) || filepath.ToSlash(logicalPath) != logicalPath ||
		filepath.Dir(logicalPath) != "revision" {
		return nil, errUnsafeFilesystem
	}
	name := filepath.Base(logicalPath)
	files, err := openRunFS(runDir)
	if err != nil {
		return nil, err
	}
	defer files.Close()
	if err := files.ValidateLocation(); err != nil || files.EnsureRevision() != nil {
		return nil, errUnsafeFilesystem
	}
	raw, err := files.ReadRevision(name, max)
	if err != nil || digest.RawSHA256(raw) != expectedDigest {
		return nil, errUnsafeFilesystem
	}
	return raw, nil
}
