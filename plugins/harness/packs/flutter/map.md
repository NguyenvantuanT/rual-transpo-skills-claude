### Flutter (bộ base MVVM + Provider)

- Chạy: `fvm flutter run --flavor <flavor> -t lib/app/main_<app>_<env>.dart --dart-define-from-file=.env.<env>` · test: `fvm flutter test` · analyze: `fvm flutter analyze`
- Feature nhiều file → subagent `flutter-mobile-dev`. Tự kiểm chứng trên app thật → skill `flutter-run-and-verify`.

| Việc | Skill |
|---|---|
| Kiến trúc, VM/Page, DI, router, EventBus | `flutter-mvvm-provider-architecture` |
| Dio/ApiClient, model (theo `HARNESS_MODEL_STYLE`), SharedPrefs, debounce | `flutter-networking-and-data` |
| Widget, màu, typography, list, button, form | `flutter-ui-style-guide` |
| String, ARB, locale | `flutter-internationalization` |
| Flavor, entry point, multi-app | `flutter-multi-app-flavor` |
| Native config, signing, release | `flutter-deployment-guide` |
| Test unit VM / widget Page | `flutter-testing` |
| Crash reporting, handler lỗi toàn app | `flutter-error-handling` |
| UI giật, rebuild thừa, scroll lag | `flutter-performance` |
| Push notification, deep link | `flutter-push-and-deep-link` |
