#!/usr/bin/env bash
# Golden test cho engine + hooks. Usage: bash run.sh        (so với expected/)
#                                        UPDATE=1 bash run.sh (ghi lại expected/ — chỉ khi output đổi có chủ đích)
# Dựng repo tạm: commit fixture/base, chép fixture/change đè lên, rồi chạy check, docs-check và hooks.
here=$(cd "$(dirname "$0")" && pwd)
check=${CHECK:-$here/../check.sh}
docs=${DOCS:-$here/../docs-check.sh}
hooks=$here/../../hooks
tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT

cp -r "$here/fixture/base/." "$tmp/"
cd "$tmp" || exit 1
git init -q && git config core.autocrlf false && git add -A && git -c user.name=t -c user.email=t@t commit -qm base
cp -r "$here/fixture/change/." "$tmp/"
git add -N .
export CLAUDE_PROJECT_DIR="$tmp"

hook_input() { printf '{"file_path": "%s"}' "$(printf '%s' "$1" | sed 's/\\/\\\\/g')"; }
run() { echo "\$ $1"; eval "$2" 2>&1; echo "exit=$?"; }
actual=$(
  run "check (full)"          "bash '$check'"
  run "check (diff HEAD)"     "HARNESS_DIFF=HEAD bash '$check' \$(git diff --name-only HEAD)"
  run "check (absolute path)" "HARNESS_DIFF=HEAD bash '$check' '$tmp/lib/src/models/user.dart'"
  mkdir -p .claude; echo 'HARNESS_DISABLE=null_assert comment arb_sync' > .claude/harness.env
  run "check (disabled rules)" "HARNESS_DIFF=HEAD bash '$check' lib/src/pages/home/home_page.dart lib/l10n/intl_en.arb"
  rm -rf .claude
  run "docs-check"            "bash '$docs'"
  [ -n "$CHECK" ] && exit 0  # so với engine cũ: chỉ phần check/docs
  native=$(cygpath -w "$tmp" 2>/dev/null || echo "$tmp")
  run "pre_edit (generated, native path)" "hook_input '$native/lib/router/app_router.gr.dart' | bash '$hooks/pre_edit.sh'"
  run "pre_edit (source)"     "hook_input '$tmp/lib/src/models/user.dart' | bash '$hooks/pre_edit.sh'"
  mkdir -p .claude; echo 'HARNESS_DISABLE=analyze squawk' > .claude/harness.env
  run "stop_verify"           "echo '{}' | bash '$hooks/stop_verify.sh'"
  run "stop_verify (active)"  "echo '{\"stop_hook_active\": true}' | bash '$hooks/stop_verify.sh'"
)
mixed=$(cygpath -m "$tmp" 2>/dev/null || echo "$tmp")
actual=$(printf '%s\n' "$actual" | sed -e "s|$mixed|<tmp>|g" -e "s|$tmp|<tmp>|g")

expected="$here/expected/output.txt"
if [ -n "$UPDATE" ]; then printf '%s\n' "$actual" > "$expected"; echo "updated $expected"; exit 0; fi
if diff <(printf '%s\n' "$actual") "$expected"; then echo "PASS"; else echo "FAIL (diff: actual < > expected)"; exit 1; fi
