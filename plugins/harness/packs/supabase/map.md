### Supabase

- Schema ở `supabase/migrations/` là nguồn sự thật — sửa schema = thêm file migration mới `<version>_<tên>.sql`, áp lên project cùng version. Không sửa migration cũ, không sửa schema trên dashboard.
- Cấu hình máy (URL + publishable key) để ở file gitignore (`.env`, `supabase.cfg`...), commit file mẫu (`.env.example`, `supabase.example.cfg`). Không bao giờ commit service_role / secret key.
- Có CLI: `supabase start` · reset + chạy lại migration: `supabase db reset` · test RLS (pgTAP): `supabase test db` · migration mới: `supabase migration new <tên>`. Không có CLI: dùng MCP `apply_migration` rồi ghi file theo `list_migrations`.

| Việc | Skill |
|---|---|
| Đổi schema (bảng, cột, RLS, grant, function, trigger) | `supabase-migrations` |
| Sửa `supabase/` (SQL, RLS, view, trigger, edge function) | `supabase-security-review` |
| App Flutter gọi Supabase: query, RPC, realtime, optimistic update | `flutter-supabase-queries` |
