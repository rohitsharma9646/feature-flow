package hostadapter

import (
	"encoding/json"
	"errors"
	"fmt"
	"path/filepath"
	"strings"

	"github.com/rohitsharma9646/feature-flow/integrity/jsonstrict"
	"github.com/rohitsharma9646/feature-flow/integrity/observe"
	"github.com/rohitsharma9646/feature-flow/integrity/preflight"
)

type codexEnvelope struct {
	HookEventName string `json:"hook_event_name"`
	CWD           string `json:"cwd"`
	ToolName      string `json:"tool_name"`
	ToolInput     struct {
		Command string `json:"command"`
	} `json:"tool_input"`
}

func DecodeCodex(raw []byte) (Decoded, error) {
	if len(raw) == 0 || len(raw) > MaxEnvelopeBytes {
		return Decoded{}, errors.New("Codex hook envelope is empty or oversized")
	}
	if _, err := jsonstrict.Decode(raw); err != nil {
		return Decoded{}, fmt.Errorf("invalid Codex hook envelope: %w", err)
	}
	var envelope codexEnvelope
	if err := json.Unmarshal(raw, &envelope); err != nil {
		return Decoded{}, fmt.Errorf("invalid Codex hook envelope: %w", err)
	}
	if envelope.HookEventName != "PreToolUse" {
		return Decoded{}, nil
	}
	if envelope.ToolName == "Bash" {
		claude := claudeEnvelope{HookEventName: envelope.HookEventName, CWD: envelope.CWD, ToolName: "Bash"}
		claude.ToolInput.Command = envelope.ToolInput.Command
		decoded, err := decodeClaudeMutationCommand(claude)
		decoded.Request.Host = preflight.HostCodex
		return decoded, err
	}
	if envelope.ToolName != "apply_patch" {
		return Decoded{}, nil
	}
	return decodeCodexPatch(envelope.CWD, envelope.ToolInput.Command)
}

func EncodeCodex(decision preflight.Decision) ([]byte, error) {
	// Both hosts document the same supported PreToolUse deny envelope. Keeping
	// one encoder prevents transport-level diagnostic drift.
	return EncodeClaude(decision)
}

