package main

import (
	"fmt"
	"io"
	"os"

	"github.com/rohitsharma9646/feature-flow/integrity/classifier"
)

func main() {
	os.Exit(run(os.Stdin, os.Stdout, os.Stderr, os.Args[1:]))
}

func run(in io.Reader, out, errOut io.Writer, args []string) int {
	if len(args) != 0 {
		fmt.Fprintln(errOut, "ff-integrity-classify accepts manifest bytes on stdin only")
		return 2
	}
	raw, err := io.ReadAll(io.LimitReader(in, classifier.MaxManifestBytes+1))
	if err != nil {
		fmt.Fprintln(errOut, "failed to read stdin")
		return 2
	}
	encoded, err := classifier.MarshalResult(classifier.Classify(raw))
	if err != nil {
		fmt.Fprintln(errOut, "failed to encode result")
		return 2
	}
	if _, err := out.Write(encoded); err != nil {
		fmt.Fprintln(errOut, "failed to write result")
		return 2
	}
	return 0
}
