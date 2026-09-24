#!/usr/bin/env bash
# Regression guard: Retrospective (v0.18.0). Pins the STRUCTURAL acceptance criteria of the
# ff-retro feature (.feature-flow/retro-forward-testing):
#   AC1   ff-retro.md STOPs on a run whose currentPhase is not "done", writing nothing.
#   AC2   ff-retro.md resolves upstream only via manifest.artifacts.<name> and scans the closed
#         signal list; no tier gate (lite + bugfix allowed).
#   AC3   the nine-field candidate schema + its three closed enums live in the schema and template.
#   AC4   docs/manifest-schema.md §Retrospective states a materiality test.
#   AC5   the confirm gate: nothing written until the user confirms; never self-answered.
#   AC6   write mechanics: retro.md at the durable path, artifacts.retro + phases.retro, currentPhase
#         stays "done", nothing else written.
#   AC7   the zero-candidate sentinel `_No material events._`.
#   AC8   autopilot never chains ff-retro; ff-verify / ff-review completion names it.
#   AC9   re-run guard.
#   AC10  forward-test-owned findings use the Fired input / Expected outcome / Control input shape.
#   AC11  schema wiring (section, durable set, field note, §Autopilot row NOT "unconditional"),
#         JSON schema (phases.retro + 4 track enums, NOT currentPhase), SKILL/README, dist parity.
#
# Whether ff-retro actually HOLDS its confirm gate in a live session (writes nothing unconfirmed)
# is an LLM judgment — proven by the headless self-run in the run's verify evidence (design FS3),
# not here.
set -u
cd "$(dirname "$0")/../.." || exit 2
fail=0
err() { echo "FAIL: $1"; fail=1; }
ok()  { echo "ok:   $1"; }
has() { grep -qF -- "$2" "$1" && ok "$1: $3" || err "$1: $3 (missing: $2)"; }

# body of the first '## ' section whose heading matches, up to (excluding) the next '## '.
section() { awk -v re="$2" '$0 ~ "^## " && seen {exit} $0 ~ re {seen=1} seen' "$1"; }

. scripts/checks/lib/schema.sh
schema_join  # SCHEMA = the joined contract (temp file); SCHEMA_LABEL names it in messages
TPL="templates/retro.md"
CMD="commands/ff-retro.md"
JSON="schemas/manifest-v1.schema.json"

[ -f "$CMD" ] || err "$CMD must exist"
[ -f "$TPL" ] || err "$TPL must exist"

# --- AC4/AC3/AC5/AC11: canonical §Retrospective --------------------------------------------
sec="$(section "$SCHEMA" '^## Retrospective')"
[ -n "$sec" ] && ok "$SCHEMA_LABEL: '## Retrospective' section present" || err "$SCHEMA_LABEL: '## Retrospective' section missing"
for needle in '### Materiality test' '### Candidate schema' '### Confirm gate' '### Signals' \
              'worked` · `failed` · `missing` · `ambiguous` · `bypassed' \
              'one-off` · `repo-specific` · `reusable' \
              'regression/forward test' 'Fired input / Expected outcome / Control input' \
              'nothing is written until the user accepts, edits, or rejects' \
              'NOT extended with `retro`' '_No material events._' 'no numeric scores'; do
  printf '%s\n' "$sec" | grep -qiF -- "$needle" && ok "§Retrospective: $needle" || err "§Retrospective must state: $needle"
done
grep -qF '`verify`, `delivery`, `retro`' "$SCHEMA" \
  && ok "$SCHEMA_LABEL: durable-eligible set includes 'retro'" || err "$SCHEMA_LABEL: durable-eligible set must include 'retro'"
grep -qF '**`phases.retro`** and **`artifacts.retro`**' "$SCHEMA" \
  && ok "$SCHEMA_LABEL: field note for phases.retro/artifacts.retro" || err "$SCHEMA_LABEL: field note for phases.retro/artifacts.retro missing"
grep -qF '**Retro is never chained.**' "$SCHEMA" \
  && ok "$SCHEMA_LABEL: 'Retro is never chained'" || err "$SCHEMA_LABEL: §Autopilot must say 'Retro is never chained'"
row="$(grep -E '^\| Retro confirm-gate' "$SCHEMA")"
if [ -n "$row" ]; then
  ok "$SCHEMA_LABEL: §Autopilot mandatory-pauses row for the retro confirm-gate"
  printf '%s\n' "$row" | grep -qi 'unconditional' \
    && err "$SCHEMA_LABEL: retro confirm-gate row must NOT say 'unconditional' (passive confirm-gate shape)" \
    || ok "$SCHEMA_LABEL: retro confirm-gate row is not 'unconditional' (passive confirm-gate shape)"
else
  err "$SCHEMA_LABEL: §Autopilot mandatory-pauses table needs a 'Retro confirm-gate' row"
fi

