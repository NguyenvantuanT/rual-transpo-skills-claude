#!/usr/bin/env bash
# PreToolUse(Bash): chặn đường vòng qua pre_edit (ghi file generated bằng shell) và hỏi user trước lệnh mất việc / bỏ qua kiểm tra.
input=$(cat)
. "$(dirname "$0")/../engine/lib.sh"
harness_on || exit 0
cmd=$(printf '%s' "$input" | sed -nE 's/.*"command"[[:space:]]*:[[:space:]]*"(([^"\\]|\\.)*)".*/\1/p' | head -1)
[ -n "$cmd" ] || exit 0

decide() {  # decide <ask|deny> <lý do — không chứa " hoặc \>
  printf '{"hookSpecificOutput":{"hookEventName":"PreToolUse","permissionDecision":"%s","permissionDecisionReason":"Harness: %s"}}\n' "$1" "$2"
  exit 0
}

if printf '%s' "$cmd" | grep -qE '(sed|perl)[[:space:]]+-[a-zA-Z]*i|>|\btee\b|\b(cp|mv)[[:space:]]'; then
  for tok in $(printf '%s' "$cmd" | tr -s " \t;|&<>()'" '\n\n\n\n\n\n\n\n\n'); do
    case "$tok" in *.*|*/*) ;; *) continue ;; esac
    rel=$(relpath "$tok")
    p=$(generated_by "$rel") && decide deny "$rel là file generated, không ghi bằng shell. Sửa nguồn rồi chạy bước generate."
    [ "$rel" = .claude/harness.env ] && decide ask "lệnh ghi vào .claude/harness.env (tắt rule / đổi pack) là quyết định của team, cần user đồng ý."
  done
fi
off bash_guard && exit 0
printf '%s' "$cmd" | grep -qE -- '--no-verify\b' && decide ask "--no-verify bỏ qua git hook. Sửa lỗi hook báo thay vì bỏ qua."
printf '%s' "$cmd" | grep -qE 'git[[:space:]]+push\b.*([[:space:]]-f\b|--force\b([^-]|$))' && decide ask "push --force ghi đè lịch sử remote. Dùng --force-with-lease nếu thật sự cần."
printf '%s' "$cmd" | grep -qE 'git[[:space:]]+(reset[[:space:]]+--hard|clean[[:space:]]+-[a-zA-Z]*f|checkout[[:space:]]+--[[:space:]]+\.|restore[[:space:]]+\.)' && decide ask "lệnh này xoá thay đổi chưa commit, không lấy lại được."
exit 0
