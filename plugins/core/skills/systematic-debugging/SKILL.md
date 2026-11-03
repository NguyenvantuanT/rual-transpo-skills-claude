---
name: systematic-debugging
description: Quy trình debug có hệ thống cho mọi stack — tái hiện, thu hẹp, đặt giả thuyết và kiểm chứng, tìm nguyên nhân gốc, viết test chặn hồi quy. Dùng khi gặp bug, test fail khó hiểu, lỗi chỉ xảy ra ở production, flaky, hoặc đã sửa 2 lần mà vẫn lỗi.
---

# Systematic debugging

Không sửa khi chưa hiểu nguyên nhân. Sửa theo phỏng đoán thường che triệu chứng và tạo bug mới.

## 1. Tái hiện

- Viết lại chính xác: input, môi trường (version, OS, dữ liệu), bước, kết quả mong đợi so với thực tế.
- Tái hiện được bằng lệnh/test tự động thì tốt nhất: **viết test fail trước** (test này sẽ chặn hồi quy sau khi sửa).
- Không tái hiện được → thu thêm dữ liệu (log theo requestId, stack trace, version, dữ liệu liên quan) trước khi đoán.

## 2. Đọc kỹ lỗi

- Đọc toàn bộ thông báo lỗi và stack trace; tìm dòng đầu tiên thuộc code của dự án.
- Lỗi đầu tiên trong log mới là lỗi gốc; các lỗi sau thường là hệ quả.

## 3. Thu hẹp

- **Diff**: lần cuối chạy đúng là khi nào? `git log`, `git bisect` giữa commit tốt và xấu.
- **Chia đôi**: bỏ bớt một nửa input/code/bước, xem lỗi còn không.
- **So sánh**: chạy được ở máy A mà không chạy ở B, với user X mà không với Y → khác nhau ở đâu (env, dữ liệu, version, timezone, quyền).

## 4. Giả thuyết → kiểm chứng

- Viết 1 giả thuyết cụ thể ("`total` sai vì cộng float"). Đặt 1 phép thử chỉ đúng khi giả thuyết đúng (log giá trị, assert, chạy lại với input tối thiểu).
- Mỗi lần chỉ đổi 1 thứ. Ghi lại những gì đã loại trừ.
- Đã thử 2 lần không ra → dừng lại, xem lại giả định (code đang chạy có phải code đang đọc không? cache? build cũ? sai môi trường?).

## 5. Sửa ở nguyên nhân gốc

- Hỏi "vì sao" đến khi chạm thiết kế/giả định sai. Thêm `?.`/`try-catch` để hết crash thường chỉ là che triệu chứng.
- Tìm chỗ khác có cùng lỗi (grep pattern).
- Lỗi mà máy có thể bắt được → đề xuất rule (pack harness) hoặc test để không lặp lại.

## 6. Xác nhận

- Test viết ở bước 1 pass; toàn bộ test liên quan pass.
- Chạy lại đúng bước tái hiện ban đầu (run-and-verify của stack).
- Gỡ log debug tạm.

## Bẫy hay gặp

Timezone/DST · float khi tính tiền · race condition/async không await · cache (CDN, Next cache, query cache) · biến môi trường khác nhau · dữ liệu null/rỗng ở production · build/generated cũ · test phụ thuộc thứ tự.

## Report

Nguyên nhân gốc (1–2 câu), bằng chứng, cách sửa, test chặn hồi quy, chỗ khác có thể bị cùng lỗi.