# --- AC11: JSON schema — phases.retro everywhere phases are enumerated, never currentPhase ---
python3 - "$JSON" <<'PY' && ok "$JSON: phases.retro + all four track enums; currentPhase enum omits retro" || err "$JSON: retro wiring wrong (see above)"
import json, sys
s = json.load(open(sys.argv[1]))
p = s["properties"]
assert "retro" in p["phases"]["properties"], "phases.properties lacks retro"
assert "retro" not in p["currentPhase"]["enum"], "currentPhase enum must not contain retro"
enums = []
def walk(o):
    if isinstance(o, dict):
        ph = o.get("properties", {}).get("phases", {}) if isinstance(o.get("properties"), dict) else {}
        if isinstance(ph, dict) and "propertyNames" in ph:
            enums.append(ph["propertyNames"]["enum"])
        for v in o.values(): walk(v)
    elif isinstance(o, list):
        for v in o: walk(v)
walk(s)
assert len(enums) == 4, f"expected 4 track phase enums, found {len(enums)}"
assert all("retro" in e for e in enums), "a track phase enum lacks retro"
PY

# --- AC1/AC2/AC5/AC6/AC8/AC9: the command ---------------------------------------------------
has "$CMD" '§Retrospective' "references §Retrospective by name"
has "$CMD" 'currentPhase != "done"' "done gate"
has "$CMD" 'Write **no** file and make **no** manifest change' "done gate writes nothing (AC1)"
has "$CMD" '**No tier gate.**' "no tier gate (lite allowed)"
has "$CMD" 'Re-run guard' "re-run guard (AC9)"
for a in spec diagnosis design decision plan review verify delivery; do
  has "$CMD" "artifacts.$a" "resolves artifacts.$a by pointer"
done
has "$CMD" '**Nothing is written until the user confirms**' "confirm gate (AC5)"
has "$CMD" 'Never answer this gate yourself' "gate never self-answered"
has "$CMD" 'Autopilot never chains into the retrospective' "never autopilot-chained (AC8)"
has "$CMD" 'Durable artifact resolution' "durable write (AC6)"
has "$CMD" 'artifacts.retro' "records artifacts.retro"
has "$CMD" 'phases.retro = { status: "complete"' "records phases.retro"
has "$CMD" 'Leave `currentPhase = "done"` unchanged' "currentPhase stays done"
has "$CMD" '**Write nothing else.**' "writes nothing else (AC6)"
has "$CMD" 'Fired input / Expected outcome / Control input' "forward-test case shape (AC10)"

# --- AC3/AC7/AC10: the template ------------------------------------------------------------
for f in Event Expected 'Observed evidence' Impact Safeguard 'Safeguard result' Generalizability \
         'Recommended owner' 'Proposed validation'; do
  grep -qF -- "- **$f:**" "$TPL" && ok "$TPL: field '$f'" || err "$TPL: missing field '$f'"
done
has "$TPL" 'worked | failed | missing | ambiguous | bypassed' "safeguard-result enum"
has "$TPL" 'one-off | repo-specific | reusable' "generalizability enum"
has "$TPL" 'regression/forward test' "owner enum includes regression/forward test"
has "$TPL" '_No material events._' "zero-candidate sentinel (AC7)"
has "$TPL" '_No accepted findings — see Rejected._' "all-rejected sentinel (never 'no material events')"
has "$CMD" '_No accepted findings — see Rejected._' "all-rejected sentinel in the command"
has "$TPL" '## Rejected' "rejected count section"
has "$TPL" 'Fired input:' "forward-test case shape (AC10)"

# --- AC8: completion hand-offs name ff-retro (and ff-deliver) --------------------------------
for f in commands/ff-verify.md commands/ff-review.md; do
  grep -q 'ff-retro' "$f" && grep -q 'ff-deliver' "$f" \
    && ok "$f: completion names ff-deliver + ff-retro as optional next steps" \
    || err "$f: completion must name /feature-flow:ff-deliver and /feature-flow:ff-retro"
done

# --- AC11: SKILL + README -------------------------------------------------------------------
grep -q 'ff-retro' skills/feature-flow/SKILL.md && ok "SKILL.md references ff-retro" || err "SKILL.md must reference ff-retro"
grep -q 'ff-retro' README.md                    && ok "README.md references ff-retro" || err "README.md command table must reference ff-retro"

# --- dist parity: every touched packaged file -----------------------------------------------
DIST="dist/codex/feature-flow"
for rel in commands/ff-retro.md templates/retro.md docs/manifest-schema.md commands/ff-verify.md \
           commands/ff-review.md skills/feature-flow/SKILL.md README.md; do
  if diff -q "$rel" "$DIST/$rel" >/dev/null 2>&1; then
    ok "dist parity: $rel"
  else
    err "dist parity: $rel differs from $DIST/$rel (re-run scripts/package-codex-plugin.sh)"
  fi
done

if [ "$fail" -eq 0 ]; then echo "PASS: retro guard"; else echo "RED: retro guard failed"; fi
exit "$fail"
