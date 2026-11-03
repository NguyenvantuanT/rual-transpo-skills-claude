@AGENTS.md

# Claude Code

- Harness: marketplace `vtinter-harness` — plugin `harness` (luật + hooks + agent `reviewer`/`evaluator`), `core`, và plugin tri thức theo stack.
- Sửa file thuộc domain có skill mà chưa load → hook nhắc một lần mỗi phiên. Đã nắm convention thì cứ sửa tiếp.
- Subagent khởi động lạnh: chỉ giao khi việc nhiều file hoặc cần kiểm độc lập (`reviewer`, `evaluator`).
- Phần riêng cho Claude đặt ở đây; mọi thứ agent khác cũng cần → `AGENTS.md`.
