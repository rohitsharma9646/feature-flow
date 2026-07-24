package schemas

import (
	"bytes"
	"testing"

	jsonschema "github.com/santhosh-tekuri/jsonschema/v6"
)

func compile(t *testing.T, uri string, raw []byte) {
	t.Helper()
	doc, err := jsonschema.UnmarshalJSON(bytes.NewReader(raw))
	if err != nil {
		t.Fatal(err)
	}
	compiler := jsonschema.NewCompiler()
	compiler.DefaultDraft(jsonschema.Draft2020)
	if err := compiler.AddResource(uri, doc); err != nil {
		t.Fatal(err)
	}
	if _, err := compiler.Compile(uri); err != nil {
		t.Fatal(err)
	}
}

func TestSchemasCompileAsDraft2020(t *testing.T) {
	compile(t, "https://feature-flow.dev/schemas/manifest-v1.schema.json", ManifestV1)
	compile(t, "https://feature-flow.dev/schemas/golden-vector-v1.schema.json", GoldenVectorV1)
	compile(t, "https://feature-flow.dev/schemas/doctor-result-v1.schema.json", DoctorResultV1)
	compile(t, "https://feature-flow.dev/schemas/migration-plan-v1.schema.json", MigrationPlanV1)
	compile(t, "https://feature-flow.dev/schemas/code-revision-v1.schema.json", CodeRevisionV1)
	compile(t, "https://feature-flow.dev/schemas/attestation-v1.schema.json", AttestationV1)
	compile(t, "https://feature-flow.dev/schemas/wp3-corpus-v1.schema.json", WP3CorpusV1)
}
