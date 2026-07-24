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
