package diagnostics

import (
	"encoding/json"
	"sort"

	protocolv1 "github.com/rohitsharma9646/feature-flow/integrity/protocol/v1"
)

type Diagnostic struct {
	Code        string `json:"code"`
	Severity    string `json:"severity"`
	JSONPointer string `json:"jsonPointer,omitempty"`
	Message     string `json:"message"`
	Remediation string `json:"remediation"`
	LogicalPath string `json:"logicalPath,omitempty"`
}

type document struct {
	Diagnostics []struct {
		Code        string `json:"code"`
		Severity    string `json:"severity"`
		Meaning     string `json:"meaning"`
		Remediation string `json:"remediation"`
	} `json:"diagnostics"`
}

var catalogue = load()

func load() map[string]Diagnostic {
	var doc document
	if err := json.Unmarshal(protocolv1.DiagnosticsJSON, &doc); err != nil {
		panic("invalid embedded diagnostic catalogue")
	}
	out := make(map[string]Diagnostic, len(doc.Diagnostics))
	for _, entry := range doc.Diagnostics {
		out[entry.Code] = Diagnostic{
			Code: entry.Code, Severity: entry.Severity,
			Message: entry.Meaning, Remediation: entry.Remediation,
		}
	}
	return out
}

func New(code, pointer string) Diagnostic {
	value, ok := catalogue[code]
	if !ok {
		panic("unknown diagnostic code: " + code)
	}
	value.JSONPointer = pointer
	return value
}

// All returns a defensive copy for compatibility tests and protocol tooling.
func All() map[string]Diagnostic {
	out := make(map[string]Diagnostic, len(catalogue))
	for code, item := range catalogue {
		out[code] = item
	}
	return out
}

func AtPath(code, pointer, logicalPath string) Diagnostic {
	value := New(code, pointer)
	value.LogicalPath = logicalPath
	return value
}

func Normalize(in []Diagnostic) []Diagnostic {
	unique := make(map[string]Diagnostic, len(in))
	for _, item := range in {
		unique[item.JSONPointer+"\x00"+item.Code+"\x00"+item.LogicalPath] = item
	}
	out := make([]Diagnostic, 0, len(unique))
	for _, item := range unique {
		out = append(out, item)
	}
	sort.Slice(out, func(i, j int) bool {
		if out[i].JSONPointer != out[j].JSONPointer {
			return out[i].JSONPointer < out[j].JSONPointer
		}
		if out[i].Code != out[j].Code {
			return out[i].Code < out[j].Code
		}
		return out[i].LogicalPath < out[j].LogicalPath
	})
	return out
}
