#!/usr/bin/env bash
# Regression guard: revision binding (v0.22.0, .feature-flow/revision-binding) must stay wired.
# Review and verify stamp a working-tree fingerprint; the done-transition (prose, both platforms)
# and Gate B (hooks/enforce-gate, Claude Code) require both stamps to equal the current revision.
#   AC12  every manifest-creating entry point writes revisionBound: true.
#   AC13  the rule is stated in the contract (field notes, Gate B, Revision agreement, the
#         Stale-phase re-run cycle) and in ff-review / ff-verify; the WP4 constraint is stated in
#         enforcement.md and the newest CHANGELOG entry.
#   FS2   the canonical recipe in enforcement.md §Revision fingerprint is hooks/lib/revision.sh
#         byte-for-byte (a paraphrase would yield a different id and deny every done) — plus a
#         negative self-test that a one-character drift is caught.
#   dflt  the lib's built-in exclusion defaults equal config/defaults.json's paths.*.
# Behaviour (the fingerprint itself, Gate B allow/deny/warn) is proven by enforce-gate-guard.sh
# against real git repositories — not re-implemented here. The Stale-phase re-run cycle actually
# firing once and then stopping is semantic (a fresh-session self-run), not grep-checkable.
set -u
cd "$(dirname "$0")/../.." || exit 2
fail=0
err() { echo "FAIL: $1"; fail=1; }
ok()  { echo "ok:   $1"; }
flat() { tr '\n' ' ' | tr -s '[:space:]' ' '; }  # prose may reflow across lines
has()  { flat < "$1" | grep -qF -- "$2"; }

LIB="hooks/lib/revision.sh"
ENF="docs/schema/enforcement.md"
TC="docs/schema/terminal-convergence.md"
AP="docs/schema/autopilot.md"
CORE="docs/manifest-schema.md"

# --- AC12: creation writes revisionBound ------------------------------------------------------
for f in commands/ff.md commands/ff-explore.md commands/ff-clarify.md commands/ff-diagnose.md; do
  grep -q 'revisionBound: true' "$f" && ok "AC12: $f writes revisionBound: true at creation" \
    || err "AC12: $f must write revisionBound: true when it creates a manifest"
done

# --- AC13: contract text -------------------------------------------------------------------------
grep -q '"revisionBound": true' "$CORE" && has "$CORE" '**`revisionBound`** (boolean, added v0.22.0)' \
  && ok "AC13: $CORE Schema + field note for revisionBound" || err "AC13: $CORE lacks the revisionBound schema line / field note"
grep -q '"revision": "<git tree id or null>"' "$CORE" && has "$CORE" '**`phases.review.revision`** / **`phases.verify.revision`**' \
  && ok "AC13: $CORE Schema + field note for phases.<review|verify>.revision" || err "AC13: $CORE lacks the per-phase revision schema / field note"
has "$CORE" 'Absent field = not revision-bound' \
  && ok "AC13: $CORE states the absent-field back-compat rule" || err "AC13: $CORE must say an absent revisionBound = not revision-bound"
has "$ENF" 'On a revision-bound run' && has "$ENF" 'revision not recorded' && has "$ENF" 'revision is stale' \
  && ok "AC13: $ENF Gate B states the revision condition and both reasons" || err "AC13: $ENF Gate B revision condition incomplete"
has "$ENF" 'skipped silently' && has "$ENF" 'allows loudly' \
  && ok "AC13: $ENF separates the silent skip from the loud allow" || err "AC13: $ENF must state the silent-skip vs loud-allow split"
grep -q '^### Revision fingerprint' "$ENF" \
  && ok "AC13: $ENF defines ### Revision fingerprint" || err "AC13: $ENF must define '### Revision fingerprint'"
has "$ENF" '**WP4 constraint.**' && has "$ENF" 'must never regress enforcement to observe-only' \
  && ok "AC13: $ENF states the WP4 preservation constraint" || err "AC13: $ENF must state the WP4 constraint"
grep -q '^\*\*Revision agreement (' "$TC" && has "$TC" 'Stale-phase re-run cycle' \
  && ok "AC13: $TC defines Revision agreement and routes to the stale-phase cycle" || err "AC13: $TC Revision agreement missing"
grep -q '^\*\*Stale-phase re-run cycle (' "$AP" && has "$AP" '## Stale re-run' && has "$AP" 'never a second cycle' \
  && ok "AC13: $AP defines the Stale-phase re-run cycle with its durable one-cycle cap" || err "AC13: $AP stale-phase cycle incomplete"
