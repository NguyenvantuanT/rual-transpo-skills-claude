---
name: nestjs-architecture
description: Kiến trúc app NestJS — chia module theo domain, layer controller → service → repository, dependency injection, config có validate, tránh circular dependency. Dùng khi thêm module/service, tổ chức lại code, hoặc phân vân logic nên đặt ở đâu.
---

# NestJS architecture

## Cấu trúc

```
src/
  main.ts                    # bootstrap: ValidationPipe, filter, logger, CORS, shutdown hooks
  app.module.ts
  config/                    # ConfigModule + schema validate env
  common/                    # filter, interceptor, guard, decorator, pipe dùng chung
  prisma/                    # PrismaModule + PrismaService (global)
  modules/<domain>/
    <domain>.module.ts
    <domain>.controller.ts   # HTTP: nhận DTO, gọi service, trả response DTO
    <domain>.service.ts      # nghiệp vụ, transaction, kiểm quyền theo dữ liệu
    <domain>.repository.ts   # truy cập DB (khi query phức tạp hoặc cần tách khỏi Prisma)
    dto/  entities/  <domain>.service.spec.ts
```

## Trách nhiệm từng layer

| Layer | Làm | Không làm |
|---|---|---|
| Controller | Route, decorator, nhận DTO, gọi 1 service method, map response | Gọi Prisma, if/else nghiệp vụ, try/catch nuốt lỗi |
| Service | Nghiệp vụ, điều phối repo/service khác, transaction, throw exception nghiệp vụ | Đọc `req`/`res`, biết về HTTP status ngoài exception có sẵn |
| Repository/Prisma | Query, select đúng field, phân trang | Quyết định nghiệp vụ |

## Module

- Một module một domain. Module khác cần dùng thì `exports: [XService]`, và bên dùng `imports: [XModule]`.
- Không import repository của module khác, đi qua service của nó.
- Circular dependency (`forwardRef`) là dấu hiệu chia sai: tách phần chung ra module thứ ba hoặc dùng event (`@nestjs/event-emitter`).
- Tác vụ phụ (gửi mail, gửi thông báo) sau nghiệp vụ chính → event hoặc queue, không gọi đồng bộ trong service chính.

## DI và config

- Mọi phụ thuộc inject qua constructor, không `new XService()` (pack harness bắt).
- Thư viện bên ngoài (Stripe, S3) → custom provider (`useFactory`) để mock được khi test.
- Env: `ConfigModule.forRoot({ validate })` với zod/class-validator; dùng `ConfigService` hoặc config namespace (`registerAs`). Không đọc `process.env` rải rác (pack harness bắt).

## Bootstrap (main.ts)

`ValidationPipe({ whitelist: true, forbidNonWhitelisted: true, transform: true })`, global exception filter, `enableShutdownHooks()`, `helmet()`, CORS theo danh sách origin, prefix `/api` + versioning.

## Checklist

- [ ] Controller không gọi Prisma trực tiếp, không chứa nghiệp vụ
- [ ] Module chỉ phụ thuộc qua service được export; không `forwardRef` mới
- [ ] Không `new` provider, không `process.env` ngoài config
- [ ] Logic mới trong service có unit test (`nestjs-testing`)
