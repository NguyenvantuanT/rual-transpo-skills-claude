#!/usr/bin/env bash
file=$(grep -o '"file_path"[[:space:]]*:[[:space:]]*"[^"]*"' | head -1 | sed -E 's/.*:[[:space:]]*"//; s/"$//; s/\\+/\//g')
[ -n "$file" ] || exit 0
. "$(dirname "$0")/../engine/lib.sh"
p=$(generated_by "$(relpath "$file")") || exit 0
eval "msg=\$${p}_generated_msg"
echo "BLOCKED: $file là file generated. ${msg:-Sửa nguồn rồi chạy lại bước generate.}" >&2
exit 2
