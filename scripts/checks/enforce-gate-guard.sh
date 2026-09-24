#!/usr/bin/env bash
# Behavioral guard for the M1 enforcement hook (hooks/enforce-gate).
# Feeds crafted PreToolUse JSON to the hook and asserts allow / deny / warn.
# Unlike the structural grep guards, this exercises real decision logic.
set -u
cd "$(dirname "$0")/../.." || exit 2
HOOK="hooks/enforce-gate"
fail=0
err() { echo "FAIL: $1"; fail=1; }
ok()  { echo "ok:   $1"; }

TMP="$(mktemp -d)"; trap 'rm -rf "$TMP"' EXIT

# payload <file_path> <content-string> <cwd> : build a PreToolUse Write payload.
# `content` is a STRING (Write passes file content as a string), matching reality.
payload() { jq -cn --arg fp "$1" --arg c "$2" --arg cwd "$3" \
  '{tool_name:"Write", tool_input:{file_path:$fp, content:$c}, cwd:$cwd}'; }

mkrun() { local d="$TMP/.feature-flow/$1"; mkdir -p "$d"; printf '%s' "$d"; }

assert_deny()  { printf '%s' "$2" | grep -q '"permissionDecision":"deny"' \
  && printf '%s' "$2" | grep -q 'Gate [AB]' \
  && ok "$1" || err "$1 — expected DENY naming a gate, got: ${2:-<empty>}"; }   # AC7: reason names the gate
assert_allow() { [ -z "$2" ] \
  && ok "$1" || err "$1 — expected ALLOW (no output), got: $2"; }
assert_warn()  { printf '%s' "$2" | grep -q '"systemMessage"' \
  && ok "$1" || err "$1 — expected systemMessage warn, got: ${2:-<empty>}"; }

run() { payload "$1" "$2" "${3:-$TMP}" | bash "$HOOK"; }  # echoes hook stdout

# ---- Gate A: enter implement -------------------------------------------------
rd="$(mkrun a-feat)"
m='{"track":"feature","tier":"full","currentPhase":"implement","phases":{"implement":{"status":"in_progress"}},"signOff":{"signed":false},"artifacts":{}}'
assert_deny  "GateA: feature unsigned → implement" "$(run "$rd/manifest.json" "$m")"
m='{"track":"feature","tier":"full","currentPhase":"implement","phases":{"implement":{"status":"in_progress"}},"signOff":{"signed":true},"artifacts":{}}'
assert_allow "GateA: feature signed → implement"   "$(run "$rd/manifest.json" "$m")"
m='{"track":"bugfix","tier":"lite","currentPhase":"implement","phases":{"diagnose":{"status":"in_progress"},"implement":{"status":"in_progress"}},"signOff":{"signed":false}}'
assert_deny  "GateA: bugfix-lite diagnose incomplete → implement" "$(run "$rd/manifest.json" "$m")"
m='{"track":"bugfix","tier":"lite","currentPhase":"implement","phases":{"diagnose":{"status":"complete"},"implement":{"status":"in_progress"}},"signOff":{"signed":false}}'
assert_allow "GateA: bugfix-lite diagnose complete → implement (no sign-off needed)" "$(run "$rd/manifest.json" "$m")"
m='{"track":"bugfix","tier":"full","currentPhase":"implement","phases":{"implement":{"status":"in_progress"}},"signOff":{"signed":false}}'
assert_deny  "GateA: bugfix-full unsigned → implement" "$(run "$rd/manifest.json" "$m")"
# feature/lite is covered by the feature/* arm with NO hook change (M2/AC8)
m='{"track":"feature","tier":"lite","currentPhase":"implement","phases":{"implement":{"status":"in_progress"}},"signOff":{"signed":false},"artifacts":{}}'
assert_deny  "GateA: feature-lite unsigned → implement (feature/* arm covers lite)" "$(run "$rd/manifest.json" "$m")"
m='{"track":"feature","tier":"lite","currentPhase":"implement","phases":{"implement":{"status":"in_progress"}},"signOff":{"signed":true},"artifacts":{}}'
assert_allow "GateA: feature-lite signed → implement" "$(run "$rd/manifest.json" "$m")"

