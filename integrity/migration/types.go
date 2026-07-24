package migration

import (
	"github.com/rohitsharma9646/feature-flow/integrity/diagnostics"
	"github.com/rohitsharma9646/feature-flow/integrity/pathpolicy"
)

type Status string

const (
	StatusReady          Status = "ready"
	StatusRefused        Status = "refused"
	StatusAlreadyCurrent Status = "already-current"
	StatusDiagnosisOnly  Status = "diagnosis-only"
)

type Request struct {
	Raw                []byte
	LogicalRunPath     string
	RepositoryKind     string
	RepositoryRoot     string
	RunRoot            string
	DurableRoot        string
	RepositoryIdentity string
	WorktreeIdentity   string
	PointerFacts       map[string]pathpolicy.Fact
}

type Finalizer struct {
	Field  string `json:"field"`
	Source string `json:"source"`
}

type PlanResult struct {
	SchemaVersion                int                        `json:"schemaVersion"`
	Status                       Status                     `json:"status"`
	SourceDigest                 string                     `json:"sourceDigest,omitempty"`
	ProfileID                    string                     `json:"profileId,omitempty"`
	RunID                        string                     `json:"runId,omitempty"`
	Proposed                     map[string]any             `json:"proposed,omitempty"`
	LegacyUnknownPointers        []string                   `json:"legacyUnknownPointers"`
	RequiresTerminalConfirmation bool                       `json:"requiresTerminalConfirmation"`
	ApplyFinalizers              []Finalizer                `json:"applyFinalizers"`
	PointerFacts                 map[string]pathpolicy.Fact `json:"pointerFacts,omitempty"`
	Diagnostics                  []diagnostics.Diagnostic   `json:"diagnostics"`
	PlanDigest                   string                     `json:"planDigest,omitempty"`
}
