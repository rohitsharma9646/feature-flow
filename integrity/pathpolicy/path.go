package pathpolicy

import (
	"crypto/sha256"
	"encoding/hex"
	"errors"
	"fmt"
	"os"
	"path/filepath"
	"regexp"
	"strings"
)

var drivePath = regexp.MustCompile(`^[A-Za-z]:`)

type Fact struct {
	LogicalPath string `json:"logicalPath"`
	Exists      bool   `json:"exists"`
	RealPath    string `json:"-"`
	Identity    string `json:"identity,omitempty"`
}

func Resolve(root, pointer string) (Fact, error) {
	if pointer == "" || strings.IndexByte(pointer, 0) >= 0 {
		return Fact{}, errors.New("empty or invalid pointer")
	}
	normalized := strings.ReplaceAll(pointer, `\`, "/")
	if strings.HasPrefix(normalized, "/") || strings.HasPrefix(normalized, "//") ||
		drivePath.MatchString(normalized) {
		return Fact{}, errors.New("absolute pointer")
	}
	clean := filepath.ToSlash(filepath.Clean(filepath.FromSlash(normalized)))
	if clean == "." || clean == ".." || strings.HasPrefix(clean, "../") {
		return Fact{}, errors.New("pointer traversal")
	}
	absRoot, err := filepath.Abs(root)
	if err != nil {
		return Fact{}, errors.New("root unavailable")
	}
	absRoot, err = filepath.EvalSymlinks(absRoot)
	if err != nil {
		return Fact{}, errors.New("root unavailable")
	}
	candidate := filepath.Join(absRoot, filepath.FromSlash(clean))
	parent := candidate
	for {
		if _, err := os.Lstat(parent); err == nil {
			break
		}
		next := filepath.Dir(parent)
		if next == parent {
			return Fact{}, errors.New("parent unavailable")
		}
		parent = next
	}
	realParent, err := filepath.EvalSymlinks(parent)
	if err != nil || !contained(absRoot, realParent) {
		return Fact{}, errors.New("symlink escape")
	}
	fact := Fact{LogicalPath: clean}
	if _, err := os.Lstat(candidate); err == nil {
		real, err := filepath.EvalSymlinks(candidate)
		if err != nil || !contained(absRoot, real) {
			return Fact{}, errors.New("symlink escape")
		}
		realInfo, err := os.Stat(real)
		if err != nil {
			return Fact{}, errors.New("target unavailable")
		}
		fact.Exists = true
		fact.RealPath = filepath.Clean(real)
		token := fmt.Sprintf("%s\x00%d\x00%d\x00%s", fact.RealPath, realInfo.Size(),
			realInfo.ModTime().UnixNano(), realInfo.Mode().String())
		sum := sha256.Sum256([]byte(token))
		fact.Identity = "sha256:" + hex.EncodeToString(sum[:])
	} else if !os.IsNotExist(err) {
		return Fact{}, errors.New("target unavailable")
	}
	return fact, nil
}

func contained(root, candidate string) bool {
	rel, err := filepath.Rel(root, candidate)
	return err == nil && rel != ".." && !strings.HasPrefix(rel, ".."+string(filepath.Separator))
}

func Equivalent(a, b Fact) bool {
	if a.Exists != b.Exists {
		return false
	}
	if a.Exists && a.RealPath != "" && b.RealPath != "" {
		return filepath.Clean(a.RealPath) == filepath.Clean(b.RealPath) && a.Identity == b.Identity
	}
	return a.LogicalPath == b.LogicalPath
}
