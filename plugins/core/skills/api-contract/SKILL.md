---
name: api-contract
description: Hợp đồng API giữa client và server, không phụ thuộc stack — đặt tên resource/field, format lỗi chung, phân trang, ngày giờ/tiền trong JSON, idempotency key, versioning và thay đổi tương thích ngược, OpenAPI là nguồn chuẩn. Dùng khi thiết kế endpoint mới, đổi response, hoặc client (web/mobile) và BE lệch nhau.
---

# API contract

Hợp đồng là thứ client đã build theo. Đổi nó thì mọi app đang chạy (kể cả bản mobile cũ chưa update) bị ảnh hưởng.

## Quy ước

| Mục | Quy ước |
|---|---|
| URL | Danh từ số nhiều, kebab-case: `/order-items/:id`. Hành động: `POST /orders/:id/cancel` |
| Field JSON | `camelCase`, thống nhất toàn API |
| ID | String (UUID/ULID), không lộ id tăng dần nếu enumerate được là rủi ro |
| Thời gian | ISO 8601 UTC có `Z`: `"2026-11-03T08:00:00Z"`. Ngày không giờ: `"2026-11-03"` |
| Tiền | `{ "amount": "125000.00", "currency": "VND" }`: amount là string thập phân hoặc số nguyên đơn vị nhỏ nhất. Không float |
| Enum | `UPPER_SNAKE` string; client phải xử lý giá trị lạ (fallback) |
| Null | Field không có giá trị: `null` hoặc bỏ hẳn; thống nhất 1 cách |

## Lỗi

```json
{ "statusCode": 409, "code": "ORDER_ALREADY_PAID", "message": "Đơn đã thanh toán",
  "details": [{ "field": "items[0].qty", "code": "MIN", "message": "..." }], "requestId": "..." }
```

- Client xử lý theo `code` (ổn định), không theo `message` (có thể đổi/dịch).
- 400 dữ liệu sai · 401 chưa đăng nhập · 403 không có quyền · 404 không có (hoặc giấu sự tồn tại) · 409 xung đột trạng thái · 422 vi phạm nghiệp vụ · 429 quá giới hạn · 5xx lỗi server.

## Danh sách

`GET /orders?limit=20&cursor=...&status=PAID&sort=-createdAt` → `{ "data": [...], "nextCursor": "..." | null }`. `limit` có giá trị tối đa. Cursor cho dữ liệu lớn/thay đổi nhiều; page/offset chỉ khi cần nhảy trang.

## Ghi an toàn

- `POST` tạo tài nguyên/thanh toán nhận header `Idempotency-Key`; gọi lại cùng key → trả kết quả cũ, không tạo trùng. Client mobile retry khi mạng chập chờn nên bắt buộc với thao tác tiền.
- Cập nhật đồng thời: `version`/`updatedAt` trong body hoặc `If-Match` → 409 khi lệch.

## Thay đổi tương thích

| Không phá (làm tự do) | Phá (cần version mới hoặc hỏi user) |
|---|---|
| Thêm endpoint, thêm field response, thêm field request **không bắt buộc**, thêm giá trị enum (khi client đã có fallback) | Xoá/đổi tên field, đổi type, field tuỳ chọn thành bắt buộc, đổi ý nghĩa, đổi mã lỗi |

- Breaking → `/v2` hoặc thêm field mới song song, đánh dấu field cũ `deprecated` và giữ đến khi bản app cũ hết dùng.
- OpenAPI (hoặc schema chung zod/proto) là nguồn chuẩn; client sinh type từ đó. Đổi API mà không cập nhật spec trong cùng PR là chưa xong.

## Checklist

- [ ] Field, thời gian, tiền đúng quy ước; lỗi có `code` ổn định
- [ ] Danh sách có phân trang + giới hạn
- [ ] Thao tác tiền/tạo quan trọng có idempotency
- [ ] Không có breaking change ngầm; spec đã cập nhật