# ---- Gate B: reach done ------------------------------------------------------
# v0.9.0/AC10: the historic stub (heading but no evidence content) must now DENY.
rd="$(mkrun b-ok)"; printf '# Verify\n\n## Verdict\npass\n' > "$rd/verify.md"
m='{"track":"feature","currentPhase":"done","phases":{"verify":{"status":"complete"}},"artifacts":{"verify":"verify.md"}}'
assert_deny  "GateB/AC10: legacy stub verify.md (no Contract mapping) → denied" "$(run "$rd/manifest.json" "$m")"

rd="$(mkrun b-filled)"
printf '# Verify\n\n## Contract mapping\n\n### AC1: thing works\n- **Evidence:** `make test` — exit 0 — all green\n\n## Verdict\npass\n' > "$rd/verify.md"
assert_allow "GateB/AC10: filled report (Contract mapping + status token) → allowed" "$(run "$rd/manifest.json" "$m")"

rd="$(mkrun b-headingonly)"; printf '# Verify\n\n## Contract mapping\n\nlooks fine to me\n' > "$rd/verify.md"
assert_deny  "GateB/AC10: Contract mapping without a captured status token → denied" "$(run "$rd/manifest.json" "$m")"

# The SHIPPED TEMPLATE itself (verbatim, unfilled) must never pass Gate B — pins the
# placeholder-contains-a-real-status-token regression class (a bare digit in a skeleton
# line would make the content check vacuous).
rd="$(mkrun b-template)"; cp templates/verify.md "$rd/verify.md"
assert_deny  "GateB/AC10: verbatim unfilled template → denied" "$(run "$rd/manifest.json" "$m")"

rd="$(mkrun b-missing)"
m='{"track":"feature","currentPhase":"done","phases":{"verify":{"status":"complete"}},"artifacts":{"verify":"verify.md"}}'
assert_deny  "GateB: feature done, verify.md absent" "$(run "$rd/manifest.json" "$m")"

rd="$(mkrun b-empty)"; : > "$rd/verify.md"
assert_deny  "GateB: feature done, verify.md empty" "$(run "$rd/manifest.json" "$m")"

rd="$(mkrun b-noheading)"; printf 'plain text, no heading\n' > "$rd/verify.md"
assert_deny  "GateB: feature done, verify.md has no heading" "$(run "$rd/manifest.json" "$m")"

rd="$(mkrun b-status)"; printf '# Verify\n' > "$rd/verify.md"
m='{"track":"feature","currentPhase":"done","phases":{"verify":{"status":"in_progress"}},"artifacts":{"verify":"verify.md"}}'
assert_deny  "GateB: feature done but verify.status != complete" "$(run "$rd/manifest.json" "$m")"

# AC5: renamed pointer honored (no hardcoded filename)
# (content enriched for v0.9.0/AC10 — this fixture tests the pointer, not content depth)
rd="$(mkrun b-renamed)"; printf '# Verify\n\n## Contract mapping\n\nAC1 — exit 0\n' > "$rd/verify-out.md"
m='{"track":"feature","currentPhase":"done","phases":{"verify":{"status":"complete"}},"artifacts":{"verify":"verify-out.md"}}'
assert_allow "GateB/AC5: honors renamed artifacts.verify pointer" "$(run "$rd/manifest.json" "$m")"

# bugfix needs BOTH verify + review. review.md stays a bare heading on purpose —
# the AC10 content check is verify-specific and must NOT apply to review.
rd="$(mkrun b-bugfix-ok)"; printf '# Verify\n\n## Contract mapping\n\nRED then GREEN — exit 0\n' > "$rd/verify.md"; printf '# Review\n' > "$rd/review.md"
m='{"track":"bugfix","currentPhase":"done","phases":{"verify":{"status":"complete"},"review":{"status":"complete"}},"artifacts":{"verify":"verify.md","review":"review.md"}}'
assert_allow "GateB: bugfix done + verify + review" "$(run "$rd/manifest.json" "$m")"
rd="$(mkrun b-bugfix-noreview)"; printf '# Verify\n\n## Contract mapping\n\nRED then GREEN — exit 0\n' > "$rd/verify.md"
assert_deny  "GateB: bugfix done, review.md absent" "$(run "$rd/manifest.json" "$m")"

