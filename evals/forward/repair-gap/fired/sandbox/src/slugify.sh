#!/usr/bin/env bash
# slugify "<title>" -> lowercase, runs of non-alphanumerics collapsed to "-", trimmed
printf '%s\n' "$1" | sed -E 's/[^a-zA-Z0-9]+/-/g; s/^-+//; s/-+$//'
