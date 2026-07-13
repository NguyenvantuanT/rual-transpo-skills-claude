---
name: flutter-mvvm-provider-architecture
description: |
  Kiến trúc chuẩn cho rual_transpo_rider_mobile theo MVVM + Provider — BaseViewModel (ChangeNotifier) + MixinBasePage + get_it (DI) + auto_route (AppRouterBase, 2 router Rider/Driver) + Dio (ApiClient) + flutter_intl (2 locale: fr/en) + flutter_gen (AppAsset) + EventBus (cross-VM) + multi-app flavor (Rider/Driver).
  Sử dụng khi: implement feature / page / ViewModel mới, thêm navigation flow, wire DI service, scaffold một flow mới, cross-VM communication, theme, hoặc review code để check architecture compliance.
---

# Flutter MVVM + Provider Architecture — rual_transpo_rider_mobile

> **Đọc trước**: `.claude/CLAUDE.md` quy định các rule bắt buộc của repo. Mọi code example trong skill này lấy từ code thật của repo — code mới phải **khớp code xung quanh**, không tự ý nghĩ pattern mới.

## Tổng quan

Rual Transpo Rider Mobile là app transportation/rider cho thị trường Pháp (`fr` là locale mặc định), gồm **2 app** dùng chung 1 codebase: **Rider** (hành khách) và **Driver** (a.k.a "user-facing" trong lịch sử đặt tên — xem `flutter-multi-app-flavor` cho chi tiết naming mismatch Gradle/Dart). Kiến trúc tách lớp rõ ràng, mỗi feature = 1 VM + 1 Page + optional widgets:

- **State**: `provider` + `ChangeNotifier`. Mỗi VM extend `BaseViewModel` (đã inherit sẵn `api`, `prefs`, `appRouter`, `locationService`, `activeTripServices` qua `GetIt`).
- **Navigation**: `auto_route` — abstraction `AppRouterBase`, 2 router cụ thể `AppRouter` (Rider) / `AppRouterUser` (Driver), chọn qua DI theo cờ `isRider`.
- **DI**: `get_it` (`locator`) với `setUpInjector({required bool isRider})` ở `lib/src/utils/locator.dart` — **nơi duy nhất** được rẽ nhánh theo app.
- **Data**: REST qua `ApiClient` (Dio) — xem skill `flutter-networking-and-data` cho phần internals (interceptor, error mapping, socket URL).
- **Models**: class Dart thuần, hand-written `fromJson`/`toJson`, tất cả fields nullable. KHÔNG dùng `freezed`/`json_serializable` dù package này vẫn nằm trong `dev_dependencies` (chưa dọn).
- **Pages**: `StatelessWidget with MixinBasePage<T>` — mixin wrap `ChangeNotifierProvider` + `VisibilityDetector` + snack-bar wiring + state machine + tap-to-dismiss-keyboard.
- **i18n**: `flutter_intl`, 2 ARB (`fr` main + `en`); truy cập qua `S.current.<key>` — xem skill `flutter-internationalization`.
- **Multi-app**: `lib/app/main_rider_dev.dart` / `lib/app/main_driver_dev.dart` chia sẻ codebase — xem skill `flutter-multi-app-flavor`.

## Khi nào sử dụng

- Implement feature / page / ViewModel mới
- Thêm navigation flow mới
- Wire 1 singleton service mới vào `locator`
- Cross-VM communication (EventBus)
- Review Flutter code để check architecture compliance

## Kiến trúc tổng quan

```
lib/
├── rual_transpo_rider_app.dart   # Rider app root — MaterialApp.router
├── rual_transpo_driver_app.dart  # Driver app root — MaterialApp.router
├── app/
│   ├── app_config.dart            # AppConfig singleton (appName, baseUrl, flavor, isRider, keys)
│   ├── main_rider_dev.dart        # main(): dotenv → AppConfig → DI → SharedPrefs → runApp(RualTranspoRiderApp)
│   └── main_driver_dev.dart       # main(): cùng flow, isRider: false, runApp(RualTranspoDriverApp)
├── router/
│   ├── app_router_base.dart       # abstract class AppRouterBase extends RootStackRouter + AppRouteObserver
│   ├── app_router.dart            # @AutoRouterConfig: AppRouter (Rider) + AppRouterUser (Driver)
│   └── app_router.gr.dart         # generated (part 'app_router.gr.dart'), TRACKED bởi git, KHÔNG import trực tiếp
└── src/
    ├── base/                      # base_vm.dart (BaseViewModel + ChangeState) + base_page.dart (MixinBasePage)
    ├── components/                # shared UI: button/, chip/, circle/, input/, loading/, map/, snack_bar/
    ├── constants/                 # AppConstants, AppBaseUrl (đọc dotenv)
    ├── gen/                       # flutter_gen output — assets.gen.dart (AppAsset), fonts.gen.dart (FontFamily)
    ├── generated/                 # intl_utils output — l10n.dart (S), intl/*
    ├── l10n/                      # intl_fr.arb (main) + intl_en.arb
    ├── models/                    # data class + enums/ + driver/ + delete_late/ (xem ghi chú bên dưới)
    ├── pages/                     # main_rider/, main_driver/, splash_rider/, splash_driver/
    ├── resources/                 # app_color.dart, app_style.dart + *_scheme.dart (ThemeExtension)
    ├── services/                  # remote/ (ApiClient) local/ (SharedPrefs) location/ active_trip/
    ├── theme/                     # app_theme.dart (AppTheme.lightTheme / darkTheme)
    └── utils/                     # locator, app_provider, extension, svg_marker, ...
```

