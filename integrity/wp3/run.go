package wp3

import (
	"encoding/json"
	"errors"
	"fmt"
	"path/filepath"
	"strings"
	"time"

	"github.com/rohitsharma9646/feature-flow/integrity/assurance"
	"github.com/rohitsharma9646/feature-flow/integrity/classifier"
	"github.com/rohitsharma9646/feature-flow/integrity/digest"
	"github.com/rohitsharma9646/feature-flow/integrity/observe"
	"github.com/rohitsharma9646/feature-flow/integrity/revision"
	"github.com/rohitsharma9646/feature-flow/integrity/revision/gitobserve"
	"github.com/rohitsharma9646/feature-flow/integrity/storage"
)

type RunRevisionResult struct {
	Status   gitobserve.Status `json:"status"`
	Revision revision.Result   `json:"revision"`
	Artifact string            `json:"artifact,omitempty"`
	CAS      storage.CASStatus `json:"cas"`
}

type RunAttestationRequest struct {
	Kind           assurance.Kind     `json:"kind"`
	Status         assurance.Status   `json:"status"`
	Producer       assurance.Producer `json:"producer"`
	RecordedAt     time.Time          `json:"recordedAt"`
	ArtifactKey    string             `json:"artifactKey"`
	Evidence       []RunEvidence      `json:"evidence"`
	Supersedes     *string            `json:"supersedes"`
	SemanticValid  bool               `json:"semanticValid"`
	IdempotencyKey string             `json:"idempotencyKey"`
}

type RunEvidence struct {
	ArtifactKey string `json:"artifactKey"`
	Kind        string `json:"kind"`
	Status      string `json:"status"`
}

type bundledEvidence struct {
	Reference string `json:"reference"`
	Pointer   string `json:"pointer"`
	Kind      string `json:"kind"`
	Status    string `json:"status"`
	Content   []byte `json:"content"`
}

type assuranceBundle struct {
	Version      int               `json:"version"`
	ArtifactRef  string            `json:"artifactRef"`
	Artifact     []byte            `json:"artifact"`
	EvidenceRefs []string          `json:"evidenceRefs"`
	Evidence     []bundledEvidence `json:"evidence"`
}

// CaptureRun establishes the manifest-authorized baseline artifact and current
// revision in one artifact-first, manifest-CAS transition.
func CaptureRun(runDir, repository string, scope revision.Scope, limits gitobserve.Limits, now time.Time) (RunRevisionResult, error) {
	return captureRun(runDir, repository, scope, limits, now, "")
}

// ReconcileScopeRun requires explicit authorization and an exact current
// revision before replacing scope/baseline authority.
func ReconcileScopeRun(runDir, repository string, request ScopeRequest, scope revision.Scope, limits gitobserve.Limits) (RunRevisionResult, error) {
	if !request.Authorized || !digest.ValidRevisionID(request.ExpectedRevision) || request.DetectedAt.IsZero() {
		return RunRevisionResult{}, errors.New("scope reconciliation is not authorized")
	}
	return captureRun(runDir, repository, scope, limits, request.DetectedAt, request.ExpectedRevision)
}

