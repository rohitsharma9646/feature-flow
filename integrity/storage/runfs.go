package storage

import (
	"errors"
	"io"
)

var errUnsafeFilesystem = errors.New("handle-anchored filesystem operations unavailable")

type runFS interface {
	Close() error
	ReadManifest(max int64) ([]byte, error)
	ValidateLocation() error
	EnsureMigration() error
	PublishSnapshot(name string, raw []byte) (bool, error)
	RemoveSnapshot(name string) error
	WriteManifestTemp(raw []byte) (string, error)
	RemoveManifestTemp(name string) error
	ReplaceManifest(name string) error
	SyncRun() error
}

func readLimited(file io.Reader, max int64) ([]byte, error) {
	raw, err := io.ReadAll(io.LimitReader(file, max+1))
	if err != nil || int64(len(raw)) > max {
		return nil, errors.New("bounded read failed")
	}
	return raw, nil
}
