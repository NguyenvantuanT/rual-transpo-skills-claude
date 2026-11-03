---
name: web-performance
description: Hiệu năng web Next.js — Core Web Vitals (LCP, INP, CLS), giảm JS phía client, ảnh/font, streaming, cache, đo bằng Lighthouse và bundle analyzer. Dùng khi trang chậm, bundle to, điểm Lighthouse thấp, hoặc trước khi ra mắt trang quan trọng.
---

# Web performance

Đo trước, sửa sau. Không tối ưu theo cảm giác.

## Đo

- `npm run build`: đọc bảng First Load JS theo route; route > ~200 kB là đáng xem xét.
- `@next/bundle-analyzer` (`ANALYZE=true npm run build`) để tìm thư viện nặng.
- Lighthouse / PageSpeed trên bản build production (không đo trên `next dev`). Field data: `useReportWebVitals` hoặc Vercel Analytics.

## LCP (tải nội dung chính)

- Ảnh hero: `next/image` với `priority` và `sizes` đúng. Các ảnh khác để lazy (mặc định).
- Font: `next/font` (tự host, `display: swap`). Không `<link>` Google Fonts tay.
- Data chậm → streaming: bọc phần chậm trong `<Suspense>` để phần còn lại hiện trước.
- Trang ít đổi → static hoặc `revalidate`, không render động mỗi request.

## INP (phản hồi tương tác)

- Giảm JS client: đẩy `'use client'` xuống lá; component chỉ hiển thị để ở server.
- Thư viện nặng chỉ dùng khi tương tác (editor, chart, map) → `next/dynamic` với `ssr: false` hoặc import trong handler.
- Danh sách dài (> ~100 dòng) → virtualize (`@tanstack/react-virtual`). Input lọc dùng `useDeferredValue`/debounce.
- Không tính toán nặng trong render; `useMemo` chỉ khi đo thấy chậm.

## CLS (bố cục nhảy)

- Ảnh, video, iframe có kích thước hoặc `aspect-ratio`. Skeleton có cùng kích thước với nội dung thật.
- Không chèn banner/thông báo đẩy nội dung xuống sau khi load.

## Import và bundle

- Import theo từng phần: `import debounce from 'lodash/debounce'`, không `import _ from 'lodash'`. Ngày tháng dùng `date-fns`/`dayjs`, không dùng moment.
- Script bên thứ ba: `next/script` với `strategy="lazyOnload"` hoặc `afterInteractive`.
- Kiểm tra trước khi thêm dependency: kích thước (bundlephobia), đã có thư viện tương tự trong repo chưa.

## Checklist

- [ ] Đã đo trước/sau và ghi số vào report (First Load JS, LCP/INP/CLS)
- [ ] Ảnh hero `priority`; mọi ảnh có kích thước
- [ ] Không có thư viện nặng trong bundle chung khi chỉ một trang dùng
- [ ] Phần chậm được stream bằng Suspense
