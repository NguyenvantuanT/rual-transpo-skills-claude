---
name: flutter-internationalization
description: i18n bộ base Flutter qua flutter_intl (intl_utils) — ARB nhiều locale, S.current, placeholder/plural ICU, label enum theo locale, header language. Dùng khi thêm/sửa user-visible string, ARB, hoặc logic locale.
---

# Flutter Internationalization

Danh sách locale + `main_locale` là fact của dự án → `pubspec.yaml` (`flutter_intl:`) và `ls <arb_dir>`. Không có `l10n.yaml`; không dùng `flutter gen-l10n`.

## Workflow

1. Tìm key có sẵn trước (`grep -i "<từ khoá>" lib/src/l10n/intl_*.arb`) — trùng nghĩa thì dùng lại.
2. Thêm key vào **mọi** `intl_<locale>.arb` — `check.sh` (rule `arb_sync`) báo locale nào thiếu. Interpolation qua placeholder ICU, không nối chuỗi `'$var'`:
   ```json
   "homeGreeting": "Bonjour, {name}",
   "@homeGreeting": { "placeholders": { "name": { "type": "String" } } }
   ```
3. `fvm flutter pub run intl_utils:generate` (hook Stop nhắc nếu quên). Generated được track trong git → commit cùng.
4. Dùng `S.current.<key>` — cả trong widget lẫn VM (VM không có `BuildContext`). `S.current` non-nullable, không `?.`.

## Rule

- Không hardcode user-visible text (label, hint, title, message, error) trong widget/VM — `check.sh` bắt `Text('...')`, các chỗ khác (`hintText:`, `label:`, `showError('...')`) tự kiểm.
- Key camelCase, prefix theo feature (`homeGreetingMorning`, `orderDetailsArrivingAt`, `messageErrorLostConnect`).
- Plural: cú pháp ICU `{count, plural, =0{...} =1{...} other{...}}` trong mọi ARB — không tự chế.
- Enum cần label → extension cạnh enum, widget chỉ gọi `status.label()`:
  ```dart
  extension OrderStatusLabel on OrderStatus {
    String label() => switch (this) {
          OrderStatus.pending => S.current.orderStatusPending,
          OrderStatus.delayed => S.current.orderStatusDelayed,
          OrderStatus.onTime => S.current.orderStatusOnTime,
        };
  }
  ```
- Locale runtime: `AppProvider.setLocale(code)` (persist qua `prefs.locale`); `ApiInterceptor` tự gửi header `language`. Đổi locale logic mà thấy `AppConstants.defaultLang` lệch `main_locale` → ghi `docs/tech-debt-tracker.md`, không tự chọn bên đúng.
