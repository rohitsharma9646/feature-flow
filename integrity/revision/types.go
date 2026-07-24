// Package revision defines the host-neutral CodeRevision v1 contract.
package revision

type EntryKind string

const (
	KindFile     EntryKind = "file"
	KindSymlink  EntryKind = "symlink"
	KindDeletion EntryKind = "deletion"
)

type Exclusion struct {
	Path                string `json:"path"`
	Reason              string `json:"reason"`
	BaselineStateDigest string `json:"baselineStateDigest"`
}

type Scope struct {
	TrackedPaths           []string    `json:"trackedPaths"`
	IncludedUntrackedPaths []string    `json:"includedUntrackedPaths"`
	Exclusions             []Exclusion `json:"exclusions"`
}

type Entry struct {
	Path                string    `json:"path"`
	Kind                EntryKind `json:"kind"`
	Mode                string    `json:"mode"`
	BaselineBlob        *string   `json:"baselineBlob"`
	IndexBlob           *string   `json:"indexBlob"`
	WorktreeDigest      *string   `json:"worktreeDigest"`
	SymlinkTargetDigest *string   `json:"symlinkTargetDigest"`
}

type Descriptor struct {
	RepositoryIdentity  string  `json:"repositoryIdentity"`
	WorktreeIdentity    string  `json:"worktreeIdentity"`
	BaselineHead        string  `json:"baselineHead"`
	StartSnapshotDigest string  `json:"startSnapshotDigest"`
	Scope               Scope   `json:"scope"`
	Entries             []Entry `json:"entries"`
}

type Result struct {
	Status    string `json:"status"`
	Algorithm string `json:"algorithm"`
	ID        string `json:"id"`
	Canonical []byte `json:"-"`
}
