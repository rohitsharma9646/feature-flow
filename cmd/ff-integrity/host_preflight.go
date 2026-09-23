package main

import (
	"bytes"
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
	if err != nil {
		return writeDecodeFailure(*hostValue, *modeValue, stdout, stderr)
	}
	if len(raw) == 0 {
		return 0
	}
	if len(raw) > hostadapter.MaxEnvelopeBytes {
		// Every Write, Edit, and Bash call reaches this hook, so an oversized
		// envelope is only indeterminate when it could concern Feature Flow.
		mentions, err := mentionsFeatureFlow(io.MultiReader(bytes.NewReader(raw), input))
		if err != nil || mentions {
			return writeDecodeFailure(*hostValue, *modeValue, stdout, stderr)
		}
		return 0
	}
	var decoded hostadapter.Decoded
	switch *hostValue {
	case "claude":
		decoded, err = hostadapter.DecodeClaude(raw)
	case "codex":
		decoded, err = hostadapter.DecodeCodex(raw)
	}
	if err != nil {
		return writeDecodeFailure(*hostValue, *modeValue, stdout, stderr)
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

func writeDecodeFailure(host, mode string, stdout, stderr writer) int {
	decision := preflight.Decision{
		SchemaVersion: preflight.SchemaVersion,
		Applicable:    true,
		Allowed:       mode == "observe",
		Diagnostics: []preflight.Diagnostic{
			{Code: "FFI_SCHEMA_INVALID", Severity: preflight.SeverityError},
		},
	}
	return writeHostDecision(host, decision, stdout, stderr)
}

var featureFlowMarkers = [][]byte{[]byte(".feature-flow"), []byte("ff-integrity")}

// mentionsFeatureFlow streams input looking for a Feature Flow manifest path
// or integrity command, keeping only a marker-sized overlap between reads.
func mentionsFeatureFlow(input io.Reader) (bool, error) {
	overlap := 0
	for _, marker := range featureFlowMarkers {
		overlap = max(overlap, len(marker)-1)
	}
	buffer := make([]byte, 0, 64<<10+overlap)
	chunk := make([]byte, 64<<10)
	for {
		n, err := input.Read(chunk)
		buffer = append(buffer, chunk[:n]...)
		for _, marker := range featureFlowMarkers {
			if bytes.Contains(buffer, marker) {
				return true, nil
			}
		}
		if len(buffer) > overlap {
			buffer = append(buffer[:0], buffer[len(buffer)-overlap:]...)
		}
		if err == io.EOF {
			return false, nil
		}
		if err != nil {
			return false, err
		}
	}
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
