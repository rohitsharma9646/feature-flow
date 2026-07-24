//go:build windows

package observe

import (
	"errors"
	"io"
	"os"
	"path/filepath"

	"golang.org/x/sys/windows"
)

func readAnchored(base, slug string, max int64, afterRunOpen func()) ([]byte, error) {
	baseHandle, err := openLockedDirectory(base)
	if err != nil {
		return nil, errors.New("manifest unavailable")
	}
	defer windows.CloseHandle(baseHandle)
	runPath := filepath.Join(base, slug)
	runHandle, err := openLockedDirectory(runPath)
	if err != nil {
		return nil, errors.New("manifest unavailable")
	}
	defer windows.CloseHandle(runHandle)
	if afterRunOpen != nil {
		afterRunOpen()
	}
	manifestPath := filepath.Join(runPath, "manifest.json")
	handle, err := openRegularNoReparse(manifestPath)
	if err != nil {
		return nil, errors.New("manifest unavailable")
	}
	file := os.NewFile(uintptr(handle), manifestPath)
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

func openLockedDirectory(path string) (windows.Handle, error) {
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
		return 0, errors.New("unsafe directory")
	}
	return handle, nil
}

func openRegularNoReparse(path string) (windows.Handle, error) {
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
		windows.FILE_ATTRIBUTE_NORMAL|windows.FILE_FLAG_OPEN_REPARSE_POINT,
		0,
	)
	if err != nil {
		return 0, err
	}
	var info windows.ByHandleFileInformation
	if err := windows.GetFileInformationByHandle(handle, &info); err != nil ||
		info.FileAttributes&(windows.FILE_ATTRIBUTE_DIRECTORY|windows.FILE_ATTRIBUTE_REPARSE_POINT) != 0 {
		windows.CloseHandle(handle)
		if err != nil {
			return 0, err
		}
		return 0, errors.New("unsafe file")
	}
	return handle, nil
}
