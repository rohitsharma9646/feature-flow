#!/usr/bin/env bash
# Regression guard: durable artifact promotion must be structurally wired (paths.durable).
# Pins the STRUCTURAL acceptance criteria of the artifact-org feature
# (.feature-flow/artifact-org): the config key, the canonical resolution rule, the
# authority wording, pointer-aware reads, and Codex dist parity. Behavioral ACs
# (docs actually land in <durable>/<date>-<slug>/, dir auto-created, no git commit)
# are NOT grep-checkable — they are Task 9 live-smoke, manual-unverified until a
# fresh session reloads the plugin. This guard deliberately does not assert them.
set -u
cd "$(dirname "$0")/../.." || exit 2
fail=0
err() { echo "FAIL: $1"; fail=1; }
ok()  { echo "ok:   $1"; }

first_line() { grep -inE "$1" "$2" 2>/dev/null | head -1 | cut -d: -f1; }

. scripts/checks/lib/schema.sh
schema_join  # SCHEMA = the joined contract (temp file); SCHEMA_LABEL names it in messages

# --- (a) config key (AC4): paths.durable present AND defaults to null --------
grep -qE '"durable"[[:space:]]*:[[:space:]]*null' config/defaults.json \
  && ok "config/defaults.json: paths.durable present, default null" \
  || err "config/defaults.json: paths object must contain \"durable\": null"

# --- (b) canonical Durable artifact resolution rule (AC2, AC3, AC5) ----------
grep -q 'Durable artifact resolution' "$SCHEMA" \
  && ok "$SCHEMA_LABEL: 'Durable artifact resolution' rule present" \
  || err "$SCHEMA_LABEL: must define a 'Durable artifact resolution' rule"
# precedence: legacy paths.spec/plan -> paths.durable -> sandbox
grep -q 'paths.durable' "$SCHEMA" \
  && ok "$SCHEMA_LABEL: rule names paths.durable" \
  || err "$SCHEMA_LABEL: resolution rule must name paths.durable"
# the <date>-<slug>/<artifact> directory scheme
grep -qE '\-<(slug|S)>/' "$SCHEMA" \
  && ok "$SCHEMA_LABEL: rule states the <date>-<slug>/<artifact> scheme" \
  || err "$SCHEMA_LABEL: resolution rule must state the <date>-<slug>/<artifact>.md scheme"

# --- (c) authority wording graft (AC8 foot-gun removal) ----------------------
grep -q 'display mirror' "$SCHEMA" \
  && ok "$SCHEMA_LABEL: phases.<phase>.artifact described as a display mirror" \
  || err "$SCHEMA_LABEL: phases.<phase>.artifact must be called a display mirror (not authoritative)"
# the stale 'only spec and plan are relocatable' claim must be GONE.
# (The full sentence wraps across two lines; match the on-line fragment.)
if grep -qiE 'spec. and .plan. are relocatable' "$SCHEMA"; then
  err "$SCHEMA_LABEL: stale 'spec and plan are relocatable' claim must be removed"
else
  ok "$SCHEMA_LABEL: stale 'only spec/plan relocatable' claim absent"
fi

# --- (d) Disk-inference is pointer-aware + durable-fallback (AC8) ------------
awk '/## Disk inference procedure/,/^## Re-run guard/' "$SCHEMA" | grep -q 'artifacts\.' \
  && ok "$SCHEMA_LABEL: Disk-inference references artifacts.<name>" \
  || err "$SCHEMA_LABEL: Disk-inference procedure must resolve via artifacts.<name>"
awk '/## Disk inference procedure/,/^## Re-run guard/' "$SCHEMA" | grep -q 'paths.durable' \
  && ok "$SCHEMA_LABEL: Disk-inference has the paths.durable manifest-lost fallback" \
  || err "$SCHEMA_LABEL: Disk-inference must describe the paths.durable manifest-lost fallback"