Quy tắc:

- **Một feature = một folder dưới `lib/src/pages/<app>/<feature>/`**, chứa `<feature>_page.dart` + `<feature>_vm.dart` + `widgets/`.
- **Route riêng của app nào khai trong router của app đó** — page thuộc Rider ở dưới `main_rider/`, Driver ở dưới `main_driver/`.
- **Một service = một file dưới `lib/src/services/<group>/<name>_service.dart`** (`ActiveTripServices`, `LocationService`).
- **Một model = một file** trong `lib/src/models/`, enum ở `lib/src/models/enums/`.
- `lib/src/models/delete_late/` tồn tại thật trong repo — trông giống model tạm/superseded đang chờ dọn. Đây là **nợ kỹ thuật đã biết**, không phải pattern để bắt chước khi tạo model mới.

## State — Provider + ChangeNotifier + BaseViewModel

`enum ChangeState { loading, blank, page, serverError, clone }` khai báo ngay trong `lib/src/base/base_vm.dart` (không tách file riêng). Mọi VM extend `BaseViewModel extends ChangeNotifier`. Base class cung cấp sẵn:

- **Inherited services** (field final, gán từ `locator<T>()` ngay khi construct): `api` (`ApiClient`), `prefs` (`SharedPrefs`), `appRouter` (`AppRouterBase`), `locationService` (`LocationService`), `activeTripServices` (`ActiveTripServices`).
- **Lifecycle hooks**:
  - `onInit()` — abstract, phải override. Constructor của `BaseViewModel` tự `WidgetsBinding.instance.addPostFrameCallback((_) => onInit())`.
  - `onAppear()` / `onDisAppear()` — khai `external`, override khi cần. Được gọi qua wrapper `appear()` / `disAppear()` (public, gọi từ `VisibilityDetector` trong `MixinBasePage`) — wrapper này **nuốt mọi exception** (`try { onAppear.call(); } catch (_) {}`) và **bỏ qua lần `appear()` đầu tiên** nhờ flag `_isFirst` (vì `onInit()` đã lo phần khởi tạo lần đầu).
- **Feedback helpers**: `showLoading()` / `hideLoading()` (có guard `_showLoading` để không gọi callback trùng lặp), `showInfo(msg, {label})` / `showWarning(...)` / `showSuccess(...)` / `showError(...)`, `showErrorConnection()` — dùng `connectivity_plus` để phân biệt `S.current.messageErrorLostConnect` (mất mạng) vs `S.current.messageErrorProcessFailed` (lỗi xử lý). Tất cả các hàm show-message này gọi `hideLoading()` trước khi bắn callback.
- **State machine**: `changeState(ChangeState newState)` — switch toàn bộ UI state của page (mặc định `ChangeState.page`).
- `appLogOut({String? email})` — gọi `onLogOut?.call(email)`, được wire ở `MixinBasePage` (xem phần Page Pattern — logic logout thật ở đó, không phải ở đây).
- `notifyListeners()` đã override để guard `_disposed` — gọi sau dispose không crash.
- VM nắm giữ `StreamSubscription`/controller thì override `dispose()`.

```dart
class HomeVm extends BaseViewModel {
  AppUserModel? _appUser;
  AppUserModel? get appUser => _appUser;

  bool isLoadingTrips = false;

  @override
  void onInit() {
    _appUser = prefs.appUser;
    notifyListeners();
  }

  Future<void> loadUpcomingTrips() async {
    isLoadingTrips = true;
    notifyListeners();
    try {
      final response = await api.dio.get('/trips/upcoming');
      // map response.data sang TripOptionModel ở đây
    } catch (e) {
      showError(S.current.messageErrorProcessFailed);
    } finally {
      isLoadingTrips = false;
      notifyListeners();
    }
  }
}
```

Quy tắc:

