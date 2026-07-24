// Package gitobserve is the supported Git adapter for CodeRevision v1.
package gitobserve

import (
	"bytes"
	"context"
	"errors"
	"fmt"
	"os"
	"os/exec"
	"path/filepath"
	"sort"
	"strings"
	"time"
	"unicode/utf8"

	"github.com/rohitsharma9646/feature-flow/integrity/canonicaljson"
	"github.com/rohitsharma9646/feature-flow/integrity/digest"
	"github.com/rohitsharma9646/feature-flow/integrity/revision"
)

type Limits struct {
	MaxPaths      int
	MaxFileBytes  int64
	MaxTotalBytes int64
	MaxGitOutput  int
	Timeout       time.Duration
}

func DefaultLimits() Limits {
	return Limits{
		MaxPaths: 10000, MaxFileBytes: 16 << 20, MaxTotalBytes: 256 << 20,
		MaxGitOutput: 16 << 20, Timeout: 20 * time.Second,
	}
}

type PathFact struct {
	Path                string             `json:"path"`
	Kind                revision.EntryKind `json:"kind"`
	Mode                string             `json:"mode"`
	BaselineBlob        *string            `json:"baselineBlob"`
	IndexBlob           *string            `json:"indexBlob"`
	WorktreeDigest      *string            `json:"worktreeDigest"`
	SymlinkTargetDigest *string            `json:"symlinkTargetDigest"`
	StateDigest         string             `json:"stateDigest"`
}

type Baseline struct {
	RepositoryIdentity  string         `json:"repositoryIdentity"`
	WorktreeIdentity    string         `json:"worktreeIdentity"`
	Head                string         `json:"head"`
	StartSnapshotDigest string         `json:"startSnapshotDigest"`
	Scope               revision.Scope `json:"scope"`
	Facts               []PathFact     `json:"facts"`
	Canonical           []byte         `json:"-"`
	ArtifactDigest      string         `json:"artifactDigest"`
}

type Status string

const (
	StatusReady       Status = "ready"
	StatusUnsupported Status = "unsupported"
	StatusScopeDrift  Status = "scope-drift"
)

type ObserveResult struct {
	Status     Status
	Revision   revision.Result
	DriftPaths []string
	Err        error
}

func Capture(root string, scope revision.Scope, limits Limits) (Baseline, error) {
	sort.Strings(scope.TrackedPaths)
	sort.Strings(scope.IncludedUntrackedPaths)
	sort.Slice(scope.Exclusions, func(i, j int) bool { return scope.Exclusions[i].Path < scope.Exclusions[j].Path })
	firstHead, err := gitText(root, limits, "rev-parse", "--verify", "HEAD")
	if err != nil || firstHead == "" {
		return Baseline{}, errors.New("FFI_REVISION_UNSUPPORTED")
	}
	identity, worktree, err := identities(root, firstHead, limits)
	if err != nil {
		return Baseline{}, errors.New("FFI_REVISION_UNSUPPORTED")
	}
	facts, err := snapshot(root, firstHead, limits)
	if err != nil {
		return Baseline{}, err
	}
	lastHead, err := gitText(root, limits, "rev-parse", "--verify", "HEAD")
	if err != nil || lastHead != firstHead {
		return Baseline{}, errors.New("FFI_REVISION_UNSUPPORTED")
	}
	byPath := factMap(facts)
	if err := validateScope(scope, byPath); err != nil {
		return Baseline{}, err
	}
	for index := range scope.Exclusions {
		scope.Exclusions[index].BaselineStateDigest = byPath[scope.Exclusions[index].Path].StateDigest
	}
	raw, err := baselineBytes(identity, worktree, firstHead, scope, facts)
	if err != nil {
		return Baseline{}, err
	}
	return Baseline{
		RepositoryIdentity: identity, WorktreeIdentity: worktree, Head: firstHead,
		StartSnapshotDigest: digest.SHA256("baseline-snapshot-v1", raw),
		Scope:               scope, Facts: facts, Canonical: raw,
		ArtifactDigest: digest.RawSHA256(raw),
	}, nil
}

