---
name: web-testing
description: Test cho web Next.js/React — chọn tầng (unit Vitest, component React Testing Library, e2e Playwright), mock API bằng MSW, test Server Action, tránh test flaky. Dùng khi thêm test, sửa test fail/flaky, hoặc cần test cho logic vừa viết.
---

# Web testing

Test là vòng phản hồi mà hook Stop (`vitest related` / `jest --findRelatedTests` với file vừa đổi) và CI dựa vào. Logic mới không tầm thường phải có test.

## Chọn tầng rẻ nhất mà vẫn fail đúng lý do

| Tầng | Dùng cho | Công cụ |
|---|---|---|
| Unit | Util, zod schema, hàm tính tiền/ngày, reducer, hook thuần | Vitest |
| Component | Render theo props/state, tương tác người dùng, form validate | Vitest + React Testing Library + user-event |
| Server Action / query | Validate, kiểm quyền, gọi repo đúng tham số | Vitest, mock `lib/auth` + repo |
| E2E | Flow chính: đăng nhập, checkout, CRUD | Playwright |

Async Server Component khó test bằng RTL → tách logic ra hàm và test hàm đó, flow tổng thể để e2e lo.

## Component test

```tsx
test('báo lỗi khi email sai', async () => {
  const user = userEvent.setup();
  render(<SignupForm onSubmit={vi.fn()} />);
  await user.type(screen.getByLabelText(/email/i), 'abc');
  await user.click(screen.getByRole('button', { name: /đăng ký/i }));
  expect(await screen.findByText(/email không hợp lệ/i)).toBeInTheDocument();
});
```

- Query theo thứ tự ưu tiên: `getByRole` → `getByLabelText` → `getByText`. `data-testid` là cách cuối cùng.
- Test hành vi người dùng thấy, không test state nội bộ hay tên class.
- Dùng `findBy*`/`waitFor` cho async, không dùng `setTimeout`.

## Mock

- Mock HTTP bằng MSW (`setupServer`) ở mức network, không mock `fetch` bằng tay ở từng test.
- Thời gian: `vi.useFakeTimers()` + `vi.setSystemTime()`. Không phụ thuộc giờ máy hay timezone (đặt `TZ=UTC` trong config test).
- Reset mock/handler sau mỗi test.

## E2E (Playwright)

- Selector: `getByRole`, `getByLabel`. Không dùng CSS path dài.
- Không `waitForTimeout`, dựa vào auto-wait và `expect(...).toBeVisible()`.
- Đăng nhập 1 lần bằng `storageState`, seed data qua API/DB, không qua UI.
- Mỗi test độc lập, chạy song song được.

## Checklist

- [ ] Test đặt cạnh file (`x.test.ts`) hoặc trong `__tests__/`
- [ ] Có case lỗi và case biên, không chỉ happy path
- [ ] Không sleep, không phụ thuộc thứ tự test hay giờ máy
- [ ] Chạy: `npm test` (unit), `npx playwright test` (e2e)