- **VM phải extend `BaseViewModel`** và override `onInit()`. Đừng tạo ad-hoc `ChangeNotifier`.
- Mỗi async operation có **own named loading flag** (`isLoadingTrips`, `isLoadingSubmit`). Không share một `isLoading` chung (field `isLoading` có sẵn trong `BaseViewModel` là để phục vụ `showLoading()`/`hideLoading()` dialog-based, KHÔNG dùng nó làm cờ loading cho section UI — xem phần Page Pattern để hiểu rõ 2 pattern khác nhau này).
- Luôn `notifyListeners()` sau khi mutate observable state.
- Dùng inherited services qua `this.api` / `this.prefs` / `this.appRouter` — **không** gọi `locator<T>()` trong VM.

## Page Pattern — MixinBasePage<T>

Mọi page là **`StatelessWidget with MixinBasePage<T extends BaseViewModel>`** + `@RoutePage()`:

```dart
@RoutePage()
class HomePage extends StatelessWidget with MixinBasePage<HomeVm> {
  const HomePage({super.key});

  @override
  Widget build(BuildContext context) {
    return builder(
      () => Scaffold(body: /* ... provider.appUser ... */),
    );
  }

  @override
  HomeVm create() => HomeVm();

  @override
  void initialise(BuildContext context) {}
}
```

Mixin `MixinBasePage<T>` (`lib/src/base/base_page.dart`) cung cấp:

- `provider` getter — VM hiện tại (sync qua `Consumer<T>`).
- `create()` — bắt buộc override, trả fresh VM (wrap trong `ChangeNotifierProvider<T>`).
- `initialise(BuildContext)` — bắt buộc override (để `{}` nếu không cần), chạy một lần trong `create` callback của `ChangeNotifierProvider`.
- `builder(() => WidgetTree)` — wrap UI + wiring callbacks + state machine + `VisibilityDetector` (key = `T.toString()`) cho appear/disappear + `GestureDetector` ngoài cùng tap-anywhere-unfocus keyboard.

Callback wiring thật trong `builder()`:

- `onShowLoading` → `AppLoading.show(context)` (xem phần Loading Overlay bên dưới).
- `onHideLoading` → **`Navigator.of(context).pop()`**. Đây là raw-`Navigator` call **duy nhất được cho phép trong toàn bộ codebase** — nó chỉ dismiss dialog loading vừa mở bằng `showDialog`, KHÔNG phải điều hướng route thật. Mọi navigation thật khác phải qua `context.router` / `appRouter` (xem phần Navigation).
- `onShowInfo/Warning/Success/Error` → `showTopSnackBar(context, AppSnackBar.<variant>(message:, label:))`.
- `onLogOut` → hiện tại chỉ gọi `prefs.removeSession()`; dòng redirect về màn login (`context.router.pushAndPopUntil(...)`) đang **bị comment trong source** — đây là TODO chưa hoàn thiện, không phải đã hoạt động.

State machine trong `Consumer<T>.builder`, switch theo `provider.state`:

| `ChangeState` | Render |
|---|---|
| `clone` | `Container(child: builder.call())` |
| `blank` | `const Scaffold()` |
| `loading` | `const AppLoading()` |
| `serverError` | `const ServerError()` |
| `page` | `builder.call()` |

`ServerError` (`lib/src/components/server_error.dart`) hiện tại literally chỉ là `Center(child: AppLoading())` — một stub cố ý, chưa có UI lỗi thật.

### Loading overlay: 2 pattern coi xét, không trộn lẫn

Repo hiện có **2 cơ chế loading khác nhau, cùng tồn tại**:

1. **Dialog-based overlay** — `showLoading()`/`hideLoading()` trên VM, wired qua `onShowLoading`/`onHideLoading` ở trên, dùng `AppLoading.show(context)` (`lib/src/components/loading/app_loading.dart`): `showDialog` non-dismissible (`barrierDismissible: false`, wrap `PopScope(canPop: false)`), hiện 1 vòng tròn trắng chứa `AppCircularProgress`.
2. **Inline per-operation flag** — `bool isLoadingFoo` trong VM, UI đọc flag để conditionally render `AppCircularProgress` tại chỗ (không phải dialog).

> **Lưu ý xung đột**: `.claude/CLAUDE.md` của repo này có rule "NEVER use `onShowLoading`/`onHideLoading` with a `showDialog` overlay — forbidden". Nhưng code thật ở `base_page.dart` hiện tại **đang wire chính xác pattern đó** (`onShowLoading` → `AppLoading.show()` dùng `showDialog`). Đây là mâu thuẫn thật giữa rule đã viết và code đã có — skill này mô tả **code hiện có** để bạn hiểu hệ thống đang chạy thế nào; không tự ý xoá 1 trong 2 phía khi chưa có quyết định rõ ràng từ team.