func Observe(root string, baseline Baseline, limits Limits) ObserveResult {
	head, err := gitText(root, limits, "rev-parse", "--verify", "HEAD")
	if err != nil || head != baseline.Head {
		return ObserveResult{Status: StatusUnsupported, Err: errors.New("FFI_REVISION_UNSUPPORTED")}
	}
	identity, worktree, err := identities(root, head, limits)
	if err != nil || identity != baseline.RepositoryIdentity || worktree != baseline.WorktreeIdentity {
		return ObserveResult{Status: StatusUnsupported, Err: errors.New("FFI_REVISION_UNSUPPORTED")}
	}
	current, err := snapshot(root, head, limits)
	if err != nil {
		return ObserveResult{Status: StatusUnsupported, Err: err}
	}
	if after, checkErr := gitText(root, limits, "rev-parse", "--verify", "HEAD"); checkErr != nil || after != head {
		return ObserveResult{Status: StatusUnsupported, Err: errors.New("FFI_REVISION_UNSUPPORTED")}
	}
	beforeMap, currentMap := factMap(baseline.Facts), factMap(current)
	all := make(map[string]struct{}, len(beforeMap)+len(currentMap))
	for name := range beforeMap {
		all[name] = struct{}{}
	}
	for name := range currentMap {
		all[name] = struct{}{}
	}
	included := make(map[string]bool)
	for _, name := range baseline.Scope.TrackedPaths {
		included[name] = true
	}
	for _, name := range baseline.Scope.IncludedUntrackedPaths {
		included[name] = true
	}
	excluded := make(map[string]string)
	for _, item := range baseline.Scope.Exclusions {
		excluded[item.Path] = item.BaselineStateDigest
	}
	var drift []string
	for name := range all {
		before, beforeOK := beforeMap[name]
		now, nowOK := currentMap[name]
		if beforeOK == nowOK && before.StateDigest == now.StateDigest {
			continue
		}
		if included[name] {
			continue
		}
		if expected, ok := excluded[name]; ok && nowOK && now.StateDigest == expected {
			continue
		}
		drift = append(drift, name)
	}
	sort.Strings(drift)
	if len(drift) != 0 {
		return ObserveResult{Status: StatusScopeDrift, DriftPaths: drift, Err: errors.New("FFI_REVISION_SCOPE_DRIFT")}
	}
	entries := make([]revision.Entry, 0, len(included))
	for name := range included {
		fact, ok := currentMap[name]
		if !ok {
			previous, wasTracked := beforeMap[name]
			if !wasTracked {
				fact = PathFact{Path: name, Kind: revision.KindDeletion, Mode: "000000"}
			} else {
				fact = PathFact{
					Path: name, Kind: revision.KindDeletion, Mode: "000000",
					BaselineBlob: previous.BaselineBlob,
				}
			}
		}
		entries = append(entries, revision.Entry{
			Path: fact.Path, Kind: fact.Kind, Mode: fact.Mode,
			BaselineBlob: fact.BaselineBlob, IndexBlob: fact.IndexBlob,
			WorktreeDigest: fact.WorktreeDigest, SymlinkTargetDigest: fact.SymlinkTargetDigest,
		})
	}
	result, err := revision.Compute(revision.Descriptor{
		RepositoryIdentity: baseline.RepositoryIdentity, WorktreeIdentity: baseline.WorktreeIdentity,
		BaselineHead: baseline.Head, StartSnapshotDigest: baseline.StartSnapshotDigest,
		Scope: baseline.Scope, Entries: entries,
	})
	if err != nil {
		return ObserveResult{Status: StatusUnsupported, Err: err}
	}
	return ObserveResult{Status: StatusReady, Revision: result, DriftPaths: []string{}}
}

