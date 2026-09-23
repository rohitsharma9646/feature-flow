#!/usr/bin/env bash
# slugify "<title>" -> lowercase, runs of non-alphanumerics collapsed to "-", trimmed
printf '%s\n' "$1" | tr '[:upper:]' '[:lower:]' | sed -E 's/[^a-z0-9]+/-/g; s/^-+//; s/-+$//'
