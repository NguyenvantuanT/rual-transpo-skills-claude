### NestJS (API + Prisma)

- Chạy: `npm run start:dev` · test: `npm test` · e2e: `npm run test:e2e` · migration: `npx prisma migrate dev --name <việc>`.
- Tự kiểm chứng API: skill `nestjs-run-and-verify` (chạy server, gọi endpoint bằng curl, đọc log JSON theo request id). Feature nhiều file → subagent `nestjs-backend-dev`.

| Việc | Skill |
|---|---|
| Module, layer controller → service → repository, DI, config | `nestjs-architecture` |
| Endpoint, DTO + validation, lỗi, phân trang, OpenAPI | `nestjs-api-design` (hợp đồng chung: `api-contract`) |
| Prisma: schema, migration, transaction, N+1 | `nestjs-prisma` (thiết kế bảng: `database-design`) |
| Auth (JWT, guard, role), rate limit, CORS, secret | `nestjs-auth-security` |
| Queue (BullMQ), cron, retry, idempotency | `nestjs-jobs-queues` |
| Log có cấu trúc, request id, health check, exception filter | `nestjs-observability` |
| Test unit (TestingModule), e2e (supertest), DB test | `nestjs-testing` |
