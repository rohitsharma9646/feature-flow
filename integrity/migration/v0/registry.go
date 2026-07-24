package v0

import (
	"sort"

	"github.com/rohitsharma9646/feature-flow/integrity/jsonstrict"
)

type Profile struct {
	ID    string
	Match func(map[string]any) bool
}

var Registry = []Profile{
	{ID: "legacy-minimal-feature-v0", Match: func(object map[string]any) bool {
		return exactKeys(object, "currentPhase", "slug", "track") &&
			object["track"] == "feature" && object["currentPhase"] == "implement"
	}},
	{ID: "legacy-minimal-feature-request-v0", Match: func(object map[string]any) bool {
		return exactKeys(object, "currentPhase", "request", "slug", "track") &&
			object["track"] == "feature" && object["currentPhase"] == "implement"
	}},
	{ID: "legacy-feature-active-v0", Match: func(object map[string]any) bool {
		return exactKeys(object, "artifacts", "autopilot", "currentPhase", "phases", "signOff", "slug", "tier", "track") &&
			object["track"] == "feature" && object["currentPhase"] != "done"
	}},
	{ID: "legacy-feature-terminal-v0", Match: func(object map[string]any) bool {
		return exactKeys(object, "artifacts", "autopilot", "currentPhase", "phases", "signOff", "slug", "tier", "track") &&
			object["track"] == "feature" && object["currentPhase"] == "done"
	}},
	{ID: "legacy-bugfix-active-v0", Match: func(object map[string]any) bool {
		return exactKeys(object, "artifacts", "autopilot", "bugfix", "currentPhase", "phases", "signOff", "slug", "tier", "track") &&
			object["track"] == "bugfix" && object["currentPhase"] != "done"
	}},
}

func Match(raw []byte) (string, bool) {
	value, err := jsonstrict.Decode(raw)
	if err != nil {
		return "", false
	}
	object, ok := value.(map[string]any)
	if !ok {
		return "", false
	}
	return MatchObject(object)
}

func MatchObject(object map[string]any) (string, bool) {
	var matched string
	for _, profile := range Registry {
		if profile.Match(object) {
			if matched != "" {
				return "", false
			}
			matched = profile.ID
		}
	}
	return matched, matched != ""
}

func exactKeys(object map[string]any, expected ...string) bool {
	if len(object) != len(expected) {
		return false
	}
	actual := make([]string, 0, len(object))
	for key := range object {
		actual = append(actual, key)
	}
	sort.Strings(actual)
	sort.Strings(expected)
	for index := range actual {
		if actual[index] != expected[index] {
			return false
		}
	}
	return true
}
