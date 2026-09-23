package preflight

import (
	"encoding/json"
	"os"
	"path/filepath"
	"testing"
)

func TestRuntimeAuthorityAllowsPostTerminalDeliveryAndClose(t *testing.T) {
	current, err := os.ReadFile("../testdata/manifests/terminal.json")
	if err != nil {
		t.Fatal(err)
	}
	var document map[string]any
	if err := json.Unmarshal(current, &document); err != nil {
		t.Fatal(err)
	}
	document["closedAt"] = nil
	open, _ := json.Marshal(document)
	repository := t.TempDir()
	runRoot := filepath.Join(repository, ".feature-flow", "terminal")
	if err := os.MkdirAll(runRoot, 0o700); err != nil {
		t.Fatal(err)
	}
	if err := os.WriteFile(filepath.Join(runRoot, "manifest.json"), open, 0o600); err != nil {
		t.Fatal(err)
	}
	request := Request{
		Operation: OperationManifestMutation,
		Target:    ".feature-flow/terminal/manifest.json",
		Context:   TrustedContext{RepositoryRoot: repository, RunRoot: runRoot},
	}

	delivered := cloneDocument(t, document)
	delivered["updatedAt"] = "2026-07-24T00:00:00Z"
	delivered["phases"].(map[string]any)["deliver"] = map[string]any{"status": "complete", "artifact": "delivery.md"}
	delivered["artifacts"].(map[string]any)["delivery"] = "delivery.md"
	request.ProposedManifest, _ = json.Marshal(delivered)
	if codes, err := RuntimeAuthority(request); err != nil || len(codes) != 0 {
		t.Fatalf("deliver codes=%v err=%v, want allow", codes, err)
	}

	closed := cloneDocument(t, document)
	closed["closedAt"] = "2026-07-24T00:00:00Z"
	request.ProposedManifest, _ = json.Marshal(closed)
	if codes, err := RuntimeAuthority(request); err != nil || len(codes) != 0 {
		t.Fatalf("close codes=%v err=%v, want allow", codes, err)
	}

	tampered := cloneDocument(t, delivered)
	tampered["signOff"].(map[string]any)["signed"] = false
	request.ProposedManifest, _ = json.Marshal(tampered)
	if codes, err := RuntimeAuthority(request); err == nil && len(codes) == 0 {
		t.Fatal("post-terminal non-delivery mutation allowed")
	}
}

func cloneDocument(t *testing.T, value map[string]any) map[string]any {
	t.Helper()
	raw, err := json.Marshal(value)
	if err != nil {
		t.Fatal(err)
	}
	var out map[string]any
	if err := json.Unmarshal(raw, &out); err != nil {
		t.Fatal(err)
	}
	return out
}
