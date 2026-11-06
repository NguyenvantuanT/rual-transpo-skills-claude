#!/usr/bin/env bash
# PostToolUse MCP Supabase apply_migration: schema vừa đổi trên project remote → nhắc ghi file migration vào repo. Không chặn.
input=$(cat)
. "$(dirname "$0")/../engine/lib.sh"
off sb_migration_hint && exit 0
git rev-parse --git-dir >/dev/null 2>&1 || exit 0
name=$(printf '%s' "$input" | grep -o '"name"[[:space:]]*:[[:space:]]*"[^"]*"' | head -1 | sed -E 's/.*:[[:space:]]*"//; s/"$//' | tr -cd 'A-Za-z0-9_-')
d=$(pack_roots supabase | head -1)
dir=supabase/migrations; [ -n "$d" ] && [ "$d" != . ] && dir="$d/supabase/migrations"
[ -n "$name" ] && compgen -G "$dir/*_$name.sql" >/dev/null && exit 0
msg="Harness: apply_migration \`${name:-<tên>}\` vừa đổi schema trên project remote. Repo là nguồn sự thật của schema → ngay bây giờ: gọi \`list_migrations\` lấy version (YYYYMMDDHHMMSS) của migration này, ghi \`$dir/<version>_${name:-<tên>}.sql\` đúng SQL vừa áp (không sửa file migration cũ), commit cùng code dùng nó. (tắt: HARNESS_DISABLE=sb_migration_hint)"
printf '{"hookSpecificOutput":{"hookEventName":"PostToolUse","additionalContext":"%s"}}\n' "$msg"
