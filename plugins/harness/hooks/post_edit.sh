#!/usr/bin/env bash
# Regen reminders live in each pack's <name>_verify (Stop hook) — checked once, not on every edit.
file=$(grep -o '"file_path"[[:space:]]*:[[:space:]]*"[^"]*"' | head -1 | sed -E 's/.*:[[:space:]]*"//; s/"$//; s/\\+/\//g')
[ -f "$file" ] || exit 0
here="$(dirname "$0")/../engine"
. "$here/lib.sh"
harness_on || exit 0

case "$file" in
  *.md) out=$(bash "$here/docs-check.sh" "$file") ;;
  *)    out=$(HARNESS_DIFF=HEAD bash "$here/check.sh" "$file") ;;
esac
[ -z "$out" ] && exit 0
printf 'Harness check:\n%s\n' "$out" >&2
exit 2
