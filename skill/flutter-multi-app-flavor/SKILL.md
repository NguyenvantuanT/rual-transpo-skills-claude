---
name: flutter-multi-app-flavor
description: |
  Setup nhiều app (multi-role / multi-brand, vd Admin + User, Rider + Driver, Customer + Merchant — tuỳ dự án) build ra từ CÙNG MỘT Flutter codebase, kết hợp với multi-environment (dev/stg/prod) — tức 2 trục flavor độc lập (App × Env) trong cùng 1 project. Cover: naming convention nhất quán cho ma trận App×Env, Xcode build configuration + scheme cho iOS, Android flavorDimensions 2 chiều (+ lựa chọn thay thế 1 dimension gộp sẵn), Info.plist / AndroidManifest per-app display name + icon, CocoaPods flavored-config workaround, router pattern (N router riêng dùng chung 1 base abstraction + DI chọn theo app), các loại conflict đặc thù multi-app (scheme mồ côi, naming drift giữa các tầng, route/page class trùng tên trong auto_route, resValue không wire vào manifest, icon share nhầm giữa app) kèm lệnh detect, và checklist tránh lỗi thường gặp.
  Sử dụng khi: 1 codebase Flutter phải build ra ≥2 app khác nhau (bundle ID / applicationId khác nhau, có thể khác tên, icon, vài feature) — không phải chỉ khác environment. Tên 2 app tuỳ dự án (Admin/User, Rider/Driver, ...) — thay placeholder `<app1>`/`<app2>` bằng tên thật khi áp dụng. Cũng dùng để review/audit 1 project multi-app có sẵn xem có thiếu config nhánh nào không.
  KHÔNG dùng nếu chỉ cần dev/stg/prod cho 1 app duy nhất (env-only, không có trục App) — đó là bài toán 1 trục, đơn giản hơn nhiều so với skill này.
---

# Flutter Multi-App Flavor — N app × M env trong 1 codebase

## Bài toán

Một số sản phẩm cần **nhiều app riêng biệt** (bundle ID / applicationId khác nhau, cài song song được, có thể lên store độc lập) nhưng dùng chung 99% code Dart. Tên 2 app tuỳ dự án — có thể là `admin` + `user`, `rider` + `driver`, `customer` + `merchant`, v.v. Skill này dùng placeholder `<app1>` / `<app2>` (thay bằng tên thật của dự án đang làm) vì đây là quy ước cấu trúc, không phải tên cố định.

Đây là bài toán **2 trục flavor độc lập**:

```
                    dev                 staging              production
<app1>   →   <app1>-dev           <app1>-stg           <app1>-prod
<app2>   →   <app2>-dev           <app2>-stg           <app2>-prod
```

Ví dụ cụ thể hoá cho 1 dự án dùng `admin` / `user`:

```
                    dev                 staging              production
admin    →   admin-dev            admin-stg            admin-prod
user     →   user-dev             user-stg             user-prod
```

N app × M env = N×M tổ hợp build. Nếu chỉ làm nửa vời (vd chỉ hoàn thiện cột `dev`, bỏ trống `stg`/`prod`) thì build ở nhánh thiếu sẽ lỗi ngay khi cần — đây là lỗi thực tế hay gặp nhất khi audit loại project này (xem §4.1 và §8).

> Nếu chỉ cần 1 app với nhiều env (không có trục App) thì đây là bài toán đơn giản hơn — dùng flavor-per-env thông thường (`main_dev.dart` / `main_stg.dart` / `main_prod.dart`), không cần áp dụng ma trận 2 chiều ở skill này.

## Nguyên tắc cốt lõi

1. **1 codebase, N target ảo** — KHÔNG fork repo, KHÔNG tạo Xcode target thứ 2 (`Runner2`). Vẫn 1 target `Runner` / 1 Gradle module `app`, phân biệt app qua build configuration (iOS) / product flavor (Android).
2. **Naming PHẢI đặt 1 lần, dùng xuyên suốt** — chốt tên 2 app (vd `<app1>`, `<app2>`) và tên env (`dev`, `stg`, `prod`) trước khi tạo bất kỳ config nào. Đổi tên giữa chừng (vd `driver` → `user` → `driver`) để lại rác naming ở nhiều tầng (xcconfig, Pods, scheme) rất khó dọn sạch — xem case thật + lệnh detect ở §4.2.
3. **Mọi nhánh trong ma trận đều phải có config đầy đủ ngay từ đầu**, kể cả khi staging/production chưa cần build thật. Một scheme trỏ tới build configuration không tồn tại sẽ im lặng cho tới lúc ai đó chọn scheme đó — phát hiện muộn, thường là lúc gấp (release).
4. **Bundle ID / Application ID unique cho từng (App, Env)** — không chỉ unique theo App. `com.acme.<app1>` và `com.acme.<app2>` là chưa đủ nếu dev/stg/prod cũng phải cài song song.
5. **Display name + icon phải khác nhau theo App** (không chỉ theo Env) — nếu không, 2 app cài trên máy sẽ trông giống hệt nhau, user không phân biệt được. Đây là lỗi tinh vi vì `flutter build` vẫn chạy được, bundle ID vẫn khác, nhưng UX bị sai.

## Naming convention

| Khái niệm | Convention | Ví dụ (đặt tên `<app1>`=admin, `<app2>`=user) |
|---|---|---|
| App name (trục 1) | lowercase, ngắn, KHÔNG đổi lại giữa chừng — thay bằng tên thật của dự án | `admin`, `user` |
| Env name (trục 2) | `dev` / `stg` / `prod` | |
| Dart entry | `lib/main_<app>_<env>.dart` (hoặc `lib/main_<app>.dart` + `--dart-define=ENV=<env>` nếu muốn ít file hơn) | `main_admin_dev.dart` |
| Bundle ID / Application ID | `com.<org>.<app>.<env>` (prod bỏ suffix env) | `com.acme.admin.dev`, `com.acme.user` |
| App display name | `<App Display> <Env>` (prod bỏ suffix env) | `Admin Dev`, `User` |
| iOS scheme | `<env><App>` (PascalCase App, lowerCamel env) — nhất quán 1 kiểu duy nhất | `devAdmin`, `stgUser`, `prodUser` |
| XCBuildConfiguration | `Debug-<env><App>` / `Release-<env><App>` / `Profile-<env><App>` | `Debug-devAdmin` |
| Android flavor dimension `app` | tên app | `admin`, `user` |
| Android flavor dimension `env` | tên env | `dev`, `stg`, `prod` |

> **Chốt 1 case convention và dùng xuyên suốt mọi tầng** (Dart, Xcode scheme, XCBuildConfiguration, Android flavor, tên file xcconfig). Trộn `Admin` / `admin` / `Admin-dev` / `development-admin` ở các tầng khác nhau là nguồn lỗi hay gặp nhất — máy tính coi các chuỗi đó là khác nhau, người review rất khó lần ra scheme nào thật sự trỏ đúng config.

## 1. Dart layer

### 1.1 Entry point tách theo App (không tách theo Env ở tầng Dart)

Env vẫn dùng chung 1 cơ chế (`--dart-define` / `.env.<env>`) như setup single-app thông thường. Trục App thêm 1 tầng ở trên:

```dart
// lib/main_<app1>.dart — ví dụ lib/main_admin.dart
import 'app/bootstrap.dart';

Future<void> main() async {
  await bootstrap(appFlavor: AppFlavor.app1);
}
```

```dart
// lib/main_<app2>.dart — ví dụ lib/main_user.dart
import 'app/bootstrap.dart';

Future<void> main() async {
  await bootstrap(appFlavor: AppFlavor.app2);
}
```

```dart
// lib/app/app_flavor.dart — đổi tên enum value theo app thật của dự án
enum AppFlavor { app1, app2 } // ví dụ: { admin, user }
```

