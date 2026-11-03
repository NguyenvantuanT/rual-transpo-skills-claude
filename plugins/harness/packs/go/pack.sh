# Pack go — BE Go. Hợp đồng: ../README.md
# T0: lỗi agent hay mắc mà go vet không bắt. T1: gofmt, go vet, golangci-lint (nếu có), go test theo package đổi.
go_markers="go.mod"
go_files="*.go"
go_generated='\.pb(\.gw)?\.go$|_gen\.go$|(^|/)zz_generated[^/]*\.go$|(^|/)mocks?/|(^|/)vendor/'
go_generated_msg="Sửa nguồn (.proto, interface, sqlc query...) rồi chạy \`go generate ./...\`."
go_skills=''

go_rules() {
  case "$rel" in
    *.go)
      local tests='_test\.go$'
      flag go_ignored_err '^[[:space:]]*_[[:space:]]*(,[[:space:]]*_[[:space:]]*)?=[[:space:]]*[A-Za-z_][A-Za-z0-9_.]*\(' 'Bỏ qua error bằng `_ =` → `if err := f(); err != nil { return fmt.Errorf("<ngữ cảnh>: %w", err) }`' "$tests"
      flag go_panic '\bpanic\(' '`panic` trong code thường → trả `error` cho caller (chỉ panic ở main/init khi không thể khởi động)' "$tests|(^|/)main\\.go$"
      flag go_println '\bfmt\.Print(ln|f)?\(|\blog\.Print(ln|f)?\(' 'In log thô → dùng logger có cấu trúc của dự án (`slog` / zap) với field' "$tests|(^|/)cmd/"
      flag go_bg_ctx 'context\.(Background|TODO)\(\)' 'Tạo context mới giữa request → nhận `ctx context.Context` làm tham số đầu và truyền xuống' "$tests|(^|/)(main\\.go|cmd/)"
      flag go_sql_concat '(Query|QueryRow|Exec)(Context)?\([^)]*(fmt\.Sprintf|"[^"]*"[[:space:]]*\+)' 'SQL dựng bằng Sprintf/nối chuỗi → SQL injection. Dùng placeholder `$1` / `?` + tham số'
      flag go_secret "$HARNESS_SECRET_RE" 'Secret hard-code → đọc từ env / secret manager'
      ;;
  esac
}

go_pkgs() { printf '%s\n' "$changed" | grep -E '\.go$' | while read -r f; do [ -f "$f" ] && echo "./$(dirname "$f")"; done | sort -u; }

go_verify() {
  local go_files pkgs out bin
  command -v go >/dev/null 2>&1 || return 0
  go_files=$(printf '%s\n' "$changed" | grep -E '\.go$' | while read -r f; do [ -f "$f" ] && echo "$f"; done)
  [ -n "$go_files" ] || return 0
  pkgs=$(go_pkgs)
  off gofmt || { out=$(gofmt -l $go_files 2>&1); [ -n "$out" ] && msgs+="- [gofmt] Chưa format → \`gofmt -w\`:"$'\n'"$out"$'\n'; }
  off vet || { out=$(go vet $pkgs 2>&1) || msgs+="- [vet] go vet FAIL → sửa theo báo cáo:"$'\n'"$(printf '%s\n' "$out" | head -20)"$'\n'; }
  if ! off golangci && bin=$(tool golangci-lint); then
    out=$("$bin" run $pkgs 2>&1) || msgs+="- [golangci] Sửa theo linter (đừng thêm //nolint nếu không ghi lý do):"$'\n'"$(printf '%s\n' "$out" | head -20)"$'\n'
  fi
  return 0
}

go_test() {
  local pkgs="" p out
  command -v go >/dev/null 2>&1 || return 0
  for p in $(go_pkgs); do ls "$p"/*_test.go >/dev/null 2>&1 && pkgs+=" $p"; done
  [ -n "$pkgs" ] || return 0
  out=$(go test $pkgs 2>&1) || msgs+="- [test] go test FAIL → sửa code (không sửa test cho xanh trừ khi test sai, ghi lý do):"$'\n'"$(printf '%s\n' "$out" | grep -vE '^(ok|\?)[[:space:]]' | tail -30)"$'\n'
}
