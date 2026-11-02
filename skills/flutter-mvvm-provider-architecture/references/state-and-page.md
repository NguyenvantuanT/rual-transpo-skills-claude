# BaseViewModel + MixinBasePage

## State — Provider + ChangeNotifier + BaseViewModel

`enum ChangeState { loading, blank, page, serverError, clone }` khai báo ngay trong `lib/src/base/base_vm.dart` (không tách file riêng). Mọi VM extend `BaseViewModel extends ChangeNotifier`. Base class cung cấp sẵn:

- **Inherited services** (field final, gán từ `locator<T>()` ngay khi construct): `api` (`ApiClient`), `prefs` (`SharedPrefs`), `appRouter` (`AppRouterBase`) + service dùng chung riêng của dự án (vd: `locationService`, `activeOrderServices`).
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

  bool isLoadingOrders = false;

  @override
  void onInit() {
    _appUser = prefs.appUser;
    notifyListeners();
  }

  Future<void> loadUpcomingOrders() async {
    isLoadingOrders = true;
    notifyListeners();
    try {
      final response = await api.dio.get('/orders/upcoming');
      // map response.data sang OrderOptionModel ở đây
    } catch (e) {
      showError(S.current.messageErrorProcessFailed);
    } finally {
      isLoadingOrders = false;
      notifyListeners();
    }
  }
}
```

Quy tắc:

- **VM phải extend `BaseViewModel`** và override `onInit()`. Đừng tạo ad-hoc `ChangeNotifier`.
- Mỗi async operation có **own named loading flag** (`isLoadingOrders`, `isLoadingSubmit`). Không share một `isLoading` chung (field `isLoading` có sẵn trong `BaseViewModel` là để phục vụ `showLoading()`/`hideLoading()` dialog-based, KHÔNG dùng nó làm cờ loading cho section UI — xem phần Page Pattern để hiểu rõ 2 pattern khác nhau này).
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
- `onLogOut` → gọi `prefs.removeSession()` rồi redirect về màn login (`context.router.pushAndPopUntil(...)`) — đọc `base_page.dart` thật để biết dự án đã wire redirect chưa.

State machine trong `Consumer<T>.builder`, switch theo `provider.state`:

| `ChangeState` | Render |
|---|---|
| `clone` | `Container(child: builder.call())` |
| `blank` | `const Scaffold()` |
| `loading` | `const AppLoading()` |
| `serverError` | `const ServerError()` |
| `page` | `builder.call()` |

`ServerError` (`lib/src/components/server_error.dart`) trong bộ base gốc chỉ là stub `Center(child: AppLoading())` — dự án tự thay bằng UI lỗi thật khi cần.

### Loading overlay: 2 pattern coi xét, không trộn lẫn

Repo hiện có **2 cơ chế loading khác nhau, cùng tồn tại**:

1. **Dialog-based overlay** — `showLoading()`/`hideLoading()` trên VM, wired qua `onShowLoading`/`onHideLoading` ở trên, dùng `AppLoading.show(context)` (`lib/src/components/loading/app_loading.dart`): `showDialog` non-dismissible (`barrierDismissible: false`, wrap `PopScope(canPop: false)`), hiện 1 vòng tròn trắng chứa `AppCircularProgress`.
2. **Inline per-operation flag** — `bool isLoadingFoo` trong VM, UI đọc flag để conditionally render `AppCircularProgress` tại chỗ (không phải dialog).

Rules:

- **`@RoutePage()` bắt buộc** cho mọi page reachable qua router.
- Pages là `StatelessWidget` — KHÔNG `StatefulWidget`. State thuộc về VM.
- `create()` trả VM mới mỗi lần. Không share VM cross-page.

