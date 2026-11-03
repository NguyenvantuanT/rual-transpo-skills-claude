# Pack flutter — bộ base MVVM + Provider. Hợp đồng: ../README.md
# shortcut: grep-based checks, not AST — expect rare false positives (e.g. "!" inside string literals); upgrade to a custom_lint package if noise grows.
flutter_markers="pubspec.yaml"
flutter_files="lib/*.dart lib/*.arb pubspec.yaml"
flutter_generated='\.(gr|g|freezed)\.dart$|^lib/src/(gen|generated)/'
flutter_generated_msg="Sửa nguồn (app_router.dart / @RoutePage / ARB / assets) rồi chạy build_runner hoặc intl_utils:generate."
flutter_skills='lib/src/pages/.*_vm\.dart$=flutter-mvvm-provider-architecture
lib/src/(pages|components)/=flutter-ui-style-guide
lib/src/(services|models)/=flutter-networking-and-data
lib/.*\.arb$=flutter-internationalization
^(test|integration_test)/=flutter-testing'

flutter_app_flag=$(cfg HARNESS_APP_FLAG)
flutter_max_lines=$(cfg HARNESS_MAX_LINES); flutter_max_lines=${flutter_max_lines:-500}
flutter_model_style=$(cfg HARNESS_MODEL_STYLE); flutter_model_style=${flutter_model_style:-manual}
flutter_arb_done=" "

flutter_layer() {
  case "$rel" in $1) flag "layer_$2" "^import ['\"].*/($3)/" "$4" ;; esac
}

flutter_rules() {
  case "$rel" in
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
      [ -n "$flutter_app_flag" ] && flag app_branch "\\b$flutter_app_flag\\b" "Rẽ nhánh app (\`$flutter_app_flag\`) chỉ được ở setUpInjector → inject qua DI" '^lib/(app/|src/utils/locator\.dart)'
      flutter_layer 'lib/src/models/*' models 'pages|components|services|base' 'models/ chỉ chứa data class + enum → không import pages/components/services/base'
      flutter_layer 'lib/src/services/*' services 'pages|components' 'services/ không phụ thuộc UI → không import pages/components; trả data cho VM'
      flutter_layer 'lib/src/components/*' components 'pages' 'components/ dùng chung → không import pages/; nhận data qua constructor'
      case "$rel" in lib/src/pages/*_vm.dart) ;; lib/src/pages/*|lib/src/components/*)
        flag supa_in_ui "Supabase\\.instance|\\bsupa\\.|\\.from\\(['\"]|\\.rpc\\(" 'UI không gọi Supabase → thêm method vào <domain>_queries.dart, VM gọi query' ;;
      esac
      case "$rel" in lib/src/models/enums/*) ;; lib/src/models/*)
        if [ "$flutter_model_style" = generated ]; then
          grep -q '_\$' "$file" || flag model_handwritten 'factory [A-Za-z0-9_]+\.from(Json|Map)\(' 'HARNESS_MODEL_STYLE=generated → `@JsonSerializable` + `part '"'"'<file>.g.dart'"'"'` + `_$XFromJson`, rồi build_runner'
        else
          flag model_codegen '@JsonSerializable' 'HARNESS_MODEL_STYLE=manual → viết tay `fromJson`/`toJson` (cascade `..`), không codegen'
        fi ;;
      esac
      flag sb_secret 'sk_live_[0-9A-Za-z]{10,}|sk-ant-[A-Za-z0-9_-]{10,}|sk-(proj-)?[A-Za-z0-9]{20,}|eyJ[A-Za-z0-9_-]{15,}\.eyJ[A-Za-z0-9_-]{15,}' 'Secret hard-code → đưa vào .env / secret store, đọc qua AppConfig'
      case "$disabled" in *" file_size "*) ;; *)
        n=$(wc -l < "$file")
        old=0; in_base "$rpath" && old=$(git show "$diff_base:$rpath" 2>/dev/null | wc -l)
        [ "$n" -gt "$flutter_max_lines" ] && { [ -z "$diff_base" ] || [ "$n" -gt "$old" ]; } && msgs+="- [file_size] $n dòng > $flutter_max_lines → tách sub-widget ra lib/src/components/<feature>/<widget>.dart"$'\n' ;;
      esac
      ;;

    lib/*intl_*.arb)
      dir=$(dirname "$file")
      case "$disabled$flutter_arb_done" in *" arb_sync "*|*" $dir "*) ;; *)
        flutter_arb_done+="$dir "
        keys() { grep -oE '^[[:space:]]*"[^"@][^"]*"[[:space:]]*:' "$1" | sed -E 's/^[[:space:]]*"([^"]*)".*/\1/' | sort -u; }
        all=$(for f in "$dir"/intl_*.arb; do keys "$f"; done | sort -u)
        scope="$all"
        if [ -n "$diff_base" ]; then
          scope=$(for f in "$dir"/intl_*.arb; do
                    r=$(relpath "$f")
                    if in_base "$r"; then git diff -U0 "$diff_base" -- "$r" 2>/dev/null | grep -E '^\+'; else cat "$f"; fi
                  done | grep -oE '^\+?[[:space:]]*"[^"@][^"]*"[[:space:]]*:' | sed -E 's/^\+?[[:space:]]*"([^"]*)".*/\1/' | sort -u)
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
}

