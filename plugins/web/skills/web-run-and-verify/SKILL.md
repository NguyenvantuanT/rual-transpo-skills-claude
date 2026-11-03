---
name: web-run-and-verify
description: Tự chạy và kiểm chứng web Next.js như người dùng thật — dev server, build production, Playwright mở trang, chụp ảnh trước/sau, đọc console và network lỗi. Dùng sau khi sửa UI/flow để chứng minh nó chạy, hoặc khi cần tái hiện bug.
---

# Web run & verify

Test pass chưa đủ chứng minh UI đúng. Thay đổi UI/flow phải được xem tận mắt (ảnh chụp) trước khi báo xong.

## 1. Chạy

```bash
npm run dev -- -p 3100 > /tmp/next-dev.log 2>&1 &   # chạy nền, ghi log
npx wait-on http://localhost:3100                     # hoặc: until curl -sf ...; do sleep 1; done
```

- Dùng port riêng để không đụng server user đang chạy. Xong việc thì kill đúng process mình đã mở.
- Thiếu env → đọc `.env.example`, hỏi user giá trị thật; không tự bịa key.
- Trước khi báo xong việc lớn: `npm run build` phải pass (bắt lỗi type, lỗi server/client boundary mà dev bỏ qua).

## 2. Mở trang và tương tác

Dùng Playwright (đã có trong repo thì dùng, chưa có thì `npx playwright` tạm thời, không thêm vào `package.json` khi chưa hỏi):

```ts
// /tmp/verify.ts — chạy: npx tsx /tmp/verify.ts
import { chromium } from 'playwright';
const b = await chromium.launch(); const p = await b.newPage();
p.on('console', m => m.type() === 'error' && console.log('CONSOLE', m.text()));
p.on('response', r => r.status() >= 400 && console.log('HTTP', r.status(), r.url()));
await p.goto('http://localhost:3100/orders');
await p.getByRole('button', { name: /tạo đơn/i }).click();
await p.screenshot({ path: '/tmp/after.png', fullPage: true });
await b.close();
```

Có công cụ trình duyệt (MCP/Chrome) thì có thể dùng thay script.

## 3. Kiểm chứng

| Kiểm | Đạt khi |
|---|---|
| Ảnh chụp | Đúng thiết kế/yêu cầu; mở file ảnh để xem, không đoán |
| Console | Không có error mới (hydration mismatch, key, 404 asset) |
| Network | Không có 4xx/5xx ngoài dự kiến |
| Mobile | Chụp thêm ở viewport 375×812 nếu đổi layout |
| Trạng thái | Loading, empty, error đều được nhìn thấy ít nhất 1 lần |
| Log server | `/tmp/next-dev.log` không có lỗi mới |

Bug: tái hiện trước khi sửa (ảnh hoặc log), sửa xong chạy lại đúng các bước đó.

## 4. Report

Ghi: URL đã kiểm, các bước, đường dẫn ảnh trước/sau, lỗi console/network (nếu có), kết quả `npm run build`.
