package classifier

import (
	"bytes"
	"encoding/json"
	"errors"
	"math/big"
	"strings"

	"github.com/rohitsharma9646/feature-flow/integrity/jsonstrict"
	protocolv1 "github.com/rohitsharma9646/feature-flow/integrity/protocol/v1"
	"github.com/rohitsharma9646/feature-flow/schemas"
	jsonschema "github.com/santhosh-tekuri/jsonschema/v6"
)

const MaxManifestBytes = 4 << 20

func one(class ManifestClass, code string) Result {
	pointer := ""
	if code == "FFI_SCHEMA_VERSION_UNSUPPORTED" || code == "FFI_LEGACY_MIGRATION_REQUIRED" {
		pointer = "/schemaVersion"
	}
	return Result{ProtocolVersion: protocolv1.ProtocolVersion, Classification: class, Diagnostics: []Diagnostic{diagnostic(code, pointer)}}
}

func Classify(raw []byte) Result {
	if len(raw) > MaxManifestBytes {
		return one(Corrupt, "FFI_INVALID_JSON")
	}
	value, err := jsonstrict.Decode(raw)
	if err != nil {
		return one(Corrupt, "FFI_INVALID_JSON")
	}
	obj, ok := value.(map[string]any)
	if !ok {
		return one(Corrupt, "FFI_INVALID_JSON")
	}
	version, exists := obj["schemaVersion"]
	if !exists {
		return one(LegacyUnversioned, "FFI_LEGACY_MIGRATION_REQUIRED")
	}
	n, ok := version.(json.Number)
	if !ok || strings.ContainsAny(n.String(), ".eE") {
		d := diagnostic("FFI_SCHEMA_INVALID", "/schemaVersion")
		return Result{protocolv1.ProtocolVersion, CurrentStructuralInvalid, []Diagnostic{d}}
	}
	var v big.Int
	if _, ok := v.SetString(n.String(), 10); !ok {
		d := diagnostic("FFI_SCHEMA_INVALID", "/schemaVersion")
		return Result{protocolv1.ProtocolVersion, CurrentStructuralInvalid, []Diagnostic{d}}
	}
	manifestVersion := big.NewInt(protocolv1.ManifestVersion)
	if v.Cmp(manifestVersion) > 0 {
		return one(UnsupportedFuture, "FFI_SCHEMA_VERSION_UNSUPPORTED")
	}
	if v.Cmp(manifestVersion) < 0 {
		return one(UnsupportedOld, "FFI_SCHEMA_VERSION_UNSUPPORTED")
	}
	compiler := jsonschema.NewCompiler()
	compiler.DefaultDraft(jsonschema.Draft2020)
	doc, err := jsonschema.UnmarshalJSON(bytes.NewReader(schemas.ManifestV1))
	if err != nil || compiler.AddResource("https://feature-flow.dev/schemas/manifest-v1.schema.json", doc) != nil {
		return one(CurrentStructuralInvalid, "FFI_SCHEMA_INVALID")
	}
	schema, err := compiler.Compile("https://feature-flow.dev/schemas/manifest-v1.schema.json")
	if err != nil {
		return one(CurrentStructuralInvalid, "FFI_SCHEMA_INVALID")
	}
	if err := schema.Validate(value); err != nil {
		if ve := new(jsonschema.ValidationError); errors.As(err, &ve) {
			return Result{protocolv1.ProtocolVersion, CurrentStructuralInvalid, schemaDiagnostics(ve)}
		}
		return one(CurrentStructuralInvalid, "FFI_SCHEMA_INVALID")
	}
	return Result{ProtocolVersion: protocolv1.ProtocolVersion, Classification: CurrentStructuralValid, Diagnostics: []Diagnostic{}}
}

func jsonPointer(parts []string) string {
	if len(parts) == 0 {
		return ""
	}
	escaped := make([]string, len(parts))
	for i, part := range parts {
		part = strings.ReplaceAll(part, "~", "~0")
		escaped[i] = strings.ReplaceAll(part, "/", "~1")
	}
	return "/" + strings.Join(escaped, "/")
}
