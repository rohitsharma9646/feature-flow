package protocolv1

import (
	"encoding/json"
	"testing"
)

func TestDiagnosticCatalogue(t *testing.T) {
	var catalog struct {
		CatalogVersion int `json:"catalogVersion"`
		Diagnostics    []struct {
			Code string `json:"code"`
		} `json:"diagnostics"`
	}
	if err := json.Unmarshal(DiagnosticsJSON, &catalog); err != nil {
		t.Fatal(err)
	}
	if catalog.CatalogVersion != CatalogVersion {
		t.Fatalf("catalog version %d", catalog.CatalogVersion)
	}
	if len(catalog.Diagnostics) != 18 {
		t.Fatalf("got %d diagnostics, want 18", len(catalog.Diagnostics))
	}
	seen := map[string]bool{}
	for _, item := range catalog.Diagnostics {
		if item.Code == "" || seen[item.Code] {
			t.Fatalf("empty or duplicate code %q", item.Code)
		}
		seen[item.Code] = true
	}
}
