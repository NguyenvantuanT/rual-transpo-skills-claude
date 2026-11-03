#!/usr/bin/env bash
# Harness rule engine. Usage: check.sh [file...]   (no args = mọi file tracked mà các pack đang bật phụ trách)
# HARNESS_DIFF=<git ref> → chỉ báo vi phạm trên dòng thêm từ ref đó (hook: HEAD, CI: PR base). Không đặt = cả file (init, gardening).
# Chạy từ root repo app (monorepo: vẫn root repo, engine tự chia file theo root của từng pack). Exit 1 khi có rule fail. Dùng chung cho hook, CI và người. Rule nằm trong packs/<stack>/pack.sh.
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
  for p in $packs; do
    eval "fs=\$${p}_files"
    for d in $(pack_roots "$p"); do
      for s in $fs; do if [ "$d" = . ]; then specs+=" $s"; else specs+=" $d/$s"; fi; done
    done
  done
  set -f; set -- $(git ls-files $specs 2>/dev/null | LC_ALL=C sort -u); set +f
fi

out=""
for file in "$@"; do
  file=$(norm "$file")
  [ -f "$file" ] || continue
  rpath=$(relpath "$file")
  generated_by "$rpath" >/dev/null && continue
  msgs=""
  added=$(added_lines "$rpath")
  # Pack chỉ thấy file nằm trong root của nó; $rel = path tính từ root pack, $rpath = path từ root repo.
  for p in $packs; do d=$(pack_root "$p" "$rpath") || continue; rel=$(pack_rel "$d" "$rpath"); "${p}_rules"; done
  [ -n "$msgs" ] && out+="$rpath:"$'\n'"$msgs"
done

[ -z "$out" ] && exit 0
total=$(printf '%s' "$out" | wc -l)
printf '%s' "$out" | head -n "$max_out"
[ "$total" -gt "$max_out" ] && echo "… còn $((total - max_out)) dòng — chạy check.sh <file> cho từng file"
echo "(tắt rule cho dự án: HARNESS_DISABLE trong .claude/harness.env)"
exit 1
