---
name: nestjs-testing
description: Test cho NestJS — unit test service bằng TestingModule + mock, e2e bằng supertest, test với DB thật (Testcontainers/DB test), factory dữ liệu, test guard và DTO validation. Dùng khi thêm test, sửa test fail/flaky, hoặc cần test cho logic vừa viết.
---

# NestJS testing

Test là vòng phản hồi mà hook Stop (`jest --findRelatedTests` / `vitest related` theo file vừa đổi) và CI dựa vào. Logic mới trong service phải có test.

## Chọn tầng

| Tầng | Dùng cho | Đặt ở |
|---|---|---|
| Unit | Service: nghiệp vụ, nhánh lỗi, kiểm quyền; pipe/guard tự viết | `*.service.spec.ts` cạnh file |
| Integration (DB thật) | Repository/query phức tạp, transaction, constraint | `test/integration/` |
| E2E | Endpoint: auth, validate DTO, status code, format lỗi | `test/*.e2e-spec.ts` |

Mock Prisma để test query phức tạp là test sai lớp: dùng DB thật.

## Unit test service

```ts
const module = await Test.createTestingModule({
  providers: [
    OrdersService,
    { provide: OrdersRepository, useValue: { findById: jest.fn(), update: jest.fn() } },
    { provide: PaymentGateway, useValue: { charge: jest.fn() } },
  ],
}).compile();
service = module.get(OrdersService);
```

- Mỗi nhánh có test: thành công, không tìm thấy (404), không có quyền (403), xung đột trạng thái (409).
- Thời gian: `jest.useFakeTimers().setSystemTime(...)`; inject clock nếu có.

## E2E

```ts
app = moduleRef.createNestApplication();
// dùng lại đúng cấu hình của main.ts: tách hàm configureApp(app) và gọi ở cả 2 nơi
configureApp(app); await app.init();
await request(app.getHttpServer()).post('/orders').set('Authorization', `Bearer ${token}`)
  .send({ items: [] }).expect(400);
```

- Không có `configureApp` chung → e2e test sẽ thiếu ValidationPipe/filter và pass sai.
- DB: Postgres test (Testcontainers hoặc service trong CI), `prisma migrate deploy` trước khi chạy, dọn dữ liệu giữa các test (truncate hoặc transaction rollback).
- Dịch vụ ngoài (mail, thanh toán) → override provider bằng fake (`overrideProvider(...).useValue`).
- Dữ liệu: factory (`buildUser({ role: 'admin' })`), không dùng fixture JSON lớn dùng chung.

## Checklist

- [ ] Service mới có unit test cho nhánh lỗi
- [ ] Endpoint mới có e2e: 401 khi không token, 400 khi DTO sai, case thành công
- [ ] Test độc lập, không phụ thuộc thứ tự hay dữ liệu test khác để lại
- [ ] Chạy: `npm test`, `npm run test:e2e`
