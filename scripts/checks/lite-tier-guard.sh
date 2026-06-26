#!/usr/bin/env bash
# Contract guard for the M2 lite feature tier. Greps the command contracts for the
# lite-tier rules (the repo pins prose contracts with grep guards, executable code with
# behavioral fixtures). A drift that drops a lite rule fails here.
set -u
cd "$(dirname "$0")/../.." || exit 2
fail=0
err() { echo "FAIL: $1"; fail=1; }
ok()  { echo "ok:   $1"; }
has() { grep -qiE "$2" "$1" && ok "$3" || err "$3 (missing /$2/ in $1)"; }

# ff.md: soft tier judgment + resolved (not hardcoded) tier in the feature manifest
has commands/ff.md 'tier .*lite vs full|feature tier .*lite'      "ff.md judges feature tier"
has commands/ff.md 'in doubt.*full|doubt → full'                 "ff.md defaults full on doubt"
has commands/ff.md 'resolved .*tier|tier.*resolved'              "ff.md writes resolved tier (not hardcoded full)"

# ff-explore.md: resolved tier on cold-start + 1-agent lite explore
has commands/ff-explore.md 'resolved .*tier|tier.*lite/full'      "ff-explore writes resolved tier"
has commands/ff-explore.md 'exactly ONE|one .*ff-code-explorer'   "ff-explore dispatches 1 explorer when lite"
has commands/ff-explore.md 'tier == .lite.'                       "ff-explore branches on tier == lite"

# ff-clarify.md: lite minimal clarify, route lite->implement, escalation valve
has commands/ff-clarify.md 'Lite tier'                            "ff-clarify has a lite-tier mode"
has commands/ff-clarify.md 'skip beats 1.2|skip beats 1'          "ff-clarify lite skips premise+approach beats"
has commands/ff-clarify.md 'ff-implement'                         "ff-clarify routes lite to implement"
has commands/ff-clarify.md 'Escalation .lite . full|tier = .full.' "ff-clarify has lite->full escalation"

# ff-implement.md: tier-aware feature cold-start — lite requires only spec, never routes to design/plan
has commands/ff-implement.md 'Feature, .tier: lite|Feature.*tier == .lite' "ff-implement has a feature-lite cold-start branch"
has commands/ff-implement.md 'only.*artifacts\.spec|require .*only.*spec' "ff-implement lite requires only spec"
has commands/ff-implement.md 'never.*ff-design|never.*ff-plan'    "ff-implement lite never routes to design/plan"

if [ "$fail" -eq 0 ]; then echo "PASS: lite-tier guard"; else echo "RED: lite-tier guard failed"; fi
exit "$fail"
