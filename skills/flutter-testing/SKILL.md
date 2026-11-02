---
name: flutter-testing
description: Viết/sửa test cho bộ base Flutter — chọn tầng test (unit VM, widget Page, integration), fake/mock service qua get_it, pump/finder ổn định, async/time deterministic. Dùng khi thêm test, sửa test fail/flaky, hoặc cần test cho logic vừa viết.
---

# Flutter testing

Phỏng theo `flutter-testing` của BOW Skills (MIT) — xem `THIRD_PARTY_NOTICES.md`. Test là vòng phản hồi mà hook Stop và CI dựa vào — logic mới không tầm thường phải có test.

## Chọn tầng rẻ nhất mà vẫn fail đúng lý do

| Tầng | Dùng cho | Đặt ở |
|---|---|---|
| `test` (unit) | Logic VM (state, cờ loading, optimistic revert), model `fromJson`, enum `fromString`, validator, util | `test/<mirror lib path>_test.dart` |
| `testWidgets` | 1 Page/component: render theo state, tap gọi đúng method VM | `test/…/<x>_page_test.dart` |
| `integration_test` | Flow xuyên màn, plugin thật | `integration_test/` — xem `flutter-run-and-verify` |
| golden | Hạn chế: chỉ vài component ổn định, sinh + verify trên 1 nền tảng | |

Logic chỉ test được bằng cách pump màn hình → logic đang nằm sai chỗ, chuyển vào VM. Phần lớn test là `test` thuần.

## Unit test ViewModel

VM lấy service qua `locator` → đăng ký fake/mock vào `get_it` trước khi tạo VM, reset sau mỗi test. `BaseViewModel.onInit()` chạy post-frame → trong unit test gọi trực tiếp method cần test, không dựa vào `onInit` tự chạy.

```dart
class _MockOrderQueries extends Mock implements OrderQueries {}

void main() {
  late _MockOrderQueries queries;

  setUp(() {
    queries = _MockOrderQueries();
    locator.registerSingleton<OrderQueries>(queries);
  });
  tearDown(() => locator.reset());

  test('cancel thất bại → trả lại danh sách cũ', () async {
    final order = OrderModel()..id = '1';
    when(() => queries.cancel('1')).thenThrow(Exception('net'));
    final vm = OrderListVm()..orders = [order];

    await vm.cancel(order);

    expect(vm.orders, [order]);
  });
}
```

- `mocktail` (không codegen) — thêm vào `dev_dependencies` cần hỏi user nếu chưa có.
- Cần hành vi thật (store in-memory, `StreamController`) → viết **fake**; mock chỉ để assert tương tác. Không mock model, không mock chính class đang test, không `verify` mọi lời gọi.
- Locale/i18n trong VM test: `await S.load(const Locale('<main>'))` trong `setUpAll` trước khi gọi code dùng `S.current`.
- `SharedPreferences.setMockInitialValues({})` cho code chạm `prefs`; không test nào chạm network/disk/plugin thật.

## Widget test Page

Page dùng `MixinBasePage` → bọc trong `MaterialApp` có `localizationsDelegates: [S.delegate, …]` + `ThemeData` có extension (`AppTheme.lightTheme`), đăng ký service fake vào `locator` như unit test.

```dart
testWidgets('đang load → hiện AppCircularProgress', (tester) async {
  await tester.pumpWidget(MaterialApp(theme: AppTheme.lightTheme, localizationsDelegates: const [S.delegate], home: const OrderListPage()));
  await tester.pump();
  expect(find.byType(AppCircularProgress), findsOneWidget);
});
```

- Finder: `find.byKey` / `find.byType` trước; `find.text` chỉ khi so với `S.current.<key>` (không literal — đổi copy/locale sẽ vỡ).
- `pump()` = 1 frame; `pumpAndSettle()` không bao giờ dừng nếu có animation lặp (`AppCircularProgress` lặp vô hạn!) → dùng `pump(Duration(...))`.
- I/O thật trong widget test → `tester.runAsync(...)`. Không `Future.delayed` để "đợi".
- Đổi kích thước màn: `tester.view.physicalSize = …` + `addTearDown(tester.view.resetPhysicalSize)`.

## Kỷ luật

- Test mới phải **fail trước** (đảo expectation / phá code) rồi mới tin.
- 1 test = 1 hành vi; tên test mô tả hành vi.
- Reset global state (`locator.reset()`, prefs mock) trong `setUp`/`tearDown` — singleton rò rỉ làm test phụ thuộc thứ tự.
- Chạy: `fvm flutter test` (CI chạy lại; hook Stop không chạy test để giữ nhanh).