Rules:

- **`@RoutePage()` bắt buộc** cho mọi page reachable qua router.
- Pages là `StatelessWidget` — KHÔNG `StatefulWidget`. State thuộc về VM.
- `create()` trả VM mới mỗi lần. Không share VM cross-page.

## Cross-VM Communication — EventBus

Khi VM A cần báo cho VM B (khác page, khác route) — vd rider bấm "Use ticket" ở `HomeQueuedVm` → `MainRiderVm` (VM cha, giữ trạng thái chuyến đi active) cần cập nhật theo. Dùng **EventBus** (`package:event_bus`). Trong repo này, instance **không tập trung ở 1 file `event_bus.dart` chung** — nó khai ngay cạnh VM sở hữu domain đó:

```dart
// lib/src/pages/main_rider/main_rider_vm.dart
EventBus activeTripEventBus = EventBus();

class MainRiderVm extends BaseViewModel {
  ActiveTripStatus? status;

  @override
  void onInit() {
    status = activeTripServices.status;
    notifyListeners();
    activeTripEventBus.on<ActiveTripStatus>().listen((event) {
      status = event;
      notifyListeners();
    });
  }
}
```

**Publisher** — các VM con dưới `main_rider/home/` (`HomeQueuedVm`, `HomeActiveVm`, `HomeMissedVm`, `QueueActiveVm`, `TicketConfirmedVm`) fire lên cùng bus này mỗi khi trip status đổi:

```dart
void onTapUseTicket() {
  activeTripServices.setActiveTripStatus(ActiveTripStatus.ticketActive);
  activeTripEventBus.fire(ActiveTripStatus.ticketActive);
}
```

### Quy tắc

- **1 EventBus cho 1 domain** — không share 1 bus cho nhiều event type khác nhau.
- **Type parameter rõ ràng** — `on<ActiveTripStatus>()`, không `on<dynamic>()`.
- **`fire()` non-blocking**, không chờ result. Không dùng cho critical path.
- **KHÔNG dùng EventBus thay cho `prefs` / VM state**: state persist → `prefs`; local state 1 page → VM field; cross-page ephemeral notification → EventBus.
- Bus khai **cạnh VM sở hữu domain** (không phải ở file trung tâm) là pattern thật của repo hiện tại. Khi số lượng bus tăng lên, cân nhắc gom vào 1 file `lib/src/utils/event_bus.dart` để dễ tra cứu — nhưng đây là **đề xuất cải tiến**, chưa phải convention đã áp dụng.

### Cờ đỏ đã quan sát thấy trong chính repo — đừng lặp lại

`MainRiderVm.onInit()` subscribe `activeTripEventBus.on<ActiveTripStatus>().listen(...)` nhưng **không lưu `StreamSubscription` và không override `dispose()` để cancel**. Đây là gap thật đang tồn tại trong code, không phải pattern mẫu để copy. Khi viết subscriber mới:

- **Lưu subscription vào field `StreamSubscription<T>?` (nullable), KHÔNG `late final`** — `onInit()` chạy qua `addPostFrameCallback` (deferred). Nếu page bị pop/dispose trước khi frame đầu tiên chạy xong, `dispose()` gọi `.cancel()` trên field `late final` chưa được gán → `LateInitializationError`.
- **Cancel trong `dispose()`** bằng `?.cancel()`:

```dart
class MainRiderVm extends BaseViewModel {
  StreamSubscription<ActiveTripStatus>? _statusSub;

  @override
  void onInit() {
    _statusSub = activeTripEventBus.on<ActiveTripStatus>().listen((event) {
      status = event;
      notifyListeners();
    });
  }

  @override
  void dispose() {
    _statusSub?.cancel();
    super.dispose();
  }
}
```

### Khi nào KHÔNG dùng

- VM trong cùng widget tree — truyền callback qua constructor hoặc `context.read<VM>()`.
- Persist state — `prefs`.

## Navigation — AutoRoute + AppRouterBase

2 app có route/flow khác nhau → **2 router cụ thể dùng chung 1 abstraction**, chọn qua DI (chi tiết: skill `flutter-multi-app-flavor`):

