package migration

import (
	"encoding/json"
	"testing"
)

func TestPlanIsDeterministicAndRefusesUnknownBehavior(t *testing.T) {
	raw := []byte(`{"slug":"legacy","track":"feature","tier":"full","autopilot":false,"currentPhase":"implement","phases":{},"signOff":{"required":true,"signed":false,"date":null},"artifacts":{}}`)
	input := Request{Raw: raw, LogicalRunPath: "legacy", RepositoryIdentity: "repo", WorktreeIdentity: "worktree"}
	first := Plan(input)
	second := Plan(input)
	if first.Status != StatusReady || first.PlanDigest == "" {
		t.Fatalf("first plan = %#v", first)
	}
	a, _ := json.Marshal(first)
	b, _ := json.Marshal(second)
	if string(a) != string(b) {
		t.Fatalf("plans differ:\n%s\n%s", a, b)
	}
	ambiguous := Plan(Request{Raw: []byte(`{"slug":"x","track":"feature","currentPhase":"implement","danger":true}`)})
	if ambiguous.Status != StatusRefused {
		t.Fatalf("unknown behavior field accepted: %#v", ambiguous)
	}
}

func TestPlanTerminalRequiresConfirmationAndUnsupportedRevision(t *testing.T) {
	raw := []byte(`{"slug":"legacy","track":"feature","tier":"full","autopilot":false,"currentPhase":"done","phases":{},"signOff":{"required":true,"signed":true,"date":"2026-01-01"},"artifacts":{}}`)
	plan := Plan(Request{Raw: raw, LogicalRunPath: "legacy", RepositoryIdentity: "repo", WorktreeIdentity: "wt"})
	if !plan.RequiresTerminalConfirmation {
		t.Fatal("terminal confirmation not required")
	}
	code := plan.Proposed["code"].(map[string]any)
	if code["revision"].(map[string]any)["status"] != "unsupported" {
		t.Fatal("ready revision fabricated")
	}
}

func TestPlanRefusesNestedUnknownAndRecordsInertMetadata(t *testing.T) {
	unknown := []byte(`{"slug":"legacy","track":"feature","currentPhase":"implement","signOff":{"signed":false,"surprise":true}}`)
	if got := Plan(Request{Raw: unknown}); got.Status != StatusRefused {
		t.Fatalf("nested unknown accepted: %#v", got)
	}
	inert := []byte(`{"slug":"legacy","track":"feature","currentPhase":"implement","request":"original prompt"}`)
	got := Plan(Request{Raw: inert})
	if got.Status != StatusReady || len(got.LegacyUnknownPointers) != 1 ||
		got.LegacyUnknownPointers[0] != "/request" {
		t.Fatalf("inert metadata not recorded: %#v", got)
	}
}
