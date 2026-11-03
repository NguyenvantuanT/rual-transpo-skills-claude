---
name: web-auth-security
description: Auth và bảo mật cho web Next.js — session/cookie, middleware, phân quyền ở server, Server Action/route handler an toàn, XSS, CSRF, secret và biến môi trường, security header. Dùng khi đụng login, phân quyền, cookie, env, hoặc review bảo mật.
---

# Web auth & bảo mật

## Nguyên tắc

1. **Kiểm quyền ở server, sát dữ liệu.** Middleware chỉ để chuyển hướng cho UX, không phải lớp bảo vệ duy nhất. Mọi page, Server Action và route handler đọc data riêng đều phải tự gọi `requireUser()` và kiểm quyền sở hữu.
2. **Không tin client.** Ẩn nút trên UI không phải là phân quyền. ID trong form/URL phải kiểm `resource.ownerId === user.id` (hoặc role).
3. **Secret chỉ ở server.** Biến `NEXT_PUBLIC_*` bị đóng gói vào bundle, nên chỉ chứa giá trị công khai (pack harness bắt tên kiểu SECRET/KEY/TOKEN).

## Session

- Ưu tiên thư viện sẵn có (Auth.js, Clerk, Lucia, Supabase Auth). Không tự viết crypto.
- Cookie session: `httpOnly`, `secure`, `sameSite=lax`, có hạn. Không lưu token trong `localStorage`.
- Gom vào `lib/auth.ts`: `getSession()`, `requireUser()`, `requireRole(role)`. Code khác chỉ gọi các hàm này.

```ts
export async function requireUser() {
  const session = await getSession();
  if (!session) redirect('/login');
  return session.user;
}
```

## Các lỗ hổng thường gặp

| Lỗi | Cách tránh |
|---|---|
| XSS | Không dùng `dangerouslySetInnerHTML`; bắt buộc phải dùng thì sanitize bằng DOMPurify. URL do user nhập: chỉ cho `http(s):` |
| CSRF | Server Action có kiểm Origin sẵn. Route handler nhận cookie mà đổi dữ liệu → kiểm Origin hoặc dùng token |
| IDOR | Luôn lọc theo `userId`/tenant trong query, không chỉ theo `id` |
| Open redirect | `?next=` chỉ nhận path bắt đầu bằng `/` và không phải `//` |
| Lộ thông tin lỗi | Không trả stack hay lỗi DB ra client; log ở server |
| Webhook giả | Verify chữ ký (Stripe, GitHub...) với raw body |

## Env

- Validate env khi khởi động bằng zod (`lib/env.ts`); thiếu biến → crash sớm.
- `.env*.local` không commit; `.env.example` liệt kê tên biến, không có giá trị thật.

## Header

`next.config` → `headers()`: `Content-Security-Policy` (bắt đầu bằng report-only), `X-Content-Type-Options: nosniff`, `Referrer-Policy: strict-origin-when-cross-origin`, `frame-ancestors 'none'` nếu không cần nhúng iframe.

## Checklist

- [ ] Mọi Server Action/route handler/page riêng tư có `requireUser` + kiểm quyền sở hữu
- [ ] Không có secret trong `NEXT_PUBLIC_*` hay trong file `'use client'`
- [ ] Không `dangerouslySetInnerHTML` chưa sanitize; redirect chỉ nội bộ
- [ ] Webhook verify chữ ký; env được validate
- Đổi auth, session hay permission → dừng, hỏi user trước khi merge.
