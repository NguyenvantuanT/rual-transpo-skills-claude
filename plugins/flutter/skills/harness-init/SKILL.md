---
name: harness-init
description: Dựng vtinter-harness vào repo app Flutter — CLAUDE.md dạng mục lục, ARCHITECTURE.md, docs/, .claude/harness.env, CI, baseline vi phạm. Dùng khi user muốn init/áp dụng harness hoặc CLAUDE.md đã phình to.
---

# Harness init

Mục tiêu: repo app trở thành **nguồn sự thật duy nhất** mà agent đọc được — CLAUDE.md ngắn trỏ tới `docs/`, mọi rule kiểm được bằng máy.

Template ở `templates/` của plugin (base directory của skill này → `../../templates`). Script ở `../../scripts`.

## Bước

1. **Khảo sát repo app** (không đoán): `pubspec.yaml` (package, `flutter_intl`, deps), `.fvmrc`, `lib/app/main_*.dart`, `lib/router/app_router.dart`, `lib/src/utils/locator.dart`, `lib/src/base/base_vm.dart`, cây `lib/src/pages/`, `test/`. Ghi lại: 1 app hay multi-app (cờ app), locale, service inherited thật, domain chính, backend (`supabase_flutter` trong pubspec → Supabase; có `supabase/` thì có cả SQL/edge function), kiểu model (`grep -rl "@JsonSerializable" lib/src/models` có kết quả → `generated`, không → `manual`; lẫn cả hai → hỏi user chọn 1, ghi phần còn lại vào tech-debt).
2. **Copy template** — không ghi đè file đã có; file đã tồn tại thì merge ở bước 3:
   - `templates/CLAUDE.md` → `CLAUDE.md`
   - `templates/ARCHITECTURE.md` → `ARCHITECTURE.md`
   - `templates/docs/` → `docs/` (gồm `.gitkeep`)
   - `templates/harness.env` → `.claude/harness.env` (điền `HARNESS_MODEL_STYLE`; `HARNESS_APP_FLAG` nếu multi-app)
   - `templates/ci/harness.yml` → `.github/workflows/harness.yml` (sửa `HARNESS_REPO` thành git URL của plugin)
3. **Nếu repo đã có CLAUDE.md dài**: phân loại từng đoạn —
   - convention chung đã có trong skill `flutter-*` → **xoá** (không chép trùng);
   - fact dự án (app, locale, lệnh chạy) → mục Project của CLAUDE.md mới;
   - kiến trúc/domain → `ARCHITECTURE.md`;
   - nợ kỹ thuật, bug đã biết, xung đột rule ↔ code → `docs/tech-debt-tracker.md` (1 dòng/mục);
   - rule bất biến riêng dự án → `docs/golden-principles.md`;
   - ngoại lệ → mục Ngoại lệ + `HARNESS_DISABLE` nếu tắt cả rule.
   Kết quả CLAUDE.md ≤ 150 dòng.
4. **Điền placeholder** `<...>` bằng fact đã khảo sát ở bước 1. Placeholder chưa biết → để nguyên và liệt kê trong report.
5. **Baseline**: chạy từ root repo app
   ```bash
   bash <plugin>/scripts/check.sh      > /tmp/harness-baseline.txt; echo $?
   bash <plugin>/scripts/docs-check.sh
   ```
   Không sửa vi phạm cũ trong bước này. Tổng hợp theo rule id → ghi vào `docs/tech-debt-tracker.md` (1 dòng/rule: số vi phạm, file tiêu biểu) và chấm `docs/QUALITY_SCORE.md` lần đầu. Rule có quá nhiều vi phạm hợp lệ → đề xuất user tắt qua `HARNESS_DISABLE`, đừng tự tắt.
6. `docs-check.sh` phải exit 0 cho chính các doc vừa tạo.

## Report

File đã tạo/merge · placeholder còn trống · baseline vi phạm theo rule id · đề xuất bước tiếp (sửa nhóm vi phạm nào trước, có nên lên lịch `harness-gardening` không).

## Không làm

- Không commit, không push, không sửa code `lib/` trong lúc init.
- Không chép nội dung skill vào docs của repo.
