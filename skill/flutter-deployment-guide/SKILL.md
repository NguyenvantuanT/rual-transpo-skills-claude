---
name: flutter-deployment-guide
description: |
  Hướng dẫn triển khai (scaffold + build + release) Flutter mobile app cho iOS + Android theo pattern 3-flavor chuẩn (dev / stg / prod). Cover toàn bộ setup: multi-flavor Dart entry + iOS Xcode scheme + Android productFlavors, env switching qua flutter_dotenv + --dart-define, native API key injection, signing cho cả 2 platform, build/release commands, và pre-flight checklist trước khi submit App Store / Play Store.
  Sử dụng khi: scaffold project Flutter mới cần multi-flavor, setup Apple Developer / Play Console signing, fix bug liên quan config native (Info.plist, AndroidManifest, build.gradle.kts), chuẩn bị bản release, hoặc review deployment config của project khác.
---

# Flutter Deployment Guide — iOS + Android (3-flavor)

> **⚠️ Trạng thái `rual_transpo_rider_mobile` hiện tại KHÁC template này**: repo có **cả 2 trục** — App (Rider/Driver) **×** Env (dev/stg/prod) — nhưng trục Env mới chỉ setup xong ở tầng Gradle (6 `productFlavors`: `developmentRider/stagingRider/productionRider/developmentUser/stagingUser/productionUser`), chưa đủ ở tầng Dart (chỉ có entry `main_rider_dev.dart`/`main_driver_dev.dart` — thiếu `_stg`/`_prod`) và chưa tách `applicationId`/bundle ID riêng theo từng env. Setup thật + gap chi tiết mô tả ở `flutter-multi-app-flavor/SKILL.md`. Skill này là **template chuẩn 1-app × 3-env** — dùng khi scaffold project MỚI, setup signing, hoặc tra cứu native config / store checklist (các phần đó áp dụng nguyên vẹn cho từng app riêng lẻ của `rual_transpo_rider_mobile`, nhân đôi cho cả Rider lẫn Driver).

## Tổng quan

Mục tiêu: tạo một Flutter mobile app có thể build & chạy ở **3 môi trường độc lập** (dev / stg / prod) với:

- **Bundle ID / Application ID riêng** cho mỗi flavor (cài song song được trên cùng 1 máy).
- **API key / base URL / env vars riêng** cho mỗi flavor, switch qua CLI flag.
- **App icon & display name riêng** cho mỗi flavor.
- **Signing đầy đủ** cho cả iOS (Apple Developer) lẫn Android (Play Console keystore).
- **Code Dart dùng chung**, không fork theo flavor.

Convention này là template chuẩn 1-app × 3-env, đã đối chiếu thực tế với setup 2-app (Rider/Driver) của `rual_transpo_rider_mobile` — nhiều bug thường gặp bên dưới (§9) lấy từ chính review đó.

## Khi nào sử dụng

- **Scaffold project mới** cần multi-flavor từ đầu (startup mới, contract mới).
- **Setup signing** cho Apple Developer / Play Console account mới.
- **Setup env switching** giữa dev / stg / prod (Flutter dotenv + dart-define + native injection).
- **Fix bug native config**: thiếu permission, sai bundle ID, hard-code API key, debug keystore dùng cho release.
- **Pre-flight check** trước khi submit App Store / Play Store.
- **Review deployment config** của project khác (Freelance / take-over codebase).

## Khi nào KHÔNG sử dụng

- Đã có sẵn project chạy ổn — chỉ sửa feature code, không đụng native config → dùng `flutter-mvvm-provider-architecture`.
- Cần setup backend (Firebase / API riêng) → xem `flutter-networking-and-data` (project này dùng Dio/REST qua `ApiClient`, không có Supabase).
- Cần i18n / locale handling → dùng `flutter-internationalization`.

Skill này **không cover**:
- Kiến trúc code (VM / Page / DI) — đã có skill riêng.
- Backend API / database — ngoài scope.
- Design system / UI style — đã có `flutter-ui-style-guide` + `frontend-design`.
- CI/CD chi tiết (Fastlane / GitHub Actions / Codemagic) — chỉ nhắc ở §10; tham khảo tài liệu riêng nếu cần.

## Quy ước đặt tên trong skill này

| Khái niệm | Convention |
|---|---|
| Flavor name | `dev` / `stg` / `prod` (lowercase, ngắn) |
| Dart entry | `lib/main_dev.dart` / `main_stg.dart` / `main_prod.dart` |
| Env file | `.env.dev` / `.env.stg` / `.env.prod` |
| iOS scheme | `dev` / `stg` / `prod` (Flutter tự generate) |
| Android flavor | `dev` / `stg` / `prod` (productFlavors) |
| Bundle ID | `com.<org>.<app>.dev` / `.stg` / `.prod` (iOS) |
| Application ID | `com.<org>.<app>.dev` / `.stg` / `.prod` (Android) |
| App display name | `<App Name> Dev` / `Stg` / `Prod` (hoặc chỉ `<App Name>` cho prod) |

Ví dụ cho project tên "acme":
- iOS: `com.acme.app.dev` / `.stg` / `.prod`
- Android: `com.acme.app.dev` / `.stg` / `.prod`
- App name: `Acme Dev` / `Acme Stg` / `Acme`

> **Quy tắc quan trọng**: Mỗi flavor PHẢI có bundle/application ID riêng để có thể cài song song 3 bản trên cùng 1 máy thật. Nếu không, dev chỉ có thể test 1 flavor tại 1 thời điểm.

---

# 1. Chuẩn bị trước khi bắt đầu

## 1.1 Account & quyền cần có