flutter_bin() { if command -v fvm >/dev/null 2>&1; then echo "fvm flutter"; else echo flutter; fi; }

# T1 — chạy trong Stop hook. $changed = file đổi (rel). Ghi vào $msgs.
flutter_verify() {
  newer() { [ -f "$1" ] && [ -f "$2" ] && [ "$1" -nt "$2" ]; }
  newer lib/router/app_router.dart lib/router/app_router.gr.dart && msgs+="- app_router.gr.dart cũ hơn app_router.dart → chạy build_runner"$'\n'
  local l10n arb m g out issues flutter_cmd
  l10n=$(ls lib/src/generated/l10n.dart lib/generated/l10n.dart 2>/dev/null | head -1)
  for arb in $(printf '%s\n' "$changed" | grep -E 'intl_.*\.arb$'); do
    newer "$arb" "$l10n" && { msgs+="- l10n generated cũ hơn ARB → chạy intl_utils:generate"$'\n'; break; }
  done
  for m in $(printf '%s\n' "$changed" | grep -E '^lib/src/models/.*\.dart$' | grep -vE '\.g\.dart$'); do
    g="${m%.dart}.g.dart"
    grep -q "part '.*\.g\.dart'" "$m" 2>/dev/null && { [ ! -f "$g" ] || newer "$m" "$g"; } && { msgs+="- $g thiếu/cũ hơn model → chạy build_runner"$'\n'; break; }
  done

  printf '%s\n' "$changed" | grep -qE '\.(dart|yaml)$' || return 0
  case "$disabled" in *" analyze "*) return 0 ;; esac
  flutter_cmd=$(flutter_bin)
  if ! out=$($flutter_cmd analyze --no-pub 2>&1); then
    issues=$(printf '%s\n' "$out" | grep -E '^\s*(error|warning|info) ' | head -20)
    msgs+="- flutter analyze FAIL:"$'\n'"${issues:-$(printf '%s\n' "$out" | tail -15)}"$'\n'
  fi
}

# T1 test — chỉ test liên quan: file test đổi + test/**/<tên>_test.dart của file lib đổi. Không tìm thấy test → im (thiếu test là việc của reviewer/evaluator).
flutter_test() {
  [ -d test ] || return 0
  local f t tests="" out
  for f in $(printf '%s\n' "$changed" | grep -E '^(lib|test)/.*\.dart$' | grep -vE '\.(g|gr|freezed)\.dart$'); do
    case "$f" in
      test/*_test.dart) [ -f "$f" ] && tests+="$f"$'\n' ;;
      lib/*) tests+="$(find test -name "$(basename "$f" .dart)_test.dart" 2>/dev/null)"$'\n' ;;
    esac
  done
  tests=$(printf '%s' "$tests" | grep -v '^$' | sort -u | head -30)
  [ -n "$tests" ] || return 0
  if ! out=$($(flutter_bin) test --no-pub $tests 2>&1); then
    msgs+="- [test] flutter test FAIL → sửa code (không sửa test cho xanh trừ khi test sai, ghi lý do):"$'\n'"$(printf '%s\n' "$out" | grep -vE '^[0-9]{2}:[0-9]{2} \+[0-9]+.*: (loading|Some tests)' | tail -25)"$'\n'
  fi
}
