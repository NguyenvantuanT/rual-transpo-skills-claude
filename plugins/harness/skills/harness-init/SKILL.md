---
name: harness-init
description: Dựng hoặc cập nhật vtinter-harness trong repo app (mọi stack) — AGENTS.md + CLAUDE.md dạng mục lục, ARCHITECTURE.md, docs/, .claude/harness.env, CI, bản đồ skill theo stack, baseline vi phạm. Dùng khi user muốn init/áp dụng/cập nhật harness hoặc CLAUDE.md đã phình to.
---

# Harness init

Mục tiêu: repo app trở thành **nguồn sự thật duy nhất** mà agent đọc được — `AGENTS.md` ngắn trỏ tới `docs/`, mọi rule kiểm được bằng máy.

Engine ở `../../engine` (tính từ base directory của skill này), template ở `../../templates`, pack ở `../../packs/<stack>/`.

## Bước

1. **Khảo sát repo app** (không đoán). Pack bật tự động theo file đánh dấu ở root: `pubspec.yaml` → `flutter`, `supabase/` → `supabase`, `tsconfig.json` → `web_ts`. Stack chưa có pack → báo user (vẫn có docs-check + hooks, chưa có rule code). Ghi lại: stack, lệnh chạy/test thật, domain chính, entry point. Riêng Flutter: `pubspec.yaml`, `.fvmrc`, `lib/app/main_*.dart`, router, locator, 1 app hay multi-app (cờ app), locale, kiểu model (`grep -rl "@JsonSerializable" lib/src/models` có kết quả → `generated`, không → `manual`; lẫn cả hai → hỏi user).
2. **Scaffold** từ root repo app:
   ```bash
   bash <plugin harness>/engine/scaffold.sh
   ```
   Script chỉ tạo file còn thiếu, cập nhật file template chưa ai sửa, không đụng file đã sửa (theo `.claude/harness.lock`), và sinh khối Stack trong `AGENTS.md` từ pack đang bật. Đọc output: dòng "giữ" là file cần merge tay ở bước 3.
3. **Repo đã có CLAUDE.md / AGENTS.md dài**: phân loại từng đoạn —
   - convention chung đã có trong skill → **xoá** (không chép trùng);
   - fact dự án (app, locale, lệnh chạy) → mục Dự án của `AGENTS.md`;
   - kiến trúc/domain → `ARCHITECTURE.md`;
   - nợ kỹ thuật, bug đã biết, xung đột rule ↔ code → `docs/tech-debt-tracker.md` (1 dòng/mục);
   - rule bất biến riêng dự án → `docs/golden-principles.md`;
   - ngoại lệ → mục Ngoại lệ + `HARNESS_DISABLE` nếu tắt cả rule;
   - chỉ dành cho Claude → `CLAUDE.md` (dòng đầu phải là `@AGENTS.md`, nếu không Claude Code bỏ qua `AGENTS.md`).
   `AGENTS.md` ≤ 150 dòng.
4. **Điền placeholder** `<...>` bằng fact đã khảo sát. `.claude/harness.env`: `HARNESS_MODEL_STYLE`, `HARNESS_APP_FLAG` nếu multi-app, `HARNESS_PACKS` nếu detect sai (monorepo). `.github/workflows/harness.yml`: `HARNESS_REPO`, `HARNESS_REF` (tag, không để `main`), xoá khối của stack không dùng. Placeholder chưa biết → để nguyên và liệt kê trong report.
5. **Baseline**:
   ```bash
   bash <plugin harness>/engine/check.sh      > /tmp/harness-baseline.txt; echo $?
   bash <plugin harness>/engine/docs-check.sh
   ```
   Không sửa vi phạm cũ trong bước này. Tổng hợp theo rule id → `docs/tech-debt-tracker.md` (1 dòng/rule: số vi phạm, file tiêu biểu), chấm `docs/QUALITY_SCORE.md` lần đầu. Rule có quá nhiều vi phạm hợp lệ → đề xuất user tắt qua `HARNESS_DISABLE`, đừng tự tắt.
6. `docs-check.sh` phải exit 0 cho chính các doc vừa tạo.

**Cập nhật harness** (lên version mới, thêm stack): chạy lại bước 2, rồi bước 6. File đã sửa tay không bị ghi đè; xem dòng "giữ" để quyết định có merge template mới không.

## Report

Output của scaffold · placeholder còn trống · baseline vi phạm theo rule id · đề xuất bước tiếp (sửa nhóm vi phạm nào trước, có nên lên lịch `harness-gardening` không).

## Không làm

- Không commit, không push, không sửa code app trong lúc init.
- Không chép nội dung skill vào docs của repo.
- Không sửa tay khối giữa `<!-- harness:stack:start -->` và `<!-- harness:stack:end -->`.