| Service | Cần gì | Dùng cho |
|---|---|---|
| **Apple Developer Program** ($99/năm) | Team ID (10 ký tự, vd `J96CHAV8L7`), App ID prefix, signing cert, provisioning profile | iOS code signing, App Store Connect, TestFlight |
| **Google Play Console** ($25/lifetime) | Service account JSON (cho CI/CD), app signing key, internal test track | Android release signing, Play Store listing |
| **Apple App Store Connect** | App record cho mỗi flavor (dev thường không cần, stg/prod cần) | Submit iOS app |
| **Backend project (Firebase / API riêng)** | Project ID, API key, service account | Nếu dùng backend managed |
| **Google Cloud Console** | Maps API key (Android + iOS riêng), billing enabled | `google_maps_flutter` |
| **RevenueCat / AppsFlyer** | Public API key (Dart-side), private key (server-side) | Nếu dùng IAP / attribution |

> ⚠️ **KHÔNG commit secret thật vào git.** Chỉ commit `.env.example` (placeholder). API key thật để local trong `.env.<env>` (gitignore) hoặc CI secret.

## 1.2 Tool cần cài

```bash
# FVM (Flutter Version Manager)
brew tap leoafarias/fvm && brew install fvm

# Flutter qua FVM (version phải khớp .fvmrc của team)
fvm install 3.44.0
fvm use 3.44.0

# Xcode + Command Line Tools
xcode-select --install
sudo xcode-select -s /Applications/Xcode.app/Contents/Developer

# CocoaPods (iOS dependency)
sudo gem install cocoapods

# Android Studio + SDK 34+ + cmdline-tools
# (download từ https://developer.android.com/studio)

# (Optional) Fastlane cho CI/CD
brew install fastlane
```

## 1.3 Folder structure dự kiến

```
<project>/
├── .env.example                ← committed, chỉ placeholder
├── .env.dev                    ← gitignored
├── .env.stg                    ← gitignored
├── .env.prod                   ← gitignored
├── .fvmrc                      ← commit version pin
├── .gitignore                  ← phải ignore .env.* (trừ .example)
├── pubspec.yaml
├── lib/
│   ├── main_dev.dart           ← entry dev
│   ├── main_stg.dart           ← entry stg
│   ├── main_prod.dart          ← entry prod
│   └── app/
│       └── app_config.dart     ← singleton đọc env
├── ios/
│   ├── Runner.xcodeproj/
│   │   └── xcshareddata/xcschemes/  ← dev.xcscheme, stg.xcscheme, prod.xcscheme
│   ├── Runner/
│   │   ├── Info.plist
│   │   └── AppDelegate.swift
│   ├── Flutter/
│   │   ├── Debug.xcconfig      ← FLUTTER_TARGET=lib/main_dev.dart
│   │   ├── Release.xcconfig    ← tương tự cho prod
│   │   └── Staging.xcconfig    ← tương tự cho stg
│   └── Podfile
└── android/
    ├── key.properties          ← gitignored (chứa keystore credential)
    ├── app/
    │   ├── build.gradle.kts    ← productFlavors + signingConfigs
    │   ├── key.properties      ← gitignored
    │   └── src/
    │       ├── main/AndroidManifest.xml
    │       ├── dev/res/values/strings.xml     ← app_name="App Dev"
    │       ├── stg/res/values/strings.xml
    │       └── prod/res/values/strings.xml
    └── gradle.properties
```

---

# 2. Multi-flavor setup

Pattern: **3 Dart entry points** → Flutter CLI mapping tới 3 iOS scheme + 3 Android flavor → mỗi flavor load env file riêng + bundle ID riêng.

## 2.1 Dart entry points (3 file)

Mỗi file chỉ khác nhau ở 2 dòng: env file name + AppConfig. Phần còn lại import chung.

```dart
// lib/main_dev.dart
import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'app/app_config.dart';
import 'app/bootstrap.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await dotenv.load(fileName: '.env.dev');          // ← khác biệt duy nhất
  AppConfig.init(flavor: 'dev');                    // ← khác biệt duy nhất
  await bootstrap();
}
```

```dart
// lib/main_stg.dart  — tương tự, .env.stg + flavor 'stg'
// lib/main_prod.dart — tương tự, .env.prod + flavor 'prod'
```

```dart
// lib/app/bootstrap.dart — code chung cho cả 3 flavor
Future<void> bootstrap() async {
  // setup DI, runApp(App()), v.v.
}
```

```dart
// lib/app/app_config.dart
class AppConfig {
  AppConfig._();
  static late final String flavor;
  static late final String baseUrl;
  static late final String socketUrl;
  static late final String googleMapsApiKey;
  // ... thêm key khác tùy project

  static void init({required String flavor}) {
    AppConfig.flavor = flavor;
    baseUrl = dotenv.env['BASE_URL'] ?? '';
    socketUrl = dotenv.env['BASE_SOCKET_URL'] ?? '';
    googleMapsApiKey = Platform.isIOS
        ? (dotenv.env['GOOGLE_API_KEY_IOS'] ?? '')
        : (dotenv.env['GOOGLE_API_KEY_ANDROID'] ?? '');
    // assert trong debug để bắt thiếu env
    assert(baseUrl.isNotEmpty, 'BASE_URL missing for flavor=$flavor');
  }
}
```

> **Rule**: KHÔNG đọc `dotenv.env[...]` rải rác trong code. Luôn qua `AppConfig.<field>`. Lý do: test mock được, đổi sang `String.fromEnvironment` không phải sửa 50 chỗ.

## 2.2 iOS — Xcode scheme + build configuration

### Bước 1: tạo 3 scheme

Cách nhanh nhất là dùng Flutter CLI:

```bash
flutter create --platforms=ios --org com.acme --project-name acme_app .
```

Sau đó mở `ios/Runner.xcodeproj` trong Xcode, tạo scheme mới:

