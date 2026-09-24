#!/usr/bin/env bash
# Regression guard: the Knowledge base feature must be structurally wired.
# Pins the STRUCTURAL acceptance criteria of the KB feature
# (.feature-flow/knowledge-base) as amended by the kb-on-by-default run (v0.8.0):
# the config keys default-ON (v0.8.0 AC1 — supersedes the original AC10 default-off),
# the canonical '## Knowledge base' contract section + entry-template provenance (AC3),
# the capture wiring in the terminal commands (AC1, AC2), the recall wiring in
# explore/design/diagnose (AC5, AC6; diagnose added by v0.8.0 AC2/AC3), the staleness
# terminology (AC8, AC9), honest deferral (AC13), and Codex dist parity (AC11). Section-scoped `awk` (the durable-paths section-(k) lesson):
# each command-file check is scoped to its '## KB capture' / '## KB recall' section
# and requires contract/template terminology, so a coarse rename can't pass it.
#
# Behavioral ACs are NOT grep-checkable and this guard deliberately does not assert
# them: capture actually writes an entry with provenance (AC1 live), the reject path
# writes nothing (AC4), recall surfaces a tagged entry (AC5/AC6 live), empty-KB raises
# no error (AC7), a stale entry is flagged-not-dropped (AC8/AC9 live). Those are the
# Task 8 live-smoke in a fresh KB-enabled session (plugins load at process start),
# manual-unverified until then — exactly like durable-paths-guard's behavioral ACs.
set -u
cd "$(dirname "$0")/../.." || exit 2
fail=0
err() { echo "FAIL: $1"; fail=1; }
ok()  { echo "ok:   $1"; }

. scripts/checks/lib/schema.sh
schema_join  # SCHEMA = the joined contract (temp file); SCHEMA_LABEL names it in messages
CFG="config/defaults.json"
TPL="templates/kb-entry.md"

# section <file> <start-heading-ERE> : print the body of the first '## ' section whose
# heading matches the regex, up to (excluding) the next '## ' heading. Scopes a grep to
# exactly that section. '### ' sub-headings stay inside (only '## ' ends a section).
section() { awk -v re="$2" '$0 ~ "^## " && seen {exit} $0 ~ re {seen=1} seen' "$1"; }

# --- (a) config keys, default-ON (v0.8.0 AC1; supersedes AC10 default-off) ---
grep -qE '"kb"[[:space:]]*:[[:space:]]*true' "$CFG" \
  && ok "$CFG: toggles.kb present, default true" \
  || err "$CFG: toggles object must contain \"kb\": true"
grep -qE '"kb"[[:space:]]*:[[:space:]]*"\.feature-flow-kb"' "$CFG" \
  && ok "$CFG: paths.kb present, default \".feature-flow-kb\"" \
  || err "$CFG: paths object must contain \"kb\": \".feature-flow-kb\""
grep -q 'freshnessWindowDays' "$CFG" && grep -q 'maxRecallEntries' "$CFG" \
  && ok "$CFG: kb.freshnessWindowDays + kb.maxRecallEntries present" \
  || err "$CFG: must define kb.freshnessWindowDays and kb.maxRecallEntries"

# --- (b) canonical contract section (AC8 staleness, AC11 degrade, AC13) ------
grep -q '^## Knowledge base' "$SCHEMA" \
  && ok "$SCHEMA_LABEL: '## Knowledge base' contract section present" \
  || err "$SCHEMA_LABEL: must define a '## Knowledge base' contract section"
kb="$(section "$SCHEMA" '^## Knowledge base')"
for term in freshnessWindowDays referencedFiles captureCommitSha maxRecallEntries paths.kb; do
  printf '%s\n' "$kb" | grep -q "$term" \
    && ok "$SCHEMA_LABEL §Knowledge base: names $term" \
    || err "$SCHEMA_LABEL §Knowledge base: contract must name $term"
done
printf '%s\n' "$kb" | grep -qiE 'degrade' \
  && ok "$SCHEMA_LABEL §Knowledge base: documents the Codex degrade path (AC11)" \
  || err "$SCHEMA_LABEL §Knowledge base: must document the Codex degrade path"
