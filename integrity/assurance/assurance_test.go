package assurance

import (
	"testing"
	"time"
)

const (
	revisionA = "ffr1:aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa"
	revisionB = "ffr1:bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb"
)

func TestRecordIsIdempotentAndRefusesIdentityConflict(t *testing.T) {
	request := validRequest(KindReview)
	first, err := Record(nil, request)
	if err != nil {
		t.Fatal(err)
	}
	second, err := Record(&first.Attestation, request)
	if err != nil {
		t.Fatal(err)
	}
	if second.Outcome != OutcomeUnchanged || second.Attestation.AttestationID != first.Attestation.AttestationID {
		t.Fatalf("unexpected idempotent result: %#v", second)
	}
	conflict := request
	conflict.Status = StatusFailed
	if _, err := Record(&first.Attestation, conflict); err == nil {
		t.Fatal("expected conflicting identity reuse to fail")
	}
}

func TestEffectivePassIgnoresInvalidationAnnotation(t *testing.T) {
	recorded, err := Record(nil, validRequest(KindReview))
	if err != nil {
		t.Fatal(err)
	}
	if !EffectivePass(&recorded.Attestation, KindReview, revisionA, validRefs()) {
		t.Fatal("passing current attestation was ineffective")
	}
	recorded.Attestation.Invalidation = &Invalidation{
		Reason: "observed_mismatch", DetectedAt: time.Unix(1, 0).UTC(),
		FromRevision: revisionA, ToRevision: revisionB,
	}
	if !EffectivePass(&recorded.Attestation, KindReview, revisionA, validRefs()) {
		t.Fatal("annotation invalidated unchanged revision")
	}
	if EffectivePass(&recorded.Attestation, KindReview, revisionB, validRefs()) {
		t.Fatal("stale attestation was effective")
	}
	if EffectivePass(&recorded.Attestation, KindVerification, revisionA, validRefs()) {
		t.Fatal("review attestation satisfied verification")
	}
}

func TestConvergeRequiresSameCurrentRevisionAndValidEvidence(t *testing.T) {
	review, _ := Record(nil, validRequest(KindReview))
	verify, _ := Record(nil, validRequest(KindVerification))
	allowed := Converge(ConvergenceInput{
		ManifestValid: true, ProposedDone: true, RevisionReady: true,
		StoredRevision: revisionA, ObservedRevision: revisionA,
		Review: &review.Attestation, Verification: &verify.Attestation,
		References: validRefs(),
	})
	if !allowed.Allowed {
		t.Fatalf("expected convergence, got %#v", allowed)
	}
	verify.Attestation.CodeRevision = revisionB
	denied := Converge(ConvergenceInput{
		ManifestValid: true, ProposedDone: true, RevisionReady: true,
		StoredRevision: revisionA, ObservedRevision: revisionA,
		Review: &review.Attestation, Verification: &verify.Attestation,
		References: validRefs(),
	})
	if denied.Allowed || len(denied.Codes) == 0 {
		t.Fatalf("expected stable denial, got %#v", denied)
	}
}

func TestConvergeRejectsDuplicatedOrSwappedAttestationKinds(t *testing.T) {
	review, _ := Record(nil, validRequest(KindReview))
	verify, _ := Record(nil, validRequest(KindVerification))
	base := ConvergenceInput{
		ManifestValid: true, ProposedDone: true, RevisionReady: true,
		StoredRevision: revisionA, ObservedRevision: revisionA, References: validRefs(),
	}
	for name, pair := range map[string][2]*Attestation{
		"review in both slots":       {&review.Attestation, &review.Attestation},
		"verification in both slots": {&verify.Attestation, &verify.Attestation},
		"swapped kinds":              {&verify.Attestation, &review.Attestation},
	} {
		t.Run(name, func(t *testing.T) {
			input := base
			input.Review, input.Verification = pair[0], pair[1]
			if result := Converge(input); result.Allowed {
				t.Fatal("convergence accepted invalid attestation kinds")
			}
		})
	}
}

func validRequest(kind Kind) RecordRequest {
	return RecordRequest{
		Kind: kind, Status: StatusPassed, CodeRevision: revisionA,
		Producer:   Producer{Kind: "agent", Host: "codex", ID: "session-1"},
		RecordedAt: time.Unix(1, 0).UTC(), Artifact: string(kind),
		EvidenceRefs: []string{"evidence:" + string(kind)}, SemanticValid: true,
		CurrentRevision: revisionA, RevisionReady: true, References: validRefs(),
		IdempotencyKey: "request-1-" + string(kind),
	}
}

func validRefs() ReferenceSet {
	return ReferenceSet{
		Artifacts: map[string]bool{"review": true, "verification": true},
		Evidence: map[string]bool{
			"evidence:review": true, "evidence:verification": true,
		},
	}
}