1. **Product → Scheme → Manage Schemes…**
2. Click **+**, đặt tên `dev`, target `Runner`, shared (checkbox).
3. Lặp lại cho `stg` và `prod`.
4. Với mỗi scheme, vào **Edit Scheme… → Run → Info → Executable** = `Runner`, **Build Configuration**:
   - `dev` → `Debug-dev` (hoặc `Debug-development` tuỳ convention)
   - `stg` → `Debug-stg`
   - `prod` → `Debug-prod`

### Bước 2: tạo 9 XCBuildConfiguration

Trong Xcode, **Project → Info → Configurations**:

| Configuration | PRODUCT_BUNDLE_IDENTIFIER | FLUTTER_TARGET | APP_DISPLAY_NAME |
|---|---|---|---|
| Debug-dev | `com.acme.app.dev` | `lib/main_dev.dart` | `Acme Dev` |
| Release-dev | `com.acme.app.dev` | `lib/main_dev.dart` | `Acme Dev` |
| Profile-dev | `com.acme.app.dev` | `lib/main_dev.dart` | `Acme Dev` |
| Debug-stg | `com.acme.app.stg` | `lib/main_stg.dart` | `Acme Stg` |
| Release-stg | `com.acme.app.stg` | `lib/main_stg.dart` | `Acme Stg` |
| Profile-stg | `com.acme.app.stg` | `lib/main_stg.dart` | `Acme Stg` |
| Debug-prod | `com.acme.app.prod` | `lib/main_prod.dart` | `Acme` |
| Release-prod | `com.acme.app.prod` | `lib/main_prod.dart` | `Acme` |
| Profile-prod | `com.acme.app.prod` | `lib/main_prod.dart` | `Acme` |

> **Map `FLUTTER_TARGET`** bằng cách edit file `ios/Flutter/<config>.xcconfig`:

```xcconfig
// ios/Flutter/Debug.xcconfig
#include? "Pods/Target Support Files/Pods-Runner/Pods-Runner.debug-dev.xcconfig"
#include "Generated.xcconfig"
FLUTTER_TARGET=lib/main_dev.dart
APP_DISPLAY_NAME=Acme Dev
```

> Mỗi config có file `.xcconfig` riêng (`Debug-dev.xcconfig`, `Release-stg.xcconfig`, …) hoặc dùng `xcodebuild -config Debug-dev` switch tới đúng file.

### Bước 3: xác minh scheme chạy đúng entry

```bash
cd ios
xcodebuild -workspace Runner.xcworkspace \
  -scheme dev \
  -configuration Debug-dev \
  -sdk iphonesimulator \
  -derivedDataPath build/

# Trong log phải thấy:
# "Built /path/to/main_dev.dart"
```

## 2.3 Android — productFlavors

Edit `android/app/build.gradle.kts`:

```kotlin
android {
    namespace = "com.acme.app"
    compileSdk = 36

    defaultConfig {
        applicationId = "com.acme.app"  // base, sẽ bị flavor override
        minSdk = 24
        targetSdk = 34
        versionCode = 1
        versionName = "1.0.0"
    }

    flavorDimensions += "environment"

    productFlavors {
        create("dev") {
            dimension = "environment"
            applicationIdSuffix = ".dev"           // → com.acme.app.dev
            versionNameSuffix = "-dev"
            resValue("string", "app_name", "Acme Dev")
            // KHÔNG dùng manifestPlaceholders ở đây — xem §3.4
        }
        create("stg") {
            dimension = "environment"
            applicationIdSuffix = ".stg"           // → com.acme.app.stg
            versionNameSuffix = "-stg"
            resValue("string", "app_name", "Acme Stg")
        }
        create("prod") {
            dimension = "environment"
            // production KHÔNG suffix, applicationId = com.acme.app
            resValue("string", "app_name", "Acme")
        }
    }

    buildTypes {
        release {
            signingConfig = signingConfigs.getByName("release")  // xem §5.2
            isMinifyEnabled = true
            isShrinkResources = true
            proguardFiles(
                getDefaultProguardFile("proguard-android-optimize.txt"),
                "proguard-rules.pro"
            )
        }
    }
}
```

> **Rule**: Production flavor KHÔNG có `applicationIdSuffix` (giữ ID gốc `com.acme.app`), dev/stg suffix `.dev` / `.stg`. Lý do: Play Store chỉ chấp nhận ID gốc, suffix chỉ dùng để cài song song khi dev.

### Source set riêng cho mỗi flavor (optional)

Nếu mỗi flavor cần icon / resource khác:

```
android/app/src/
├── main/res/mipmap-*/ic_launcher.png        ← base (production default)
├── dev/res/mipmap-*/ic_launcher.png         ← override icon cho dev
├── stg/res/mipmap-*/ic_launcher.png         ← override icon cho stg
└── prod/res/mipmap-*/ic_launcher.png        ← optional, giống main thì bỏ
```

Cấu trúc `dev/` / `stg/` / `prod/` là source set mà AGP tự nhận — không cần khai báo thêm.

---

# 3. Environment switching

## 3.1 .env files structure

**3 file + 1 template**, tất cả đặt ở root project:

```bash
# .env.example (commit vào git, chỉ chứa placeholder)
MODE=development
BASE_URL=https://api.dev.example.com
BASE_SOCKET_URL=wss://socket.dev.example.com
GOOGLE_API_KEY_ANDROID=YOUR_ANDROID_KEY_HERE
GOOGLE_API_KEY_IOS=YOUR_IOS_KEY_HERE
```

```bash
# .env.dev (gitignored, dev dùng local)
MODE=development
BASE_URL=https://api.dev.acme.com
BASE_SOCKET_URL=wss://socket.dev.acme.com
GOOGLE_API_KEY_ANDROID=AIzaSyA_DEV_KEY_...
GOOGLE_API_KEY_IOS=AIzaSyI_DEV_KEY_...
```

