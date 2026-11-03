# iOS: build configuration, scheme, Info.plist, icon, Podfile

## 2. iOS — ma trận Build Configuration

### 2.1 Tạo đủ N×M×3 build configuration ngay từ đầu

Với 2 app × 3 env × 3 build type (Debug/Release/Profile) = **18 configuration**. Tạo hết cả 18 dù staging/prod chưa build thật — tránh scheme "mồ côi" (trỏ config không tồn tại).

Trong Xcode → Project → Info → Configurations, tạo lần lượt (đặt tên đúng convention đã chốt ở bảng naming, ví dụ dưới đây dùng `<app1>`=admin, `<app2>`=user — đổi theo tên thật của dự án):

| Configuration | PRODUCT_BUNDLE_IDENTIFIER | FLUTTER_TARGET | APP_DISPLAY_NAME |
|---|---|---|---|
| Debug-devAdmin | `com.acme.admin.dev` | `lib/main_admin.dart` | `Admin Dev` |
| Release-devAdmin | `com.acme.admin.dev` | `lib/main_admin.dart` | `Admin Dev` |
| Profile-devAdmin | `com.acme.admin.dev` | `lib/main_admin.dart` | `Admin Dev` |
| Debug-stgAdmin | `com.acme.admin.stg` | `lib/main_admin.dart` | `Admin Stg` |
| Release-stgAdmin | `com.acme.admin.stg` | `lib/main_admin.dart` | `Admin Stg` |
| Profile-stgAdmin | `com.acme.admin.stg` | `lib/main_admin.dart` | `Admin Stg` |
| Debug-prodAdmin | `com.acme.admin` | `lib/main_admin.dart` | `Admin` |
| Release-prodAdmin | `com.acme.admin` | `lib/main_admin.dart` | `Admin` |
| Profile-prodAdmin | `com.acme.admin` | `lib/main_admin.dart` | `Admin` |
| Debug-devUser | `com.acme.user.dev` | `lib/main_user.dart` | `User Dev` |
| Release-devUser | `com.acme.user.dev` | `lib/main_user.dart` | `User Dev` |
| Profile-devUser | `com.acme.user.dev` | `lib/main_user.dart` | `User Dev` |
| Debug-stgUser | `com.acme.user.stg` | `lib/main_user.dart` | `User Stg` |
| Release-stgUser | `com.acme.user.stg` | `lib/main_user.dart` | `User Stg` |
| Profile-stgUser | `com.acme.user.stg` | `lib/main_user.dart` | `User Stg` |
| Debug-prodUser | `com.acme.user` | `lib/main_user.dart` | `User` |
| Release-prodUser | `com.acme.user` | `lib/main_user.dart` | `User` |
| Profile-prodUser | `com.acme.user` | `lib/main_user.dart` | `User` |

> **Cách detect nhanh xem 1 project có bị thiếu config không**: đếm số dòng `isa = XCBuildConfiguration` trong `project.pbxproj` và so với N×M×3 kỳ vọng. Rồi đối chiếu với danh sách scheme — mỗi scheme phải trỏ tới config nằm trong danh sách đã đếm được (xem lệnh ở §8).

### 2.2 xcscheme — 1 scheme cho mỗi (App, Env)

6 scheme (2 app × 3 env), mỗi scheme trỏ đúng 3 config Debug/Release/Profile tương ứng — **không dùng tên config của app/env khác** (lỗi hay gặp: copy-paste scheme rồi quên đổi build configuration bên trong, dẫn tới build app A nhưng ra bundle ID của app B).

> **Rule sống còn**: Flutter tooling xác định flavor bằng cách **parse chính TÊN của build configuration** đang được scheme dùng (`Debug-user` → flavor `user`), **không phải** tên file scheme hay tên scheme hiển thị trong Xcode. Hệ quả: tạo `User.xcscheme` xong nhưng để các action bên trong (`LaunchAction`, `ProfileAction`, `AnalyzeAction`, `ArchiveAction`) trỏ về config trơn `Debug`/`Release`/`Profile` (config này CÓ THẬT, Xcode build bình thường trong IDE) — vẫn KHÔNG đủ. `flutter run --flavor user` sẽ báo lỗi khác hẳn scheme mồ côi (§4.1), dạng: `Flutter expects a build configuration named Debug-User or similar` — vì Flutter không tìm thấy config nào có tên chứa `user`. Đây là bug tinh vi nhất trong nhóm iOS vì: (1) scheme tồn tại thật, (2) config nó trỏ tới cũng tồn tại thật và Xcode build được qua IDE, chỉ riêng Flutter CLI mới từ chối. Fix: **mọi scheme phục vụ 1 flavor phải trỏ config có tên MANG flavor suffix** (`Debug-user`, không phải `Debug`), tạo đủ ở cả 3 tầng XCConfigurationList (project/Runner target/RunnerTests target) rồi mới sửa scheme trỏ vào — xem case chi tiết ở §4.10.

