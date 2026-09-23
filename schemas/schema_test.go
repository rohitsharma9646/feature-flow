package schemas

import (
	"bytes"
	"os"
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
	if uri == "https://feature-flow.dev/schemas/doctor-result-v1.schema.json" ||
		uri == "https://feature-flow.dev/schemas/preflight-result-v1.schema.json" {
		capabilityDoc, capabilityErr := jsonschema.UnmarshalJSON(bytes.NewReader(CapabilityReportV1))
		if capabilityErr != nil {
			t.Fatal(capabilityErr)
		}
		if err := compiler.AddResource(
			"https://feature-flow.dev/schemas/capability-report-v1.schema.json",
			capabilityDoc,
		); err != nil {
			t.Fatal(err)
		}
	}
	if err := compiler.AddResource(uri, doc); err != nil {
		t.Fatal(err)
	}
	if _, err := compiler.Compile(uri); err != nil {
		t.Fatal(err)
	}
}

func TestWP4CorpusInstanceValid(t *testing.T) {
	doc, err := jsonschema.UnmarshalJSON(bytes.NewReader(WP4CorpusV1))
	if err != nil {
		t.Fatal(err)
	}
	compiler := jsonschema.NewCompiler()
	compiler.DefaultDraft(jsonschema.Draft2020)
	const uri = "https://feature-flow.dev/schemas/wp4-corpus-v1.schema.json"
	if err := compiler.AddResource(uri, doc); err != nil {
		t.Fatal(err)
	}
	schema, err := compiler.Compile(uri)
	if err != nil {
		t.Fatal(err)
	}
	raw, err := os.ReadFile("../integrity/testdata/adapter/v1/index.json")
	if err != nil {
		t.Fatal(err)
	}
	instance, err := jsonschema.UnmarshalJSON(bytes.NewReader(raw))
	if err != nil {
		t.Fatal(err)
	}
	if err := schema.Validate(instance); err != nil {
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
	compile(t, "https://feature-flow.dev/schemas/preflight-request-v1.schema.json", PreflightRequestV1)
	compile(t, "https://feature-flow.dev/schemas/preflight-result-v1.schema.json", PreflightResultV1)
	compile(t, "https://feature-flow.dev/schemas/capability-report-v1.schema.json", CapabilityReportV1)
	compile(t, "https://feature-flow.dev/schemas/wp4-corpus-v1.schema.json", WP4CorpusV1)
}
