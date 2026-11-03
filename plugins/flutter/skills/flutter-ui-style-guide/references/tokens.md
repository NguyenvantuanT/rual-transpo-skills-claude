# Màu, typography, kiểu số

## Theming & Colors

Design tokens ở `lib/src/resources/`:

- **`app_color.dart`** — `class AppColor` với **static const** `Color`. Base theo thang Material 3 (`white`, `black`, `primary`/`onPrimary`/`primaryContainer`/`onPrimaryContainer`, `secondary...`, `tertiary...`, `error...`, `background`, `surface`, `surfaceVariant`, `outline`, `outlineVariant`, `shadow`, `scrim`, đầy đủ biến thể `...Dark` cho dark theme, `surfaceContainer*`, `inverseSurface`...), cộng thêm khu **CUSTOM COLORS — brand tokens của dự án** ở cuối file (ví dụ từ dự án mẫu): `textPrimary`, `textSecondary`, `color818183`, `successGreen` (xanh "On time", khác `tertiary`), `surfaceTintBrand` (nền card highlight, vd "Frequently travelled"), `cardBorder`, `mutedDisabledText`, `pendingOrange` (card "PENDING" ở màn queue on-demand), `delayedRed`, `shadowSoft`, và nhóm màu thẻ thanh toán (`visaBrand`, `visaCardOverlay`, `priceFooterBackground`) dùng ở màn order-details. Đọc hết file trước khi thêm token mới — rất nhiều màu semantic đã có sẵn.
- **`app_color_scheme.dart`** — `class AppColorScheme extends ThemeExtension<AppColorScheme>`: bộ token semantic + numbered scale — `primaryText`, `secondaryText`, `background`, `onPrimary`, `coolgray10/20/30/40/60/80/100`, `primary10/20/40/60/80/100`, `secondary10/20/40/50/60/80/100`, `success`, `info`, `warning`, `error`, `shadow`, `divider`, `disabled`, `border`. Register trong `lib/src/theme/app_theme.dart` (map từ `AppColor.*`), đọc qua **`context.appColors`** (`extension SchemeExtension on BuildContext`, ở cuối `app_color_scheme.dart`) — **không phải `context.appColor` số ít**, nhớ số nhiều.

Quy tắc:

- **KHÔNG BAO GIỜ `Color(0xFF...)` literal trong widget files.** Tất cả màu qua `AppColor.*`.
- Nếu màu chưa có, **thêm vào `AppColor` trước**, đặt tên mô tả ý nghĩa theo tiền lệ mới nhất trong file (`successGreen`, `pendingOrange`, `delayedRed`...) hoặc theo hex value cho màu trung tính (`color818183`) — ưu tiên semantic name khi màu gắn với ý nghĩa nghiệp vụ cụ thể (trạng thái nghiệp vụ, tiền, cảnh báo).
- **Mặc định dùng static token `AppColor.*` trong feature/page widgets** (pattern của bộ base — ví dụ: `AddressTimeline`, `OrderInfoItem`, `TextConnectByArrow`, `MapPreviewCard`... đều import `app_color.dart` trực tiếp). Chỉ dùng `context.appColors` khi widget thật sự cần đổi màu theo theme (dự án chưa bật dark mode ở page layer thì `context.appColors` gần như chỉ xuất hiện trong theme setup).
- **KHÔNG `isDark ? ... : ...` ternary trong widget** — khi thực sự cần theme-aware, dùng `AppColorScheme`, không tự rẽ nhánh.

## Typography

- **`app_style.dart`** — `class AppStyle` với static const `TextStyle` `display36Bold/Regular` xuống tới `display10Bold/Regular`, cộng thêm size nhỏ dùng cho label/caption: `display8Regular`, `display7Regular`, `display5Regular`, `display4Regular` (không có bản Bold cho các size này). Mỗi style mặc định `color: AppColor.black`, `fontWeight` w500 (Bold) / w400 (Regular) — override màu qua `.copyWith(color: ...)`.
- **`app_style_scheme.dart`** — `class AppStyleScheme extends ThemeExtension<AppStyleScheme>`: `display36Bold/Regular` xuống `display10Bold/Regular` (13 size × Bold/Regular, không có size 8/7/5/4 ở tầng này) + field `name: AppThemeMode`. `enum AppThemeMode { light, dark, kimia }` — `kimia` **có khai báo nhưng chưa dùng ở đâu** (chỉ `light`/`dark` được set trong `app_theme.dart`), giữ nguyên không xoá. Đọc qua **`context.appStyle`** (`extension StyleExtension on BuildContext`), cũng expose `context.isLight` / `context.isDark` / `context.isKimia` (boolean, so theo `appStyle.name`).
- **Font**: `FontFamily.inter` (`lib/src/gen/fonts.gen.dart`, generated bởi `flutter_gen`, hiện chỉ khai báo đúng 1 family) — set ở `fontFamily: FontFamily.inter` trong `ThemeData` (`app_theme.dart`). Đây là family DUY NHẤT có trong generated file; nếu cần thêm font, thêm asset + khai báo trong `pubspec.yaml` rồi regen (`fvm dart run build_runner build`), không tự viết string family khác tay.

**Static `AppStyle.*` vs ThemeExtension `context.appStyle`** — trong bộ base, hai tầng tồn tại song song:

- **Feature/page widget** (trong `lib/src/pages/`) dùng thẳng `AppStyle.displayXxBold.copyWith(color: AppColor.textPrimary)` — tiền lệ: `TextConnectByArrow`, `OrderInfoItem`, `SuggestedOrdersSection`, `QueueActiveUpcomingItems`.
- **Shared component ở `lib/src/components/`** cần dùng lại ở nhiều feature/khả năng theme-aware dùng `context.appStyle.displayXxRegular.copyWith(...)` — tiền lệ: `AppTextField`, `AppMonoButton`, `AppSnackBar`.

Quy tắc thực dụng: viết feature UI mới → dùng `AppStyle.*` (nhất quán với phần lớn code hiện có); viết/sửa **shared component dùng ở nhiều feature** → ưu tiên `context.appStyle` giống các component kể trên. Cả hai đều đúng convention, không tự chế thang size mới ngoài 2 file trên.

## Numeric Parameter Types

Luôn dùng **đúng numeric type** khớp bản chất của value:

- Whole numbers (count, index, `maxLines`, flex factor) → `int` / `int?`
- Fractional / pixel measurements (width, height, radius, padding, font size, opacity) → `double` / `double?`

Ví dụ thật trong `AppSnackBar` (`lib/src/components/snack_bar/app_snack_bar.dart`): `final int maxLines` (mặc định `3`, một con số đếm dòng) đi cạnh `EdgeInsetsGeometry messagePadding` toàn `double` (`EdgeInsets.only(top: 16.0, ...)`) — không lẫn lộn hai loại.

```dart
// BAD
final int radius;             // radius là measurement → double
final double maxLines;        // maxLines là count → int
SizedBox(width: 8)            // thiếu .0 trên pixel measurement
maxLines: 4.0                 // .0 trên int parameter

// GOOD
final double? radius;
final int? maxLines;
SizedBox(width: 8.0)
maxLines: 4
```

