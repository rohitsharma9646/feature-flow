// Package wp3 coordinates host-neutral revision and assurance transitions.
// Domain decisions remain in revision and assurance; this package owns only
// transition ordering and immutable-state copying.
package wp3

import (
	"errors"
	"time"

	"github.com/rohitsharma9646/feature-flow/integrity/assurance"
	"github.com/rohitsharma9646/feature-flow/integrity/digest"
)

type State struct {
	Revision     string
	Review       *assurance.Attestation
	Verification *assurance.Attestation
}

type MutationResult struct {
	Changed bool
	State   State
}

type ReconcileResult struct {
	Mismatch bool     `json:"mismatch"`
	Codes    []string `json:"codes"`
}

type MutationBoundary struct {
	Reason  string
	Observe func() (string, error)
	Mutate  func() error
	Persist func(State) error
	Now     func() time.Time
}

type ScopeRequest struct {
	Authorized       bool
	ExpectedRevision string
	ObservedRevision string
	DetectedAt       time.Time
}

type ReadinessInput struct {
	Tier          string
	RevisionReady bool
	ScopeDrift    bool
	Mismatch      bool
}

type Route string

const (
	RouteFeatureTerminal Route = "feature-terminal"
	RouteBugfixReview    Route = "bugfix-review-terminal"
	RouteBugfixReverse   Route = "bugfix-reverse-terminal"
	RouteRepaired        Route = "repaired-terminal"
	RouteResume          Route = "resume"
	RouteDoctor          Route = "doctor"
	RouteAlreadyDone     Route = "already-done"
)

func ReconcileMutation(current State, before, after, reason string, detectedAt time.Time) (MutationResult, error) {
	if !digest.ValidRevisionID(before) || !digest.ValidRevisionID(after) ||
		current.Revision != before || !validReason(reason) || detectedAt.IsZero() {
		return MutationResult{}, errors.New("invalid mutation transition")
	}
	next := cloneState(current)
	if before == after {
		return MutationResult{State: next}, nil
	}
	next.Revision = after
	assurance.AnnotateChanged(next.Review, reason, detectedAt, after)
	assurance.AnnotateChanged(next.Verification, reason, detectedAt, after)
	return MutationResult{Changed: true, State: next}, nil
}

func RunMutation(current State, boundary MutationBoundary) (MutationResult, error) {
	if boundary.Observe == nil || boundary.Mutate == nil || boundary.Persist == nil ||
		boundary.Now == nil || !validReason(boundary.Reason) {
		return MutationResult{}, errors.New("incomplete mutation boundary")
	}
	before, err := boundary.Observe()
	if err != nil || before != current.Revision {
		return MutationResult{}, errors.New("FFI_REVISION_MISMATCH")
	}
	if err := boundary.Mutate(); err != nil {
		return MutationResult{}, err
	}
	after, err := boundary.Observe()
	if err != nil || !digest.ValidRevisionID(after) {
		return MutationResult{}, errors.New("FFI_REVISION_UNSUPPORTED")
	}
	result, err := ReconcileMutation(current, before, after, boundary.Reason, boundary.Now())
	if err != nil {
		return MutationResult{}, err
	}
	if result.Changed {
		if err := boundary.Persist(result.State); err != nil {
			return MutationResult{}, err
		}
	}
	return result, nil
}

func ReconcileScope(current State, request ScopeRequest) (MutationResult, error) {
	if !request.Authorized {
		return MutationResult{}, errors.New("scope reconciliation is not authorized")
	}
	return ReconcileMutation(current, request.ExpectedRevision, request.ObservedRevision,
		"scope_change", request.DetectedAt)
}

func ReadyForMutation(input ReadinessInput) ReconcileResult {
	if input.Tier != "full" && input.Tier != "lite" {
		return ReconcileResult{Mismatch: true, Codes: []string{"FFI_REVISION_UNSUPPORTED"}}
	}
	var codes []string
	if !input.RevisionReady {
		codes = append(codes, "FFI_REVISION_UNSUPPORTED")
	}
	if input.ScopeDrift {
		codes = append(codes, "FFI_REVISION_SCOPE_DRIFT")
	}
	if input.Mismatch {
		codes = append(codes, "FFI_REVISION_MISMATCH")
	}
	return ReconcileResult{Mismatch: len(codes) != 0, Codes: codes}
}

func DecideRoute(route Route, input assurance.ConvergenceInput) (assurance.ConvergenceResult, error) {
	switch route {
	case RouteFeatureTerminal, RouteBugfixReview, RouteBugfixReverse, RouteRepaired,
		RouteResume, RouteDoctor, RouteAlreadyDone:
		return assurance.Converge(input), nil
	default:
		return assurance.ConvergenceResult{}, errors.New("unknown convergence route")
	}
}

func ReconcileCrash(current State, observed string) ReconcileResult {
	if !digest.ValidRevisionID(observed) {
		return ReconcileResult{
			Mismatch: true,
			Codes:    []string{"FFI_REVISION_UNSUPPORTED", "FFI_TERMINAL_INCONSISTENT"},
		}
	}
	if current.Revision == observed {
		return ReconcileResult{Codes: []string{}}
	}
	return ReconcileResult{
		Mismatch: true,
		Codes: []string{
			"FFI_ATTESTATION_STALE", "FFI_REVISION_MISMATCH", "FFI_TERMINAL_INCONSISTENT",
		},
	}
}

func cloneState(current State) State {
	next := State{Revision: current.Revision}
	if current.Review != nil {
		value := *current.Review
		value.EvidenceRefs = append([]string(nil), current.Review.EvidenceRefs...)
		next.Review = &value
	}
	if current.Verification != nil {
		value := *current.Verification
		value.EvidenceRefs = append([]string(nil), current.Verification.EvidenceRefs...)
		next.Verification = &value
	}
	return next
}

func validReason(reason string) bool {
	switch reason {
	case "implementation_change", "review_repair", "verification_repair", "scope_change":
		return true
	default:
		return false
	}
}
