package migration

import (
	"crypto/sha256"
	"encoding/hex"
	"encoding/json"
	"strings"

	"github.com/rohitsharma9646/feature-flow/integrity/classifier"
	"github.com/rohitsharma9646/feature-flow/integrity/diagnostics"
	"github.com/rohitsharma9646/feature-flow/integrity/jsonstrict"
	migrationv0 "github.com/rohitsharma9646/feature-flow/integrity/migration/v0"
)

var knownTopLevel = map[string]bool{
	"slug": true, "track": true, "tier": true, "createdAt": true, "updatedAt": true,
	"closedAt": true, "autopilot": true, "currentPhase": true, "phases": true,
	"signOff": true, "lock": true, "bugfix": true, "artifacts": true,
	"request": true,
}

func digest(raw []byte) string {
	sum := sha256.Sum256(raw)
	return "sha256:" + hex.EncodeToString(sum[:])
}

func Plan(request Request) PlanResult {
	result := PlanResult{
		SchemaVersion: 1, LegacyUnknownPointers: []string{},
		ApplyFinalizers: []Finalizer{}, Diagnostics: []diagnostics.Diagnostic{},
	}
	class := classifier.Classify(request.Raw)
	switch class.Classification {
	case classifier.CurrentStructuralValid:
		result.Status = StatusAlreadyCurrent
		return result
	case classifier.LegacyUnversioned:
	default:
		result.Status = StatusDiagnosisOnly
		result.Diagnostics = class.Diagnostics
		return result
	}
	value, err := jsonstrict.Decode(request.Raw)
	if err != nil {
		result.Status = StatusDiagnosisOnly
		result.Diagnostics = []diagnostics.Diagnostic{diagnostics.New("FFI_INVALID_JSON", "")}
		return result
	}
	legacy := value.(map[string]any)
	for key := range legacy {
		if !knownTopLevel[key] {
			result.Status = StatusRefused
			result.Diagnostics = []diagnostics.Diagnostic{diagnostics.New("FFI_MIGRATION_AMBIGUOUS", "/"+escape(key))}
			return result
		}
	}
	profileID, registered := migrationv0.MatchObject(legacy)
	if !registered {
		result.Status = StatusRefused
		result.Diagnostics = []diagnostics.Diagnostic{diagnostics.New("FFI_MIGRATION_AMBIGUOUS", "")}
		return result
	}
	inertPointers, valid := validateLegacyShape(legacy)
	if !valid {
		result.Status = StatusRefused
		result.Diagnostics = []diagnostics.Diagnostic{diagnostics.New("FFI_MIGRATION_AMBIGUOUS", "")}
		return result
	}
	proposed, terminal, ok := project(legacy, request)
	if !ok {
		result.Status = StatusRefused
		result.Diagnostics = []diagnostics.Diagnostic{diagnostics.New("FFI_MIGRATION_AMBIGUOUS", "")}
		return result
	}
	sourceDigest := digest(request.Raw)
	runID := stableRunID(request, sourceDigest)
	proposed["runId"] = runID
	rawProposed, _ := json.Marshal(proposed)
	if validated := classifier.Classify(rawProposed); validated.Classification != classifier.CurrentStructuralValid {
		result.Status = StatusRefused
		result.Diagnostics = append([]diagnostics.Diagnostic{}, validated.Diagnostics...)
		return result
	}
	result.Status = StatusReady
	result.SourceDigest = sourceDigest
	result.ProfileID = profileID
	result.RunID = runID
	result.Proposed = proposed
	result.PointerFacts = request.PointerFacts
	result.LegacyUnknownPointers = inertPointers
	result.RequiresTerminalConfirmation = terminal
	result.ApplyFinalizers = []Finalizer{{Field: "/migration/migratedAt", Source: "apply-commit-clock"}}
	result.PlanDigest = planDigest(result)
	return result
}

