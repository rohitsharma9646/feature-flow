//go:build windows

package storage

import (
	"bytes"
	"errors"
	"io/fs"
	"os"
	"path/filepath"

	"golang.org/x/sys/windows"
)

type lockedWindowsRunFS struct {
	parentHandle    windows.Handle
	runHandle       windows.Handle
	migrationHandle windows.Handle
	revisionHandle  windows.Handle
	runDir          string
	migrationDir    string
	publisher       publisher
}

func openRunFS(runDir string) (runFS, error) {
	clean := filepath.Clean(runDir)
	parentHandle, err := openWindowsDirectory(filepath.Dir(clean))
	if err != nil {
		return nil, err
	}
	runHandle, err := openWindowsDirectory(clean)
	if err != nil {
		windows.CloseHandle(parentHandle)
		return nil, err
	}
	return &lockedWindowsRunFS{
		parentHandle: parentHandle, runHandle: runHandle,
		migrationHandle: windows.InvalidHandle,
		revisionHandle:  windows.InvalidHandle,
		runDir:          clean, migrationDir: filepath.Join(clean, "migration"),
		publisher: newPublisher(),
	}, nil
}

func (r *lockedWindowsRunFS) Close() error {
	var first error
	if r.migrationHandle != windows.InvalidHandle {
		first = windows.CloseHandle(r.migrationHandle)
		r.migrationHandle = windows.InvalidHandle
	}
	if r.revisionHandle != windows.InvalidHandle {
		if err := windows.CloseHandle(r.revisionHandle); first == nil {
			first = err
		}
		r.revisionHandle = windows.InvalidHandle
	}
	if err := windows.CloseHandle(r.runHandle); first == nil {
		first = err
	}
	if err := windows.CloseHandle(r.parentHandle); first == nil {
		first = err
	}
	return first
}

func (r *lockedWindowsRunFS) ReadManifest(max int64) ([]byte, error) {
	return readWindowsRegular(filepath.Join(r.runDir, "manifest.json"), max)
}

func (r *lockedWindowsRunFS) ValidateLocation() error {
	current, err := openWindowsDirectory(r.runDir)
	if err != nil {
		return err
	}
	defer windows.CloseHandle(current)
	same, err := sameWindowsFile(r.runHandle, current)
	if err != nil || !same {
		return errUnsafeFilesystem
	}
	return nil
}

func (r *lockedWindowsRunFS) EnsureMigration() error {
	if r.migrationHandle != windows.InvalidHandle {
		return nil
	}
	if err := os.Mkdir(r.migrationDir, 0o700); err != nil && !errors.Is(err, fs.ErrExist) {
		return err
	}
	handle, err := openWindowsDirectory(r.migrationDir)
	if err != nil {
		return err
	}
	r.migrationHandle = handle
	return nil
}

func (r *lockedWindowsRunFS) PublishSnapshot(name string, raw []byte) (bool, error) {
	if r.migrationHandle == windows.InvalidHandle || filepath.Base(name) != name {
		return false, errUnsafeFilesystem
	}
	destination := filepath.Join(r.migrationDir, name)
	if current, err := readWindowsRegular(destination, int64(len(raw))); err == nil {
		if bytes.Equal(current, raw) {
			return false, nil
		}
		return false, errCollision
	} else if !errors.Is(err, fs.ErrNotExist) && !errors.Is(err, windows.ERROR_FILE_NOT_FOUND) {
		return false, err
	}
	temp, err := writeTemp(r.migrationDir, ".snapshot-", raw)
	if err != nil {
		return false, err
	}
	defer os.Remove(temp)
	if err := r.publisher.PublishNew(temp, destination); err != nil {
		return false, err
	}
	return true, nil
}

func (r *lockedWindowsRunFS) RemoveSnapshot(name string) error {
	if r.migrationHandle == windows.InvalidHandle || filepath.Base(name) != name {
		return errUnsafeFilesystem
	}
	err := os.Remove(filepath.Join(r.migrationDir, name))
	if errors.Is(err, fs.ErrNotExist) {
		return nil
	}
	return err
}

func (r *lockedWindowsRunFS) EnsureRevision() error {
	if r.revisionHandle != windows.InvalidHandle {
		return nil
	}
	revisionDir := filepath.Join(r.runDir, "revision")
	if err := os.Mkdir(revisionDir, 0o700); err != nil && !errors.Is(err, fs.ErrExist) {
		return err
	}
	handle, err := openWindowsDirectory(revisionDir)
	if err != nil {
		return err
	}
	r.revisionHandle = handle
	return nil
}

