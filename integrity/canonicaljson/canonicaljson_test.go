package canonicaljson

import (
	"strings"
	"testing"
)

func TestMarshalSortsObjectKeysAndPreservesArrayOrder(t *testing.T) {
	got, err := Marshal(map[string]any{
		"z": []any{"second", "first"},
		"a": map[string]any{"β": "utf8", "b": true},
	})
	if err != nil {
		t.Fatal(err)
	}
	want := `{"a":{"b":true,"β":"utf8"},"z":["second","first"]}`
	if string(got) != want {
		t.Fatalf("canonical bytes = %q, want %q", got, want)
	}
}

func TestMarshalRejectsFloatsAndNonStringMaps(t *testing.T) {
	for name, value := range map[string]any{
		"float":          1.5,
		"non-string-map": map[int]string{1: "x"},
	} {
		t.Run(name, func(t *testing.T) {
			if _, err := Marshal(value); err == nil {
				t.Fatal("expected rejection")
			}
		})
	}
}

func TestMarshalRejectsInvalidUTF8(t *testing.T) {
	if _, err := Marshal(string([]byte{0xff})); err == nil ||
		!strings.Contains(err.Error(), "UTF-8") {
		t.Fatalf("expected UTF-8 error, got %v", err)
	}
}
