# Sourced by check.sh, hooks. Sets: root (cwd = root), conf, cfg(), disabled, packs (active pack names), relpath(), flag().
harness_dir=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
norm() { printf '%s' "$1" | sed -E 's/\\+/\//g; s#^/([a-zA-Z])/#\1:/#'; }
root=$(norm "${CLAUDE_PROJECT_DIR:-$PWD}")
cd "$root" || exit 0
conf=".claude/harness.env"
cfg() { grep -E "^$1=" "$conf" 2>/dev/null | tail -1 | cut -d= -f2- | tr -d "\"'\r"; }
disabled=" $(cfg HARNESS_DISABLE) "

relpath() {
  local f lf lr
  f=$(norm "$1"); lf=$(printf '%s' "$f" | tr 'A-Z' 'a-z'); lr=$(printf '%s' "$root/" | tr 'A-Z' 'a-z')
  case "$lf" in "$lr"*) echo "${f:${#lr}}" ;; *) echo "${f#./}" ;; esac
}

# Pack = packs/<name>/pack.sh. Hợp đồng: packs/README.md.
# shortcut: marker chỉ xét ở root repo — monorepo nhiều app thì liệt kê tay qua HARNESS_PACKS.
packs=""
for p in "$harness_dir"/packs/*/pack.sh; do
  name=$(basename "$(dirname "$p")")
  . "$p"
  want=$(cfg HARNESS_PACKS)
  if [ -n "$want" ]; then
    case " $want " in *" $name "*) packs+="$name " ;; esac
  else
    eval "markers=\$${name}_markers"
    for m in $markers; do compgen -G "$m" >/dev/null && { packs+="$name "; break; }; done
  fi
done

generated_by() {
  local p re
  for p in $packs; do
    eval "re=\$${p}_generated"
    [ -n "$re" ] && printf '%s' "$1" | grep -qE "$re" && { echo "$p"; return 0; }
  done
  return 1
}

# Rule helper cho pack: flag <id> <regex> <cách sửa> [path bỏ qua] [dòng bỏ qua]. Đọc $file $rel $added, ghi vào $msgs. GI=-i để không phân biệt hoa thường.
only_added() { if [ "$added" = ALL ]; then cat; else awk -F: -v set=" $added" 'index(set, " " $1 " ")'; fi; }
flag() {
  case "$disabled" in *" $1 "*) return ;; esac
  [ -n "$4" ] && printf '%s' "$rel" | grep -qE "$4" && return
  local hits
  hits=$(grep -nE $GI "$2" "$file" | grep -vE "${5:-^$}" | only_added | head -5)
  [ -n "$hits" ] && msgs+="- [$1] $3"$'\n'"$hits"$'\n'
}

# Hook chỉ chạy ở repo đã init harness hoặc có pack khớp — repo lạ không bị chặn.
harness_on() { [ -f "$conf" ] || [ -n "$packs" ]; }
