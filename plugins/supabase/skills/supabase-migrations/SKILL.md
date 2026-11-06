---
name: supabase-migrations
description: Giữ schema Supabase trong repo — mọi thay đổi DDL (bảng, cột, RLS policy, grant, function, trigger) phải có file supabase/migrations/<version>_<tên>.sql trùng version đã áp lên project, kể cả khi áp qua MCP apply_migration không có CLI. Dùng khi tạo/sửa schema, gọi apply_migration, repo thiếu migration (rule sb_migrations), hoặc cần đồng bộ repo với project remote.
---

# Supabase migrations: repo là nguồn sự thật

Cách viết SQL, RLS, CLI, debug: skill `supabase` (plugin `supabase-official`). Review bảo mật: `supabase-security-review`. Skill này chỉ lo **schema có trong repo, khớp với project**.

## Quy ước

- Mọi DDL (bảng, cột, RLS policy, grant, function, trigger, extension) có file `supabase/migrations/<version>_<snake_name>.sql`.
  `<version>` = version thật trên project (`YYYYMMDDHHMMSS`), nội dung = đúng SQL đã áp.
- Không sửa file migration cũ — sai thì thêm migration mới để sửa.
- Không sửa schema trên dashboard (Table Editor, SQL Editor). Lỡ sửa → viết lại thành migration ngay.
- DDL chỉ qua `apply_migration` (MCP) hoặc `supabase migration new` + `supabase db push` (CLI). Không chạy DDL bằng `execute_sql`: nó không ghi vào lịch sử migration.
- Commit file migration **cùng** code dùng nó.
- Cấu hình máy (URL + publishable key) để file gitignore, commit file mẫu (`.env.example` / `supabase.example.cfg`).

## Áp schema qua MCP (không có CLI local)

1. Viết SQL, review theo `supabase-security-review`.
2. `apply_migration(name: "<snake_name>", query: <SQL>)`.
3. `list_migrations` → lấy `version` của migration vừa áp.
4. Ghi `supabase/migrations/<version>_<snake_name>.sql` với đúng `<SQL>` ở bước 2. Hook harness nhắc bước 3–4 sau mỗi `apply_migration`.
5. `get_advisors` (security) → sửa cảnh báo bằng migration mới.

## Repo thiếu migration (rule `sb_migrations`) hoặc nghi lệch

1. `list_migrations` → danh sách `version` + `name` trên project.
2. So với tên file trong `supabase/migrations/`: thiếu file nào thì lấy SQL của version đó (`execute_sql`: `select statements from supabase_migrations.schema_migrations where version = '<version>'`), ghi ra `<version>_<name>.sql`.
3. File có trong repo mà project không có → chưa áp: hỏi user trước khi áp.
4. Có CLI thì thay bằng `supabase db pull` / `supabase migration list`.
5. Có thay đổi trên dashboard không nằm trong migration nào → báo user, viết migration bù sau khi user đồng ý.

## Bài học khi chạy trong VS Code

- Lệnh phá huỷ qua MCP (`drop table`, `delete`, `truncate`) bị hộp xác nhận trong panel VS Code tự từ chối. **Đừng thử lại liên tục**: đưa user đoạn SQL để chạy ở dashboard SQL Editor, rồi ghi thành migration nếu là DDL.
- Smoke test tạo tài khoản test trên Auth → email dạng `<user>+<tag>@gmail.com` (không bounce). Ghi lại các tài khoản đã tạo để user xoá, hoặc có bước dọn ở cuối.

## Xong khi

- [ ] Mỗi migration trên project (`list_migrations`) có đúng 1 file cùng version trong `supabase/migrations/`.
- [ ] Không file migration cũ nào bị sửa (`git diff --name-status` chỉ có `A` trong `supabase/migrations/`).
- [ ] `get_advisors` không còn cảnh báo security mới.
