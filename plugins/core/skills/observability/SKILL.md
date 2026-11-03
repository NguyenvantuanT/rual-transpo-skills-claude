---
name: observability
description: Nguyên tắc quan sát hệ thống không phụ thuộc stack — log có cấu trúc, mức log, correlation/request id, metric RED/USE, tracing, alert theo triệu chứng, không log dữ liệu nhạy cảm. Dùng khi thêm log/metric, xử lý lỗi toàn cục, chuẩn bị lên production, hoặc khi debug sự cố.
---

# Observability

Mục tiêu: khi có sự cố production, trả lời được "chuyện gì xảy ra, với ai, lúc nào, vì sao" mà không cần thêm log rồi deploy lại.

## Log

- **Có cấu trúc** (JSON): `{ level, time, msg, requestId, userId, orderId, durationMs }`. `msg` là câu cố định; giá trị thay đổi đặt vào field.
- **Correlation id**: mỗi request/job có id, truyền qua mọi service, queue và gắn vào mọi log. Client (web/mobile) gửi `x-request-id` và hiển thị nó khi báo lỗi.
- **Mức log**:
  - `error`: cần người xử lý (lỗi không mong đợi, 5xx, job hết retry). Mỗi lỗi log **1 lần** ở nơi xử lý cuối cùng, không log rồi throw lại ở mỗi tầng.
  - `warn`: bất thường đã tự xử lý (retry thành công, fallback).
  - `info`: sự kiện nghiệp vụ (đơn được tạo, thanh toán thành công, đổi quyền).
  - `debug`: chi tiết khi phát triển; tắt ở production.
- **Không log**: mật khẩu, token, OTP, số thẻ, dữ liệu cá nhân đầy đủ. Cấu hình redact ở logger, không dựa vào việc nhớ.

## Metric

- Dịch vụ request (RED): **R**ate, **E**rrors, **D**uration (p50/p95/p99) theo route.
- Tài nguyên (USE): **U**tilization, **S**aturation, **E**rrors: CPU, memory, connection pool, độ dài queue.
- Metric nghiệp vụ: đơn/phút, tỉ lệ thanh toán lỗi. Thường là thứ phát hiện sự cố sớm nhất.
- Label có số giá trị ít (route, status). Không dùng userId/orderId làm label.

## Tracing

OpenTelemetry: span cho request vào, query DB, call HTTP ra, job. Truyền `traceparent` qua HTTP và queue. Log có `traceId` để nhảy từ log sang trace.

## Alert

- Alert theo **triệu chứng người dùng thấy** (tỉ lệ lỗi > X%, p95 > Y ms, queue tồn > Z phút), không theo nguyên nhân (CPU cao).
- Mỗi alert phải có hành động cụ thể; alert không cần làm gì thì xoá.

## Client (web/mobile)

Bắt lỗi chưa xử lý (Sentry/Crashlytics) kèm release version, màn hình, requestId của API lỗi gần nhất. Không gửi dữ liệu cá nhân.

## Checklist

- [ ] Log JSON, có requestId, đã redact
- [ ] Lỗi log 1 lần, đúng mức
- [ ] Có health check và metric RED cho dịch vụ mới
- [ ] Sự kiện nghiệp vụ quan trọng có log `info` để truy vết
