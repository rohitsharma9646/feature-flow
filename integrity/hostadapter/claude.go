package hostadapter

import (
	"bytes"
	"encoding/json"
	"errors"
	"fmt"
	"path/filepath"
	"strings"

	"github.com/rohitsharma9646/feature-flow/integrity/jsonstrict"
	"github.com/rohitsharma9646/feature-flow/integrity/observe"
	"github.com/rohitsharma9646/feature-flow/integrity/preflight"
)

type claudeEnvelope struct {
	HookEventName string `json:"hook_event_name"`
	CWD           string `json:"cwd"`
	ToolName      string `json:"tool_name"`
	ToolInput     struct {
		FilePath   string          `json:"file_path"`
		Content    json.RawMessage `json:"content"`
		Command    string          `json:"command"`
		OldString  string          `json:"old_string"`
		NewString  string          `json:"new_string"`
		ReplaceAll bool            `json:"replace_all"`
	} `json:"tool_input"`
}

func DecodeClaude(raw []byte) (Decoded, error) {
	if len(raw) == 0 || len(raw) > MaxEnvelopeBytes {
		return Decoded{}, errors.New("Claude hook envelope is empty or oversized")
	}
	if _, err := jsonstrict.Decode(raw); err != nil {
		return Decoded{}, fmt.Errorf("invalid Claude hook envelope: %w", err)
	}
	var envelope claudeEnvelope
	if err := json.Unmarshal(raw, &envelope); err != nil {
		return Decoded{}, fmt.Errorf("invalid Claude hook envelope: %w", err)
	}
	if envelope.HookEventName != "PreToolUse" {
		return Decoded{}, nil
	}
	switch envelope.ToolName {
	case "Bash":
		return decodeClaudeMutationCommand(envelope)
	case "Write", "Edit":
	default:
		return Decoded{}, nil
	}
	target, runRoot, recognized, err := normalizeManifestTarget(envelope.CWD, envelope.ToolInput.FilePath)
	if err != nil {
		return Decoded{}, err
	}
	if !recognized {
		return Decoded{}, nil
	}
	var proposed json.RawMessage
	switch envelope.ToolName {
	case "Write":
		if len(envelope.ToolInput.Content) != 0 {
			proposed, err = contentBytes(envelope.ToolInput.Content)
			if err != nil {
				return Decoded{}, fmt.Errorf("invalid Claude Write content: %w", err)
			}
		}
	case "Edit":
		current, readErr := observe.ReadManifest(
			filepath.Join(envelope.CWD, filepath.FromSlash(target)),
			preflight.MaxManifestBytes,
		)
		if readErr != nil || envelope.ToolInput.OldString == "" {
			return Decoded{}, errors.New("recognized Claude Edit cannot materialize current manifest")
		}
		count := strings.Count(string(current), envelope.ToolInput.OldString)
		if count == 0 || (!envelope.ToolInput.ReplaceAll && count != 1) {
			return Decoded{}, errors.New("recognized Claude Edit match is indeterminate")
		}
		replacements := 1
		if envelope.ToolInput.ReplaceAll {
			replacements = -1
		}
		proposed = json.RawMessage(strings.Replace(
			string(current), envelope.ToolInput.OldString,
			envelope.ToolInput.NewString, replacements,
		))
	}
	request := preflight.Request{
		SchemaVersion: preflight.SchemaVersion,
		Host:          preflight.HostClaude,
		Event:         preflight.EventPreToolUse,
		Operation:     preflight.OperationManifestMutation,
		ToolClass:     preflight.ToolClassFileWrite,
		Target:        target,
		Context: preflight.TrustedContext{
			RepositoryRoot: filepath.Clean(envelope.CWD),
			RunRoot:        runRoot,
		},
		ProposedManifest: proposed,
		RequiredCapabilities: []preflight.CapabilityName{
			preflight.CapabilityLifecycleHook,
			preflight.CapabilityKernel,
			preflight.CapabilitySchema,
			preflight.CapabilityJSONOutput,
		},
		EnforcementMode: preflight.EnforcementEnforce,
	}
	return Decoded{Recognized: true, Request: request}, nil
}

