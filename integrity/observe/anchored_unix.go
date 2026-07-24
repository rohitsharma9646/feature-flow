//go:build !windows

package observe

import (
	"errors"
	"io"
	"os"

	"golang.org/x/sys/unix"
)

func readAnchored(base, slug string, max int64, afterRunOpen func()) ([]byte, error) {
	baseFD, err := unix.Open(base, unix.O_RDONLY|unix.O_DIRECTORY|unix.O_CLOEXEC|unix.O_NOFOLLOW, 0)
	if err != nil {
		return nil, errors.New("manifest unavailable")
	}
	defer unix.Close(baseFD)
	runFD, err := unix.Openat(baseFD, slug, unix.O_RDONLY|unix.O_DIRECTORY|unix.O_CLOEXEC|unix.O_NOFOLLOW, 0)
	if err != nil {
		return nil, errors.New("manifest unavailable")
	}
	defer unix.Close(runFD)
	if afterRunOpen != nil {
		afterRunOpen()
	}
	manifestFD, err := unix.Openat(runFD, "manifest.json", unix.O_RDONLY|unix.O_CLOEXEC|unix.O_NOFOLLOW, 0)
	if err != nil {
		return nil, errors.New("manifest unavailable")
	}
	file := os.NewFile(uintptr(manifestFD), "manifest.json")
	defer file.Close()
	info, err := file.Stat()
	if err != nil || !info.Mode().IsRegular() || info.Size() > max {
		return nil, errors.New("manifest unavailable")
	}
	raw, err := io.ReadAll(io.LimitReader(file, max+1))
	if err != nil || int64(len(raw)) > max {
		return nil, errors.New("manifest unavailable")
	}
	return raw, nil
}