```dart
// lib/app/bootstrap.dart — dùng chung, env vẫn qua --dart-define như bình thường
Future<void> bootstrap({required AppFlavor appFlavor}) async {
  WidgetsFlutterBinding.ensureInitialized();
  AppConfig.init(appFlavor: appFlavor); // set role-specific behavior (router, theme, DI)
  runApp(App(flavor: appFlavor));
}
```

> **Rule**: KHÔNG rẽ nhánh `if (appFlavor == app1)` rải rác trong widget/VM. Rẽ nhánh 1 lần ở tầng bootstrap (chọn router, theme, danh sách DI service theo role), phần còn lại code dùng chung không biết mình đang chạy app nào.

> **Biến thể chấp nhận được — không dùng `bootstrap.dart` chung**: nếu team muốn mỗi entry point (`main_<app>.dart`) tự đọc được toàn bộ flow init (không phải nhảy sang 1 file khác để hiểu `runApp` được gọi thế nào), có thể bỏ hẳn `lib/app/bootstrap.dart` và inline toàn bộ nội dung (`runZonedGuarded`, `dotenv.load`, `AppConfig.create`, `SystemChrome`, `setUpInjector`, `runApp`) trực tiếp vào từng `main_<app>.dart`. Đánh đổi: trùng lặp code giữa các entry point (phải sync tay khi đổi init flow chung), đổi lại mỗi file đọc độc lập được, không cần nhảy file để trace init. Case thật áp dụng biến thể này: §9.

### 1.2 AppConfig — 2 trục độc lập

```dart
class AppConfig {
  static late final AppFlavor appFlavor; // trục App — set ở compile/bootstrap
  static late final String env;          // trục Env — đọc từ --dart-define=ENV=dev|stg|prod
  static late final String baseUrl;      // đọc từ .env.<env> như bình thường

  static void init({required AppFlavor appFlavor}) {
    AppConfig.appFlavor = appFlavor;
    env = const String.fromEnvironment('ENV', defaultValue: 'dev');
    // load .env.<env>, set baseUrl, v.v. — giống pattern single-app
  }
}
```

### 1.3 Router — N app, N router riêng dùng chung 1 base abstraction

2 app thường có route/flow khác nhau (Admin không có màn đặt hàng, User không có màn quản trị). **KHÔNG** dùng 1 router chứa tất cả route rồi `if (appFlavor == app1) hide route` — dùng N router cụ thể, mỗi router implement chung 1 abstraction, chọn router nào qua DI ở tầng bootstrap (đúng rule "rẽ nhánh 1 lần" ở §1.1).

```dart
// lib/router/app_router_base.dart — abstraction chung, VM/widget chỉ biết tới type này
abstract class AppRouterBase extends RootStackRouter {}
```

> **Đã verify thật (auto_route 11.1.0, `build_runner build`)**: `auto_route`/`source_gen` generate `part` ĐỘC LẬP theo từng file — 1 file khai `part 'x.gr.dart'` + `@AutoRouterConfig()` sẽ có generated code riêng, không bị gộp chung với file khác, kể cả khi 2 router ở 2 file khác nhau cùng tham chiếu trùng tên page/route (đã test bằng cách tạo 2 router file trỏ chung page class, build_runner chạy sạch, sinh 2 file `.gr.dart` độc lập không đụng nhau). Vì vậy **tách 1 router = 1 file riêng cho mỗi App** (`admin_router.dart` + `part 'admin_router.gr.dart'`, `user_router.dart` + `part 'user_router.gr.dart'`) là lựa chọn AN TOÀN HƠN và nên là mặc định nếu 2 app không cần điều hướng chéo vào route của nhau — nó loại bỏ hẳn rủi ro trùng tên route ở §4.3 thay vì chỉ giảm thiểu bằng convention đặt tên. Gộp chung 1 file (ví dụ dưới đây) vẫn là lựa chọn HỢP LỆ nếu team muốn 1 chỗ nhìn thấy hết mọi route của mọi app, hoặc cần 1 app điều hướng sang route của app kia — nhưng đó là lựa chọn có chủ đích, không phải giới hạn kỹ thuật bắt buộc.

```dart
// lib/router/app_router.dart
// Ví dụ gộp 1 file (lựa chọn, không bắt buộc) — nếu tách riêng theo app,
// mỗi file tự "part" file .gr.dart của chính nó, xem note ở trên.
part 'app_router.gr.dart';

@AutoRouterConfig()
class AppRouterAdmin extends AppRouterBase {
  @override
  RouteType get defaultRouteType => const RouteType.material();

  @override
  List<AutoRoute> get routes => [
    CupertinoRoute(page: SplashAdminRoute.page, initial: true),
    CupertinoRoute(page: MainAdminRoute.page),
    // ... chỉ liệt kê route thuộc về Admin
  ];
}

@AutoRouterConfig()
class AppRouterUser extends AppRouterBase {
  @override
  RouteType get defaultRouteType => const RouteType.material();

  @override
  List<AutoRoute> get routes => [
    CupertinoRoute(page: SplashUserRoute.page, initial: true),
    CupertinoRoute(page: MainUserRoute.page),
    // ... chỉ liệt kê route thuộc về User
  ];
}
```

DI chọn đúng router cụ thể ở bootstrap — đây là NƠI DUY NHẤT trong codebase được phép rẽ nhánh theo `AppFlavor`:

```dart
// lib/src/utils/locator.dart
void setUpInjector({required AppFlavor appFlavor}) {
  locator.registerLazySingleton(() => SharedPrefs());
  locator.registerLazySingleton(() => ApiClient());
  locator.registerLazySingleton<AppRouterBase>(
    () => appFlavor == AppFlavor.app1 ? AppRouterAdmin() : AppRouterUser(),
  );
}
```

Phần widget dùng chung (`MaterialApp.router`) chỉ resolve qua `locator<AppRouterBase>()` — không biết và không cần biết đang chạy app nào:

```dart
routerConfig: locator<AppRouterBase>().config(
  navigatorObservers: () => [AppRouteObserver()],
),
```

**Namespace page theo app** — khi UI/flow của 1 page khác nhau giữa 2 app, đặt ở 2 thư mục riêng dưới `lib/src/pages/`, không trộn lẫn qua `if`:

```
lib/src/pages/
├── splash_admin/            ← splash riêng Admin
├── splash_user/             ← splash riêng User
├── main_admin/               ← shell/tab bar riêng Admin
│   └── home/
├── main_user/                 ← shell/tab bar riêng User
│   └── home/
└── setting/                  ← page dùng chung cả 2 app (giống hệt nhau) → KHÔNG namespace
```

Chỉ namespace khi 2 app thực sự khác UI/flow. Page dùng chung y hệt (vd `SettingsPage`) vẫn để ở 1 chỗ như dự án single-app bình thường — namespace thừa chỉ tạo duplicate code phải sync tay.

> **Rule quan trọng của phần router**: NẾU chọn gộp mọi `@AutoRouterConfig` vào chung 1 file `part` (như ví dụ ở trên), class page/route phải **unique tên trên toàn project**, không chỉ unique trong 1 router — `HomePage` ở Admin và `HomePage` ở User (2 file khác nhau, cùng tên class) sinh ra 2 route cùng tên `HomeRoute` trong CÙNG 1 file generated → conflict thật. Đặt tên class có prefix app ngay từ đầu: `HomeAdminPage` / `HomeUserPage` — xem thêm §4.3. **Nếu tách router theo app thành file riêng** (khuyến nghị, xem note ở trên), rủi ro này không tồn tại — mỗi file generated độc lập, trùng tên class giữa 2 app không gây conflict kỹ thuật; prefix tên page lúc đó chỉ còn là hygiene cho dễ đọc/debug, không phải yêu cầu bắt buộc.

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