# ---- Fast-exit + fail-open ---------------------------------------------------
assert_allow "non-manifest write → fast-exit allow" "$(run "$TMP/src/foo.js" 'console.log(1)')"
rd="$(mkrun fo-parse)"
assert_allow "unparseable proposed content → fail-open" "$(run "$rd/manifest.json" '{not valid json')"
m='{"currentPhase":"implement","phases":{"implement":{"status":"in_progress"}}}'
assert_allow "missing track → fail-open" "$(run "$rd/manifest.json" "$m")"

# kill switch: enforce=false allows an otherwise-illegal transition
printf '{"toggles":{"enforce":false}}' > "$TMP/.feature-flow.json"
m='{"track":"feature","tier":"full","currentPhase":"implement","phases":{"implement":{"status":"in_progress"}},"signOff":{"signed":false}}'
assert_allow "kill switch: toggles.enforce=false → allow" "$(run "$rd/manifest.json" "$m")"
rm -f "$TMP/.feature-flow.json"

# jq absent → warn + allow. Restricted PATH (coreutils shim, NO jq); absolute bash.
shim="$TMP/shim"; mkdir -p "$shim"
for b in cat dirname grep sed; do ln -sf "$(command -v "$b")" "$shim/$b"; done
out="$(payload "$rd/manifest.json" "$m" "$TMP" | PATH="$shim" "$(command -v bash)" "$HOOK")"
assert_warn "jq absent → systemMessage warning (fail-open)" "$out"

# ---- Dispatch seam: route a deny case through the run-hook.cmd WRAPPER, not the
# script directly. A chmod/path/wrapper regression would leave every other fixture
# green while enforcement is silently off in production — this is the only check
# that exercises hooks.json's actual dispatch target.
rd="$(mkrun seam)"
m='{"track":"feature","tier":"full","currentPhase":"implement","phases":{"implement":{"status":"in_progress"}},"signOff":{"signed":false}}'
out="$(payload "$rd/manifest.json" "$m" "$TMP" | bash hooks/run-hook.cmd enforce-gate)"
assert_deny "dispatch seam: run-hook.cmd → enforce-gate denies" "$out"

# ---- Edit / MultiEdit (v0.19.0): the gates judge the POST-edit manifest -----------
# Before v0.19.0 hooks.json matched only Write, so an Edit that flipped currentPhase to
# "done" bypassed both gates. The hook now reconstructs the proposed manifest from the
# on-disk file + the edit(s), then runs the same Gate A/B logic.
# payload_edit <file_path> <old> <new> <replace_all:true|false> [cwd]
payload_edit() { jq -cn --arg fp "$1" --arg o "$2" --arg n "$3" --argjson ra "$4" --arg cwd "${5:-$TMP}" \
  '{tool_name:"Edit", tool_input:{file_path:$fp, old_string:$o, new_string:$n, replace_all:$ra}, cwd:$cwd}'; }
# payload_multi <file_path> <edits-json-array> [cwd]
payload_multi() { jq -cn --arg fp "$1" --argjson e "$2" --arg cwd "${3:-$TMP}" \
  '{tool_name:"MultiEdit", tool_input:{file_path:$fp, edits:$e}, cwd:$cwd}'; }
redit()  { payload_edit "$@" | bash "$HOOK"; }
rmulti() { payload_multi "$@" | bash "$HOOK"; }

# E1: Edit flips a verify-phase run to done with no verify evidence on disk → Gate B.
rd="$(mkrun e-done)"
printf '{\n  "track": "feature",\n  "tier": "full",\n  "currentPhase": "verify",\n  "phases": {"verify": {"status": "complete"}},\n  "artifacts": {"verify": "verify.md"}\n}\n' > "$rd/manifest.json"
assert_deny  "Edit: currentPhase verify→done without verify.md → Gate B" \
  "$(redit "$rd/manifest.json" '"currentPhase": "verify"' '"currentPhase": "done"' false)"

