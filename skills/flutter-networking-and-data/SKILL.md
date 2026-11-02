---
name: flutter-networking-and-data
description: Data layer bộ base Flutter — REST qua Dio (ApiClient + ApiInterceptor), model hand-written all-nullable, enum discriminator fromString, SharedPrefs (secure storage token/user), EasyDebounce, pagination. Dùng khi thêm API call, service, model, đọc/ghi local storage, debounce search.
---

# Flutter Networking & Data

Đọc file này trước; mở `references/` khi cần code mẫu. Endpoint/service thật của dự án → grep `lib/src/services/`.

## REST

- Một `Dio` duy nhất trong `ApiClient` (`lib/src/services/remote/api_client.dart`), VM dùng `api.dio` (inherited). Không `Dio()` mới (`check.sh` rule `raw_dio`).
- **`dio.options.baseUrl` không được set** → tự nối `'${AppConstants.baseURL}<path>'`; `api.dio.get('/x')` suông sẽ thiếu host.
- Path endpoint là hằng trong `EndPoint` (`lib/src/services/remote/utils/end_point.dart`).
- Service domain mới: `abstract class FooService` + `FooServiceImpl(Dio, {baseUrl})`, đăng ký trong `setUpInjector()`, VM đọc qua field — không `locator<T>()` trong VM.
- `ApiInterceptor` tự gắn `Authorization: Bearer` (bỏ qua `/auth/refresh`) và header `language`, map lỗi (offline → message no-internet; body `code`/`message`). Không set token thủ công per-call.
- Lỗi: GET danh sách → `debugPrint`; POST/PUT/DELETE + auth → `showError(...)`.

## Model

```dart
class OrderModel {
  String? id;
  OrderStatus? status;
  DateTime? createdAt;

  OrderModel();

  factory OrderModel.fromJson(Map<String, dynamic> json) => OrderModel()
    ..id = json['id'] as String?
    ..status = OrderStatus.fromString(json['status'] as String?)
    ..createdAt = DateTime.tryParse(json['createdAt'] as String? ?? '');

  Map<String, dynamic> toJson() => {'id': id, 'status': status?.name, 'createdAt': createdAt?.toIso8601String()};
}
```

- Mọi field nullable, không `final`, không `required`; constructor no-arg không `const`; `fromJson` factory + cascade; cast `as T?` (không `as T`).
- Hand-written — không `freezed` / `json_serializable` dù có trong `dev_dependencies`.
- Field string cố định (type/status/kind/role) → enum ở `lib/src/models/enums/` có `static fromString()` (switch + `_` default); label hiển thị qua extension `S.current`-backed cạnh enum.
- Key JSON khớp đúng field — đọc lại từng dòng cascade (bug copy-paste `id = json['email']` đã từng gặp).

## Local storage

Chỉ qua `prefs` (`SharedPrefs`): `prefs.accessToken`, `prefs.appUser` (secure storage), `prefs.isLogin`, `prefs.removeSession()`, theme/locale (shared_preferences). VM không đụng `FlutterSecureStorage`/`SharedPreferences` trực tiếp.

## Debounce

`EasyDebounce.debounce('<tag-riêng>', Duration(milliseconds: 400), () => ...)` trong VM; `EasyDebounce.cancel('<tag>')` trong `dispose()`. Mỗi thao tác 1 tag riêng (dùng chung tag sẽ cancel lẫn nhau). Không tự viết `Timer`.

## Pagination

Chưa có convention chung — `grep -r loadMore lib/src/pages` trước: có tiền lệ thì theo; chưa có thì: `page`/`hasMore` + cờ riêng `isLoadingFirst` / `isLoadingMore`, reset `page = 1` khi đổi filter / refresh, nối `items = [...items, ...next]`. Ghi pattern mới vào `docs/` của dự án.

## references/ — mở khi cần

| File | Khi nào |
|---|---|
| `references/api-client.md` | Code `ApiClient` + ví dụ service abstract/impl đầy đủ + thứ tự xử lý lỗi trong `ApiInterceptor` |
| `references/storage-and-debounce.md` | Bảng cơ chế lưu từng loại dữ liệu, migration 1 lần trong `initialise()`, API `EasyDebounce` đầy đủ |
| `references/models.md` | Ví dụ model dài, enum + label extension, gợi ý pagination chi tiết |
