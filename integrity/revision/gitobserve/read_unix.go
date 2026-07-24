//go:build !windows

package gitobserve

import (
	"errors"
	"io"
	"os"
	"path/filepath"
	"strings"

	"github.com/rohitsharma9646/feature-flow/integrity/digest"
	"github.com/rohitsharma9646/feature-flow/integrity/revision"
	"golang.org/x/sys/unix"
)

func observeWorktree(root, name string, max int64) (revision.EntryKind, string, *string, *string, int64, error) {
	rootFD, err := unix.Open(root, unix.O_RDONLY|unix.O_DIRECTORY|unix.O_CLOEXEC|unix.O_NOFOLLOW, 0)
	if err != nil {
		return "", "", nil, nil, 0, errors.New("FFI_REVISION_UNSUPPORTED")
	}
	defer unix.Close(rootFD)
	parts := strings.Split(filepath.ToSlash(name), "/")
	current := rootFD
	for _, component := range parts[:len(parts)-1] {
		next, openErr := unix.Openat(current, component, unix.O_RDONLY|unix.O_DIRECTORY|unix.O_CLOEXEC|unix.O_NOFOLLOW, 0)
		if current != rootFD {
			unix.Close(current)
		}
		if openErr != nil {
			return "", "", nil, nil, 0, errors.New("FFI_REVISION_UNSUPPORTED")
		}
		current = next
	}
	if current != rootFD {
		defer unix.Close(current)
	}
	base := parts[len(parts)-1]
	var stat unix.Stat_t
	if err := unix.Fstatat(current, base, &stat, unix.AT_SYMLINK_NOFOLLOW); errors.Is(err, unix.ENOENT) {
		return "", "", nil, nil, 0, nil
	} else if err != nil {
		return "", "", nil, nil, 0, errors.New("FFI_REVISION_UNSUPPORTED")
	}
	switch stat.Mode & unix.S_IFMT {
	case unix.S_IFLNK:
		buffer := make([]byte, max+1)
		count, readErr := unix.Readlinkat(current, base, buffer)
		if readErr != nil || int64(count) > max {
			return "", "", nil, nil, 0, errors.New("FFI_REVISION_UNSUPPORTED")
		}
		value := digest.RawSHA256(buffer[:count])
		return revision.KindSymlink, "120000", nil, &value, int64(count), nil
	case unix.S_IFREG:
		fd, openErr := unix.Openat(current, base, unix.O_RDONLY|unix.O_CLOEXEC|unix.O_NOFOLLOW, 0)
		if openErr != nil {
			return "", "", nil, nil, 0, errors.New("FFI_REVISION_UNSUPPORTED")
		}
		file := os.NewFile(uintptr(fd), base)
		defer file.Close()
		var opened unix.Stat_t
		info, statErr := file.Stat()
		if statErr != nil || unix.Fstat(fd, &opened) != nil || info.Size() > max ||
			opened.Dev != stat.Dev || opened.Ino != stat.Ino ||
			opened.Mode != stat.Mode || opened.Size != stat.Size {
			return "", "", nil, nil, 0, errors.New("FFI_REVISION_UNSUPPORTED")
		}
		raw, readErr := io.ReadAll(io.LimitReader(file, max+1))
		if readErr != nil || int64(len(raw)) > max {
			return "", "", nil, nil, 0, errors.New("FFI_REVISION_UNSUPPORTED")
		}
		value := digest.RawSHA256(raw)
		mode := "100644"
		if stat.Mode&0o111 != 0 {
			mode = "100755"
		}
		return revision.KindFile, mode, &value, nil, int64(len(raw)), nil
	default:
		return "", "", nil, nil, 0, errors.New("FFI_REVISION_UNSUPPORTED")
	}
}

func readArtifact(root, name string, max int64) ([]byte, error) {
	rootFD, err := unix.Open(root, unix.O_RDONLY|unix.O_DIRECTORY|unix.O_CLOEXEC|unix.O_NOFOLLOW, 0)
	if err != nil {
		return nil, errors.New("FFI_REVISION_UNSUPPORTED")
	}
	defer unix.Close(rootFD)
	parts := strings.Split(filepath.ToSlash(name), "/")
	current := rootFD
	for _, component := range parts[:len(parts)-1] {
		next, openErr := unix.Openat(current, component, unix.O_RDONLY|unix.O_DIRECTORY|unix.O_CLOEXEC|unix.O_NOFOLLOW, 0)
		if current != rootFD {
			unix.Close(current)
		}
		if openErr != nil {
			return nil, errors.New("FFI_REVISION_UNSUPPORTED")
		}
		current = next
	}
	if current != rootFD {
		defer unix.Close(current)
	}
	fd, err := unix.Openat(current, parts[len(parts)-1], unix.O_RDONLY|unix.O_CLOEXEC|unix.O_NOFOLLOW, 0)
	if err != nil {
		return nil, errors.New("FFI_REVISION_UNSUPPORTED")
	}
	file := os.NewFile(uintptr(fd), name)
	defer file.Close()
	info, err := file.Stat()
	if err != nil || !info.Mode().IsRegular() || info.Size() > max {
		return nil, errors.New("FFI_REVISION_UNSUPPORTED")
	}
	raw, err := io.ReadAll(io.LimitReader(file, max+1))
	if err != nil || int64(len(raw)) > max {
		return nil, errors.New("FFI_REVISION_UNSUPPORTED")
	}
	return raw, nil
}