```dart
// lib/router/app_router_base.dart
abstract class AppRouterBase extends RootStackRouter {}

class AppRouteObserver extends AutoRouterObserver {
  // log 🟢 PUSH / 🔴 POP / 🔄 REPLACE / 📌 TAB qua dart:developer log()
}

// lib/router/app_router.dart
part 'app_router.gr.dart';

@AutoRouterConfig()
class AppRouter extends AppRouterBase {           // Rider app
  @override
  RouteType get defaultRouteType => const RouteType.material();

  @override
  List<AutoRoute> get routes => [
    CupertinoRoute(page: SplashRiderRoute.page, initial: true),
    CupertinoRoute(page: MainRiderRoute.page),
    CupertinoRoute(page: HomeRoute.page),
    CupertinoRoute(page: FullMapRoute.page),
    CupertinoRoute(page: TripRoute.page),
    CupertinoRoute(page: TripDetailsRoute.page),
    CupertinoRoute(page: TicketConfirmedRoute.page),
    CupertinoRoute(page: OnDemandRequestRoute.page),
    CupertinoRoute(page: QueueActiveRoute.page),
  ];
}

@AutoRouterConfig()
class AppRouterUser extends AppRouterBase {        // Driver app — nhỏ hơn nhiều
  @override
  RouteType get defaultRouteType => const RouteType.material();

  @override
  List<AutoRoute> get routes => [
    CupertinoRoute(page: SplashDriverRoute.page, initial: true),
    CupertinoRoute(page: HomeDriverRoute.page),
  ];
}
```

Toàn bộ route đều dùng `CupertinoRoute`. Sau khi edit `app_router.dart` hoặc thêm page mới có `@RoutePage()`:

```bash
fvm flutter pub run build_runner build --delete-conflicting-outputs
```

`app_router.gr.dart` (sinh bằng `part 'app_router.gr.dart'`) **được track bởi git trong repo này** (không nằm trong `.gitignore`) — vẫn KHÔNG được hand-edit hay import trực tiếp.

Quy tắc navigation:

- Push (trong VM): `appRouter.push(FooRoute(args: ...))`. Push (trong widget hiếm khi cần): `context.router.push(FooRoute())`.
- Replace all (sau splash check session): `appRouter.replaceAll([const MainRiderRoute()])` hoặc `[HomeDriverRoute()]` tuỳ app.
- Pop / dismiss: `appRouter.maybePop()` (trong VM) — KHÔNG BAO GIỜ `Navigator.of(context).pop()` cho navigation thật (ngoại lệ đã nêu ở phần Page Pattern chỉ dành cho dismiss `AppLoading` dialog).
- **KHÔNG import `app_router.gr.dart` trực tiếp** — import `app_router.dart`.
- Route thuộc app nào khai vào ĐÚNG router app đó (Rider vào `AppRouter`, Driver vào `AppRouterUser`).
- Chưa có `AuthGuard` — điều hướng đầu app quyết định ở `SplashRiderPage`/`SplashDriverPage` (check `context.router.topRoute.name == Splash*Route.name` rồi `replaceAll`).

## Dependency Injection — get_it

`lib/src/utils/locator.dart` — **nơi DUY NHẤT trong codebase được rẽ nhánh theo `isRider`**:

```dart
GetIt locator = GetIt.instance;

void setUpInjector({required bool isRider}) {
  locator.registerLazySingleton(() => SharedPrefs());
  locator.registerLazySingleton(() => ApiClient());
  locator.registerLazySingleton(() => ActiveTripServices());
  locator.registerLazySingleton(() => LocationService());
  locator.registerLazySingleton<AppRouterBase>(
    () => isRider ? AppRouter() : AppRouterUser(),
  );
}
```

- Trong VM: dùng inherited fields của `BaseViewModel` (`api`, `prefs`, `appRouter`, `locationService`, `activeTripServices`) — không gọi `locator<T>()` trực tiếp.
- Ngoài VM (widget root, `main_*.dart`): `locator<AppRouterBase>()` hoặc `locator<SharedPrefs>()` — chấp nhận được (xem `RualTranspoRiderApp.build()` dùng `locator<AppRouterBase>().config(...)`).
- Service mới → thêm field vào `BaseViewModel` CHỈ khi nhiều feature cần; service 1-feature thì inject qua constructor VM.
- Chi tiết rẽ nhánh Rider/Driver sâu hơn (naming mismatch Gradle `Rider`/`User` vs Dart `rider`/`driver`, entry points): skill `flutter-multi-app-flavor`.

## Bootstrap — main_<app>_<env>.dart

Mỗi entry point inline toàn bộ init flow — **không có `bootstrap.dart` chung**. Thứ tự chuẩn (từ `lib/app/main_rider_dev.dart` thật):

```dart
void main() {
  runZonedGuarded<Future<void>>(
    () async {
      WidgetsFlutterBinding.ensureInitialized();
      await dotenv.load(fileName: '.env.dev');              // 1. env
      AppConfig.create(                                      // 2. config
        appName: "Rual transpo rider dev",
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
      setUpInjector(isRider: AppConfig.shared.isRider);            // 5. DI
      await locator<SharedPrefs>().initialise();                   // 6. local storage
      runApp(const RualTranspoRiderApp());                         // 7. run
    },
    (error, stack) => debugPrint('$error'),
  );
}
```

