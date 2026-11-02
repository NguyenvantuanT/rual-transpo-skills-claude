#!/usr/bin/env bash
file=$(grep -o '"file_path"[[:space:]]*:[[:space:]]*"[^"]*"' | head -1 | sed -E 's/.*:[[:space:]]*"//; s/"$//; s/\\+/\//g')

case "$file" in
  *.gr.dart|*.g.dart|*.freezed.dart|*/lib/src/gen/*|*/lib/src/generated/*)
    echo "BLOCKED: $file là file generated. Sửa nguồn (app_router.dart / @RoutePage / ARB / assets) rồi chạy build_runner hoặc intl_utils:generate." >&2
    exit 2 ;;
esac
exit 0
