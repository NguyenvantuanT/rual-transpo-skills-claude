---
name: ai-code-review
description: Review code do AI/agent viết trước khi mở hoặc merge PR — API/cột/package bịa, lỗi logic tinh vi (biên, async, nuốt lỗi), bảo mật (RLS, identity từ client, secret), độ phức tạp thừa, lệch convention. Dùng khi user nói review PR / review diff agent viết / trước khi merge.
---

# Review code AI viết

Phỏng theo `ai-generated-code-review` của BOW Skills (MIT) — xem `THIRD_PARTY_NOTICES.md`. Code AI viết trông chắc chắn, format đẹp, và sai theo kiểu người ít khi sai: giả định nó compile được và trông hợp lý — lỗi nằm dưới lớp bóng đó.

Lint/analyzer của dự án (với Flutter: `check.sh` + `flutter analyze`) đã chặn phần cơ học (convention, `!`, secret, SQL rule). Review này tập trung vào thứ máy không thấy.

## 0. Trước khi đọc dòng nào

- Đọc lại yêu cầu gốc / exec plan: diff giải quyết **đúng** việc đó hay việc na ná?
- Đếm phạm vi (file, dòng) — phình ngoài yêu cầu là cờ đỏ.
- Đọc test **sau cùng** — test do AI viết hay assert đúng cái hành vi sai.

## 1. API bịa — xác minh mọi thứ "trông có vẻ thật"

- Package mới → có trong `pubspec.yaml`? symbol có trong đúng version đó? (`fvm flutter pub deps --no-dev | grep <pkg>`)
- Method / named arg của thư viện ngoài → đối chiếu source đã cài (`~/.pub-cache`), không tin trí nhớ.
- Bảng / cột / RPC Supabase → `grep -rn "<tên>" supabase/migrations/`; endpoint REST → `EndPoint` + tài liệu API.
- Class / component nội bộ được gọi → grep thấy trong `lib/`.

Không tìm thấy trong source thật sau ~30 giây → coi là bịa cho tới khi chứng minh được.

## 2. Lỗi logic tinh vi

Với mỗi nhánh không tầm thường, hỏi "input nào làm nó sai?":
- Biên: list rỗng, 1 phần tử, null, 0, cuối tháng, múi giờ.
- Off-by-one: `.range(from, to)` inclusive, phân trang, retry.
- Async: thiếu `await`, `Future` bắn rồi bỏ, 2 lời gọi phải tuần tự lại chạy song song, `notifyListeners()` sau `dispose`.
- Nuốt lỗi: `catch (_) {}` hoặc catch rồi trả mặc định che mất lỗi (xem `flutter-error-handling`).
- Mutate: copy rồi lại sửa bản gốc; sửa list trong lúc duyệt; optimistic update không có snapshot để revert.

Không tự trả lời được → yêu cầu test cho case đó trước khi duyệt.

## 3. Bảo mật

- Bảng / đường dữ liệu mới không có RLS, hoặc query tin `user_id` client gửi thay vì `auth.uid()`.
- Ghi tiền / giảm giá / role từ client không có ràng buộc server-side.
- `select('*')` trả cột client không nên thấy.
- Nối chuỗi vào SQL / shell; edge function tin body request không validate.
- Đụng auth / RLS / input người dùng → bắt buộc chạy `supabase-security-review`.

## 4. Phức tạp thừa

Với mỗi file / class mới hỏi "xoá hoặc inline thì cái gì vỡ?" — "không gì" → bỏ.
- Abstraction / interface / generic chỉ có 1 implementation.
- Flag cấu hình, strategy map, factory cho thứ không bao giờ thay đổi.
- Tự viết lại thứ đã có (component `App*`, `EasyDebounce`, converter dùng chung).
- `try/catch` / null-check quanh giá trị không thể null.

## 5. Khớp codebase

- Đúng pattern VM/Page, đúng layer, đúng kiểu model của dự án (`HARNESS_MODEL_STYLE`)?
- Có kéo thêm HTTP client / date lib / cách DI thứ hai khi repo đã có một cái? → lỗi, không phải chuyện style.

## 6. Test

- Có case biên từ §2 hay chỉ happy path? Có assert vô nghĩa (`expect(x, x)`, mock chính class đang test)?
- Thêm ít nhất 1 case "đối nghịch" do chính bạn nghĩ ra.

## Chặn merge khi

- API / cột / package không xác minh được là có thật.
- Đường dữ liệu mới thiếu RLS hoặc tin identity từ client.
- Câu hỏi đúng-sai ở §2 chưa có test trả lời.
- Thêm độ phức tạp mà không có yêu cầu thay đổi nào biện minh.

Report: danh sách `[chặn/nên sửa/ghi chú] file:line — vấn đề → cách sửa`.