`lib/app/main_driver_dev.dart` giống hệt flow, chỉ khác `appName`, KHÔNG truyền `isRider` (mặc định `true` trong `AppConfig.create`) — thực tế `main_driver_dev.dart` set `isRider: false` tường minh, `googleMapsApiKey` không truyền (Driver app chưa cần map). `main_rider_stg.dart` / `main_rider_prod.dart` / `main_driver_stg.dart` / `main_driver_prod.dart` **chưa tồn tại** — cần tạo mới theo đúng shape này, đổi `.env.stg`/`.env.prod` và `Flavor.stg`/`Flavor.prod` khi cần build staging/prod.

App-root widget (`rual_transpo_rider_app.dart` / `rual_transpo_driver_app.dart`): `AppProvider(theme:, locale:, builder:)` wrap `MaterialApp.router` với `routerConfig: locator<AppRouterBase>().config(navigatorObservers: () => [AppRouteObserver()])`, localization delegates của `S`, textScaler khoá `1.0`.

### AppConfig

`lib/app/app_config.dart` — singleton `AppConfig.shared`, set qua `AppConfig.create(...)` trong từng `main_*.dart`. Field hiện có: `appName`, `baseUrl`, `baseSocketUrl`, `appsflyerKey`, `revenueCatApiKey`, `googleMapsApiKey`, `flavor` (`Flavor { dev, stg, prod }`), `showDebugBanner`, `isRider`. Thêm field mới:

1. Thêm field + constructor param + `create()` param vào `AppConfig`.
2. Đọc từ `.env*` qua `lib/src/constants/app_base_url.dart` (`AppBaseUrl.*`).
3. Pass value trong CẢ `main_rider_dev.dart` + `main_driver_dev.dart` (và các entry point khác khi được tạo).

## Local Storage — SharedPrefs

`lib/src/services/local/share_prefs.dart` wrap `FlutterSecureStorage` cho token + user model (+ migration 1 lần từ `SharedPreferences` cũ trong `initialise()`); theme mode và locale code vẫn lưu ở `SharedPreferences` thường:

```dart
prefs.accessToken = token;             // String? — qua FlutterSecureStorage
prefs.appUser = profile;               // AppUserModel? (JSON-encoded, qua FlutterSecureStorage)
final loggedIn = prefs.isLogin;        // bool — accessToken not-empty
prefs.removeSession();                 // logout: xoá accessToken + appUser
```

`SharedPrefs.initialise()` phải `await` trong `main_*.dart` trước `runApp(...)`. Chi tiết Dio/ApiClient/interceptor: skill `flutter-networking-and-data`.

## i18n — flutter_intl (2 locale)

ARB ở `lib/src/l10n/`: `intl_fr.arb` (**main_locale**, `pubspec.yaml` → `flutter_intl.main_locale: fr`, `arb_dir: lib/src/l10n`, `output_dir: lib/src/generated`) + `intl_en.arb`. **Chỉ 2 locale**, không có locale thứ 3.

```dart
import 'package:rual_transpo_rider_mobile/src/generated/l10n.dart';

Text(S.of(context).homeYou)         // trong widget
S.current.messageErrorProcessFailed // trong VM
```

Thêm key mới: thêm vào **cả 2 ARB** + `fvm flutter pub run intl_utils:generate`. Chi tiết đầy đủ: skill `flutter-internationalization`.

## Assets — flutter_gen

Asset khai trong `pubspec.yaml` → `flutter.assets`; `flutter_gen_runner` generate `lib/src/gen/assets.gen.dart` (class `AppAsset`) + `fonts.gen.dart` (class `FontFamily`).

```dart
AppAsset.icons.icCaretDown.svg(colorFilter: ...);
AppAsset.images.bgLogin.provider();
```

Thêm asset mới: (1) drop file vào `assets/icons/` hoặc `assets/images/`, (2) `fvm flutter pub run build_runner build --delete-conflicting-outputs`, (3) reference qua `AppAsset.<group>.<name>` — KHÔNG raw path string. Font family dùng constant `FontFamily.inter` (theme hiện dùng font Inter), không hardcode string `'Inter'`.

## Form Pattern

Convention đã xác nhận: **field-level `GlobalKey<FormFieldState>`**, một key riêng cho mỗi field cần validate — KHÔNG bọc `Form` widget + `GlobalKey<FormState>` chung, và KHÔNG dùng `TextEditingController` để đọc giá trị (đọc qua `.currentState?.value`, set qua `.currentState?.didChange(value)` nếu cần prefill). Tiền lệ thật: `SignInVm`/`SignInPage` (`lib/src/pages/auth_rider/sign_in/`).

