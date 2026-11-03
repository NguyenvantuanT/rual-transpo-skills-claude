---
name: nestjs-auth-security
description: Auth và bảo mật cho API NestJS — JWT/refresh token, Passport strategy, guard + decorator role, kiểm quyền theo dữ liệu, hash mật khẩu, rate limit, CORS, helmet, secret. Dùng khi đụng login, phân quyền, guard, token, hoặc review bảo mật API.
---

# NestJS auth & bảo mật

## Mặc định là chặn

- Đăng ký `JwtAuthGuard` làm global guard (`APP_GUARD`). Route công khai đánh dấu bằng `@Public()`.
- Lấy user qua decorator `@CurrentUser()`, không đọc `req.user` rải rác.
- Phân quyền theo role: `@Roles('admin')` + `RolesGuard`. Phân quyền theo dữ liệu (đơn này có phải của user không) làm trong **service**, bằng `where: { id, userId }`.

## Token

- Access token ngắn hạn (5–15 phút), refresh token dài hạn, lưu hash trong DB, xoay vòng mỗi lần dùng (rotation) và thu hồi được.
- Web: refresh token trong cookie `httpOnly; secure; sameSite`. Mobile: secure storage.
- Secret JWT lấy từ `ConfigService`, đủ dài; kiểm `iss`/`aud`/`exp`.

## Mật khẩu và dữ liệu nhạy cảm

- Hash bằng `argon2` (hoặc `bcrypt` cost ≥ 12). Không log mật khẩu, token, OTP.
- So sánh token/chữ ký bằng `timingSafeEqual`.
- Response không trả `passwordHash`, `refreshTokenHash` (dùng response DTO).
- Login/đăng ký/quên mật khẩu trả thông báo chung, không tiết lộ email có tồn tại hay không.

## Bảo vệ API

| Mối nguy | Cách |
|---|---|
| Brute force | `@nestjs/throttler` global, siết chặt hơn cho `/auth/*` |
| Mass assignment | `ValidationPipe({ whitelist: true, forbidNonWhitelisted: true })`; DTO không có `role`, `userId` |
| IDOR | Kiểm owner/tenant trong mọi query theo id |
| Injection | Prisma có tham số; raw SQL chỉ dùng `$queryRaw` tagged |
| CORS | Danh sách origin cụ thể, không `*` khi có credentials |
| Header | `helmet()` |
| Webhook | Verify chữ ký với raw body (`rawBody: true` khi tạo app) |
| Upload | Giới hạn kích thước + kiểm MIME; lưu vào storage ngoài, không phục vụ trực tiếp từ server |

## Secret

- Chỉ trong env/secret manager. `.env` không commit, `.env.example` không có giá trị thật. Pack harness bắt key lộ trong code.

## Checklist

- [ ] Route mới mặc định cần auth; `@Public()` có lý do rõ ràng
- [ ] Kiểm quyền theo dữ liệu trong service
- [ ] Không log hay trả về secret/token/hash
- [ ] Endpoint auth có rate limit
- Đổi auth, token, role hay permission → dừng, hỏi user.