func captureRun(runDir, repository string, scope revision.Scope, limits gitobserve.Limits, now time.Time, expectedRevision string) (RunRevisionResult, error) {
	raw, expected, document, err := readCurrentManifest(runDir)
	if err != nil {
		return RunRevisionResult{}, err
	}
	if expectedRevision != "" {
		code, _ := object(document["code"])
		if revisionID(code) != expectedRevision {
			return RunRevisionResult{}, errors.New("FFI_REVISION_MISMATCH")
		}
	} else {
		code, _ := object(document["code"])
		baseline, _ := object(code["baseline"])
		if revisionID(code) != "" || baseline["facts"] != nil {
			return RunRevisionResult{}, errors.New("authoritative baseline already exists")
		}
	}
	baseline, err := gitobserve.Capture(repository, scope, limits)
	if err != nil {
		return RunRevisionResult{}, err
	}
	observed := gitobserve.Observe(repository, baseline, limits)
	if observed.Err != nil || observed.Status != gitobserve.StatusReady {
		return RunRevisionResult{}, errors.New("FFI_REVISION_UNSUPPORTED")
	}
	name := "baseline-v1-" + strings.TrimPrefix(baseline.ArtifactDigest, "sha256:") + ".json"
	artifact := filepath.ToSlash(filepath.Join("revision", name))
	if err := setBaselineManifest(document, baseline, observed.Revision, artifact, now); err != nil {
		return RunRevisionResult{}, err
	}
	proposed, err := json.MarshalIndent(document, "", "  ")
	if err != nil {
		return RunRevisionResult{}, err
	}
	proposed = append(proposed, '\n')
	result := storage.PublishRevisionCAS(runDir, storage.RevisionCASRequest{
		ExpectedManifestDigest: expected,
		ProposedManifest:       proposed,
		ArtifactName:           name,
		Artifact:               baseline.Canonical,
		ArtifactDigest:         baseline.ArtifactDigest,
	})
	if result.Status != storage.CASApplied {
		return RunRevisionResult{Status: gitobserve.StatusUnsupported, Artifact: result.Artifact, CAS: result.Status},
			fmt.Errorf("baseline publication %s", result.Status)
	}
	_ = raw
	return RunRevisionResult{
		Status: gitobserve.StatusReady, Revision: observed.Revision,
		Artifact: artifact, CAS: result.Status,
	}, nil
}

// RunMutationRun brackets a real host mutation with authoritative observations
// and persists the resulting revision plus attestation invalidations by CAS.
func RunMutationRun(runDir, repository, reason string, limits gitobserve.Limits, now time.Time, mutate func() error) (RunRevisionResult, error) {
	if mutate == nil || !validReason(reason) || now.IsZero() {
		return RunRevisionResult{}, errors.New("incomplete mutation boundary")
	}
	_, expected, document, err := readCurrentManifest(runDir)
	if err != nil {
		return RunRevisionResult{}, err
	}
	baseline, artifact, err := loadAuthorizedBaseline(runDir, document)
	if err != nil {
		return RunRevisionResult{}, err
	}
	code, _ := object(document["code"])
	before := gitobserve.Observe(repository, baseline, limits)
	if before.Err != nil || before.Status != gitobserve.StatusReady ||
		revisionID(code) != before.Revision.ID {
		return RunRevisionResult{}, errors.New("FFI_REVISION_MISMATCH")
	}
	if err := mutate(); err != nil {
		return RunRevisionResult{}, err
	}
	after := gitobserve.Observe(repository, baseline, limits)
	if after.Err != nil || after.Status != gitobserve.StatusReady {
		return RunRevisionResult{Status: after.Status, Artifact: artifact}, errors.New("FFI_REVISION_UNSUPPORTED")
	}
	if before.Revision.ID != after.Revision.ID {
		code["revision"] = revisionManifest(after.Revision, now)
		annotateManifestAssurance(document, before.Revision.ID, after.Revision.ID, reason, now)
		document["updatedAt"] = now.UTC().Format(time.RFC3339)
		if err := publishDocument(runDir, expected, document); err != nil {
			return RunRevisionResult{Status: gitobserve.StatusUnsupported, Artifact: artifact}, err
		}
	}
	return RunRevisionResult{
		Status: gitobserve.StatusReady, Revision: after.Revision,
		Artifact: artifact, CAS: storage.CASApplied,
	}, nil
}