func snapshot(root, head string, limits Limits) ([]PathFact, error) {
	if err := checkCapabilities(root, limits); err != nil {
		return nil, err
	}
	indexRaw, err := gitBytes(root, limits, "ls-files", "-z", "--stage")
	if err != nil {
		return nil, errors.New("FFI_REVISION_UNSUPPORTED")
	}
	index, err := parseIndex(indexRaw)
	if err != nil {
		return nil, err
	}
	headRaw, err := gitBytes(root, limits, "ls-tree", "-rz", "--full-tree", head)
	if err != nil {
		return nil, errors.New("FFI_REVISION_UNSUPPORTED")
	}
	headFacts, err := parseTree(headRaw)
	if err != nil {
		return nil, err
	}
	untrackedRaw, err := gitBytes(root, limits, "ls-files", "-z", "--others", "--exclude-standard")
	if err != nil {
		return nil, errors.New("FFI_REVISION_UNSUPPORTED")
	}
	names := make(map[string]struct{}, len(index)+len(headFacts))
	for name := range index {
		names[name] = struct{}{}
	}
	for name := range headFacts {
		names[name] = struct{}{}
	}
	for _, raw := range bytes.Split(untrackedRaw, []byte{0}) {
		if len(raw) != 0 {
			names[string(raw)] = struct{}{}
		}
	}
	if len(names) > limits.MaxPaths {
		return nil, errors.New("FFI_REVISION_UNSUPPORTED")
	}
	sorted := make([]string, 0, len(names))
	folded := make(map[string]string, len(names))
	for name := range names {
		if !utf8.ValidString(name) || strings.ContainsRune(name, 0) {
			return nil, errors.New("FFI_REVISION_UNSUPPORTED")
		}
		key := strings.ToLower(filepath.ToSlash(name))
		if previous, exists := folded[key]; exists && previous != name {
			return nil, errors.New("FFI_REVISION_UNSUPPORTED")
		}
		folded[key] = name
		sorted = append(sorted, name)
	}
	sort.Strings(sorted)
	var total int64
	facts := make([]PathFact, 0, len(sorted))
	for _, name := range sorted {
		item := PathFact{Path: filepath.ToSlash(name)}
		if indexed, ok := index[name]; ok {
			item.Mode, item.IndexBlob = indexed.mode, &indexed.blob
		} else if tracked, ok := headFacts[name]; ok {
			item.Mode = tracked.mode
		}
		if tracked, ok := headFacts[name]; ok {
			item.BaselineBlob = &tracked.blob
		}
		kind, mode, content, target, size, readErr := observeWorktree(root, name, limits.MaxFileBytes)
		if readErr != nil {
			return nil, readErr
		}
		total += size
		if total > limits.MaxTotalBytes {
			return nil, errors.New("FFI_REVISION_UNSUPPORTED")
		}
		item.Kind = kind
		if mode != "" {
			item.Mode = mode
		}
		item.WorktreeDigest, item.SymlinkTargetDigest = content, target
		if item.Kind == "" {
			item.Kind, item.Mode = revision.KindDeletion, "000000"
		}
		state, stateErr := stateDigest(item)
		if stateErr != nil {
			return nil, stateErr
		}
		item.StateDigest = state
		facts = append(facts, item)
	}
	return facts, nil
}

func checkCapabilities(root string, limits Limits) error {
	for _, key := range []string{"core.sparseCheckout", "core.sparseCheckoutCone", "remote.origin.promisor"} {
		value, err := gitText(root, limits, "config", "--bool", "--get", key)
		if err == nil && value == "true" {
			return errors.New("FFI_REVISION_UNSUPPORTED")
		}
	}
	attributes := filepath.Join(root, ".gitattributes")
	if raw, err := os.ReadFile(attributes); err == nil && bytes.Contains(raw, []byte("filter=")) {
		return errors.New("FFI_REVISION_UNSUPPORTED")
	}
	return nil
}

type gitEntry struct{ mode, blob string }

func parseIndex(raw []byte) (map[string]gitEntry, error) {
	out := make(map[string]gitEntry)
	for _, record := range bytes.Split(raw, []byte{0}) {
		if len(record) == 0 {
			continue
		}
		tab := bytes.IndexByte(record, '\t')
		if tab < 0 {
			return nil, errors.New("FFI_REVISION_UNSUPPORTED")
		}
		fields := strings.Fields(string(record[:tab]))
		if len(fields) != 3 || fields[2] != "0" || fields[0] == "160000" {
			return nil, errors.New("FFI_REVISION_UNSUPPORTED")
		}
		out[string(record[tab+1:])] = gitEntry{mode: fields[0], blob: fields[1]}
	}
	return out, nil
}

func parseTree(raw []byte) (map[string]gitEntry, error) {
	out := make(map[string]gitEntry)
	for _, record := range bytes.Split(raw, []byte{0}) {
		if len(record) == 0 {
			continue
		}
		tab := bytes.IndexByte(record, '\t')
		if tab < 0 {
			return nil, errors.New("FFI_REVISION_UNSUPPORTED")
		}
		fields := strings.Fields(string(record[:tab]))
		if len(fields) != 3 || fields[1] != "blob" {
			return nil, errors.New("FFI_REVISION_UNSUPPORTED")
		}
		out[string(record[tab+1:])] = gitEntry{mode: fields[0], blob: fields[2]}
	}
	return out, nil
}

func stateDigest(fact PathFact) (string, error) {
	raw, err := canonicaljson.Marshal(map[string]any{
		"path": fact.Path, "kind": string(fact.Kind), "mode": fact.Mode,
		"baselineBlob": optional(fact.BaselineBlob), "indexBlob": optional(fact.IndexBlob),
		"worktreeDigest":      optional(fact.WorktreeDigest),
		"symlinkTargetDigest": optional(fact.SymlinkTargetDigest),
	})
	if err != nil {
		return "", err
	}
	return digest.SHA256("path-state-v1", raw), nil
}

