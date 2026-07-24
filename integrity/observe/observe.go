package observe

import (
	"crypto/sha256"
	"encoding/hex"
	"errors"
	"os"
	"path/filepath"
	"sort"
)

type Run struct {
	Slug           string `json:"slug"`
	LogicalPath    string `json:"logicalPath"`
	Manifest       []byte `json:"-"`
	SourceDigest   string `json:"sourceDigest,omitempty"`
	ReadError      bool   `json:"readError,omitempty"`
	RunDir         string `json:"-"`
	RepositoryRoot string `json:"-"`
}

func One(base, slug string, maxBytes int64) (Run, error) {
	if slug == "" || filepath.Base(slug) != slug || slug == "." || slug == ".." {
		return Run{}, errors.New("invalid slug")
	}
	runDir := filepath.Join(base, slug)
	raw, err := readAnchored(base, slug, maxBytes, nil)
	if err != nil {
		return Run{Slug: slug, LogicalPath: slug + "/manifest.json", ReadError: true}, err
	}
	sum := sha256.Sum256(raw)
	return Run{
		Slug: slug, LogicalPath: slug + "/manifest.json", Manifest: raw,
		SourceDigest: "sha256:" + hex.EncodeToString(sum[:]),
		RunDir:       runDir, RepositoryRoot: filepath.Dir(base),
	}, nil
}

func All(base string, maxRuns int, maxBytes int64) ([]Run, error) {
	entries, err := os.ReadDir(base)
	if os.IsNotExist(err) {
		return []Run{}, nil
	}
	if err != nil {
		return nil, errors.New("run root unavailable")
	}
	if len(entries) > maxRuns {
		return nil, errors.New("run limit exceeded")
	}
	runs := make([]Run, 0, len(entries))
	for _, entry := range entries {
		info, err := entry.Info()
		if err != nil || !info.IsDir() || info.Mode()&os.ModeSymlink != 0 {
			continue
		}
		run, readErr := One(base, entry.Name(), maxBytes)
		if readErr != nil {
			run.Slug = entry.Name()
			run.LogicalPath = entry.Name() + "/manifest.json"
			run.ReadError = true
		}
		runs = append(runs, run)
	}
	sort.Slice(runs, func(i, j int) bool { return runs[i].Slug < runs[j].Slug })
	return runs, nil
}

// ReadManifest reads a canonical manifest through the same bounded no-follow
// boundary used by doctor discovery.
func ReadManifest(path string, max int64) ([]byte, error) {
	runDir := filepath.Dir(filepath.Clean(path))
	return readAnchored(filepath.Dir(runDir), filepath.Base(runDir), max, nil)
}
