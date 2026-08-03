package preflight

import (
	"encoding/json"
	"errors"

	"github.com/rohitsharma9646/feature-flow/integrity/classifier"
	"github.com/rohitsharma9646/feature-flow/integrity/revision/gitobserve"
	"github.com/rohitsharma9646/feature-flow/integrity/wp3"
)

// RuntimeAuthority composes the existing WP1-WP3 authorities for a normalized
// request. It is read-only; mutation execution remains in wp3.RunMutationRun.
func RuntimeAuthority(request Request) ([]string, error) {
	switch request.Operation {
	case OperationManifestMutation, OperationTerminal:
		if len(request.ProposedManifest) == 0 {
			return []string{"FFI_SCHEMA_INVALID"}, nil
		}
		classified := classifier.Classify(request.ProposedManifest)
		if classified.Classification != classifier.CurrentStructuralValid {
			codes := make([]string, 0, len(classified.Diagnostics))
			for _, diagnostic := range classified.Diagnostics {
				codes = append(codes, diagnostic.Code)
			}
			return codes, nil
		}
		var manifest transitionManifest
		if err := json.Unmarshal(request.ProposedManifest, &manifest); err != nil {
			return []string{"FFI_SCHEMA_INVALID"}, nil
		}
		if request.Operation == OperationTerminal || manifest.CurrentPhase == "done" {
			if request.Context.DurableRoot == "" {
				return []string{"FFI_CAPABILITY_DEGRADED"}, nil
			}
			result, err := wp3.ConvergeProposedRun(
				request.Context.RunRoot,
				request.Context.RepositoryRoot,
				request.Context.DurableRoot,
				gitobserve.DefaultLimits(),
				request.ProposedManifest,
			)
			if err != nil {
				return nil, err
			}
			return result.Codes, nil
		}
		facts := wp3.TransitionFacts{
			Operation:      wp3.TransitionManifestMutation,
			Track:          manifest.Track,
			Tier:           manifest.Tier,
			ProposedPhase:  manifest.CurrentPhase,
			ImplementState: manifest.Phases.Implement.Status,
			DiagnoseState:  manifest.Phases.Diagnose.Status,
			SignedOff:      manifest.SignOff.Signed,
		}
		return wp3.EvaluateTransitionFacts(facts).Codes, nil
	case OperationCodeMutation, OperationAssurance:
		result, err := wp3.PreflightReadinessRun(
			request.Context.RunRoot,
			request.Context.RepositoryRoot,
			gitobserve.DefaultLimits(),
		)
		if err != nil {
			return nil, err
		}
		return result.Codes, nil
	default:
		return nil, errors.New("unknown preflight operation")
	}
}

type transitionManifest struct {
	Track        string `json:"track"`
	Tier         string `json:"tier"`
	CurrentPhase string `json:"currentPhase"`
	SignOff      struct {
		Signed bool `json:"signed"`
	} `json:"signOff"`
	Phases struct {
		Implement struct {
			Status string `json:"status"`
		} `json:"implement"`
		Diagnose struct {
			Status string `json:"status"`
		} `json:"diagnose"`
	} `json:"phases"`
}
