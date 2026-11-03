---
name: nestjs-jobs-queues
description: Việc nền trong NestJS — BullMQ queue/processor, cron (@nestjs/schedule), retry + backoff, idempotency, outbox, chạy nhiều instance an toàn. Dùng khi thêm job nền, cron, gửi mail/thông báo bất đồng bộ, hoặc xử lý webhook.
---

# NestJS jobs & queues

## Khi nào dùng queue

Việc chậm (> vài trăm ms), gọi dịch vụ ngoài có thể lỗi (mail, push, thanh toán), hoặc cần retry → đẩy vào queue, trả response ngay (202 nếu client cần biết).

## BullMQ

```ts
@Processor('emails')
export class EmailProcessor extends WorkerHost {
  async process(job: Job<SendEmailJob>) { await this.mailer.send(job.data); }
}
// enqueue
await this.emailQueue.add('welcome', { userId }, {
  jobId: `welcome:${userId}`,            // chống trùng
  attempts: 5, backoff: { type: 'exponential', delay: 2000 },
  removeOnComplete: 1000, removeOnFail: 5000,
});
```

- Payload nhỏ, chỉ chứa id; processor tự đọc dữ liệu mới nhất từ DB.
- **Idempotent**: job có thể chạy lại (retry, crash giữa chừng). Kiểm trạng thái trước khi làm (`if (order.emailSentAt) return`), hoặc dùng `jobId`/idempotency key.
- Lỗi tạm thời → throw để retry. Lỗi vĩnh viễn (dữ liệu sai) → `UnrecoverableError` để không retry vô ích.
- Job thất bại hết lượt retry phải được nhìn thấy: log error + alert / dashboard (Bull Board).

## Enqueue sau khi commit

Enqueue trong transaction DB có thể tạo job cho dữ liệu đã rollback. Cách đúng:
1. Đơn giản: enqueue **sau** khi transaction commit.
2. Cần chắc chắn: **outbox**: ghi bản ghi `outbox_events` trong cùng transaction; một worker đọc outbox rồi đẩy vào queue.

## Cron

- `@Cron('0 */5 * * * *', { timeZone: 'Asia/Ho_Chi_Minh' })` hoặc dùng repeatable job của BullMQ.
- Nhiều instance chạy cùng lúc → cron chạy N lần. Dùng repeatable job của BullMQ (chỉ 1 lần) hoặc lock (Redis `SET NX PX`), hoặc chỉ bật scheduler ở 1 worker.
- Cron xử lý theo lô có giới hạn (`take: 500`), không load toàn bộ bảng.

## Webhook vào

Verify chữ ký → lưu event (unique theo event id của nhà cung cấp) → trả 200 ngay → xử lý trong queue.

## Checklist

- [ ] Job idempotent; có `attempts` + backoff; lỗi vĩnh viễn không retry
- [ ] Enqueue sau commit hoặc qua outbox
- [ ] Cron an toàn khi nhiều instance; có timezone; xử lý theo lô
- [ ] Graceful shutdown: worker đóng trước khi process thoát (`enableShutdownHooks`)