```dart
class SignInVm extends BaseViewModel {
  final fieldPhone = GlobalKey<FormFieldState>();
  final fieldPassword = GlobalKey<FormFieldState>();

  bool isValidated = false;

  bool get _validatePhone => fieldPhone.currentState?.validate() ?? false;
  bool get _validatePassword => fieldPassword.currentState?.validate() ?? false;

  void onChangeValidate([String? value]) {
    isValidated = _validatePhone && _validatePassword;
    notifyListeners();
  }

  void onSignInTap() {
    if (!isValidated || isSigningIn) return;
    // ... submit, đọc giá trị qua fieldPhone.currentState?.value / fieldPassword.currentState?.value
  }
}
```

```dart
AppPhoneField(
  keyField: provider.fieldPhone,
  validator: Validator.phone.call,
  onChanged: provider.onChangeValidate,
),
AppPasswordField(
  keyField: provider.fieldPassword,
  validator: Validator.password.call,
  onChanged: provider.onChangeValidate,
),
```

Quy tắc:

- Key khai trong VM (field final `GlobalKey<FormFieldState>`), một key / một field — sống cùng vòng đời VM, không tái tạo mỗi lần rebuild Page.
- Wiring qua prop `keyField` sẵn có trên `AppTextField`/`AppPhoneField`/`AppPasswordField` (`lib/src/components/input/`) — không tự thêm `Key` khác, không bọc `Form`.
- **Không dùng `TextEditingController` song song với `GlobalKey<FormFieldState>`** — 2 nguồn giá trị trùng lặp, dễ lệch nhau. Đọc giá trị hiện tại qua `.currentState?.value`; nếu component yêu cầu `controller` bắt buộc (như `AppPhoneField` trước đây), đổi param đó thành optional thay vì tạo controller thừa chỉ để thoả mãn API — tiền lệ: `AppPhoneField.controller` đã đổi từ `required` sang optional cho đúng pattern này.
- `isValidated` (bool trong VM) + `onChangeValidate([String? value])` wired vào `onChanged` của từng field — recompute mỗi lần field đổi giá trị, dùng để enable/disable nút submit (`onPressed: provider.isValidated ? provider.onSubmitTap : null`). Không tự chế cờ `canSubmit` dựa trên `controller.text` — đã lệch pattern.
- Validate trước submit: guard đơn giản `if (!isValidated || isLoadingFlag) return;` trong hàm submit — không re-validate lại từng field riêng lẻ trong đó (đã được `isValidated` cover qua `onChangeValidate`).
- `Validator.<name>` (`lib/src/utils/validator.dart`, `MultiValidator`) truyền thẳng vào `validator:` của field — không viết validate logic tay trong VM.

Khi implement thật, kiểm tra lại input component sẵn có dưới `lib/src/components/input/` trước — đừng tự tạo field widget mới nếu đã có component tương đương.

## Theme — reference

`context.appColors` (extension `SchemeExtension` trong `lib/src/resources/app_color_scheme.dart`, đọc `Theme.of(this).extension<AppColorScheme>()`) và `context.appStyle` (extension `StyleExtension` trong `lib/src/resources/app_style_scheme.dart`). Cả 2 `ThemeExtension` được register trong `AppTheme.lightTheme` / `AppTheme.darkTheme` (`lib/src/theme/app_theme.dart`); dark theme re-color style sang `AppColor.white`. Đổi theme/locale runtime không cần context: `AppProvider.setTheme(AppTheme.darkTheme)` / `AppProvider.setLocale('en')` (`lib/src/utils/app_provider.dart`, tự persist qua `SharedPrefs`).

Full depth của hệ màu/typography (token nào dùng khi nào, static `AppColor`/`AppStyle` vs scheme): skill `flutter-ui-style-guide` — không lặp lại ở đây.

## Snack-bar & Feedback từ VM

`MixinBasePage` wires tự động — gọi method trên VM, không đụng `ScaffoldMessenger`:

```dart
showInfo('...');  showSuccess('...');  showWarning('...');
showError('...');                 // generic error
showErrorConnection();            // tự phân biệt no-internet vs process-failed
```

## Null Safety (global rule)

**KHÔNG BAO GIỜ dùng `!`** ở widget, VM, service. Dùng `?.` / `??`:

```dart
// BAD
user.profile!.fullName!;
(accessToken!).isNotEmpty;

// GOOD
user.profile?.fullName ?? '';
(accessToken?.isNotEmpty ?? false)
```

Ngoại lệ duy nhất: file do generator sinh ra (`app_router.gr.dart`, `l10n.dart`/`intl/*`, `assets.gen.dart`/`fonts.gen.dart`) — không hand-edit các file này nên rule không áp dụng ở đó.

## Cái cớ thường gặp

