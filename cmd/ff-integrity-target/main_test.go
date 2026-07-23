package main

import (
	"encoding/json"
	"os"
	"path/filepath"
	"testing"
)

func TestSupportedInventoryIsComplete(t *testing.T) {
	raw, err := os.ReadFile(filepath.Join("..", "..", "release", "targets.json"))
	if err != nil {
		t.Fatal(err)
	}
	var values inventory
	if err := json.Unmarshal(raw, &values); err != nil {
		t.Fatal(err)
	}
	if len(values.Targets) != 6 {
		t.Fatalf("targets=%d want 6", len(values.Targets))
	}
	seen := make(map[string]bool)
	for _, value := range values.Targets {
		if seen[value.ID] || value.GOOS == "" || value.GOARCH == "" ||
			value.Executable == "" || value.State != "supported" {
			t.Fatalf("invalid target: %#v", value)
		}
		seen[value.ID] = true
	}
}