```bash
# .env.stg — tương tự, trỏ về staging server
# .env.prod — production key, **chỉ có ở CI/CD secret store**, dev local KHÔNG có
```

`.gitignore` phải có:

```gitignore
.env
.env.dev
.env.stg
.env.prod
!.env.example
```

## 3.2 flutter_dotenv integration

Trong `pubspec.yaml`:

```yaml
dependencies:
  flutter_dotenv: ^6.0.0

flutter:
  assets:
    - .env.dev
    - .env.stg
    - .env.prod
    # KHÔNG commit .env.prod vào assets nếu key là secret — dùng --dart-define thay thế
```

> **Tip**: Với `.env.prod`, an toàn nhất là không bundle vào app. Inject qua `--dart-define=BASE_URL=... --dart-define=GOOGLE_API_KEY_IOS=...` lúc build.

## 3.3 CLI convention --dart-define

```bash
# Dev
flutter run --flavor dev -t lib/main_dev.dart --dart-define-from-file=.env.dev

# Staging
flutter run --flavor stg -t lib/main_stg.dart --dart-define-from-file=.env.stg

# Production build
flutter build apk --release \
  --flavor prod \
  -t lib/main_prod.dart \
  --dart-define=BASE_URL=https://api.acme.com \
  --dart-define=GOOGLE_API_KEY_IOS=AIzaSyI_PROD_... \
  --dart-define=GOOGLE_API_KEY_ANDROID=AIzaSyA_PROD_...
```

Lưu ý:

- `--flavor` (lowercase) match với productFlavor name trong `build.gradle.kts`.
- `-t` (target) trỏ tới main_*.dart.
- `--dart-define-from-file` chỉ dùng local dev; CI/CD nên explicit từng key để audit được.

## 3.4 API key injection native (iOS + Android)

Vấn đề: một số key phải có ở **native side** (vd Google Maps API key cho iOS phải pass qua `GMSServices.provideAPIKey`). Dotenv chỉ đọc được từ Dart.

### iOS — inject qua AppDelegate.swift

```swift
// ios/Runner/AppDelegate.swift
import Flutter
import UIKit

@main
@objc class AppDelegate: FlutterAppDelegate {
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    // Đọc API key từ Info.plist (KHÔNG hard-code)
    if let apiKey = Bundle.main.object(forInfoDictionaryKey: "GOOGLE_MAPS_API_KEY") as? String {
      GMSServices.provideAPIKey(apiKey)
    }
    GeneratedPluginRegistrant.register(with: self)
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }
}
```

Trong `Info.plist`, **mỗi flavor build sẽ nhận key khác nhau** qua `$(GOOGLE_MAPS_API_KEY)`:

```xml
<key>GOOGLE_MAPS_API_KEY</key>
<string>$(GOOGLE_MAPS_API_KEY)</string>
```

Map key trong `ios/Flutter/Debug-dev.xcconfig`:

```xcconfig
GOOGLE_MAPS_API_KEY = AIzaSyI_DEV_KEY_...
```

> Cách này **an toàn hơn** hard-code trong AppDelegate (vì key nằm trong xcconfig, mỗi flavor build có key riêng).

### Android — inject qua manifestPlaceholders

```kotlin
// android/app/build.gradle.kts
android {
    defaultConfig {
        manifestPlaceholders["GOOGLE_API_KEY"] = ""
    }
    productFlavors {
        create("dev") {
            // ❌ ĐỪNG hard-code .env.dev — xem anti-pattern §9
            // ✅ Đọc từ local.properties (gitignored) hoặc system env
            val devKey = System.getenv("GOOGLE_API_KEY_DEV") ?: ""
            manifestPlaceholders["GOOGLE_API_KEY"] = devKey
        }
        create("stg") {
            val stgKey = System.getenv("GOOGLE_API_KEY_STG") ?: ""
            manifestPlaceholders["GOOGLE_API_KEY"] = stgKey
        }
        create("prod") {
            val prodKey = System.getenv("GOOGLE_API_KEY_PROD") ?: ""
            manifestPlaceholders["GOOGLE_API_KEY"] = prodKey
        }
    }
}
```

```xml
<!-- android/app/src/main/AndroidManifest.xml -->
<application ...>
    <meta-data
        android:name="com.google.android.geo.API_KEY"
        android:value="${GOOGLE_API_KEY}" />
</application>
```

> CI/CD: truyền key qua `GOOGLE_API_KEY_DEV=... ./gradlew assembleDevDebug`.

---

# 4. iOS configuration

## 4.1 Info.plist template