| Cái cớ | Phản bác |
|---|---|
| "VM one-off không cần extend BaseViewModel" | Base cho `prefs`, `appRouter`, `showError` consistent → features consistent |
| "Tôi chỉ dùng `!` một lần" | "Một lần" thành hàng chục. Null-safe là quy tắc, không phải suggestion |
| "Combine nhiều loading flag thành `isLoading`" | UI shows wrong state cho wrong operation. Per-op flags only — `isLoading` trong `BaseViewModel` là nội bộ cho dialog overlay, không phải cờ chung |
| "Tôi dùng `Navigator.push()` cho nhanh" | `context.router`/`appRouter` là canonical; ngoại lệ raw `Navigator` chỉ có 1 chỗ (dismiss `AppLoading` dialog) |
| "`if (AppConfig.shared.isRider)` trong widget cho tiện" | Rẽ nhánh app CHỈ ở `setUpInjector`. Widget/VM không biết mình chạy app nào |
| "register router ngay trong Page" | Router chọn theo `isRider` → phải qua locator |
| "Tôi dùng raw `Dio` ở feature mới" | `ApiClient` đã config interceptor + logger. Dùng nó |
| "Viết `status` là `String` cho nhanh" | API thay đổi → enum `fromString` giúp refactor an toàn (xem `TripStatus`) |
| "Subscribe EventBus xong không cần cancel, VM này chỉ tạo 1 lần" | `MainRiderVm` hiện đang mắc lỗi này thật — đừng lặp lại, luôn lưu `StreamSubscription<T>?` + cancel trong `dispose()` |

## Cờ đỏ

- VM không extend `BaseViewModel`
- Page là `StatefulWidget` (state phải ở VM)
- Page thiếu `@RoutePage()`
- `Navigator.of(context).pop()`/`push()` cho navigation thật (ngoài chỗ dismiss `AppLoading` dialog đã sanctioned trong `base_page.dart`)
- Shared `isLoading` cho nhiều operations
- `x!.y` ở widget / VM / service (ngoài file generated)
- `Dio` instantiation ngoài `ApiClient`
- Model field non-nullable, hoặc `as String` thay vì `as String?`
- Hardcoded hex `Color(0xFF...)` trong widget (dùng `AppColor.*` / `context.appColors`)
- Service singleton không register trong `setUpInjector()`
- `if (isRider ...)` / `if (AppConfig.shared.isRider ...)` ngoài `setUpInjector`
- Import `app_router.gr.dart` trực tiếp từ page/VM
- Edit `app_router.dart` / thêm page mà không chạy `build_runner`
- Route riêng của Rider khai vào `AppRouterUser` (hoặc ngược lại)
- Subscribe EventBus không lưu `StreamSubscription` + không cancel trong `dispose()`
- Thêm model mới vào `lib/src/models/delete_late/` (đây là thư mục chờ xoá, không phải nơi đặt model mới)
- Form validate qua `Form` widget + `GlobalKey<FormState>` chung (đúng pattern là field-level `GlobalKey<FormFieldState>`, xem § Form Pattern)
- `TextEditingController` dùng song song với `GlobalKey<FormFieldState>` trên cùng field (2 nguồn giá trị trùng lặp — đọc qua `.currentState?.value`)

## Kiểm chứng

- [ ] Mọi VM extend `BaseViewModel`, override `onInit()`
- [ ] Mỗi async op có own `isLoading<Op>` flag riêng, không tái dùng field `isLoading` của `BaseViewModel`
- [ ] Page là `StatelessWidget with MixinBasePage<T>` có `@RoutePage()`
- [ ] `create()` trả fresh VM; `initialise()` override (để `{}` nếu không cần)
- [ ] Navigation dùng `context.router.*` / `appRouter.*`, không raw `Navigator` (trừ dismiss `AppLoading`)
- [ ] Data qua `api.dio.*` rồi tự map sang model — không đụng `Dio` trực tiếp
- [ ] Route khai đúng router (`AppRouter` cho Rider / `AppRouterUser` cho Driver), regen sau khi sửa
- [ ] Model fields nullable, `fromJson`/`toJson` symmetric, enum discriminator có `fromString()`
- [ ] Assets qua `AppAsset.<group>.<name>`
- [ ] i18n qua `S.current.*`, key sync cả 2 ARB (`fr` + `en`)
- [ ] Singleton mới register trong `setUpInjector()`; đổi init flow sync cả `main_rider_dev.dart` + `main_driver_dev.dart`
- [ ] KHÔNG `!` operator ở widget / VM / service
- [ ] EventBus subscription field là `StreamSubscription<T>?` (KHÔNG `late final`), cancel qua `?.cancel()` trong `dispose()`
- [ ] `fvm flutter analyze` exit 0
