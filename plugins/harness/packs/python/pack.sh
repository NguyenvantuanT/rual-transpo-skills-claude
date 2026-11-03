# Pack python — BE Python (FastAPI, Django, Flask, worker...). Hợp đồng: ../README.md
# T0 chỉ giữ lỗi agent hay mắc mà ruff mặc định không bật; còn lại giao cho ruff / mypy / pyright của dự án ở T1.
python_markers="pyproject.toml requirements.txt setup.py Pipfile"
python_files="*.py"
python_generated='(^|/)(\.venv|venv|__pycache__|build|dist|\.tox)/|_pb2(_grpc)?\.pyi?$'
python_generated_msg="Sửa file .proto / nguồn rồi chạy lại bước generate (protoc, ...)."
python_skills=''

python_rules() {
  case "$rel" in
    *.py)
      local tests='(^|/)(tests?|testing)/|(^|/)(test_[^/]*|[^/]*_test|conftest)\.py$'
      flag py_bare_except '^[[:space:]]*except[[:space:]]*:' '`except:` bắt cả KeyboardInterrupt/SystemExit → `except <LỗiCụThể> as e:`, log rồi raise lại nếu không xử lý được'
      flag py_swallow '^[[:space:]]*except[[:space:]]+(Exception|BaseException)[^:]*:[[:space:]]*pass' 'Nuốt lỗi im lặng → log (`logger.exception`) hoặc raise lỗi domain'
      flag py_print '^[[:space:]]*print\(' '`print` trong code app → `logger = logging.getLogger(__name__)`' "$tests|(^|/)(scripts|cli|manage\\.py)"
      flag py_debugger 'breakpoint\(\)|pdb\.set_trace\(|import i?pdb' 'Debugger còn sót → xoá'
      flag py_type_ignore '#[[:space:]]*type:[[:space:]]*ignore[[:space:]]*$' '`# type: ignore` trần → sửa type; bất khả kháng thì `# type: ignore[<code>]  # <lý do>`'
      flag py_sql_fstring '(execute|executemany|raw|text)\([[:space:]]*f["'"'"']' 'SQL dựng bằng f-string → SQL injection. Dùng tham số: `execute("... WHERE id = %s", (id,))` / `text("... :id").bindparams(id=id)`'
      flag py_secret "$HARNESS_SECRET_RE" 'Secret hard-code → đọc từ env (`os.environ[...]` / pydantic-settings), không commit key'
      ;;
  esac
}

# T1: ruff (lint + format check), mypy hoặc pyright nếu dự án có cấu hình.
python_verify() {
  local py bin out
  py=$(printf '%s\n' "$changed" | grep -E '\.py$' | while read -r f; do [ -f "$f" ] && echo "$f"; done)
  [ -n "$py" ] || return 0
  if ! off ruff && bin=$(tool ruff); then
    out=$("$bin" check --quiet $py 2>&1) || msgs+="- [ruff] Sửa theo rule được báo (\`ruff check --fix\` cho lỗi tự sửa được; đừng thêm noqa nếu không ghi lý do):"$'\n'"$(printf '%s\n' "$out" | head -20)"$'\n'
    out=$("$bin" format --check $py 2>&1) || msgs+="- [ruff] Chưa format → chạy \`ruff format\` cho file đổi"$'\n'
  fi
  if ! off typecheck; then
    if grep -qs '\[tool\.mypy\]' pyproject.toml || [ -f mypy.ini ]; then
      bin=$(tool mypy) && { out=$("$bin" $py 2>&1) || msgs+="- [typecheck] mypy FAIL → sửa type, không thêm \`type: ignore\` trần:"$'\n'"$(printf '%s\n' "$out" | grep -E 'error:' | head -20)"$'\n'; }
    elif grep -qs '\[tool\.pyright\]' pyproject.toml || [ -f pyrightconfig.json ]; then
      bin=$(tool pyright) && { out=$("$bin" $py 2>&1) || msgs+="- [typecheck] pyright FAIL → sửa type:"$'\n'"$(printf '%s\n' "$out" | grep -E 'error' | head -20)"$'\n'; }
    fi
  fi
  return 0
}

# T1 test: pytest cho file test đổi + test_<tên>.py / <tên>_test.py của module đổi.
python_test() {
  local bin f tests="" out
  bin=$(tool pytest) || return 0
  for f in $(printf '%s\n' "$changed" | grep -E '\.py$'); do
    case "$(basename "$f")" in
      test_*.py|*_test.py) [ -f "$f" ] && tests+="$f"$'\n' ;;
      conftest.py|__init__.py) ;;
      *) b=$(basename "$f" .py); tests+="$(find . -path ./.venv -prune -o -path ./venv -prune -o \( -name "test_$b.py" -o -name "${b}_test.py" \) -print 2>/dev/null | sed 's#^\./##')"$'\n' ;;
    esac
  done
  tests=$(printf '%s' "$tests" | grep -v '^$' | sort -u | head -30)
  [ -n "$tests" ] || return 0
  out=$("$bin" -q -x $tests 2>&1) || msgs+="- [test] pytest FAIL → sửa code (không sửa test cho xanh trừ khi test sai, ghi lý do):"$'\n'"$(printf '%s\n' "$out" | tail -30)"$'\n'
}
