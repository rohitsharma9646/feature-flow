#!/usr/bin/env bash
set -u

cd /work || exit 2
go build -buildvcs=false -o /tmp/ff-integrity ./cmd/ff-integrity || exit 2
fixture="$(mktemp -d)"
mkdir -p "$fixture/legacy"
cp integrity/testdata/manifests/legacy.json "$fixture/legacy/manifest.json"

record=/evidence/cli-output-1-doctor-preview-apply-idempotence.txt
: > "$record"
printf 'kind: cli-output, before/after\n' >> "$record"
printf 'fixture: disposable container path %s\n' "$fixture" >> "$record"
printf '\n=== BEFORE ===\n' >> "$record"
find "$fixture" -type f -printf '%P\n' | sort >> "$record"
sha256sum "$fixture/legacy/manifest.json" >> "$record"
cp "$fixture/legacy/manifest.json" /evidence/before-1-legacy-manifest.json

printf '\n=== DOCTOR BEFORE ===\n' >> "$record"
printf 'command: /tmp/ff-integrity doctor --root <fixture> --format json legacy\n' >> "$record"
/tmp/ff-integrity doctor --root "$fixture" --format json legacy \
  > /evidence/cli-1-doctor-before.json 2>> "$record"
status=$?
printf 'exit_status: %s\n' "$status" >> "$record"
cat /evidence/cli-1-doctor-before.json >> "$record"

printf '\n=== PREVIEW ===\n' >> "$record"
printf 'command: /tmp/ff-integrity migrate --root <fixture> --to 1 --dry-run --format json legacy\n' >> "$record"
/tmp/ff-integrity migrate --root "$fixture" --to 1 --dry-run --format json legacy \
  > /evidence/cli-2-preview.json 2>> "$record"
status=$?
printf 'exit_status: %s\n' "$status" >> "$record"
cat /evidence/cli-2-preview.json >> "$record"
plan="$(jq -r '.planDigest' /evidence/cli-2-preview.json)"

printf '\n=== APPLY ===\n' >> "$record"
printf 'command: /tmp/ff-integrity migrate --root <fixture> --to 1 --apply --expect-plan %s --format json legacy\n' "$plan" >> "$record"
/tmp/ff-integrity migrate --root "$fixture" --to 1 --apply --expect-plan "$plan" --format json legacy \
  > /evidence/cli-3-apply.json 2>> "$record"
status=$?
printf 'exit_status: %s\n' "$status" >> "$record"
cat /evidence/cli-3-apply.json >> "$record"

printf '\n=== AFTER APPLY ===\n' >> "$record"
find "$fixture" -type f -printf '%P\n' | sort >> "$record"
find "$fixture" -type f -exec sha256sum {} \; | sort >> "$record"
cp "$fixture/legacy/manifest.json" /evidence/after-1-canonical-manifest.json
cp "$fixture"/legacy/migration/*.json /evidence/after-2-source-snapshot.json

printf '\n=== DOCTOR AFTER ===\n' >> "$record"
printf 'command: /tmp/ff-integrity doctor --root <fixture> --format json legacy\n' >> "$record"
/tmp/ff-integrity doctor --root "$fixture" --format json legacy \
  > /evidence/cli-4-doctor-after.json 2>> "$record"
status=$?
printf 'exit_status: %s\n' "$status" >> "$record"
cat /evidence/cli-4-doctor-after.json >> "$record"

printf '\n=== IDEMPOTENT SECOND APPLY ===\n' >> "$record"
printf 'command: /tmp/ff-integrity migrate --root <fixture> --to 1 --apply --expect-plan %s --format json legacy\n' "$plan" >> "$record"
/tmp/ff-integrity migrate --root "$fixture" --to 1 --apply --expect-plan "$plan" --format json legacy \
  > /evidence/cli-5-apply-again.json 2>> "$record"
status=$?
printf 'exit_status: %s\n' "$status" >> "$record"
cat /evidence/cli-5-apply-again.json >> "$record"

printf '\n=== AFTER SECOND APPLY ===\n' >> "$record"
find "$fixture" -type f -printf '%P\n' | sort >> "$record"
find "$fixture" -type f -exec sha256sum {} \; | sort >> "$record"
