// ff-integrity-inventory is a development/CI tool. It may execute Git; the
// packaged doctor and migration runtime never imports or invokes it.
package main

import (
	"crypto/sha256"
	"encoding/hex"
	"encoding/json"
	"flag"
	"fmt"
	"os"
	"os/exec"
	"path/filepath"
	"sort"
	"strings"

	"github.com/rohitsharma9646/feature-flow/integrity/classifier"
	"github.com/rohitsharma9646/feature-flow/integrity/jsonstrict"
	migrationv0 "github.com/rohitsharma9646/feature-flow/integrity/migration/v0"
)

type source struct {
	Reference   string `json:"reference"`
	Digest      string `json:"digest"`
	Fingerprint string `json:"fingerprint"`
	Disposition string `json:"disposition"`
	ProfileID   string `json:"profileId,omitempty"`
}

type inventory struct {
	SchemaVersion  int       `json:"schemaVersion"`
	Generation     string    `json:"generation"`
	CoveragePolicy string    `json:"coveragePolicy"`
	Profiles       []profile `json:"profiles"`
	Sources        []source  `json:"sources"`
}

type profile struct {
	ProfileID                string   `json:"profileId"`
	Disposition              string   `json:"disposition"`
	RecognizedTopLevelFields []string `json:"recognizedTopLevelFields"`
}

func main() {
	output := flag.String("output", "", "write inventory JSON to this path")
	history := flag.Bool("history", true, "scan Git history")
	flag.Parse()
	items := scanCurrent(flag.Args())
	if *history {
		items = append(items, scanHistory()...)
	}
	sort.Slice(items, func(i, j int) bool { return items[i].Reference < items[j].Reference })
	items = dedupe(items)
	raw, _ := json.MarshalIndent(inventory{
		SchemaVersion: 1,
		Generation: "Run go run ./cmd/ff-integrity-inventory --history --output " +
			"integrity/testdata/legacy/inventory-v1.json [committed-dogfood-roots...]",
		CoveragePolicy: "Every Git-history and explicitly supplied committed dogfood legacy " +
			"source receives one supported profile or explicit unsupported rationale.",
		Profiles: profileInventory(),
		Sources:  items,
	}, "", "  ")
	raw = append(raw, '\n')
	if *output == "" {
		os.Stdout.Write(raw)
		return
	}
	if err := os.WriteFile(*output, raw, 0o644); err != nil {
		fmt.Fprintln(os.Stderr, "inventory write failed")
		os.Exit(2)
	}
}

func scanCurrent(roots []string) []source {
	if len(roots) == 0 {
		roots = []string{"integrity/testdata/manifests", "integrity/testdata/legacy/profiles"}
	}
	var out []source
	for _, root := range roots {
		_ = filepath.WalkDir(root, func(path string, entry os.DirEntry, err error) error {
			if err != nil || entry.IsDir() {
				return nil
			}
			if filepath.Base(path) != "manifest.json" && !strings.Contains(filepath.ToSlash(path), "/legacy") {
				return nil
			}
			if raw, err := os.ReadFile(path); err == nil {
				out = append(out, describe(filepath.ToSlash(path), raw))
			}
			return nil
		})
	}
	return out
}

func scanHistory() []source {
	commitsRaw, err := exec.Command("git", "rev-list", "--all").Output()
	if err != nil {
		return nil
	}
	var out []source
	for _, commit := range strings.Fields(string(commitsRaw)) {
		namesRaw, err := exec.Command("git", "ls-tree", "-r", "--name-only", commit).Output()
		if err != nil {
			continue
		}
		for _, name := range strings.Split(string(namesRaw), "\n") {
			if filepath.Base(name) != "manifest.json" && !strings.Contains(name, "legacy") {
				continue
			}
			raw, err := exec.Command("git", "show", commit+":"+name).Output()
			if err == nil {
				out = append(out, describe(commit[:12]+":"+name, raw))
			}
		}
	}
	return out
}

func describe(reference string, raw []byte) source {
	sum := sha256.Sum256(raw)
	item := source{Reference: reference, Digest: "sha256:" + hex.EncodeToString(sum[:])}
	value, err := jsonstrict.Decode(raw)
	if err != nil {
		item.Fingerprint = "invalid-json"
		item.Disposition = "unsupported: invalid JSON"
		return item
	}
	item.Fingerprint = fingerprint(value)
	class := classifier.Classify(raw)
	if class.Classification != classifier.LegacyUnversioned {
		item.Disposition = "not-legacy:" + string(class.Classification)
		return item
	}
	profileID, supported := migrationv0.MatchObject(value.(map[string]any))
	if supported {
		item.Disposition = "supported"
		item.ProfileID = profileID
	} else {
		item.Disposition = "unsupported: explicit profile refusal"
	}
	return item
}

func profileInventory() []profile {
	out := make([]profile, 0, len(migrationv0.Registry))
	for _, registered := range migrationv0.Registry {
		out = append(out, profile{
			ProfileID: registered.ID, Disposition: "supported",
			RecognizedTopLevelFields: []string{"profile-specific; see integrity/migration/v0/registry.go"},
		})
	}
	return out
}

func fingerprint(value any) string {
	var walk func(any) string
	walk = func(current any) string {
		switch typed := current.(type) {
		case map[string]any:
			keys := make([]string, 0, len(typed))
			for key := range typed {
				keys = append(keys, key)
			}
			sort.Strings(keys)
			var parts []string
			for _, key := range keys {
				parts = append(parts, key+":"+walk(typed[key]))
			}
			return "{" + strings.Join(parts, ",") + "}"
		case []any:
			kinds := make([]string, 0, len(typed))
			for _, item := range typed {
				kinds = append(kinds, walk(item))
			}
			sort.Strings(kinds)
			return "[" + strings.Join(kinds, "|") + "]"
		case string:
			return "string"
		case json.Number:
			return "number"
		case bool:
			return "bool"
		case nil:
			return "null"
		default:
			return "unknown"
		}
	}
	sum := sha256.Sum256([]byte(walk(value)))
	return "shape-v1:" + hex.EncodeToString(sum[:])
}

func dedupe(items []source) []source {
	seen := make(map[string]bool)
	out := make([]source, 0, len(items))
	for _, item := range items {
		key := item.Reference + "\x00" + item.Digest
		if !seen[key] {
			seen[key] = true
			out = append(out, item)
		}
	}
	return out
}
