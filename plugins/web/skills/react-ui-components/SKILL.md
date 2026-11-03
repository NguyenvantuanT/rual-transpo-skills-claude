---
name: react-ui-components
description: Viết component React + TypeScript — tách component, props, state, form (react-hook-form + zod), Tailwind/shadcn, accessibility, tránh re-render thừa. Dùng khi tạo/sửa component, form, modal, bảng, hoặc review UI code.
---

# React UI components

Thiết kế thị giác (màu, font, bố cục) xem `ui-ux-pro-max` và `frontend-design` của plugin `core`. Skill này nói về **code**.

## Tách component

- Một component một việc. Component > ~150 dòng hoặc có > 3 `useState` liên quan → tách hook `useXxx` hoặc component con.
- `components/ui/*` không biết nghiệp vụ (Button, Dialog, DataTable). Component nghiệp vụ đặt trong `features/<domain>/components/`.
- Có shadcn/ui hoặc design system trong repo thì dùng lại; không tạo Button thứ hai.
- Props: định nghĩa `type XxxProps`, không dùng `any`. Truyền callback dạng `onSelect(id)`, không truyền setter của cha.

## State

- State dẫn xuất được thì tính khi render, không lưu thêm `useState` + `useEffect` để đồng bộ.
- `useEffect` chỉ để đồng bộ với hệ thống bên ngoài (subscription, DOM API). Logic theo sự kiện thì đặt trong handler.
- State dùng chung nhiều trang: URL (`searchParams`) cho filter/phân trang; server state dùng TanStack Query; global UI state nhỏ dùng Context hoặc Zustand.
- List: `key` là id ổn định, không dùng index (pack harness bắt).

## Form

```tsx
const form = useForm<Input>({ resolver: zodResolver(Schema), defaultValues });
```

- Dùng chung một schema zod cho client và Server Action.
- Mỗi input có `<label>`, lỗi hiển thị cạnh field (`aria-invalid`, `aria-describedby`). Nút submit disable khi đang pending.

## Accessibility (bắt buộc)

- Phần tử bấm được là `<button>`/`<a>`, không dùng `<div onClick>`.
- Ảnh có `alt` (ảnh trang trí thì `alt=""`). Icon-only button có `aria-label`.
- Modal/dropdown: focus trap, đóng bằng Esc, trả focus về chỗ cũ. Ưu tiên Radix/shadcn thay vì tự viết.
- Điều hướng được hoàn toàn bằng bàn phím, có focus ring rõ ràng.

## Styling

- Tailwind: gom class dài bằng `cn()` + `cva` cho biến thể. Không viết màu hex rời mà dùng token theme.
- Responsive mobile-first (`sm:`, `md:`...). Kiểm tra ở 375px.

## Checklist

- [ ] Không `any`, không `<div onClick>`, không `key={index}`
- [ ] Không có state dư thừa hay `useEffect` đồng bộ state
- [ ] Đủ trạng thái: loading, empty, error
- [ ] Label, alt, focus; chạy được bằng bàn phím
