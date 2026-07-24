//go:build windows

package gitobserve

import (
	"errors"
	"io"
	"os"
	"path/filepath"
	"strings"

	"github.com/rohitsharma9646/feature-flow/integrity/digest"
	"github.com/rohitsharma9646/feature-flow/integrity/revision"
	"golang.org/x/sys/windows"
)

func observeWorktree(root, name string, max int64) (revision.EntryKind, string, *string, *string, int64, error) {
	parts := strings.Split(filepath.FromSlash(name), string(filepath.Separator))
	handles := make([]windows.Handle, 0, len(parts))
	current := root
	for _, component := range parts[:len(parts)-1] {
		current = filepath.Join(current, component)
		handle, err := openDirectoryNoReparse(current)
		if err != nil {
			closeHandles(handles)
			return "", "", nil, nil, 0, errors.New("FFI_REVISION_UNSUPPORTED")
		}
		handles = append(handles, handle)
	}
	defer closeHandles(handles)
	full := filepath.Join(root, filepath.FromSlash(name))
	info, err := os.Lstat(full)
	if os.IsNotExist(err) {
		return "", "", nil, nil, 0, nil
	}
	if err != nil || info.Mode()&os.ModeSymlink != 0 || !info.Mode().IsRegular() || info.Size() > max {
		// Windows symlink target bytes are unsupported until an exact reparse
		// representation is proven.
		return "", "", nil, nil, 0, errors.New("FFI_REVISION_UNSUPPORTED")
	}
	path, err := windows.UTF16PtrFromString(full)
	if err != nil {
		return "", "", nil, nil, 0, errors.New("FFI_REVISION_UNSUPPORTED")
	}
	handle, err := windows.CreateFile(path, windows.GENERIC_READ, windows.FILE_SHARE_READ,
		nil, windows.OPEN_EXISTING, windows.FILE_ATTRIBUTE_NORMAL|windows.FILE_FLAG_OPEN_REPARSE_POINT, 0)
	if err != nil {
		return "", "", nil, nil, 0, errors.New("FFI_REVISION_UNSUPPORTED")
	}
	file := os.NewFile(uintptr(handle), full)
	defer file.Close()
	raw, err := io.ReadAll(io.LimitReader(file, max+1))
	if err != nil || int64(len(raw)) > max {
		return "", "", nil, nil, 0, errors.New("FFI_REVISION_UNSUPPORTED")
	}
	value := digest.RawSHA256(raw)
	mode := "100644"
	if info.Mode()&0o111 != 0 {
		mode = "100755"
	}
	return revision.KindFile, mode, &value, nil, int64(len(raw)), nil
}

func openDirectoryNoReparse(path string) (windows.Handle, error) {
	name, err := windows.UTF16PtrFromString(path)
	if err != nil {
		return 0, err
	}
	handle, err := windows.CreateFile(name, windows.GENERIC_READ,
		windows.FILE_SHARE_READ|windows.FILE_SHARE_WRITE, nil, windows.OPEN_EXISTING,
		windows.FILE_FLAG_BACKUP_SEMANTICS|windows.FILE_FLAG_OPEN_REPARSE_POINT, 0)
	if err != nil {
		return 0, err
	}
	var info windows.ByHandleFileInformation
	if err := windows.GetFileInformationByHandle(handle, &info); err != nil ||
		info.FileAttributes&windows.FILE_ATTRIBUTE_DIRECTORY == 0 ||
		info.FileAttributes&windows.FILE_ATTRIBUTE_REPARSE_POINT != 0 {
		windows.CloseHandle(handle)
		return 0, errors.New("unsafe directory")
	}
	return handle, nil
}

func closeHandles(handles []windows.Handle) {
	for _, handle := range handles {
		windows.CloseHandle(handle)
	}
}
