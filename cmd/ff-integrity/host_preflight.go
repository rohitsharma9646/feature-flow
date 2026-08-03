package main

import (
	"flag"
	"fmt"
	"io"

	"github.com/rohitsharma9646/feature-flow/integrity/hostadapter"
	"github.com/rohitsharma9646/feature-flow/integrity/preflight"
)

func runHostPreflight(args []string, input io.Reader, stdout, stderr writer) int {
	flags := flag.NewFlagSet("host preflight", flag.ContinueOnError)
	flags.SetOutput(stderr)
	hostValue := flags.String("host", "", "claude or codex")
	modeValue := flags.String("mode", "enforce", "enforce or observe")
	if err := flags.Parse(args); err != nil || len(flags.Args()) != 0 ||
		(*hostValue != "claude" && *hostValue != "codex") ||
		(*modeValue != "enforce" && *modeValue != "observe") {
		fmt.Fprintln(stderr, "host-preflight requires --host claude|codex and --mode enforce|observe")
		return 2
	}
	raw, err := io.ReadAll(io.LimitReader(input, hostadapter.MaxEnvelopeBytes+1))
	if err != nil || len(raw) == 0 || len(raw) > hostadapter.MaxEnvelopeBytes {
		fmt.Fprintln(stderr, "host envelope unavailable or exceeds limit")
		return 2
	}
	var decoded hostadapter.Decoded
	switch *hostValue {
	case "claude":
		decoded, err = hostadapter.DecodeClaude(raw)
	case "codex":
		decoded, err = hostadapter.DecodeCodex(raw)
	}
	if err != nil {
		decision := preflight.Decision{
			SchemaVersion: preflight.SchemaVersion,
			Applicable:    true,
			Allowed:       false,
			Diagnostics: []preflight.Diagnostic{
				{Code: "FFI_SCHEMA_INVALID", Severity: preflight.SeverityError},
			},
		}
		if *modeValue == "observe" {
			decision.Allowed = true
		}
		return writeHostDecision(*hostValue, decision, stdout, stderr)
	}
	if !decoded.Recognized {
		return 0
	}
	decoded.Request.EnforcementMode = preflight.EnforcementMode(*modeValue)
	decoded.Request.Context.DurableRoot = configuredDurableRoot(decoded.Request.Context.RepositoryRoot)
	engine := preflight.Engine{
		Capabilities: func(request preflight.Request) (preflight.CapabilityReport, error) {
			return runtimeCapabilityReport(request.Host, request.EnforcementMode, true)
		},
		Authority: preflight.RuntimeAuthority,
	}
	return writeHostDecision(*hostValue, engine.Decide(decoded.Request), stdout, stderr)
}

func writeHostDecision(host string, decision preflight.Decision, stdout, stderr writer) int {
	var raw []byte
	var err error
	switch host {
	case "claude":
		raw, err = hostadapter.EncodeClaude(decision)
	case "codex":
		raw, err = hostadapter.EncodeCodex(decision)
	}
	if err != nil {
		fmt.Fprintln(stderr, "host response encoding failed")
		return 2
	}
	if len(raw) != 0 {
		if _, err := stdout.Write(raw); err != nil {
			return 2
		}
	}
	// Lifecycle hosts consume the normalized deny from stdout. A successful
	// hook process exit preserves the structured reason instead of replacing it
	// with host-specific command-failure handling.
	return 0
}
