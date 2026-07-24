package revision

import (
	"errors"
	"fmt"
	"path"
	"sort"
	"strings"
	"unicode/utf8"

	"github.com/rohitsharma9646/feature-flow/integrity/canonicaljson"
	"github.com/rohitsharma9646/feature-flow/integrity/digest"
)

func Compute(input Descriptor) (Result, error) {
	canonical, err := canonicalDescriptor(input)
	if err != nil {
		return Result{}, err
	}
	raw, err := canonicaljson.Marshal(canonical)
	if err != nil {
		return Result{}, err
	}
	return Result{
		Status: "ready", Algorithm: "ff-code-revision-v1",
		ID: digest.RevisionID(raw), Canonical: raw,
	}, nil
}

func canonicalDescriptor(input Descriptor) (map[string]any, error) {
	if input.RepositoryIdentity == "" || input.WorktreeIdentity == "" ||
		!validGitOID(input.BaselineHead) || !digest.Valid(input.StartSnapshotDigest) {
		return nil, errors.New("revision identity or baseline is invalid")
	}
	scope, scopePaths, err := canonicalScope(input.Scope)
	if err != nil {
		return nil, err
	}
	entries := append([]Entry(nil), input.Entries...)
	sort.Slice(entries, func(i, j int) bool { return entries[i].Path < entries[j].Path })
	entryValues := make([]any, 0, len(entries))
	seen := make(map[string]struct{}, len(entries))
	for _, entry := range entries {
		normalized, err := normalizePath(entry.Path)
		if err != nil || normalized != entry.Path {
			return nil, fmt.Errorf("invalid entry path %q", entry.Path)
		}
		if _, exists := seen[normalized]; exists {
			return nil, fmt.Errorf("duplicate entry path %q", normalized)
		}
		seen[normalized] = struct{}{}
		if _, declared := scopePaths[normalized]; !declared {
			return nil, fmt.Errorf("entry path %q is outside included scope", normalized)
		}
		if err := validateEntry(entry); err != nil {
			return nil, fmt.Errorf("%s: %w", normalized, err)
		}
		entryValues = append(entryValues, map[string]any{
			"path": entry.Path, "kind": string(entry.Kind), "mode": entry.Mode,
			"baselineBlob": optional(entry.BaselineBlob), "indexBlob": optional(entry.IndexBlob),
			"worktreeDigest":      optional(entry.WorktreeDigest),
			"symlinkTargetDigest": optional(entry.SymlinkTargetDigest),
		})
	}
	return map[string]any{
		"domain": "feature-flow-code-revision", "version": 1,
		"repositoryIdentity":  input.RepositoryIdentity,
		"worktreeIdentity":    input.WorktreeIdentity,
		"baselineHead":        input.BaselineHead,
		"startSnapshotDigest": input.StartSnapshotDigest,
		"scope":               scope, "entries": entryValues,
	}, nil
}

func canonicalScope(input Scope) (map[string]any, map[string]struct{}, error) {
	tracked := append([]string(nil), input.TrackedPaths...)
	untracked := append([]string(nil), input.IncludedUntrackedPaths...)
	exclusions := append([]Exclusion(nil), input.Exclusions...)
	sort.Strings(tracked)
	sort.Strings(untracked)
	sort.Slice(exclusions, func(i, j int) bool { return exclusions[i].Path < exclusions[j].Path })
	seen := make(map[string]struct{}, len(tracked)+len(untracked)+len(exclusions))
	included := make(map[string]struct{}, len(tracked)+len(untracked))
	validate := func(candidate, class string) error {
		normalized, err := normalizePath(candidate)
		if err != nil || normalized != candidate {
			return fmt.Errorf("invalid %s path %q", class, candidate)
		}
		if _, exists := seen[normalized]; exists {
			return fmt.Errorf("scope path %q has duplicate or conflicting classes", normalized)
		}
		seen[normalized] = struct{}{}
		return nil
	}
	for _, candidate := range tracked {
		if err := validate(candidate, "tracked"); err != nil {
			return nil, nil, err
		}
		included[candidate] = struct{}{}
	}
	for _, candidate := range untracked {
		if err := validate(candidate, "untracked"); err != nil {
			return nil, nil, err
		}
		included[candidate] = struct{}{}
	}
	exclusionValues := make([]any, 0, len(exclusions))
	for _, exclusion := range exclusions {
		if err := validate(exclusion.Path, "excluded"); err != nil {
			return nil, nil, err
		}
		if strings.TrimSpace(exclusion.Reason) != exclusion.Reason || exclusion.Reason == "" ||
			!digest.Valid(exclusion.BaselineStateDigest) {
			return nil, nil, fmt.Errorf("invalid exclusion %q", exclusion.Path)
		}
		exclusionValues = append(exclusionValues, map[string]any{
			"path": exclusion.Path, "reason": exclusion.Reason,
			"baselineStateDigest": exclusion.BaselineStateDigest,
		})
	}
	return map[string]any{
		"trackedPaths":           stringsToAny(tracked),
		"includedUntrackedPaths": stringsToAny(untracked),
		"exclusions":             exclusionValues,
	}, included, nil
}

func validateEntry(entry Entry) error {
	for _, oid := range []*string{entry.BaselineBlob, entry.IndexBlob} {
		if oid != nil && !validGitOID(*oid) {
			return errors.New("invalid Git object ID")
		}
	}
	switch entry.Kind {
	case KindFile:
		if entry.Mode != "100644" && entry.Mode != "100755" {
			return errors.New("invalid file mode")
		}
		if entry.SymlinkTargetDigest != nil {
			return errors.New("file has symlink target")
		}
	case KindSymlink:
		if entry.Mode != "120000" || entry.SymlinkTargetDigest == nil ||
			!digest.Valid(*entry.SymlinkTargetDigest) || entry.WorktreeDigest != nil {
			return errors.New("invalid symlink representation")
		}
	case KindDeletion:
		if entry.Mode != "000000" || entry.WorktreeDigest != nil ||
			entry.SymlinkTargetDigest != nil {
			return errors.New("invalid deletion representation")
		}
	default:
		return errors.New("invalid entry kind")
	}
	for _, value := range []*string{entry.WorktreeDigest, entry.SymlinkTargetDigest} {
		if value != nil && !digest.Valid(*value) {
			return errors.New("invalid content digest")
		}
	}
	return nil
}

func validGitOID(value string) bool {
	if len(value) != 40 && len(value) != 64 {
		return false
	}
	for _, character := range value {
		if (character < '0' || character > '9') && (character < 'a' || character > 'f') {
			return false
		}
	}
	return true
}

func normalizePath(value string) (string, error) {
	if value == "" || !utf8.ValidString(value) || strings.ContainsRune(value, 0) ||
		strings.Contains(value, "\\") || strings.HasPrefix(value, "/") {
		return "", errors.New("invalid path")
	}
	normalized := path.Clean(value)
	if normalized == "." || normalized == ".." || strings.HasPrefix(normalized, "../") {
		return "", errors.New("escaping path")
	}
	return normalized, nil
}

func optional(value *string) any {
	if value == nil {
		return nil
	}
	return *value
}

func stringsToAny(values []string) []any {
	out := make([]any, len(values))
	for i := range values {
		out[i] = values[i]
	}
	return out
}
