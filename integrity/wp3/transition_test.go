package wp3

import (
	"testing"
	"time"

	"github.com/rohitsharma9646/feature-flow/integrity/assurance"
)

func TestReconcileMutationPreservesNoOpAndInvalidatesChange(t *testing.T) {
	review := &assurance.Attestation{
		AttestationID: "a", Kind: assurance.KindReview, Status: assurance.StatusPassed,
		CodeRevision: revisionA,
	}
	verify := *review
	verify.Kind = assurance.KindVerification
	state := State{Revision: revisionA, Review: review, Verification: &verify}
	noOp, err := ReconcileMutation(state, revisionA, revisionA, "review_repair", time.Unix(1, 0))
	if err != nil || noOp.Changed || noOp.State.Review.Invalidation != nil {
		t.Fatalf("bad no-op result: %#v %v", noOp, err)
	}
	changed, err := ReconcileMutation(state, revisionA, revisionB, "review_repair", time.Unix(1, 0))
	if err != nil || !changed.Changed || changed.State.Revision != revisionB {
		t.Fatalf("bad changed result: %#v %v", changed, err)
	}
	if changed.State.Review.Invalidation == nil || changed.State.Verification.Invalidation == nil {
		t.Fatal("changed mutation lacked annotations")
	}
}

func TestReconcileCrashFailsClosed(t *testing.T) {
	got := ReconcileCrash(State{Revision: revisionA}, revisionB)
	if !got.Mismatch || len(got.Codes) == 0 {
		t.Fatalf("expected mismatch: %#v", got)
	}
}

func TestRunMutationOrdersObservationAndPersistsChangedState(t *testing.T) {
	var order []string
	observations := []string{revisionA, revisionB}
	result, err := RunMutation(State{Revision: revisionA}, MutationBoundary{
		Reason: "implementation_change",
		Observe: func() (string, error) {
			order = append(order, "observe")
			value := observations[0]
			observations = observations[1:]
			return value, nil
		},
		Mutate: func() error {
			order = append(order, "mutate")
			return nil
		},
		Persist: func(state State) error {
			order = append(order, "persist")
			if state.Revision != revisionB {
				t.Fatal("persist received stale revision")
			}
			return nil
		},
		Now: func() time.Time { return time.Unix(1, 0) },
	})
	if err != nil || !result.Changed || len(order) != 4 ||
		order[0] != "observe" || order[1] != "mutate" ||
		order[2] != "observe" || order[3] != "persist" {
		t.Fatalf("unexpected boundary result: %#v %v %v", result, order, err)
	}
}

func TestScopeReconciliationRequiresAuthorization(t *testing.T) {
	state := State{Revision: revisionA}
	if _, err := ReconcileScope(state, ScopeRequest{
		ExpectedRevision: revisionA, ObservedRevision: revisionB, DetectedAt: time.Unix(1, 0),
	}); err == nil {
		t.Fatal("unauthorized scope change was accepted")
	}
	result, err := ReconcileScope(state, ScopeRequest{
		Authorized: true, ExpectedRevision: revisionA,
		ObservedRevision: revisionB, DetectedAt: time.Unix(1, 0),
	})
	if err != nil || !result.Changed || result.State.Revision != revisionB {
		t.Fatalf("authorized scope change failed: %#v %v", result, err)
	}
}

func TestReadinessIsTierInvariant(t *testing.T) {
	for _, tier := range []string{"full", "lite"} {
		got := ReadyForMutation(ReadinessInput{Tier: tier, RevisionReady: false})
		if !got.Mismatch || len(got.Codes) != 1 || got.Codes[0] != "FFI_REVISION_UNSUPPORTED" {
			t.Fatalf("%s readiness differed: %#v", tier, got)
		}
	}
}

func TestEveryRouteUsesIdenticalConvergenceDecision(t *testing.T) {
	review := &assurance.Attestation{
		AttestationID: "review", Kind: assurance.KindReview, Status: assurance.StatusPassed,
		CodeRevision: revisionA, Artifact: "review", EvidenceRefs: []string{"evidence:review"},
	}
	verification := &assurance.Attestation{
		AttestationID: "verify", Kind: assurance.KindVerification, Status: assurance.StatusPassed,
		CodeRevision: revisionA, Artifact: "verify", EvidenceRefs: []string{"evidence:verify"},
	}
	input := assurance.ConvergenceInput{
		ManifestValid: true, ProposedDone: true, RevisionReady: true,
		StoredRevision: revisionA, ObservedRevision: revisionA,
		Review: review, Verification: verification,
		References: assurance.ReferenceSet{
			Artifacts: map[string]bool{"review": true, "verify": true},
			Evidence:  map[string]bool{"evidence:review": true, "evidence:verify": true},
		},
	}
	routes := []Route{
		RouteFeatureTerminal, RouteBugfixReview, RouteBugfixReverse, RouteRepaired,
		RouteResume, RouteDoctor, RouteAlreadyDone,
	}
	var first assurance.ConvergenceResult
	for index, route := range routes {
		got, err := DecideRoute(route, input)
		if err != nil {
			t.Fatal(err)
		}
		if index == 0 {
			first = got
		} else if got.Allowed != first.Allowed || len(got.Codes) != len(first.Codes) {
			t.Fatalf("route %s diverged: %#v != %#v", route, got, first)
		}
	}
}

const (
	revisionA = "ffr1:aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa"
	revisionB = "ffr1:bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb"
)
