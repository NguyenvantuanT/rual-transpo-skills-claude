# Dart layer: entry point, AppConfig, router

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