**Đã verify thật trên chính `ios/Podfile` của `rual_transpo_rider_mobile`**: ngược với giả định trực quan ("CocoaPods tự resolve `$(CONFIGURATION)` đúng theo config đang active nên không cần patch gì"), thực tế CocoaPods build MỖI POD TARGET bằng config **trơn** (`Debug`/`Release`), sản phẩm build ra nằm ở `Debug-iphonesimulator/<PodName>/` — trong khi Runner (dùng config có flavor, vd `Debug-developmentRider`) lại tìm ở `Debug-developmentRider-iphonesimulator/<PodName>/`. Vì xcconfig flavor hoá do CocoaPods generate (`Pods-Runner.debug-developmentrider.xcconfig`) vẫn tham chiếu `${PODS_CONFIGURATION_BUILD_DIR}` — khi Runner consume xcconfig này, biến đó resolve theo config CỦA RUNNER (`Debug-developmentRider-iphonesimulator`), lệch với nơi pod thật sự được build → linker "file not found". Đây KHÔNG phải giả thuyết — patch `post_install` bên dưới đang thật sự nằm trong Podfile của repo này, kèm comment giải thích chính xác cơ chế trên:

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

> **Gap thật đang tồn tại trong repo này**: glob `Pods-Runner.*-development*.xcconfig` chỉ khớp config chứa chữ `development` — patch KHÔNG tự áp dụng cho `staging*`/`production*` một khi các build configuration đó được tạo thật ở tầng Xcode (xem §9). Khi hoàn thiện trục Env, phải sửa glob này thành pattern khớp cả 3 env (vd `Pods-Runner.*-{development,staging,production}*.xcconfig` hoặc đơn giản hơn — mọi file có flavor suffix, loại trừ 2 file trơn `debug`/`release`), nếu không `pod install`/build sẽ chạy được cho `developmentRider`/`developmentDriver` nhưng lỗi linker y hệt lỗi gốc khi build `stagingRider`/`productionRider`/`stagingDriver`/`productionDriver`.

Việc khác cần nhớ mỗi khi thêm build configuration mới (kể cả chỉ mới tạo trong `project.pbxproj`, chưa từng chạy `pod install`): phải chạy lại `pod install` để CocoaPods generate `Pods-Runner.<config-name>.xcconfig` tương ứng — patch `post_install` ở trên chỉ rewrite file ĐÃ generate, không tự tạo file mới.

> Nếu build vẫn gặp linker "file not found" ở 1 pod khi build config có tên flavor: kiểm tra theo thứ tự (1) đã `pod install` lại sau khi thêm config mới chưa, (2) `Pods-Runner.<config>.xcconfig` tương ứng đã được generate chưa (`find Pods/Target\ Support\ Files -iname "*<flavor>*"`), (3) glob trong patch `post_install` có khớp tên config đó không (xem gap ở trên).

## 3. Android — 2 flavor dimension

Khác biệt quan trọng với iOS: Android hỗ trợ **flavor dimension gốc** (native), không cần build-configuration-matrix thủ công.

```kotlin
// android/app/build.gradle.kts
android {
    namespace = "com.acme.app"

    flavorDimensions += listOf("app", "env")

    productFlavors {
        // Trục App — đổi tên "admin"/"user" theo tên thật của dự án
        create("admin") {
            dimension = "app"
            applicationId = "com.acme.admin"
            resValue("string", "app_name", "Admin")
        }
        create("user") {
            dimension = "app"
            applicationId = "com.acme.user"
            resValue("string", "app_name", "User")
        }

        // Trục Env — applicationIdSuffix cộng dồn với app ở trên
        create("dev") {
            dimension = "env"
            applicationIdSuffix = ".dev"
            versionNameSuffix = "-dev"
        }
        create("stg") {
            dimension = "env"
            applicationIdSuffix = ".stg"
            versionNameSuffix = "-stg"
        }
        create("prod") {
            dimension = "env"
            // prod không suffix
        }
    }
}
```

Gradle tự sinh **6 build variant**: `adminDevDebug`, `adminStgDebug`, `adminProdRelease`, `userDevDebug`, … applicationId tự ghép đúng cả 2 trục (`com.acme.admin.dev`, `com.acme.user.stg`, …) — không cần tự tay ghép chuỗi.

### 3.1 Icon + tên riêng theo App (source set)

```
android/app/src/
├── admin/
│   ├── res/mipmap-*/ic_launcher.png     ← icon app1 (vd Admin)
│   └── res/values/strings.xml           ← app_name="Admin" (nếu không dùng resValue ở trên)
└── user/
    ├── res/mipmap-*/ic_launcher.png     ← icon app2 (vd User)
    └── res/values/strings.xml
```

AGP tự nhận source set trùng tên flavor — không cần khai báo gì thêm trong `build.gradle.kts`.

### 3.2 Build command

```bash
flutter build apk --release --flavor adminProd -t lib/main_admin.dart
flutter build apk --release --flavor userProd -t lib/main_user.dart

# Run local
flutter run --flavor adminDev -t lib/main_admin.dart
```

> Flutter CLI ghép tên flavor 2 dimension thành 1 chuỗi camelCase (`adminDev`, không phải `admin-dev` hay `admin,dev`) — đây là quy tắc cứng của Flutter tooling, không tự đặt tên khác được.

### 3.3 Lựa chọn thay thế — gộp App+Env vào 1 dimension duy nhất

Cách ở mục 3 (2 dimension `app` × `env`) là mặc định nên dùng. Có 1 cách khác vẫn gặp trong thực tế: gộp cả 2 trục vào CHUNG 1 dimension, đặt tên flavor là chuỗi ghép sẵn:

```kotlin
android {
    flavorDimensions += listOf("default")

    productFlavors {
        create("adminDev") { dimension = "default"; applicationId = "com.acme.admin.dev" }
        create("adminStg") { dimension = "default"; applicationId = "com.acme.admin.stg" }
        create("adminProd") { dimension = "default"; applicationId = "com.acme.admin" }
        create("userDev") { dimension = "default"; applicationId = "com.acme.user.dev" }
        create("userStg") { dimension = "default"; applicationId = "com.acme.user.stg" }
        create("userProd") { dimension = "default"; applicationId = "com.acme.user" }
    }
}
```

| | 2 dimension (`app` × `env`) | 1 dimension gộp sẵn |
|---|---|---|
| `applicationId` | Gradle tự ghép 2 trục | Phải tự gõ đủ cho từng flavor — dễ gõ sai hoặc bỏ sót 1 nhánh |
| Thêm 1 App mới | Thêm 1 `create()` ở dimension `app`, Gradle tự nhân với mọi env có sẵn | Phải tự thêm M flavor mới (1 cho mỗi env) — dễ quên 1 nhánh, không có gì nhắc |
| Thêm 1 Env mới | Thêm 1 `create()` ở dimension `env`, tự nhân với mọi app | Phải tự thêm N flavor mới (1 cho mỗi app) — dễ quên 1 nhánh |
| Khi nào chọn | Mặc định — Gradle tự enforce đủ tổ hợp, không thể "quên" 1 ô trong ma trận | Chỉ khi có tổ hợp (App,Env) cần setting đặc thù không fit gọn vào 2 dimension |

> Cách gộp 1 dimension không có cơ chế nào cảnh báo "bạn đang thiếu `userStg`" — thiếu là thiếu im lặng, chỉ lộ ra khi ai đó chọn đúng flavor đó. Ưu tiên 2 dimension trừ khi có lý do cụ thể; nếu buộc phải dùng 1 dimension gộp, sau khi tạo phải tự đếm lại N×M flavor đã đủ chưa (đừng tin vào cảm giác "chắc đủ rồi").

## 4. Conflict thường gặp khi build N app từ 1 codebase

Nhóm lỗi này khác với lỗi build thông thường: code Dart/Kotlin/Swift từng dòng đều "trông đúng", nhưng 2 nhánh (App1, App2) vô tình đụng nhau ở tầng cấu hình hoặc generated code — vì vậy compiler không báo, chỉ lộ ra khi build/cài đúng tổ hợp bị conflict, thường là muộn.

### 4.1 Scheme "mồ côi" — trỏ build configuration không tồn tại

