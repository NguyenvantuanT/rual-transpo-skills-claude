#!/usr/bin/env bash
grep -qE '"stop_hook_active"[[:space:]]*:[[:space:]]*true' && exit 0
here="$(dirname "$0")/../engine"
. "$here/lib.sh"
harness_on || exit 0
git rev-parse --git-dir >/dev/null 2>&1 || exit 0
status=$(git status --porcelain -uall)
[ -n "$status" ] || exit 0

stamp="$(git rev-parse --git-dir)/harness-verified"
sig=$({ printf '%s\n' "$status"; git diff HEAD 2>/dev/null
        git ls-files -o --exclude-standard | xargs -r git hash-object 2>/dev/null; } | git hash-object --stdin)
[ "$(cat "$stamp" 2>/dev/null)" = "$sig" ] && exit 0

changed=$(printf '%s\n' "$status" | cut -c4- | sed 's/.* -> //; s/^"//; s/"$//')
msgs=""

# T1 của từng pack: regen, analyze, lint migration...
for p in $packs; do declare -F "${p}_verify" >/dev/null && "${p}_verify"; done

code_files=$(printf '%s\n' "$changed" | grep -vE '\.md$' | while read -r f; do [ -f "$f" ] && echo "$f"; done)
[ -n "$code_files" ] && { rules=$(HARNESS_DIFF=HEAD bash "$here/check.sh" $code_files) || msgs+="$rules"$'\n'; }

if printf '%s\n' "$status" | grep -qE '^( ?D|D |R)'; then
  docs=$(bash "$here/docs-check.sh") || msgs+="$docs"$'\n'
else
  md_files=$(printf '%s\n' "$changed" | grep -E '\.md$')
  [ -n "$md_files" ] && { docs=$(bash "$here/docs-check.sh" $md_files) || msgs+="$docs"$'\n'; }
fi

if [ -z "$msgs" ]; then
  printf '%s' "$sig" > "$stamp"
  exit 0
fi
printf 'Chưa xong — harness verify:\n%s' "$msgs" >&2
exit 2
