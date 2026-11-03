# SharedPrefs + EasyDebounce

## Local Storage — SharedPrefs

`lib/src/services/local/share_prefs.dart`. Một class, **hai cơ chế lưu trữ khác
nhau** cho hai nhóm dữ liệu:

| Dữ liệu | Cơ chế | Field |
|---|---|---|
| `accessToken` (`String?`) | `FlutterSecureStorage` | `_accessToken` |
| `appUser` (`AppUserModel?`) | `FlutterSecureStorage`, JSON qua `jsonEncode(user.toJson())` | `_appUser` |
| `theme` (`ThemeMode`) | `SharedPreferences` thường | key `theme` |
| `locale` (`String?`) | `SharedPreferences` thường | key `locale` |

`initialise()` (phải `await` 1 lần trong mỗi `main_*.dart`, ngay sau
`setUpInjector(...)`) làm thêm 1 việc: **migrate 1 lần** `accessToken`/`appUser`
cũ nếu chúng còn nằm ở `SharedPreferences` (kiểm tra `containsKey`, đọc giá trị,
ghi sang secure storage, rồi `remove` key cũ) — dữ liệu mới từ đây về sau chỉ còn
nằm ở secure storage. `theme`/`locale` không có bước migrate vì chúng vốn đã ở
`SharedPreferences` và ở lại đó.

```dart
bool get isLogin => _accessToken?.isNotEmpty ?? false;

void removeSession() {
  accessToken = null; // setter tự xóa key khỏi secure storage khi gán null
  appUser = null;
}
```

Quy tắc: VM không tự đọc `FlutterSecureStorage`/`SharedPreferences` trực tiếp —
luôn qua `prefs` (field inherited từ `BaseViewModel`, đã `locator<SharedPrefs>()`).

## Debounce — EasyDebounce (tag-based)

Repo dùng `lib/src/components/easy_debounce.dart` — **static, theo tag**, không
phải một class instantiate riêng cho từng VM:

```dart
class EasyDebounce {
  static void debounce(String tag, Duration duration, EasyDebounceCallback onExecute);
  static void fire(String tag);
  static void cancel(String tag);
  static void cancelAll();
  static int count();
}
```

Ví dụ trong bộ base (`lib/src/components/input/app_text_field.dart`) —
debounce forward `onChanged` ở tầng widget dùng chung:

```dart
void _onChanged(String value) {
  EasyDebounce.debounce(
    'onChanged',
    const Duration(milliseconds: 20),
    () => widget.onChanged?.call(value),
  );
}

@override
void dispose() {
  EasyDebounce.cancel('onChanged');
  super.dispose();
}
```

Khi debounce một search/filter gọi API, đặt logic ở **VM**, chọn tag riêng cho
mỗi thao tác (tránh 2 debounce khác nhau vô tình dùng chung tag rồi cancel lẫn
nhau), và nhớ `EasyDebounce.cancel(tag)` trong `dispose()` của VM:

```dart
void onSearchChanged(String query) {
  _query = query;
  EasyDebounce.debounce('searchOrders', const Duration(milliseconds: 500), () {
    fetchOrders();
  });
}

@override
void dispose() {
  EasyDebounce.cancel('searchOrders');
  super.dispose();
}
```