# E2: same Edit once real evidence exists → allowed (the gate, not the tool, decides).
printf '# Verify\n\n## Contract mapping\n\nAC1 — exit 0\n' > "$rd/verify.md"
assert_allow "Edit: currentPhase verify→done with valid verify.md → allowed" \
  "$(redit "$rd/manifest.json" '"currentPhase": "verify"' '"currentPhase": "done"' false)"

# E3: Edit enters implement on an unsigned spec → Gate A.
rd="$(mkrun e-impl)"
printf '{"track":"feature","tier":"full","currentPhase":"plan","phases":{},"signOff":{"signed":false}}\n' > "$rd/manifest.json"
assert_deny  "Edit: currentPhase plan→implement unsigned → Gate A" \
  "$(redit "$rd/manifest.json" '"currentPhase":"plan"' '"currentPhase":"implement"' false)"

# E4: MultiEdit applies edits IN ORDER — entering implement without signing → Gate A;
# signing in the same MultiEdit → allowed.
assert_deny  "MultiEdit: enter implement, sign-off untouched → Gate A" \
  "$(rmulti "$rd/manifest.json" '[{"old_string":"\"currentPhase\":\"plan\"","new_string":"\"currentPhase\":\"implement\""}]')"
assert_allow "MultiEdit: sign off + enter implement → allowed" \
  "$(rmulti "$rd/manifest.json" '[{"old_string":"\"signed\":false","new_string":"\"signed\":true"},{"old_string":"\"currentPhase\":\"plan\"","new_string":"\"currentPhase\":\"implement\""}]')"

# E5: an unrelated Edit on a legal manifest → allowed.
rd="$(mkrun e-benign)"
printf '{"track":"feature","tier":"full","currentPhase":"implement","phases":{"implement":{"status":"in_progress"}},"signOff":{"signed":true},"updatedAt":"a"}\n' > "$rd/manifest.json"
assert_allow "Edit: unrelated field change on a legal manifest → allowed" \
  "$(redit "$rd/manifest.json" '"updatedAt":"a"' '"updatedAt":"b"' false)"

# E6: replace_all is honored. The first "verify" occurrence is lastNote, not currentPhase:
# replace_all=false changes only lastNote (currentPhase stays verify → allow);
# replace_all=true also rewrites currentPhase to done (no evidence → Gate B).
rd="$(mkrun e-replaceall)"
printf '{"lastNote":"verify","track":"feature","currentPhase":"verify","phases":{},"artifacts":{}}\n' > "$rd/manifest.json"
assert_allow "Edit: replace_all=false rewrites only the first occurrence → allowed" \
  "$(redit "$rd/manifest.json" '"verify"' '"done"' false)"
assert_deny  "Edit: replace_all=true rewrites currentPhase too → Gate B" \
  "$(redit "$rd/manifest.json" '"verify"' '"done"' true)"

# E7: fail-open on indeterminate edits (Claude Code rejects these edits itself).
assert_allow "Edit: old_string not found → fail-open" \
  "$(redit "$rd/manifest.json" '"no-such-text"' '"currentPhase":"done"' false)"
assert_allow "Edit: manifest file missing on disk → fail-open" \
  "$(redit "$TMP/.feature-flow/e-absent/manifest.json" '"currentPhase":"verify"' '"currentPhase":"done"' false)"
assert_allow "Edit: non-manifest file → fast-exit allow" \
  "$(redit "$TMP/src/foo.js" 'a' 'b' false)"

# E7b: Edit with an EMPTY old_string is Claude Code's create-a-file form (target missing or
# empty) — it must be gated exactly like a Write of new_string, not failed open.
m='{"track":"feature","tier":"full","currentPhase":"implement","signOff":{"signed":false}}'
assert_deny  "Edit create (empty old_string, file missing) unsigned implement → Gate A" \
  "$(redit "$TMP/.feature-flow/e-create/manifest.json" '' "$m" false)"
rd="$(mkrun e-emptyfile)"; : > "$rd/manifest.json"
assert_deny  "Edit create (empty old_string, empty file) unsigned implement → Gate A" \
  "$(redit "$rd/manifest.json" '' "$m" false)"
rd="$(mkrun e-emptyold)"; printf '{"track":"feature","currentPhase":"plan"}\n' > "$rd/manifest.json"
assert_allow "Edit: empty old_string on a non-empty file → fail-open (tool rejects it)" \
  "$(redit "$rd/manifest.json" '' "$m" false)"