func validateLegacyShape(legacy map[string]any) ([]string, bool) {
	inert := []string{}
	if _, exists := legacy["request"]; exists {
		inert = append(inert, "/request")
	}
	for _, field := range []string{"slug", "track", "tier", "createdAt", "updatedAt", "currentPhase"} {
		if value, exists := legacy[field]; exists {
			if _, ok := value.(string); !ok {
				return nil, false
			}
		}
	}
	if value, exists := legacy["autopilot"]; exists {
		if _, ok := value.(bool); !ok {
			return nil, false
		}
	}
	if value, exists := legacy["closedAt"]; exists && value != nil {
		if _, ok := value.(string); !ok || legacy["currentPhase"] != "done" {
			return nil, false
		}
	}
	if value, exists := legacy["lock"]; exists && value != nil {
		object, ok := value.(map[string]any)
		if !ok || !onlyKeys(object, "owner", "acquiredAt") ||
			!isString(object["owner"]) || !isString(object["acquiredAt"]) {
			return nil, false
		}
	}
	if value, exists := legacy["signOff"]; exists {
		object, ok := value.(map[string]any)
		if !ok || !onlyKeys(object, "required", "signed", "date", "actor", "evidenceRef") {
			return nil, false
		}
		if required, ok := object["required"]; ok && !isBool(required) {
			return nil, false
		}
		if signed, ok := object["signed"]; ok && !isBool(signed) {
			return nil, false
		}
		if date, ok := object["date"]; ok && date != nil && !isString(date) {
			return nil, false
		}
	}
	if value, exists := legacy["phases"]; exists {
		phases, ok := value.(map[string]any)
		if !ok {
			return nil, false
		}
		for name, value := range phases {
			if !knownPhase(name) {
				return nil, false
			}
			phase, ok := value.(map[string]any)
			if !ok || !onlyKeys(phase, "status", "artifact") {
				return nil, false
			}
			status, ok := phase["status"].(string)
			if !ok || (status != "pending" && status != "in_progress" && status != "complete") {
				return nil, false
			}
			if artifact, exists := phase["artifact"]; exists && artifact != nil && !isString(artifact) {
				return nil, false
			}
		}
	}
	if value, exists := legacy["artifacts"]; exists {
		artifacts, ok := value.(map[string]any)
		if !ok {
			return nil, false
		}
		for _, pointer := range artifacts {
			if !isString(pointer) {
				return nil, false
			}
		}
	}
	if value, exists := legacy["bugfix"]; exists {
		bugfix, ok := value.(map[string]any)
		if !ok || !onlyKeys(bugfix, "red", "green") {
			return nil, false
		}
		for _, key := range []string{"red", "green"} {
			if evidence, exists := bugfix[key]; exists {
				object, ok := evidence.(map[string]any)
				if !ok || !onlyKeys(object, "command", "exit", "evidence") ||
					!isString(object["command"]) || !isString(object["evidence"]) {
					return nil, false
				}
				if _, ok := object["exit"].(json.Number); !ok {
					return nil, false
				}
			}
		}
	}
	return inert, true
}

func onlyKeys(object map[string]any, allowed ...string) bool {
	set := make(map[string]bool, len(allowed))
	for _, key := range allowed {
		set[key] = true
	}
	for key := range object {
		if !set[key] {
			return false
		}
	}
	return true
}

func isString(value any) bool {
	_, ok := value.(string)
	return ok
}

func isBool(value any) bool {
	_, ok := value.(bool)
	return ok
}

func knownPhase(value string) bool {
	switch value {
	case "explore", "clarify", "design", "plan", "diagnose", "implement", "review", "verify", "deliver":
		return true
	default:
		return false
	}
}