row="$(grep -F '| Stale-phase stop' "$AP")"
if [ -n "$row" ] && ! printf '%s' "$row" | grep -qi 'unconditional'; then
  ok "AC13: $AP mandatory-pauses row is capped-then-stop (not 'unconditional')"
else err "AC13: $AP needs a 'Stale-phase stop' mandatory-pauses row that is not 'unconditional'"; fi
for f in commands/ff-review.md commands/ff-verify.md; do
  grep -q '^## Stamp the revision (revision-bound runs)' "$f" && has "$f" '**Revision agreement** in' \
    && has "$f" 'Never re-type or paraphrase it' \
    && ok "AC13: $f stamps the revision (verbatim recipe) and checks Revision agreement" \
    || err "AC13: $f must have '## Stamp the revision' (verbatim-recipe rule) and the Revision agreement check"
done
# the stamp section precedes the manifest update it feeds
for f in commands/ff-review.md commands/ff-verify.md; do
  s="$(grep -n '^## Stamp the revision' "$f" | head -1 | cut -d: -f1)"
  u="$(grep -n '^## Update manifest + hand off' "$f" | head -1 | cut -d: -f1)"
  [ -n "$s" ] && [ -n "$u" ] && [ "$s" -lt "$u" ] && ok "AC13: $f stamps before its manifest update" \
    || err "AC13: $f '## Stamp the revision' must precede '## Update manifest + hand off'"
done
for f in templates/review.md templates/verify.md; do
  line="$(grep -F '**Revision:**' "$f")"
  [ -n "$line" ] && ! printf '%s' "$line" | grep -q '[0-9]' && grep -q '^## Stale re-run' "$f" \
    && ok "AC13: $f has a digit-free **Revision:** line and a ## Stale re-run skeleton" \
    || err "AC13: $f needs a digit-free **Revision:** line and a ## Stale re-run section"
done
newest="$(awk '/^## \[/{n++} n==1' CHANGELOG.md)"
printf '%s' "$newest" | flat | grep -q 'WP4' && printf '%s' "$newest" | grep -q 'revision' \
  && ok "AC13: newest CHANGELOG entry states the WP4 constraint" || err "AC13: newest CHANGELOG entry must state the WP4 constraint"

# --- FS2: canonical recipe == hooks/lib/revision.sh, byte for byte -------------------------------
extract() { awk '/^### Revision fingerprint/{s=1} s && /^```bash$/{c=1; next} c && /^```$/{exit} c' "$1"; }
TMPD="$(mktemp -d)"; trap 'rm -rf "$TMPD"' EXIT
extract "$ENF" > "$TMPD/block.sh"
if [ -s "$TMPD/block.sh" ] && cmp -s "$TMPD/block.sh" "$LIB"; then
  ok "FS2: $ENF §Revision fingerprint block is $LIB byte-for-byte"
else err "FS2: $ENF §Revision fingerprint block differs from $LIB — edit both together"; fi
sed 's/--literal-pathspecs/--literal-pathspec/' "$ENF" > "$TMPD/drift.md"      # one-character drift
extract "$TMPD/drift.md" > "$TMPD/drift.sh"
cmp -s "$TMPD/drift.sh" "$LIB" && err "FS2 self-test: a one-character drift must be caught" \
  || ok "FS2 self-test: a one-character drift is caught"

# --- dflt: built-in defaults == config/defaults.json (behavioural, in a repo with no project config)
if command -v git >/dev/null 2>&1 && command -v jq >/dev/null 2>&1; then
  R="$TMPD/repo"; mkdir -p "$R"; git -C "$R" init -q
  got="$( . "$LIB"; revision_excludes "$R" )"
  want="$(jq -r '.paths | [.base, .durable, .kb][] | select(. != null)' config/defaults.json)"
  [ "$got" = "$want" ] && ok "dflt: lib defaults ($(printf '%s' "$got" | tr '\n' ' ')) = config/defaults.json paths" \
    || err "dflt: lib defaults '$got' != config/defaults.json '$want'"
else err "dflt: needs git and jq"; fi

if [ "$fail" -eq 0 ]; then echo "PASS: revision-binding guard"; else echo "RED: revision-binding guard failed"; fi
exit "$fail"
