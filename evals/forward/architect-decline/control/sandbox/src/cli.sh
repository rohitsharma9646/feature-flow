#!/usr/bin/env bash
# src/cli.sh <command> — dispatches on the first argument. No --version flag yet.
set -u
cmd="${1:-}"
case "$cmd" in
  *)
    echo "usage: cli.sh <command>" >&2
    exit 2
    ;;
esac
