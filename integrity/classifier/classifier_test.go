package classifier

import "testing"

func TestClassificationBranches(t *testing.T) {
	tests := []struct {
		name string
		raw  string
		want ManifestClass
	}{
		{"malformed", `{`, Corrupt},
		{"non-object", `[]`, Corrupt},
		{"duplicate key", `{"schemaVersion":1,"schemaVersion":2}`, Corrupt},
		{"legacy", `{}`, LegacyUnversioned},
		{"typed invalid", `{"schemaVersion":"1"}`, CurrentStructuralInvalid},
		{"null invalid", `{"schemaVersion":null}`, CurrentStructuralInvalid},
		{"bool invalid", `{"schemaVersion":true}`, CurrentStructuralInvalid},
		{"decimal invalid", `{"schemaVersion":1.0}`, CurrentStructuralInvalid},
		{"exponent invalid", `{"schemaVersion":1e0}`, CurrentStructuralInvalid},
		{"arbitrarily large future", `{"schemaVersion":999999999999999999999999}`, UnsupportedFuture},
		{"arbitrarily small old", `{"schemaVersion":-999999999999999999999999}`, UnsupportedOld},
		{"future", `{"schemaVersion":2}`, UnsupportedFuture},
		{"old", `{"schemaVersion":0}`, UnsupportedOld},
		{"current invalid", `{"schemaVersion":1}`, CurrentStructuralInvalid},
	}
	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			if got := Classify([]byte(tt.raw)).Classification; got != tt.want {
				t.Fatalf("got %s want %s", got, tt.want)
			}
		})
	}
}

func TestDeterministic(t *testing.T) {
	raw := []byte(`{"schemaVersion":1}`)
	a, b := Classify(raw), Classify(raw)
	if a.Classification != b.Classification || a.Diagnostics[0] != b.Diagnostics[0] {
		t.Fatalf("non-deterministic result: %#v %#v", a, b)
	}
}

func FuzzClassifierDeterministic(f *testing.F) {
	for _, seed := range []string{
		`{`,
		`{}`,
		`{"schemaVersion":1}`,
		`{"schemaVersion":2}`,
		string(fixture(f, "current-feature.json")),
	} {
		f.Add([]byte(seed))
	}
	f.Fuzz(func(t *testing.T, raw []byte) {
		first := Classify(raw)
		second := Classify(raw)
		a, err := MarshalResult(first)
		if err != nil {
			t.Fatal(err)
		}
		b, err := MarshalResult(second)
		if err != nil {
			t.Fatal(err)
		}
		if string(a) != string(b) {
			t.Fatalf("non-deterministic output")
		}
	})
}
