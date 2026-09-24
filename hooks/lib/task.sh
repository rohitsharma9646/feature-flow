#!/usr/bin/env bash
# Feature Flow task packaging (v0.23.0) — docs/schema/task-controller.md §Task packaging.
# That section reproduces this file byte-for-byte; scripts/checks/implement-controller-guard.sh
# fails CI if the two ever differ. Edit both together.
#
# Run:    bash task.sh section <file> <heading-ERE>        -> prints that section of a markdown file
#         bash task.sh diff <project-dir> <tree-a> <tree-b> -> prints --stat, then the unified diff
# Source: . task.sh                                         -> defines task_section, task_diff
#
# task_section finds headings only OUTSIDE fenced code blocks (``` or ~~~, any length >= 3, closed
# by the same character repeated at least as many times), so a plan step whose code contains a
# heading-shaped line never cuts or starts a task brief. The section runs from the matching heading
# to the next heading of the same or a higher level; trailing blank lines are dropped.
# task_diff compares two tree ids (from revision_fingerprint in revision.sh) at the git top level;
# it reads existing objects only — the real index, the working tree and the history are never
# modified. Any failure prints nothing and returns non-zero.

# task_section <file> <heading-ERE>: print the first section whose heading line matches.
task_section() {
  local file=$1 re=$2
  [ -f "$file" ] || return 1
  awk -v re="$re" '
    function run(s, c,   n) { n = 0; while (substr(s, n + 1, 1) == c) n++; return n }
    {
      line = $0; t = line; sub(/^[ \t]*/, "", t)
      if (fc != "") {
        if (substr(t, 1, 1) == fc && run(t, fc) >= fl && substr(t, run(t, fc) + 1) ~ /^[ \t]*$/) fc = ""
        if (on) buf[++n] = line
        next
      }
      c = substr(t, 1, 1)
      if ((c == "`" || c == "~") && run(t, c) >= 3) {
        fc = c; fl = run(t, c)
        if (on) buf[++n] = line
        next
      }
      if (line ~ /^#+[ \t]/) {
        lvl = match(line, /[^#]/) - 1
        if (on && lvl <= level) exit
        if (!on && line ~ re) { on = 1; level = lvl }
      }
      if (on) buf[++n] = line
    }
    END {
      while (n > 0 && buf[n] ~ /^[ \t]*$/) n--
      for (i = 1; i <= n; i++) print buf[i]
      exit(on ? 0 : 1)
    }' "$file"
}

# task_diff <project-dir> <tree-a> <tree-b>: print `git diff --stat` then `git diff -U10`.
task_diff() {
  local proj=$1 a=$2 b=$3 top id stat body
  command -v git >/dev/null 2>&1 || return 1
  for id in "$a" "$b"; do
    case ${#id} in 40|64) ;; *) return 1 ;; esac
    case $id in *[!0-9a-f]*) return 1 ;; esac
  done
  top=$(git -C "$proj" rev-parse --show-toplevel 2>/dev/null) || return 1
  git -C "$top" cat-file -e "$a^{tree}" 2>/dev/null || return 1
  git -C "$top" cat-file -e "$b^{tree}" 2>/dev/null || return 1
  stat=$(git -C "$top" diff --no-color --no-ext-diff --stat "$a" "$b" 2>/dev/null) || return 1
  body=$(git -C "$top" diff --no-color --no-ext-diff -U10 "$a" "$b" 2>/dev/null) || return 1
  printf '%s\n\n%s\n' "$stat" "$body"
}

if [ -z "${BASH_SOURCE[0]:-}" ] || [ "${BASH_SOURCE[0]}" = "$0" ]; then
  case ${1:-} in
    section) shift; task_section "$@" ;;
    diff) shift; task_diff "$@" ;;
    *) echo "usage: task.sh section <file> <heading-ERE> | diff <project-dir> <tree-a> <tree-b>" >&2; exit 2 ;;
  esac
  exit
fi
