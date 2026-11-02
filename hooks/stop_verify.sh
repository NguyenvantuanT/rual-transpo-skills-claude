#!/usr/bin/env bash
grep -qE '"stop_hook_active"[[:space:]]*:[[:space:]]*true' && exit 0
root=$(printf '%s' "${CLAUDE_PROJECT_DIR:-$PWD}" | sed -E 's/\\+/\//g')
cd "$root" || exit 0
[ -f pubspec.yaml ] && git rev-parse --git-dir >/dev/null 2>&1 || exit 0
status=$(git status --porcelain -uall -- lib supabase pubspec.yaml '*.md')
[ -n "$status" ] || exit 0

stamp="$(git rev-parse --git-dir)/harness-verified"
sig=$({ printf '%s\n' "$status"; git diff HEAD -- lib supabase pubspec.yaml '*.md' 2>/dev/null
        git ls-files -o --exclude-standard -- lib supabase '*.md' | xargs -r git hash-object 2>/dev/null; } | git hash-object --stdin)
[ "$(cat "$stamp" 2>/dev/null)" = "$sig" ] && exit 0

changed=$(printf '%s\n' "$status" | cut -c4- | sed 's/.* -> //')
here="$(dirname "$0")/../scripts"
disabled=$(grep -E '^HARNESS_DISABLE=' .claude/harness.env 2>/dev/null | tail -1)

msgs=""
newer() { [ -f "$1" ] && [ -f "$2" ] && [ "$1" -nt "$2" ]; }
newer lib/router/app_router.dart lib/router/app_router.gr.dart && msgs+="- app_router.gr.dart cũ hơn app_router.dart → chạy build_runner"$'\n'
l10n=$(ls lib/src/generated/l10n.dart lib/generated/l10n.dart 2>/dev/null | head -1)
for arb in $(printf '%s\n' "$changed" | grep -E 'intl_.*\.arb$'); do
  newer "$arb" "$l10n" && { msgs+="- l10n generated cũ hơn ARB → chạy intl_utils:generate"$'\n'; break; }
done

for m in $(printf '%s\n' "$changed" | grep -E '^lib/src/models/.*\.dart$' | grep -vE '\.g\.dart$'); do
  g="${m%.dart}.g.dart"
  grep -q "part '.*\.g\.dart'" "$m" 2>/dev/null && { [ ! -f "$g" ] || newer "$m" "$g"; } && { msgs+="- $g thiếu/cũ hơn model → chạy build_runner"$'\n'; break; }
done

code_files=$(printf '%s\n' "$changed" | grep -E '\.(dart|arb|yaml|sql|ts|js)$')
[ -n "$code_files" ] && { rules=$(HARNESS_DIFF=HEAD bash "$here/check.sh" $code_files) || msgs+="$rules"$'\n'; }

if printf '%s\n' "$status" | grep -qE '^( ?D|D |R ) *lib/|^R.* lib/'; then
  docs=$(bash "$here/docs-check.sh") || msgs+="$docs"$'\n'
else
  md_files=$(printf '%s\n' "$changed" | grep -E '\.md$')
  [ -n "$md_files" ] && { docs=$(bash "$here/docs-check.sh" $md_files) || msgs+="$docs"$'\n'; }
fi

if [ -n "$(printf '%s\n' "$code_files" | grep -E '\.(dart|yaml)$')" ]; then
  case "$disabled" in *analyze*) ;; *)
    flutter_cmd="flutter"
    command -v fvm >/dev/null 2>&1 && flutter_cmd="fvm flutter"
    if ! out=$($flutter_cmd analyze --no-pub 2>&1); then
      issues=$(printf '%s\n' "$out" | grep -E '^\s*(error|warning|info) ' | head -20)
      msgs+="- flutter analyze FAIL:"$'\n'"${issues:-$(printf '%s\n' "$out" | tail -15)}"$'\n'
    fi ;;
  esac
fi

if [ -z "$msgs" ]; then
  printf '%s' "$sig" > "$stamp"
  exit 0
fi
printf 'Chưa xong — harness verify:\n%s' "$msgs" >&2
exit 2