```bash
# Verify 1 scheme trỏ đúng config — check thủ công sau khi tạo/copy scheme
grep "buildConfiguration" ios/Runner.xcodeproj/xcshareddata/xcschemes/devAdmin.xcscheme
# Kỳ vọng: chỉ thấy "Debug-devAdmin" / "Release-devAdmin", KHÔNG lẫn config app/env khác,
# và KHÔNG phải config trơn "Debug"/"Release"/"Profile" không mang tên flavor nào cả.
```

### 2.3 Info.plist — display name + icon PHẢI theo biến, không hardcode

Lỗi hay gặp nhất: `CFBundleDisplayName` hardcode 1 chuỗi cứng (copy từ app đầu tiên) → mọi app build ra đều hiện cùng 1 tên trên home screen, chỉ khác nhau ở bundle ID (vô hình với user).

```xml
<!-- ios/Runner/Info.plist -->
<key>CFBundleDisplayName</key>
<string>$(APP_DISPLAY_NAME)</string>   <!-- PHẢI là biến, map trong xcconfig từng config -->

<key>CFBundleIdentifier</key>
<string>$(PRODUCT_BUNDLE_IDENTIFIER)</string>
```

Map biến trong xcconfig riêng từng build configuration (`ios/Flutter/Debug-devAdmin.xcconfig`, …):

```xcconfig
#include "Generated.xcconfig"
FLUTTER_TARGET=lib/main_admin.dart
APP_DISPLAY_NAME=Admin Dev
```

### 2.4 App icon — asset catalog riêng theo App

Không dùng chung 1 `AppIcon.appiconset` cho cả 2 app. Cách sạch nhất: 2 asset catalog riêng + set `ASSETCATALOG_COMPILER_APPICON_NAME` khác nhau theo build configuration.

```
ios/Runner/
├── Assets.xcassets/            ← icon <app1> (mặc định, vd admin)
│   └── AppIcon.appiconset/
└── AssetsUser.xcassets/        ← icon <app2> (vd user)
    └── AppIconUser.appiconset/
```

```xcconfig
// ios/Flutter/Debug-devUser.xcconfig
ASSETCATALOG_COMPILER_APPICON_NAME=AppIconUser
```

### 2.5 Podfile — CocoaPods build pod target bằng config TRƠN, Runner build bằng config CÓ FLAVOR → cần patch `post_install` redirect build dir

**Đã verify thật trên `ios/Podfile` của 1 dự án thật**: ngược với giả định trực quan ("CocoaPods tự resolve `$(CONFIGURATION)` đúng theo config đang active nên không cần patch gì"), thực tế CocoaPods build MỖI POD TARGET bằng config **trơn** (`Debug`/`Release`), sản phẩm build ra nằm ở `Debug-iphonesimulator/<PodName>/` — trong khi Runner (dùng config có flavor, vd `Debug-developmentCustomer`) lại tìm ở `Debug-developmentCustomer-iphonesimulator/<PodName>/`. Vì xcconfig flavor hoá do CocoaPods generate (`Pods-Runner.debug-developmentcustomer.xcconfig`) vẫn tham chiếu `${PODS_CONFIGURATION_BUILD_DIR}` — khi Runner consume xcconfig này, biến đó resolve theo config CỦA RUNNER (`Debug-developmentCustomer-iphonesimulator`), lệch với nơi pod thật sự được build → linker "file not found". Đây KHÔNG phải giả thuyết — patch `post_install` bên dưới đang thật sự chạy ở Podfile của dự án đó, kèm comment giải thích chính xác cơ chế trên:

