#!/usr/bin/env bash
# bash tests/test.sh — exits 0 only when every check passes
fail=0
check_exit() { bash "$1" "$2" >/dev/null 2>&1; got=$?; if [ "$got" = "$3" ]; then echo "ok   $1 '$2' exit $got"; else echo "FAIL $1 '$2' exit $got (want $3)"; fail=1; fi; }
check_exit src/cli.sh bogus 2
exit $fail
