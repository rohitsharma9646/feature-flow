package classifier

import (
	"encoding/json"
	"sort"
	"strings"

	protocolv1 "github.com/rohitsharma9646/feature-flow/integrity/protocol/v1"
	jsonschema "github.com/santhosh-tekuri/jsonschema/v6"
)

type catalogueDocument struct {
	CatalogVersion int `json:"catalogVersion"`
	Diagnostics    []struct {
		Code        string `json:"code"`
		Severity    string `json:"severity"`
		Meaning     string `json:"meaning"`
		Remediation string `json:"remediation"`
	} `json:"diagnostics"`
}

var catalogue = loadCatalogue()

func loadCatalogue() map[string]Diagnostic {
	var document catalogueDocument
	if err := json.Unmarshal(protocolv1.DiagnosticsJSON, &document); err != nil {
		panic("invalid embedded diagnostic catalogue")
	}
	out := make(map[string]Diagnostic, len(document.Diagnostics))
	for _, entry := range document.Diagnostics {
		out[entry.Code] = Diagnostic{
			Code: entry.Code, Severity: entry.Severity,
			Message: entry.Meaning, Remediation: entry.Remediation,
		}
	}
	return out
}

func diagnostic(code, pointer string) Diagnostic {
	value := catalogue[code]
	value.JSONPointer = pointer
	return value
}

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
	return normalize(out)
}

func normalize(in []Diagnostic) []Diagnostic {
	unique := make(map[string]Diagnostic, len(in))
	for _, item := range in {
		unique[item.JSONPointer+"\x00"+item.Code] = item
	}
	out := make([]Diagnostic, 0, len(unique))
	for _, item := range unique {
		out = append(out, item)
	}
	sort.Slice(out, func(i, j int) bool {
		if out[i].JSONPointer == out[j].JSONPointer {
			return out[i].Code < out[j].Code
		}
		return strings.Compare(out[i].JSONPointer, out[j].JSONPointer) < 0
	})
	return out
}
