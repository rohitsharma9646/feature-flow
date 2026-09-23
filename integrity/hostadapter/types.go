// Package hostadapter translates lifecycle envelopes to and from the
// host-neutral preflight contract. It contains no workflow policy.
package hostadapter

import "github.com/rohitsharma9646/feature-flow/integrity/preflight"

const MaxEnvelopeBytes = preflight.MaxRequestBytes

type Decoded struct {
	Recognized bool
	Request    preflight.Request
}
