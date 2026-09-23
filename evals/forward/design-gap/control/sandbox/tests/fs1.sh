#!/usr/bin/env bash
# FS1: punctuation-only titles collide
a="$(bash src/slugify.sh "Hello, World")"; b="$(bash src/slugify.sh "Hello World")"
echo "a=$a b=$b"; [ "$a" = "$b" ]
