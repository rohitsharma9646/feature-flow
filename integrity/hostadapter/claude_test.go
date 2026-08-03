package hostadapter

import (
	"encoding/json"
	"os"
	"path/filepath"
	"strings"
	"testing"

	"github.com/rohitsharma9646/feature-flow/integrity/preflight"
)

func TestDecodeClaudeEditReconstructsProposedManifest(t *testing.T) {
	repository := t.TempDir()
	runRoot := filepath.Join(repository, ".feature-flow", "run")
	if err := os.MkdirAll(runRoot, 0o700); err != nil {
		t.Fatal(err)
	}
	target := filepath.Join(runRoot, "manifest.json")
	if err := os.WriteFile(target, []byte(`{"currentPhase":"plan"}`), 0o600); err != nil {
		t.Fatal(err)
	}
	raw := []byte(`{
	  "hook_event_name":"PreToolUse",
	  "cwd":` + quote(repository) + `,
	  "tool_name":"Edit",
	  "tool_input":{"file_path":` + quote(target) + `,
	    "old_string":"\"plan\"","new_string":"\"implement\"","replace_all":false}
	}`)
	decoded, err := DecodeClaude(raw)
	if err != nil {
		t.Fatal(err)
	}
	if string(decoded.Request.ProposedManifest) != `{"currentPhase":"implement"}` {
		t.Fatalf("proposed = %s", decoded.Request.ProposedManifest)
	}
}

func TestDecodeClaudeWriteNormalizesCanonicalManifest(t *testing.T) {
	repository := t.TempDir()
	target := filepath.Join(repository, ".feature-flow", "run", "manifest.json")
	raw := []byte(`{
	  "hook_event_name":"PreToolUse",
	  "cwd":` + quote(repository) + `,
	  "tool_name":"Write",
	  "tool_input":{"file_path":` + quote(target) + `,"content":{"schemaVersion":1}}
	}`)
	decoded, err := DecodeClaude(raw)
	if err != nil {
		t.Fatal(err)
	}
	if !decoded.Recognized || decoded.Request.Host != preflight.HostClaude ||
		decoded.Request.Target != ".feature-flow/run/manifest.json" ||
		decoded.Request.Context.RunRoot != filepath.Join(repository, ".feature-flow", "run") {
		t.Fatalf("decoded = %#v", decoded)
	}
	if string(decoded.Request.ProposedManifest) != `{"schemaVersion":1}` {
		t.Fatalf("proposed = %s", decoded.Request.ProposedManifest)
	}
}

func TestDecodeClaudeUnrelatedWriteDoesNotInspectContent(t *testing.T) {
	repository := t.TempDir()
	raw := []byte(`{
	  "hook_event_name":"PreToolUse",
	  "cwd":` + quote(repository) + `,
	  "tool_name":"Write",
	  "tool_input":{"file_path":` + quote(filepath.Join(repository, "notes.txt")) + `,
	    "content":".feature-flow/run/manifest.json"}
	}`)
	decoded, err := DecodeClaude(raw)
	if err != nil {
		t.Fatal(err)
	}
	if decoded.Recognized {
		t.Fatalf("decoded = %#v", decoded)
	}
}

func TestDecodeClaudeRecognizedEditWithoutFullContentFailsClosed(t *testing.T) {
	repository := t.TempDir()
	raw := []byte(`{
	  "hook_event_name":"PreToolUse",
	  "cwd":` + quote(repository) + `,
	  "tool_name":"Edit",
	  "tool_input":{"file_path":` + quote(filepath.Join(repository, ".feature-flow", "run", "manifest.json")) + `,
	    "old_string":"x","new_string":"y"}
	}`)
	if _, err := DecodeClaude(raw); err == nil {
		t.Fatal("DecodeClaude() accepted an indeterminate Edit")
	}
}

func TestEncodeClaudeDecisionIsSilentOrDeniesWithCodes(t *testing.T) {
	unrelated, err := EncodeClaude(preflight.Decision{
		SchemaVersion: 1, Applicable: false, Allowed: true,
	})
	if err != nil || len(unrelated) != 0 {
		t.Fatalf("unrelated = %q err=%v", unrelated, err)
	}
	denied, err := EncodeClaude(preflight.Decision{
		SchemaVersion: 1, Applicable: true, Allowed: false,
		Diagnostics: []preflight.Diagnostic{
			{Code: "FFI_CAPABILITY_DEGRADED", Severity: preflight.SeverityError},
		},
	})
	if err != nil {
		t.Fatal(err)
	}
	if !strings.Contains(string(denied), `"permissionDecision":"deny"`) ||
		!strings.Contains(string(denied), "FFI_CAPABILITY_DEGRADED") {
		t.Fatalf("denied = %s", denied)
	}
}

func quote(value string) string {
	raw, _ := json.Marshal(value)
	return string(raw)
}
