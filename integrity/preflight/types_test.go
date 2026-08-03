package preflight

import (
	"bytes"
	"encoding/json"
	"strings"
	"testing"
)

func validRequest() Request {
	return Request{
		SchemaVersion: SchemaVersion,
		Host:          HostDirect,
		Event:         EventCommandPreflight,
		Operation:     OperationManifestMutation,
		ToolClass:     ToolClassFileWrite,
		Target:        ".feature-flow/example/manifest.json",
		Context: TrustedContext{
			RepositoryRoot: "/workspace",
			RunRoot:        "/workspace/.feature-flow/example",
		},
		ProposedManifest: json.RawMessage(`{"track":"feature"}`),
		RequiredCapabilities: []CapabilityName{
			CapabilityKernel,
			CapabilitySchema,
		},
		EnforcementMode: EnforcementEnforce,
	}
}

func TestRequestValidateAcceptsHostNeutralV1(t *testing.T) {
	request := validRequest()
	if err := request.Validate(); err != nil {
		t.Fatalf("Validate() error = %v", err)
	}
}

func TestRequestValidateRejectsHostSyntaxAndAmbiguousFields(t *testing.T) {
	cases := []struct {
		name   string
		mutate func(*Request)
	}{
		{"version", func(r *Request) { r.SchemaVersion = 2 }},
		{"host", func(r *Request) { r.Host = "claude-code-payload" }},
		{"event", func(r *Request) { r.Event = "PreToolUse" }},
		{"operation", func(r *Request) { r.Operation = "" }},
		{"tool class", func(r *Request) { r.ToolClass = "Write" }},
		{"absolute target", func(r *Request) { r.Target = "/tmp/manifest.json" }},
		{"traversal target", func(r *Request) { r.Target = "../manifest.json" }},
		{"relative repository", func(r *Request) { r.Context.RepositoryRoot = "workspace" }},
		{"relative run root", func(r *Request) { r.Context.RunRoot = ".feature-flow/example" }},
		{"mode", func(r *Request) { r.EnforcementMode = "disabled" }},
		{"duplicate capability", func(r *Request) {
			r.RequiredCapabilities = []CapabilityName{CapabilityKernel, CapabilityKernel}
		}},
		{"oversized manifest", func(r *Request) {
			r.ProposedManifest = json.RawMessage(`"` + strings.Repeat("x", MaxManifestBytes) + `"`)
		}},
	}
	for _, tc := range cases {
		t.Run(tc.name, func(t *testing.T) {
			request := validRequest()
			tc.mutate(&request)
			if err := request.Validate(); err == nil {
				t.Fatal("Validate() error = nil, want rejection")
			}
		})
	}
}

func TestDecodeRequestIsStrictAndBounded(t *testing.T) {
	raw, err := json.Marshal(validRequest())
	if err != nil {
		t.Fatal(err)
	}
	decoded, err := DecodeRequest(raw)
	if err != nil {
		t.Fatalf("DecodeRequest() error = %v", err)
	}
	if decoded.Host != HostDirect {
		t.Fatalf("Host = %q, want %q", decoded.Host, HostDirect)
	}

	withUnknown := bytes.TrimSuffix(raw, []byte("}"))
	withUnknown = append(withUnknown, []byte(`,"tool_input":{"file_path":"forbidden"}}`)...)
	if _, err := DecodeRequest(withUnknown); err == nil {
		t.Fatal("DecodeRequest() accepted host-specific unknown field")
	}
	if _, err := DecodeRequest(append(raw, '\n', '{', '}')); err == nil {
		t.Fatal("DecodeRequest() accepted trailing JSON")
	}
	if _, err := DecodeRequest(bytes.Repeat([]byte(" "), MaxRequestBytes+1)); err == nil {
		t.Fatal("DecodeRequest() accepted oversized input")
	}
}

func TestDecisionMarshalIsByteStable(t *testing.T) {
	decision := Decision{
		SchemaVersion: SchemaVersion,
		Applicable:    true,
		Allowed:       false,
		Diagnostics: []Diagnostic{
			{Code: "FFI_CAPABILITY_DEGRADED", Severity: SeverityError},
		},
	}
	first, err := MarshalDecision(decision)
	if err != nil {
		t.Fatal(err)
	}
	second, err := MarshalDecision(decision)
	if err != nil {
		t.Fatal(err)
	}
	if !bytes.Equal(first, second) {
		t.Fatalf("MarshalDecision() unstable:\n%s\n%s", first, second)
	}
	want := "{\"schemaVersion\":1,\"applicable\":true,\"allowed\":false,\"diagnostics\":[{\"code\":\"FFI_CAPABILITY_DEGRADED\",\"severity\":\"error\"}]}\n"
	if string(first) != want {
		t.Fatalf("MarshalDecision() = %s, want %s", first, want)
	}
}

func TestDecisionValidateRejectsInvalidOrDuplicateDiagnostics(t *testing.T) {
	for _, decision := range []Decision{
		{SchemaVersion: 2},
		{SchemaVersion: 1, Applicable: false, Allowed: false},
		{SchemaVersion: 1, Applicable: true, Allowed: true, Diagnostics: []Diagnostic{{Code: "", Severity: SeverityError}}},
		{SchemaVersion: 1, Applicable: true, Diagnostics: []Diagnostic{
			{Code: "FFI_CAPABILITY_DEGRADED", Severity: SeverityError},
			{Code: "FFI_CAPABILITY_DEGRADED", Severity: SeverityError},
		}},
	} {
		if err := decision.Validate(); err == nil {
			t.Fatalf("Validate() accepted %#v", decision)
		}
	}
}