func (r *lockedWindowsRunFS) PublishRevision(name string, raw []byte) (bool, error) {
	if r.revisionHandle == windows.InvalidHandle || filepath.Base(name) != name {
		return false, errUnsafeFilesystem
	}
	revisionDir := filepath.Join(r.runDir, "revision")
	destination := filepath.Join(revisionDir, name)
	if current, err := readWindowsRegular(destination, int64(len(raw))); err == nil {
		if bytes.Equal(current, raw) {
			return false, nil
		}
		return false, errCollision
	} else if !errors.Is(err, fs.ErrNotExist) && !errors.Is(err, windows.ERROR_FILE_NOT_FOUND) {
		return false, err
	}
	temp, err := writeTemp(revisionDir, ".baseline-", raw)
	if err != nil {
		return false, err
	}
	defer os.Remove(temp)
	if err := r.publisher.PublishNew(temp, destination); err != nil {
		return false, err
	}
	return true, nil
}

func (r *lockedWindowsRunFS) WriteManifestTemp(raw []byte) (string, error) {
	path, err := writeTemp(r.runDir, ".manifest-v1-", raw)
	if err != nil {
		return "", err
	}
	return filepath.Base(path), nil
}

func (r *lockedWindowsRunFS) RemoveManifestTemp(name string) error {
	if filepath.Base(name) != name {
		return errUnsafeFilesystem
	}
	err := os.Remove(filepath.Join(r.runDir, name))
	if errors.Is(err, fs.ErrNotExist) {
		return nil
	}
	return err
}

func (r *lockedWindowsRunFS) ReplaceManifest(name string) error {
	if filepath.Base(name) != name {
		return errUnsafeFilesystem
	}
	return r.publisher.Replace(filepath.Join(r.runDir, name), filepath.Join(r.runDir, "manifest.json"))
}

func (r *lockedWindowsRunFS) SyncRun() error { return nil }

func openWindowsDirectory(path string) (windows.Handle, error) {
	name, err := windows.UTF16PtrFromString(path)
	if err != nil {
		return 0, err
	}
	handle, err := windows.CreateFile(
		name,
		windows.GENERIC_READ,
		windows.FILE_SHARE_READ|windows.FILE_SHARE_WRITE,
		nil,
		windows.OPEN_EXISTING,
		windows.FILE_FLAG_BACKUP_SEMANTICS|windows.FILE_FLAG_OPEN_REPARSE_POINT,
		0,
	)
	if err != nil {
		return 0, err
	}
	var info windows.ByHandleFileInformation
	if err := windows.GetFileInformationByHandle(handle, &info); err != nil ||
		info.FileAttributes&windows.FILE_ATTRIBUTE_DIRECTORY == 0 ||
		info.FileAttributes&windows.FILE_ATTRIBUTE_REPARSE_POINT != 0 {
		windows.CloseHandle(handle)
		if err != nil {
			return 0, err
		}
		return 0, errUnsafeFilesystem
	}
	return handle, nil
}

func readWindowsRegular(path string, max int64) ([]byte, error) {
	name, err := windows.UTF16PtrFromString(path)
	if err != nil {
		return nil, err
	}
	handle, err := windows.CreateFile(
		name,
		windows.GENERIC_READ,
		windows.FILE_SHARE_READ|windows.FILE_SHARE_WRITE,
		nil,
		windows.OPEN_EXISTING,
		windows.FILE_ATTRIBUTE_NORMAL|windows.FILE_FLAG_OPEN_REPARSE_POINT,
		0,
	)
	if err != nil {
		return nil, err
	}
	file := os.NewFile(uintptr(handle), path)
	defer file.Close()
	var handleInfo windows.ByHandleFileInformation
	if err := windows.GetFileInformationByHandle(handle, &handleInfo); err != nil ||
		handleInfo.FileAttributes&(windows.FILE_ATTRIBUTE_DIRECTORY|windows.FILE_ATTRIBUTE_REPARSE_POINT) != 0 {
		return nil, errUnsafeFilesystem
	}
	info, err := file.Stat()
	if err != nil || !info.Mode().IsRegular() || info.Size() > max {
		return nil, errUnsafeFilesystem
	}
	return readLimited(file, max)
}

func sameWindowsFile(left, right windows.Handle) (bool, error) {
	var a, b windows.ByHandleFileInformation
	if err := windows.GetFileInformationByHandle(left, &a); err != nil {
		return false, err
	}
	if err := windows.GetFileInformationByHandle(right, &b); err != nil {
		return false, err
	}
	return a.VolumeSerialNumber == b.VolumeSerialNumber &&
		a.FileIndexHigh == b.FileIndexHigh && a.FileIndexLow == b.FileIndexLow, nil
}

func writeTemp(dir, pattern string, raw []byte) (string, error) {
	file, err := os.CreateTemp(dir, pattern)
	if err != nil {
		return "", err
	}
	name := file.Name()
	ok := false
	defer func() {
		file.Close()
		if !ok {
			os.Remove(name)
		}
	}()
	if err := file.Chmod(0o600); err != nil || writeAll(file, raw) != nil ||
		file.Sync() != nil || file.Close() != nil {
		return "", errors.New("temporary publication failed")
	}
	ok = true
	return name, nil
}
