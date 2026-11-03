# Pack web_ts — web/Node viết bằng TypeScript. Hợp đồng: ../README.md
# Luật T0 chỉ giữ thứ eslint mặc định hay bỏ sót; phần còn lại giao cho tsc / eslint / dependency-cruiser của dự án ở T1.
web_ts_markers="tsconfig.json"
web_ts_files="*.ts *.tsx"
web_ts_generated='(^|/)(dist|build|\.next|coverage)/|\.gen\.tsx?$|\.d\.ts$'
web_ts_generated_msg="Sửa source rồi build / chạy lại bước generate của dự án."

web_ts_rules() {
  case "$rel" in
    supabase/*|node_modules/*) ;;  # edge function Deno thuộc pack supabase
    *.ts|*.tsx)
      flag ts_any '(:|\bas|<)[[:space:]]*any\b' '`any` → khai báo type cụ thể, hoặc `unknown` rồi narrow (zod/type guard ở biên)' '(^|/)(test|tests|__tests__)/|\.(test|spec)\.tsx?$'
      flag ts_ignore '@ts-ignore' '`@ts-ignore` → sửa type; bất khả kháng thì `@ts-expect-error <lý do>` (tự báo khi hết lỗi)'
      flag console_log '\bconsole\.log\(' '`console.log` → xoá, hoặc dùng logger của dự án' '(^|/)(scripts|test|tests|__tests__)/|\.(test|spec)\.tsx?$'
      ;;
  esac
}

# T1: công cụ của chính dự án, chỉ khi đã cài (node_modules/.bin). Chậm hoặc không có → bỏ qua, không báo lỗi.
web_ts_verify() {
  local ts bin out
  ts=$(printf '%s\n' "$changed" | grep -E '\.tsx?$' | grep -vE '^(supabase|node_modules)/' | while read -r f; do [ -f "$f" ] && echo "$f"; done)
  [ -n "$ts" ] || return 0
  bin=node_modules/.bin
  case "$disabled" in *" tsc "*) ;; *)
    if [ -x "$bin/tsc" ] && ! out=$("$bin/tsc" --noEmit -p . 2>&1); then
      msgs+="- [tsc] Type error → sửa type, không dùng any/@ts-ignore:"$'\n'"$(printf '%s\n' "$out" | grep -E 'error TS' | head -20)"$'\n'
    fi ;;
  esac
  case "$disabled" in *" eslint "*) ;; *)
    if [ -x "$bin/eslint" ] && ! out=$("$bin/eslint" --no-warn-ignored $ts 2>&1); then
      msgs+="- [eslint] Sửa theo rule được báo (đừng thêm eslint-disable nếu không ghi lý do):"$'\n'"$(printf '%s\n' "$out" | head -20)"$'\n'
    fi ;;
  esac
  case "$disabled" in *" depcruise "*) ;; *)
    local cfg
    cfg=$(ls .dependency-cruiser.js .dependency-cruiser.cjs .dependency-cruiser.json 2>/dev/null | head -1)
    if [ -n "$cfg" ] && [ -x "$bin/depcruise" ] && ! out=$("$bin/depcruise" --config "$cfg" $ts 2>&1); then
      msgs+="- [depcruise] Sai hướng phụ thuộc giữa layer → đổi import theo comment của rule:"$'\n'"$(printf '%s\n' "$out" | head -20)"$'\n'
    fi ;;
  esac
}

# T1 test — runner của dự án, chỉ test liên quan tới file đổi. Không có vitest/jest → bỏ qua.
web_ts_test() {
  local ts bin=node_modules/.bin out
  ts=$(printf '%s\n' "$changed" | grep -E '\.(ts|tsx|js|jsx)$' | grep -vE '^(supabase|node_modules)/' | while read -r f; do [ -f "$f" ] && echo "$f"; done)
  [ -n "$ts" ] || return 0
  if [ -x "$bin/vitest" ]; then out=$("$bin/vitest" related --run --passWithNoTests $ts 2>&1)
  elif [ -x "$bin/jest" ]; then out=$("$bin/jest" --findRelatedTests --passWithNoTests $ts 2>&1)
  else return 0; fi \
    || msgs+="- [test] Test liên quan FAIL → sửa code (không sửa test cho xanh trừ khi test sai, ghi lý do):"$'\n'"$(printf '%s\n' "$out" | tail -30)"$'\n'
}