func baselineBytes(repositoryIdentity, worktreeIdentity, head string, scope revision.Scope, facts []PathFact) ([]byte, error) {
	factValues := make([]any, len(facts))
	for index, fact := range facts {
		factValues[index] = map[string]any{
			"path": fact.Path, "kind": string(fact.Kind), "mode": fact.Mode,
			"baselineBlob": optional(fact.BaselineBlob), "indexBlob": optional(fact.IndexBlob),
			"worktreeDigest":      optional(fact.WorktreeDigest),
			"symlinkTargetDigest": optional(fact.SymlinkTargetDigest),
			"stateDigest":         fact.StateDigest,
		}
	}
	exclusions := make([]any, len(scope.Exclusions))
	for index, item := range scope.Exclusions {
		exclusions[index] = map[string]any{
			"path": item.Path, "reason": item.Reason,
			"baselineStateDigest": item.BaselineStateDigest,
		}
	}
	return canonicaljson.Marshal(map[string]any{
		"domain": "feature-flow-baseline", "version": 1,
		"repositoryIdentity": repositoryIdentity, "worktreeIdentity": worktreeIdentity,
		"head": head,
		"scope": map[string]any{
			"trackedPaths":           toAny(scope.TrackedPaths),
			"includedUntrackedPaths": toAny(scope.IncludedUntrackedPaths),
			"exclusions":             exclusions,
		},
		"facts": factValues,
	})
}

func identities(root, head string, limits Limits) (string, string, error) {
	objectFormat, err := gitText(root, limits, "rev-parse", "--show-object-format")
	if err != nil {
		return "", "", err
	}
	roots, err := gitText(root, limits, "rev-list", "--max-parents=0", "--reverse", head)
	if err != nil || roots == "" {
		return "", "", errors.New("missing repository roots")
	}
	gitDir, err := gitText(root, limits, "rev-parse", "--git-dir")
	if err != nil {
		return "", "", err
	}
	repository := digest.SHA256("git-repository-v1", []byte(objectFormat+"\x00"+roots))
	logicalGitDir := filepath.ToSlash(gitDir)
	if filepath.IsAbs(gitDir) {
		logicalGitDir = filepath.Base(gitDir)
	}
	worktree := digest.SHA256("git-worktree-v1", []byte(logicalGitDir))
	return repository, worktree, nil
}

func gitText(root string, limits Limits, args ...string) (string, error) {
	raw, err := gitBytes(root, limits, args...)
	return strings.TrimSpace(string(raw)), err
}

func gitBytes(root string, limits Limits, args ...string) ([]byte, error) {
	context, cancel := context.WithTimeout(context.Background(), limits.Timeout)
	defer cancel()
	command := exec.CommandContext(context, "git", append([]string{"-C", root}, args...)...)
	output := &boundedBuffer{limit: limits.MaxGitOutput}
	command.Stdout = output
	command.Stderr = &boundedBuffer{limit: 4096}
	err := command.Run()
	if err != nil || context.Err() != nil || output.overflow {
		return nil, errors.New("git observation failed")
	}
	return output.Bytes(), nil
}

type boundedBuffer struct {
	bytes.Buffer
	limit    int
	overflow bool
}

func (b *boundedBuffer) Write(value []byte) (int, error) {
	if b.limit < 0 || b.Len()+len(value) > b.limit {
		b.overflow = true
		return 0, errors.New("bounded Git output exceeded")
	}
	return b.Buffer.Write(value)
}

func validateScope(scope revision.Scope, facts map[string]PathFact) error {
	seen := make(map[string]bool)
	for _, name := range scope.TrackedPaths {
		if seen[name] || name == "" || filepath.IsAbs(name) || filepath.ToSlash(filepath.Clean(name)) != name ||
			name == ".." || strings.HasPrefix(name, "../") {
			return fmt.Errorf("invalid scope path %q", name)
		}
		seen[name] = true
	}
	for _, name := range scope.IncludedUntrackedPaths {
		if seen[name] || facts[name].Path == "" {
			return fmt.Errorf("invalid scope path %q", name)
		}
		seen[name] = true
	}
	for _, item := range scope.Exclusions {
		if seen[item.Path] || facts[item.Path].Path == "" || strings.TrimSpace(item.Reason) == "" {
			return fmt.Errorf("invalid exclusion %q", item.Path)
		}
		seen[item.Path] = true
	}
	return nil
}

func factMap(facts []PathFact) map[string]PathFact {
	out := make(map[string]PathFact, len(facts))
	for _, fact := range facts {
		out[fact.Path] = fact
	}
	return out
}

func optional(value *string) any {
	if value == nil {
		return nil
	}
	return *value
}

func toAny(values []string) []any {
	out := make([]any, len(values))
	for index := range values {
		out[index] = values[index]
	}
	return out
}
