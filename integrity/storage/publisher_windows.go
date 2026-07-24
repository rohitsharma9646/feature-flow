//go:build windows

package storage

import (
	"os"
	"syscall"
	"unsafe"
)

const (
	moveFileReplaceExisting = 0x1
	moveFileWriteThrough    = 0x8
)

var (
	kernel32    = syscall.NewLazyDLL("kernel32.dll")
	moveFileExW = kernel32.NewProc("MoveFileExW")
)

type nativePublisher struct{}

func newPublisher() publisher { return nativePublisher{} }

func (nativePublisher) Preflight(root string) error {
	info, err := os.Stat(root)
	if err != nil || !info.IsDir() {
		return os.ErrInvalid
	}
	if err := kernel32.Load(); err != nil {
		return err
	}
	return nil
}

func (nativePublisher) PublishNew(temp, destination string) error {
	return moveFile(temp, destination, moveFileWriteThrough)
}

func (nativePublisher) Replace(temp, destination string) error {
	return moveFile(temp, destination, moveFileReplaceExisting|moveFileWriteThrough)
}

func (nativePublisher) SyncDir(string) error { return nil }

func moveFile(from, to string, flags uintptr) error {
	source, err := syscall.UTF16PtrFromString(from)
	if err != nil {
		return err
	}
	destination, err := syscall.UTF16PtrFromString(to)
	if err != nil {
		return err
	}
	ok, _, callErr := moveFileExW.Call(uintptr(unsafe.Pointer(source)), uintptr(unsafe.Pointer(destination)), flags)
	if ok == 0 {
		if callErr != syscall.Errno(0) {
			return callErr
		}
		return syscall.EINVAL
	}
	return nil
}
