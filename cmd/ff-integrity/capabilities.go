package main

import (
	"flag"
	"fmt"

	"github.com/rohitsharma9646/feature-flow/integrity/preflight"
)

const integrityKernelVersion = "1.0.0"

func runCapabilities(args []string, stdout, stderr writer) int {
	flags := flag.NewFlagSet("integrity capabilities", flag.ContinueOnError)
	flags.SetOutput(stderr)
	hostValue := flags.String("host", "direct", "direct, claude, or codex")
	modeValue := flags.String("mode", "enforce", "enforce or observe")
	format := flags.String("format", "json", "json")
	if err := flags.Parse(args); err != nil || len(flags.Args()) != 0 || *format != "json" {
		fmt.Fprintln(stderr, "capabilities requires --host direct|claude|codex and --format json")
		return 2
	}
	host := preflight.Host(*hostValue)
	mode := preflight.EnforcementMode(*modeValue)
	report, err := runtimeCapabilityReport(host, mode, false)
	if err != nil {
		fmt.Fprintln(stderr, err)
		return 2
	}
	raw, err := preflight.MarshalCapabilityReport(report)
	if err != nil {
		fmt.Fprintln(stderr, err)
		return 2
	}
	if _, err := stdout.Write(raw); err != nil {
		return 2
	}
	if report.Enforceable {
		return 0
	}
	return 1
}

func runtimeCapabilityReport(host preflight.Host, mode preflight.EnforcementMode, trustedInvocation bool) (preflight.CapabilityReport, error) {
	if host != preflight.HostDirect && host != preflight.HostClaude && host != preflight.HostCodex {
		return preflight.CapabilityReport{}, fmt.Errorf("invalid capability host %q", host)
	}
	if mode != preflight.EnforcementEnforce && mode != preflight.EnforcementObserve {
		return preflight.CapabilityReport{}, fmt.Errorf("invalid capability mode %q", mode)
	}
	report := preflight.CapabilityReport{
		SchemaVersion:     preflight.SchemaVersion,
		Host:              host,
		Mode:              mode,
		KernelVersion:     integrityKernelVersion,
		SchemaVersionName: "manifest-v1",
		Capabilities: []preflight.CapabilityState{
			{Name: preflight.CapabilityCommandPreflight, State: preflight.CapabilityAvailable, Required: host == preflight.HostDirect, Version: "v1", Evidence: "native ff-integrity command"},
			{Name: preflight.CapabilityKernel, State: preflight.CapabilityAvailable, Required: true, Version: integrityKernelVersion, Evidence: "running native binary"},
			{Name: preflight.CapabilitySchema, State: preflight.CapabilityAvailable, Required: true, Version: "manifest-v1", Evidence: "embedded schema"},
			{Name: preflight.CapabilityGitObservation, State: preflight.CapabilityAvailable, Required: false, Version: "revision-v1", Evidence: "native git observer"},
			{Name: preflight.CapabilityAtomicReplace, State: preflight.CapabilityAvailable, Required: false, Version: "storage-v1", Evidence: "native storage provider"},
			{Name: preflight.CapabilityJSONOutput, State: preflight.CapabilityAvailable, Required: true, Version: "v1", Evidence: "native JSON encoder"},
		},
	}
	if host == preflight.HostDirect {
		report.Capabilities = append(report.Capabilities, preflight.CapabilityState{
			Name: preflight.CapabilityLifecycleHook, State: preflight.CapabilityUnknown,
			Required: false, Evidence: "not applicable to direct invocation",
		})
		report.Enforceable = mode == preflight.EnforcementEnforce
		return report, report.Validate()
	}
	truth := preflight.TruthUnknown
	state := preflight.CapabilityUnknown
	evidence := "standalone inspection cannot attest host trust"
	if trustedInvocation {
		truth = preflight.TruthYes
		state = preflight.CapabilityAvailable
		evidence = "active trusted lifecycle invocation"
	}
	report.Capabilities = append(report.Capabilities, preflight.CapabilityState{
		Name: preflight.CapabilityLifecycleHook, State: state, Required: true,
		Version: "pre-tool-use-v1", Evidence: evidence,
	})
	report.Lifecycle = &preflight.LifecycleState{
		Supported: preflight.TruthYes, Packaged: preflight.TruthYes,
		Enabled: truth, Trusted: truth, Executable: truth,
		Enforceable: trustedInvocation,
	}
	report.Enforceable = mode == preflight.EnforcementEnforce && trustedInvocation
	return report, report.Validate()
}
