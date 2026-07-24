package storage

type publisher interface {
	Preflight(root string) error
	PublishNew(temp, destination string) error
	Replace(temp, destination string) error
	SyncDir(path string) error
}