Lỗi hay gặp nhất: tạo scheme cho staging/production bằng cách duplicate scheme dev, Xcode giữ tên `buildConfiguration` bên trong theo đúng convention (`Debug-stgAdmin`) — nhưng không ai thực sự tạo build configuration đó trong `project.pbxproj` (chỉ `Debug-devAdmin` tồn tại thật). Chọn scheme đó sẽ báo lỗi "cannot find configuration" ngay lập tức.

```bash
# 1. Config THẬT SỰ tồn tại trong project.pbxproj
grep -oE '(Debug|Release|Profile)-[A-Za-z0-9]+' ios/Runner.xcodeproj/project.pbxproj \
  | sort -u > /tmp/real_configs.txt

# 2. Config mà TỪNG scheme yêu cầu
for f in ios/Runner.xcodeproj/xcshareddata/xcschemes/*.xcscheme; do
  grep -oE 'buildConfiguration = "[^"]+"' "$f" | sed 's/buildConfiguration = "//;s/"//'
done | sort -u > /tmp/scheme_configs.txt

# 3. Config nào scheme cần nhưng KHÔNG tồn tại thật → scheme mồ côi
comm -23 /tmp/scheme_configs.txt /tmp/real_configs.txt
```

Output không rỗng → có scheme mồ côi. Fix trước khi báo "đã xong multi-app setup", vì đây luôn lộ ra đúng lúc gấp nhất (ai đó chọn scheme release để archive).

### 4.2 Naming drift giữa tên file scheme và buildConfiguration bên trong

