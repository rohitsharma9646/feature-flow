package classifier

import (
	"bytes"
	"testing"
)

func TestCanonicalOutput(t *testing.T) {
	result := Classify([]byte(`{"schemaVersion":2}`))
	first, err := MarshalResult(result)
	if err != nil {
		t.Fatal(err)
	}
	second, err := MarshalResult(Classify([]byte(`{"schemaVersion":2}`)))
	if err != nil {
		t.Fatal(err)
	}
	if !bytes.Equal(first, second) || len(first) == 0 || first[len(first)-1] != '\n' {
		t.Fatalf("non-canonical output %q %q", first, second)
	}
}
