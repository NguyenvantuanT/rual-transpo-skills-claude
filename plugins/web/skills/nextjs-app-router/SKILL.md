---
name: nextjs-app-router
description: Cấu trúc app Next.js App Router — route/layout/loading/error, Server vs Client Component, metadata/SEO, route handler, tổ chức thư mục theo feature. Dùng khi thêm trang, layout, route API, hoặc phân vân đặt code ở server hay client.
---

# Next.js App Router

Mặc định là **Server Component**. Chỉ thêm `'use client'` khi thật sự cần state, effect, event handler hay API của trình duyệt, và đặt nó ở **lá** của cây (nút bấm, form), không đặt ở page/layout.

## Cấu trúc thư mục

```
src/
  app/                       # chỉ routing: page, layout, loading, error, route
    (marketing)/page.tsx     # route group: chia layout, không ảnh hưởng URL
    (app)/orders/[id]/page.tsx
    api/webhooks/stripe/route.ts
  features/<domain>/         # code theo nghiệp vụ
    components/  actions.ts  queries.ts  schema.ts  types.ts
  components/ui/             # component dùng chung, không biết nghiệp vụ
  lib/                       # client API, db, auth, util
```

- `app/` mỏng: page lấy data (gọi `features/*/queries.ts`) rồi render component. Logic nghiệp vụ không nằm trong `page.tsx`.
- `features/A` không import nội bộ `features/B`; cần dùng chung thì đưa lên `lib/` hoặc `components/`.
- Code chỉ chạy ở server (db, secret) → `import 'server-only'` ở đầu file.

## File đặc biệt của route

| File | Khi nào |
|---|---|
| `loading.tsx` | Route có fetch chậm → skeleton, tự bọc Suspense |
| `error.tsx` (`'use client'`) | Mọi segment có fetch; có nút `reset()` |
| `not-found.tsx` + `notFound()` | Khi `[id]` không tồn tại, không trả trang rỗng |
| `route.ts` | Webhook, endpoint cho bên ngoài. Form nội bộ dùng Server Action |

## Server ↔ Client

- Props truyền từ Server sang Client phải serialize được: không truyền hàm, class instance hay `Date` (đổi sang ISO string).
- Muốn bọc Server Component trong Client Component thì truyền qua `children`, không import trực tiếp.
- `params`/`searchParams` (Next 15+) là Promise: `const { id } = await params`.
- Đọc `cookies()`/`headers()` làm route thành dynamic. Chỉ đọc ở nơi cần.

## Metadata

- Trang công khai: `export const metadata` hoặc `generateMetadata` (title, description, openGraph). Không dùng `<head>` tay.
- `app/sitemap.ts`, `app/robots.ts` cho site công khai.

## Checklist

- [ ] `'use client'` chỉ ở component lá, file đó không import `server-only`, db hay secret
- [ ] Segment có fetch thì có `loading.tsx` + `error.tsx`; `[id]` sai → `notFound()`
- [ ] Không có logic nghiệp vụ trong `page.tsx`/`layout.tsx`
- [ ] Link nội bộ dùng `next/link`, ảnh dùng `next/image` (pack harness bắt)
- [ ] Trang công khai có metadata
