#!/usr/bin/env bash
# Harness rule engine. Usage: check.sh [file...]   (no args = every tracked file under lib/ + pubspec.yaml)
# HARNESS_DIFF=<git ref> → only report violations on lines added since that ref (hooks: HEAD, CI: PR base). Unset = whole file (init, gardening).
# Run from the app repo root. Exit 1 when any rule fails. Shared by hooks, CI and humans.
# shortcut: grep-based checks, not AST — expect rare false positives (e.g. "!" inside string literals); upgrade to a custom_lint package if noise grows.
root=$(printf '%s' "${CLAUDE_PROJECT_DIR:-$PWD}" | sed -E 's/\+/\//g')
cd "$root" || exit 0
conf=".claude/harness.env"
cfg() { grep -E "^$1=" "$conf" 2>/dev/null | tail -1 | cut -d= -f2- | tr -d "\"'\r"; }
disabled=" $(cfg HARNESS_DISABLE) "
app_flag=$(cfg HARNESS_APP_FLAG)
max_lines=$(cfg HARNESS_MAX_LINES); max_lines=${max_lines:-500}
max_out=60
diff_base="${HARNESS_DIFF:-}"

relpath() { case "$1" in */lib/*) echo "lib/${1#*/lib/}" ;; lib/*) echo "$1" ;; *) basename "$1" ;; esac; }
in_base() { [ -n "$diff_base" ] && git cat-file -e "$diff_base:$1" 2>/dev/null; }
added_lines() {
  [ -z "$diff_base" ] && { echo ALL; return; }
  in_base "$1" || { echo ALL; return; }
  git diff -U0 "$diff_base" -- "$1" 2>/dev/null | sed -nE 's/^@@ [^+]*\+([0-9]+)(,([0-9]+))? @@.*/\1 \3/p' \
    | while read -r s c; do c=${c:-1}; i=0; while [ "$i" -lt "$c" ]; do printf '%s ' $((s + i)); i=$((i + 1)); done; done
}
only_added() { if [ "$added" = ALL ]; then cat; else awk -F: -v set=" $added" 'index(set, " " $1 " ")'; fi; }
if [ $# -eq 0 ]; then
  set -- $(git ls-files 'lib/*.dart' 'lib/*.arb' pubspec.yaml 2>/dev/null)
fi

out=""
arb_dirs_done=" "
for file in "$@"; do
  file=$(printf '%s' "$file" | sed -E 's/\\+/\//g')
  [ -f "$file" ] || continue
  rel=$(relpath "$file")
  msgs=""
  added=$(added_lines "$rel")
  case "$rel" in *.arb) ;; *) [ -z "${added// /}" ] && continue ;; esac

  flag() {
    case "$disabled" in *" $1 "*) return ;; esac
    [ -n "$4" ] && printf '%s' "$rel" | grep -qE "$4" && return
    local hits
    hits=$(grep -nE "$2" "$file" | grep -vE "${5:-^$}" | only_added | head -5)
    [ -n "$hits" ] && msgs+="- [$1] $3"$'\n'"$hits"$'\n'
  }
  layer() {
    case "$rel" in $1) flag "layer_$2" "^import ['\"].*/($3)/" "$4" ;; esac
  }

  case "$rel" in
    *.gr.dart|*.g.dart|*.freezed.dart|lib/src/gen/*|lib/src/generated/*) continue ;;

    lib/*.dart)
      flag null_assert '[]A-Za-z0-9_)]!([].;,) ]|$)' 'Null-assertion `!` → dùng `?.` / `??` / bind local sau null-check' '' '\bis!'
      flag navigator 'Navigator\.(push|of\(|pop\()' 'Navigator.* → `appRouter.push(...)` / `context.router.maybePop()`' 'lib/src/base/base_page\.dart'
      flag color_literal 'Color\(0x' 'Color literal → thêm token vào `AppColor` rồi dùng `AppColor.<name>`' '^lib/src/resources/'
      flag raw_button '\b(ElevatedButton|TextButton|OutlinedButton)\(' 'Raw button → `AppMonoButton` (.small / .smallOutline)' '^lib/src/components/button/'
      flag raw_tap '\b(GestureDetector|InkWell|InkResponse)\(' 'Raw tap widget → `AppBounceButton(onTap: ..., child: ...)` (ngoại lệ: unfocus keyboard, hoặc ghi trong CLAUDE.md + HARNESS_DISABLE)' '^lib/src/(components/button/|base/base_page\.dart)'
      flag raw_progress '\bCircularProgressIndicator\(' '→ `AppCircularProgress(size:, color:)`' '^lib/src/components/loading/'
      flag listview_builder 'ListView\.builder\(' '→ `ListView.separated` + `separatorBuilder`'
      flag raw_dio '\bDio\(' 'Không tự tạo Dio → dùng `api.dio` (ApiClient) từ BaseViewModel' '^lib/src/services/remote/'
      flag hardcoded_text '\bText\(\s*['"'"'"][^'"'"'"]*[A-Za-z]' 'Hardcoded text → thêm key vào mọi ARB, dùng `S.current.<key>`'
      flag comment '^\s*//' 'Comment trong code → xoá, đặt tên tự giải thích (chỉ giữ `// ignore:`)' '' '^[0-9]+:\s*// ?ignore'
      flag gr_import "^import ['\"].*\\.gr\\.dart" 'Import `.gr.dart` trực tiếp → import `app_router.dart`' '^lib/router/'
      [ -n "$app_flag" ] && flag app_branch "\\b$app_flag\\b" "Rẽ nhánh app (\`$app_flag\`) chỉ được ở setUpInjector → inject qua DI" '^lib/(app/|src/utils/locator\.dart)'
      layer 'lib/src/models/*' models 'pages|components|services|base' 'models/ chỉ chứa data class + enum → không import pages/components/services/base'
      layer 'lib/src/services/*' services 'pages|components' 'services/ không phụ thuộc UI → không import pages/components; trả data cho VM'
      layer 'lib/src/components/*' components 'pages' 'components/ dùng chung → không import pages/; nhận data qua constructor'
      case "$disabled" in *" file_size "*) ;; *)
        n=$(wc -l < "$file")
        old=0; in_base "$rel" && old=$(git show "$diff_base:$rel" 2>/dev/null | wc -l)
        [ "$n" -gt "$max_lines" ] && { [ -z "$diff_base" ] || [ "$n" -gt "$old" ]; } && msgs+="- [file_size] $n dòng > $max_lines → tách sub-widget ra lib/src/components/<feature>/<widget>.dart"$'\n' ;;
      esac
      ;;

    lib/*intl_*.arb)
      dir=$(dirname "$file")
      case "$disabled$arb_dirs_done" in *" arb_sync "*|*" $dir "*) ;; *)
        arb_dirs_done+="$dir "
        keys() { grep -oE '^\s*"[^"@][^"]*"\s*:' "$1" | sed -E 's/^\s*"([^"]*)".*/\1/' | sort -u; }
        all=$(for f in "$dir"/intl_*.arb; do keys "$f"; done | sort -u)
        scope="$all"
        if [ -n "$diff_base" ]; then
          scope=$(for f in "$dir"/intl_*.arb; do
                    r=$(relpath "$f")
                    if in_base "$r"; then git diff -U0 "$diff_base" -- "$r" 2>/dev/null | grep -E '^\+'; else cat "$f"; fi
                  done | grep -oE '^\+?\s*"[^"@][^"]*"\s*:' | sed -E 's/^\+?\s*"([^"]*)".*/\1/' | sort -u)
        fi
        for f in "$dir"/intl_*.arb; do
          missing=$(comm -23 <(printf '%s\n' "$all") <(keys "$f") | comm -12 - <(printf '%s\n' "$scope"))
          locale=$(basename "$f" .arb)
          [ -n "$missing" ] && msgs+="- [arb_sync] ${locale#intl_} thiếu key: $(echo $missing) → thêm vào $(basename "$f")"$'\n'
        done ;;
      esac
      ;;

    pubspec.yaml)
      flag caret_version '^\s+[a-z0-9_]+:\s*\^' 'Dependency phải pin EXACT version, không dùng `^`'
      ;;
  esac

  [ -n "$msgs" ] && out+="$rel:"$'\n'"$msgs"
done

[ -z "$out" ] && exit 0
total=$(printf '%s' "$out" | wc -l)
printf '%s' "$out" | head -n "$max_out"
[ "$total" -gt "$max_out" ] && echo "… còn $((total - max_out)) dòng — chạy check.sh <file> cho từng file"
echo "(tắt rule cho dự án: HARNESS_DISABLE trong .claude/harness.env)"
exit 1
