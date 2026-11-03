---
name: nestjs-run-and-verify
description: Tự chạy và kiểm chứng API NestJS như client thật — dựng DB/Redis, migrate, chạy server, gọi endpoint bằng curl, đọc log JSON theo request id. Dùng sau khi sửa endpoint/logic để chứng minh nó chạy, hoặc khi cần tái hiện bug.
---

# NestJS run & verify

Test pass chưa đủ chứng minh API đúng. Endpoint mới/đổi phải được gọi thật ít nhất 1 lần trước khi báo xong.

## 1. Dựng môi trường

```bash
docker compose up -d db redis          # theo docker-compose.yml của repo
npx prisma migrate deploy && npx prisma db seed   # nếu repo có seed
PORT=3101 npm run start:dev > /tmp/nest.log 2>&1 &
until curl -sf localhost:3101/health/live; do sleep 1; done
```

- Dùng port riêng; xong việc thì kill đúng process mình đã mở. Không đụng DB của user ngoài DB local/dev.
- Thiếu env → đọc `.env.example`, hỏi user; không tự bịa secret.
- Không bao giờ chạy migrate/seed vào DB production hay staging.

## 2. Gọi API

```bash
TOKEN=$(curl -s localhost:3101/api/auth/login -H 'content-type: application/json' \
  -d '{"email":"dev@example.com","password":"..."}' | jq -r .accessToken)
curl -si localhost:3101/api/orders -H "authorization: Bearer $TOKEN" \
  -H 'content-type: application/json' -H 'x-request-id: verify-1' -d '{"items":[...]}'
```

Kiểm tối thiểu cho mỗi endpoint đã đổi:

| Case | Mong đợi |
|---|---|
| Hợp lệ | Status đúng (200/201/204), body khớp response DTO, không lộ field nội bộ |
| Không token | 401 |
| Token user khác / sai role | 403 hoặc 404 |
| Body sai | 400, `message` chỉ ra field sai |
| Trùng / sai trạng thái | 409 với `code` ổn định |

## 3. Đọc log và DB

- `grep verify-1 /tmp/nest.log | jq .` để xem toàn bộ log của request đó: không có error ngoài dự kiến, không có secret trong log.
- Kiểm dữ liệu đã ghi: `npx prisma studio` hoặc `psql` với `SELECT` (chỉ đọc).
- Job nền: kiểm job đã chạy (log processor hoặc Bull Board).

Bug: tái hiện bằng curl trước khi sửa, sửa xong chạy lại đúng lệnh đó.

## 4. Report

Ghi: lệnh curl đã chạy, status + body rút gọn, request id, kết quả kiểm DB/log, `npm run build` pass.
