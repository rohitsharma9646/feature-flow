package schemas

import _ "embed"

// ManifestV1 is the canonical executable schema.
//
//go:embed manifest-v1.schema.json
var ManifestV1 []byte

// GoldenVectorV1 is the canonical vector-index schema.
//
//go:embed golden-vector-v1.schema.json
var GoldenVectorV1 []byte

// DoctorResultV1 is the machine-readable doctor response schema.
//
//go:embed doctor-result-v1.schema.json
var DoctorResultV1 []byte

// MigrationPlanV1 is the deterministic migration preview schema.
//
//go:embed migration-plan-v1.schema.json
var MigrationPlanV1 []byte

// CodeRevisionV1 is the direct revision-result schema.
//
//go:embed code-revision-v1.schema.json
var CodeRevisionV1 []byte

// AttestationV1 is the typed assurance record schema.
//
//go:embed attestation-v1.schema.json
var AttestationV1 []byte

// WP3CorpusV1 is the executable revision/assurance corpus index schema.
//
//go:embed wp3-corpus-v1.schema.json
var WP3CorpusV1 []byte