func decodeCodexPatch(cwd, patch string) (Decoded, error) {
	if cwd == "" || !filepath.IsAbs(cwd) {
		return Decoded{}, errors.New("trusted cwd is missing")
	}
	sections, err := parsePatchSections(patch)
	if err != nil {
		return Decoded{}, err
	}
	var selected *patchSection
	var target, runRoot string
	for i := range sections {
		normalized, candidateRunRoot, recognized, normalizeErr :=
			normalizeManifestTarget(cwd, sections[i].Path)
		if normalizeErr != nil {
			return Decoded{}, normalizeErr
		}
		if !recognized {
			continue
		}
		if selected != nil {
			return Decoded{}, errors.New("one hook invocation may mutate only one Feature Flow manifest")
		}
		selected = &sections[i]
		target, runRoot = normalized, candidateRunRoot
	}
	if selected == nil {
		return Decoded{}, nil
	}
	proposed, err := applyPatchSection(cwd, *selected)
	if err != nil {
		return Decoded{}, fmt.Errorf("recognized Codex manifest patch is indeterminate: %w", err)
	}
	return Decoded{Recognized: true, Request: preflight.Request{
		SchemaVersion: preflight.SchemaVersion,
		Host:          preflight.HostCodex,
		Event:         preflight.EventPreToolUse,
		Operation:     preflight.OperationManifestMutation,
		ToolClass:     preflight.ToolClassFileWrite,
		Target:        target,
		Context: preflight.TrustedContext{
			RepositoryRoot: filepath.Clean(cwd),
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
	}}, nil
}

type patchSection struct {
	Kind  string
	Path  string
	Lines []string
}

func parsePatchSections(raw string) ([]patchSection, error) {
	lines := strings.Split(strings.ReplaceAll(raw, "\r\n", "\n"), "\n")
	var sections []patchSection
	for i := 0; i < len(lines); i++ {
		var kind, name string
		switch {
		case strings.HasPrefix(lines[i], "*** Update File: "):
			kind, name = "update", strings.TrimPrefix(lines[i], "*** Update File: ")
		case strings.HasPrefix(lines[i], "*** Add File: "):
			kind, name = "add", strings.TrimPrefix(lines[i], "*** Add File: ")
		case strings.HasPrefix(lines[i], "*** Delete File: "):
			kind, name = "delete", strings.TrimPrefix(lines[i], "*** Delete File: ")
		default:
			continue
		}
		if strings.TrimSpace(name) == "" {
			return nil, errors.New("patch section path is empty")
		}
		section := patchSection{Kind: kind, Path: strings.TrimSpace(name)}
		for i++; i < len(lines); i++ {
			if strings.HasPrefix(lines[i], "*** Update File: ") ||
				strings.HasPrefix(lines[i], "*** Add File: ") ||
				strings.HasPrefix(lines[i], "*** Delete File: ") ||
				lines[i] == "*** End Patch" {
				i--
				break
			}
			section.Lines = append(section.Lines, lines[i])
		}
		sections = append(sections, section)
	}
	return sections, nil
}

func applyPatchSection(cwd string, section patchSection) ([]byte, error) {
	switch section.Kind {
	case "delete":
		return nil, nil
	case "add":
		var added []string
		for _, line := range section.Lines {
			if line == "" {
				continue
			}
			if !strings.HasPrefix(line, "+") {
				return nil, errors.New("invalid add-file line")
			}
			added = append(added, strings.TrimPrefix(line, "+"))
		}
		return []byte(strings.Join(added, "\n") + "\n"), nil
	case "update":
	default:
		return nil, errors.New("unknown patch section")
	}
	file := section.Path
	if !filepath.IsAbs(file) {
		file = filepath.Join(cwd, file)
	}
	currentRaw, err := observe.ReadManifest(filepath.Clean(file), preflight.MaxManifestBytes)
	if err != nil {
		return nil, err
	}
	normalizedCurrent := strings.ReplaceAll(string(currentRaw), "\r\n", "\n")
	hadFinalNewline := strings.HasSuffix(normalizedCurrent, "\n")
	current := strings.Split(strings.TrimSuffix(normalizedCurrent, "\n"), "\n")
	for i := 0; i < len(section.Lines); {
		if !strings.HasPrefix(section.Lines[i], "@@") {
			i++
			continue
		}
		i++
		var oldLines, newLines []string
		for i < len(section.Lines) && !strings.HasPrefix(section.Lines[i], "@@") {
			line := section.Lines[i]
			i++
			if strings.HasPrefix(line, `\ No newline`) || line == "" {
				continue
			}
			switch line[0] {
			case ' ':
				oldLines = append(oldLines, line[1:])
				newLines = append(newLines, line[1:])
			case '-':
				oldLines = append(oldLines, line[1:])
			case '+':
				newLines = append(newLines, line[1:])
			default:
				return nil, errors.New("invalid update line")
			}
		}
		at := findLines(current, oldLines)
		if at < 0 {
			return nil, errors.New("patch context does not match current manifest")
		}
		next := make([]string, 0, len(current)-len(oldLines)+len(newLines))
		next = append(next, current[:at]...)
		next = append(next, newLines...)
		next = append(next, current[at+len(oldLines):]...)
		current = next
	}
	proposed := strings.Join(current, "\n")
	if hadFinalNewline {
		proposed += "\n"
	}
	return []byte(proposed), nil
}

func findLines(haystack, needle []string) int {
	if len(needle) == 0 {
		return -1
	}
	for i := 0; i+len(needle) <= len(haystack); i++ {
		match := true
		for j := range needle {
			if haystack[i+j] != needle[j] {
				match = false
				break
			}
		}
		if match {
			return i
		}
	}
	return -1
}
