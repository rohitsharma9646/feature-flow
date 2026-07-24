package revision

import (
	"slices"
	"testing"
)

func TestComputeCanonicalizesScopeAndEntries(t *testing.T) {
	input := fixture()
	input.Scope.TrackedPaths = []string{"b.go", "a.go"}
	input.Entries = []Entry{
		{Path: "b.go", Kind: KindFile, Mode: "100644", IndexBlob: ptr("b")},
		{Path: "a.go", Kind: KindFile, Mode: "100644", IndexBlob: ptr("a"), WorktreeDigest: ptr("sha256:aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa")},
	}
	first, err := Compute(input)
	if err != nil {
		t.Fatal(err)
	}
	slices.Reverse(input.Scope.TrackedPaths)
	slices.Reverse(input.Entries)
	second, err := Compute(input)
	if err != nil {
		t.Fatal(err)
	}
	if first.ID != second.ID || string(first.Canonical) != string(second.Canonical) {
		t.Fatalf("enumeration order changed revision:\n%s\n%s", first.Canonical, second.Canonical)
	}
}

func TestComputeChangedDimensionsChangeRevision(t *testing.T) {
	base := fixture()
	original, err := Compute(base)
	if err != nil {
		t.Fatal(err)
	}
	mutations := map[string]func(*Descriptor){
		"worktree content": func(value *Descriptor) {
			value.Entries[0].WorktreeDigest = ptr("sha256:bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb")
		},
		"index blob": func(value *Descriptor) { value.Entries[0].IndexBlob = ptr("next-index") },
		"mode":       func(value *Descriptor) { value.Entries[0].Mode = "100755" },
		"scope": func(value *Descriptor) {
			value.Scope.TrackedPaths = append(value.Scope.TrackedPaths, "future.go")
			value.Entries = append(value.Entries, Entry{Path: "future.go", Kind: KindDeletion, Mode: "000000"})
		},
		"exclusion": func(value *Descriptor) {
			value.Scope.Exclusions = []Exclusion{{
				Path: "excluded.txt", Reason: "user work",
				BaselineStateDigest: "sha256:cccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccc",
			}}
		},
		"baseline head":       func(value *Descriptor) { value.BaselineHead = "next-head" },
		"repository identity": func(value *Descriptor) { value.RepositoryIdentity = "next-repo" },
		"worktree identity":   func(value *Descriptor) { value.WorktreeIdentity = "next-worktree" },
	}
	for name, mutate := range mutations {
		t.Run(name, func(t *testing.T) {
			changed := fixture()
			mutate(&changed)
			next, err := Compute(changed)
			if err != nil {
				t.Fatal(err)
			}
			if original.ID == next.ID {
				t.Fatalf("%s change preserved revision", name)
			}
		})
	}
}

func TestComputeRejectsInvalidOrDuplicatePaths(t *testing.T) {
	for name, mutate := range map[string]func(*Descriptor){
		"escape": func(d *Descriptor) { d.Entries[0].Path = "../escape" },
		"duplicate": func(d *Descriptor) {
			d.Entries = append(d.Entries, d.Entries[0])
		},
		"scope conflict": func(d *Descriptor) {
			d.Scope.IncludedUntrackedPaths = append(d.Scope.IncludedUntrackedPaths, "a.go")
		},
	} {
		t.Run(name, func(t *testing.T) {
			value := fixture()
			mutate(&value)
			if _, err := Compute(value); err == nil {
				t.Fatal("expected rejection")
			}
		})
	}
}

func fixture() Descriptor {
	return Descriptor{
		RepositoryIdentity:  "repo-id",
		WorktreeIdentity:    "worktree-id",
		BaselineHead:        "0123456789abcdef",
		StartSnapshotDigest: "sha256:1111111111111111111111111111111111111111111111111111111111111111",
		Scope:               Scope{TrackedPaths: []string{"a.go"}},
		Entries: []Entry{{
			Path: "a.go", Kind: KindFile, Mode: "100644", BaselineBlob: ptr("base"),
			IndexBlob:      ptr("index"),
			WorktreeDigest: ptr("sha256:aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa"),
		}},
	}
}

func ptr(value string) *string { return &value }
