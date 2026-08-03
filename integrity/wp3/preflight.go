package wp3

import (
	"errors"
	"sort"

	"github.com/rohitsharma9646/feature-flow/integrity/revision/gitobserve"
)

type TransitionOperation string

const (
	TransitionManifestMutation TransitionOperation = "manifest_mutation"
	TransitionCodeMutation     TransitionOperation = "code_mutation"
	TransitionTerminal         TransitionOperation = "terminal_transition"
	TransitionAssurance        TransitionOperation = "assurance_recording"
)

// TransitionFacts are already classified and authoritatively observed facts.
// Host envelopes and filesystem discovery do not belong in this policy input.
type TransitionFacts struct {
	Operation        TransitionOperation
	Track            string
	Tier             string
	ProposedPhase    string
	ImplementState   string
	DiagnoseState    string
	SignedOff        bool
	RevisionReady    bool
	ScopeDrift       bool
	RevisionMismatch bool
	TerminalAllowed  bool
	TerminalCodes    []string
}

type TransitionDecision struct {
	Allowed bool
	Codes   []string
}

// EvaluateTransitionFacts is the sole host-neutral transition decision seam.
// It delegates revision and terminal truth to the existing WP3/assurance
// authorities and contains no host transport behavior.
func EvaluateTransitionFacts(facts TransitionFacts) TransitionDecision {
	switch facts.Operation {
	case TransitionManifestMutation:
		if entersImplement(facts) && !implementAuthorized(facts) {
			return TransitionDecision{Codes: []string{"FFI_TERMINAL_INCONSISTENT"}}
		}
		return TransitionDecision{Allowed: true}
	case TransitionCodeMutation, TransitionAssurance:
		readiness := ReadyForMutation(ReadinessInput{
			Tier:          facts.Tier,
			RevisionReady: facts.RevisionReady,
			ScopeDrift:    facts.ScopeDrift,
			Mismatch:      facts.RevisionMismatch,
		})
		return TransitionDecision{Allowed: !readiness.Mismatch, Codes: readiness.Codes}
	case TransitionTerminal:
		codes := uniqueTransitionCodes(facts.TerminalCodes)
		return TransitionDecision{Allowed: facts.TerminalAllowed && len(codes) == 0, Codes: codes}
	default:
		return TransitionDecision{Codes: []string{"FFI_SCHEMA_INVALID"}}
	}
}

func entersImplement(facts TransitionFacts) bool {
	return facts.ProposedPhase == "implement" ||
		facts.ImplementState == "in_progress" ||
		facts.ImplementState == "complete"
}

func implementAuthorized(facts TransitionFacts) bool {
	if facts.Track == "feature" || facts.Tier == "full" {
		return facts.SignedOff
	}
	return facts.Track == "bugfix" && facts.Tier == "lite" && facts.DiagnoseState == "complete"
}

func uniqueTransitionCodes(codes []string) []string {
	seen := make(map[string]struct{}, len(codes))
	for _, code := range codes {
		if code != "" {
			seen[code] = struct{}{}
		}
	}
	out := make([]string, 0, len(seen))
	for code := range seen {
		out = append(out, code)
	}
	sort.Strings(out)
	return out
}

// PreflightReadinessRun observes current revision readiness without mutating
// the manifest. The mutation command's before/after CAS bracket remains the
// final authority when the mutation executes.
func PreflightReadinessRun(runDir, repository string, limits gitobserve.Limits) (ReconcileResult, error) {
	_, _, document, err := readCurrentManifest(runDir)
	if err != nil {
		return ReconcileResult{}, err
	}
	baseline, _, err := loadAuthorizedBaseline(runDir, document)
	if err != nil {
		return ReconcileResult{}, err
	}
	observed := gitobserve.Observe(repository, baseline, limits)
	if observed.Err != nil {
		return ReconcileResult{}, observed.Err
	}
	code, ok := object(document["code"])
	if !ok {
		return ReconcileResult{}, errors.New("manifest code state missing")
	}
	tier, _ := document["tier"].(string)
	return ReadyForMutation(ReadinessInput{
		Tier:          tier,
		RevisionReady: observed.Status == gitobserve.StatusReady,
		ScopeDrift:    observed.Status == gitobserve.StatusScopeDrift,
		Mismatch:      revisionID(code) == "" || revisionID(code) != observed.Revision.ID,
	}), nil
}
