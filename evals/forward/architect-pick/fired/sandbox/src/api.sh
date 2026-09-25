#!/usr/bin/env bash
# src/api.sh <caller-id> — handle one request for <caller-id>. No throttling yet.
set -u
caller_id="${1:-}"
if [ -z "$caller_id" ]; then
  echo "usage: api.sh <caller-id>" >&2
  exit 2
fi
echo "ok"
