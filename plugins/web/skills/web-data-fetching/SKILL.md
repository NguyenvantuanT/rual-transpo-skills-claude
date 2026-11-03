---
name: web-data-fetching
description: Lấy và ghi data trong Next.js — fetch ở Server Component, Server Action cho mutation, TanStack Query cho data phía client, cache/revalidate, xử lý lỗi và loading. Dùng khi gọi API/DB, viết form submit, hoặc dữ liệu hiển thị bị cũ/không cập nhật.
---

# Data fetching

## Chọn cách

| Tình huống | Cách |
|---|---|
| Hiển thị data khi render trang | `async` Server Component gọi `features/<x>/queries.ts` |
| Form tạo/sửa/xoá | Server Action (`'use server'`) + `revalidatePath`/`revalidateTag` |
| Data đổi liên tục, polling, infinite scroll, optimistic phức tạp ở client | TanStack Query gọi route handler / API |
| Bên ngoài gọi vào (webhook, mobile) | `route.ts` |

Không `useEffect(() => fetch(...))` để lấy data lúc render. Không gọi route handler của chính app từ Server Component (gọi thẳng hàm query).

## Query phía server

```ts
// features/orders/queries.ts
import 'server-only';
export async function getOrder(id: string) {
  const res = await api(`/orders/${id}`, { next: { tags: [`order:${id}`] } });
  if (res.status === 404) return null;
  if (!res.ok) throw new ApiError(res.status, await res.text());
  return OrderSchema.parse(await res.json());   // validate biên bằng zod
}
```

- Data từ bên ngoài (API, form, searchParams) phải parse bằng zod ở biên rồi mới dùng type.
- Các fetch độc lập chạy song song bằng `Promise.all`, không `await` lần lượt.
- Cache: ghi rõ ý định (`cache: 'no-store'` hoặc `next: { revalidate, tags }`). Data riêng của user không được cache chung.

## Server Action

```ts
'use server';
export async function updateOrder(_: State, form: FormData): Promise<State> {
  const user = await requireUser();                       // auth trong MỌI action
  const parsed = UpdateOrderSchema.safeParse(Object.fromEntries(form));
  if (!parsed.success) return { errors: parsed.error.flatten().fieldErrors };
  await ordersRepo.update(user.id, parsed.data);          // kiểm quyền sở hữu bên trong
  revalidateTag(`order:${parsed.data.id}`);
  return { ok: true };
}
```

- Server Action là endpoint công khai: luôn kiểm auth, quyền và validate, dù form đã validate ở client.
- Lỗi nghiệp vụ trả về dạng state để form hiển thị; chỉ throw khi là lỗi bất ngờ (để `error.tsx` bắt).
- Client dùng `useActionState` + `useFormStatus` cho trạng thái pending.

## TanStack Query (client)

- Query key là mảng có cấu trúc: `['orders', { status, page }]`; gom vào factory `orderKeys`.
- Sau mutation thì `invalidateQueries` đúng key. Optimistic update phải có rollback trong `onError`.
- Hydrate từ server bằng `initialData` hoặc `HydrationBoundary`, tránh fetch 2 lần.

## Checklist

- [ ] Không có fetch lúc render trong `useEffect`; có loading + error state
- [ ] Dữ liệu từ ngoài vào đã parse bằng zod
- [ ] Server Action: auth + validate + kiểm quyền + revalidate
- [ ] Cache có chủ đích; data riêng user không cache chung
