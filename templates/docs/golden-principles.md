# Golden principles

Rule bất biến, có chủ kiến, kiểm chứng được. Agent chép pattern có sẵn trong repo — nên rule nào ở đây cũng phải hoặc được `check.sh` ép, hoặc được `harness-gardening` quét định kỳ.

Mỗi rule: 1 dòng phát biểu · cách kiểm (rule id hoặc "gardening") · lý do.

1. **Sửa code xấu, đừng mô tả nó.** Thấy bug/pattern lệch trong code mẫu → sửa hoặc ghi vào `docs/tech-debt-tracker.md` kèm plan dọn. Không viết "đừng copy file X" trong doc. · gardening · agent vẫn copy thứ nó thấy.
2. **Validate data ở biên.** JSON → model qua `fromJson` có kiểu nullable rõ ràng; discriminator → enum `fromString()`. Không đoán shape. · review/gardening · tránh build trên data đoán mò.
3. **Dùng helper chung thay vì tự viết.** Debounce, loading, button, tap, snack-bar đều có component sẵn. · `raw_*` rules · invariant tập trung một chỗ.
4. **Một nguồn sự thật cho mỗi fact.** Fact dự án ở `docs/`, convention chung ở skill plugin — không chép qua lại. · `docs-check.sh` · bản sao sẽ lệch.
5. <rule riêng của dự án>