// ObserveRun resolves the baseline only through the manifest's registered
// content-addressed pointer, freshly observes the repository, and CAS-publishes
// the new current revision.
func ObserveRun(runDir, repository string, limits gitobserve.Limits, now time.Time) (RunRevisionResult, error) {
	_, expected, document, err := readCurrentManifest(runDir)
	if err != nil {
		return RunRevisionResult{}, err
	}
	baseline, artifact, err := loadAuthorizedBaseline(runDir, document)
	if err != nil {
		return RunRevisionResult{}, err
	}
	observed := gitobserve.Observe(repository, baseline, limits)
	if observed.Err != nil {
		return RunRevisionResult{Status: observed.Status}, observed.Err
	}
	code, ok := object(document["code"])
	if !ok {
		return RunRevisionResult{}, errors.New("manifest code state missing")
	}
	previous := revisionID(code)
	code["revision"] = revisionManifest(observed.Revision, now)
	if previous != "" && previous != observed.Revision.ID {
		annotateManifestAssurance(document, previous, observed.Revision.ID, "observed_mismatch", now)
	}
	document["updatedAt"] = now.UTC().Format(time.RFC3339)
	proposed, err := json.MarshalIndent(document, "", "  ")
	if err != nil {
		return RunRevisionResult{}, err
	}
	proposed = append(proposed, '\n')
	status := storage.ReplaceManifestCAS(runDir, expected, proposed)
	if status != storage.CASApplied {
		return RunRevisionResult{Status: gitobserve.StatusUnsupported, Artifact: artifact, CAS: status},
			fmt.Errorf("revision publication %s", status)
	}
	return RunRevisionResult{
		Status: gitobserve.StatusReady, Revision: observed.Revision,
		Artifact: artifact, CAS: status,
	}, nil
}

// RecordRunAttestation derives revision and reference authority from the
// current manifest and persists the typed result with manifest CAS.
func RecordRunAttestation(runDir, repository, durableRoot string, limits gitobserve.Limits, request RunAttestationRequest) (assurance.RecordResult, error) {
	_, expected, document, err := readCurrentManifest(runDir)
	if err != nil {
		return assurance.RecordResult{}, err
	}
	code, _ := object(document["code"])
	current := revisionID(code)
	if !digest.ValidRevisionID(current) {
		return assurance.RecordResult{}, errors.New("attestation revision is not current and ready")
	}
	baseline, _, err := loadAuthorizedBaseline(runDir, document)
	if err != nil {
		return assurance.RecordResult{}, err
	}
	observed := gitobserve.Observe(repository, baseline, limits)
	if observed.Err != nil || observed.Status != gitobserve.StatusReady || observed.Revision.ID != current {
		return assurance.RecordResult{}, errors.New("FFI_REVISION_MISMATCH")
	}
	roots := observe.TrustedRoots{RepositoryRoot: repository, RunRoot: runDir, DurableRoot: durableRoot}
	bundle, bundleRaw, bundleDigest, err := makeAssuranceBundle(roots, document, request)
	if err != nil {
		return assurance.RecordResult{}, err
	}
	references := assurance.ReferenceSet{
		Artifacts: map[string]bool{bundle.ArtifactRef: true},
		Evidence:  make(map[string]bool, len(bundle.EvidenceRefs)),
	}
	for _, reference := range bundle.EvidenceRefs {
		references.Evidence[reference] = true
	}
	input := assurance.RecordRequest{
		Kind: request.Kind, Status: request.Status, CodeRevision: current,
		Producer: request.Producer, RecordedAt: request.RecordedAt,
		Artifact: bundle.ArtifactRef, EvidenceRefs: bundle.EvidenceRefs,
		Supersedes: request.Supersedes, SemanticValid: request.SemanticValid,
		CurrentRevision: current, RevisionReady: true, References: references,
		IdempotencyKey: request.IdempotencyKey,
	}
	assuranceState, ok := object(document["assurance"])
	if !ok {
		return assurance.RecordResult{}, errors.New("manifest assurance state missing")
	}
	slot := string(request.Kind)
	var existing *assurance.Attestation
	if value := assuranceState[slot]; value != nil {
		raw, _ := json.Marshal(value)
		var parsed assurance.Attestation
		if json.Unmarshal(raw, &parsed) != nil {
			return assurance.RecordResult{}, errors.New("invalid stored attestation")
		}
		existing = &parsed
	}
	var result assurance.RecordResult
	if existing == nil {
		if request.Supersedes != nil {
			return assurance.RecordResult{}, errors.New("attestation supersedes missing predecessor")
		}
		result, err = assurance.Record(nil, input)
	} else {
		result, err = assurance.Record(existing, input)
		if err != nil {
			if request.Supersedes == nil || *request.Supersedes != existing.AttestationID {
				return assurance.RecordResult{}, errors.New("new attestation must explicitly supersede current slot")
			}
			result, err = assurance.Record(nil, input)
			if err == nil && result.Attestation.AttestationID == existing.AttestationID {
				return assurance.RecordResult{}, errors.New("attestation cannot supersede itself")
			}
		}
	}
	if err != nil {
		return assurance.RecordResult{}, err
	}
	assuranceState[slot] = result.Attestation
	bundleName := "assurance-v1-" + strings.TrimPrefix(bundleDigest, "sha256:") + ".json"
	bundlePath := filepath.ToSlash(filepath.Join("revision", bundleName))
	if err := registerAssuranceBundle(document, bundle, bundlePath, bundleDigest); err != nil {
		return assurance.RecordResult{}, err
	}
	document["updatedAt"] = request.RecordedAt.UTC().Format(time.RFC3339)
	proposed, err := json.MarshalIndent(document, "", "  ")
	if err != nil {
		return assurance.RecordResult{}, err
	}
	rechecked := gitobserve.Observe(repository, baseline, limits)
	if rechecked.Err != nil || rechecked.Status != gitobserve.StatusReady || rechecked.Revision.ID != current {
		return assurance.RecordResult{}, errors.New("FFI_REVISION_MISMATCH")
	}
	published := storage.PublishRevisionCAS(runDir, storage.RevisionCASRequest{
		ExpectedManifestDigest: expected, ProposedManifest: append(proposed, '\n'),
		ArtifactName: bundleName, Artifact: bundleRaw, ArtifactDigest: bundleDigest,
		ArtifactPrefix: "assurance-v1-",
	})
	if published.Status != storage.CASApplied {
		return assurance.RecordResult{}, fmt.Errorf("assurance publication %s", published.Status)
	}
	return result, nil
}

