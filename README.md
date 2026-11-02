# vtinter-harness

Harness Claude Code cho các dự án Flutter dựng trên bộ base MVVM + Provider (BaseViewModel + MixinBasePage + get_it + auto_route + Dio/ApiClient + intl_utils + component `App*`).

Theo tinh thần [harness engineering](https://openai.com/index/harness-engineering/): con người lái, agent làm. Việc của harness là cho agent **bản đồ** để biết đọc gì, **luật được máy ép** để không trôi, và **vòng phản hồi** để tự kiểm chứng.

## Thành phần

| | Vai trò |
|---|---|
| `agents/flutter-mobile-dev.md` | Bản đồ + quy trình cho subagent code Flutter |
| `skills/flutter-*` | Convention chung của bộ base, nạp theo nhu cầu |
| `skills/flutter-supabase-queries` | Backend Supabase: query theo domain, select tường minh + range, RPC, optimistic update, realtime |
| `skills/supabase-security-review` | Review SQL/RLS/view/trigger/edge function. Rule máy `sb_*` có trong `check.sh` |
| `skills/flutter-testing` | Test unit VM / widget Page theo bộ base, mock qua `get_it` |
| `skills/flutter-error-handling` | Bốn kênh lỗi, phân loại lỗi, crash reporting + symbolication |
| `skills/flutter-performance` | Rebuild của Provider/MixinBasePage, repaint, list, isolate |
| `skills/flutter-push-and-deep-link` | FCM, local notification, app_links, pending intent qua `appRouter` |
| `skills/datetime-and-money` | UTC/IANA/DST, tiền là số nguyên + mã tiền tệ |
| `skills/offline-sync` | HLC, chiến lược theo field, tombstone, outbox, test hội tụ |
| `skills/ai-code-review` | Review diff do agent viết: API bịa, logic, bảo mật, độ phức tạp |
| `skills/flutter-run-and-verify` | Agent tự chạy app, chụp màn hình, đọc log, viết integration test |
| `skills/harness-init` | Dựng harness vào repo app: CLAUDE.md mục lục, `docs/`, `harness.env`, CI |
| `skills/harness-gardening` | Dọn rác định kỳ: quét vi phạm, sửa doc lệch, cập nhật tech debt và quality score |
| `scripts/check.sh` | Engine luật: rule code, hướng import giữa các layer, giới hạn kích thước file, đồng bộ ARB, version pin. Dùng chung cho hook, CI và người |
| `scripts/docs-check.sh` | Doc drift: đường dẫn trong doc phải tồn tại, CLAUDE.md phải ngắn |
| `hooks/` | Pre: chặn sửa file generated. Post: `check.sh` cho file vừa sửa. Stop: `check.sh` + `docs-check.sh` + `flutter analyze` + kiểm tra đã regen chưa |
| `templates/` | CLAUDE.md, ARCHITECTURE.md, `docs/`, `harness.env`, CI workflow |

## Luồng chạy

```
yêu cầu → Claude đọc CLAUDE.md (mục lục) → giao flutter-mobile-dev
  → agent đọc docs/ + load skill → code
  → mỗi Edit/Write: pre_edit (chặn generated) · post_edit (check.sh) → lỗi thì tự sửa
  → UI/flow: flutter-run-and-verify (ảnh trước/sau)
  → định dừng: stop_verify (check + docs-check + analyze + regen) → fail thì phải làm tiếp
  → PR: CI chạy lại đúng các script đó
định kỳ: harness-gardening → PR dọn rác nhỏ
```

## Cài vào repo app

```
/plugin marketplace add <đường dẫn hoặc git URL của repo này>
/plugin install vtinter-harness@vtinter-harness
```

Rồi nhờ Claude: **"init harness cho repo này"** (skill `harness-init`). Skill sẽ tạo CLAUDE.md, `docs/`, `.claude/harness.env`, `.github/workflows/harness.yml`, rồi chạy baseline.

Chạy tay:

```bash
bash <plugin>/scripts/check.sh            # cả repo
bash <plugin>/scripts/check.sh lib/a.dart # vài file
bash <plugin>/scripts/docs-check.sh
```

## Tiết kiệm token

- **Skill nạp từng lớp**: `SKILL.md` khoảng 40–70 dòng chứa rule + checklist. Chi tiết và code mẫu nằm ở `references/`, agent chỉ mở khi cần.
- **Chỉ check dòng vừa đổi**: hook và CI chạy `check.sh` với `HARNESS_DIFF`, nên vi phạm cũ không kéo agent ra khỏi task. Nợ cũ do `harness-gardening` dọn (chế độ quét toàn bộ).
- **Hook Stop có cache**: trạng thái code không đổi thì không chạy lại. `analyze` chỉ chạy khi `.dart`/`.yaml` đổi, và chỉ đưa vào context các dòng lỗi (tối đa 20). Output của `check.sh` bị giới hạn 60 dòng.
- **Không nhắc trùng**: nhắc regen chỉ có ở hook Stop (dựa vào thời gian sửa file), không lặp lại sau mỗi lần edit.
- **Subagent chỉ cho việc lớn**: sửa nhỏ thì làm trực tiếp. Subagent khởi động lạnh, chỉ đáng dùng khi feature nhiều file.

## Thêm rule

Lỗi agent mắc lặp lại mà chưa bị bắt → thêm một dòng `flag <id> '<regex>' '<cách sửa>' '<path bỏ qua>'` vào `scripts/check.sh`. Message phải chỉ **cách sửa**, vì nó được đưa thẳng vào context của agent. Sau đó thêm rule id vào danh sách trong `templates/harness.env`.

Yêu cầu: `bash` (Git Bash trên Windows), `git`, `fvm` hoặc `flutter` trong PATH.
