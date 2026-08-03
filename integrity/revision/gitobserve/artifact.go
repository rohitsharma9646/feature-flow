package gitobserve

import (
	"errors"
	"path"
	"strings"
	"unicode/utf8"
)

// ReadArtifact reads a repository-relative regular artifact through the same
// handle-relative, no-follow boundary used for revision observation.
func ReadArtifact(root, logicalPath string, max int64) ([]byte, error) {
	if logicalPath == "" || !utf8.ValidString(logicalPath) ||
		strings.ContainsRune(logicalPath, 0) || strings.Contains(logicalPath, "\\") ||
		strings.HasPrefix(logicalPath, "/") || path.Clean(logicalPath) != logicalPath ||
		logicalPath == "." || logicalPath == ".." || strings.HasPrefix(logicalPath, "../") {
		return nil, errors.New("FFI_REVISION_UNSUPPORTED")
	}
	return readArtifact(root, logicalPath, max)
}
