#!/usr/bin/env bash
# Regen reminders (router/ARB) live in stop_verify.sh — it checks generated files are newer, once, instead of on every edit.
file=$(grep -o '"file_path"[[:space:]]*:[[:space:]]*"[^"]*"' | head -1 | sed -E 's/.*:[[:space:]]*"//; s/"$//; s/\\+/\//g')
[ -f "$file" ] || exit 0
here="$(dirname "$0")/../scripts"

case "$file" in
  *.md) out=$(bash "$here/docs-check.sh" "$file") ;;
  *)    out=$(HARNESS_DIFF=HEAD bash "$here/check.sh" "$file") ;;
esac
[ -z "$out" ] && exit 0
printf 'Harness check:\n%s\n' "$out" >&2
exit 2
