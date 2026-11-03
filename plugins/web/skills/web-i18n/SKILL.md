---
name: web-i18n
description: Đa ngôn ngữ cho Next.js App Router bằng next-intl — cấu trúc messages, route theo locale, format ngày/số/tiền, plural, SEO đa ngôn ngữ. Dùng khi thêm/sửa chuỗi hiển thị, thêm ngôn ngữ, hoặc format ngày giờ/tiền tệ trên UI.
---

# Web i18n (next-intl)

Repo đã dùng thư viện khác (`react-i18next`, `next-i18next`...) thì theo thư viện đó; các nguyên tắc dưới vẫn áp dụng.

## Cấu trúc

```
messages/
  vi.json   en.json          # cùng cây key; vi là nguồn chuẩn
src/i18n/request.ts          # getRequestConfig: nạp messages theo locale
src/app/[locale]/layout.tsx  # NextIntlClientProvider
middleware.ts                # createMiddleware(routing): phát hiện và chuyển hướng locale
```

- Key theo màn/feature: `orders.detail.title`, `common.actions.save`. Không dùng câu tiếng Việt làm key.
- Thêm key thì thêm vào **mọi** file locale cùng lúc. Thiếu key là bug.
- Không nối chuỗi để tạo câu (`t('hello') + name`), dùng tham số: `"hello": "Xin chào {name}"`.

## Dùng

- Server Component: `const t = await getTranslations('orders')`.
- Client Component: `const t = useTranslations('orders')`. Chỉ truyền xuống client phần messages cần dùng nếu bundle lớn.
- Link/redirect dùng helper của `createNavigation(routing)` để giữ locale.

## Plural, ngày, số, tiền

```json
"items": "{count, plural, =0 {Chưa có món} other {# món}}"
```

- Ngày/giờ: `useFormatter().dateTime(date, { dateStyle: 'medium' })`, đặt `timeZone` rõ ràng trong config. Không tự format bằng `toLocaleString` rải rác.
- Tiền: `format.number(amount, { style: 'currency', currency: 'VND' })`. Quy tắc lưu tiền và múi giờ xem `datetime-and-money` (plugin `core`).

## SEO

- `generateMetadata` dịch title/description theo locale.
- `alternates.languages` khai báo các bản ngôn ngữ (hreflang). `<html lang={locale}>`.

## Checklist

- [ ] Không còn chuỗi hiển thị viết cứng trong JSX (trừ tên riêng)
- [ ] Key mới có ở mọi file `messages/*.json`
- [ ] Không nối chuỗi; plural dùng ICU
- [ ] Ngày/tiền format qua next-intl, có timezone
