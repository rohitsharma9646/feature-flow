package classifier

import (
	"bytes"
	"encoding/json"
	"errors"
	"io"
	"strings"

	"github.com/rohitsharma9646/feature-flow/schemas"
	jsonschema "github.com/santhosh-tekuri/jsonschema/v6"
)

const MaxManifestBytes = 4 << 20

func one(class ManifestClass, code string) Result {
	pointer := ""
	if code == "FFI_SCHEMA_VERSION_UNSUPPORTED" || code == "FFI_LEGACY_MIGRATION_REQUIRED" {
		pointer = "/schemaVersion"
	}
	return Result{ProtocolVersion: 1, Classification: class, Diagnostics: []Diagnostic{diagnostic(code, pointer)}}
}

func Classify(raw []byte) Result {
	if len(raw) > MaxManifestBytes {
		return one(Corrupt, "FFI_INVALID_JSON")
	}
	value, err := decodeStrict(raw)
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
		return Result{1, CurrentStructuralInvalid, []Diagnostic{d}}
	}
	v, err := n.Int64()
	if err != nil {
		d := diagnostic("FFI_SCHEMA_INVALID", "/schemaVersion")
		return Result{1, CurrentStructuralInvalid, []Diagnostic{d}}
	}
	if v > 1 {
		return one(UnsupportedFuture, "FFI_SCHEMA_VERSION_UNSUPPORTED")
	}
	if v < 1 {
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
			return Result{1, CurrentStructuralInvalid, schemaDiagnostics(ve)}
		}
		return one(CurrentStructuralInvalid, "FFI_SCHEMA_INVALID")
	}
	return Result{ProtocolVersion: 1, Classification: CurrentStructuralValid, Diagnostics: []Diagnostic{}}
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

func decodeStrict(raw []byte) (any, error) {
	check := json.NewDecoder(bytes.NewReader(raw))
	check.UseNumber()
	if err := checkJSONValue(check); err != nil {
		return nil, err
	}
	if _, err := check.Token(); err != io.EOF {
		return nil, errors.New("trailing JSON")
	}
	dec := json.NewDecoder(bytes.NewReader(raw))
	dec.UseNumber()
	var value any
	if err := dec.Decode(&value); err != nil {
		return nil, err
	}
	if err := dec.Decode(new(any)); err != io.EOF {
		return nil, errors.New("trailing JSON")
	}
	return value, nil
}

func checkJSONValue(dec *json.Decoder) error {
	token, err := dec.Token()
	if err != nil {
		return err
	}
	delim, ok := token.(json.Delim)
	if !ok {
		return nil
	}
	switch delim {
	case '{':
		seen := make(map[string]struct{})
		for dec.More() {
			keyToken, err := dec.Token()
			if err != nil {
				return err
			}
			key, ok := keyToken.(string)
			if !ok {
				return errors.New("object key is not a string")
			}
			if _, exists := seen[key]; exists {
				return errors.New("duplicate object key")
			}
			seen[key] = struct{}{}
			if err := checkJSONValue(dec); err != nil {
				return err
			}
		}
		end, err := dec.Token()
		if err != nil || end != json.Delim('}') {
			return errors.New("unterminated object")
		}
	case '[':
		for dec.More() {
			if err := checkJSONValue(dec); err != nil {
				return err
			}
		}
		end, err := dec.Token()
		if err != nil || end != json.Delim(']') {
			return errors.New("unterminated array")
		}
	default:
		return errors.New("unexpected delimiter")
	}
	return nil
}
