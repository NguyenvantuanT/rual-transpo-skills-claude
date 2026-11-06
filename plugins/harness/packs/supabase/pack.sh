# Pack supabase — migration SQL, RLS, edge function. Không phụ thuộc app là Flutter hay web. Hợp đồng: ../README.md
supabase_markers="supabase supabase.example.cfg"
supabase_files="supabase/*.sql supabase/config.toml supabase/functions/*.ts supabase/functions/*.js supabase.example.cfg .env.example"
supabase_skills='^supabase/migrations/=supabase-migrations supabase-security-review
^supabase/=supabase-security-review
^lib/.*_queries\.dart$=flutter-supabase-queries'
# Dấu hiệu app gọi Supabase dù repo chưa có thư mục supabase/ (vd game Godot gọi REST thẳng).
supabase_signal='SUPABASE_URL|/(rest|auth)/v1/|@supabase/supabase-js|supabase_flutter'

# Không có supabase/: bật pack ở root app (của pack khác đã bật) sâu nhất chứa file có dấu hiệu, không có thì root repo.
# .env* bị gitignore nên grep riêng.
# shortcut: git grep chạy ở mỗi hook khi repo không có supabase/ — repo rất lớn thấy chậm thì cache theo HEAD.
supabase_detect() {
  local apps; apps=$(printf '%s' "$roots" | awk '$2 != "." { print $2 }' | sort -u)
  { grep -lsE "$supabase_signal" .env* */.env* 2>/dev/null
    git grep -lIE "$supabase_signal" -- . ':!*.md' 2>/dev/null; } \
  | while IFS= read -r f; do
      local best=. d
      for d in $apps; do case "$f" in "$d"/*) { [ ${#d} -gt ${#best} ] || [ "$best" = . ]; } && best=$d ;; esac; done
      echo "$best"
    done | sort -u
}

supabase_rules() {
  # Trạng thái repo, không theo dòng mới: dùng Supabase mà không có migration nào → schema chỉ nằm trên server. Báo 1 lần mỗi lần chạy.
  case "$disabled $sb_migrations_seen" in *" sb_migrations "*|*seen) ;; *)
    local proot=${rpath%"$rel"} hit=""
    if ! compgen -G "${proot}supabase/migrations/*.sql" >/dev/null && ! compgen -G "supabase/migrations/*.sql" >/dev/null; then
      case "$rel" in supabase/*) hit="(file trong supabase/)" ;; *) hit=$(grep -nE "$supabase_signal" "$file" | head -1) ;; esac
    fi
    [ -n "$hit" ] && { sb_migrations_seen=seen
      msgs+="- [sb_migrations] Dùng Supabase nhưng repo không có \`${proot}supabase/migrations/*.sql\` → schema chỉ nằm trên server, không ai review được. Lấy danh sách bằng MCP \`list_migrations\` (hoặc \`supabase db pull\`), ghi mỗi migration ra \`supabase/migrations/<version>_<tên>.sql\` trùng version + đúng SQL đã áp. Xem skill \`supabase-migrations\`"$'\n'"$hit"$'\n'; } ;;
  esac

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