```ruby
# ios/Podfile — mapping này CHỈ để CocoaPods biết build config mới nên tối ưu theo :debug hay :release
project 'Runner', {
  'Debug' => :debug,
  'Profile' => :release,
  'Release' => :release,
}

target 'Runner' do
  use_frameworks!
  flutter_install_all_ios_pods File.dirname(File.realpath(__FILE__))
  target 'RunnerTests' do
    inherit! :search_paths
  end
end

post_install do |installer|
  installer.pods_project.targets.each do |target|
    flutter_additional_ios_build_settings(target)
    target.build_configurations.each do |config|
      config.build_settings['IPHONEOS_DEPLOYMENT_TARGET'] = '15.5'
      config.build_settings['EXCLUDED_ARCHS[sdk=iphonesimulator*]'] = 'x86_64'
    end
  end

  # Redirect flavored Pods-Runner xcconfig về build dir TRƠN, vì CocoaPods build
  # pod target bằng config Debug/Release (không flavor) — xem giải thích ở trên.
  pods_xcconfig_dir = File.join(installer.sandbox.target_support_files_root, 'Pods-Runner')
  Dir.glob(File.join(pods_xcconfig_dir, 'Pods-Runner.*-development*.xcconfig')).each do |path|
    contents = File.read(path)
    next if contents.include?('UNFLAVORED_PODS_CONFIG_DIR')

    rewritten = contents.dup
    rewritten.gsub!(/^PODS_CONFIGURATION_BUILD_DIR\s*=\s*.*$/, 'PODS_CONFIGURATION_BUILD_DIR = ${BUILD_DIR}/Debug${EFFECTIVE_PLATFORM_NAME}')
    rewritten.gsub!(/^PODS_XCFRAMEWORKS_BUILD_DIR\s*=\s*.*$/, 'PODS_XCFRAMEWORKS_BUILD_DIR = ${BUILD_DIR}/Debug${EFFECTIVE_PLATFORM_NAME}/XCFrameworkIntermediates')
    rewritten.gsub!('${PODS_CONFIGURATION_BUILD_DIR}', '${BUILD_DIR}/Debug${EFFECTIVE_PLATFORM_NAME}')
    rewritten.gsub!('${PODS_XCFRAMEWORKS_BUILD_DIR}', '${BUILD_DIR}/Debug${EFFECTIVE_PLATFORM_NAME}/XCFrameworkIntermediates')
    # Drop $(inherited) để Runner không kéo thêm Pods-Runner.debug.xcconfig (trơn)
    # qua chuỗi #include? trong Flutter/Debug.xcconfig — nếu không drop, đường dẫn
    # flavor lại bị nhét ngược vào cho cùng 1 Pod, quay về đúng lỗi ban đầu.
    rewritten.gsub!(/^FRAMEWORK_SEARCH_PATHS\s*=\s*\$\(inherited\)\s*/, 'FRAMEWORK_SEARCH_PATHS = ')
    rewritten.gsub!(/^HEADER_SEARCH_PATHS\s*=\s*\$\(inherited\)\s*/, 'HEADER_SEARCH_PATHS = ')
    rewritten << "\nUNFLAVORED_PODS_CONFIG_DIR = 1\n"
    File.write(path, rewritten)
  end
end
```

> **Gap hay gặp**: glob `Pods-Runner.*-development*.xcconfig` chỉ khớp config chứa chữ `development` — patch KHÔNG tự áp dụng cho `staging*`/`production*` một khi các build configuration đó được tạo thật ở tầng Xcode. Khi hoàn thiện trục Env, phải sửa glob này thành pattern khớp cả 3 env (vd `Pods-Runner.*-{development,staging,production}*.xcconfig` hoặc đơn giản hơn — mọi file có flavor suffix, loại trừ 2 file trơn `debug`/`release`), nếu không `pod install`/build sẽ chạy được cho `developmentCustomer`/`developmentMerchant` nhưng lỗi linker y hệt lỗi gốc khi build `stagingCustomer`/`productionCustomer`/`stagingMerchant`/`productionMerchant`.

Việc khác cần nhớ mỗi khi thêm build configuration mới (kể cả chỉ mới tạo trong `project.pbxproj`, chưa từng chạy `pod install`): phải chạy lại `pod install` để CocoaPods generate `Pods-Runner.<config-name>.xcconfig` tương ứng — patch `post_install` ở trên chỉ rewrite file ĐÃ generate, không tự tạo file mới.

> Nếu build vẫn gặp linker "file not found" ở 1 pod khi build config có tên flavor: kiểm tra theo thứ tự (1) đã `pod install` lại sau khi thêm config mới chưa, (2) `Pods-Runner.<config>.xcconfig` tương ứng đã được generate chưa (`find Pods/Target\ Support\ Files -iname "*<flavor>*"`), (3) glob trong patch `post_install` có khớp tên config đó không (xem gap ở trên).

