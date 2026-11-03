---
name: git-workflow
description: Quy trình git cho agent và team — branch, commit nhỏ theo Conventional Commits, PR mô tả rõ và tự review trước, xử lý conflict, thao tác nguy hiểm cần hỏi. Dùng khi tạo branch, commit, mở PR, rebase/merge, hoặc dọn lịch sử.
---

# Git workflow

## Branch

- Không commit thẳng lên `main`. Tạo branch: `feat/<việc>`, `fix/<việc>`, `chore/<việc>`, `refactor/<việc>`.
- Một branch một việc. Phát hiện việc khác trong lúc làm → ghi lại (tech-debt / issue), không làm luôn.

## Commit

- Conventional Commits: `<type>(<scope>): <mô tả>`. type: `feat`, `fix`, `refactor`, `test`, `docs`, `chore`, `perf`, `ci`. Ví dụ `fix(orders): làm tròn tiền theo currency`.
- Commit nhỏ, mỗi commit build + test được. Không gộp refactor với đổi hành vi trong 1 commit.
- Body giải thích **vì sao** (code đã cho thấy làm gì).
- Kiểm trước khi commit: `git status`, `git diff --staged`. Không commit `.env`, secret, file build, file tạm, file log.
- Chỉ commit khi user yêu cầu hoặc quy trình của repo cho phép.

## PR

- Tiêu đề theo format commit. Mô tả gồm:
  - **Vì sao**: vấn đề/yêu cầu (link issue).
  - **Thay đổi chính**: vài gạch đầu dòng.
  - **Kiểm chứng**: test đã chạy, ảnh trước/sau, lệnh curl.
  - **Rủi ro / cần chú ý**: migration, breaking change, env mới.
- Tự review diff trước khi mở (hoặc gọi agent reviewer): debug log, code chết, TODO, file thừa.
- PR nhỏ (< ~400 dòng đổi thực). Lớn hơn thì chia theo bước.
- Mở PR, push, comment là hành động ra bên ngoài → hỏi user trước nếu chưa được cho phép.

## Đồng bộ và conflict

- Cập nhật branch: `git fetch` + `git rebase origin/main` (branch cá nhân) hoặc merge (branch dùng chung).
- Conflict: hiểu cả 2 phía trước khi giải quyết; chạy lại test sau khi giải quyết. Không chọn "ours/theirs" cả file cho nhanh.
- Lock file conflict → lấy bản của main rồi cài lại, không sửa tay.

## Thao tác nguy hiểm: luôn hỏi user trước

`push --force` (nếu cần thì dùng `--force-with-lease`) · `reset --hard` · `clean -fd` · `checkout -- .` / `restore .` · `rebase` branch đã chia sẻ · xoá branch remote · `--no-verify` (bỏ qua hook). Hook `pre_bash` của harness sẽ hỏi lại các lệnh này.

Trước khi xoá/ghi đè: xem nội dung (`git stash list`, `git diff`) để không mất việc chưa commit của user.

## Checklist

- [ ] Đang ở đúng branch, không phải `main`
- [ ] Diff staged chỉ chứa thứ thuộc task, không có secret
- [ ] Message đúng format, có lý do
- [ ] PR có phần kiểm chứng và rủi ro
