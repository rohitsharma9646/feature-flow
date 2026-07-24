package assurance

import (
	"errors"
	"sort"
	"strings"
	"time"

	"github.com/rohitsharma9646/feature-flow/integrity/canonicaljson"
	"github.com/rohitsharma9646/feature-flow/integrity/digest"
)

func Record(existing *Attestation, request RecordRequest) (RecordResult, error) {
	if err := validateRequest(request); err != nil {
		return RecordResult{}, err
	}
	evidence := append([]string(nil), request.EvidenceRefs...)
	sort.Strings(evidence)
	identity, err := attestationIdentity(request, evidence)
	if err != nil {
		return RecordResult{}, err
	}
	next := Attestation{
		AttestationID: identity, Kind: request.Kind, Status: request.Status,
		CodeRevision: request.CodeRevision, Producer: request.Producer,
		RecordedAt: request.RecordedAt.UTC(), Artifact: request.Artifact,
		EvidenceRefs: evidence, Supersedes: request.Supersedes,
	}
	if existing != nil {
		if existing.AttestationID != identity {
			return RecordResult{}, errors.New("attestation identity conflict")
		}
		if !sameImmutable(*existing, next) {
			return RecordResult{}, errors.New("conflicting attestation identity reuse")
		}
		return RecordResult{Outcome: OutcomeUnchanged, Attestation: *existing}, nil
	}
	return RecordResult{Outcome: OutcomeRecorded, Attestation: next}, nil
}

func EffectivePass(attestation *Attestation, expectedKind Kind, currentRevision string, references ReferenceSet) bool {
	if attestation == nil || attestation.Kind != expectedKind || attestation.Status != StatusPassed ||
		attestation.CodeRevision != currentRevision ||
		!digest.ValidRevisionID(currentRevision) ||
		!references.Artifacts[attestation.Artifact] {
		return false
	}
	if len(attestation.EvidenceRefs) == 0 {
		return false
	}
	for _, reference := range attestation.EvidenceRefs {
		if !validEvidenceName(reference) || !references.Evidence[reference] {
			return false
		}
	}
	return true
}

func Converge(input ConvergenceInput) ConvergenceResult {
	codes := make([]string, 0, 6)
	if !input.ManifestValid || !input.ProposedDone {
		codes = append(codes, "FFI_TERMINAL_INCONSISTENT")
	}
	if !input.RevisionReady || !digest.ValidRevisionID(input.ObservedRevision) {
		codes = append(codes, "FFI_REVISION_UNSUPPORTED")
	} else if input.StoredRevision != input.ObservedRevision {
		codes = append(codes, "FFI_REVISION_MISMATCH")
	}
	if input.ScopeDrift {
		codes = append(codes, "FFI_REVISION_SCOPE_DRIFT")
	}
	if input.EvidenceGap {
		codes = append(codes, "FFI_ATTESTATION_STALE")
	}
	if !EffectivePass(input.Review, KindReview, input.ObservedRevision, input.References) ||
		!EffectivePass(input.Verification, KindVerification, input.ObservedRevision, input.References) {
		codes = append(codes, "FFI_ATTESTATION_STALE")
	}
	codes = uniqueSorted(codes)
	if len(codes) != 0 && !contains(codes, "FFI_TERMINAL_INCONSISTENT") {
		codes = append(codes, "FFI_TERMINAL_INCONSISTENT")
		sort.Strings(codes)
	}
	return ConvergenceResult{Allowed: len(codes) == 0, Codes: codes}
}

func AnnotateChanged(attestation *Attestation, reason string, detectedAt time.Time, toRevision string) {
	if attestation == nil || attestation.CodeRevision == toRevision {
		return
	}
	attestation.Invalidation = &Invalidation{
		Reason: reason, DetectedAt: detectedAt.UTC(),
		FromRevision: attestation.CodeRevision, ToRevision: toRevision,
	}
}

func validateRequest(request RecordRequest) error {
	if request.Kind != KindReview && request.Kind != KindVerification {
		return errors.New("invalid attestation kind")
	}
	if request.Status != StatusPassed && request.Status != StatusFailed &&
		request.Status != StatusUnavailable {
		return errors.New("invalid attestation status")
	}
	if !request.RevisionReady || !digest.ValidRevisionID(request.CodeRevision) ||
		request.CodeRevision != request.CurrentRevision {
		return errors.New("attestation revision is not current and ready")
	}
	if request.Producer.ID == "" || request.Producer.Kind == "" || request.Producer.Host == "" ||
		request.RecordedAt.IsZero() || request.Artifact == "" || request.IdempotencyKey == "" {
		return errors.New("incomplete attestation identity")
	}
	if !request.References.Artifacts[request.Artifact] || len(request.EvidenceRefs) == 0 {
		return errors.New("invalid artifact or evidence reference")
	}
	for _, reference := range request.EvidenceRefs {
		if !validEvidenceName(reference) || !request.References.Evidence[reference] {
			return errors.New("invalid evidence reference")
		}
	}
	if request.Status == StatusPassed && !request.SemanticValid {
		return errors.New("passing attestation failed semantic policy")
	}
	return nil
}

func attestationIdentity(request RecordRequest, evidence []string) (string, error) {
	raw, err := canonicaljson.Marshal(map[string]any{
		"domain": "feature-flow-attestation", "version": 1,
		"idempotencyKey": request.IdempotencyKey, "kind": string(request.Kind),
		"producer": map[string]any{
			"kind": request.Producer.Kind, "host": request.Producer.Host,
			"id": request.Producer.ID, "version": request.Producer.Version,
		},
	})
	if err != nil {
		return "", err
	}
	return "ffa1:" + strings.TrimPrefix(digest.RawSHA256(raw), "sha256:"), nil
}

func sameImmutable(left, right Attestation) bool {
	if left.AttestationID != right.AttestationID || left.Kind != right.Kind ||
		left.Status != right.Status || left.CodeRevision != right.CodeRevision ||
		left.Producer != right.Producer || !left.RecordedAt.Equal(right.RecordedAt) ||
		left.Artifact != right.Artifact || len(left.EvidenceRefs) != len(right.EvidenceRefs) {
		return false
	}
	for i := range left.EvidenceRefs {
		if left.EvidenceRefs[i] != right.EvidenceRefs[i] {
			return false
		}
	}
	if (left.Supersedes == nil) != (right.Supersedes == nil) {
		return false
	}
	return left.Supersedes == nil || *left.Supersedes == *right.Supersedes
}

func validEvidenceName(value string) bool {
	return strings.HasPrefix(value, "evidence:") && len(value) > len("evidence:") &&
		!strings.ContainsAny(value, `/\\`) && !strings.ContainsRune(value, 0)
}

func uniqueSorted(values []string) []string {
	sort.Strings(values)
	out := values[:0]
	for _, value := range values {
		if len(out) == 0 || out[len(out)-1] != value {
			out = append(out, value)
		}
	}
	return out
}

func contains(values []string, target string) bool {
	index := sort.SearchStrings(values, target)
	return index < len(values) && values[index] == target
}
