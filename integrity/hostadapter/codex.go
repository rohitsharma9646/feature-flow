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
	var effects []manifestEffect
	for _, section := range sections {
		sectionEffects, err := manifestEffects(cwd, section)
		if err != nil {
			return Decoded{}, err
		}
		effects = append(effects, sectionEffects...)
	}
	if len(effects) == 0 {
		return Decoded{}, nil
	}
	if len(effects) > 1 {
		return Decoded{}, errors.New("one hook invocation may mutate only one Feature Flow manifest")
	}
	effect := effects[0]
	var proposed []byte
	if !effect.removed {
		proposed, err = applyPatchSection(cwd, effect.section)
		if err != nil {
			return Decoded{}, fmt.Errorf("recognized Codex manifest patch is indeterminate: %w", err)
		}
	}
	return Decoded{Recognized: true, Request: preflight.Request{
		SchemaVersion: preflight.SchemaVersion,
		Host:          preflight.HostCodex,
		Event:         preflight.EventPreToolUse,
		Operation:     preflight.OperationManifestMutation,
		ToolClass:     preflight.ToolClassFileWrite,
		Target:        effect.target,
		Context: preflight.TrustedContext{
			RepositoryRoot: filepath.Clean(cwd),
			RunRoot:        effect.runRoot,
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
	Kind   string
	Path   string
	MoveTo string
	Lines  []string
}

// manifestEffect is one Feature Flow manifest a patch section writes. A
// removed manifest (deleted or moved away) has no proposed content.
type manifestEffect struct {
	target, runRoot string
	section         patchSection
	removed         bool
}

func manifestEffects(cwd string, section patchSection) ([]manifestEffect, error) {
	source, sourceRun, sourceRecognized, err := normalizeManifestTarget(cwd, section.Path)
	if err != nil {
		return nil, err
	}
	if section.MoveTo == "" {
		if !sourceRecognized {
			return nil, nil
		}
		return []manifestEffect{{target: source, runRoot: sourceRun, section: section, removed: section.Kind == "delete"}}, nil
	}
	destination, _, destinationRecognized, err := normalizeManifestTarget(cwd, section.MoveTo)
	if err != nil {
		return nil, err
	}
	if sourceRecognized && destinationRecognized && source == destination {
		return []manifestEffect{{target: source, runRoot: sourceRun, section: section}}, nil
	}
	if destinationRecognized {
		// The moved-in content comes from a file outside the anchored manifest
		// reader's reach, so the proposed manifest cannot be materialized.
		return nil, errors.New("patch moves a file onto a Feature Flow manifest")
	}
	if sourceRecognized {
		return []manifestEffect{{target: source, runRoot: sourceRun, section: section, removed: true}}, nil
	}
	return nil, nil
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
		if kind == "update" && i+1 < len(lines) && strings.HasPrefix(lines[i+1], "*** Move to: ") {
			i++
			section.MoveTo = strings.TrimSpace(strings.TrimPrefix(lines[i], "*** Move to: "))
			if section.MoveTo == "" {
				return nil, errors.New("patch move path is empty")
			}
		}
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

type patchChunk struct {
	oldLines, newLines []string
	endOfFile          bool
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
	chunks, err := parseChunks(section.Lines)
	if err != nil {
		return nil, err
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
	from := 0
	for _, chunk := range chunks {
		at := -1
		if chunk.endOfFile {
			if start := len(current) - len(chunk.oldLines); start >= from &&
				findLines(current[start:], chunk.oldLines) == 0 {
				at = start
			} else if len(chunk.oldLines) == 0 {
				at = len(current)
			}
		} else if found := findLines(current[from:], chunk.oldLines); found >= 0 {
			at = from + found
		}
		if at < 0 {
			return nil, errors.New("patch context does not match current manifest")
		}
		next := make([]string, 0, len(current)-len(chunk.oldLines)+len(chunk.newLines))
		next = append(next, current[:at]...)
		next = append(next, chunk.newLines...)
		next = append(next, current[at+len(chunk.oldLines):]...)
		current = next
		from = at + len(chunk.newLines)
	}
	proposed := strings.Join(current, "\n")
	if hadFinalNewline {
		proposed += "\n"
	}
	return []byte(proposed), nil
}

// parseChunks splits update lines into hunks. A hunk starts at each "@@"
// header; the first hunk may omit its header, and "*** End of File" anchors
// the preceding hunk to the end of the file.
func parseChunks(lines []string) ([]patchChunk, error) {
	var chunks []patchChunk
	var chunk *patchChunk
	for _, line := range lines {
		switch {
		case strings.HasPrefix(line, "@@"):
			chunks = append(chunks, patchChunk{})
			chunk = &chunks[len(chunks)-1]
			continue
		case line == "*** End of File":
			if chunk == nil {
				return nil, errors.New("end-of-file marker outside a hunk")
			}
			chunk.endOfFile = true
			chunk = nil
			continue
		case strings.HasPrefix(line, `\ No newline`) || line == "":
			continue
		}
		if chunk == nil {
			chunks = append(chunks, patchChunk{})
			chunk = &chunks[len(chunks)-1]
		}
		switch line[0] {
		case ' ':
			chunk.oldLines = append(chunk.oldLines, line[1:])
			chunk.newLines = append(chunk.newLines, line[1:])
		case '-':
			chunk.oldLines = append(chunk.oldLines, line[1:])
		case '+':
			chunk.newLines = append(chunk.newLines, line[1:])
		default:
			return nil, errors.New("invalid update line")
		}
	}
	return chunks, nil
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
