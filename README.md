# vtinter-harness

Marketplace Claude Code cho [harness engineering](https://openai.com/index/harness-engineering/): con người lái, agent làm. Việc của harness là cho agent **bản đồ** để biết đọc gì, **luật được máy ép** để không trôi, và **vòng phản hồi** để tự kiểm chứng.

Repo chia làm hai lớp:

- **Cơ chế** (plugin `harness`): engine luật, hooks, docs-check, init, gardening. Dùng chung mọi stack. Phần riêng của từng stack nằm trong **pack**, tự bật theo file đánh dấu của repo. Hook không tốn context nên cài thừa pack cũng không sao.
- **Tri thức** (các plugin còn lại): skill theo stack. Mô tả của mỗi skill nằm trong context ở mọi lượt, nên chỉ cài cái dự án cần.

## Plugin

| Plugin | Khi nào cài | Nội dung |
|---|---|---|
| `harness` | Mọi repo app | `engine/` (check.sh, docs-check.sh, scaffold.sh), `packs/` (flutter, supabase, web_ts), `hooks/`, agent `reviewer` + `evaluator`, skill `harness-init` + `harness-gardening`, `templates/` (AGENTS.md, CLAUDE.md, docs/, CI) |
| `core` | Mọi dự án | `ui-ux-pro-max` (từ [nextlevelbuilder/ui-ux-pro-max-skill](https://github.com/nextlevelbuilder/ui-ux-pro-max-skill), MIT), `frontend-design`, `ai-code-review`, `datetime-and-money`, `offline-sync` |
| `web` | Web Next.js (App Router) + React | Skill Next.js/React: kiến trúc route, data fetching, UI component, auth/bảo mật, test, hiệu năng, i18n, run-and-verify; agent `nextjs-web-dev` |
| `nestjs` | BE NestJS + Prisma | Skill NestJS: kiến trúc module, API design, Prisma, auth/bảo mật, queue/cron, observability, test, run-and-verify; agent `nestjs-backend-dev` |
| `flutter` | App Flutter bộ base MVVM + Provider | Skill `flutter-*` (kiến trúc, UI, data, i18n, test, lỗi, hiệu năng, push/deep link, flavor, deploy, run-and-verify), agent `flutter-mobile-dev` |
| `supabase` | Có thư mục `supabase/` | `supabase-security-review` |
| `flutter-supabase` | Flutter + Supabase | `flutter-supabase-queries` |

## Pack

| Pack | Bật khi có | Luật (T0, mỗi edit) | Verify (T1, trước khi dừng) | Test liên quan (T1) |
|---|---|---|---|---|
| `flutter` | `pubspec.yaml` | `!`, Navigator, màu/nút/tap/progress thô, text cứng, comment, import `.gr.dart`, rẽ nhánh app, hướng import giữa layer, kiểu model, file size, ARB thiếu key, version `^`, `supa_in_ui` | Regen (router, l10n, `.g.dart`), `flutter analyze` | `flutter test` cho `test/**/<tên>_test.dart` của file đổi |
| `supabase` | `supabase/` | View thiếu `security_invoker`, `WITH CHECK` chỉ so uid, CORS `*`, secret hard-code | `squawk` cho migration (nếu máy có cài) | — |
| `web_ts` | `tsconfig.json` | `any`, `@ts-ignore`, `console.log` | `tsc`, `eslint`, `dependency-cruiser` của dự án (nếu đã cài) | `vitest related` / `jest --findRelatedTests` |
| `nextjs` | `next.config.*` | `<img>`, `<a>` nội bộ, `next/router`, secret `NEXT_PUBLIC_*`, file `'use client'` kéo code server, `dangerouslySetInnerHTML`, `key={index}` | (do `web_ts`) | (do `web_ts`) |
| `nestjs` | `nest-cli.json` | Input không DTO, tự `new` service, raw SQL ghép chuỗi, `process.env` rải rác, `throw new Error` | Schema Prisma đổi mà chưa có migration, `prisma validate` | (do `web_ts`) |
| `python` | `pyproject.toml`, `requirements.txt` | `except:` trần, nuốt lỗi, `print`, debugger, `type: ignore` trần, SQL f-string | `ruff`, `mypy`/`pyright` | `pytest` test liên quan |
| `go` | `go.mod` | Bỏ qua error `_ =`, `panic`, `fmt.Println`, `context.Background()` giữa request, SQL Sprintf | `gofmt`, `go vet`, `golangci-lint` | `go test` package đổi |
| `godot` | `project.godot` | `print`, biến không type, path `../`, `find_child` | `gdlint`, `gdformat` | GUT test liên quan |
| `unity` | `ProjectSettings/ProjectVersion.txt` | `GameObject.Find`, `Debug.Log`, field public, coroutine bằng string, `Camera.main` | Compile batchmode (khi đặt `HARNESS_UNITY`) | EditMode test |

**Monorepo**: pack tự bật theo marker ở root repo, thư mục con cấp 1, hoặc `apps|packages|services|libs/*`. Mỗi app được kiểm bằng luật của chính nó, verify/test chạy trong thư mục app. Detect sai thì ghi rõ `HARNESS_PACKS="nextjs:apps/web nestjs:apps/api ..."`.

Mỗi pack còn có `map.md`: mảnh bản đồ (lệnh chạy/test, bảng việc → skill) được ghép vào mục Stack của `AGENTS.md`, và bảng path → skill để hook nhắc load skill đúng lúc.

Gate chung mọi stack: plan có acceptance criteria tick hết (hoặc nằm ở `completed/`) phải có dòng `- <ngày> đạt hết` của evaluator trong mục `## Evaluator` (rule `plan_eval`).

Thêm stack (web, BE...) = thêm `plugins/harness/packs/<name>/` theo [hợp đồng pack](plugins/harness/packs/README.md) (có checklist pack mới), không sửa engine.

## Luồng chạy

```
yêu cầu → Claude đọc CLAUDE.md → @AGENTS.md (mục lục + bảng việc → skill theo stack)
  → việc lớn: exec plan ở docs/exec-plans/active/ (giao thức phiên trong docs/PLANS.md)
  → đầu phiên: session_start nạp pack đang bật + plan đang dở (bước tiếp theo)
  → mỗi Edit/Write:
      pre_edit  — chặn file generated; sửa .claude/harness.env → hỏi user; file thuộc domain có skill mà chưa load → nhắc 1 lần
      post_edit — check.sh, chỉ dòng mới → lỗi thì tự sửa
  → mỗi lệnh Bash: pre_bash — chặn ghi file generated bằng shell; hỏi user trước --no-verify, push --force, reset --hard, clean -f
  → định dừng: stop_verify (check + docs-check + verify của từng pack → test liên quan → gate evaluator của plan) → fail thì phải làm tiếp
  → xong việc lớn: subagent evaluator kiểm acceptance criteria (chạy test, chạy app, xem màn hình), ghi kết quả vào plan
  → trước PR: subagent reviewer review diff (chỉ đọc)
  → PR: CI chạy lại engine (theo tag của harness)
định kỳ: harness-gardening → PR dọn rác nhỏ
```

Hooks chỉ chạy ở repo đã init (có `.claude/harness.env`) hoặc có pack khớp, nên repo khác không bị ảnh hưởng.

## Cài vào repo app

```
/plugin marketplace add <đường dẫn hoặc git URL của repo này>
/plugin install harness@vtinter-harness
/plugin install core@vtinter-harness
/plugin install web@vtinter-harness                # web Next.js
/plugin install nestjs@vtinter-harness             # BE NestJS
/plugin install flutter@vtinter-harness            # app Flutter
/plugin install supabase@vtinter-harness           # có Supabase
/plugin install flutter-supabase@vtinter-harness   # Flutter + Supabase
```

Rồi nhờ Claude: **"init harness cho repo này"** (skill `harness-init`). Skill chạy `scaffold.sh` để tạo `AGENTS.md` (có bản đồ theo stack), `CLAUDE.md`, `ARCHITECTURE.md`, `docs/`, `.claude/harness.env`, `.github/workflows/harness.yml` và `.claude/harness.lock`, điền thông tin dự án, rồi chạy baseline.

Cập nhật harness hoặc thêm stack: chạy lại init. File đã sửa tay không bị ghi đè (so hash trong `harness.lock`), khối Stack trong `AGENTS.md` luôn được sinh lại.

Chạy tay từ root repo app:

```bash
bash <plugin harness>/engine/check.sh            # cả repo
bash <plugin harness>/engine/check.sh lib/a.dart # vài file
bash <plugin harness>/engine/docs-check.sh
```

## Tiết kiệm token

- **Skill nạp từng lớp**: `SKILL.md` khoảng 40–70 dòng chứa rule + checklist. Chi tiết và code mẫu nằm ở `references/`, agent chỉ mở khi cần.
- **Chỉ check dòng vừa đổi**: hook và CI chạy `check.sh` với `HARNESS_DIFF`, nên vi phạm cũ không kéo agent ra khỏi task. Nợ cũ do `harness-gardening` dọn (chế độ quét toàn bộ).
- **Hook Stop có cache**: trạng thái code không đổi thì không chạy lại. Output của `check.sh` bị giới hạn 60 dòng, `flutter analyze` chỉ đưa vào tối đa 20 dòng lỗi.
- **Subagent chỉ cho việc lớn**: sửa nhỏ thì làm trực tiếp. Subagent khởi động lạnh, chỉ đáng dùng khi feature nhiều file.

## Thêm rule

Lỗi agent mắc lặp lại mà chưa bị bắt → thêm một dòng `flag <id> '<regex>' '<vấn đề> → <cách sửa>' '<path bỏ qua>'` vào `_rules()` của pack tương ứng. Message phải chỉ **cách sửa**, vì nó được đưa thẳng vào context của agent. Sau đó:

1. Thêm rule id vào danh sách trong `plugins/harness/templates/harness.env`.
2. Thêm một dòng vi phạm vào `plugins/harness/engine/test/fixture/change/`, chạy `UPDATE=1 bash plugins/harness/engine/test/run.sh`, đọc diff của `expected/output.txt`.
3. `bash plugins/harness/engine/test/run.sh` phải PASS trước khi commit.

Test của chính repo này: `bash plugins/harness/engine/test/run.sh` (CI: `.github/workflows/test.yml`, chạy cả Ubuntu lẫn macOS vì hook chạy bằng `/bin/bash` 3.2 + BSD sed trên Mac — tránh `\s`, `sed -i` không đuôi, `case` không có `(` trong `$(...)`).

Yêu cầu: `bash` (Git Bash trên Windows), `git`. Pack flutter cần `fvm` hoặc `flutter` trong PATH. Agent `reviewer` dùng skill `ai-code-review` của plugin `core`.
