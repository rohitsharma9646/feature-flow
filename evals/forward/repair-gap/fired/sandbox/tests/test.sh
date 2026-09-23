#!/usr/bin/env bash
# unit test for src/slugify.sh
fail=0
check() { got="$(bash src/slugify.sh "$1")"; if [ "$got" = "$2" ]; then echo "ok   '$1' -> '$got'"; else echo "FAIL '$1' -> '$got' (want '$2')"; fail=1; fi; }
check "Hello World" "hello-world"
check "  A--B  " "a-b"
check "Release 2.0!" "release-2-0"
exit $fail