// ConvergeRun always reloads the manifest-authorized baseline and freshly
// observes the repository before evaluating the sole convergence predicate.
func ConvergeRun(runDir, repository, durableRoot string, limits gitobserve.Limits, proposedDone bool) (assurance.ConvergenceResult, error) {
	_, _, document, err := readCurrentManifest(runDir)
	if err != nil {
		return assurance.ConvergenceResult{}, err
	}
	baseline, _, err := loadAuthorizedBaseline(runDir, document)
	if err != nil {
		return assurance.ConvergenceResult{}, err
	}
	observed := gitobserve.Observe(repository, baseline, limits)
	code, _ := object(document["code"])
	assuranceState, _ := object(document["assurance"])
	review := decodeAttestation(assuranceState["review"])
	verification := decodeAttestation(assuranceState["verification"])
	roots := observe.TrustedRoots{RepositoryRoot: repository, RunRoot: runDir, DurableRoot: durableRoot}
	references, evidenceGap := authoritativeReferences(runDir, roots, document, review, verification)
	if refs, required := bugfixEvidenceRefs(document); required {
		for _, reference := range refs {
			if !references.Evidence[reference] {
				evidenceGap = true
			}
		}
	}
	input := assurance.ConvergenceInput{
		ManifestValid: terminalSemanticallyValid(document, proposedDone), ProposedDone: proposedDone,
		RevisionReady: observed.Status == gitobserve.StatusReady,
		ScopeDrift:    observed.Status == gitobserve.StatusScopeDrift,
		EvidenceGap:   evidenceGap, StoredRevision: revisionID(code), References: references,
	}
	if observed.Status == gitobserve.StatusReady {
		input.ObservedRevision = observed.Revision.ID
	}
	input.Review = review
	input.Verification = verification
	return assurance.Converge(input), nil
}

