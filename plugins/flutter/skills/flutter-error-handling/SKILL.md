---
name: flutter-error-handling
description: Độ tin cậy cho bộ base Flutter — 4 kênh lỗi (FlutterError, PlatformDispatcher, zone, native) trong main_*.dart, phân loại lỗi vận hành vs lỗi lập trình, ErrorWidget release, ServerError/ChangeState, crash reporting (Sentry/Crashlytics) có breadcrumb + symbolication. Dùng khi wire crash reporting, xử lý lỗi toàn app, hoặc màn hình lỗi.
---

# Flutter error handling & crash reporting

Phỏng theo `flutter-error-handling-and-crash-reporting` của BOW Skills (MIT) — xem `THIRD_PARTY_NOTICES.md`. Mục tiêu: không lỗi nào chết im lặng — hoặc thành report có stack đọc được, hoặc thành màn hình user tự phục hồi được.

## 4 kênh phải bắt — wire trong MỌI `main_*.dart`

1. `FlutterError.onError` — lỗi đồng bộ trong framework (build/layout/paint/gesture).
2. `PlatformDispatcher.instance.onError` — lỗi async không bắt từ engine; trả `true` = đã xử lý.
3. `runZonedGuarded` (bộ base đã có) — timer, microtask, future không await.
4. Native crash — chỉ SDK native (Crashlytics/Sentry) bắt được.

```dart
runZonedGuarded<Future<void>>(() async {
  WidgetsFlutterBinding.ensureInitialized();
  FlutterError.onError = (d) {
    FlutterError.presentError(d);
    if (kReleaseMode) CrashReporter.recordFlutterError(d);
  };
  PlatformDispatcher.instance.onError = (e, s) {
    CrashReporter.recordError(e, s, fatal: false);
    return true;
  };
  // … init theo thứ tự bootstrap của bộ base (dotenv → AppConfig → DI → prefs)
  runApp(const App());
}, (e, s) => CrashReporter.recordError(e, s, fatal: false));
```

`ensureInitialized()` phải ở **trong** cùng zone với `runApp`. Dùng `SentryFlutter.init(appRunner:)` thì nó tự lo zone — chọn 1 cách, không cả hai. Thêm SDK crash reporting = thêm dependency → hỏi user.

## Phân loại lỗi trước khi report

- **Lỗi vận hành** (mất mạng, 404, validation, Supabase/Dio lỗi có chủ đích) → bắt ở tầng service, chuyển thành lỗi typed / message → VM `showError(...)` hoặc `changeState(ChangeState.serverError)`. **Không** report thành crash.
- **Lỗi lập trình** (null, cast sai, `FormatException` khi parse) → không nuốt; để rơi xuống handler toàn cục và report.

```dart
} on DioException catch (e) {
  if (e.response?.statusCode == 404) throw const NotFoundFailure();
  throw const NetworkFailure();
}
```

Không `catch (e) {}` rỗng; không `catch` rộng ở service rồi trả `null` che mất bug.

## UI khi lỗi

- Trang không load được → `changeState(ChangeState.serverError)` (widget `ServerError` của base — stub thì thay bằng UI có nút thử lại gọi lại method load của VM).
- Lỗi tạm thời → `showError(S.current.<key>)` (snack-bar của base). Không bao giờ hiện exception/stack cho user.
- Release: override `ErrorWidget.builder` trả UI trung tính (bọc `Directionality` vì có thể lỗi ở trên `MaterialApp`), debug giữ màn đỏ.

## Report dùng được

- Breadcrumb điều hướng: thêm vào `AppRouteObserver` (đã có trong `app_router_base.dart`).
- Breadcrumb network: interceptor ghi method/path/status — **không** ghi body, token, header auth.
- Gắn non-PII id, version, flavor. Lọc PII trong `beforeSend`.
- Symbolication: build release với `--obfuscate --split-debug-info=build/symbols`, upload symbol mỗi bản release (tự động trong CI), lưu `build/symbols` theo version.

## Kiểm chứng

Ném thử 1 lỗi cho từng kênh (`throw` trong `build`, `Future(() => throw …)`, `Timer.run(() => throw …)`) trên bản profile/release → report có stack đã symbolicate + breadcrumb; lỗi vận hành chỉ hiện UI, không sinh report.