```xml
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleDisplayName</key>
    <string>$(APP_DISPLAY_NAME)</string>

    <key>CFBundleIdentifier</key>
    <string>$(PRODUCT_BUNDLE_IDENTIFIER)</string>

    <key>CFBundleVersion</key>
    <string>$(FLUTTER_BUILD_NUMBER)</string>

    <key>CFBundleShortVersionString</key>
    <string>$(FLUTTER_BUILD_NAME)</string>

    <key>CFBundleName</key>
    <string>runner</string>

    <key>CFBundlePackageType</key>
    <string>APPL</string>

    <!-- ProMotion 120Hz -->
    <key>CADisableMinimumFrameDurationOnPhone</key>
    <true/>

    <!-- Chỉ iPhone, không iPad -->
    <key>LSRequiresIPhoneOS</key>
    <true/>
    <key>UIDeviceFamily</key>
    <array>
        <integer>1</integer>
    </array>

    <!-- Orientations -->
    <key>UISupportedInterfaceOrientations</key>
    <array>
        <string>UIInterfaceOrientationPortrait</string>
        <string>UIInterfaceOrientationLandscapeLeft</string>
        <string>UIInterfaceOrientationLandscapeRight</string>
    </array>

    <!-- Privacy keys — chỉ khai báo cái thực sự dùng -->
    <key>NSLocationWhenInUseUsageDescription</key>
    <string>App uses your location to show nearby items on the map.</string>

    <key>NSCameraUsageDescription</key>
    <string>App uses camera to scan QR codes.</string>

    <key>NSPhotoLibraryUsageDescription</key>
    <string>App needs photo access to upload your profile picture.</string>

    <!-- API key cho Google Maps (inject qua xcconfig) -->
    <key>GOOGLE_MAPS_API_KEY</key>
    <string>$(GOOGLE_MAPS_API_KEY)</string>

    <!-- Background mode (nếu cần) -->
    <key>UIBackgroundModes</key>
    <array>
        <string>location</string>
        <string>fetch</string>
    </array>

    <!-- App Transport Security — chỉ bật khi cần HTTP cleartext (vd dev internal) -->
    <key>NSAppTransportSecurity</key>
    <dict>
        <key>NSAllowsArbitraryLoads</key>
        <false/>
    </dict>
</dict>
</plist>
```

> **Rule**: Mỗi privacy key PHẢI có message giải thích rõ ràng — Apple review check kỹ. Message trống hoặc chung chung → bị reject.

## 4.2 Podfile template

```ruby
# ios/Podfile
platform :ios, '15.5'
use_frameworks!

ENV['COCOAPODS_DISABLE_STATS'] = 'true'

project 'Runner', {
  'Debug-dev' => :debug,
  'Release-dev' => :release,
  'Profile-dev' => :release,
  'Debug-stg' => :debug,
  'Release-stg' => :release,
  'Profile-stg' => :release,
  'Debug-prod' => :debug,
  'Release-prod' => :release,
  'Profile-prod' => :release,
}

target 'Runner' do
  use_modular_headers!

  flutter_install_all_ios_pods File.dirname(File.realpath(__FILE__))
  target 'RunnerTests' do
    inherit! :search_paths
  end
end

post_install do |installer|
  installer.pods_project.targets.each do |target|
    flutter_additional_ios_build_settings(target)
    target.build_configurations.each do |config|
      # Match deployment target với Pods
      config.build_settings['IPHONEOS_DEPLOYMENT_TARGET'] = '15.5'
      # Cho phép bitcode (Flutter cần)
      config.build_settings['ENABLE_BITCODE'] = 'NO'
    end
  end
end
```

> **Bug thường gặp** (từ rider app): nếu có multi-flavor + Pods build mismatch, Pods build vào `Debug-iphonesimulator/` (un-flavored) trong khi Runner dùng `Debug-dev-iphonesimulator/` → linker fail. Fix: thêm override `PODS_CONFIGURATION_BUILD_DIR` trong `post_install` (xem chi tiết ở §9).

## 4.3 Signing setup

### Bước 1: Apple Developer setup

1. Vào https://developer.apple.com/account → Membership → lấy **Team ID** (10 ký tự).
2. Tạo **App ID** cho mỗi flavor: `com.acme.app.dev`, `.stg`, `.prod` → enable capability cần (Push Notification, App Group, …).
3. Tạo **Provisioning Profile** cho mỗi App ID (Development + Distribution).

### Bước 2: Xcode setup

Trong Xcode → Runner target → Signing & Capabilities:

- **Team**: chọn team của bạn.
- **Provisioning Profile**: chọn "Automatic" (Xcode tự manage qua team).
- **Signing Certificate**:
  - Debug: `iPhone Developer` (auto-generated).
  - Release: `iPhone Distribution` (phải tạo qua Certificates page).

```ruby
# Trong project.pbxproj (hoặc qua Xcode UI):
# CODE_SIGN_STYLE = Automatic
# DEVELOPMENT_TEAM = J96CHAV8L7
# CODE_SIGN_IDENTITY[sdk=iphoneos*] = "iPhone Distribution"
```

### Bước 3: Capabilities (Push, App Group, Keychain Sharing)

Nếu cần Push Notification:

1. Runner → Signing & Capabilities → **+ Capability** → Push Notifications.
2. Tạo `Runner.entitlements` (Xcode tự generate).
3. Trong Apple Developer → App ID → chọn đúng App ID → enable Push Notification.
4. Test với `flutter run --release -t lib/main_dev.dart` + device thật.

> ⚠️ Capability phải **khớp** giữa Xcode project và Apple Developer App ID. Thiếu 1 bên → provisioning profile fail.

## 4.4 App icon

Khuyến nghị dùng `flutter_launcher_icons`:

```yaml
# pubspec.yaml
dev_dependencies:
  flutter_launcher_icons: ^0.14.0

flutter_icons:
  image_path: "assets/icon.png"
  ios: true
  android: true
  remove_alpha_ios: true
```

```bash
dart run flutter_launcher_icons
```

> **Bug thường gặp**: cài `flutter_launcher_icons` nhưng quên config `flutter_icons:` block → plugin bỏ không chạy. Icon giữ default Flutter logo.

---

# 5. Android configuration

## 5.1 AndroidManifest.xml template

