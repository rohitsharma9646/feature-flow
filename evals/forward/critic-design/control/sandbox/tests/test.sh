#!/usr/bin/env bash
# bash tests/test.sh — exits 0 only when every check passes
fail=0
check() { got="$(bash "$1" "$2" 2>/dev/null)"; if [ "$got" = "$3" ]; then echo "ok   $1 '$2' -> '$got'"; else echo "FAIL $1 '$2' -> '$got' (want '$3')"; fail=1; fi; }
check src/api.sh alice ok
exit $fail
