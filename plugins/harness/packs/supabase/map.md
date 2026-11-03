### Supabase

- Local: `supabase start` · reset + chạy lại migration: `supabase db reset` · test RLS (pgTAP): `supabase test db`
- Migration mới: `supabase migration new <tên>` — không sửa migration đã chạy trên môi trường thật.

| Việc | Skill |
|---|---|
| Sửa `supabase/` (SQL, RLS, view, trigger, edge function) | `supabase-security-review` |
| App Flutter gọi Supabase: query, RPC, realtime, optimistic update | `flutter-supabase-queries` |
