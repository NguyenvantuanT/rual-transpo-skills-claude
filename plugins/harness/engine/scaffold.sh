#!/usr/bin/env bash
# Dựng / cập nhật harness trong repo app. Usage: scaffold.sh   (chạy từ root repo app; skill harness-init gọi)
# - File template chưa có → tạo. Có rồi và chưa ai sửa (hash khớp .claude/harness.lock) → cập nhật lên template mới.
#   Đã bị sửa, hoặc có sẵn từ trước khi init → giữ nguyên, báo "giữ".
# - Khối <!-- harness:stack --> trong AGENTS.md luôn sinh lại từ map.md của các pack đang bật.
. "$(dirname "$0")/lib.sh"
tpl="$harness_dir/templates"
lock=".claude/harness.lock"
version=$(grep -oE '"version"[[:space:]]*:[[:space:]]*"[^"]+"' "$harness_dir/.claude-plugin/plugin.json" | grep -oE '[0-9][^"]*')

dest() { case "$1" in harness.env) echo .claude/harness.env ;; ci/harness.yml) echo .github/workflows/harness.yml ;; *) echo "$1" ;; esac; }
locked() { grep -E " $1\$" "$lock" 2>/dev/null | head -1 | cut -d' ' -f1; }
hash() { git hash-object "$1"; }

render_stack() {
  [ -f AGENTS.md ] || return 0
  grep -q '<!-- harness:stack:start -->' AGENTS.md || { echo "  ! AGENTS.md thiếu marker harness:stack — bỏ qua bản đồ stack"; return 0; }
  local block="" p
  for p in $packs; do [ -f "$harness_dir/packs/$p/map.md" ] && block+=$'\n'"$(cat "$harness_dir/packs/$p/map.md")"$'\n'; done
  [ -n "$block" ] || block=$'\n'"_Chưa có pack cho stack của repo này — chỉ có docs-check + hooks chung._"$'\n'
  printf '%s' "$block" > .harness-stack.tmp
  awk -v f=.harness-stack.tmp '
    /<!-- harness:stack:start -->/ { print; while ((getline l < f) > 0) print l; skip=1; next }
    /<!-- harness:stack:end -->/ { skip=0 }
    !skip' AGENTS.md > AGENTS.md.tmp && mv AGENTS.md.tmp AGENTS.md
  rm -f .harness-stack.tmp
}

packs=${packs% }
echo "harness $version · pack: ${packs:-(không có)}"
entries=""
for src in $(cd "$tpl" && find . -type f | sed 's#^\./##' | LC_ALL=C sort); do
  dst=$(dest "$src")
  old=$(locked "$dst")
  if [ ! -e "$dst" ]; then
    mkdir -p "$(dirname "$dst")" && cp "$tpl/$src" "$dst"
    [ "$dst" = AGENTS.md ] && render_stack
    echo "  tạo      $dst"; entries+="$(hash "$dst") $dst"$'\n'
  elif [ -n "$old" ] && [ "$(hash "$dst")" = "$old" ]; then
    cp "$tpl/$src" "$dst"
    [ "$dst" = AGENTS.md ] && render_stack
    new=$(hash "$dst")
    if [ "$new" = "$old" ]; then echo "  giữ nguyên $dst"; else echo "  cập nhật $dst"; fi
    entries+="$new $dst"$'\n'
  else
    [ "$dst" = AGENTS.md ] && { render_stack; echo "  bản đồ   $dst (khối stack)"; }
    echo "  giữ      $dst (đã sửa tay hoặc có từ trước)"
    [ -n "$old" ] && entries+="$old $dst"$'\n'
  fi
done

mkdir -p .claude
{ echo "# vtinter-harness $version · pack: $packs — scaffold.sh ghi, đừng sửa tay"; printf '%s' "$entries"; } > "$lock"
