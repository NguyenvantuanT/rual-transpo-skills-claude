---
name: flutter-multi-app-flavor
description: N app (bundle ID/icon/tên khác nhau) × M env (dev/stg/prod) từ 1 codebase Flutter — entry point, AppConfig, N router + DI, Xcode build configuration/scheme, Android flavor dimension, Podfile, audit config thiếu nhánh. Không dùng khi chỉ có 1 app nhiều env.
---

# Flutter Multi-App Flavor — N app × M env

Đọc file này trước; mở `references/` khi cần làm/sửa đúng tầng đó. Chỉ 1 app × N env → dùng `flutter-deployment-guide`, không cần ma trận 2 trục. Tên app/flavor thật của dự án → `CLAUDE.md`.

```
          dev           stg           prod
<app1> → <app1>-dev    <app1>-stg    <app1>-prod
<app2> → <app2>-dev    <app2>-stg    <app2>-prod
```

## Nguyên tắc

1. **1 codebase, 1 target `Runner`, 1 module `app`** — phân biệt app qua build configuration (iOS) / product flavor (Android). Không fork repo, không tạo target thứ 2.
2. **Chốt tên app + env 1 lần, 1 kiểu viết, mọi tầng** (Dart, scheme, XCBuildConfiguration, Gradle flavor, xcconfig). Đổi tên giữa chừng → `grep -ri "<tên cũ>" ios/ android/ lib/` và sửa hết trong 1 lần.
3. **Đủ N×M×3 config ngay từ đầu**, kể cả env chưa build thật — scheme trỏ config không tồn tại sẽ chỉ lộ ra lúc release.
4. **Bundle/Application ID unique theo (App, Env)**; prod không suffix env.
5. **Display name + icon khác theo App** — qua biến (`$(APP_DISPLAY_NAME)`, `resValue`) và asset/source set riêng theo app; build xong phải nhìn thấy tên/icon đổi thật.
6. **App quyết định code path, Env chỉ đổi config/data**: N router riêng implement `AppRouterBase`, chọn ở `setUpInjector` theo cờ app — nơi DUY NHẤT rẽ nhánh app. Không `if (appFlag)` trong routes/widget/VM.

## Naming

| | Convention | Ví dụ (`admin`/`user`) |
|---|---|---|
| Dart entry | `lib/app/main_<app>_<env>.dart` | `main_admin_dev.dart` |
| Bundle / Application ID | `com.<org>.<app>.<env>` (prod bỏ env) | `com.acme.admin.dev` |
| Display name | `<App> <Env>` (prod bỏ env) | `Admin Dev` |
| iOS scheme | `<env><App>` | `devAdmin` |
| XCBuildConfiguration | `Debug-<env><App>` / `Release-…` / `Profile-…` | `Debug-devAdmin` |
| Android flavor | dimension `app` + dimension `env` (hoặc 1 dimension gộp, xem `references/android.md`) | `admin` + `dev` |

## Anti-pattern hay gặp

- Scheme trỏ config không tồn tại (mồ côi) hoặc config trơn `Debug`/`Release` không mang flavor → `flutter run --flavor` lỗi mơ hồ.
- Copy scheme cho app mới nhưng quên sửa `buildConfiguration` bên trong.
- `CFBundleDisplayName` / `android:label` hardcode → app thứ 2 hiện tên app thứ nhất.
- Icon chỉ tách theo env, quên tách theo app.
- Flavor app này có `applicationId` riêng, flavor kia rơi về `defaultConfig`.
- Page/route class trùng tên giữa 2 router (auto_route chỉ nhìn tên class) → prefix theo app.
- Import thẳng `.gr.dart` (bị `check.sh` chặn — rule `gr_import`).
- Thêm build configuration mới mà không `pod install` lại.

## Checklist 1 nhánh (App, Env) "xong"

- [ ] Config tồn tại và `fvm flutter build` chạy được (không chỉ "có scheme")
- [ ] Log run đúng entry point; app chạy đúng router của nó
- [ ] Bundle/Application ID đúng convention, khác mọi nhánh khác
- [ ] Display name + icon đúng app — đã build ra và nhìn thấy
- [ ] Cài 2 app cùng lúc trên 1 máy, không đè nhau

## references/ — mở khi cần

| File | Khi nào |
|---|---|
| `references/dart-layer.md` | Entry point, AppConfig 2 trục, N router + base abstraction, auto_route nhiều `@AutoRouterConfig` |
| `references/ios.md` | Tạo build configuration, xcscheme, Info.plist theo biến, asset catalog icon, Podfile `post_install` (patch `PODS_CONFIGURATION_BUILD_DIR` khi lỗi linker) |
| `references/android.md` | `flavorDimensions` 2 trục hoặc 1 dimension gộp, source set icon/tên, build command |
| `references/conflicts.md` | Chi tiết từng conflict ở trên + lệnh detect |
| `references/audit.md` | Bộ lệnh audit 1 project multi-app có sẵn + script `xcodeproj` thêm config an toàn |