func readCurrentManifest(runDir string) ([]byte, string, map[string]any, error) {
	raw, expected, err := storage.ReadManifest(runDir)
	if err != nil {
		return nil, "", nil, err
	}
	if result := classifier.Classify(raw); result.Classification != classifier.CurrentStructuralValid {
		return nil, "", nil, errors.New("manifest is not current structural valid")
	}
	var document map[string]any
	if err := json.Unmarshal(raw, &document); err != nil {
		return nil, "", nil, err
	}
	return raw, expected, document, nil
}

func setBaselineManifest(document map[string]any, baseline gitobserve.Baseline, result revision.Result, artifact string, now time.Time) error {
	code, ok := object(document["code"])
	if !ok {
		return errors.New("manifest code state missing")
	}
	previous := revisionID(code)
	code["baseline"] = map[string]any{
		"repositoryKind": "git", "repositoryIdentity": baseline.RepositoryIdentity,
		"worktreeIdentity": baseline.WorktreeIdentity, "head": baseline.Head,
		"startSnapshotDigest": baseline.StartSnapshotDigest,
		"facts": map[string]any{
			"version": 1, "artifact": artifact, "digest": baseline.ArtifactDigest,
		},
	}
	code["scope"] = baseline.Scope
	code["revision"] = revisionManifest(result, now)
	artifacts, ok := object(document["artifacts"])
	if !ok {
		return errors.New("manifest artifact registry missing")
	}
	artifacts["revisionBaseline"] = artifact
	if previous != "" && previous != result.ID {
		annotateManifestAssurance(document, previous, result.ID, "scope_change", now)
	}
	document["updatedAt"] = now.UTC().Format(time.RFC3339)
	return nil
}

func publishDocument(runDir, expected string, document map[string]any) error {
	proposed, err := json.MarshalIndent(document, "", "  ")
	if err != nil {
		return err
	}
	status := storage.ReplaceManifestCAS(runDir, expected, append(proposed, '\n'))
	if status != storage.CASApplied {
		return fmt.Errorf("manifest publication %s", status)
	}
	return nil
}

func revisionID(code map[string]any) string {
	state, ok := object(code["revision"])
	if !ok || state["status"] != "ready" {
		return ""
	}
	value, _ := state["id"].(string)
	return value
}

func makeAssuranceBundle(roots observe.TrustedRoots, document map[string]any, request RunAttestationRequest) (assuranceBundle, []byte, string, error) {
	expectedArtifactKey := "review"
	if request.Kind == assurance.KindVerification {
		expectedArtifactKey = "verify"
	}
	artifacts, ok := object(document["artifacts"])
	artifactPointer, pointerOK := artifacts[request.ArtifactKey].(string)
	if !ok || request.ArtifactKey != expectedArtifactKey || !pointerOK ||
		len(request.Evidence) == 0 || len(request.Evidence) > 64 {
		return assuranceBundle{}, nil, "", errors.New("invalid assurance bundle")
	}
	artifact, err := readManifestPointer(roots, artifactPointer, 16<<20)
	if err != nil {
		return assuranceBundle{}, nil, "", errors.New("registered assurance artifact unavailable")
	}
	bundle := assuranceBundle{
		Version: 1, ArtifactRef: artifactPointer,
		Artifact: append([]byte(nil), artifact...),
	}
	seen := map[string]bool{}
	for _, item := range request.Evidence {
		pointer, ok := artifacts[item.ArtifactKey].(string)
		if !ok || item.ArtifactKey == "" || item.Kind == "" || item.Status != "passed" {
			return assuranceBundle{}, nil, "", errors.New("invalid assurance evidence")
		}
		content, err := readManifestPointer(roots, pointer, 16<<20)
		if err != nil {
			return assuranceBundle{}, nil, "", errors.New("registered assurance evidence unavailable")
		}
		reference := "evidence:" + item.ArtifactKey
		if seen[reference] {
			return assuranceBundle{}, nil, "", errors.New("duplicate assurance evidence")
		}
		seen[reference] = true
		bundle.EvidenceRefs = append(bundle.EvidenceRefs, reference)
		bundle.Evidence = append(bundle.Evidence, bundledEvidence{
			Reference: reference, Pointer: pointer, Kind: item.Kind,
			Status: item.Status, Content: content,
		})
	}
	raw, err := json.Marshal(bundle)
	if err != nil {
		return assuranceBundle{}, nil, "", err
	}
	return bundle, raw, digest.RawSHA256(raw), nil
}

