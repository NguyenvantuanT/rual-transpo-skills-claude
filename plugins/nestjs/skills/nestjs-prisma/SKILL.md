---
name: nestjs-prisma
description: Prisma trong NestJS — schema, migration an toàn, select/include, transaction, tránh N+1, phân trang, soft delete, Decimal cho tiền. Dùng khi sửa schema.prisma, viết migration, viết query, hoặc gặp query chậm/lỗi dữ liệu.
---

# NestJS + Prisma

Nguyên tắc thiết kế bảng (khoá, index, chuẩn hoá) xem `database-design` (plugin `core`).

## PrismaService

`PrismaService extends PrismaClient implements OnModuleInit` trong `PrismaModule` (`@Global`). Inject vào service/repository; không tạo `new PrismaClient()` ở nơi khác.

## Schema và migration

- Đổi `schema.prisma` → **luôn** `npx prisma migrate dev --name <việc>` để sinh migration, rồi commit cả 2 (hook harness báo khi thiếu). Không sửa file `migration.sql` đã commit (harness chặn).
- Migration chạy trên production: `prisma migrate deploy`. Không dùng `db push` ngoài môi trường local.
- Thay đổi phá huỷ (đổi tên/xoá cột, đổi type, thêm NOT NULL vào bảng có dữ liệu) → chia nhiều bước (expand → backfill → contract). Dừng hỏi user trước khi làm.
- Tiền: `Decimal @db.Decimal(18, 2)` hoặc số nguyên đơn vị nhỏ nhất. Thời gian: `DateTime` (lưu UTC). Xem `datetime-and-money`.
- Index cho cột dùng trong `where`/`orderBy` thường xuyên và cho khoá ngoại (`@@index([userId])`).

## Query

- Luôn `select` field cần dùng (hoặc `include` có giới hạn). Không trả nguyên bản ghi kèm field nhạy cảm.
- **N+1**: không query trong vòng lặp. Dùng `include`, hoặc `findMany({ where: { id: { in: ids } } })` rồi map.
- `findUnique` + `if (!x) throw new NotFoundException()`, hoặc `findUniqueOrThrow` khi filter đã map P2025 → 404.
- Lọc theo chủ sở hữu/tenant ngay trong `where` (`{ id, userId }`), không lấy ra rồi mới kiểm.
- Raw SQL chỉ khi cần: `$queryRaw` với tagged template (có tham số hoá). Không `$queryRawUnsafe` với chuỗi ghép (pack harness bắt).

## Transaction

```ts
await this.prisma.$transaction(async (tx) => {
  const order = await tx.order.update({ where: { id, status: 'PENDING' }, data: { status: 'PAID' } });
  await tx.payment.create({ data: { orderId: order.id, amount } });
});
```

- Nhiều thao tác ghi phải cùng thành công/thất bại → `$transaction`. Truyền `tx` xuống repository khi cần.
- Không gọi API bên ngoài (HTTP, queue) bên trong transaction. Làm sau khi commit (hoặc dùng outbox).
- Tránh race: điều kiện trong `where` của update (`status: 'PENDING'`), hoặc unique constraint, hoặc `version` (optimistic lock).

## Checklist

- [ ] Đổi schema có migration đi kèm; thay đổi phá huỷ đã hỏi user
- [ ] Không query trong vòng lặp; có `select`
- [ ] Ghi nhiều bảng dùng transaction; không gọi bên ngoài trong transaction
- [ ] Query có lọc theo owner/tenant
