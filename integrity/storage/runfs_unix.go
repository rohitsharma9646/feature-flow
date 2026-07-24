//go:build !windows

package storage

import (
	"bytes"
	"errors"
	"fmt"
	"io/fs"
	"os"
	"path/filepath"

	"golang.org/x/sys/unix"
)

type anchoredRunFS struct {
	parentFD    int
	runFD       int
	migrationFD int
	runName     string
}

func openRunFS(runDir string) (runFS, error) {
	parent := filepath.Dir(filepath.Clean(runDir))
	name := filepath.Base(filepath.Clean(runDir))
	if name == "." || name == string(filepath.Separator) {
		return nil, errUnsafeFilesystem
	}
	parentFD, err := unix.Open(parent, unix.O_RDONLY|unix.O_DIRECTORY|unix.O_CLOEXEC|unix.O_NOFOLLOW, 0)
	if err != nil {
		return nil, err
	}
	runFD, err := unix.Openat(parentFD, name, unix.O_RDONLY|unix.O_DIRECTORY|unix.O_CLOEXEC|unix.O_NOFOLLOW, 0)
	if err != nil {
		unix.Close(parentFD)
		return nil, err
	}
	return &anchoredRunFS{parentFD: parentFD, runFD: runFD, migrationFD: -1, runName: name}, nil
}

func (r *anchoredRunFS) Close() error {
	var first error
	if r.migrationFD >= 0 {
		first = unix.Close(r.migrationFD)
		r.migrationFD = -1
	}
	if err := unix.Close(r.runFD); first == nil {
		first = err
	}
	if err := unix.Close(r.parentFD); first == nil {
		first = err
	}
	return first
}

func (r *anchoredRunFS) ReadManifest(max int64) ([]byte, error) {
	fd, err := unix.Openat(r.runFD, "manifest.json", unix.O_RDONLY|unix.O_CLOEXEC|unix.O_NOFOLLOW, 0)
	if err != nil {
		return nil, err
	}
	file := os.NewFile(uintptr(fd), "manifest.json")
	defer file.Close()
	info, err := file.Stat()
	if err != nil || !info.Mode().IsRegular() || info.Size() > max {
		return nil, errUnsafeFilesystem
	}
	return readLimited(file, max)
}

func (r *anchoredRunFS) ValidateLocation() error {
	var opened unix.Stat_t
	if err := unix.Fstat(r.runFD, &opened); err != nil {
		return err
	}
	var current unix.Stat_t
	if err := unix.Fstatat(r.parentFD, r.runName, &current, unix.AT_SYMLINK_NOFOLLOW); err != nil {
		return err
	}
	if opened.Dev != current.Dev || opened.Ino != current.Ino || current.Mode&unix.S_IFMT != unix.S_IFDIR {
		return errUnsafeFilesystem
	}
	return nil
}

func (r *anchoredRunFS) EnsureMigration() error {
	if r.migrationFD >= 0 {
		return nil
	}
	if err := unix.Mkdirat(r.runFD, "migration", 0o700); err != nil && !errors.Is(err, unix.EEXIST) {
		return err
	}
	fd, err := unix.Openat(r.runFD, "migration", unix.O_RDONLY|unix.O_DIRECTORY|unix.O_CLOEXEC|unix.O_NOFOLLOW, 0)
	if err != nil {
		return err
	}
	var stat unix.Stat_t
	if err := unix.Fstat(fd, &stat); err != nil {
		unix.Close(fd)
		return err
	}
	if stat.Mode&unix.S_IFMT != unix.S_IFDIR {
		unix.Close(fd)
		return errUnsafeFilesystem
	}
	if err := unix.Fchmod(fd, 0o700); err != nil {
		unix.Close(fd)
		return err
	}
	r.migrationFD = fd
	return nil
}

func (r *anchoredRunFS) PublishSnapshot(name string, raw []byte) (bool, error) {
	if r.migrationFD < 0 || filepath.Base(name) != name {
		return false, errUnsafeFilesystem
	}
	if current, err := r.readMigration(name, int64(len(raw))); err == nil {
		if bytes.Equal(current, raw) {
			return false, nil
		}
		return false, errCollision
	} else if !errors.Is(err, fs.ErrNotExist) && !errors.Is(err, unix.ENOENT) {
		return false, err
	}
	temp, err := r.writeTempAt(r.migrationFD, ".snapshot-", raw)
	if err != nil {
		return false, err
	}
	defer unix.Unlinkat(r.migrationFD, temp, 0)
	if err := unix.Linkat(r.migrationFD, temp, r.migrationFD, name, 0); err != nil {
		if errors.Is(err, unix.EEXIST) {
			if current, readErr := r.readMigration(name, int64(len(raw))); readErr == nil && bytes.Equal(current, raw) {
				return false, nil
			}
			return false, errCollision
		}
		return false, err
	}
	if err := unix.Unlinkat(r.migrationFD, temp, 0); err != nil {
		return true, err
	}
	if err := syncFD(r.migrationFD); err != nil {
		return true, err
	}
	return true, nil
}

func (r *anchoredRunFS) RemoveSnapshot(name string) error {
	if r.migrationFD < 0 || filepath.Base(name) != name {
		return errUnsafeFilesystem
	}
	err := unix.Unlinkat(r.migrationFD, name, 0)
	if errors.Is(err, unix.ENOENT) {
		return nil
	}
	return err
}

func (r *anchoredRunFS) WriteManifestTemp(raw []byte) (string, error) {
	return r.writeTempAt(r.runFD, ".manifest-v1-", raw)
}

func (r *anchoredRunFS) RemoveManifestTemp(name string) error {
	if filepath.Base(name) != name {
		return errUnsafeFilesystem
	}
	err := unix.Unlinkat(r.runFD, name, 0)
	if errors.Is(err, unix.ENOENT) {
		return nil
	}
	return err
}

func (r *anchoredRunFS) ReplaceManifest(name string) error {
	if filepath.Base(name) != name {
		return errUnsafeFilesystem
	}
	return unix.Renameat(r.runFD, name, r.runFD, "manifest.json")
}

func (r *anchoredRunFS) SyncRun() error { return syncFD(r.runFD) }

func (r *anchoredRunFS) readMigration(name string, max int64) ([]byte, error) {
	fd, err := unix.Openat(r.migrationFD, name, unix.O_RDONLY|unix.O_CLOEXEC|unix.O_NOFOLLOW, 0)
	if err != nil {
		return nil, err
	}
	file := os.NewFile(uintptr(fd), name)
	defer file.Close()
	return readLimited(file, max)
}

func (r *anchoredRunFS) writeTempAt(dirFD int, prefix string, raw []byte) (string, error) {
	for attempt := 0; attempt < 100; attempt++ {
		name := fmt.Sprintf("%s%d-%d", prefix, os.Getpid(), attempt)
		fd, err := unix.Openat(dirFD, name, unix.O_WRONLY|unix.O_CREAT|unix.O_EXCL|unix.O_CLOEXEC|unix.O_NOFOLLOW, 0o600)
		if errors.Is(err, unix.EEXIST) {
			continue
		}
		if err != nil {
			return "", err
		}
		file := os.NewFile(uintptr(fd), name)
		ok := false
		if writeAll(file, raw) == nil && file.Sync() == nil && file.Close() == nil {
			ok = true
		}
		if !ok {
			file.Close()
			unix.Unlinkat(dirFD, name, 0)
			return "", errors.New("temporary publication failed")
		}
		return name, nil
	}
	return "", errors.New("temporary name exhausted")
}

func syncFD(fd int) error {
	return unix.Fsync(fd)
}