```xml
<?xml version="1.0" encoding="utf-8"?>
<manifest xmlns:android="http://schemas.android.com/apk/res/android">

    <!-- Network — PHẢI ở main, không chỉ debug -->
    <uses-permission android:name="android.permission.INTERNET"/>

    <!-- Location -->
    <uses-permission android:name="android.permission.ACCESS_FINE_LOCATION"/>
    <uses-permission android:name="android.permission.ACCESS_COARSE_LOCATION"/>

    <!-- Camera -->
    <uses-permission android:name="android.permission.CAMERA"/>

    <!-- Photos / Storage -->
    <uses-permission android:name="android.permission.READ_EXTERNAL_STORAGE"
        android:maxSdkVersion="32"/>
    <uses-permission android:name="android.permission.READ_MEDIA_IMAGES"/>

    <!-- Notifications (Android 13+) -->
    <uses-permission android:name="android.permission.POST_NOTIFICATIONS"/>

    <application
        android:label="@string/app_name"
        android:name="${applicationName}"
        android:icon="@mipmap/ic_launcher"
        android:requestLegacyExternalStorage="false">

        <activity
            android:name=".MainActivity"
            android:exported="true"
            android:launchMode="singleTop"
            android:theme="@style/LaunchTheme"
            android:configChanges="orientation|keyboardHidden|keyboard|screenSize|smallestScreenSize|locale|layoutDirection|fontScale|screenLayout|density|uiMode"
            android:hardwareAccelerated="true"
            android:windowSoftInputMode="adjustResize">

            <meta-data
                android:name="io.flutter.embedding.android.NormalTheme"
                android:resource="@style/NormalTheme" />

            <intent-filter>
                <action android:name="android.intent.action.MAIN"/>
                <category android:name="android.intent.category.LAUNCHER"/>
            </intent-filter>
        </activity>

        <!-- Google Maps API key -->
        <meta-data
            android:name="com.google.android.geo.API_KEY"
            android:value="${GOOGLE_API_KEY}" />

        <!-- Disable Crashlytics tự động collect (set qua Firebase init) -->
        <meta-data
            android:name="firebase_crashlytics_collection_enabled"
            android:value="false" />
    </application>

    <queries>
        <intent>
            <action android:name="android.intent.action.PROCESS_TEXT"/>
            <data android:mimeType="text/plain"/>
        </intent>
    </queries>
</manifest>
```

> **Bug nghiêm trọng** (từ rider app): `INTERNET` permission chỉ trong `debug/` + `profile/` AndroidManifest → APK **release** không có quyền mạng, mọi Dio call đều fail. Luôn đặt INTERNET ở `main/`.

## 5.2 build.gradle.kts — signing

### key.properties (gitignored)

```properties
# android/key.properties — KHÔNG commit vào git
storeFile=/Users/<user>/keys/acme-release.jks
storePassword=your_store_password
keyAlias=acme
keyPassword=your_key_password
```

### build.gradle.kts

```kotlin
// android/app/build.gradle.kts
import java.util.Properties
import java.io.FileInputStream

val keystoreProperties = Properties().apply {
    val f = rootProject.file("key.properties")
    if (f.exists()) {
        load(FileInputStream(f))
    }
}

android {
    signingConfigs {
        create("release") {
            keyAlias = keystoreProperties["keyAlias"] as String?
            keyPassword = keystoreProperties["keyPassword"] as String?
            storeFile = (keystoreProperties["storeFile"] as String?)?.let { file(it) }
            storePassword = keystoreProperties["storePassword"] as String?
        }
    }

    buildTypes {
        release {
            signingConfig = signingConfigs.getByName("release")
            isMinifyEnabled = true
            isShrinkResources = true
            proguardFiles(
                getDefaultProguardFile("proguard-android-optimize.txt"),
                "proguard-rules.pro"
            )
        }
    }
}
```

### Tạo keystore

```bash
keytool -genkey -v \
  -keystore ~/keys/acme-release.jks \
  -keyalg RSA -keysize 2048 -validity 10000 \
  -alias acme
```

> ⚠️ **Mất keystore = mất app** (không thể update trên Play Store). Backup keystore ở 2 nơi (local + cloud encrypted vault).

## 5.3 Proguard / R8 rules

```pro
# android/app/proguard-rules.pro

# Flutter
-keep class io.flutter.app.** { *; }
-keep class io.flutter.plugin.** { *; }
-keep class io.flutter.util.** { *; }
-keep class io.flutter.view.** { *; }
-keep class io.flutter.** { *; }
-keep class io.flutter.plugins.** { *; }

# Firebase / backend SDK
-keep class com.google.firebase.** { *; }
-dontwarn com.google.firebase.**

# json_serializable
-keepattributes Signature
-keepattributes *Annotation*
-keep class com.google.gson.** { *; }

# App models (giữ tất cả class trong package models)
-keep class com.acme.app.models.** { *; }
```

## 5.4 Gradle / AGP version

```kotlin
// android/settings.gradle.kts
plugins {
    id("dev.flutter.flutter-plugin-loader") version "1.0.0"
    id("com.android.application") version "8.11.1" apply false
    id("org.jetbrains.kotlin.android") version "2.2.20" apply false
    id("com.google.devtools.ksp") version "2.2.20-2.0.4" apply false
}
```

```properties
# android/gradle.properties
android.useAndroidX=true
android.enableJetifier=false
org.gradle.jvmargs=-Xmx4g -XX:MaxMetaspaceSize=512m -Dfile.encoding=UTF-8
org.gradle.parallel=true
org.gradle.caching=true
```

---

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

# 8. Anti-patterns — tuyệt đối tránh

## 8.1 Bảo mật

| ❌ Anti-pattern | ✅ Cách đúng |
|---|---|
| Hard-code API key trong Dart code | Qua `.env.<env>` + AppConfig |
| Hard-code secret trong AppDelegate.swift | Qua `Info.plist` + `$(GOOGLE_MAPS_API_KEY)` |
| Commit `.env.prod` chứa key thật vào git | `.gitignore` + inject qua CI secret |
| Để `NSAllowsArbitraryLoads=true` cho prod | Bật chỉ cho dev (qua flavor config) |
| Để `usesCleartextTraffic=true` cho prod | Qua `network_security_config.xml` chỉ allow internal |

## 8.2 Signing

