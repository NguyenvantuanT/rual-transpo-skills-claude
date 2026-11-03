---
name: nestjs-observability
description: Quan sát hệ thống NestJS — log JSON có cấu trúc (pino), request id/correlation id, exception filter toàn cục, health check (terminus), metrics, tracing OpenTelemetry. Dùng khi thêm log, xử lý lỗi toàn cục, health check, hoặc khi debug lỗi production.
---

# NestJS observability

Nguyên tắc chung (cái gì cần log, mức log, metric nào) xem `observability` (plugin `core`).

## Log

- Dùng `nestjs-pino` (hoặc Logger của Nest với transport JSON). Không dùng `console.log` (pack harness bắt).
- Log có cấu trúc: `this.logger.info({ orderId, amount }, 'order paid')`. Field là dữ liệu, message là câu cố định (để tìm kiếm và đếm được).
- Mỗi request có `requestId`: lấy từ header `x-request-id` hoặc tạo mới, gắn vào mọi log (pino-http tự làm) và trả lại trong response header.
- Redact: `authorization`, `cookie`, `password`, `token`, số thẻ. Cấu hình `redact` của pino.
- Mức log: `error` khi cần người xử lý; `warn` khi bất thường nhưng đã tự xử lý; `info` cho sự kiện nghiệp vụ; `debug` tắt ở production.

## Exception filter toàn cục

```ts
@Catch()
export class AllExceptionsFilter implements ExceptionFilter {
  catch(e: unknown, host: ArgumentsHost) {
    // HttpException → giữ status + body; Prisma P2002/P2025 → 409/404;
    // còn lại → 500 + log error kèm stack; body: { statusCode, code, message, requestId }
  }
}
```

- Lỗi 5xx: log `error` kèm stack. Lỗi 4xx: không log error (chỉ `info`/`debug` nếu cần).
- Không trả stack hay message lỗi DB cho client.
- `process.on('unhandledRejection')` → log rồi để process thoát, orchestrator sẽ khởi động lại.

## Health check

- `@nestjs/terminus`: `/health/live` (process còn sống, không kiểm phụ thuộc) và `/health/ready` (DB, Redis, queue).
- Health check không cần auth, không log mỗi lần gọi.

## Metrics và tracing

- Metrics (Prometheus `/metrics` hoặc OTel): số request và latency theo route + status, độ dài queue, job lỗi.
- Tracing: OpenTelemetry SDK khởi tạo **trước** khi import app (`instrumentation.ts`), auto-instrument http/prisma/bullmq. Truyền `traceparent` sang job trong queue.

## Checklist

- [ ] Log JSON, có requestId, đã redact; không có `console.log`
- [ ] Lỗi không mong đợi → 500 + log stack; lỗi Prisma được map đúng
- [ ] Có `/health/live` + `/health/ready`
- [ ] Sự kiện nghiệp vụ quan trọng (thanh toán, đổi quyền) có log `info` để truy vết
