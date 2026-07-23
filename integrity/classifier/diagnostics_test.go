package classifier

import "testing"

func TestEveryEmittedDiagnosticComesFromCatalogue(t *testing.T) {
	cases := [][]byte{
		[]byte(`{`),
		[]byte(`{}`),
		[]byte(`{"schemaVersion":2}`),
		[]byte(`{"schemaVersion":1}`),
	}
	for _, raw := range cases {
		for _, item := range Classify(raw).Diagnostics {
			canonical, exists := catalogue[item.Code]
			if !exists {
				t.Fatalf("unknown code %s", item.Code)
			}
			if item.Message != canonical.Message || item.Remediation != canonical.Remediation {
				t.Fatalf("non-catalogue text for %s", item.Code)
			}
		}
	}
}

func TestDiagnosticNormalization(t *testing.T) {
	input := []Diagnostic{
		diagnostic("FFI_SCHEMA_INVALID", "/z"),
		diagnostic("FFI_ENUM_INVALID", "/a"),
		diagnostic("FFI_ENUM_INVALID", "/a"),
	}
	got := normalize(input)
	if len(got) != 2 || got[0].JSONPointer != "/a" || got[1].JSONPointer != "/z" {
		t.Fatalf("got %#v", got)
	}
}
