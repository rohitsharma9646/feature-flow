package classifier

import (
	"github.com/rohitsharma9646/feature-flow/integrity/diagnostics"
	jsonschema "github.com/santhosh-tekuri/jsonschema/v6"
)

var catalogue = diagnostics.All()

func diagnostic(code, pointer string) Diagnostic {
	return diagnostics.New(code, pointer)
}

func normalize(in []Diagnostic) []Diagnostic { return diagnostics.Normalize(in) }

func schemaDiagnostics(err *jsonschema.ValidationError) []Diagnostic {
	var out []Diagnostic
	var visit func(*jsonschema.ValidationError)
	visit = func(current *jsonschema.ValidationError) {
		if len(current.Causes) != 0 {
			for _, cause := range current.Causes {
				visit(cause)
			}
			return
		}
		code := "FFI_SCHEMA_INVALID"
		path := current.ErrorKind.KeywordPath()
		if len(path) != 0 && path[len(path)-1] == "enum" {
			code = "FFI_ENUM_INVALID"
		}
		out = append(out, diagnostic(code, jsonPointer(current.InstanceLocation)))
	}
	visit(err)
	return diagnostics.Normalize(out)
}
