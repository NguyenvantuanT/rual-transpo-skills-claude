---
name: flutter-deployment-guide
description: Native config + release cho Flutter iOS/Android 3-flavor (dev/stg/prod) — Info.plist, AndroidManifest, build.gradle.kts, Podfile, signing, API key native, env switching, build/release, store checklist. Dùng khi đụng native config, signing, hoặc chuẩn bị release.
---

# Flutter Deployment — iOS + Android, 3 flavor

Đọc file này trước; chỉ mở file trong `references/` khi task cần đúng phần đó. Multi-app (N app × env) → thêm skill `flutter-multi-app-flavor`. Fact dự án (flavor thật, bundle ID, lệnh build) → `AGENTS.md` của repo.

## Naming

| | Convention |
|---|---|
| Flavor | `dev` / `stg` / `prod` |
| Dart entry | `lib/main_<flavor>.dart` (multi-app: `lib/app/main_<app>_<env>.dart`) |
| Env file | `.env.<flavor>` (gitignored, trừ `.env.example`) |
| Bundle / Application ID | `com.<org>.<app>.<flavor>`, **prod không suffix** |
| Display name | `<App> Dev` / `<App> Stg` / `<App>` |
| XCBuildConfiguration | `Debug-<flavor>` / `Release-<flavor>` / `Profile-<flavor>` |

Mỗi flavor có ID riêng → cài song song được trên 1 máy.

## Rule (vi phạm = bug release)

- **Secret**: không hard-code key trong Dart/Swift/Gradle; qua `.env.<env>` → `AppConfig`, native qua `Info.plist $(VAR)` / `manifestPlaceholders`. Không commit `.env.prod`; prod key chỉ ở CI secret.
- **Network**: `INTERNET` permission ở `android/app/src/main/AndroidManifest.xml` (không chỉ `debug/`). `NSAllowsArbitraryLoads` / `usesCleartextTraffic` chỉ cho dev.
- **Signing**: release Android ký bằng keystore riêng, password qua `key.properties` (gitignored), backup keystore ≥ 2 nơi. iOS archive dùng `iPhone Distribution`.
- **Manifest**: `android:label="@string/app_name"` (không literal); permission chỉ khai cái code thật dùng, privacy message cụ thể.
- **Env**: không rải `dotenv.env['KEY']` — đọc qua `AppConfig`. Không bundle `.env.prod` vào assets.
- **Release**: upload AAB (không APK); bump `versionCode` + `CURRENT_PROJECT_VERSION` mỗi lần; có Proguard thì test release build trước khi submit; `Profile-*` config riêng, không kế thừa `Debug-*`.

## Lệnh

```bash
fvm flutter run --flavor <f> -t lib/main_<f>.dart --dart-define-from-file=.env.<f>
fvm flutter build apk       --release --flavor <f> -t lib/main_<f>.dart --dart-define-from-file=.env.<f>
fvm flutter build appbundle --release --flavor prod -t lib/main_prod.dart --dart-define-from-file=.env.prod
fvm flutter build ipa       --release --flavor prod -t lib/main_prod.dart --dart-define-from-file=.env.prod
```

## Trước mỗi release

- [ ] Version bump: `pubspec.yaml`, `versionCode`, `CURRENT_PROJECT_VERSION`
- [ ] Signing config đúng keystore / Distribution identity
- [ ] `.env.prod` là key prod (không dùng dev/stg)
- [ ] Privacy policy URL truy cập được; privacy key đủ cho mọi permission
- [ ] Test trên release build thật (không chỉ debug)

## references/ — mở khi cần

| File | Khi nào |
|---|---|
| `references/setup-and-flavors.md` | Scaffold project mới: account, tool, folder, entry point, Xcode scheme, Android productFlavors |
| `references/env-and-api-keys.md` | `.env` structure, flutter_dotenv, `--dart-define`, inject API key native (AppDelegate / manifestPlaceholders) |
| `references/ios.md` | Template Info.plist, Podfile, signing từng bước, capabilities, app icon |
| `references/android.md` | Template AndroidManifest, signing + tạo keystore, Proguard/R8, Gradle/AGP version |
| `references/build-and-release.md` | Lệnh build đầy đủ, output location, cài song song 3 bản, pre-flight checklist store chi tiết |
| `references/pitfalls.md` | Bảng anti-pattern đầy đủ + bug thật đã gặp + lệnh detect nhanh khi review project khác |
| `references/ci.md` | GitHub Actions mẫu, Codemagic/Bitrise/Fastlane |