# E8: the dispatch surface itself — hooks.json must route Edit and MultiEdit to the gate,
# or every fixture above is green while production never calls the hook.
matcher="$(jq -r '.hooks.PreToolUse[] | select(.hooks[].command | test("enforce-gate")) | .matcher' hooks/hooks.json)"
for t in Write Edit MultiEdit; do
  printf '%s' "$t" | grep -qxE "$matcher" \
    && ok "hooks.json PreToolUse matcher routes $t to enforce-gate" \
    || err "hooks.json PreToolUse matcher '$matcher' does not match $t"
done

# ---- Revision binding (v0.22.0): hooks/lib/revision.sh ------------------------------
# Real temporary git repositories — the fingerprint is git state, so fixtures must be too.
LIB="hooks/lib/revision.sh"
gitc() { git -C "$1" -c user.name=ff -c user.email=ff@example.invalid "${@:2}"; }
fp() { bash "$LIB" "$1"; }                  # CLI mode: prints the fingerprint of <project-dir>
if ! command -v git >/dev/null 2>&1; then
  err "revision fixtures need git on PATH"
elif [ ! -f "$LIB" ]; then
  err "revision lib missing: $LIB"
else
  G="$TMP/rev-repo"; mkdir -p "$G/src" "$G/pkg"
  git -C "$G" init -q
  for n in 01 02 03 04 05 06 07 08 09 10 11 12; do printf '%s\n' "$n" > "$G/src/f$n.txt"; done
  printf 'root\n' > "$G/pkg/p.txt"
  printf '.feature-flow/\n' > "$G/.gitignore"              # base ignored; kb deliberately NOT ignored
  printf '{"paths":{"durable":"docs/ff"}}\n' > "$G/.feature-flow.json"
  gitc "$G" add -A && gitc "$G" commit -qm base

  base="$(fp "$G")"
  { [ -n "$base" ] && [ "$base" = "$(fp "$G")" ]; } \
    && ok "rev lib: fingerprint is repeatable" || err "rev lib: fingerprint not repeatable ('$base')"
  [ "$base" = "$(git -C "$G" rev-parse 'HEAD^{tree}')" ] \
    && ok "rev lib: clean tree equals HEAD's tree" || err "rev lib: clean tree != HEAD^{tree}"

  # AC3 — bookkeeping writes (paths.base, paths.durable, paths.kb) are invisible.
  mkdir -p "$G/.feature-flow/run" "$G/docs/ff/2026-run" "$G/.feature-flow-kb"
  printf '{}\n' > "$G/.feature-flow/run/manifest.json"
  printf '# spec\n' > "$G/docs/ff/2026-run/spec.md"
  printf '# kb\n' > "$G/.feature-flow-kb/entry.md"
  [ "$(fp "$G")" = "$base" ] \
    && ok "rev lib/AC3: writes under paths.base, paths.durable, paths.kb don't change it" \
    || err "rev lib/AC3: bookkeeping writes changed the fingerprint"
  # AC3 — a nested repository (e.g. .claude/worktrees/x) is invisible.
  N="$G/.claude/worktrees/x"; mkdir -p "$N"; git -C "$N" init -q; printf 'n\n' > "$N/n.txt"
  gitc "$N" add -A && gitc "$N" commit -qm nested
  [ "$(fp "$G")" = "$base" ] \
    && ok "rev lib/AC3: nested git repository doesn't change it" \
    || err "rev lib/AC3: nested repository changed the fingerprint"

  # AC4 — real code changes are visible; reverting restores the value.
  printf 'edited\n' >> "$G/src/f01.txt"; e1="$(fp "$G")"
  [ -n "$e1" ] && [ "$e1" != "$base" ] && ok "rev lib/AC4: tracked edit changes it" || err "rev lib/AC4: tracked edit not detected"
  git -C "$G" checkout -q -- src/f01.txt
  rm "$G/src/f02.txt"; e2="$(fp "$G")"
  [ -n "$e2" ] && [ "$e2" != "$base" ] && ok "rev lib/AC4: tracked delete changes it" || err "rev lib/AC4: tracked delete not detected"
  git -C "$G" checkout -q -- src/f02.txt
  printf 'new\n' > "$G/src/new.txt"; e3="$(fp "$G")"
  [ -n "$e3" ] && [ "$e3" != "$base" ] && ok "rev lib/AC4: untracked non-ignored file changes it" || err "rev lib/AC4: untracked file not detected"
  # The real index must be byte-identical across fingerprint runs on a dirty tree (sampled
  # right around the calls — the fixture's own `git checkout`s legitimately rewrite it).
  printf 'dirty\n' >> "$G/src/f04.txt"; idx0="$(cksum < "$G/.git/index")"
  fp "$G" >/dev/null; fp "$G" >/dev/null
  [ "$(cksum < "$G/.git/index")" = "$idx0" ] \
    && ok "rev lib: the real .git/index is never modified" || err "rev lib: real index changed"
  printf '04\n' > "$G/src/f04.txt"
  rm "$G/src/new.txt"
  [ "$(fp "$G")" = "$base" ] && ok "rev lib/AC4: revert restores the original value" || err "rev lib/AC4: revert did not restore"

  # FS3 — project dir is a subdirectory of the git top level (monorepo package).
  printf '{"paths":{"durable":"docs/ff"}}\n' > "$G/pkg/.feature-flow.json"
  s0="$(fp "$G/pkg")"
  mkdir -p "$G/pkg/.feature-flow/r" "$G/pkg/docs/ff/x"
  printf '{}\n' > "$G/pkg/.feature-flow/r/manifest.json"; printf '# d\n' > "$G/pkg/docs/ff/x/d.md"
  [ -n "$s0" ] && [ "$(fp "$G/pkg")" = "$s0" ] \
    && ok "rev lib/FS3: subdir project — its own bookkeeping paths are excluded" \
    || err "rev lib/FS3: subdir project bookkeeping changed the fingerprint"
  printf 'x\n' >> "$G/src/f03.txt"
  [ "$(fp "$G/pkg")" != "$s0" ] \
    && ok "rev lib/FS3: subdir project — edits elsewhere in the repo are still detected" \
    || err "rev lib/FS3: edit outside the subdir was missed"
  git -C "$G" checkout -q -- src/f03.txt
  rm -rf "$G/pkg/.feature-flow" "$G/pkg/docs" "$G/pkg/.feature-flow.json"

  # FS4 — every paths.* form: absolute, trailing slash, null, unset.
  for cfg in "{\"paths\":{\"durable\":\"$G/docs/ff\"}}" '{"paths":{"durable":"docs/ff/"}}' '{"paths":{"durable":"./docs/ff"}}'; do
    printf '%s\n' "$cfg" > "$G/.feature-flow.json"; c0="$(fp "$G")"
    printf '# more\n' > "$G/docs/ff/2026-run/more.md"
    [ -n "$c0" ] && [ "$(fp "$G")" = "$c0" ] \
      && ok "rev lib/FS4: durable form $cfg is excluded" || err "rev lib/FS4: durable form $cfg not excluded"
    rm -f "$G/docs/ff/2026-run/more.md"
  done
  printf '{"paths":{"durable":null}}\n' > "$G/.feature-flow.json"; c0="$(fp "$G")"
  printf '# kb2\n' > "$G/.feature-flow-kb/e2.md"
  [ -n "$c0" ] && [ "$(fp "$G")" = "$c0" ] \
    && ok "rev lib/FS4: durable null + kb unset → default kb still excluded" || err "rev lib/FS4: default kb not excluded"
  printf 'x\n' > "$G/docs/ff/2026-run/code-now.md"
  [ "$(fp "$G")" != "$c0" ] \
    && ok "rev lib/FS4: durable null → docs/ff counts as code" || err "rev lib/FS4: durable null still excluded docs/ff"
  rm -f "$G/docs/ff/2026-run/code-now.md" "$G/.feature-flow-kb/e2.md"
  git -C "$G" checkout -q -- .feature-flow.json

  # AC7 / FS1 — changed-path listing: capped, counted; unavailable objects; non-hex ids.
  for n in 01 02 03 04 05 06 07 08 09 10 11 12; do printf 'z\n' >> "$G/src/f$n.txt"; done
  after="$(fp "$G")"
  out="$( . "$LIB"; revision_changed_paths "$G" "$base" "$after" )"
  printf '%s' "$out" | grep -q 'src/f01.txt' && printf '%s' "$out" | grep -q '(+2 more)' \
    && ok "rev lib/AC7: changed paths listed, capped at 10 with '+N more'" || err "rev lib/AC7: bad listing: $out"
  out="$( . "$LIB"; revision_changed_paths "$G" 0123456789abcdef0123456789abcdef01234567 "$after" )"
  [ "$out" = "changed paths unavailable" ] \
    && ok "rev lib/FS1: missing tree object → 'changed paths unavailable'" || err "rev lib/FS1: got: $out"
  out="$( . "$LIB"; revision_changed_paths "$G" '--output=/tmp/x' "$after" )"
  [ "$out" = "changed paths unavailable" ] \
    && ok "rev lib: a non-hex revision is never passed to git" || err "rev lib: non-hex id accepted: $out"
  git -C "$G" checkout -q -- src
  ( . "$LIB"; revision_fingerprint "$TMP/not-a-repo-$$" ) >/dev/null 2>&1 \
    && err "rev lib: fingerprint outside a repo should fail" || ok "rev lib: fingerprint outside a git repo returns non-zero"

  # ---- Gate B revision binding (hook) — AC5–AC9, FS1 --------------------------------
  H="$TMP/rev-hook"; mkdir -p "$H/src"; git -C "$H" init -q
  printf 'a\n' > "$H/src/a.txt"; printf '.feature-flow/\n' > "$H/.gitignore"
  gitc "$H" add -A && gitc "$H" commit -qm base
  VOK='# Verify\n\n## Contract mapping\n\n### AC1\n- **Evidence:** `make test` — exit 0\n'
  # mkrb <slug>: run dir inside the git repo, with a verify.md that passes the 0.21.0 Gate B floor
  mkrb() { local d="$H/.feature-flow/$1"; mkdir -p "$d"; printf "$VOK" > "$d/verify.md"; printf '%s' "$d"; }
  # donem <review-rev> <verify-rev> [extra-json]: a revision-bound feature manifest proposing done
  donem() { jq -cn --arg r "$1" --arg v "$2" --argjson x "${3:-{\}}" '
    {track:"feature",tier:"full",revisionBound:true,currentPhase:"done",artifacts:{verify:"verify.md"},
     phases:{review:{status:"complete"},verify:{status:"complete"}}}
    | if $r == "" then . else .phases.review.revision = $r end
    | if $v == "" then . else .phases.verify.revision = $v end | . * $x'; }
  hrun() { payload "$1" "$2" "$H" | bash "$HOOK"; }
  cur="$(fp "$H")"

  rd="$(mkrb rb-ok)"
  assert_allow "GateB/AC6: both revisions equal the current tree → allowed" "$(hrun "$rd/manifest.json" "$(donem "$cur" "$cur")")"
  out="$(hrun "$rd/manifest.json" "$(donem "" "$cur")")"
  assert_deny "GateB/AC5: review revision missing → denied" "$out"
  printf '%s' "$out" | grep -q 'review revision not recorded' && ok "GateB/AC5: reason names the missing review revision" || err "GateB/AC5: reason: $out"
  out="$(hrun "$rd/manifest.json" "$(donem "$cur" "")")"
  assert_deny "GateB/AC5: verify revision missing → denied" "$out"
  printf '%s' "$out" | grep -q 'verify revision not recorded' && ok "GateB/AC5: reason names the missing verify revision" || err "GateB/AC5: reason: $out"

  printf 'repaired\n' >> "$H/src/a.txt"; cur2="$(fp "$H")"      # a verify repair after review
  out="$(hrun "$rd/manifest.json" "$(donem "$cur" "$cur2")")"
  assert_deny "GateB/AC5: review revision stale (code changed after review) → denied" "$out"
  printf '%s' "$out" | grep -q 'review revision is stale' && printf '%s' "$out" | grep -q 'src/a.txt' \
    && ok "GateB/AC7: stale reason names the phase and the changed path" || err "GateB/AC7: reason: $out"
  out="$(hrun "$rd/manifest.json" "$(donem "$cur2" "$cur")")"
  printf '%s' "$out" | grep -q 'verify revision is stale' \
    && ok "GateB/AC5: verify revision stale → denied, naming verify" || err "GateB/AC5: verify-stale reason: $out"
  assert_allow "GateB/AC6: after re-stamping both on the current tree → allowed" "$(hrun "$rd/manifest.json" "$(donem "$cur2" "$cur2")")"
  out="$(hrun "$rd/manifest.json" "$(donem 0123456789abcdef0123456789abcdef01234567 "$cur2")")"
  assert_deny "GateB/FS1: stamped tree object missing → still denied" "$out"
  printf '%s' "$out" | grep -q 'changed paths unavailable' && ok "GateB/FS1: reason says changed paths unavailable" || err "GateB/FS1: reason: $out"

  # AC8 — pre-0.22 run (no revisionBound), non-git project, kill switch: 0.21.0 behaviour.
  assert_allow "GateB/AC8: revisionBound absent in a git repo → 0.21.0 behaviour (allowed)" \
    "$(hrun "$rd/manifest.json" "$(donem "" "" '{"revisionBound":null}' | jq -c 'del(.revisionBound)')")"
  rd="$(mkrun rb-nogit)"; printf "$VOK" > "$rd/verify.md"
  assert_allow "GateB/AC8: revisionBound outside any git repo → 0.21.0 behaviour (allowed)" \
    "$(run "$rd/manifest.json" "$(donem "" "")")"
  rd="$(mkrb rb-kill)"; printf '{"toggles":{"enforce":false}}\n' > "$H/.feature-flow.json"
  assert_allow "GateB/AC8: toggles.enforce=false → no revision check" "$(hrun "$rd/manifest.json" "$(donem "" "")")"
  rm -f "$H/.feature-flow.json"

  # AC9 — a .git exists but git is missing: allow, loudly.
  gshim="$TMP/gshim"; mkdir -p "$gshim"
  for b in cat dirname grep sed jq; do ln -sf "$(command -v "$b")" "$gshim/$b"; done
  rd="$(mkrb rb-nogitbin)"
  out="$(payload "$rd/manifest.json" "$(donem "" "")" "$H" | PATH="$gshim" "$(command -v bash)" "$HOOK")"
  assert_warn "GateB/AC9: git unavailable in a git repo → allowed with a systemMessage warning" "$out"
  printf '%s' "$out" | grep -q '"permissionDecision"' && err "GateB/AC9: must not deny when the revision cannot be computed" \
    || ok "GateB/AC9: no deny when the revision cannot be computed"

  # The .git walk-up must terminate even on a relative project path (no cwd, relative file_path).
  # verify.md must exist under the relative run dir, or the 0.21.0 floor denies before the walk-up runs.
  mkdir -p "$TMP/rel/.feature-flow/x"; printf "$VOK" > "$TMP/rel/.feature-flow/x/verify.md"
  rel="$(jq -cn --arg c "$(donem "" "")" '{tool_name:"Write",tool_input:{file_path:"rel/.feature-flow/x/manifest.json",content:$c}}')"
  if command -v timeout >/dev/null 2>&1; then
    ( cd "$TMP" && printf '%s' "$rel" | timeout 10 bash "$OLDPWD/$HOOK" >/dev/null ); rc=$?
    [ "$rc" -ne 124 ] && ok "GateB: .git walk-up terminates on a relative project path" \
      || err "GateB: .git walk-up hung on a relative project path"
  fi

  # E2E shape through the production dispatch path (hooks.json → run-hook.cmd → enforce-gate).
  rd="$(mkrb rb-seam)"
  out="$(payload "$rd/manifest.json" "$(donem "$cur" "$cur2")" "$H" | bash hooks/run-hook.cmd enforce-gate)"
  assert_deny "GateB/E2E: stale review through run-hook.cmd → denied" "$out"
  git -C "$H" checkout -q -- src/a.txt
fi

if [ "$fail" -eq 0 ]; then echo "PASS: enforce-gate guard"; else echo "RED: enforce-gate guard failed"; fi
exit "$fail"