# --- (e) the rule lives in the artifacts note (AC1, AC2) ---------------------
awk '/maps logical names/,/## Run resolution/' "$SCHEMA" | grep -q 'Durable artifact resolution' \
  && ok "$SCHEMA_LABEL: artifacts note carries the resolution rule" \
  || err "$SCHEMA_LABEL: the artifacts note must carry the Durable artifact resolution rule"

# --- (f) writing commands reference the rule + record artifacts.<name> -------
check_writer() { # file artifact_field
  local f="$1" field="$2"
  grep -q 'Durable artifact resolution' "$f" \
    && ok "$f: references the Durable artifact resolution rule" \
    || err "$f: must reference the 'Durable artifact resolution' rule by name"
  grep -q "artifacts.$field" "$f" \
    && ok "$f: records the resolved path in artifacts.$field" \
    || err "$f: must record the resolved path in artifacts.$field"
}
check_writer commands/ff-clarify.md  spec
check_writer commands/ff-plan.md     plan
check_writer commands/ff-design.md   design
check_writer commands/ff-design.md   decision
check_writer commands/ff-diagnose.md diagnosis
check_writer commands/ff-verify.md   verify
check_writer commands/ff-deliver.md  delivery
check_writer commands/ff-retro.md    retro

# --- (g) ff-implement reads via artifacts.plan, manifest-first ORDER (AC6) ---
grep -q 'artifacts.plan' commands/ff-implement.md \
  && ok "commands/ff-implement.md: resolves the plan via artifacts.plan" \
  || err "commands/ff-implement.md: cold-start must resolve the plan via artifacts.plan"
# positive ordering, scoped to the Cold-start section (where the plan-resolution order
# is asserted) — so a legitimate "sandbox fallback" mention elsewhere (e.g. the bugfix
# gate/work read) cannot flip a global first-line proxy. The manifest-pointer read must
# precede the sandbox fallback WITHIN Cold-start.
coldblk=$(awk '/^## Cold-start/{c=1;next} c&&/^## /{c=0} c' commands/ff-implement.md)
ip=$(printf '%s\n' "$coldblk" | grep -nE 'artifacts\.plan'  | head -1 | cut -d: -f1)
is=$(printf '%s\n' "$coldblk" | grep -n  'sandbox fallback' | head -1 | cut -d: -f1)
if [ -n "$ip" ] && [ -n "$is" ] && [ "$ip" -lt "$is" ]; then
  ok "commands/ff-implement.md: Cold-start reads artifacts.plan (rel@$ip) before the sandbox fallback (rel@$is)"
else
  err "commands/ff-implement.md: Cold-start must resolve artifacts.plan (rel line ${ip:-MISSING}) before the sandbox fallback (rel line ${is:-MISSING})"
fi
# bugfix-track read must also resolve the diagnosis via the pointer (AC13, closes I1)
grep -q 'artifacts\.diagnosis' commands/ff-implement.md \
  && ok "commands/ff-implement.md: bugfix work resolves the diagnosis via artifacts.diagnosis" \
  || err "commands/ff-implement.md: bugfix work read must resolve the diagnosis via artifacts.diagnosis"

# --- (h) ff-status resolves existence via artifacts.<name> (AC7) ------------
grep -q 'artifacts\.' commands/ff-status.md \
  && ok "commands/ff-status.md: resolves artifact existence via artifacts.<name>" \
  || err "commands/ff-status.md: must resolve artifact existence via artifacts.<name>"

# --- (i) user-facing docs (AC documentation) --------------------------------
grep -q 'paths.durable' README.md \
  && ok "README.md: has a paths.durable config row" \
  || err "README.md: config table must have a paths.durable row"
# strengthened: the pre-existing 'durable, resumable' blurb must not satisfy this —
# require the promotion concept or the config key by name.
grep -qiE 'promot|paths.durable' skills/feature-flow/SKILL.md \
  && ok "SKILL.md: notes durable promotion" \
  || err "SKILL.md: 'manifest is the shared state' must note durable promotion (promote/paths.durable)"