| ❌ Anti-pattern | ✅ Cách đúng |
|---|---|
| Release Android ký bằng debug keystore | Tạo keystore riêng, lưu key.properties ngoài git |
| iOS archive dùng `iPhone Developer` identity | Phải là `iPhone Distribution` |
| Không backup keystore → mất → không update được | Backup ở 2+ nơi (vault + local encrypted) |
| Hard-code keystore password trong `build.gradle.kts` | Qua `key.properties` (gitignored) |

## 8.3 Bundle / Application ID

| ❌ Anti-pattern | ✅ Cách đúng |
|---|---|
| 3 flavor dùng chung bundle/application ID | Mỗi flavor suffix riêng (`.dev` / `.stg` / `.prod`) |
| Production có suffix (vd `.prod`) | Production KHÔNG suffix (giữ ID gốc cho store) |
| Copy-paste AndroidManifest từ project khác không review | Đọc từng dòng, đảm bảo `android:label` reference `@string/app_name` |

## 8.4 Env handling

| ❌ Anti-pattern | ✅ Cách đúng |
|---|---|
| Hard-code `.env.dev` trong `build.gradle.kts` | Đọc qua `System.getenv()` hoặc `local.properties` |
| `dotenv.env['KEY']` rải rác trong code | Qua `AppConfig.KEY` (singleton, mock được) |
| Bundle `.env.prod` vào app assets | Inject qua `--dart-define` lúc build |
| Để tên file `.env.dev` / `.env.stg` cứng trong main_*.dart | OK (đây là convention, mỗi entry 1 file) |

## 8.5 Permissions

| ❌ Anti-pattern | ✅ Cách đúng |
|---|---|
| `INTERNET` chỉ trong `debug/AndroidManifest.xml` | Phải ở `main/AndroidManifest.xml` |
| Khai báo permission không dùng → App Store reject | Chỉ khai báo cái code thực sự gọi |
| Privacy key message trống / chung chung | Message cụ thể, giải thích rõ tại sao cần |

## 8.6 Build / release

| ❌ Anti-pattern | ✅ Cách đúng |
|---|---|
| Upload APK lên Play Store | Phải upload AAB |
| Quên bump versionCode → Play Store reject | `versionCode++` mỗi release |
| Bật Proguard nhưng thiếu rules → crash khi chạy release | Test kỹ trên release APK trước khi submit |
| Inherit `Debug*` build config cho `Profile*` | Tạo Profile config riêng (cho Flutter profiling) |

---

# 9. Bug thường gặp — từ review thực tế

Danh sách bug phát hiện khi review `rual_transpo_rider_mobile` (Flutter multi-flavor project thật). Mỗi bug đều có file path + cách fix.

| # | Bug | File | Mức độ | Fix |
|---|---|---|---|---|
| 1 | Release APK mất `INTERNET` permission | `android/app/src/main/AndroidManifest.xml` | 🔴 Critical | Move INTERNET từ `debug/` lên `main/` |
| 2 | 3 Android flavor dùng chung `applicationId` | `android/app/build.gradle.kts` | 🟡 Medium | Thêm `applicationIdSuffix` cho dev/stg |
| 3 | `android:label` literal không pick `@string/app_name` | `android/app/src/main/AndroidManifest.xml` | 🟡 Medium | Đổi `android:label="rual_transpo_rider_mobile"` → `android:label="@string/app_name"` |
| 4 | Gradle hard-code `../.env.dev` | `android/app/build.gradle.kts:11` | 🔴 Critical | Đổi sang `System.getenv("GOOGLE_API_KEY_...")` |
| 5 | iOS staging/production scheme thiếu `XCBuildConfiguration` | `ios/Runner.xcodeproj/project.pbxproj` | 🔴 Critical | Tạo config cho `Debug-stg` / `Release-stg` / `Debug-prod` / `Release-prod` |
| 6 | Release Android ký bằng debug keystore | `android/app/build.gradle.kts:88-93` | 🔴 Critical | Tạo keystore riêng + signing config |
| 7 | iOS `APP_DISPLAY_NAME` copy-paste sai (Driver cũng ghi "rider dev") | `project.pbxproj:781,888,995` | 🟢 Minor | Sửa label cho từng config |
| 8 | `flutter_launcher_icons` install nhưng không config | `pubspec.yaml` | 🟢 Minor | Thêm `flutter_icons:` block |
| 9 | `key.properties` 0 byte (placeholder) | `android/key.properties` | 🟡 Medium | Thêm credential thật (gitignored) |
| 10 | Podfile có hack lớn cho `PODS_CONFIGURATION_BUILD_DIR` | `ios/Podfile` | 🟡 Medium | Khi nào AGP / CocoaPods đổi template, hack này có thể vỡ. Có comment TODO trong file |
| 11 | iOS Maps API key hard-code trong AppDelegate.swift | `ios/Runner/AppDelegate.swift` | 🟡 Medium | Đọc từ `Bundle.main` (qua `Info.plist` + xcconfig) |
| 12 | Không có proguard rules | `android/app/proguard-rules.pro` | 🟡 Medium | Tạo file với rules Flutter + SDK |
| 13 | iOS `NSLocationWhenInUseUsageDescription` OK nhưng thiếu privacy key khác | `ios/Runner/Info.plist` | 🟡 Medium | Kiểm tra từng permission plugin dùng |
| 14 | Android dev/stg/prod cùng share launcher icon base | `android/app/src/main/res/mipmap-*/` | 🟢 Cosmetic | Override qua `app/src/<flavor>/res/mipmap-*/` |
| 15 | Không có gitignore cho `.env.*` | `.gitignore` | 🔴 Critical | Thêm `.env.dev`, `.env.stg`, `.env.prod` + `!.env.example` |

## 9.1 Cách detect nhanh khi review project khác