func readManifestPointer(roots observe.TrustedRoots, pointer string, limit int64) ([]byte, error) {
	root, relative, err := observe.PointerLocation(pointer, roots)
	if err != nil {
		return nil, err
	}
	return gitobserve.ReadArtifact(root, relative, limit)
}

func registerAssuranceBundle(document map[string]any, bundle assuranceBundle, path, bundleDigest string) error {
	registry, ok := object(document["assuranceRegistry"])
	if !ok {
		registry = map[string]any{"artifacts": map[string]any{}, "evidence": map[string]any{}}
		document["assuranceRegistry"] = registry
	}
	artifacts, artifactsOK := object(registry["artifacts"])
	evidence, evidenceOK := object(registry["evidence"])
	if !artifactsOK || !evidenceOK {
		return errors.New("invalid assurance registry")
	}
	entry := map[string]any{"bundle": path, "digest": bundleDigest}
	entry["pointer"] = bundle.ArtifactRef
	entry["contentDigest"] = digest.RawSHA256(bundle.Artifact)
	if existing := artifacts[bundle.ArtifactRef]; existing != nil && !sameJSON(existing, entry) {
		return errors.New("artifact reference collision")
	}
	artifacts[bundle.ArtifactRef] = entry
	for index, reference := range bundle.EvidenceRefs {
		value := map[string]any{
			"bundle": path, "digest": bundleDigest,
			"pointer":       bundle.Evidence[index].Pointer,
			"contentDigest": digest.RawSHA256(bundle.Evidence[index].Content),
			"kind":          bundle.Evidence[index].Kind, "status": bundle.Evidence[index].Status,
		}
		if existing := evidence[reference]; existing != nil && !sameJSON(existing, value) {
			return errors.New("evidence reference collision")
		}
		evidence[reference] = value
	}
	return nil
}

func authoritativeReferences(runDir string, roots observe.TrustedRoots, document map[string]any, attestations ...*assurance.Attestation) (assurance.ReferenceSet, bool) {
	result := assurance.ReferenceSet{Artifacts: map[string]bool{}, Evidence: map[string]bool{}}
	registry, ok := object(document["assuranceRegistry"])
	if !ok {
		return result, true
	}
	artifacts, artifactsOK := object(registry["artifacts"])
	evidence, evidenceOK := object(registry["evidence"])
	if !artifactsOK || !evidenceOK {
		return result, true
	}
	bundles := map[string]assuranceBundle{}
	load := func(entry any) (assuranceBundle, bool) {
		value, ok := object(entry)
		if !ok {
			return assuranceBundle{}, false
		}
		path, pathOK := value["bundle"].(string)
		expected, digestOK := value["digest"].(string)
		if !pathOK || !digestOK {
			return assuranceBundle{}, false
		}
		key := path + "\x00" + expected
		if cached, exists := bundles[key]; exists {
			return cached, true
		}
		raw, err := storage.ReadRevisionArtifact(runDir, path, expected, 64<<20)
		if err != nil {
			return assuranceBundle{}, false
		}
		var bundle assuranceBundle
		if json.Unmarshal(raw, &bundle) != nil || bundle.Version != 1 {
			return assuranceBundle{}, false
		}
		bundles[key] = bundle
		return bundle, true
	}
	gap := false
	for _, attestation := range attestations {
		if attestation == nil {
			gap = true
			continue
		}
		bundle, valid := load(artifacts[attestation.Artifact])
		artifactEntry, entryOK := object(artifacts[attestation.Artifact])
		pointer, pointerOK := artifactEntry["pointer"].(string)
		contentDigest, contentDigestOK := artifactEntry["contentDigest"].(string)
		authoritative, artifactErr := readManifestPointer(roots, pointer, 16<<20)
		if !valid || bundle.ArtifactRef != attestation.Artifact ||
			!entryOK || !pointerOK || !contentDigestOK || artifactErr != nil ||
			pointer != attestation.Artifact || digest.RawSHA256(authoritative) != contentDigest ||
			digest.RawSHA256(bundle.Artifact) != contentDigest {
			gap = true
		} else {
			result.Artifacts[attestation.Artifact] = true
		}
		for _, reference := range attestation.EvidenceRefs {
			entry, ok := object(evidence[reference])
			evidenceBundle, valid := load(entry)
			pointer, pointerOK := entry["pointer"].(string)
			contentDigest, contentDigestOK := entry["contentDigest"].(string)
			authoritative, evidenceErr := readManifestPointer(roots, pointer, 16<<20)
			if !ok || !valid || entry["status"] != "passed" ||
				!pointerOK || !contentDigestOK || evidenceErr != nil ||
				digest.RawSHA256(authoritative) != contentDigest ||
				!bundleHasEvidence(evidenceBundle, reference, pointer, contentDigest) {
				gap = true
				continue
			}
			result.Evidence[reference] = true
		}
	}
	return result, gap
}

