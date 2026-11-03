# AGENTS.md

Mục lục cho mọi coding agent (Claude Code, Codex, Cursor, Copilot...). Giữ ngắn (hook báo khi > 150 dòng): chi tiết ở `docs/`, ở đây chỉ trỏ tới. Đường dẫn trong backtick được `docs-check.sh` kiểm tra tồn tại.

Fact riêng của dự án nằm trong repo này; convention chung của stack nằm trong skill. Lệch nhau → repo này + code thật thắng.

## Dự án

- **Là gì**: <1 dòng>
- **Stack**: <vd: app Flutter + Supabase>
- **Lệnh riêng của dự án**: <ngoài các lệnh ở mục Stack>

## Làm việc

- Sửa nhỏ (1–2 file, yêu cầu rõ) → làm trực tiếp, load đúng skill theo bảng ở mục Stack.
- Việc lớn (> 1 PR, nhiều quyết định hoặc nhiều phiên) → viết exec plan ở `docs/exec-plans/active/` trước khi code (format: `docs/PLANS.md`).
- Tiếp tục việc dở ở phiên mới → đọc plan active, `git log --oneline -10`, chạy test nhanh trước khi sửa tiếp.
- Xong việc → hook chạy check + docs-check + verify của từng stack. Fail thì sửa, không bỏ qua.
- Trước khi báo xong việc lớn → subagent `evaluator` kiểm acceptance criteria; trước PR → subagent `reviewer` review diff.
- Sai vì thiếu context → bổ sung vào `docs/`; sai lặp lại → đề xuất rule mới cho harness.

## Bản đồ tri thức

| Cần biết | Đọc |
|---|---|
| Domain, layer, entry point | `ARCHITECTURE.md` |
| Nguyên tắc bất biến | `docs/golden-principles.md` |
| Chất lượng từng domain, gap đang theo dõi | `docs/QUALITY_SCORE.md` |
| Nợ kỹ thuật, xung đột rule ↔ code | `docs/tech-debt-tracker.md` |
| Việc đang làm / đã xong | `docs/exec-plans/active/`, `docs/exec-plans/completed/` |
| Spec sản phẩm | `docs/product-specs/` |
| Rule bị tắt, pack đang bật | `.claude/harness.env` |

## Skill dùng chung

| Việc | Skill |
|---|---|
| Thiết kế UI/UX, bảng màu, font | `ui-ux-pro-max` · reskin có chủ đích: `frontend-design` |
| Giờ, múi giờ, lịch, giá, tiền | `datetime-and-money` |
| Sửa dữ liệu lúc offline rồi đồng bộ | `offline-sync` |
| Review diff do agent viết | `ai-code-review` (subagent `reviewer`) |

## Stack

Khối dưới do `harness-init` sinh theo pack đang bật: đừng sửa tay, chạy lại init để cập nhật.

<!-- harness:stack:start -->
<!-- harness:stack:end -->

## Ngoại lệ đã chấp nhận

Mỗi ngoại lệ = 1 dòng + rule id trong `HARNESS_DISABLE` nếu tắt cả rule.

- <vd: InkWell trong map preview card — tap-through>
