---
name: harness-gardening
description: Dọn rác định kỳ repo app dùng vtinter-harness — quét vi phạm, sửa doc lệch code, cập nhật tech debt + quality score, sửa theo lô nhỏ. Dùng khi user nói dọn rác/gardening hoặc khi lên lịch cleanup.
---

# Harness gardening

Agent chép pattern có sẵn trong repo, kể cả pattern xấu → nợ tích lại nếu không dọn liên tục. Trả nợ từng phần nhỏ, thường xuyên; đừng để dồn.

Engine ở `../../engine`, rule theo stack ở `../../packs/<stack>/pack.sh` (tính từ base directory của skill này).

## Một lượt gardening

0. **Thoát sớm**: đọc ngày "Cập nhật lần cuối" trong `docs/QUALITY_SCORE.md`. `git log --since=<ngày đó> --oneline -- lib/ docs/` rỗng → báo "không có gì mới" và dừng, không quét.
1. **Quét** (từ root repo app):
   ```bash
   bash <plugin harness>/engine/check.sh      # vi phạm rule cơ học
   bash <plugin harness>/engine/docs-check.sh # doc trỏ tới path không còn
   git log --since="<lần chạy trước>" --name-only --oneline -- lib/   # vùng mới thay đổi
   ```
   Thêm phần không máy hoá được: đọc `docs/golden-principles.md`, đối chiếu với file thay đổi gần đây (helper tự viết trùng component có sẵn, parse JSON đoán shape, pattern lệch với code xung quanh).
2. **Doc gardening**: mỗi doc có path chết hoặc mô tả không khớp code → sửa doc theo code thật (code là sự thật, không phải ngược lại). Fact nằm ngoài repo (Slack, trí nhớ) mà agent cần → đề xuất ghi vào `docs/`.
3. **Cập nhật** `docs/tech-debt-tracker.md` (mục mới, mục đã xong thì xoá) và `docs/QUALITY_SCORE.md` (ngày + điểm domain thay đổi).
4. **Sửa theo lô nhỏ**: mỗi lô = 1 rule id hoặc 1 golden principle, ≤ ~10 file, thay đổi cơ học. Sau mỗi lô: `check.sh` cho file đã sửa + `fvm flutter analyze`. Lô cần quyết định thiết kế → không sửa, ghi tracker và hỏi user.
5. **Đề xuất rule mới**: cùng 1 loại lỗi xuất hiện ≥ 2 lần mà `check.sh` chưa bắt được → đề xuất rule (pattern + message chỉ cách sửa) cho plugin, không tự thêm.

## Chạy định kỳ

```
/schedule weekly harness-gardening cho repo <path>: chạy 1 lượt, mở PR nhỏ theo từng lô
```

Mỗi lô → 1 branch/PR riêng, mô tả: rule id, số file, cách kiểm chứng. Không gộp lô.

## Report

Vi phạm trước/sau theo rule id · doc đã sửa · lô đã sửa / để lại · đề xuất rule mới.

## Không làm

- Không sửa file generated, không đổi kiến trúc, không thêm dependency.
- Không tắt rule để "xanh" — tắt rule là quyết định của user.
