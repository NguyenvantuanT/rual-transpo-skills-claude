# Environment switching + API key native

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

