package conformance

import (
	"bytes"
	"encoding/json"
	"os"
	"path/filepath"
	"testing"

	"github.com/rohitsharma9646/feature-flow/schemas"
	jsonschema "github.com/santhosh-tekuri/jsonschema/v6"
)

func TestAllVectors(t *testing.T) {
	root := filepath.Join("..", "testdata")
	index, err := Load(root)
	if err != nil {
		t.Fatal(err)
	}
	if index.VectorVersion != 1 || len(index.Vectors) != 12 {
		t.Fatalf("version=%d vectors=%d", index.VectorVersion, len(index.Vectors))
	}
	seen := map[string]bool{}
	for _, vector := range index.Vectors {
		if seen[vector.ID] {
			t.Fatalf("duplicate vector %s", vector.ID)
		}
		seen[vector.ID] = true
		if err := Run(root, vector); err != nil {
			t.Error(err)
		}
	}
}

func TestVectorIndexSchema(t *testing.T) {
	raw, err := os.ReadFile(filepath.Join("..", "testdata", "vectors", "v1", "index.json"))
	if err != nil {
		t.Fatal(err)
	}
	var value any
	if err := json.Unmarshal(raw, &value); err != nil {
		t.Fatal(err)
	}
	doc, err := jsonschema.UnmarshalJSON(bytes.NewReader(schemas.GoldenVectorV1))
	if err != nil {
		t.Fatal(err)
	}
	compiler := jsonschema.NewCompiler()
	compiler.DefaultDraft(jsonschema.Draft2020)
	const uri = "https://feature-flow.dev/schemas/golden-vector-v1.schema.json"
	if err := compiler.AddResource(uri, doc); err != nil {
		t.Fatal(err)
	}
	schema, err := compiler.Compile(uri)
	if err != nil {
		t.Fatal(err)
	}
	if err := schema.Validate(value); err != nil {
		t.Fatal(err)
	}
}
