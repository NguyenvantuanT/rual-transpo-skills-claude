---
name: flutter-run-and-verify
description: Tự kiểm chứng trên app Flutter đang chạy — chọn device, chạy đúng flavor, chụp màn hình trước/sau, đọc log, viết integration_test. Dùng khi tái hiện bug UI, xác nhận fix/feature trên máy, hoặc user nói chạy thử / chụp màn hình.
---

# Flutter run & verify

`flutter analyze` chỉ chứng minh code biên dịch được. Thay đổi UI/flow chưa xong cho tới khi đã thấy nó chạy. Lặp: **tái hiện → sửa → chạy lại → so sánh → lặp tới khi sạch**.

**Ngân sách context**: mỗi ảnh chụp tốn ~1.5k token — chỉ chụp ở trạng thái quyết định (trước sửa, sau sửa, lúc lỗi), không chụp mỗi bước thao tác. Log luôn lọc + giới hạn (`grep … | tail -50`), không bao giờ đọc nguyên file log.

## 1. Chọn device

```bash
fvm flutter devices                 # chọn id
fvm flutter emulators               # nếu chưa có device: fvm flutter emulators --launch <id>
adb devices                         # Android: xác nhận đã online
```

Không có device nào → dừng, báo user (đừng giả vờ đã kiểm chứng).

## 2. Chạy đúng flavor

Lệnh run lấy từ mục **Chạy** trong `CLAUDE.md` của repo. Chạy nền và ghi log ra file để đọc lại:

```bash
fvm flutter run -d <id> --flavor <flavor> -t lib/app/main_<app>_<env>.dart \
  --dart-define-from-file=.env.<env> > /tmp/flutter_run.log 2>&1 &
```

Dùng Bash `run_in_background`, rồi đợi tới khi log có `Flutter run key commands` (hoặc lỗi build) — dùng Monitor / until-loop, không `sleep` cố định. Multi-app: đổi file trong `lib/` dùng chung → chạy kiểm chứng cho **mọi** app bị ảnh hưởng.

## 3. Quan sát

| Cần | Lệnh (Android) |
|---|---|
| Màn hình | `adb -s <id> exec-out screencap -p > /tmp/shot-<bước>.png` rồi Read file ảnh |
| Log app | `/tmp/flutter_run.log`, hoặc `adb -s <id> logcat -d -t 300 \| grep -iE "flutter\|exception\|error"` |
| Thao tác | `adb -s <id> shell input tap <x> <y>`, `input text "<chuỗi>"`, `input keyevent 4` (back) |
| Hot reload | ghi `r` vào stdin của process run; thay đổi `main`/DI/router → hot restart `R` hoặc chạy lại |

iOS simulator: `xcrun simctl io booted screenshot /tmp/shot.png`, log qua `/tmp/flutter_run.log`.

Chụp **trước** khi sửa (tái hiện bug) và **sau** khi sửa (cùng thao tác) — report kèm cả hai.

## 4. Biến kiểm chứng thành test

Flow vừa kiểm chứng tay mà quan trọng → viết `integration_test/<feature>_test.dart`:

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('<feature>: <hành vi>', (tester) async {
    // khởi tạo giống main_<app>_<env>.dart: dotenv → AppConfig → setUpInjector → SharedPrefs → pumpWidget(App)
    await tester.pumpAndSettle();
    expect(find.byType(<Widget>), findsOneWidget);
  });
}
```

Chạy: `fvm flutter test integration_test/<feature>_test.dart -d <id> --flavor <flavor>`. Dự án chưa có `integration_test` trong `dev_dependencies` → hỏi user trước khi thêm (thêm dependency cần duyệt).

## 5. Dọn

Dừng process `flutter run` khi xong (`q` vào stdin hoặc kill PID). Không để emulator/app chạy treo.

## Report

Device + flavor đã chạy · ảnh trước/sau · log lỗi (nếu còn) · test mới (nếu có). Không chạy được → nói rõ bước nào chặn.
