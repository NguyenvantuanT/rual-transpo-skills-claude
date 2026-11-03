# Exec plans

Task nhỏ: plan ngắn ngay trong hội thoại, không cần file. Task lớn (nhiều PR, nhiều quyết định, nhiều phiên): tạo `docs/exec-plans/active/<YYYY-MM-DD>-<slug>.md` theo khung dưới, commit cùng code. Xong → chuyển sang `docs/exec-plans/completed/`.

Plan là bộ nhớ giữa các phiên: phiên sau (người hoặc agent khác, context trống) phải tiếp tục được chỉ từ plan + git log.

```markdown
# <Tên việc>

## Mục tiêu & acceptance criteria
- [ ] <kiểm chứng được: lệnh test / màn hình cụ thể / output mong đợi>

## Bước
- [x] <bước đã xong> — <commit>
- [ ] <bước tiếp — mỗi bước đủ nhỏ để xong trong 1 phiên>

## Quyết định
- <YYYY-MM-DD> <quyết định> — vì <lý do>

## Tiến độ
- <YYYY-MM-DD> <làm được gì> · <đang dở ở đâu> · <bước tiếp theo>

## Còn mở
- <câu hỏi cần human>
```

## Giao thức phiên

1. **Đầu phiên**: đọc plan active → `git log --oneline -10` → chạy test nhanh (lệnh ở mục Stack của `AGENTS.md`). Test đang đỏ từ trước → sửa trước khi làm bước mới.
2. **Trong phiên**: làm **một** bước. Không sửa hay xoá acceptance criteria để cho dễ đạt; tiêu chí sai → ghi vào "Còn mở", hỏi human.
3. **Cuối phiên**: commit, tick bước đã xong, thêm 1 dòng vào "Tiến độ". Dừng giữa chừng cũng phải ghi đang dở ở đâu.
4. **Báo xong cả việc**: subagent `evaluator` kiểm từng acceptance criteria. Chưa đạt hết → chưa chuyển plan sang `completed/`.
