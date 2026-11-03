# Build, run, pre-flight checklist

# 6. Build & Run commands

## 6.1 Local development

```bash
# Dev (load .env.dev tự động)
flutter run --flavor dev -t lib/main_dev.dart --dart-define-from-file=.env.dev

# Staging
flutter run --flavor stg -t lib/main_stg.dart --dart-define-from-file=.env.stg

# Production (test trên máy thật)
flutter run --flavor prod -t lib/main_prod.dart \
  --dart-define=BASE_URL=https://api.acme.com \
  --dart-define=GOOGLE_API_KEY_IOS=AIzaSyI_PROD_...
```

## 6.2 Build APK / IPA

```bash
# Android — dev APK
flutter build apk --debug --flavor dev -t lib/main_dev.dart --dart-define-from-file=.env.dev

# Android — staging APK
flutter build apk --release --flavor stg -t lib/main_stg.dart --dart-define-from-file=.env.stg

# Android — production AAB (cho Play Store)
flutter build appbundle --release --flavor prod -t lib/main_prod.dart \
  --dart-define=BASE_URL=https://api.acme.com

# iOS — dev (cần Xcode mở trước để signing)
flutter build ios --debug --flavor dev -t lib/main_dev.dart --dart-define-from-file=.env.dev

# iOS — production IPA (cho App Store / TestFlight)
flutter build ipa --release --flavor prod -t lib/main_prod.dart \
  --dart-define=BASE_URL=https://api.acme.com
```

## 6.3 Build output location

| Platform | Output |
|---|---|
| Android APK debug | `build/app/outputs/flutter-apk/app-dev-debug.apk` |
| Android APK release | `build/app/outputs/flutter-apk/app-prod-release.apk` |
| Android AAB release | `build/app/outputs/bundle/prodRelease/app-prod-release.aab` |
| iOS IPA | `build/ios/ipa/<flavor>.ipa` |

## 6.4 Cài song song 3 bản trên máy thật

Vì bundle/application ID khác nhau → 3 bản dev/stg/prod cài cùng lúc được:

```bash
# Android
adb install build/app/outputs/flutter-apk/app-dev-debug.apk
adb install build/app/outputs/flutter-apk/app-stg-release.apk
adb install build/app/outputs/bundle/prodRelease/app-prod-release.aab

# iOS — dùng Xcode → Window → Devices and Simulators → chọn device → + drag IPA
```

---

# 7. Pre-flight checklist trước khi submit store

## 7.1 Chung

- [ ] **API key production** đã đổi từ dev/stg (Google Maps, Firebase, RevenueCat, …).
- [ ] **Crash reporting** (Crashlytics / Sentry) bật cho prod, tắt cho dev.
- [ ] **Analytics** đã bật + event quan trọng đã log.
- [ ] **Privacy policy URL** đã có + link trong store listing + trong app.
- [ ] **Terms of service** (nếu cần theo ngành).
- [ ] **App icon** + splash screen đúng brand, không có placeholder.
- [ ] **Tất cả locale** đã test (đặc biệt RTL nếu support Arabic).
- [ ] **Debug code** (print, debugPrint, TODO, FIXME) đã dọn — grep `console.log` / `debugPrint` trước khi build release.
- [ ] **App version** (`versionCode` Android, `CFBundleVersion` iOS) đã bump.
- [ ] **CHANGELOG** đã cập nhật cho release mới.

## 7.2 iOS

- [ ] **Bundle ID unique** cho từng flavor (3 ID khác nhau).
- [ ] **Code signing identity** = `iPhone Distribution` (không phải `iPhone Developer` cho archive).
- [ ] **Provisioning profile** đúng App ID + capability.
- [ ] **Capabilities** cần thiết đã bật (Push, Background Modes, App Group).
- [ ] **Privacy keys** trong Info.plist đầy đủ cho mọi permission thực sự dùng.
- [ ] **Privacy manifest** (`PrivacyInfo.xcprivacy`) đã khai báo nếu dùng SDK tracking (required từ 2024).
- [ ] **App Store Connect** metadata đầy đủ: name, subtitle, description, keywords, screenshots (3 size: 6.5", 5.5", 12.9"), icon 1024x1024.
- [ ] **TestFlight** đã pass ít nhất 1 round external testing.
- [ ] **Export compliance** (encryption) đã khai báo đúng.
- [ ] **NSAppTransportSecurity** không có `NSAllowsArbitraryLoads=true` cho prod.

## 7.3 Android

- [ ] **`INTERNET` permission** có trong `main/AndroidManifest.xml` (không chỉ debug).
- [ ] **applicationId unique** cho từng flavor.
- [ ] **Release signing config** KHÔNG dùng debug keystore — verify trong `build.gradle.kts`.
- [ ] **minSdkVersion ≥ 24** (Google Play yêu cầu từ 2024).
- [ ] **targetSdkVersion = 34** (Google Play yêu cầu hiện tại).
- [ ] **Proguard/R8** đã bật + rules đầy đủ cho app + SDK.
- [ ] **AAB build** (không APK) cho Play Store upload.
- [ ] **Play Console listing** đầy đủ: title, short description, full description, screenshots, feature graphic 1024x500, icon 512x512.
- [ ] **Content rating** đã điền (IARC questionnaire).
- [ ] **Target audience & content** đã khai báo (cho GDPR / Kids COPPA).
- [ ] **Data safety form** đã điền (bắt buộc từ 2023).
- [ ] **App Bundle Explorer** check: không có resource thừa, không có string debug.

---

