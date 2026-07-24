//go:build windows

package gitobserve

import (
	"errors"
	"io"
	"os"
	"path/filepath"
	"strings"
	"unsafe"

	"github.com/rohitsharma9646/feature-flow/integrity/digest"
	"github.com/rohitsharma9646/feature-flow/integrity/revision"
	"golang.org/x/sys/windows"
)

func observeWorktree(root, name string, max int64) (revision.EntryKind, string, *string, *string, int64, error) {
	parts := strings.Split(filepath.FromSlash(name), string(filepath.Separator))
	handles := make([]windows.Handle, 0, len(parts)+1)
	rootHandle, err := openDirectoryNoReparse(root)
	if err != nil {
		return "", "", nil, nil, 0, errors.New("FFI_REVISION_UNSUPPORTED")
	}
	handles = append(handles, rootHandle)
	parent := rootHandle
	for _, component := range parts[:len(parts)-1] {
		handle, err := openRelativeNoReparse(parent, component, true)
		if err != nil {
			closeHandles(handles)
			return "", "", nil, nil, 0, errors.New("FFI_REVISION_UNSUPPORTED")
		}
		handles = append(handles, handle)
		parent = handle
	}
	defer closeHandles(handles)
	handle, err := openRelativeNoReparse(parent, parts[len(parts)-1], false)
	if err != nil {
		if errors.Is(err, windows.ERROR_FILE_NOT_FOUND) || errors.Is(err, windows.ERROR_PATH_NOT_FOUND) {
			return "", "", nil, nil, 0, nil
		}
		return "", "", nil, nil, 0, errors.New("FFI_REVISION_UNSUPPORTED")
	}
	file := os.NewFile(uintptr(handle), name)
	defer file.Close()
	var handleInfo windows.ByHandleFileInformation
	info, statErr := file.Stat()
	if windows.GetFileInformationByHandle(handle, &handleInfo) != nil || statErr != nil ||
		handleInfo.FileAttributes&windows.FILE_ATTRIBUTE_REPARSE_POINT != 0 ||
		!info.Mode().IsRegular() || info.Size() > max {
		// Windows symlink target bytes are unsupported until an exact reparse
		// representation is proven.
		return "", "", nil, nil, 0, errors.New("FFI_REVISION_UNSUPPORTED")
	}
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

func readArtifact(root, name string, max int64) ([]byte, error) {
	parts := strings.Split(filepath.FromSlash(name), string(filepath.Separator))
	rootHandle, err := openDirectoryNoReparse(root)
	if err != nil {
		return nil, errors.New("FFI_REVISION_UNSUPPORTED")
	}
	handles := []windows.Handle{rootHandle}
	parent := rootHandle
	for _, component := range parts[:len(parts)-1] {
		handle, openErr := openRelativeNoReparse(parent, component, true)
		if openErr != nil {
			closeHandles(handles)
			return nil, errors.New("FFI_REVISION_UNSUPPORTED")
		}
		handles = append(handles, handle)
		parent = handle
	}
	defer closeHandles(handles)
	handle, err := openRelativeNoReparse(parent, parts[len(parts)-1], false)
	if err != nil {
		return nil, errors.New("FFI_REVISION_UNSUPPORTED")
	}
	file := os.NewFile(uintptr(handle), name)
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

func openRelativeNoReparse(parent windows.Handle, name string, directory bool) (windows.Handle, error) {
	objectName, err := windows.NewNTUnicodeString(name)
	if err != nil {
		return 0, err
	}
	attributes := &windows.OBJECT_ATTRIBUTES{
		RootDirectory: parent,
		ObjectName:    objectName,
		Attributes:    windows.OBJ_CASE_INSENSITIVE,
	}
	attributes.Length = uint32(unsafe.Sizeof(*attributes))
	var handle windows.Handle
	var status windows.IO_STATUS_BLOCK
	options := uint32(windows.FILE_NON_DIRECTORY_FILE | windows.FILE_OPEN_REPARSE_POINT)
	share := uint32(windows.FILE_SHARE_READ)
	if directory {
		options = windows.FILE_DIRECTORY_FILE | windows.FILE_OPEN_REPARSE_POINT
		share = windows.FILE_SHARE_READ | windows.FILE_SHARE_WRITE
	}
	if err := windows.NtCreateFile(
		&handle, windows.FILE_GENERIC_READ, attributes, &status, nil, 0, share,
		windows.FILE_OPEN, options, 0, 0,
	); err != nil {
		return 0, err
	}
	var info windows.ByHandleFileInformation
	if err := windows.GetFileInformationByHandle(handle, &info); err != nil ||
		info.FileAttributes&windows.FILE_ATTRIBUTE_REPARSE_POINT != 0 ||
		(directory && info.FileAttributes&windows.FILE_ATTRIBUTE_DIRECTORY == 0) ||
		(!directory && info.FileAttributes&windows.FILE_ATTRIBUTE_DIRECTORY != 0) {
		windows.CloseHandle(handle)
		return 0, errors.New("unsafe relative object")
	}
	return handle, nil
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
