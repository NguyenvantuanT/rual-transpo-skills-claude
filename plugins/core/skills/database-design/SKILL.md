---
name: database-design
description: Thiết kế cơ sở dữ liệu quan hệ (Postgres/MySQL), không phụ thuộc ORM — khoá chính, khoá ngoại, ràng buộc, index, kiểu dữ liệu cho tiền/thời gian, soft delete, multi-tenant, migration không downtime. Dùng khi thêm bảng/cột, đổi schema, viết migration, hoặc query chậm.
---

# Database design

Ràng buộc trong DB là lớp phòng thủ cuối cùng: code có bug thì DB vẫn chặn dữ liệu sai.

## Bảng và cột

- Khoá chính: UUID (v7/ULID nếu cần sắp theo thời gian) hoặc `bigint identity`. Mọi bảng có `created_at`, `updated_at` (`timestamptz`).
- Tên: `snake_case`, bảng số nhiều (`order_items`), khoá ngoại `<bảng số ít>_id`.
- Kiểu:
  - Tiền: `numeric(18,2)` hoặc `bigint` đơn vị nhỏ nhất + cột `currency`. Không `float`/`double`.
  - Thời điểm: `timestamptz` (lưu UTC). Ngày lịch (sinh nhật, ngày lễ): `date`.
  - Trạng thái: enum hoặc `text` + `CHECK`. Dữ liệu bán cấu trúc: `jsonb`, nhưng field cần lọc/join thì tách cột.
- `NOT NULL` là mặc định; chỉ cho null khi "không có" là trạng thái có nghĩa.

## Ràng buộc

- Khoá ngoại cho mọi quan hệ, chọn `ON DELETE` có chủ ý (`RESTRICT` mặc định; `CASCADE` chỉ cho dữ liệu con thuần tuý).
- `UNIQUE` cho bất biến nghiệp vụ (email theo tenant, mã đơn). Đừng chỉ kiểm trong code (race condition).
- `CHECK` cho miền giá trị (`qty > 0`, `amount >= 0`).

## Index

- Index khoá ngoại và cột trong `WHERE`/`ORDER BY` của query thường dùng. Index nhiều cột: cột lọc bằng `=` đứng trước, cột range/sort đứng sau.
- Unique một phần: `UNIQUE (email) WHERE deleted_at IS NULL`.
- Kiểm bằng `EXPLAIN ANALYZE` trên dữ liệu đủ lớn; không thêm index đoán mò (mỗi index làm chậm ghi).

## Mẫu thường gặp

| Nhu cầu | Cách |
|---|---|
| Xoá mềm | `deleted_at timestamptz null` + mọi query lọc + unique một phần. Không cần thì xoá cứng |
| Multi-tenant | Cột `tenant_id` trên mọi bảng nghiệp vụ, có trong mọi index/unique, lọc ở mọi query (hoặc RLS) |
| Lịch sử/audit | Bảng `<x>_events` chỉ thêm, không sửa |
| Nhiều-nhiều | Bảng nối có khoá chính kép hoặc unique (a_id, b_id) |
| Đếm/tổng hiển thị nhiều | Tính khi đọc trước; chỉ denormalize khi đo thấy chậm, và cập nhật trong cùng transaction |

## Migration không downtime

Expand → migrate → contract:
1. Thêm cột mới (nullable hoặc có default), code ghi cả 2 cột.
2. Backfill theo lô.
3. Code chỉ đọc cột mới; thêm `NOT NULL`/ràng buộc.
4. Release sau: xoá cột cũ.

- Bảng lớn: `CREATE INDEX CONCURRENTLY` (Postgres), tránh lệnh khoá bảng lâu.
- Migration đã chạy trên môi trường chung thì không sửa, tạo migration mới.
- Xoá/đổi tên cột, đổi type → dừng, hỏi user.

## Checklist

- [ ] Kiểu tiền/thời gian đúng; `NOT NULL` + FK + UNIQUE + CHECK đủ
- [ ] Index cho FK và query chính; đã xem `EXPLAIN` nếu bảng lớn
- [ ] Multi-tenant: `tenant_id` có mặt ở mọi nơi cần
- [ ] Migration chia bước nếu bảng đang có dữ liệu
