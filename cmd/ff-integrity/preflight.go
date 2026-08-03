package main

import (
	"flag"
	"fmt"
	"os"

	"github.com/rohitsharma9646/feature-flow/integrity/preflight"
)

func runPreflight(args []string, stdout, stderr writer) int {
	flags := flag.NewFlagSet("integrity preflight", flag.ContinueOnError)
	flags.SetOutput(stderr)
	input := flags.String("input", "", "bounded host-neutral JSON request file")
	format := flags.String("format", "json", "json")
	if err := flags.Parse(args); err != nil || *input == "" || *format != "json" || len(flags.Args()) != 0 {
		fmt.Fprintln(stderr, "preflight requires --input <request.json> and --format json")
		return 2
	}
	info, err := os.Stat(*input)
	if err != nil || !info.Mode().IsRegular() || info.Size() <= 0 || info.Size() > preflight.MaxRequestBytes {
		fmt.Fprintln(stderr, "preflight input unavailable or exceeds limit")
		return 2
	}
	raw, err := os.ReadFile(*input)
	if err != nil {
		fmt.Fprintln(stderr, "preflight input unavailable")
		return 2
	}
	request, err := preflight.DecodeRequest(raw)
	if err != nil {
		fmt.Fprintln(stderr, err)
		return 2
	}
	engine := preflight.Engine{
		Capabilities: func(request preflight.Request) (preflight.CapabilityReport, error) {
			return runtimeCapabilityReport(request.Host, request.EnforcementMode, false)
		},
		Authority: preflight.RuntimeAuthority,
	}
	decision := engine.Decide(request)
	result, err := preflight.MarshalDecision(decision)
	if err != nil {
		fmt.Fprintln(stderr, err)
		return 2
	}
	if _, err := stdout.Write(result); err != nil {
		return 2
	}
	if !decision.Applicable || decision.Allowed {
		return 0
	}
	return 1
}
