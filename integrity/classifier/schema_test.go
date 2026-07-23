package classifier

import "testing"

const validFeature = `{
  "schemaVersion":1,
  "slug":"fixture",
  "runId":"run-0001",
  "track":"feature",
  "tier":"full",
  "createdAt":"2026-07-23T00:00:00Z",
  "updatedAt":"2026-07-23T00:00:00Z",
  "closedAt":null,
  "autopilot":true,
  "currentPhase":"explore",
  "phases":{"explore":{"status":"in_progress","artifact":null}},
  "signOff":{"required":true,"signed":false,"date":null,"actor":null,"evidenceRef":null},
  "lock":null,
  "artifacts":{},
  "code":{
    "baseline":{"repositoryKind":"git","repositoryIdentity":"repo","worktreeIdentity":"worktree","head":"abc","startSnapshotDigest":"sha256:0000000000000000000000000000000000000000000000000000000000000000"},
    "scope":{"trackedPaths":[],"includedUntrackedPaths":[],"exclusions":[]},
    "revision":{"status":"unsupported","diagnostic":"FFI_REVISION_UNSUPPORTED"}
  },
  "assurance":{"review":null,"verification":null},
  "migration":null
}`

func TestValidFeatureManifest(t *testing.T) {
	got := Classify([]byte(validFeature))
	if got.Classification != CurrentStructuralValid {
		t.Fatalf("got %#v", got)
	}
}

func TestTrackTierPhaseConditionals(t *testing.T) {
	tests := []string{
		`{"schemaVersion":1,"slug":"x","runId":"r","track":"feature","tier":"lite","createdAt":"2026-07-23T00:00:00Z","updatedAt":"2026-07-23T00:00:00Z","closedAt":null,"autopilot":false,"currentPhase":"design","phases":{"design":{"status":"complete","artifact":"design.md"}},"signOff":{"required":true,"signed":true,"date":"2026-07-23","actor":{"kind":"user","id":null},"evidenceRef":"artifact:spec"},"lock":null,"artifacts":{},"code":{"baseline":{"repositoryKind":"git","repositoryIdentity":"repo","worktreeIdentity":"worktree","head":"abc","startSnapshotDigest":"sha256:0000000000000000000000000000000000000000000000000000000000000000"},"scope":{"trackedPaths":[],"includedUntrackedPaths":[],"exclusions":[]},"revision":{"status":"unsupported","diagnostic":"FFI_REVISION_UNSUPPORTED"}},"assurance":{"review":null,"verification":null},"migration":null}`,
		`{"schemaVersion":1,"slug":"x","runId":"r","track":"bugfix","tier":"lite","createdAt":"2026-07-23T00:00:00Z","updatedAt":"2026-07-23T00:00:00Z","closedAt":null,"autopilot":false,"currentPhase":"explore","phases":{"explore":{"status":"complete","artifact":"explore.md"}},"signOff":{"required":false,"signed":false,"date":null,"actor":null,"evidenceRef":null},"lock":null,"artifacts":{},"code":{"baseline":{"repositoryKind":"git","repositoryIdentity":"repo","worktreeIdentity":"worktree","head":"abc","startSnapshotDigest":"sha256:0000000000000000000000000000000000000000000000000000000000000000"},"scope":{"trackedPaths":[],"includedUntrackedPaths":[],"exclusions":[]},"revision":{"status":"unsupported","diagnostic":"FFI_REVISION_UNSUPPORTED"}},"assurance":{"review":null,"verification":null},"migration":null}`,
	}
	for _, raw := range tests {
		if got := Classify([]byte(raw)).Classification; got != CurrentStructuralInvalid {
			t.Fatalf("got %s", got)
		}
	}
}

func TestIntegrityOwnedObjectsAreClosed(t *testing.T) {
	raw := []byte(`{"schemaVersion":1,"slug":"x","runId":"r","track":"feature","tier":"full","createdAt":"2026-07-23T00:00:00Z","updatedAt":"2026-07-23T00:00:00Z","closedAt":null,"autopilot":false,"currentPhase":"explore","phases":{},"signOff":{"required":true,"signed":false,"date":null,"actor":null,"evidenceRef":null},"lock":null,"artifacts":{},"code":{"baseline":{"repositoryKind":"git","repositoryIdentity":"repo","worktreeIdentity":"worktree","head":"abc","startSnapshotDigest":"sha256:0000000000000000000000000000000000000000000000000000000000000000"},"scope":{"trackedPaths":[],"includedUntrackedPaths":[],"exclusions":[]},"revision":{"status":"unsupported","diagnostic":"FFI_REVISION_UNSUPPORTED"},"unknown":true},"assurance":{"review":null,"verification":null},"migration":null}`)
	if got := Classify(raw).Classification; got != CurrentStructuralInvalid {
		t.Fatalf("got %s", got)
	}
}