Lỗi tinh vi hơn §4.1: file scheme đặt tên đúng convention (`stgUser.xcscheme`) nhưng bên trong lại trỏ `Debug-stgAdmin` (copy-paste từ scheme khác, quên sửa) — hoặc trỏ tên cũ còn sót lại từ lần đổi tên app trước đó (`Debug-stgDriver` dù mọi tầng khác đã đổi `Driver` → `User`, đúng case ở Nguyên tắc cốt lõi #2). Đây là case thật cần detect thủ công vì cả 2 tên đều "hợp lệ về mặt cú pháp":

```bash
for f in ios/Runner.xcodeproj/xcshareddata/xcschemes/*.xcscheme; do
  scheme_name=$(basename "$f" .xcscheme)
  cfg=$(grep -oE 'buildConfiguration = "[^"]+"' "$f" | head -1)
  echo "$scheme_name  →  $cfg"
done
```

Đọc kết quả bằng mắt: phần `<App>` rút ra từ tên scheme (`stgUser` → `User`) phải xuất hiện y hệt trong `buildConfiguration` (`Debug-stgUser`) — KHÔNG phải tên app khác (`Debug-stgAdmin`) hay tên app cũ (`Debug-stgDriver`).

### 4.3 auto_route — page/route class trùng tên giữa 2 router (CHỈ khi cố tình gộp chung 1 file)

Rủi ro này chỉ tồn tại nếu chọn gộp mọi `@AutoRouterConfig` vào CHUNG 1 file `part` (xem §1.3 — đây là lựa chọn, không phải bắt buộc: **đã verify thật** `build_runner`/`auto_route` generate `part` độc lập theo từng file, tách router theo app thành file riêng loại bỏ hẳn rủi ro này). Nếu vẫn chọn gộp chung 1 file: `build_runner` sinh tên route class dựa theo tên class page (`HomePage` → `HomeRoute`). Nếu Admin và User đều có 1 page tên `HomePage` (2 file khác nhau, tình cờ trùng tên class) → sinh ra 2 route cùng tên `HomeRoute` trong CÙNG 1 file generated → build_runner conflict thật — hoặc nếu qua được, route của app này có thể trỏ nhầm sang page của app kia. Rule khi gộp chung file: prefix tên class page theo app ngay từ đầu (`HomeAdminPage` / `HomeUserPage`), không dựa vào việc "để ở thư mục khác nhau là đủ" — auto_route không quan tâm thư mục, chỉ quan tâm tên class trong CÙNG 1 file generated.

### 4.4 `resValue` / biến khai báo nhưng không wire vào nơi tiêu thụ thật

`build.gradle.kts` khai báo `resValue("string", "app_name", "Admin")` cho từng flavor — nhưng nếu `AndroidManifest.xml` vẫn hardcode `android:label="my_app"` thay vì `android:label="@string/app_name"`, khai báo trên coi như vô nghĩa: mọi flavor build ra vẫn hiện chung 1 tên. Đây là lỗi **âm thầm nhất** trong nhóm này — Gradle build pass, APK cài được, chỉ sai ở chỗ ít ai để ý kiểm tra (tên hiển thị trên home screen).

```bash
grep "android:label" android/app/src/main/AndroidManifest.xml
# Kỳ vọng: android:label="@string/app_name"     (biến — đổi theo flavor)
# Dấu hiệu lỗi: android:label="<chuỗi cứng>"    (không đổi theo flavor dù build.gradle.kts đã resValue)
```

Tương tự phía iOS: xem lại §2.3 — `CFBundleDisplayName` phải là `$(APP_DISPLAY_NAME)`, không hardcode.

### 4.5 Icon/asset chỉ tách theo Env, quên tách theo App

Source set Android hay bị tổ chức theo Env trước (`android/app/src/dev/res/mipmap-*`, `.../stg/...`, `.../prod/...`) vì đó là bước tự nhiên khi mới thêm multi-env — nhưng khi thêm trục App phải tách theo App nữa (icon thường khác App nhiều hơn khác Env). Nếu source set vẫn chỉ có `dev/`, `stg/`, `prod/` mà không có `admin/`, `user/` (hoặc `adminDev/`, `userDev/`, ...) thì 2 app đang share chung icon — vi phạm Nguyên tắc cốt lõi #5. Không có build error nào báo lỗi này, chỉ lộ ra khi cài cả 2 app lên máy thật và thấy icon giống hệt nhau.

```bash
find android/app/src -maxdepth 1 -type d
# Kỳ vọng thấy thư mục đặt tên theo App (admin/, user/) — riêng hoặc kết hợp với env
# Dấu hiệu thiếu: chỉ thấy dev/, stg/, prod/ — không thư mục nào mang tên app
```

### 4.6 CocoaPods — quên `pod install` lại sau khi thêm build configuration mới

Đã cover chi tiết ở §2.5 — không lặp lại ở đây. Chỉ nhắc: build configuration mới (`Debug-user`) thêm vào `project.pbxproj` KHÔNG tự động có `Pods-Runner.debug-user.xcconfig` tương ứng — phải chạy `pod install` lại để CocoaPods generate. Nếu build iOS lỗi linker "file not found" ở 1 pod nào đó khi build config có tên flavor mới thêm nhưng chạy OK ở config gốc → quay lại §2.5 kiểm tra đã `pod install` lại chưa, KHÔNG áp patch `PODS_CONFIGURATION_BUILD_DIR` (đã kiểm chứng là không cần thiết trong Podfile template hiện đại).

### 4.7 Bundle ID không phân biệt theo Env — chỉ chấp nhận nếu là quyết định có chủ đích

Nguyên tắc cốt lõi #4 yêu cầu bundle ID unique theo cả (App, Env). Có 1 ngoại lệ hợp lệ: nếu team **cố ý** không cần dev/stg/prod cài song song trên cùng máy (mỗi lúc chỉ cài 1 bản, phân biệt qua display name + debug banner), dùng chung bundle ID cho mọi Env của 1 App là chấp nhận được — đổi lại đơn giản hoá quản lý provisioning profile / Play Console listing. Khác biệt giữa "quyết định có chủ đích" và "thiếu sót": quyết định có chủ đích phải ghi rõ lý do trong README/CHANGELOG; thiếu sót là im lặng, không ai note lại, và thường đi kèm với các dấu hiệu ở §4.1 (scheme mồ côi) — nếu thấy cả 2 dấu hiệu cùng lúc, nhiều khả năng là thiếu sót chứ không phải chủ đích.

### 4.8 `applicationId` khai báo bất đối xứng giữa các flavor App

Lỗi thường gặp trong thực tế: `productFlavors` khai 2 flavor App nhưng chỉ 1 flavor dùng `applicationIdSuffix`, flavor còn lại không khai gì cả — rơi về đúng `defaultConfig.applicationId` gốc:

```kotlin
// SAI — bất đối xứng, "user" không có identity riêng, chỉ là "cái còn lại sau khi trừ admin"
productFlavors {
    create("user") {
        dimension = "app"
        resValue("string", "app_name", "User")
        // không có applicationId / applicationIdSuffix → applicationId = defaultConfig gốc
    }
    create("admin") {
        dimension = "app"
        applicationIdSuffix = ".admin"
        resValue("string", "app_name", "Admin")
    }
}
```

Build vẫn pass, 2 APK vẫn cài song song được (2 applicationId cuối cùng vẫn khác nhau) — nên lỗi này **không lộ ra qua build error**, chỉ lộ ra khi đọc kỹ hoặc khi thêm trục Env: lúc đó flavor "user" không có gì để cộng dồn suffix vào cho rõ ràng, dễ nhầm lẫn với "chưa áp dụng flavor nào". Rule: mọi flavor ở dimension `app` phải tự khai `applicationId` đầy đủ, tường minh, đối xứng với nhau — không để 1 flavor "ăn ké" giá trị gốc của `defaultConfig`:

```kotlin
// ĐÚNG — đối xứng, mỗi app có applicationId riêng tường minh
productFlavors {
    create("user") {
        dimension = "app"
        applicationId = "com.acme.app.user"
        resValue("string", "app_name", "User")
    }
    create("admin") {
        dimension = "app"
        applicationId = "com.acme.app.admin"
        resValue("string", "app_name", "Admin")
    }
}
```

`namespace` (dùng cho R class / package Kotlin) và `defaultConfig.applicationId` gốc không cần đổi — chỉ cần đảm bảo MỌI flavor ở dimension `app` đều tự khai `applicationId` của riêng nó, không flavor nào im lặng dùng ké giá trị `defaultConfig`.

```bash
grep -A 3 'create("' android/app/build.gradle.kts
# Kỳ vọng: mọi flavor dimension "app" đều có dòng applicationId = "..." riêng
# Dấu hiệu lỗi: có flavor không xuất hiện applicationId lẫn applicationIdSuffix nào cả
```

### 4.9 Import trực tiếp file `.gr.dart` — vỡ khi router đổi cấu trúc file

Nhiều page/VM quen import thẳng `app_router.gr.dart` (file generated, `part of` router.dart) thay vì import `app_router.dart` (file khai báo `part` + export mọi route class ra ngoài). Việc này thường vẫn chạy được lúc đầu (Dart cho phép import 1 file `part` trực tiếp trong nhiều trường hợp), nhưng dễ vỡ khi cấu trúc router đổi — vd đổi tên file, gộp/tách router theo App (§1.3), hoặc build_runner regenerate với cấu trúc khác — vì các file đã import thẳng `.gr.dart` giờ trỏ tới nội dung khác hoặc file không còn tồn tại đúng chỗ cũ. Fix: luôn import `app_router.dart` (file khai `part`, là entry point ổn định), không import `*.gr.dart` trực tiếp ở bất kỳ đâu ngoài chính file khai `part` nó.

```bash
grep -rln "app_router.gr.dart'" lib/
# Kỳ vọng: không có kết quả nào ngoài chính app_router.dart
# Dấu hiệu lỗi: page/VM khác import thẳng .gr.dart — phải sửa lại thành import app_router.dart
```

### 4.10 Scheme trỏ config CÓ THẬT nhưng thiếu flavor suffix — khác hẳn scheme mồ côi (§4.1)

Là lỗi nguy hiểm nhất trong nhóm iOS vì KHÔNG giống 2 case đã biết: không phải config không tồn tại (§4.1), không phải trỏ nhầm config app khác (§4.2) — mà là scheme trỏ tới config **có thật, hợp lệ, Xcode build được qua IDE** (`Debug`/`Release`/`Profile` trơn, chưa từng gắn flavor nào), nhưng tên config đó không mang flavor suffix.

Chuỗi sự kiện điển hình khi gặp case này: tạo `<App2>.xcscheme` (copy cấu trúc từ `Runner.xcscheme` mặc định) → scheme trỏ `Debug`/`Release`/`Profile` → build qua Xcode UI vẫn chạy bình thường (vì đây là config thật) → nhưng `flutter run --flavor <app2>` báo lỗi:

```
Error: You must specify a --flavor option to select one of the available schemes.
```

Sau khi sửa để scheme trỏ đúng `Debug-<app2>` (nhưng lúc đó config `Debug-<app2>` **chưa tồn tại** trong `project.pbxproj`), lỗi đổi thành:

```
Flutter expects a build configuration named Debug-<App2> or similar.
```

Root cause: Flutter CLI xác định flavor bằng cách tự parse TÊN của build configuration mà scheme's LaunchAction đang dùng — tìm chuỗi khớp pattern `<Debug|Release|Profile>-<flavor>`. Config `Debug` trơn không match pattern này dù nó tồn tại thật và hợp lệ với Xcode. Fix đầy đủ, đúng thứ tự — sai thứ tự sẽ chỉ đổi từ lỗi này sang lỗi khác chứ không hết lỗi:

1. Tạo đủ `Debug-<flavor>`/`Release-<flavor>`/`Profile-<flavor>` ở CẢ 3 tầng XCConfigurationList (project, Runner target, RunnerTests target) — xem §2.1.
2. Tạo `.xcconfig` riêng cho flavor (`ios/Flutter/Debug-<flavor>.xcconfig`, …) set `FLUTTER_TARGET`/`APP_DISPLAY_NAME` — xem §2.3.
3. Sửa scheme để LaunchAction/ProfileAction/AnalyzeAction/ArchiveAction trỏ đúng `Debug-<flavor>`/`Release-<flavor>`/`Profile-<flavor>` (KHÔNG để lại config trơn — chỉ `TestAction` được phép giữ `Debug` trơn, đây là convention chung, không ảnh hưởng flavor detection vì Flutter không đọc TestAction).
4. `pod install` lại để CocoaPods generate xcconfig tương ứng — xem §2.5.

Sửa project.pbxproj tay rất dễ hỏng cấu trúc tham chiếu chéo (ID) — dùng gem `xcodeproj` (Ruby) để thao tác an toàn thay vì sửa text thô, xem ví dụ script ở cuối §8.

```bash
# Detect: liệt kê scheme nào đang trỏ config KHÔNG mang flavor suffix (trơn Debug/Release/Profile)
# ở các action ngoài TestAction — dấu hiệu chắc chắn sẽ lỗi khi build bằng --flavor
for f in ios/Runner.xcodeproj/xcshareddata/xcschemes/*.xcscheme; do
  echo "== $(basename "$f") =="
  grep -E '(Launch|Profile|Analyze|Archive)Action' -A1 "$f" | grep -oE 'buildConfiguration = "[^"]+"'
done
# Kỳ vọng: mọi giá trị đều dạng "Debug-<flavor>"/"Release-<flavor>"/"Profile-<flavor>"
# Dấu hiệu lỗi: thấy "Debug"/"Release"/"Profile" trơn ở scheme KHÔNG phải Runner mặc định
```

## 5. Checklist trước khi coi 1 nhánh (App, Env) là "xong"

- [ ] Build configuration (iOS) / flavor combination (Android) tồn tại và build được — không chỉ "có scheme".
- [ ] `flutter run`/`flutter build` chạy hết, log show đúng entry point (`main_<app>.dart`).
- [ ] Bundle ID / Application ID đúng convention, khác mọi (App,Env) khác.
- [ ] App hiện đúng display name của app đó (không phải tên app khác dính lại do copy-paste).
- [ ] App hiện đúng icon của app đó.
- [ ] Cài 2 app cùng lúc trên 1 máy thật/simulator — verify không đè lẫn nhau.
- [ ] Router: app chạy đúng router cụ thể của mình (`AppRouterAdmin`/`AppRouterUser`), không lẫn route của app kia — verify bằng cách thử điều hướng tới toàn bộ tab/flow chính.
- [ ] Không có page/route class nào trùng tên giữa 2 router (grep nhanh trước khi chạy `build_runner` — xem §4.3).
- [ ] `android:label` / `CFBundleDisplayName` thực sự đổi theo app khi build 2 app liên tiếp — không chỉ kiểm tra config có khai báo biến, phải build ra và nhìn thấy tên đổi thật (xem §4.4).

## 6. Anti-pattern — tránh lặp lại

| ❌ | ✅ | Vì sao |
|---|---|---|
| Chỉ hoàn thiện config cho 1 env (thường là dev), để scheme staging/prod trỏ config "sẽ tạo sau" | Tạo đủ N×M×3 config ngay từ đầu, kể cả rỗng/tạm | Scheme mồ côi build lỗi đúng lúc cần gấp nhất (release) |
| Đổi tên app giữa chừng (vd `driver` → `user` → `driver`) mà không dọn hết các tầng | Chốt tên 1 lần, nếu phải đổi thì `grep -ri "<tên cũ>"` toàn bộ `ios/`/`android/` và sửa hết trong 1 lần | Rác naming ở Pods xcconfig / scheme khiến review sau này không biết config nào còn dùng thật |
| `CFBundleDisplayName` / Android `app_name` hardcode 1 chuỗi copy từ app đầu tiên | Luôn qua biến (`$(APP_DISPLAY_NAME)` / `resValue`) map riêng theo config/flavor | App thứ 2 build ra vẫn hiện tên app thứ nhất — bug âm thầm, không crash, chỉ sai UX |
| Dùng chung 1 asset icon cho mọi app | Source set / asset catalog riêng theo App | 2 app cài cạnh nhau trông giống hệt, user không phân biệt được |
| Copy scheme cho app mới nhưng quên đổi `buildConfiguration` bên trong | Sau khi copy scheme, `grep buildConfiguration` để verify | Build "app B" nhưng thực chất build config của app A — bundle ID sai lặng lẽ |
| Tạo sẵn thư mục config rỗng (`ios/config/<env>/`) nhưng không có nội dung, cũng không ai note lại là chưa làm | Nếu chưa làm, note rõ trong README/CHANGELOG hoặc xoá thư mục rỗng | Người sau tưởng đã setup xong, không biết là placeholder |
| 1 router chứa route của cả 2 app, ẩn/hiện qua `if (appFlavor == ...)` trong `routes` getter | N router riêng, mỗi cái implement `AppRouterBase`, chọn qua DI ở bootstrap (xem §1.3) | Route "chết" của app kia vẫn compile vào bundle, dễ bấm nhầm lúc test, review khó biết route nào thật sự dùng |
| Page/route class trùng tên giữa 2 app vì đặt tên theo domain chung (`HomePage`) và chỉ phân biệt bằng thư mục | Prefix tên class theo app (`HomeAdminPage`) — xem §4.3 | auto_route không quan tâm thư mục, chỉ quan tâm tên class → generate `.gr.dart` conflict hoặc route trỏ nhầm app |
| `resValue`/biến display name khai báo trong build config nhưng manifest/plist vẫn hardcode chuỗi cũ | Sau khi thêm biến, `grep` lại đúng file tiêu thụ (`AndroidManifest.xml`, `Info.plist`) để verify đã wire — xem §4.4 | Build pass, APK cài được, nhưng tên hiển thị sai — lỗi không ai để ý vì không có gì đỏ |
| 1 flavor App có `applicationId`/`applicationIdSuffix` tường minh, flavor App còn lại không khai gì, rơi về `defaultConfig` gốc | Mọi flavor ở dimension `app` đều tự khai `applicationId` đầy đủ, đối xứng — xem §4.8 | Build vẫn pass (2 ID cuối cùng vẫn khác nhau) nhưng 1 app không có identity riêng, dễ nhầm khi thêm trục Env sau này |
| Scheme trỏ config trơn (`Debug`/`Release`/`Profile`, không mang flavor suffix) — config này CÓ THẬT, Xcode build qua IDE vẫn chạy | Mọi action của scheme (trừ TestAction) trỏ config có tên MANG flavor suffix (`Debug-user`) — xem §4.10 | `flutter run --flavor` báo lỗi mơ hồ ("must specify --flavor" / "expects a build configuration named...") dù scheme + config đều tồn tại thật, dễ tưởng nhầm là bug khác |
| Áp patch `PODS_CONFIGURATION_BUILD_DIR` trong Podfile "phòng trước" vì tưởng CocoaPods luôn lệch thư mục build với flavored config | Chỉ `pod install` lại sau khi thêm config mới; patch này KHÔNG cần thiết với Podfile template hiện đại — xem §2.5 | Thêm code phức tạp, khó hiểu để giải quyết 1 vấn đề không tồn tại — người sau đọc code tưởng là bắt buộc |

## 7. Liên hệ với skill env-flavor đơn giản

Nếu project chỉ cần 1 app × N env (không có trục App) thì đừng áp dụng ma trận 2 chiều ở đây — dùng pattern flavor-per-env thông thường (1 trục, đơn giản hơn nhiều), xem [flutter-deployment-guide](../flutter-deployment-guide/SKILL.md): Dart entry `main_<env>.dart`, Xcode config `Debug-<env>`, Android `productFlavors` 1 dimension. Chỉ leo lên ma trận 2 trục khi thực sự có ≥2 app khác nhau về bundle ID/icon/tên cần build từ cùng 1 codebase.

## 8. Cách detect nhanh khi audit 1 project multi-app có sẵn

```bash
# 1. Đếm build configuration thực có trong project.pbxproj
grep -c "isa = XCBuildConfiguration;" ios/Runner.xcodeproj/project.pbxproj

# 2. Liệt kê build configuration mà từng scheme yêu cầu
for f in ios/Runner.xcodeproj/xcshareddata/xcschemes/*.xcscheme; do
  echo "== $f =="; grep -o 'buildConfiguration = "[^"]*"' "$f" | sort -u
done
# → đối chiếu mỗi config này có thực sự tồn tại trong project.pbxproj không (bước 1)

# 3. Check display name có hardcode không (dấu hiệu: không thấy $(...))
grep -A1 "CFBundleDisplayName" ios/Runner/Info.plist

# 4. Check bundle ID có unique theo cả 2 trục không
grep "PRODUCT_BUNDLE_IDENTIFIER" ios/Runner.xcodeproj/project.pbxproj | sort -u

# 5. Check icon asset catalog có tách riêng theo app không
find ios/Runner -iname "*.xcassets" -maxdepth 1

# 6. Android — check flavorDimensions có đủ 2 trục không
grep -A3 "flavorDimensions" android/app/build.gradle.kts

# 7. Check Android manifest label có thực sự wire vào resValue không (xem §4.4)
grep "android:label" android/app/src/main/AndroidManifest.xml

# 8. Check icon source set Android có tách theo App không, hay chỉ tách theo Env (xem §4.5)
find android/app/src -maxdepth 1 -type d

# 9. Check page/route class trùng tên giữa các router (xem §4.3) — liệt kê tên class @RoutePage
grep -rhoE '^class \w+Page' lib/src/pages lib/router 2>/dev/null | sort | uniq -d

# 10. Check mọi flavor App đều tự khai applicationId riêng, không flavor nào ăn ké defaultConfig (xem §4.8)
grep -A 3 'create("' android/app/build.gradle.kts

# 11. Check không còn file nào import thẳng .gr.dart ngoài chính router.dart (xem §4.9)
grep -rln "app_router.gr.dart'" lib/

# 12. Check scheme nào trỏ config trơn (không mang flavor suffix) ở action khác TestAction (xem §4.10)
for f in ios/Runner.xcodeproj/xcshareddata/xcschemes/*.xcscheme; do
  echo "== $(basename "$f") =="
  grep -E '(Launch|Profile|Analyze|Archive)Action' -A1 "$f" | grep -oE 'buildConfiguration = "[^"]+"'
done
```

Nếu bước 2 phát hiện scheme trỏ config không tồn tại ở bước 1 → nhánh đó **build sẽ lỗi ngay khi chọn scheme**, ưu tiên fix trước khi báo "đã xong multi-app setup". Script gộp đủ cho scheme mồ côi (§4.1) và naming drift (§4.2) nằm ngay trong 2 mục đó — chạy riêng khi audit sâu hơn là đủ, không cần lặp lại ở đây.

### 8.1 Script mẫu — thêm build configuration mới cho 1 flavor bằng gem `xcodeproj` (an toàn hơn sửa `project.pbxproj` tay)

Dùng khi cần thêm flavor mới ở tầng iOS (§2.1, §4.10) — sửa tay file `project.pbxproj` rất dễ hỏng cấu trúc tham chiếu chéo ID. Dùng gem `xcodeproj` qua system Ruby — trên macOS, Ruby cài qua Homebrew thường KHÔNG có gem này, phải dùng `/usr/bin/ruby` hệ thống, nơi CocoaPods đã cài sẵn gem này làm dependency:

```ruby
require 'xcodeproj'

project = Xcodeproj::Project.open('ios/Runner.xcodeproj')
flavor = 'user'          # đổi theo flavor thật đang thêm
bundle_id = 'com.acme.app.user'

def make_xcconfig_ref(project, path, name)
  ref = project.new(Xcodeproj::Project::Object::PBXFileReference)
  ref.include_in_index = '1'
  ref.last_known_file_type = 'text.xcconfig'
  ref.name = name
  ref.path = path
  ref.source_tree = '<group>'
  ref
end

def duplicate_config(project, config, new_name, base_configuration_reference: :same, bundle_id: nil)
  new_config = project.new(Xcodeproj::Project::Object::XCBuildConfiguration)
  new_config.name = new_name
  new_config.build_settings = config.build_settings.dup
  new_config.base_configuration_reference =
    base_configuration_reference == :same ? config.base_configuration_reference : base_configuration_reference
  new_config.build_settings['PRODUCT_BUNDLE_IDENTIFIER'] = bundle_id if bundle_id
  new_config
end

# 2 file .xcconfig mới (Debug-<flavor>.xcconfig / Release-<flavor>.xcconfig phải tự tạo trước ở ios/Flutter/)
flutter_group = project.main_group['Flutter']
debug_ref = make_xcconfig_ref(project, "Flutter/Debug-#{flavor}.xcconfig", "Debug-#{flavor}.xcconfig")
release_ref = make_xcconfig_ref(project, "Flutter/Release-#{flavor}.xcconfig", "Release-#{flavor}.xcconfig")
flutter_group.children << debug_ref
flutter_group.children << release_ref

# Project-level (không baseConfigurationReference)
proj_list = project.root_object.build_configuration_list
%w[Debug Release Profile].each do |base|
  cfg = proj_list.build_configurations.find { |c| c.name == base }
  proj_list.build_configurations << duplicate_config(project, cfg, "#{base}-#{flavor}")
end

# Runner target (baseConfigurationReference → xcconfig mới, set PRODUCT_BUNDLE_IDENTIFIER)
runner = project.targets.find { |t| t.name == 'Runner' }
runner_list = runner.build_configuration_list
{ 'Debug' => debug_ref, 'Release' => release_ref, 'Profile' => release_ref }.each do |base, ref|
  cfg = runner_list.build_configurations.find { |c| c.name == base }
  runner_list.build_configurations << duplicate_config(project, cfg, "#{base}-#{flavor}", base_configuration_reference: ref, bundle_id: bundle_id)
end

project.save
puts 'Done.'
```

Sau khi chạy: (1) tạo nội dung thật cho 2 file `ios/Flutter/Debug-<flavor>.xcconfig`/`Release-<flavor>.xcconfig` (xem §2.3), (2) sửa scheme trỏ đúng config mới (§2.2, §4.10), (3) `pod install` lại (§2.5), (4) verify bằng `xcodebuild -list -project ios/Runner.xcodeproj` — Build Configurations/Schemes phải liệt kê đủ tên mới.

## 9. Case thật: audit hiện trạng `rual_transpo_rider_mobile`

Không dùng ví dụ project khác — audit trực tiếp trạng thái THẬT của chính repo này (lệnh dùng ở §8), để thấy gần như mọi anti-pattern ở §4/§6 đang có mặt ở ít nhất 1 tầng ngay lúc viết skill này. Đây là danh sách gap thật, không phải checklist đã xong — dùng làm input trực tiếp cho §10.

### 9.1 Trạng thái 2 trục hiện tại

- **Trục App**: Rider (Dart: `rider`) và Driver (Dart: `driver`) — nhưng tầng Gradle/iOS build config CHƯA đổi theo lần rename Dart này, vẫn giữ tên cũ `User` cho app Driver (naming quirk đã ghi trong `CLAUDE.md`/`flutter-mobile-dev.md`, tái hiện lại ở §9.3 dưới đây tại tầng iOS scheme).
- **Trục Env**: có 3 env (`development`/`staging`/`production`) nhưng CHỈ hoàn thiện ở tầng Gradle (Android) — chưa đủ ở tầng Dart entry point và tầng iOS build configuration.
- **DI thật của repo dùng `bool isRider`**, không phải `enum AppFlavor` như ví dụ generic ở §1.2 (đó là template chung cho skill này, không phải code thật của repo) — `setUpInjector({required bool isRider})` là nơi DUY NHẤT rẽ nhánh, đúng nguyên tắc "rẽ nhánh 1 lần ở bootstrap" (§1.1).

### 9.2 Android — 1 dimension gộp sẵn (§3.3), KHÔNG phải 2 dimension mặc định

```kotlin
// android/app/build.gradle.kts — trạng thái THẬT
flavorDimensions("default")   // 1 dimension duy nhất, không phải app × env

productFlavors {
    create("developmentRider") { dimension = "default"; applicationId = "com.example.rual_transpo_rider_mobile"; resValue("string", "app_name", "Rual transpo rider") }
    create("stagingRider")     { dimension = "default"; applicationId = "com.example.rual_transpo_rider_mobile"; resValue("string", "app_name", "Rual transpo rider") }
    create("productionRider")  { dimension = "default"; applicationId = "com.example.rual_transpo_rider_mobile"; resValue("string", "app_name", "Rual transpo rider") }
    create("developmentUser")  { dimension = "default"; applicationId = "com.example.rual_transpo_user_mobile"; resValue("string", "app_name", "Rual transpo user") }
    create("stagingUser")      { dimension = "default"; applicationId = "com.example.rual_transpo_user_mobile"; resValue("string", "app_name", "Rual transpo user") }
    create("productionUser")   { dimension = "default"; applicationId = "com.example.rual_transpo_user_mobile"; resValue("string", "app_name", "Rual transpo user") }
}
```

**Gap thật #1 (vi phạm Nguyên tắc cốt lõi #4)**: `applicationId` chỉ khác nhau theo App (`...rider_mobile` vs `...user_mobile`), KHÔNG khác theo Env — cả 3 flavor `developmentRider`/`stagingRider`/`productionRider` dùng CHUNG 1 applicationId. Hệ quả: cài `developmentRider` rồi cài `stagingRider` trên cùng máy sẽ ĐÈ LÊN NHAU, không chạy song song được để test 2 env cùng lúc. Nếu đây không phải quyết định có chủ đích (điều kiện hợp lệ duy nhất — xem §4.7), cần bổ sung `applicationIdSuffix` (`.stg`, giữ `production` không suffix) theo từng env.

**Gap thật #2 (đúng case §4.4)**: `resValue("string", "app_name", ...)` khai cho cả 6 flavor, nhưng:

```bash
$ grep android:label android/app/src/main/AndroidManifest.xml
android:label="rual_transpo_rider_mobile"
```

— hardcode chuỗi cứng, KHÔNG phải `android:label="@string/app_name"`. Mọi flavor build ra hiện CÙNG 1 TÊN trên home screen bất kể `resValue` khai gì — `resValue` hiện đang vô nghĩa với display name.

**Gap thật #3 (đúng case §4.5)**: source set icon hiện chỉ tách theo Env, KHÔNG tách theo App:

```bash
$ find android/app/src -maxdepth 1 -type d
android/app/src/staging  android/app/src/development  android/app/src/profile
android/app/src/production  android/app/src/main  android/app/src/debug
```

Không có `rider/`/`user/` (hay `developmentRider/`, …) — Rider và Driver hiện SHARE CHUNG 1 icon. Vi phạm Nguyên tắc cốt lõi #5.

### 9.3 iOS — chỉ tầng `development` là thật; `staging`/`production` là scheme mồ côi (§4.1) — Driver còn dính thêm naming drift (§4.2)

6 file scheme tồn tại (đúng ma trận 2 app × 3 env) + `Runner.xcscheme` mặc định, nhưng build configuration thật trong `project.pbxproj` (verify bằng lệnh audit ở §8 bước 1-2) chỉ có `Debug/Release/Profile-developmentRider` và `Debug/Release/Profile-developmentDriver` — KHÔNG có config nào cho `staging`/`production`:

```
developmentRider.xcscheme  → buildConfiguration = "Debug-developmentRider"  ✅ config thật, tên khớp app
productionRider.xcscheme   → buildConfiguration = "Debug-productionRider"   ❌ config KHÔNG tồn tại (§4.1)
stagingRider.xcscheme      → buildConfiguration = "Debug-stagingRider"      ❌ config KHÔNG tồn tại (§4.1)
developmentDriver.xcscheme → buildConfiguration = "Debug-developmentDriver" ✅ config thật, tên khớp app
productionDriver.xcscheme  → buildConfiguration = "Debug-productionUser"    ❌ config KHÔNG tồn tại, VÀ tên lệch sang "User" thay vì "Driver" (§4.1 + §4.2)
stagingDriver.xcscheme     → buildConfiguration = "Debug-stagingUser"       ❌ config KHÔNG tồn tại, VÀ tên lệch (§4.1 + §4.2)
```

Rider's `staging`/`production` scheme chỉ vi phạm §4.1 (thiếu config, tên bên trong vẫn nhất quán "Rider"). Driver's `staging`/`production` scheme vi phạm CẢ HAI: thiếu config VÀ tên bên trong dùng "User" — chính là naming quirk Dart `driver` ↔ Gradle/iOS `User` đã ghi ở `CLAUDE.md`, tái hiện ở tầng scheme thay vì tầng Gradle flavor.

**Gap thật #4 (đúng case §2.3/§4.4)**: `CFBundleDisplayName` hiện hardcode:

```bash
$ grep -A1 CFBundleDisplayName ios/Runner/Info.plist
<key>CFBundleDisplayName</key>
<string>Rual Transpo Rider Mobile</string>
```

Không phải biến `$(APP_DISPLAY_NAME)` — khi hoàn thiện build Driver/staging/production trên iOS, mọi build vẫn sẽ hiện tên "Rual Transpo Rider Mobile" trừ khi sửa lại thành biến trước (xem §2.3).

### 9.4 Dart — chỉ có entry `_dev`, chưa có `_stg`/`_prod`

```bash
$ find lib -iname "main*.dart"
lib/app/main_rider_dev.dart
lib/app/main_driver_dev.dart
```

Chỉ 2 file (2 app × 1 env `dev`) — khớp đúng cảnh báo đã ghi ở đầu `flutter-deployment-guide/SKILL.md`. Dù Gradle đã có flavor `stagingRider`/`productionRider`, build ra vẫn chạy cấu hình Dart của `dev` (baseURL, feature flag qua `AppConfig`, …) vì chưa có `main_rider_stg.dart`/`main_rider_prod.dart` tương ứng để load đúng `.env.<env>`.

## 10. Việc cần làm để hoàn thiện trục Env còn dang dở trong `rual_transpo_rider_mobile`

Dựa trực tiếp trên gap đã audit ở §9, thứ tự việc cần làm khi muốn build thật `staging`/`production` (không chỉ `development`):

1. **Android — quyết định giữ 1 dimension hay tách 2 dimension** (trade-off ở §3.3). Nếu giữ 1 dimension (ít thay đổi nhất): thêm `applicationIdSuffix`/`versionNameSuffix` cho `staging*`/`production*` flavor để mỗi (App, Env) có applicationId riêng — fix Gap #1 ở §9.2. Nếu tách 2 dimension (khuyến nghị dài hạn, xem §3): tách `app` (`rider`/`user`) × `env` (`development`/`staging`/`production`), Gradle tự nhân ma trận, applicationId tự ghép đúng, không cần tự tay giữ đối xứng.
2. **Android — wire `resValue("string", "app_name", ...)` vào `AndroidManifest.xml`**: đổi `android:label="rual_transpo_rider_mobile"` (hardcode) thành `android:label="@string/app_name"` — fix Gap #2 ở §9.2, xem thêm §4.4.
3. **Android — tách icon source set theo App**, không chỉ theo Env: thêm `android/app/src/rider/res/mipmap-*` và `android/app/src/user/res/mipmap-*` (tên source set phải khớp đúng tên flavor thật — xem §3.1) — fix Gap #3 ở §9.2, xem thêm §4.5.
4. **iOS — tạo đủ build configuration cho `staging`/`production`** ở cả 3 tầng XCConfigurationList (project/Runner/RunnerTests), dùng script gem `xcodeproj` ở §8.1 — fix phần "config không tồn tại" ở §9.3.
5. **iOS — sửa 2 scheme của Driver (`stagingDriver.xcscheme`, `productionDriver.xcscheme`) để buildConfiguration bên trong dùng đúng tên `...Driver`, không phải `...User`**, TRƯỚC khi tạo config mới ở bước 4 — nếu làm ngược thứ tự sẽ tạo nhầm config tên `-stagingUser`/`-productionUser` rồi phải đổi tên lại lần 2. Fix phần naming drift ở §9.3, xem thêm §4.2.
6. **iOS — đổi `CFBundleDisplayName` trong `Info.plist` sang biến `$(APP_DISPLAY_NAME)`**, map giá trị riêng trong `.xcconfig` từng config mới — fix Gap #4 ở §9.3, xem thêm §2.3.
7. **iOS — mở rộng glob trong patch `post_install` của `Podfile`** (hiện chỉ khớp `Pods-Runner.*-development*.xcconfig`) để khớp cả `staging`/`production` — fix gap đã ghi ở §2.5; thiếu bước này thì `pod install` xong vẫn lỗi linker khi build 2 env mới.
8. **Dart — quyết định có cần nhân entry point theo Env hay không**: nếu Env chỉ đổi baseURL/feature flag (không đổi DI/router) → giữ `main_rider_dev.dart`/`main_driver_dev.dart`, đọc Env qua `--dart-define=ENV=` — nhưng phải tự thêm flag này vào lệnh build/run cho `staging`/`production` vì hiện code chỉ có 1 entry point ứng với 1 env. Nếu cần rẽ nhánh DI/router theo Env → tạo thêm `main_rider_stg.dart`/`main_rider_prod.dart`/`main_driver_stg.dart`/`main_driver_prod.dart`.
9. **Sau khi xong — chạy lại checklist §5 cho từng ô (App, Env) mới**, và chạy lại toàn bộ lệnh audit ở §8 để xác nhận không còn scheme mồ côi/naming drift/`resValue` chưa wire nào sót lại.

Không cần đổi lại router (`AppRouter`/`AppRouterUser`) hay app-root widget (`rual_transpo_rider_app.dart`/`rual_transpo_driver_app.dart`) — trục Env không ảnh hưởng routing/DI structure, chỉ ảnh hưởng applicationId/bundle ID/API base URL/build configuration. Đây chính là lý do Nguyên tắc cốt lõi tách riêng "App quyết định code path nào chạy" khỏi "Env chỉ đổi config/data nguồn nào".
