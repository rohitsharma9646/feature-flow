package preflight

import "strings"

// Applicable classifies only already-decoded, host-neutral facts. It must stay
// pure so unrelated host calls can return before any repository observation.
func Applicable(request Request) bool {
	switch request.Operation {
	case OperationManifestMutation, OperationTerminal, OperationAssurance:
		parts := strings.Split(request.Target, "/")
		return len(parts) == 3 &&
			parts[0] == ".feature-flow" &&
			parts[1] != "" && parts[1] != "." && parts[1] != ".." &&
			parts[2] == "manifest.json"
	case OperationCodeMutation:
		// Code mutation is applicable only when the adapter or direct command has
		// explicitly declared this operation and supplied its trusted run context.
		return request.Target != ""
	default:
		return false
	}
}