func bundleHasEvidence(bundle assuranceBundle, reference, pointer, contentDigest string) bool {
	for index, candidate := range bundle.EvidenceRefs {
		if candidate == reference && index < len(bundle.Evidence) &&
			bundle.Evidence[index].Reference == reference &&
			bundle.Evidence[index].Pointer == pointer &&
			bundle.Evidence[index].Status == "passed" &&
			digest.RawSHA256(bundle.Evidence[index].Content) == contentDigest {
			return true
		}
	}
	return false
}

func terminalSemanticallyValid(document map[string]any, proposedDone bool) bool {
	if !proposedDone {
		return false
	}
	track, _ := document["track"].(string)
	tier, _ := document["tier"].(string)
	current, _ := document["currentPhase"].(string)
	signOff, signOffOK := object(document["signOff"])
	phases, phasesOK := object(document["phases"])
	artifacts, artifactsOK := object(document["artifacts"])
	if !signOffOK || !phasesOK || !artifactsOK {
		return false
	}
	if (track == "feature" || tier == "full") && signOff["signed"] != true {
		return false
	}
	required := []string{"implement", "review", "verify"}
	switch track {
	case "feature":
		required = append([]string{"explore", "clarify"}, required...)
		if tier == "full" {
			required = append([]string{"design", "plan"}, required...)
		}
		if current != "verify" && current != "done" {
			return false
		}
	case "bugfix":
		required = append([]string{"diagnose"}, required...)
		if tier == "full" {
			required = append([]string{"plan"}, required...)
		}
		if current != "review" && current != "verify" && current != "done" {
			return false
		}
		if _, required := bugfixEvidenceRefs(document); !required {
			return false
		}
	default:
		return false
	}
	for _, name := range required {
		phase, ok := object(phases[name])
		if !ok || phase["status"] != "complete" {
			return false
		}
		if name == "review" || name == "verify" {
			pointer, pointerOK := phase["artifact"].(string)
			if !pointerOK || artifacts[name] != pointer {
				return false
			}
		}
	}
	return true
}

func bugfixEvidenceRefs(document map[string]any) ([]string, bool) {
	if document["track"] != "bugfix" {
		return nil, false
	}
	state, ok := object(document["bugfix"])
	if !ok {
		return nil, false
	}
	red, redOK := object(state["red"])
	green, greenOK := object(state["green"])
	redExit, redExitOK := red["exit"].(float64)
	greenExit, greenExitOK := green["exit"].(float64)
	redEvidence, redEvidenceOK := red["evidence"].(string)
	greenEvidence, greenEvidenceOK := green["evidence"].(string)
	if !redOK || !greenOK || !redExitOK || !greenExitOK ||
		redExit == 0 || greenExit != 0 || !redEvidenceOK || !greenEvidenceOK ||
		!strings.HasPrefix(redEvidence, "evidence:") || !strings.HasPrefix(greenEvidence, "evidence:") {
		return nil, false
	}
	return []string{redEvidence, greenEvidence}, true
}