func project(legacy map[string]any, request Request) (map[string]any, bool, bool) {
	slug, ok := stringValue(legacy, "slug")
	if !ok || slug == "" {
		return nil, false, false
	}
	track, ok := stringValue(legacy, "track")
	if !ok || (track != "feature" && track != "bugfix") {
		return nil, false, false
	}
	tier := valueOr(legacy, "tier", "full")
	if tier != "full" && tier != "lite" {
		return nil, false, false
	}
	current, ok := stringValue(legacy, "currentPhase")
	if !ok {
		return nil, false, false
	}
	terminal := current == "done"
	if terminal {
		if track == "bugfix" {
			current = "verify"
		} else {
			current = "review"
		}
	}
	created := valueOr(legacy, "createdAt", "1970-01-01T00:00:00Z")
	updated := valueOr(legacy, "updatedAt", created)
	autopilot, _ := legacy["autopilot"].(bool)
	phases, _ := legacy["phases"].(map[string]any)
	if phases == nil {
		phases = map[string]any{}
	}
	phases = cloneMap(phases)
	if terminal {
		phases["review"] = map[string]any{"status": "pending", "artifact": nil}
		phases["verify"] = map[string]any{"status": "pending", "artifact": nil}
	}
	signOff, _ := legacy["signOff"].(map[string]any)
	required := track == "feature" || tier == "full"
	signed := false
	var signDate any
	var actor any
	var evidenceRef any
	if signOff != nil {
		if v, ok := signOff["required"].(bool); ok {
			required = v
		}
		signed, _ = signOff["signed"].(bool)
		signDate = signOff["date"]
		actor = signOff["actor"]
		evidenceRef = signOff["evidenceRef"]
	}
	artifacts, _ := legacy["artifacts"].(map[string]any)
	if artifacts == nil {
		artifacts = map[string]any{}
	}
	repoKind := request.RepositoryKind
	if repoKind != "git" && repoKind != "non-git" {
		repoKind = "non-git"
	}
	repoID := bootstrapIdentity("repository", request.RepositoryIdentity)
	worktreeID := bootstrapIdentity("worktree", request.WorktreeIdentity)
	scope := map[string]any{
		"trackedPaths": []any{}, "includedUntrackedPaths": []any{}, "exclusions": []any{},
	}
	baselineDescriptor, _ := json.Marshal(map[string]any{
		"domain": "feature-flow-bootstrap-baseline", "version": 1,
		"repositoryIdentity": repoID, "worktreeIdentity": worktreeID,
		"head": nil, "scope": scope, "observation": "unsupported-pre-wp3",
	})
	out := map[string]any{
		"schemaVersion": 1, "slug": slug, "runId": "",
		"track": track, "tier": tier, "createdAt": created, "updatedAt": updated,
		"closedAt": nil, "autopilot": autopilot, "currentPhase": current,
		"phases": phases,
		"signOff": map[string]any{
			"required": required, "signed": signed, "date": signDate,
			"actor": actor, "evidenceRef": evidenceRef,
		},
		"lock": legacy["lock"], "artifacts": artifacts,
		"code": map[string]any{
			"baseline": map[string]any{
				"repositoryKind": repoKind, "repositoryIdentity": repoID,
				"worktreeIdentity": worktreeID, "head": nil,
				"startSnapshotDigest": digest(baselineDescriptor),
			},
			"scope": scope,
			"revision": map[string]any{
				"status": "unsupported", "algorithm": "ff-code-revision-v1",
				"id": nil, "diagnostic": "FFI_REVISION_UNSUPPORTED",
			},
		},
		"assurance": map[string]any{"review": nil, "verification": nil},
		"migration": nil,
	}
	if bugfix, ok := legacy["bugfix"]; ok {
		out["bugfix"] = bugfix
	}
	return out, terminal, true
}

func planDigest(result PlanResult) string {
	result.PlanDigest = ""
	raw, _ := json.Marshal(result)
	return digest(raw)
}

func stableRunID(request Request, sourceDigest string) string {
	input := strings.Join([]string{
		"feature-flow-migrated-run-v1", bootstrapIdentity("repository", request.RepositoryIdentity),
		bootstrapIdentity("worktree", request.WorktreeIdentity), request.LogicalRunPath, sourceDigest,
	}, "\x00")
	sum := sha256.Sum256([]byte(input))
	return "ffrun1:" + hex.EncodeToString(sum[:])
}

func bootstrapIdentity(kind, value string) string {
	sum := sha256.Sum256([]byte("feature-flow-bootstrap-" + kind + "-v1\x00" + value))
	return "ff-bootstrap-" + kind + "-v1:" + hex.EncodeToString(sum[:])
}

func valueOr(object map[string]any, key, fallback string) string {
	if value, ok := object[key].(string); ok && value != "" {
		return value
	}
	return fallback
}

func stringValue(object map[string]any, key string) (string, bool) {
	value, ok := object[key].(string)
	return value, ok
}

func cloneMap(source map[string]any) map[string]any {
	out := make(map[string]any, len(source))
	for key, value := range source {
		out[key] = value
	}
	return out
}

func escape(value string) string {
	return strings.ReplaceAll(strings.ReplaceAll(value, "~", "~0"), "/", "~1")
}
