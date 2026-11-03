# Sourced by check.sh, hooks. Sets: root (cwd = root), conf, cfg(), disabled, packs, roots, pack_root(), relpath(), flag().
harness_dir=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
norm() { printf '%s' "$1" | sed -E 's/\\+/\//g; s#^/([a-zA-Z])/#\1:/#'; }
root=$(norm "${CLAUDE_PROJECT_DIR:-$PWD}")
cd "$root" || exit 0
conf="$root/.claude/harness.env"
cfg() { grep -E "^$1=" "$conf" 2>/dev/null | tail -1 | cut -d= -f2- | tr -d "\"'\r"; }
disabled=" $(cfg HARNESS_DISABLE) "

relpath() {
  local f lf lr
  f=$(norm "$1"); lf=$(printf '%s' "$f" | tr 'A-Z' 'a-z'); lr=$(printf '%s' "$root/" | tr 'A-Z' 'a-z')
  case "$lf" in "$lr"*) echo "${f:${#lr}}" ;; *) echo "${f#./}" ;; esac
}

# Pack = packs/<name>/pack.sh. Hợp đồng: packs/README.md.
# Root của pack = thư mục chứa marker: root repo, thư mục con cấp 1, hoặc apps|packages|services|libs/* (monorepo).
# HARNESS_PACKS ghi đè: "flutter web_ts" (ở root) hoặc "flutter:apps/mobile web_ts:apps/web python:services/api".
# roots: mỗi dòng "<pack> <dir>" ("." = root repo). packs: tên pack đang bật (không trùng).
harness_skip_dirs=' node_modules build dist out coverage android ios linux macos windows lib src test tests docs supabase vendor Library Temp Logs obj bin Assets Packages ProjectSettings '
packs=""; roots=""
want=$(cfg HARNESS_PACKS)
cand="."
for d in */ apps/*/ packages/*/ services/*/ libs/*/; do
  [ -d "$d" ] || continue
  d=${d%/}
  case "$harness_skip_dirs" in *" ${d##*/} "*) continue ;; esac
  case "$d" in .*|*/.*) continue ;; esac
  cand+=" $d"
done
for p in "$harness_dir"/packs/*/pack.sh; do
  name=$(basename "$(dirname "$p")")
  . "$p"
  found=""
  if [ -n "$want" ]; then
    for w in $want; do
      case "$w" in "$name") found+=" ." ;; "$name":*) found+=" ${w#*:}" ;; esac
    done
  else
    eval "markers=\$${name}_markers"
    for d in $cand; do
      for m in $markers; do
        if [ "$d" = . ]; then compgen -G "$m" >/dev/null && { found+=" ."; break; }
        else compgen -G "$d/$m" >/dev/null && { found+=" $d"; break; }; fi
      done
    done
  fi
  [ -n "$found" ] || continue
  packs+="$name "
  for d in $found; do roots+="$name ${d%/}"$'\n'; done
done

# pack_root <pack> <path từ root repo> → root sâu nhất của pack chứa path (exit 1 nếu không có).
pack_root() {
  local best="" d
  for d in $(printf '%s' "$roots" | awk -v p="$1" '$1 == p { print $2 }'); do
    if [ "$d" = . ]; then [ -z "$best" ] && best=.
    else case "$2" in "$d"/*) [ ${#d} -gt ${#best} ] || [ "$best" = . ] && best=$d ;; esac; fi
  done
  [ -n "$best" ] && echo "$best"
}
# pack_rel <root> <path> → path tính từ root của pack.
pack_rel() { if [ "$1" = . ]; then echo "$2"; else echo "${2#"$1"/}"; fi; }
pack_roots() { printf '%s' "$roots" | awk -v p="$1" '$1 == p { print $2 }'; }

generated_by() {
  local p re d
  for p in $packs; do
    eval "re=\$${p}_generated"
    [ -n "$re" ] || continue
    d=$(pack_root "$p" "$1") || continue
    pack_rel "$d" "$1" | grep -qE "$re" && { echo "$p"; return 0; }
  done
  return 1
}

# Secret dùng chung cho mọi pack: flag <id> "$HARNESS_SECRET_RE" '...'
HARNESS_SECRET_RE='sk_live_[0-9A-Za-z]{10,}|sk-ant-[A-Za-z0-9_-]{10,}|sk-(proj-)?[A-Za-z0-9]{20,}|AKIA[0-9A-Z]{16}|ghp_[A-Za-z0-9]{30,}|xox[bp]-[A-Za-z0-9-]{20,}|-----BEGIN [A-Z ]*PRIVATE KEY-----|eyJ[A-Za-z0-9_-]{15,}\.eyJ[A-Za-z0-9_-]{15,}'

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

# tool <tên> → đường dẫn binary của dự án (node_modules/.bin, .venv/bin, venv/bin) hoặc trong PATH; không có → exit 1.
# Dùng trong _verify/_test (cwd = root pack): công cụ không có thì bỏ qua, không báo lỗi.
tool() {
  local c
  for c in "node_modules/.bin/$1" ".venv/bin/$1" "venv/bin/$1"; do [ -x "$c" ] && { echo "$c"; return 0; }; done
  command -v "$1" 2>/dev/null
}
# off <rule_id> → true nếu rule bị tắt qua HARNESS_DISABLE.
off() { case "$disabled" in *" $1 "*) return 0 ;; esac; return 1; }
