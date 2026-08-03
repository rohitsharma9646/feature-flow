package preflight

import (
	"sort"

	"github.com/rohitsharma9646/feature-flow/integrity/diagnostics"
)

type CapabilityProvider func(Request) (CapabilityReport, error)
type TransitionAuthority func(Request) ([]string, error)

type Engine struct {
	Capabilities CapabilityProvider
	Authority    TransitionAuthority
}

func (e Engine) Decide(request Request) Decision {
	if err := request.Validate(); err != nil {
		return denied("FFI_SCHEMA_INVALID")
	}
	if !Applicable(request) {
		return Decision{SchemaVersion: SchemaVersion, Applicable: false, Allowed: true}
	}
	if e.Capabilities == nil || e.Authority == nil {
		return denied("FFI_CAPABILITY_DEGRADED")
	}
	report, err := e.Capabilities(request)
	if err != nil || report.Validate() != nil {
		return denied("FFI_CAPABILITY_DEGRADED")
	}
	evaluation := EvaluateCapabilities(report, request.RequiredCapabilities)
	if !evaluation.Available {
		if request.EnforcementMode == EnforcementObserve {
			codes := diagnosticCodesOf(evaluation.Diagnostics)
			authorityCodes, authorityErr := e.Authority(request)
			if authorityErr != nil {
				codes = append(codes, "FFI_OBSERVATION_FAILED")
			} else {
				codes = append(codes, authorityCodes...)
			}
			return Decision{
				SchemaVersion: SchemaVersion,
				Applicable:    true,
				Allowed:       true,
				Diagnostics:   diagnosticsForCodes(codes),
				Capabilities:  &report,
			}
		}
		decision := denied(diagnosticCodesOf(evaluation.Diagnostics)...)
		decision.Capabilities = &report
		return decision
	}
	codes, err := e.Authority(request)
	if err != nil {
		if request.EnforcementMode == EnforcementObserve {
			return Decision{
				SchemaVersion: SchemaVersion,
				Applicable:    true,
				Allowed:       true,
				Diagnostics:   diagnosticsForCodes([]string{"FFI_OBSERVATION_FAILED"}),
				Capabilities:  &report,
			}
		}
		decision := denied("FFI_OBSERVATION_FAILED")
		decision.Capabilities = &report
		return decision
	}
	normalized := diagnosticsForCodes(codes)
	return Decision{
		SchemaVersion: SchemaVersion,
		Applicable:    true,
		Allowed:       request.EnforcementMode == EnforcementObserve || len(normalized) == 0,
		Diagnostics:   normalized,
		Capabilities:  &report,
	}
}

func denied(codes ...string) Decision {
	return Decision{
		SchemaVersion: SchemaVersion,
		Applicable:    true,
		Allowed:       false,
		Diagnostics:   diagnosticsForCodes(codes),
	}
}

func diagnosticsForCodes(codes []string) []Diagnostic {
	catalogue := diagnostics.All()
	unique := make(map[string]Diagnostic, len(codes))
	for _, code := range codes {
		entry, ok := catalogue[code]
		if !ok {
			code = "FFI_OBSERVATION_FAILED"
			entry = catalogue[code]
		}
		severity := Severity(entry.Severity)
		if !oneOf(string(severity), string(SeverityInfo), string(SeverityWarning), string(SeverityError)) {
			severity = SeverityError
		}
		unique[code] = Diagnostic{Code: code, Severity: severity}
	}
	out := make([]Diagnostic, 0, len(unique))
	for _, diagnostic := range unique {
		out = append(out, diagnostic)
	}
	sort.Slice(out, func(i, j int) bool { return out[i].Code < out[j].Code })
	return out
}

func diagnosticCodesOf(in []Diagnostic) []string {
	out := make([]string, len(in))
	for i, diagnostic := range in {
		out[i] = diagnostic.Code
	}
	return out
}
