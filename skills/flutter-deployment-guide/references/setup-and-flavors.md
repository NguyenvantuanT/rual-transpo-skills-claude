# Chuẩn bị + multi-flavor setup

# 1. Chuẩn bị trước khi bắt đầu

## 1.1 Account & quyền cần có

| Service | Cần gì | Dùng cho |
|---|---|---|
| **Apple Developer Program** ($99/năm) | Team ID (10 ký tự, vd `ABCDE12345`), App ID prefix, signing cert, provisioning profile | iOS code signing, App Store Connect, TestFlight |
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

