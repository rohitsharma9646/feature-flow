package wp3

import (
	"encoding/json"
	"testing"
)

func TestEvaluateTransitionFactsRequiresFeatureSignOffBeforeImplement(t *testing.T) {
	input := TransitionFacts{
		Operation:      TransitionManifestMutation,
		Track:          "feature",
		Tier:           "full",
		ProposedPhase:  "implement",
		ImplementState: "in_progress",
		SignedOff:      false,
	}
	result := EvaluateTransitionFacts(input)
	if result.Allowed || len(result.Codes) != 1 || result.Codes[0] != "FFI_TERMINAL_INCONSISTENT" {
		t.Fatalf("result = %#v", result)
	}
	input.SignedOff = true
	if result := EvaluateTransitionFacts(input); !result.Allowed {
		t.Fatalf("signed result = %#v", result)
	}
}

func TestEvaluateTransitionFactsRequiresLiteBugDiagnosis(t *testing.T) {
	input := TransitionFacts{
		Operation:      TransitionManifestMutation,
		Track:          "bugfix",
		Tier:           "lite",
		ProposedPhase:  "implement",
		ImplementState: "in_progress",
		DiagnoseState:  "in_progress",
	}
	if EvaluateTransitionFacts(input).Allowed {
		t.Fatal("unsigned lite diagnosis allowed implement")
	}
	input.DiagnoseState = "complete"
	if result := EvaluateTransitionFacts(input); !result.Allowed {
		t.Fatalf("confirmed result = %#v", result)
	}
}

func TestEvaluateTransitionFactsDelegatesReadinessAndTerminalCodes(t *testing.T) {
	readiness := EvaluateTransitionFacts(TransitionFacts{
		Operation:        TransitionCodeMutation,
		Tier:             "full",
		RevisionReady:    false,
		ScopeDrift:       true,
		RevisionMismatch: true,
	})
	if readiness.Allowed || len(readiness.Codes) != 3 {
		t.Fatalf("readiness = %#v", readiness)
	}

	terminal := EvaluateTransitionFacts(TransitionFacts{
		Operation:       TransitionTerminal,
		TerminalAllowed: false,
		TerminalCodes:   []string{"FFI_ATTESTATION_STALE", "FFI_TERMINAL_INCONSISTENT"},
	})
	if terminal.Allowed || len(terminal.Codes) != 2 {
		t.Fatalf("terminal = %#v", terminal)
	}
}

func TestTerminalMetadataOnlyRejectsAssuranceOrArtifactMutation(t *testing.T) {
	current := map[string]any{
		"currentPhase": "verify", "updatedAt": "old", "closedAt": nil, "lock": map[string]any{"owner": "x"},
		"artifacts": map[string]any{"verify": "verify.md"},
		"assurance": map[string]any{"verification": "attestation"},
	}
	proposed := cloneForTest(current)
	proposed["currentPhase"] = "done"
	proposed["updatedAt"] = "new"
	proposed["closedAt"] = "2026-08-03T00:00:00Z"
	proposed["lock"] = nil
	if !terminalMetadataOnly(current, proposed) {
		t.Fatal("terminal-only metadata transition rejected")
	}
	proposed = cloneForTest(proposed)
	proposed["artifacts"].(map[string]any)["verify"] = "other.md"
	if terminalMetadataOnly(current, proposed) {
		t.Fatal("artifact mutation accepted with terminal transition")
	}
}

func cloneForTest(value map[string]any) map[string]any {
	raw, _ := json.Marshal(value)
	var out map[string]any
	_ = json.Unmarshal(raw, &out)
	return out
}
