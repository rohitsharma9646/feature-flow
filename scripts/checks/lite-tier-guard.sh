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

if [ "$fail" -eq 0 ]; then echo "PASS: lite-tier guard"; else echo "RED: lite-tier guard failed"; fi
exit "$fail"