printf '%s\n' "$kb" | grep -qiE 'dedup' && printf '%s\n' "$kb" | grep -qiE 'supersession' \
  && ok "$SCHEMA_LABEL §Knowledge base: states dedup + supersession non-goals (AC13)" \
  || err "$SCHEMA_LABEL §Knowledge base: must state dedup + supersession as v1 non-goals"
# the autopilot mandatory-pause table must carry the KB capture confirm-gate row
section "$SCHEMA" '^## Autopilot' | grep -qiE 'KB capture' \
  && ok "$SCHEMA_LABEL §Autopilot: has the KB capture confirm-gate row" \
  || err "$SCHEMA_LABEL §Autopilot: mandatory-pause table must have a KB capture confirm-gate row"
# terminal-convergence single-source (Q6): the done-transition rule lives in its own
# section, and the capture rule references it rather than keeping its own 'By track' copy.
grep -q '^## Terminal convergence' "$SCHEMA" \
  && ok "$SCHEMA_LABEL: '## Terminal convergence' section present (canonical done-transition rule)" \
  || err "$SCHEMA_LABEL: must define a '## Terminal convergence' section (the done-transition rule)"
printf '%s\n' "$kb" | grep -qi 'Terminal convergence' \
  && ok "$SCHEMA_LABEL §Knowledge base: capture rule references Terminal convergence (single-source)" \
  || err "$SCHEMA_LABEL §Knowledge base: capture rule must reference '## Terminal convergence', not restate the done-transition"

# --- (c) entry-template provenance (AC3) ------------------------------------
for f in title captureDate captureCommitSha runSlug tags referencedFiles; do
  grep -q "$f" "$TPL" \
    && ok "$TPL: provenance field $f" \
    || err "$TPL: entry template must carry the $f field"
done

# --- (d) capture wiring (AC1, AC2): ff-verify + ff-review -------------------
check_capture() { # file
  local f="$1" body
  body="$(section "$f" '^## KB capture')"
  if [ -z "$body" ]; then
    err "$f: missing a '## KB capture' section (capture wiring absent)"
    return
  fi
  ok "$f: has a '## KB capture' section"
  printf '%s\n' "$body" | grep -q 'toggles.kb' \
    && ok "$f §KB capture: gates on toggles.kb" \
    || err "$f §KB capture: must gate on toggles.kb (+ paths.kb)"
  printf '%s\n' "$body" | grep -q 'Knowledge base' \
    && ok "$f §KB capture: references the §Knowledge base contract" \
    || err "$f §KB capture: must reference the §Knowledge base contract by name"
  printf '%s\n' "$body" | grep -qE 'artifacts\.' \
    && ok "$f §KB capture: reads run artifacts via artifacts.<name> pointers" \
    || err "$f §KB capture: must read run artifacts via manifest.artifacts.<name>"
}
check_capture commands/ff-verify.md
check_capture commands/ff-review.md
# ff-review must carry the feature-track guard so feature runs don't double-capture
section commands/ff-review.md '^## KB capture' | grep -qiE 'feature' \
  && ok "commands/ff-review.md §KB capture: has the feature-track guard" \
  || err "commands/ff-review.md §KB capture: must skip capture on the feature track"
# capture must be INVOKED at EVERY done-transition, not merely defined as a dead section.
# Scoped to '## Update manifest' and counted (bold **KB capture** marks an invocation
# bullet): ff-verify has TWO done-transitions — feature-terminal AND the bugfix
# both-complete convergence — so it needs >=2; dropping the convergence call (the original
# bugfix review-ran-first gap) drops the count to 1 and turns this RED. ff-review has one
# done-transition (bugfix verify-already-passed), so >=1.
nvf=$(section commands/ff-verify.md '^## Update manifest' | grep -cE '\*\*KB capture\*\*')
[ "${nvf:-0}" -ge 2 ] \
  && ok "commands/ff-verify.md §Update manifest: both done-transitions invoke KB capture ($nvf)" \
  || err "commands/ff-verify.md §Update manifest: each done-transition must invoke KB capture (found ${nvf:-0}, need >=2: feature-terminal + bugfix convergence)"
nvr=$(section commands/ff-review.md '^## Update manifest' | grep -cE '\*\*KB capture\*\*')
[ "${nvr:-0}" -ge 1 ] \
  && ok "commands/ff-review.md §Update manifest: bugfix done-transition invokes KB capture ($nvr)" \
  || err "commands/ff-review.md §Update manifest: the bugfix done-transition must invoke KB capture (found ${nvr:-0})"

