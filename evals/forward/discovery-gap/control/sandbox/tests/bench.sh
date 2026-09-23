#!/usr/bin/env bash
# SM1: 5,000-char title slugifies in <= 2 s
t="$(head -c 5000 /dev/zero | tr '\0' a)"
start=$(date +%s%N); bash src/slugify.sh "$t" >/dev/null; end=$(date +%s%N)
ms=$(( (end-start)/1000000 )); echo "elapsed_ms=$ms"; [ "$ms" -le 2000 ]
