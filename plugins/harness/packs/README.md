# Pack

Một pack = luật máy + verify cho một stack. Engine (`../engine`) lo phần chung: đọc `.claude/harness.env`, chỉ báo dòng mới (`HARNESS_DIFF`), gom output, hooks. Pack chỉ khai báo stack của nó.

`packs/<name>/pack.sh` được `source` bằng bash. `<name>` phải là tên biến bash hợp lệ (`web_ts`, không phải `web-ts`).

| Khai báo | Bắt buộc | Ý nghĩa |
|---|---|---|
| `<name>_markers` | có | Glob tính từ root của pack, có một cái tồn tại → pack bật ở thư mục đó. `HARNESS_PACKS` trong `harness.env` ghi đè |
| `<name>_detect()` | không | Marker theo nội dung, chỉ gọi khi không glob nào khớp (cwd = root repo). In ra các root, mỗi dòng một: `.` hoặc root app của pack đã detect trước (`$roots`, pack xếp theo tên). Giữ nhanh: chạy ở mọi hook |
| `<name>_files` | có | Pathspec cho `git ls-files` khi quét toàn bộ (`check.sh` không tham số) |
| `<name>_rules()` | có | Gọi cho **mọi** file được kiểm, kể cả file của pack khác → tự `case "$rel"` để lọc. Dùng `flag` hoặc ghi thẳng vào `$msgs` |
| `<name>_generated` | không | Regex path file sinh ra: hook chặn sửa, engine bỏ qua |
| `<name>_generated_msg` | không | Cách sửa khi bị chặn (sửa nguồn nào, chạy lệnh gì) |
| `<name>_verify()` | không | T1, chạy trong Stop hook với `$changed` (file đổi, path tương đối). Ghi lỗi vào `$msgs`. Giữ dưới ~1–2 phút |
| `<name>_test()` | không | T1 test, chạy sau `_verify` và chỉ khi `$msgs` còn rỗng. Chỉ chạy test **liên quan** tới `$changed` (runner của dự án), không tìm thấy test → im. Tắt chung bằng rule id `test` |
| `<name>_skills` | không | Mỗi dòng `regex path=tên skill`, dòng khớp đầu tiên thắng. Sửa file khớp mà skill chưa load trong phiên → hook nhắc 1 lần |
| `map.md` | nên có | Mảnh bản đồ cho `AGENTS.md` (mục Stack): lệnh chạy/test, bảng việc → skill, subagent. `scaffold.sh` ghép theo pack đang bật |

**Root của pack** = thư mục chứa marker: root repo, thư mục con cấp 1, hoặc `apps|packages|services|libs/*` (monorepo). Một pack có thể có nhiều root; file thuộc root sâu nhất chứa nó. Pack chỉ thấy file trong root của mình.

Biến có sẵn trong `_rules`: `$file` (path đọc được), `$rel` (path **tính từ root của pack**: viết `case` như thể app nằm ở root repo), `$rpath` (path từ root repo, dùng cho lệnh git), `$added` (dòng mới hoặc `ALL`), `$diff_base`, `$disabled`. Hàm có sẵn: `flag`, `only_added`, `in_base <rpath>`, `cfg`, `relpath`, `off <rule_id>`, `tool <tên>` (binary trong `node_modules/.bin`, `.venv/bin` hoặc PATH). Regex secret dùng chung: `$HARNESS_SECRET_RE`.

`_verify` và `_test` chạy **trong từng root** (cwd = root của pack, `$changed` = file đổi tính từ root đó), nên lệnh như `npx tsc -p .` hay `go test ./...` chạy đúng app.

```bash
flag <rule_id> '<regex>' '<vấn đề> → <cách sửa>' ['<regex path bỏ qua>'] ['<regex dòng bỏ qua>']
```

Message phải chỉ **cách sửa**: nó đi thẳng vào context của agent. Rule id phải tắt được qua `HARNESS_DISABLE` và được liệt kê trong `../templates/harness.env`.

Stack đã có linter tốt (eslint, dependency-cruiser, import-linter, squawk...) → trong `_verify` gọi công cụ đó và chuyển output thành `- [rule_id] … → cách sửa`, đừng viết lại bằng regex. Công cụ không có trên máy thì bỏ qua (`command -v`), không báo lỗi.

## Thêm pack

1. Tạo `packs/<name>/pack.sh` theo bảng trên và `packs/<name>/map.md`. Thêm rule id vào `../templates/harness.env`, khối CI vào `../templates/ci/harness.yml`.
2. Thêm fixture vào `../engine/test/fixture/` (base + change có vi phạm), chạy `UPDATE=1 bash ../engine/test/run.sh`, đọc diff của `expected/output.txt` rồi commit.
3. Checklist pack mới (web, BE...): marker · rule T0 cho lỗi agent hay lặp mà linter sẵn có bỏ sót · `_verify` gọi typecheck/lint/kiểm layer của dự án · `_test` chạy test liên quan · `_generated` · `map.md` có lệnh chạy/test và cách agent **tự nhìn** kết quả (UI: Playwright/DevTools; BE: gọi endpoint, đọc log) · khối CI.
4. Không phải sửa engine. Nếu phải sửa → hợp đồng thiếu, sửa hợp đồng trước.