func decodeClaudeMutationCommand(envelope claudeEnvelope) (Decoded, error) {
	fields := mutationArguments(shellWords(envelope.ToolInput.Command))
	if fields == nil {
		return Decoded{}, nil
	}
	runRoot, repository := flagValue(fields, "--run"), flagValue(fields, "--repo")
	if runRoot == "" || repository == "" || !filepath.IsAbs(runRoot) || !filepath.IsAbs(repository) {
		return Decoded{}, errors.New("declared mutation command lacks trusted absolute --run and --repo")
	}
	return Decoded{Recognized: true, Request: preflight.Request{
		SchemaVersion: preflight.SchemaVersion,
		Host:          preflight.HostClaude,
		Event:         preflight.EventPreToolUse,
		Operation:     preflight.OperationCodeMutation,
		ToolClass:     preflight.ToolClassShell,
		Target:        "__declared_code_mutation__",
		Context: preflight.TrustedContext{
			RepositoryRoot: filepath.Clean(repository),
			RunRoot:        filepath.Clean(runRoot),
		},
		RequiredCapabilities: []preflight.CapabilityName{
			preflight.CapabilityLifecycleHook,
			preflight.CapabilityKernel,
			preflight.CapabilitySchema,
			preflight.CapabilityGitObservation,
			preflight.CapabilityJSONOutput,
		},
		EnforcementMode: preflight.EnforcementEnforce,
	}}, nil
}

type shellWord struct {
	text     string
	operator bool
}

// shellWords splits a command line into words and control operators, honoring
// quotes and backslash escapes. It performs no expansion.
func shellWords(command string) []shellWord {
	var words []shellWord
	var current strings.Builder
	inWord := false
	flush := func() {
		if inWord {
			words = append(words, shellWord{text: current.String()})
			current.Reset()
			inWord = false
		}
	}
	for i := 0; i < len(command); i++ {
		c := command[i]
		switch {
		case c == '\'':
			inWord = true
			end := strings.IndexByte(command[i+1:], '\'')
			if end < 0 {
				end = len(command) - i - 1
			}
			current.WriteString(command[i+1 : i+1+end])
			i += end + 1
		case c == '"':
			inWord = true
			for i++; i < len(command) && command[i] != '"'; i++ {
				if command[i] == '\\' && i+1 < len(command) && strings.IndexByte("$`\"\\\n", command[i+1]) >= 0 {
					i++
				}
				current.WriteByte(command[i])
			}
		case c == '\\' && i+1 < len(command):
			inWord = true
			i++
			current.WriteByte(command[i])
		case c == ' ' || c == '\t':
			flush()
		case strings.IndexByte(";&|()\n", c) >= 0:
			flush()
			words = append(words, shellWord{text: string(c), operator: true})
		default:
			inWord = true
			current.WriteByte(c)
		}
	}
	flush()
	return words
}

