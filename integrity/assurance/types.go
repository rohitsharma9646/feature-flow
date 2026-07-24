// Package assurance defines revision-bound review and verification policy.
package assurance

import "time"

type Kind string
type Status string
type Outcome string

const (
	KindReview       Kind = "review"
	KindVerification Kind = "verification"

	StatusPassed      Status = "passed"
	StatusFailed      Status = "failed"
	StatusUnavailable Status = "unavailable"

	OutcomeRecorded  Outcome = "recorded"
	OutcomeUnchanged Outcome = "unchanged"
)

type Producer struct {
	Kind    string `json:"kind"`
	Host    string `json:"host"`
	ID      string `json:"id"`
	Version string `json:"version,omitempty"`
}

type Invalidation struct {
	Reason       string    `json:"reason"`
	DetectedAt   time.Time `json:"detectedAt"`
	FromRevision string    `json:"fromRevision"`
	ToRevision   string    `json:"toRevision"`
}

type Attestation struct {
	AttestationID string        `json:"attestationId"`
	Kind          Kind          `json:"kind"`
	Status        Status        `json:"status"`
	CodeRevision  string        `json:"codeRevision"`
	Producer      Producer      `json:"producer"`
	RecordedAt    time.Time     `json:"recordedAt"`
	Artifact      string        `json:"artifact"`
	EvidenceRefs  []string      `json:"evidenceRefs"`
	Invalidation  *Invalidation `json:"invalidation"`
	Supersedes    *string       `json:"supersedes"`
}

type ReferenceSet struct {
	Artifacts map[string]bool
	Evidence  map[string]bool
}

type RecordRequest struct {
	Kind            Kind
	Status          Status
	CodeRevision    string
	Producer        Producer
	RecordedAt      time.Time
	Artifact        string
	EvidenceRefs    []string
	Supersedes      *string
	SemanticValid   bool
	CurrentRevision string
	RevisionReady   bool
	References      ReferenceSet
	IdempotencyKey  string
}

type RecordResult struct {
	Outcome     Outcome
	Attestation Attestation
}

type ConvergenceInput struct {
	ManifestValid    bool
	ProposedDone     bool
	RevisionReady    bool
	ScopeDrift       bool
	EvidenceGap      bool
	StoredRevision   string
	ObservedRevision string
	Review           *Attestation
	Verification     *Attestation
	References       ReferenceSet
}

type ConvergenceResult struct {
	Allowed bool     `json:"allowed"`
	Codes   []string `json:"codes"`
}
