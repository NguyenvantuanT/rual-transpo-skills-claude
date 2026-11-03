# iOS configuration

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

> **Bug thường gặp** (từ dự án thật): nếu có multi-flavor + Pods build mismatch, Pods build vào `Debug-iphonesimulator/` (un-flavored) trong khi Runner dùng `Debug-dev-iphonesimulator/` → linker fail. Fix: thêm override `PODS_CONFIGURATION_BUILD_DIR` trong `post_install` (xem chi tiết ở §9).

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
# DEVELOPMENT_TEAM = ABCDE12345
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