// mutationArguments returns the arguments after "ff-integrity mutation" when
// that executable is invoked in command position, or nil when it is not.
func mutationArguments(words []shellWord) []string {
	commandPosition := true
	for i, word := range words {
		if word.operator {
			commandPosition = true
			continue
		}
		if !commandPosition {
			continue
		}
		switch {
		case isAssignment(word.text), word.text == "exec", word.text == "command", word.text == "env":
			continue
		}
		commandPosition = false
		base := word.text[strings.LastIndexAny(word.text, `/\`)+1:]
		if (base != "ff-integrity" && base != "ff-integrity.exe") ||
			i+1 >= len(words) || words[i+1].operator || words[i+1].text != "mutation" {
			continue
		}
		arguments := []string{}
		for _, argument := range words[i+2:] {
			if argument.operator {
				break
			}
			arguments = append(arguments, argument.text)
		}
		return arguments
	}
	return nil
}

func isAssignment(word string) bool {
	name, _, found := strings.Cut(word, "=")
	if !found || name == "" {
		return false
	}
	for i, r := range name {
		if r != '_' && (r < 'A' || r > 'Z') && (r < 'a' || r > 'z') && (i == 0 || r < '0' || r > '9') {
			return false
		}
	}
	return true
}

func flagValue(fields []string, name string) string {
	for i, field := range fields {
		if field == name && i+1 < len(fields) {
			return fields[i+1]
		}
		if strings.HasPrefix(field, name+"=") {
			return strings.TrimPrefix(field, name+"=")
		}
	}
	return ""
}

func EncodeClaude(decision preflight.Decision) ([]byte, error) {
	if err := decision.Validate(); err != nil {
		return nil, err
	}
	if !decision.Applicable || decision.Allowed {
		if decision.Applicable && len(decision.Diagnostics) != 0 {
			codes := make([]string, len(decision.Diagnostics))
			for i, diagnostic := range decision.Diagnostics {
				codes[i] = diagnostic.Code
			}
			raw, err := json.Marshal(struct {
				SystemMessage string `json:"systemMessage"`
			}{SystemMessage: "Feature Flow integrity observe-only: " + strings.Join(codes, ",")})
			if err != nil {
				return nil, err
			}
			return append(raw, '\n'), nil
		}
		return nil, nil
	}
	codes := make([]string, len(decision.Diagnostics))
	for i, diagnostic := range decision.Diagnostics {
		codes[i] = diagnostic.Code
	}
	response := struct {
		HookSpecificOutput struct {
			HookEventName            string `json:"hookEventName"`
			PermissionDecision       string `json:"permissionDecision"`
			PermissionDecisionReason string `json:"permissionDecisionReason"`
		} `json:"hookSpecificOutput"`
	}{}
	response.HookSpecificOutput.HookEventName = "PreToolUse"
	response.HookSpecificOutput.PermissionDecision = "deny"
	response.HookSpecificOutput.PermissionDecisionReason =
		"Feature Flow integrity preflight denied: " + strings.Join(codes, ",")
	raw, err := json.Marshal(response)
	if err != nil {
		return nil, err
	}
	return append(raw, '\n'), nil
}

func normalizeManifestTarget(cwd, candidate string) (string, string, bool, error) {
	if cwd == "" || !filepath.IsAbs(cwd) || candidate == "" {
		return "", "", false, errors.New("trusted cwd or target is missing")
	}
	target := candidate
	if !filepath.IsAbs(target) {
		target = filepath.Join(cwd, target)
	}
	relative, err := filepath.Rel(filepath.Clean(cwd), filepath.Clean(target))
	if err != nil || relative == ".." || strings.HasPrefix(relative, ".."+string(filepath.Separator)) {
		// Only a manifest-shaped target outside cwd is indeterminate; any other
		// file there is unrelated to Feature Flow.
		if manifestShaped(target) {
			return "", "", false, errors.New("hook target escapes trusted cwd")
		}
		return "", "", false, nil
	}
	slash := filepath.ToSlash(relative)
	parts := strings.Split(slash, "/")
	if len(parts) != 3 || parts[0] != ".feature-flow" ||
		parts[1] == "" || parts[1] == "." || parts[1] == ".." ||
		parts[2] != "manifest.json" {
		return slash, "", false, nil
	}
	return slash, filepath.Join(filepath.Clean(cwd), ".feature-flow", parts[1]), true, nil
}

func manifestShaped(target string) bool {
	parts := strings.Split(filepath.ToSlash(filepath.Clean(target)), "/")
	return len(parts) >= 3 && parts[len(parts)-1] == "manifest.json" &&
		parts[len(parts)-3] == ".feature-flow"
}

func contentBytes(raw json.RawMessage) (json.RawMessage, error) {
	if len(raw) == 0 {
		return nil, nil
	}
	if bytes.HasPrefix(bytes.TrimSpace(raw), []byte(`"`)) {
		var value string
		if err := json.Unmarshal(raw, &value); err != nil {
			return nil, err
		}
		return json.RawMessage(value), nil
	}
	return append(json.RawMessage(nil), raw...), nil
}
