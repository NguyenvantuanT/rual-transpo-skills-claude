---
name: flutter-mvvm-provider-architecture
description: Kiến trúc bộ base Flutter MVVM + Provider — BaseViewModel, MixinBasePage, auto_route (AppRouterBase), get_it, EventBus, bootstrap main_*.dart. Dùng khi tạo/sửa feature, page, ViewModel, route, DI service, cross-VM event, hoặc review kiến trúc.
---

# Flutter MVVM + Provider

Đọc file này trước; mở `references/` khi cần chi tiết. Ví dụ chỉ minh hoạ shape — grep code thật trước khi dùng tên class. Fact dự án (1 app hay multi-app, service inherited thật) → `CLAUDE.md` + `lib/src/base/base_vm.dart`.

## Cấu trúc

```
lib/
├── app/          main_<app>_<env>.dart (entry, inline init) + app_config.dart (AppConfig.shared)
├── router/       app_router_base.dart + app_router.dart (@AutoRouterConfig) + .gr.dart (generated)
└── src/
    ├── base/       base_vm.dart (BaseViewModel, ChangeState) + base_page.dart (MixinBasePage)
    ├── pages/      <app>/<feature>/{<feature>_page.dart, <feature>_vm.dart, widgets/}
    ├── components/ widget dùng chung      services/ remote/ local/ …      models/ + enums/
    └── resources/ theme/ utils/(locator.dart) constants/ gen/ generated/ l10n/
```

Hướng import giữa layer được `check.sh` ép (`layer_*`).

## Rule

**ViewModel**
- `extends BaseViewModel`, override `onInit()` (chạy post-frame). Không ad-hoc `ChangeNotifier`.
- Dùng field inherited `api`, `prefs`, `appRouter` (+ service dự án thêm vào base) — không `locator<T>()` trong VM.
- Mỗi async op có cờ riêng `isLoading<Op>`; field `isLoading` của base chỉ phục vụ dialog `showLoading()/hideLoading()`.
- `notifyListeners()` sau mỗi lần đổi state. Feedback qua `showError/showSuccess/showInfo/showWarning/showErrorConnection()` — không đụng `ScaffoldMessenger`.
- Giữ `StreamSubscription`/controller → field nullable, cancel trong `dispose()`.

**Page**
- `@RoutePage()` + `StatelessWidget with MixinBasePage<FooVm>`; override `create()` (VM mới mỗi lần) + `initialise(context)` (để `{}` nếu không cần); UI bọc trong `builder(() => ...)`.
- Không `StatefulWidget` — state ở VM. Đổi màn hình trạng thái qua `changeState(ChangeState.<x>)`.

**Navigation**
- VM: `appRouter.push(FooRoute())` / `appRouter.maybePop()` / `appRouter.replaceAll([...])`. Widget: `context.router.*`.
- Không raw `Navigator` (ngoại lệ duy nhất: `base_page.dart` đóng dialog `AppLoading`).
- Import `app_router.dart`, không import `.gr.dart`. Sửa router / thêm `@RoutePage` → `fvm flutter pub run build_runner build --delete-conflicting-outputs`.
- Multi-app: route của app nào khai vào router của app đó; page riêng app nằm dưới `pages/<app>/`.

**DI & bootstrap**
- Singleton mới đăng ký trong `setUpInjector(...)` (`lib/src/utils/locator.dart`). Thêm field vào `BaseViewModel` chỉ khi nhiều feature dùng; service 1 feature → inject qua constructor VM.
- Multi-app: `setUpInjector` là nơi DUY NHẤT rẽ nhánh theo cờ app (`check.sh` rule `app_branch`).
- Đổi init flow / thêm field `AppConfig` → sửa MỌI `main_*.dart`.

**Cross-VM (EventBus)**
- Chỉ cho thông báo ephemeral giữa VM khác page. State lâu dài → `prefs`; state 1 page → field VM; cùng widget tree → callback / `context.read<VM>()`.
- 1 bus / 1 domain, khai cạnh VM sở hữu domain, `on<ConcreteType>()`. Subscription lưu vào `StreamSubscription<T>?` (không `late final` — `onInit` chạy deferred), `?.cancel()` trong `dispose()`.

**Liên quan**: form/validation → `flutter-ui-style-guide` (`references/forms.md`); Dio, model, SharedPrefs, debounce → `flutter-networking-and-data`; string → `flutter-internationalization`; asset qua `AppAsset.<group>.<name>`, font qua `FontFamily.*`.

## Cờ đỏ ngoài `check.sh` (máy không bắt được — tự kiểm)

- VM không extend `BaseViewModel`; Page thiếu `@RoutePage()` hoặc là `StatefulWidget`
- Dùng chung 1 cờ loading cho nhiều operation
- Service singleton không đăng ký trong `setUpInjector()`
- Subscribe EventBus không cancel
- Code mới đặt vào thư mục mà `docs/tech-debt-tracker.md` đánh dấu chờ xoá

## references/ — mở khi cần

| File | Khi nào |
|---|---|
| `references/state-and-page.md` | Chi tiết BaseViewModel (lifecycle, appear/disappear, helper), MixinBasePage (callback wiring, state machine), 2 cơ chế loading |
| `references/eventbus.md` | Ví dụ publisher/subscriber đầy đủ |
| `references/navigation-di-bootstrap.md` | Code mẫu router 1 app / multi-app, `setUpInjector`, thứ tự init trong `main_*.dart`, thêm field `AppConfig` |