```bash
# 1. Check INTERNET permission có ở main không
grep -A1 "INTERNET" android/app/src/*/AndroidManifest.xml

# 2. Check applicationId có unique không
grep "applicationId" android/app/build.gradle.kts

# 3. Check signing config có dùng debug keystore không
grep -A3 "release {" android/app/build.gradle.kts

# 4. Check .env có bị commit không
git ls-files | grep -E "\.env\.(dev|stg|prod)$"

# 5. Check Info.plist có đầy đủ privacy key không
grep -E "UsageDescription" ios/Runner/Info.plist | wc -l
# (số này phải ≥ số permission plugin thực sự dùng)

# 6. Check Podfile có hack lạ không
grep -c "PODS_CONFIGURATION_BUILD_DIR\|post_install" ios/Podfile

# 7. Check Flutter đã pin version chưa
cat .fvmrc
```

---

# 10. Tích hợp CI/CD (tóm tắt)

Skill này không cover CI/CD chi tiết, nhưng outline để tham khảo:

## 10.1 GitHub Actions (cơ bản)

```yaml
# .github/workflows/release.yml
name: Release
on:
  push:
    tags: ['v*']

jobs:
  android:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - uses: subosito/flutter-action@v2
        with:
          flutter-version: '3.44.0'
          channel: stable
      - run: flutter pub get
      - run: flutter test
      - name: Build AAB
        env:
          GOOGLE_API_KEY_PROD: ${{ secrets.GOOGLE_API_KEY_PROD }}
        run: flutter build appbundle --release --flavor prod -t lib/main_prod.dart
      - uses: r0adkll/upload-google-play@v1
        with:
          serviceAccountJsonPlainText: ${{ secrets.PLAY_SERVICE_ACCOUNT }}
          packageName: com.acme.app
          releaseFiles: build/app/outputs/bundle/prodRelease/app-prod-release.aab
          track: production

  ios:
    runs-on: macos-latest
    steps:
      - uses: actions/checkout@v4
      - uses: subosito/flutter-action@v2
        with:
          flutter-version: '3.44.0'
      - run: flutter pub get
      - run: cd ios && pod install
      - name: Build IPA
        run: flutter build ipa --release --flavor prod -t lib/main_prod.dart
      - uses: apple-actions/upload-testflight-build@v1
        with:
          apple-id: ${{ secrets.APPLE_ID }}
          app-specific-password: ${{ secrets.APP_SPECIFIC_PASSWORD }}
          team-id: ${{ secrets.APPLE_TEAM_ID }}
          ipa-path: build/ios/ipa/prod.ipa
```

## 10.2 Codemagic / Bitrise / Fastlane

Tương tự, dùng environment variables để inject secret. Tham khảo:
- Codemagic: https://docs.codemagic.io/flutter-configuration/flutter-projects/
- Fastlane: https://docs.fastlane.tools/

---

# 11. Liên kết với các skill khác trong `rual_transpo_rider_mobile`

| Skill | Quan hệ |
|---|---|
| [flutter-mvvm-provider-architecture](../flutter-mvvm-provider-architecture/SKILL.md) | Kiến trúc code (VM / Page / DI) — dùng song song |
| [flutter-internationalization](../flutter-internationalization/SKILL.md) | i18n / locale (fr main + en) — phải test cả 2 locale trước khi release |
| [flutter-networking-and-data](../flutter-networking-and-data/SKILL.md) | Dio/`ApiClient` config, base URL qua env |
| [flutter-multi-app-flavor](../flutter-multi-app-flavor/SKILL.md) | Ma trận App (Rider/Driver) × Env thật của repo này — đọc trước khi build/release |
| [flutter-ui-style-guide](../flutter-ui-style-guide/SKILL.md) | UI component — không đụng native config |
| [frontend-design](../frontend-design/SKILL.md) | Design system — brand assets cho icon / splash |

---

# 12. Quick reference

## 12.1 Naming convention tóm tắt

| Loại | Convention |
|---|---|
| Flavor | `dev` / `stg` / `prod` |
| Dart entry | `lib/main_<flavor>.dart` |
| Env file | `.env.<flavor>` (gitignored, trừ `.env.example`) |
| Bundle ID | `com.<org>.<app>.<flavor>` (prod không có suffix) |
| Application ID | `com.<org>.<app>.<flavor>` (prod không có suffix) |
| App display name | `<App Name> <Flavor capitalized>` (prod = `<App Name>`) |
| iOS scheme | `<flavor>` (lowercase) |
| Android source set | `app/src/<flavor>/res/...` |
| XCBuildConfiguration | `Debug-<flavor>` / `Release-<flavor>` / `Profile-<flavor>` |

## 12.2 Build command tóm tắt

```bash
# Run local
flutter run --flavor <f> -t lib/main_<f>.dart --dart-define-from-file=.env.<f>

# Build APK
flutter build apk --release --flavor <f> -t lib/main_<f>.dart --dart-define-from-file=.env.<f>

# Build AAB (Play Store)
flutter build appbundle --release --flavor prod -t lib/main_prod.dart \
  --dart-define=BASE_URL=https://api.acme.com

# Build IPA (App Store / TestFlight)
flutter build ipa --release --flavor prod -t lib/main_prod.dart \
  --dart-define=BASE_URL=https://api.acme.com
```

## 12.3 File cần check trước mỗi release

- [ ] `pubspec.yaml` — version bump
- [ ] `android/app/build.gradle.kts` — versionCode bump + signing config OK
- [ ] `ios/Runner.xcodeproj/project.pbxproj` — `CURRENT_PROJECT_VERSION` bump
- [ ] `.env.prod` — key đã đổi (không dùng dev/stg key)
- [ ] `CHANGELOG.md` — đã cập nhật
- [ ] Privacy policy URL — accessible + đúng version app