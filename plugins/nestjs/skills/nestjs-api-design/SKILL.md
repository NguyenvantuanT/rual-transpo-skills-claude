---
name: nestjs-api-design
description: Thiết kế endpoint NestJS — route REST, DTO + class-validator, response DTO, mã lỗi và exception, phân trang/lọc/sắp xếp, versioning, OpenAPI (Swagger). Dùng khi thêm/sửa controller, DTO, hoặc thay đổi hợp đồng API.
---

# NestJS API design

Quy tắc hợp đồng chung (đặt tên, format lỗi, phân trang, tương thích ngược) xem `api-contract` (plugin `core`). Skill này nói cách làm trong NestJS.

## Route

- Danh từ số nhiều, kebab-case: `GET /orders`, `GET /orders/:id`, `POST /orders`, `PATCH /orders/:id`, `DELETE /orders/:id`. Hành động không phải CRUD: `POST /orders/:id/cancel`.
- `@Param('id', ParseUUIDPipe)` (hoặc `ParseIntPipe`) để validate id.
- Status: tạo → 201, xoá → 204 (`@HttpCode(204)`), action bất đồng bộ → 202.

## DTO

```ts
export class CreateOrderDto {
  @IsUUID() customerId: string;
  @IsArray() @ArrayMinSize(1) @ValidateNested({ each: true }) @Type(() => OrderItemDto)
  items: OrderItemDto[];
  @IsOptional() @IsString() @MaxLength(500) note?: string;
}
export class UpdateOrderDto extends PartialType(CreateOrderDto) {}
```

- Mọi `@Body/@Query/@Param` có DTO, không dùng `any`/`object` (pack harness bắt).
- Query: `@Type(() => Number)` cho số; enum dùng `@IsEnum`.
- **Response DTO** riêng, không trả thẳng entity Prisma (lộ `passwordHash`, field nội bộ). Map trong service hoặc dùng `ClassSerializerInterceptor` + `@Exclude`.

## Lỗi

- Dùng exception có sẵn: `NotFoundException`, `ConflictException`, `ForbiddenException`, `BadRequestException`, `UnprocessableEntityException`. Không `throw new Error()` trong luồng nghiệp vụ (pack harness bắt).
- Body lỗi thống nhất qua global filter: `{ statusCode, code, message, details?, requestId }`. `code` là mã ổn định (`ORDER_ALREADY_PAID`) để client xử lý.
- Lỗi Prisma (`P2002` trùng unique, `P2025` không tìm thấy) map sang 409/404 trong filter, không để thành 500.

## Danh sách

- Phân trang: `?limit=20&cursor=<id>` (cursor) hoặc `?page&limit`; `limit` có giá trị tối đa (vd 100). Response `{ data, nextCursor }` hoặc `{ data, total, page }`.
- Lọc/sắp xếp theo whitelist field, không truyền thẳng từ query vào `orderBy`/`where`.

## OpenAPI

- `@nestjs/swagger` plugin CLI để tự sinh schema từ DTO. `@ApiTags`, `@ApiOkResponse({ type })`, `@ApiBearerAuth` trên controller.
- Client (web/mobile) sinh type từ `openapi.json`. Đổi hợp đồng thì cập nhật spec trong cùng PR.

## Checklist

- [ ] DTO vào có validate, DTO ra không lộ field nội bộ
- [ ] Mã status và exception đúng; lỗi Prisma không thành 500
- [ ] Danh sách có phân trang với giới hạn
- [ ] Breaking change (đổi tên field, đổi type, bỏ endpoint) → dừng, hỏi user / tạo version mới