# --- (j) Codex dist parity (AC10): each edited packaged file is byte-identical
# NOTE: scripts/ is excluded from the package (package-codex-plugin.sh line 130),
# so this guard script is never in dist/ — only the packaged source files below.
DIST="dist/codex/feature-flow"
for rel in \
  config/defaults.json \
  docs/manifest-schema.md docs/schema/*.md \
  commands/ff.md \
  commands/ff-clarify.md \
  commands/ff-plan.md \
  commands/ff-design.md \
  commands/ff-diagnose.md \
  commands/ff-implement.md \
  commands/ff-verify.md \
  commands/ff-status.md \
  commands/ff-resume.md \
  README.md \
  skills/feature-flow/SKILL.md
do
  if diff -q "$rel" "$DIST/$rel" >/dev/null 2>&1; then
    ok "dist parity: $rel"
  else
    err "dist parity: $rel differs from $DIST/$rel (re-run scripts/package-codex-plugin.sh)"
  fi
done

# --- (k) read-site completeness (AC13, AC14): NO bare-name durable reader ----
# For each command body (from the first '## ' heading onward — skips frontmatter,
# the intro blurb, and the precedence blockquote), any `(spec|design|plan|diagnosis).md`
# is a bare-name reader/gate UNLESS it is one of the principled legitimate-use classes
# subtracted below. Any survivor fails the guard (printing file:line), so a future edit
# cannot silently reintroduce a bare-name reader. This converts the C1-C4 bug class into
# a standing check (the four sites passed the original GREEN precisely because no scan
# asserted read-site completeness). Exclude classes, each a *kind* of legitimate use:
#   - artifacts.<name>          already pointer-aware (manifest.artifacts.<name>)
#   - write|writes|writing|...  write/record targets + re-run-guard "overwriting <x>.md"
#   - templates/                template references (templates/<x>.md)
#   - User signed off           I3 sign-off mirror reads — DEFERRED (spec Non-goals);
#                               *** REMOVE this exclude when I3 is implemented ***
#   - never gate on a bare|...  prohibition doctrine (prose that names the anti-pattern)
# Match a durable artifact name as a doc token: the leading `(^|[^-[:alnum:]])` rejects
# only names glued to a `ff-` style prefix — command-file refs (`commands/ff-plan.md`,
# `ff-design.md`) are NOT durable-artifact reads. `/` is deliberately NOT excluded here:
# a sandbox-PATH-form reader (`.feature-flow/<slug>/spec.md`) MUST still be caught, so the
# invariant stays total. Legitimate `/`-preceded forms (write targets `<dir>/spec.md;
# create…`, `templates/…`) are removed by the write/create + templates excludes below, not
# by the pattern — FP-over-FN per design §B2. awk emits `FNR: <line>` (no filename, so the
# `ff-design.md`/`ff-plan.md` filenames can't self-match); the file is reported separately.
DURABLE='(^|[^-[:alnum:]])(spec|design|decision|plan|diagnosis|delivery|retro)\.md'
kviol=0
for f in commands/*.md; do
  while IFS= read -r h; do
    [ -z "$h" ] && continue
    err "read-site completeness: bare durable-artifact reader/gate — $f:$h"
    kviol=1
  done < <(awk '/^## /{b=1} b{print FNR": "$0}' "$f" \
    | grep -E "$DURABLE" \
    | grep -viE 'artifacts\.(spec|design|decision|plan|diagnosis)' \
    | grep -viE 'write|writes|writing|record|overwriting|create' \
    | grep -viE 'templates/' \
    | grep -viE 'User signed off' \
    | grep -viE 'never gate on a bare|outside the sandbox|false-fire')
done
[ "$kviol" -eq 0 ] && ok "read-site completeness (AC13): no bare-name durable-artifact reader/gate in any command body"

if [ "$fail" -eq 0 ]; then echo "PASS: durable-paths guard"; else echo "RED: durable-paths guard failed"; fi
exit "$fail"
