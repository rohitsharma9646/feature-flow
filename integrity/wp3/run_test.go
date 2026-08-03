package wp3

import "testing"

func TestTerminalSemanticValidationRequiresFullBugfixPlanAndRedGreen(t *testing.T) {
	document := map[string]any{
		"track": "bugfix", "tier": "full", "currentPhase": "review",
		"signOff":   map[string]any{"signed": true},
		"artifacts": map[string]any{"review": "review.md", "verify": "verify.md"},
		"phases": map[string]any{
			"diagnose":  map[string]any{"status": "complete", "artifact": nil},
			"implement": map[string]any{"status": "complete", "artifact": nil},
			"review":    map[string]any{"status": "complete", "artifact": "review.md"},
			"verify":    map[string]any{"status": "complete", "artifact": "verify.md"},
		},
	}
	if terminalSemanticallyValid(document, true) {
		t.Fatal("full bugfix without plan and RED/GREEN was accepted")
	}
	document["phases"].(map[string]any)["plan"] = map[string]any{"status": "complete", "artifact": nil}
	document["bugfix"] = map[string]any{
		"red":   map[string]any{"exit": float64(1), "evidence": "evidence:red"},
		"green": map[string]any{"exit": float64(0), "evidence": "evidence:green"},
	}
	if !terminalSemanticallyValid(document, true) {
		t.Fatal("complete full bugfix was rejected")
	}
	delete(document["phases"].(map[string]any), "plan")
	document["tier"] = "lite"
	document["signOff"].(map[string]any)["signed"] = false
	if !terminalSemanticallyValid(document, true) {
		t.Fatal("complete lite bugfix incorrectly required a plan or sign-off")
	}
	document["bugfix"].(map[string]any)["red"].(map[string]any)["exit"] = float64(0)
	if terminalSemanticallyValid(document, true) {
		t.Fatal("bugfix without a failing RED record was accepted")
	}
}
