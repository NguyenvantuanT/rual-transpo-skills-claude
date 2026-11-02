---
name: supabase-security-review
description: Review bảo mật thay đổi Supabase (migration SQL, RLS policy, view, trigger, edge function) trước khi commit — rule máy trong check.sh + checklist tay. Dùng khi sửa supabase/ hoặc user nói check RLS, security review migration, review supabase.
---

# Supabase security review

Phỏng theo `supabase-security-review` của BOW Skills (MIT) — xem `THIRD_PARTY_NOTICES.md`.

## 1. Rule máy (`check.sh`, chạy tự động qua hook + CI)

| Rule id | Bắt gì | Sửa |
|---|---|---|
| `sb_view_invoker` | `CREATE VIEW` thiếu `security_invoker` → view chạy quyền owner, vượt RLS | `CREATE VIEW v WITH (security_invoker = true) AS …` |
| `sb_cors_wildcard` | Edge function trả `Access-Control-Allow-Origin: *` | Giới hạn origin cụ thể (bắt buộc với endpoint admin/mutation) |
| `sb_secret` | Hard-code Stripe live key, service-role JWT, OpenAI/Anthropic key | Đưa vào secret của Supabase / CI, đọc qua env |
| `sb_check_uid_only` | `WITH CHECK (auth.uid() = user_id)` mà không kiểm tra FK liên quan | Kiểm tra quyền sở hữu mọi FK; thật sự N/A thì thêm `-- security: fk-not-applicable` cùng dòng |

Chạy tay toàn bộ: `bash <plugin>/scripts/check.sh $(git ls-files 'supabase/*')`.

## 2. Checklist tay (máy không thấy)

**RLS**
- INSERT/UPDATE `WITH CHECK` xác minh quyền sở hữu của **mọi** FK, không chỉ `user_id`.
- Tiền / giảm giá không lấy từ client — ép server-side hoặc `CHECK` constraint.
- Không nới rộng phạm vi SELECT ngoài ý muốn; policy đọc của owner vẫn giữ.

**Trigger**
- `SECURITY DEFINER` → đi kèm INSERT policy chặt trên bảng đó.
- Trigger đếm đối xứng: tăng khi INSERT, giảm khi DELETE/UPDATE, tính cả `ON DELETE CASCADE`.

**Edge function**
- Side-effect sau mutation (log, notification) bọc `try/catch` để lỗi phụ không phá giao dịch chính.

**SQL**
- Không có mệnh đề vô nghĩa (`WHERE created_at < now()`).
- Backfill cập nhật đủ bộ cột liên quan (set `reviewed_by` thì set cả `reviewed_at`).

## 3. Report

Mỗi mục: `[✓/✗/N/A] <rule> <file:line> — ghi chú`. Kết luận: sạch, hoặc danh sách lỗi chặn commit.
