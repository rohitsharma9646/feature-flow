package storage

import (
	"github.com/rohitsharma9646/feature-flow/integrity/observe"
	"github.com/rohitsharma9646/feature-flow/integrity/pathpolicy"
)

func observePointers(raw []byte, roots observe.TrustedRoots) (map[string]pathpolicy.Fact, error) {
	return observe.Pointers(raw, roots)
}
