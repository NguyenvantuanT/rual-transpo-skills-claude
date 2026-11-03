#!/usr/bin/env bash
# Doc-drift check. Usage: docs-check.sh [doc.md...]   (no args = CLAUDE.md, AGENTS.md, ARCHITECTURE.md, docs/**/*.md)
# Run from the app repo root. Exit 1 when a doc points at a path that no longer exists, or the entry doc stops being a short map.
root=$(printf '%s' "${CLAUDE_PROJECT_DIR:-$PWD}" | sed -E 's/\\+/\//g')
cd "$root" || exit 0
max_entry=$(grep -E '^HARNESS_MAX_ENTRY_LINES=' .claude/harness.env 2>/dev/null | tail -1 | cut -d= -f2- | tr -d "\"'\r")
max_entry=${max_entry:-150}

if [ $# -eq 0 ]; then
  set -- $(ls CLAUDE.md .claude/CLAUDE.md AGENTS.md ARCHITECTURE.md 2>/dev/null) $(git ls-files 'docs/*.md' 2>/dev/null)
fi

out=""
for doc in "$@"; do
  doc=$(printf '%s' "$doc" | sed -E 's/\\+/\//g')
  [ -f "$doc" ] || continue
  rel="${doc#"$root"/}"
  case "$rel" in docs/generated/*|docs/references/*|docs/exec-plans/completed/*) continue ;; esac
  msgs=""

  missing=$(grep -noE '`(lib|test|integration_test|docs|android|ios|assets|tool)/[^`]+`' "$doc" \
    | tr -d '`' | while IFS=: read -r line path; do
        case "$path" in *'<'*|*'*'*|*' '*|*'{'*|*'...'*) continue ;; esac
        path="${path%%#*}"; path="${path%/}"
        [ -e "$path" ] || printf '%s:%s\n' "$line" "$path"
      done)
  [ -n "$missing" ] && msgs+="- [doc_stale_path] Đường dẫn không còn tồn tại → sửa doc theo code thật (hoặc xoá dòng):"$'\n'"$missing"$'\n'

  case "$rel" in CLAUDE.md|.claude/CLAUDE.md|AGENTS.md)
    n=$(wc -l < "$doc")
    [ "$n" -gt "$max_entry" ] && msgs+="- [doc_entry_size] $n dòng > $max_entry → CLAUDE.md là mục lục: chuyển chi tiết sang docs/*.md, giữ lại 1 dòng trỏ tới" ;;
  esac

  [ -n "$msgs" ] && out+="$rel:"$'\n'"$msgs"
done

[ -z "$out" ] && exit 0
printf '%s' "$out"
exit 1
