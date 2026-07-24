package observe

import (
	"path/filepath"
	"strings"

	"github.com/rohitsharma9646/feature-flow/integrity/jsonstrict"
	"github.com/rohitsharma9646/feature-flow/integrity/pathpolicy"
)

// Pointers observes legacy artifact targets from trusted roots. Bare run-local
// pointers resolve under runDir; repository-relative durable pointers resolve
// under repositoryRoot. A failed resolution is represented by an error so the
// caller can fail closed without reading an escaped target.
type TrustedRoots struct {
	RepositoryRoot string
	RunRoot        string
	DurableRoot    string
}

func Pointers(raw []byte, roots TrustedRoots) (map[string]pathpolicy.Fact, error) {
	value, err := jsonstrict.Decode(raw)
	if err != nil {
		return nil, err
	}
	object, ok := value.(map[string]any)
	if !ok {
		return map[string]pathpolicy.Fact{}, nil
	}
	artifacts, _ := object["artifacts"].(map[string]any)
	out := make(map[string]pathpolicy.Fact, len(artifacts))
	for name, value := range artifacts {
		pointer, ok := value.(string)
		if !ok || pointer == "" {
			continue
		}
		root := roots.RunRoot
		normalized := strings.ReplaceAll(pointer, `\`, "/")
		if underConfiguredRoot(roots.RepositoryRoot, roots.DurableRoot, normalized) ||
			underConfiguredRoot(roots.RepositoryRoot, filepath.Join(roots.RepositoryRoot, ".feature-flow"), normalized) {
			root = roots.RepositoryRoot
		}
		fact, err := pathpolicy.Resolve(root, pointer)
		if err != nil {
			return nil, err
		}
		out[name] = fact
	}
	return out, nil
}

func underConfiguredRoot(repositoryRoot, configuredRoot, pointer string) bool {
	if configuredRoot == "" {
		return false
	}
	relative, err := filepath.Rel(repositoryRoot, configuredRoot)
	if err != nil || relative == "." || relative == ".." || strings.HasPrefix(relative, ".."+string(filepath.Separator)) {
		return false
	}
	prefix := filepath.ToSlash(filepath.Clean(relative))
	return pointer == prefix || strings.HasPrefix(pointer, prefix+"/")
}