func sameJSON(left, right any) bool {
	a, _ := json.Marshal(left)
	b, _ := json.Marshal(right)
	return string(a) == string(b)
}

func decodeAttestation(value any) *assurance.Attestation {
	if value == nil {
		return nil
	}
	raw, err := json.Marshal(value)
	if err != nil {
		return nil
	}
	var parsed assurance.Attestation
	if json.Unmarshal(raw, &parsed) != nil {
		return nil
	}
	return &parsed
}

func annotateManifestAssurance(document map[string]any, from, to, reason string, now time.Time) {
	state, ok := object(document["assurance"])
	if !ok {
		return
	}
	for _, slot := range []string{"review", "verification"} {
		current := decodeAttestation(state[slot])
		if current == nil || current.CodeRevision != from {
			continue
		}
		assurance.AnnotateChanged(current, reason, now, to)
		state[slot] = current
	}
}

func loadAuthorizedBaseline(runDir string, document map[string]any) (gitobserve.Baseline, string, error) {
	code, ok := object(document["code"])
	if !ok {
		return gitobserve.Baseline{}, "", errors.New("manifest code state missing")
	}
	baselineValue, ok := object(code["baseline"])
	if !ok {
		return gitobserve.Baseline{}, "", errors.New("manifest baseline missing")
	}
	factsRef, ok := object(baselineValue["facts"])
	if !ok {
		return gitobserve.Baseline{}, "", errors.New("manifest baseline facts missing")
	}
	artifact, artifactOK := factsRef["artifact"].(string)
	expectedDigest, digestOK := factsRef["digest"].(string)
	artifacts, registryOK := object(document["artifacts"])
	if !artifactOK || !digestOK || !registryOK || artifacts["revisionBaseline"] != artifact {
		return gitobserve.Baseline{}, "", errors.New("manifest baseline authority mismatch")
	}
	raw, err := storage.ReadRevisionArtifact(runDir, artifact, expectedDigest, 256<<20)
	if err != nil {
		return gitobserve.Baseline{}, "", err
	}
	var stored struct {
		Domain             string                `json:"domain"`
		Version            int                   `json:"version"`
		RepositoryIdentity string                `json:"repositoryIdentity"`
		WorktreeIdentity   string                `json:"worktreeIdentity"`
		Head               string                `json:"head"`
		Scope              revision.Scope        `json:"scope"`
		Facts              []gitobserve.PathFact `json:"facts"`
	}
	if err := json.Unmarshal(raw, &stored); err != nil || stored.Domain != "feature-flow-baseline" || stored.Version != 1 {
		return gitobserve.Baseline{}, "", errors.New("invalid baseline artifact")
	}
	start, _ := baselineValue["startSnapshotDigest"].(string)
	baseline := gitobserve.Baseline{
		RepositoryIdentity: stored.RepositoryIdentity, WorktreeIdentity: stored.WorktreeIdentity,
		Head: stored.Head, StartSnapshotDigest: start, Scope: stored.Scope, Facts: stored.Facts,
		Canonical: raw, ArtifactDigest: expectedDigest,
	}
	if baselineValue["repositoryIdentity"] != baseline.RepositoryIdentity ||
		baselineValue["worktreeIdentity"] != baseline.WorktreeIdentity ||
		baselineValue["head"] != baseline.Head ||
		digest.SHA256("baseline-snapshot-v1", raw) != start ||
		gitobserve.ValidateBaseline(baseline) != nil {
		return gitobserve.Baseline{}, "", errors.New("manifest baseline authority mismatch")
	}
	return baseline, artifact, nil
}

func revisionManifest(result revision.Result, now time.Time) map[string]any {
	return map[string]any{
		"status": "ready", "algorithm": result.Algorithm, "id": result.ID,
		"computedAt": now.UTC().Format(time.RFC3339),
	}
}

func object(value any) (map[string]any, bool) {
	out, ok := value.(map[string]any)
	return out, ok
}
