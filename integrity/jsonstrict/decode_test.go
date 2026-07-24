package jsonstrict

import "testing"

func TestDecodeRejectsDuplicateAndTrailingJSON(t *testing.T) {
	for _, raw := range []string{`{"a":1,"a":2}`, `{"a":1} {}`} {
		if _, err := Decode([]byte(raw)); err == nil {
			t.Fatalf("Decode(%q) succeeded", raw)
		}
	}
}

func TestDecodePreservesNumbers(t *testing.T) {
	value, err := Decode([]byte(`{"n":9007199254740993}`))
	if err != nil {
		t.Fatal(err)
	}
	if got := value.(map[string]any)["n"].(interface{ String() string }).String(); got != "9007199254740993" {
		t.Fatalf("number = %s", got)
	}
}
