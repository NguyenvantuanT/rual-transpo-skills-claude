# Pack supabase — migration SQL, RLS, edge function. Không phụ thuộc app là Flutter hay web. Hợp đồng: ../README.md
supabase_markers="supabase"
supabase_files="supabase/*.sql supabase/functions/*.ts supabase/functions/*.js"

supabase_rules() {
  case "$rel" in
    supabase/*.sql)
      case "$disabled" in *" sb_view_invoker "*) ;; *)
        local hits
        hits=$(awk 'BEGIN{IGNORECASE=1} { l=tolower($0) }
                    l ~ /create (or replace )?view/ { start=NR; buf="" }
                    start { buf = buf " " l; if (buf ~ /[^a-z_]as[ \t]*(\(|select|$)/ || l ~ /;/) { if (buf !~ /security_invoker/) print start ": " $0; start=0 } }' "$file" \
               | only_added | head -5)
        [ -n "$hits" ] && msgs+="- [sb_view_invoker] View thiếu security_invoker → chạy quyền owner, vượt RLS. Sửa: \`CREATE VIEW v WITH (security_invoker = true) AS …\`"$'\n'"$hits"$'\n' ;;
      esac
      GI=-i flag sb_check_uid_only 'with check[[:space:]]*\([[:space:]]*\(?[[:space:]]*auth\.uid\(\)[[:space:]]*=[[:space:]]*[a-z_.]+[[:space:]]*\)?[[:space:]]*\)' '`WITH CHECK` chỉ so `auth.uid() = user_id` → kiểm tra cả quyền sở hữu FK liên quan (thật sự N/A: thêm `-- security: fk-not-applicable` cùng dòng)' '' 'fk-not-applicable'
      flag sb_secret 'sk_live_[0-9A-Za-z]{10,}|sk-ant-[A-Za-z0-9_-]{10,}|eyJ[A-Za-z0-9_-]{15,}\.eyJ[A-Za-z0-9_-]{15,}' 'Secret hard-code trong SQL → dùng Vault / secret, không commit key'
      ;;

    supabase/functions/*.ts|supabase/functions/*.js)
      GI=-i flag sb_cors_wildcard 'access-control-allow-origin["'"'"']?[[:space:]]*[:,][[:space:]]*["'"'"']\*' 'CORS `*` → giới hạn origin cụ thể (bắt buộc với endpoint admin/mutation)'
      flag sb_secret 'sk_live_[0-9A-Za-z]{10,}|sk-ant-[A-Za-z0-9_-]{10,}|sk-(proj-)?[A-Za-z0-9]{20,}|eyJ[A-Za-z0-9_-]{15,}\.eyJ[A-Za-z0-9_-]{15,}' 'Secret hard-code → `Deno.env.get(...)` + `supabase secrets set`'
      ;;
  esac
}

# T1: squawk (lint migration không an toàn: khoá bảng, đổi kiểu cột, NOT NULL không default...) nếu máy có cài.
supabase_verify() {
  case "$disabled" in *" squawk "*) return 0 ;; esac
  command -v squawk >/dev/null 2>&1 || return 0
  local sql out
  sql=$(printf '%s\n' "$changed" | grep -E '^supabase/migrations/.*\.sql$' | while read -r f; do [ -f "$f" ] && echo "$f"; done)
  [ -n "$sql" ] || return 0
  out=$(squawk $sql 2>&1) || msgs+="- [squawk] Migration không an toàn khi chạy trên DB thật → sửa theo gợi ý (tắt: HARNESS_DISABLE=squawk):"$'\n'"$(printf '%s\n' "$out" | head -20)"$'\n'
}