# --- (e) recall wiring (AC5, AC6, AC8, AC9; + ff-diagnose per v0.8.0 AC2; ----
#         + ff-implement '## Decision recall' per decision-records v0.10.0) ----
# heading param defaults to '^## KB recall' so the three pre-v0.10.0 call-sites are
# byte-identical in behavior; ff-implement's decision recall reuses the SAME assertions
# (gates on toggles.kb for source 2, references §Knowledge base, applies staleness).
check_recall() { # file [heading-regex]
  local f="$1" heading="${2:-^## KB recall}" name body
  name="${heading#^}"
  body="$(section "$f" "$heading")"
  if [ -z "$body" ]; then
    err "$f: missing a '$name' section (recall wiring absent)"
    return
  fi
  ok "$f: has a '$name' section"
  printf '%s\n' "$body" | grep -q 'toggles.kb' \
    && ok "$f §$name: gates on toggles.kb" \
    || err "$f §$name: must gate on toggles.kb (+ paths.kb)"
  printf '%s\n' "$body" | grep -q 'Knowledge base' \
    && ok "$f §$name: references the §Knowledge base contract" \
    || err "$f §$name: must reference the §Knowledge base contract by name"
  printf '%s\n' "$body" | grep -qiE 'stale' \
    && ok "$f §$name: applies the staleness flag (flag-not-suppress)" \
    || err "$f §$name: must apply the staleness flag (flag-not-suppress)"
}
check_recall commands/ff-explore.md
check_recall commands/ff-design.md
check_recall commands/ff-diagnose.md
check_recall commands/ff-implement.md '^## Decision recall'

# --- (f) honest deferral in user docs (AC13) -------------------------------
for f in skills/feature-flow/SKILL.md README.md; do
  { grep -qiE 'dedup' "$f" && grep -qiE 'supersession' "$f"; } \
    && ok "$f: documents dedup + supersession as v1 non-goals" \
    || err "$f: must document dedup + supersession as deferred v1 non-goals"
done

# --- (g) read-site safety: no bare-name durable reader in any KB section -----
# KB capture/recall sections read run artifacts; they MUST use the pointer form so
# durable-paths-guard.sh section (k) stays GREEN. Belt-and-suspenders check here.
for f in commands/ff-verify.md commands/ff-review.md commands/ff-explore.md commands/ff-design.md commands/ff-diagnose.md commands/ff-implement.md; do
  bad="$(section "$f" '^## (KB (capture|recall)|Decision recall)' \
        | grep -nE '(^|[^-[:alnum:]])(spec|design|decision|plan|diagnosis)\.md' \
        | grep -viE 'artifacts\.(spec|design|decision|plan|diagnosis)' \
        | grep -viE 'write|writes|writing|record|overwriting|create' \
        | grep -viE 'templates/' \
        | grep -viE 'never gate on a bare|outside the sandbox|false-fire' \
        || true)"
  if [ -n "$bad" ]; then
    err "$f: bare-name durable reader inside a KB section (use artifacts.<name>): $bad"
  else
    ok "$f: KB section reads are pointer-form (no bare durable reader)"
  fi
done

# --- (h) Codex dist parity (AC11): each edited packaged file byte-identical ---
# scripts/ is excluded from the package, so this guard is never in dist/ — only the
# packaged source files below (templates/, config/, commands/, skills/, docs schema,
# README all auto-mirror via REQUIRED_PATHS in package-codex-plugin.sh).
DIST="dist/codex/feature-flow"
for rel in \
  config/defaults.json \
  docs/manifest-schema.md docs/schema/*.md \
  templates/kb-entry.md \
  commands/ff-verify.md \
  commands/ff-review.md \
  commands/ff-explore.md \
  commands/ff-design.md \
  commands/ff-diagnose.md \
  commands/ff-implement.md \
  skills/feature-flow/SKILL.md \
  README.md
do
  if diff -q "$rel" "$DIST/$rel" >/dev/null 2>&1; then
    ok "dist parity: $rel"
  else
    err "dist parity: $rel differs from $DIST/$rel (re-run scripts/package-codex-plugin.sh)"
  fi
done

if [ "$fail" -eq 0 ]; then echo "PASS: kb guard"; else echo "RED: kb guard failed"; fi
exit "$fail"
