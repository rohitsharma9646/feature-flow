// Package digest owns the integrity protocol's digest formats and domain
// separation.
package digest

import (
	"crypto/sha256"
	"encoding/hex"
	"regexp"
)

var (
	digestPattern   = regexp.MustCompile(`^sha256:[0-9a-f]{64}$`)
	revisionPattern = regexp.MustCompile(`^ffr1:[0-9a-f]{64}$`)
)

func SHA256(domain string, raw []byte) string {
	hash := sha256.New()
	hash.Write([]byte("feature-flow\x00"))
	hash.Write([]byte(domain))
	hash.Write([]byte{0})
	hash.Write(raw)
	return "sha256:" + hex.EncodeToString(hash.Sum(nil))
}

func RawSHA256(raw []byte) string {
	sum := sha256.Sum256(raw)
	return "sha256:" + hex.EncodeToString(sum[:])
}

func RevisionID(canonical []byte) string {
	sum := sha256.Sum256(canonical)
	return "ffr1:" + hex.EncodeToString(sum[:])
}

func Valid(value string) bool { return digestPattern.MatchString(value) }

func ValidRevisionID(value string) bool { return revisionPattern.MatchString(value) }
