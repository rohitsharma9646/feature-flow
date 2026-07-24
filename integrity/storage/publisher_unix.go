//go:build !windows

package storage

import (
	"os"
)

type nativePublisher struct{}

func newPublisher() publisher { return nativePublisher{} }

func (nativePublisher) Preflight(root string) error {
	info, err := os.Stat(root)
	if err != nil || !info.IsDir() {
		return os.ErrInvalid
	}
	return nil
}

func (nativePublisher) PublishNew(temp, destination string) error {
	if err := os.Link(temp, destination); err != nil {
		return err
	}
	return os.Remove(temp)
}

func (nativePublisher) Replace(temp, destination string) error {
	return os.Rename(temp, destination)
}

func (nativePublisher) SyncDir(path string) error {
	dir, err := os.Open(path)
	if err != nil {
		return err
	}
	defer dir.Close()
	return dir.Sync()
}
