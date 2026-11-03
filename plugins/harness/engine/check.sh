#!/usr/bin/env bash
# Harness rule engine. Usage: check.sh [file...]   (no args = mọi file tracked mà các pack đang bật phụ trách)
# HARNESS_DIFF=<git ref> → chỉ báo vi phạm trên dòng thêm từ ref đó (hook: HEAD, CI: PR base). Không đặt = cả file (init, gardening).
# Chạy từ root repo app. Exit 1 khi có rule fail. Dùng chung cho hook, CI và người. Rule nằm trong packs/<stack>/pack.sh.
. "$(dirname "$0")/lib.sh"
max_out=60
diff_base="${HARNESS_DIFF:-}"

in_base() { [ -n "$diff_base" ] && git cat-file -e "$diff_base:$1" 2>/dev/null; }
added_lines() {
  [ -z "$diff_base" ] && { echo ALL; return; }
  in_base "$1" || { echo ALL; return; }
  git diff -U0 "$diff_base" -- "$1" 2>/dev/null | sed -nE 's/^@@ [^+]*\+([0-9]+)(,([0-9]+))? @@.*/\1 \3/p' \
    | while read -r s c; do c=${c:-1}; i=0; while [ "$i" -lt "$c" ]; do printf '%s ' $((s + i)); i=$((i + 1)); done; done
}

if [ $# -eq 0 ]; then
  specs=""
  for p in $packs; do eval "specs+=\" \$${p}_files\""; done
  set -f; set -- $(git ls-files $specs 2>/dev/null | LC_ALL=C sort -u); set +f
fi

out=""
for file in "$@"; do
  file=$(norm "$file")
  [ -f "$file" ] || continue
  rel=$(relpath "$file")
  generated_by "$rel" >/dev/null && continue
  msgs=""
  added=$(added_lines "$rel")
  for p in $packs; do "${p}_rules"; done
  [ -n "$msgs" ] && out+="$rel:"$'\n'"$msgs"
done

[ -z "$out" ] && exit 0
total=$(printf '%s' "$out" | wc -l)
printf '%s' "$out" | head -n "$max_out"
[ "$total" -gt "$max_out" ] && echo "… còn $((total - max_out)) dòng — chạy check.sh <file> cho từng file"
echo "(tắt rule cho dự án: HARNESS_DISABLE trong .claude/harness.env)"
exit 1
