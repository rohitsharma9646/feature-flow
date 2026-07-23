package conformance

import (
	"encoding/json"
	"fmt"
	"os"
	"path/filepath"

	"github.com/rohitsharma9646/feature-flow/integrity/classifier"
)

type Index struct {
	VectorVersion int      `json:"vectorVersion"`
	Vectors       []Vector `json:"vectors"`
}

type Vector struct {
	ID                      string   `json:"id"`
	ProtocolVersion         int      `json:"protocolVersion"`
	InputRef                string   `json:"inputRef"`
	ExpectedClassification  string   `json:"expectedClassification"`
	ExpectedDiagnosticCodes []string `json:"expectedDiagnosticCodes"`
	Applicability           []string `json:"applicability"`
	SourcePackageParity     bool     `json:"sourcePackageParity"`
}

func Load(root string) (Index, error) {
	raw, err := os.ReadFile(filepath.Join(root, "vectors", "v1", "index.json"))
	if err != nil {
		return Index{}, err
	}
	var index Index
	if err := json.Unmarshal(raw, &index); err != nil {
		return Index{}, err
	}
	return index, nil
}

func Run(root string, vector Vector) error {
	raw, err := os.ReadFile(filepath.Join(root, vector.InputRef))
	if err != nil {
		return err
	}
	result := classifier.Classify(raw)
	if string(result.Classification) != vector.ExpectedClassification {
		return fmt.Errorf("%s: class %s, want %s", vector.ID, result.Classification, vector.ExpectedClassification)
	}
	if len(result.Diagnostics) != len(vector.ExpectedDiagnosticCodes) {
		return fmt.Errorf("%s: diagnostic count %d, want %d", vector.ID, len(result.Diagnostics), len(vector.ExpectedDiagnosticCodes))
	}
	for i, code := range vector.ExpectedDiagnosticCodes {
		if result.Diagnostics[i].Code != code {
			return fmt.Errorf("%s: diagnostic %d is %s, want %s", vector.ID, i, result.Diagnostics[i].Code, code)
		}
	}
	return nil
}
