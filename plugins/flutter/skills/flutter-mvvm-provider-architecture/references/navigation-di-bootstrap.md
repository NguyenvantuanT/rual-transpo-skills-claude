# Navigation, DI, bootstrap, AppConfig

## Navigation — AutoRoute + AppRouterBase

Dự án 1 app: 1 router `AppRouter extends AppRouterBase`. Multi-app (ví dụ dưới): các app có route/flow khác nhau → **N router cụ thể dùng chung 1 abstraction**, chọn qua DI (chi tiết: skill `flutter-multi-app-flavor`):

```dart
// lib/router/app_router_base.dart
abstract class AppRouterBase extends RootStackRouter {}

class AppRouteObserver extends AutoRouterObserver {
  // log 🟢 PUSH / 🔴 POP / 🔄 REPLACE / 📌 TAB qua dart:developer log()
}

// lib/router/app_router.dart
part 'app_router.gr.dart';

@AutoRouterConfig()
class AppRouter extends AppRouterBase {           // Customer app
  @override
  RouteType get defaultRouteType => const RouteType.material();

  @override
  List<AutoRoute> get routes => [
    CupertinoRoute(page: SplashCustomerRoute.page, initial: true),
    CupertinoRoute(page: MainCustomerRoute.page),
    CupertinoRoute(page: HomeRoute.page),
    CupertinoRoute(page: FullMapRoute.page),
    CupertinoRoute(page: OrderRoute.page),
    CupertinoRoute(page: OrderDetailsRoute.page),
    CupertinoRoute(page: VoucherConfirmedRoute.page),
    CupertinoRoute(page: OnDemandRequestRoute.page),
    CupertinoRoute(page: QueueActiveRoute.page),
  ];
}

@AutoRouterConfig()
class AppRouterUser extends AppRouterBase {        // Merchant app — nhỏ hơn nhiều
  @override
  RouteType get defaultRouteType => const RouteType.material();

  @override
  List<AutoRoute> get routes => [
    CupertinoRoute(page: SplashMerchantRoute.page, initial: true),
    CupertinoRoute(page: HomeMerchantRoute.page),
  ];
}
```

Toàn bộ route đều dùng `CupertinoRoute`. Sau khi edit `app_router.dart` hoặc thêm page mới có `@RoutePage()`:

```bash
fvm flutter pub run build_runner build --delete-conflicting-outputs
```

`app_router.gr.dart` (sinh bằng `part 'app_router.gr.dart'`) tracked hay gitignore tuỳ dự án — dù thế nào cũng KHÔNG được hand-edit hay import trực tiếp.

Quy tắc navigation:

- Push (trong VM): `appRouter.push(FooRoute(args: ...))`. Push (trong widget hiếm khi cần): `context.router.push(FooRoute())`.
- Replace all (sau splash check session): `appRouter.replaceAll([const MainRoute()])` (tên route main của app).
- Pop / dismiss: `appRouter.maybePop()` (trong VM) — KHÔNG BAO GIỜ `Navigator.of(context).pop()` cho navigation thật (ngoại lệ đã nêu ở phần Page Pattern chỉ dành cho dismiss `AppLoading` dialog).
- **KHÔNG import `app_router.gr.dart` trực tiếp** — import `app_router.dart`.
- Multi-app: route thuộc app nào khai vào ĐÚNG router app đó.
- Bộ base chưa có `AuthGuard` mặc định — điều hướng đầu app quyết định ở Splash page (check `context.router.topRoute.name == Splash*Route.name` rồi `replaceAll`). Dự án có guard riêng thì ghi trong CLAUDE.md.

## Dependency Injection — get_it

`lib/src/utils/locator.dart` — với multi-app, **nơi DUY NHẤT trong codebase được rẽ nhánh theo cờ app** (vd `isCustomer`):

```dart
GetIt locator = GetIt.instance;

void setUpInjector({required bool isCustomer}) {
  locator.registerLazySingleton(() => SharedPrefs());
  locator.registerLazySingleton(() => ApiClient());
  locator.registerLazySingleton(() => ActiveOrderServices());
  locator.registerLazySingleton(() => LocationService());
  locator.registerLazySingleton<AppRouterBase>(
    () => isCustomer ? AppRouter() : AppRouterUser(),
  );
}
```

- Trong VM: dùng inherited fields của `BaseViewModel` (`api`, `prefs`, `appRouter`, `locationService`, `activeOrderServices`) — không gọi `locator<T>()` trực tiếp.
- Ngoài VM (widget root, `main_*.dart`): `locator<AppRouterBase>()` hoặc `locator<SharedPrefs>()` — chấp nhận được (xem `<App1>App.build()` dùng `locator<AppRouterBase>().config(...)`).
- Service mới → thêm field vào `BaseViewModel` CHỈ khi nhiều feature cần; service 1-feature thì inject qua constructor VM.
- Chi tiết rẽ nhánh multi-app sâu hơn (naming giữa Gradle/iOS/Dart, entry points): skill `flutter-multi-app-flavor`.

## Bootstrap — main_<app>_<env>.dart

Mỗi entry point inline toàn bộ init flow — **không có `bootstrap.dart` chung**. Thứ tự chuẩn (ví dụ `lib/app/main_customer_dev.dart` ):

```dart
void main() {
  runZonedGuarded<Future<void>>(
    () async {
      WidgetsFlutterBinding.ensureInitialized();
      await dotenv.load(fileName: '.env.dev');              // 1. env
      AppConfig.create(                                      // 2. config
        appName: "<App name> dev",
        baseUrl: AppBaseUrl.baseUrl,
        baseSocketUrl: AppBaseUrl.socketUrl,
        appsflyerKey: AppBaseUrl.appsflyerKey,
        revenueCatApiKey: AppBaseUrl.revenueCatApiKey,
        googleMapsApiKey: AppBaseUrl.googleMapsApiKey,
        showDebugBanner: false,
        flavor: Flavor.dev,
      );
      SystemChrome.setSystemUIOverlayStyle(/* status bar */);      // 3. system UI
      await SystemChrome.setPreferredOrientations([...]);
      Provider.debugCheckInvalidValueType = null;                  // 4. provider debug flag
      setUpInjector(isCustomer: AppConfig.shared.isCustomer);            // 5. DI
      await locator<SharedPrefs>().initialise();                   // 6. local storage
      runApp(const <App1>App());                         // 7. run
    },
    (error, stack) => debugPrint('$error'),
  );
}
```

Các entry point khác (app khác / env khác) giữ đúng flow này, chỉ khác `appName`, cờ app, file `.env.<env>` và `Flavor.<env>`.

App-root widget (`<app1>_app.dart` / `<app2>_app.dart`): `AppProvider(theme:, locale:, builder:)` wrap `MaterialApp.router` với `routerConfig: locator<AppRouterBase>().config(navigatorObservers: () => [AppRouteObserver()])`, localization delegates của `S`, textScaler khoá `1.0`.

### AppConfig

`lib/app/app_config.dart` — singleton `AppConfig.shared`, set qua `AppConfig.create(...)` trong từng `main_*.dart`. Field hiện có: `appName`, `baseUrl`, `baseSocketUrl`, `appsflyerKey`, `revenueCatApiKey`, `googleMapsApiKey`, `flavor` (`Flavor { dev, stg, prod }`), `showDebugBanner`, `isCustomer`. Thêm field mới:

1. Thêm field + constructor param + `create()` param vào `AppConfig`.
2. Đọc từ `.env*` qua `lib/src/constants/app_base_url.dart` (`AppBaseUrl.*`).
3. Pass value trong MỌI `main_*.dart` entry point.

