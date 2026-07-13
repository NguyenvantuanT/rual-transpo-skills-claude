---
name: flutter-ui-style-guide
description: |
  Convention UI cho Rual Transpo Rider Mobile — hai tầng token (static AppColor/AppStyle + ThemeExtension AppColorScheme/AppStyleScheme qua context.appColors/context.appStyle), AppCircularProgress, AppBounceButton, AppMonoButton, kiểu số nghiêm ngặt, ListView.separated, domain components cho trip/bus/stop, Google Maps preview card, form field validation qua GlobalKey<FormFieldState> + Validator.
  Sử dụng khi: viết hoặc review bất kỳ widget, page, hoặc shared component nào trong app rider (trips, bus, stop, vé, fare), hoặc bất kỳ form/field nào cần validate (auth, sign up, input tự do).
---

# Flutter UI Style Guide — Rual Transpo Rider Mobile

## Tổng quan

Convention cho widget layer:

- **Colors**: `AppColor.<name>` (static const) — không bao giờ hex literal trong widget files. Theme-aware (khi thật sự cần) qua `context.appColors` (`AppColorScheme`).
- **Typography**: `AppStyle.<name>` (static const `TextStyle`) là lựa chọn mặc định trong feature widget; `context.appStyle` (`AppStyleScheme`) dùng trong shared component layer cần theme-aware.
- **Numeric types**: `int` cho whole numbers, `double` cho measurements. Không trộn.
- **Lists**: chỉ `ListView.separated`. Spacing explicit qua `separatorBuilder`.
- **Shared components hơn inline subtrees**: mọi reusable section là `StatelessWidget` class riêng.
- **Không logic trong widget callbacks**: VM owns behavior; widgets chỉ call back.
- **Trước khi tạo widget mới**: check `lib/src/components/` — app này là domain vận tải hành khách (trip/bus/stop/ticket/fare), nhiều mảnh UI (timeline điểm đón/trả, badge trạng thái chuyến) đã có sẵn.
- **Form field nào có validate/submit-gating**: LUÔN dùng `GlobalKey<FormFieldState>` per field + `Validator.*` (`lib/src/utils/validator.dart`) — không tự check `.text.isNotEmpty` tay. Chi tiết ở § Form Fields & Validation.

## Khi nào sử dụng

- Viết widget, page, hoặc shared component
- Review UI code cho style compliance
- Thêm color, button, text field, list, hoặc domain UI component mới (trip card, bus status, stop timeline...)

## Theming & Colors

Design tokens ở `lib/src/resources/`:

- **`app_color.dart`** — `class AppColor` với **static const** `Color`. Base theo thang Material 3 (`white`, `black`, `primary`/`onPrimary`/`primaryContainer`/`onPrimaryContainer`, `secondary...`, `tertiary...`, `error...`, `background`, `surface`, `surfaceVariant`, `outline`, `outlineVariant`, `shadow`, `scrim`, đầy đủ biến thể `...Dark` cho dark theme, `surfaceContainer*`, `inverseSurface`...), cộng thêm **CUSTOM COLORS — Rual Transpo brand tokens** ở cuối file: `textPrimary`, `textSecondary`, `color818183`, `successGreen` (xanh "On time", khác `tertiary`), `surfaceTintBrand` (nền card highlight, vd "Frequently travelled"), `cardBorder`, `mutedDisabledText`, `pendingOrange` (card "PENDING" ở màn queue on-demand), `delayedRed`, `shadowSoft`, và nhóm màu thẻ thanh toán (`visaBrand`, `visaCardOverlay`, `fareFooterBackground`) dùng ở màn trip-details. Đọc hết file trước khi thêm token mới — rất nhiều màu semantic đã có sẵn.
- **`app_color_scheme.dart`** — `class AppColorScheme extends ThemeExtension<AppColorScheme>`: bộ token semantic + numbered scale — `primaryText`, `secondaryText`, `background`, `onPrimary`, `coolgray10/20/30/40/60/80/100`, `primary10/20/40/60/80/100`, `secondary10/20/40/50/60/80/100`, `success`, `info`, `warning`, `error`, `shadow`, `divider`, `disabled`, `border`. Register trong `lib/src/theme/app_theme.dart` (map từ `AppColor.*`), đọc qua **`context.appColors`** (`extension SchemeExtension on BuildContext`, ở cuối `app_color_scheme.dart`) — **không phải `context.appColor` số ít**, nhớ số nhiều.

Quy tắc:

- **KHÔNG BAO GIỜ `Color(0xFF...)` literal trong widget files.** Tất cả màu qua `AppColor.*`.
- Nếu màu chưa có, **thêm vào `AppColor` trước**, đặt tên mô tả ý nghĩa theo tiền lệ mới nhất trong file (`successGreen`, `pendingOrange`, `delayedRed`...) hoặc theo hex value cho màu trung tính (`color818183`) — ưu tiên semantic name khi màu gắn với ý nghĩa nghiệp vụ cụ thể (trạng thái chuyến, tiền, cảnh báo).
- **Mặc định dùng static token `AppColor.*` trong feature/page widgets** (đây là pattern thực tế đang dùng ở toàn bộ `lib/src/pages/` — `AddressTimeline`, `TripInfoItem`, `TextConnectByArrow`, `MapPreviewCard`... đều import `app_color.dart` trực tiếp). Chỉ dùng `context.appColors` khi widget thật sự cần đổi màu theo theme (hiện tại app chưa bật dark mode ở page layer, nên `context.appColors` gần như không xuất hiện ngoài internal của theme setup).
- **KHÔNG `isDark ? ... : ...` ternary trong widget** — khi thực sự cần theme-aware, dùng `AppColorScheme`, không tự rẽ nhánh.

## Typography

- **`app_style.dart`** — `class AppStyle` với static const `TextStyle` `display36Bold/Regular` xuống tới `display10Bold/Regular`, cộng thêm size nhỏ dùng cho label/caption: `display8Regular`, `display7Regular`, `display5Regular`, `display4Regular` (không có bản Bold cho các size này). Mỗi style mặc định `color: AppColor.black`, `fontWeight` w500 (Bold) / w400 (Regular) — override màu qua `.copyWith(color: ...)`.
- **`app_style_scheme.dart`** — `class AppStyleScheme extends ThemeExtension<AppStyleScheme>`: `display36Bold/Regular` xuống `display10Bold/Regular` (13 size × Bold/Regular, không có size 8/7/5/4 ở tầng này) + field `name: AppThemeMode`. `enum AppThemeMode { light, dark, kimia }` — `kimia` **có khai báo nhưng chưa dùng ở đâu** (chỉ `light`/`dark` được set trong `app_theme.dart`), giữ nguyên không xoá. Đọc qua **`context.appStyle`** (`extension StyleExtension on BuildContext`), cũng expose `context.isLight` / `context.isDark` / `context.isKimia` (boolean, so theo `appStyle.name`).
- **Font**: `FontFamily.inter` (`lib/src/gen/fonts.gen.dart`, generated bởi `flutter_gen`, hiện chỉ khai báo đúng 1 family) — set ở `fontFamily: FontFamily.inter` trong `ThemeData` (`app_theme.dart`). Đây là family DUY NHẤT có trong generated file; nếu cần thêm font, thêm asset + khai báo trong `pubspec.yaml` rồi regen (`fvm dart run build_runner build`), không tự viết string family khác tay.

**Static `AppStyle.*` vs ThemeExtension `context.appStyle`** — thực tế trong repo, hai tầng đang tồn tại song song:

- **Feature/page widget** (trong `lib/src/pages/`) dùng thẳng `AppStyle.displayXxBold.copyWith(color: AppColor.textPrimary)` — tiền lệ: `TextConnectByArrow`, `TripInfoItem`, `SuggestedTripsSection`, `QueueActiveUpcomingBuses`.
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

## Loading Indicator

**`AppCircularProgress`** (`lib/src/components/loading/app_circular_progress.dart`) — **luôn** dùng thay cho `CircularProgressIndicator` bare. Wrap `LoadingAnimationWidget.discreteCircle` (package `loading_animation_widget`), tự derive `secondRingColor`/`thirdRingColor` bằng alpha falloff (0.5, 0.25) từ 1 tham số `color` duy nhất (mặc định `AppColor.black`), `size` mặc định `24.0`:

```dart
const AppCircularProgress({
  super.key,
  this.color,          // mặc định AppColor.black nếu null
  this.size = 24.0,
  this.alignment = Alignment.center,
});
```

Dùng cho: inline spinner trong section (`SuggestedTripsSection` khi `isLoading`), thay thế content của button khi `isLoading` (`AppMonoButton`, `AppCircleButton` đều dùng `Visibility(replacement: AppCircularProgress(...))`). Truyền `color:` khớp `fontColor`/`iconColor` của button cha để spinner không lệch tone.

**Full-screen loading overlay**: ngoài inline spinner ở trên, repo còn có `AppLoading` (`lib/src/components/loading/app_loading.dart`, static `AppLoading.show(context)`) — cơ chế overlay toàn màn dùng `showDialog` nội bộ, wired sẵn trong `MixinBasePage` (`lib/src/base/base_page.dart`, gọi qua `showLoading()`/`hideLoading()` của `BaseViewModel`). Đây là chỗ dùng `showDialog` DUY NHẤT còn lại trong repo — không có `dialog/`/`modal/` component subdirectory chung nào khác ở `lib/src/components/`, nên không tự tạo generic dialog/modal system mới nếu chỉ cần loading overlay. Chi tiết cách gọi từ VM/page → `flutter-mvvm-provider-architecture/SKILL.md`, không lặp lại ở đây.

## Tap / Click Wrapper

**Mọi widget cần xử lý tap để trigger action** (list item, icon nhỏ, chip, custom card, marker preview...) — bọc bằng **`AppBounceButton`** (`lib/src/components/button/app_bounce_button.dart`), hiệu ứng scale + tilt khi nhấn (`scale`/`scaleFactor` mặc định `true`/`0.95`, `tilt`/`tiltAngle` mặc định `true`/`pi/10`). **KHÔNG BAO GIỜ** raw `GestureDetector` / `InkWell` / `InkResponse` cho tap action.

```dart
AppBounceButton(
  onTap: onTap,
  child: MapPreviewCardContent(...),
)
```

Params khác sẵn có khi cần: `onTapUp`, `onSecondaryTapUp`, `onLongPress` (nhận `TapDownDetails`), `duration`/`tapDelay`/`longPressDuration` (đã có default hợp lý — không override trừ khi có lý do UX rõ), `behavior` (mặc định `HitTestBehavior.deferToChild`), `filterQuality`, `cursor`.

- `AppMonoButton` / `AppCircleButton` (§ Buttons) vẫn là lựa chọn riêng cho nút text/label hoặc icon-button chuẩn. `AppBounceButton` dùng cho tap target không phải nút chuẩn (chip, card, marker, list row...).
- **Ngoại lệ duy nhất**: `GestureDetector` bắt tap-outside-để-unfocus keyboard ở page/dialog level — không phải "click functionality" trigger action.

## Buttons

- **`AppMonoButton`** (`lib/src/components/button/app_mono_button.dart`) — nút pill filled/gradient chuẩn của app. 3 constructor: mặc định (`AppMonoButton(...)`, padding rộng `horizontal: 50.0, vertical: 10.0`, bo góc `99.0` — pill), **`.small`** (padding hẹp, bo góc `10.0`, có `border` + `boxShadow` mặc định), **`.smallOutline`** (giống `.small` nhưng nền `AppColor.surfaceTintBrand`, chữ `AppColor.primary`). Params chính: `text` / `child` (custom content), `colors` (`List<Color>` cho `LinearGradient`, mặc định `[AppColor.primary, AppColor.primary]`), `padding`, `fontColor`, `borderRadius`, `isLoading` (dùng `Visibility`/`replacement` swap sang `AppCircularProgress`), `boxShadow`, `border`, `icon`/`trailingIcon` (`SvgGenImage?` từ `flutter_gen`) + `iconColor`/`iconSize`/`iconTextGap`, `onPressed`. Khi `onPressed == null`, gradient tự hạ `alpha: 0.2` để thể hiện trạng thái disabled — không cần tự vẽ opacity riêng.
- Text style bên trong dùng `style ?? context.appStyle.display14Regular.copyWith(color: ...)` — tiền lệ chuẩn cho "kết hợp ThemeExtension style với override màu một lần":

```dart
Text(
  text ?? '',
  style: style ?? context.appStyle.display14Regular.copyWith(
    color: onPressed == null ? AppColor.white : fontColor,
  ),
)
```

- **`AppCircleButton`** (`lib/src/components/button/app_circle_button.dart`) — nút icon tròn/vuông-bo-góc (constructor mặc định = tròn qua `BoxShape.circle`; `.radius` = bo góc `16.0` qua `borderRadius`), nền trắng mặc định, border `AppColor.cardBorder` dày `1.5`, hỗ trợ `isLoading` (swap sang `AppCircularProgress`). Dùng cho nút hành động icon-only (locate-me, back, stop-dot trên timeline...).
- **KHÔNG BAO GIỜ raw `ElevatedButton` / `TextButton` / `OutlinedButton`** trong feature UI files.
- **KHÔNG pass hardcoded `height`** trên `AppMonoButton`/`AppCircleButton` — `padding`/`size` nội bộ tự control kích thước.

## Component Variants (Named Constructors)

Khi shared component cần biến thể visual/hành vi, thêm **named constructor** — không duplicate class, không boolean flag. Hai tiền lệ thật trong repo:

```dart
// AppMonoButton — 3 constructor
AppMonoButton({ /* filled pill, defaults */ });
AppMonoButton.small({ /* compact + border */ });
AppMonoButton.smallOutline({ /* compact, outline style */ });

// AppSnackBar — 4 constructor theo mức độ nghiêm trọng
AppSnackBar.info({ required message, ... });
AppSnackBar.warning({ required message, ... });
AppSnackBar.success({ required message, ... });
AppSnackBar.error({ required message, ... });
```

Call sites explicit: `AppMonoButton.smallOutline(text: ...)`, `AppSnackBar.error(message: ...)`. Không bao giờ `variant: 'error'` hay `isOutline: true`.

## Lists

**LUÔN dùng `ListView.separated`** — không bao giờ `ListView.builder`. Đã xác nhận: không có `ListView.builder` nào trong `lib/src/pages/`; mọi list đều `ListView.separated`, kể cả list ngang.

Vertical, có empty/loading branch riêng (tiền lệ `SuggestedTripsSection`, `lib/src/pages/main_rider/home/widgets/suggested_trips_section.dart`) — dùng `shrinkWrap: true` + `NeverScrollableScrollPhysics()` khi list nằm lồng trong `Column`/`ScrollView` cha (không phải màn hình full-list riêng):

```dart
if (isLoading)
  const Padding(
    padding: EdgeInsets.symmetric(vertical: 32.0),
    child: Center(child: AppCircularProgress(size: 28.0)),
  )
else
  ListView.separated(
    physics: const NeverScrollableScrollPhysics(),
    shrinkWrap: true,
    padding: EdgeInsets.zero,
    itemCount: trips?.length ?? 0,
    separatorBuilder: (_, _) => const SizedBox(height: 12.0),
    itemBuilder: (_, index) => SuggestedTripRow(trip: trips?[index], onTap: onTapTrip),
  )
```

Với màn hình **fetch remote data + phân trang thật sự** (list riêng, cuộn toàn màn), áp dụng pattern 3-method + 2-flag (`_fetchItems`/`loadMore`/`_resetAndFetch`, `isLoadingFoo` + `isLoadingMore`) mô tả ở `CLAUDE.md` §8 và chi tiết ở `flutter-networking-and-data` — nhánh loaded LUÔN `physics: const AlwaysScrollableScrollPhysics()` để pull-to-refresh không bị im lặng khi content ngắn hơn 1 màn hình.

### Horizontal scroll (bus/trip status card)

Tiền lệ: `QueueActiveUpcomingBuses` (`lib/src/pages/main_rider/home/pages/queue_active/widgets/queue_active_upcoming_buses.dart`) — label tiêu đề nằm ngoài trong `Padding` riêng, còn `ListView` ngang full-width với padding đặt ngay trong tham số `padding` của chính nó (không bọc `Padding` tổng bao ngoài `ListView`, tránh thu hẹp viewport):

```dart
SizedBox(
  height: 70.0,
  child: ListView.separated(
    scrollDirection: Axis.horizontal,
    padding: const EdgeInsets.symmetric(horizontal: 16.0),
    itemCount: buses.length,
    separatorBuilder: (_, _) => const SizedBox(width: 10.0),
    itemBuilder: (_, index) => QueueActiveBusStatusCard(
      time: buses[index].time,
      status: buses[index].status,
    ),
  ),
)
```

## Domain Components — check trước khi tạo mới

App này là transportation/rider app (trips, bus, stop, ticket, fare) — trước khi build widget timeline/route/trip mới, check các component đã có ở `lib/src/components/`:

- **`address_timeline.dart`** (`AddressTimeline`) — cặp input điểm đón/điểm đến nối bằng đường kẻ đứt (`CustomPainter`) + `AppCircleButton` locate.
- **`route_indicator.dart`** (`RouteIndicator`) — dải icon-line-icon ngang thể hiện route (điểm đầu — line — card giữa — line — điểm cuối). **Lưu ý**: file này hiện dùng `Color` param trực tiếp (không qua `AppColor`) và `TextStyle` hardcode trong `_CenterCard`/`_Dot` — không phải tiền lệ để copy nguyên; nếu sửa/mở rộng widget này, chuyển các literal đó sang `AppColor.*`/`AppStyle.*` cho đúng convention hiện hành thay vì nhân bản cách cũ.
- **`text_connect_by_arrow.dart`** (`TextConnectByArrow`) — 2 label nối bằng icon mũi tên (`AppAsset.icons.homeArrowRight`), dùng cho origin → destination text ngắn.
- **`trip_info_item.dart`** (`TripInfoItem`) — 1 dòng trong timeline chuyến đi (tên stop, subtitle route/"On time", badge giờ đến, `AppCircleButton` stop-dot).
- **`chip/status_chip.dart`**, **`circle/app_circle_check.dart`** — chip trạng thái, check icon tròn dùng lại cho selection state.

## Google Maps Preview Cards

Xem chi tiết đầy đủ (API key wiring, gesture-disabling khi preview mode, tap-through) ở `CLAUDE.md` § Google Maps preview cards — mục đó chính xác, không lặp lại ở đây. Tóm tắt cho tầng UI: card preview map (tiền lệ `lib/src/pages/main_rider/home/widgets/map_preview_card.dart`, `MapPreviewCard`) bọc `AppGoogleMap` (`lib/src/components/map/app_google_map.dart`) bên trong `AppBounceButton` để cả card bấm được (tap-through), marker vẽ qua `SvgMarker.fromAsset` (`lib/src/utils/svg_marker.dart`) — render SVG asset ra `BitmapDescriptor` PNG có halo, cache theo `assetPath|size|haloColor|haloMultiplier` để tránh re-encode mỗi build:

```dart
final descriptor = await SvgMarker.fromAsset(
  assetPath: 'assets/icons/...',
  size: 36.0,
  haloColor: AppColor.primary.withValues(alpha: 0.15),
);
```

## Search & Debounce

Utility debounce thật sự có sẵn trong repo là **`EasyDebounce`** (`lib/src/components/easy_debounce.dart`) — API tag-based:

```dart
EasyDebounce.debounce(
  'search-trips',           // tag — dùng 1 tag riêng mỗi field search để không đụng debounce khác
  const Duration(milliseconds: 400),
  () => viewModel.search(query),
);
```

Gọi trong VM (method `onSearchChanged`), **không** trong widget `onChanged` trực tiếp — widget chỉ forward text lên VM. `EasyDebounce.cancel(tag)` trong `dispose()` của VM nếu cần huỷ debounce đang chờ.

## Form Fields & Validation

**Mọi field cần validate/gate nút submit dùng `GlobalKey<FormFieldState>` per field — không check `.text.isNotEmpty` tay.** Tiền lệ thật: `sign_in_vm.dart`/`sign_in_page.dart` và `sign_up_vm.dart`/`sign_up_form.dart` (`lib/src/pages/auth_rider/`).

Component nhập liệu (`lib/src/components/input/`: `AppTextField`, `AppPhoneField`, `AppPasswordField`) đều có sẵn 2 param cho việc này — không cần sửa component khi áp dụng pattern:

- `Key? keyField` — forward thẳng vào `key:` của `TextFormField` bên trong. Gán bằng đúng `GlobalKey<FormFieldState>` sở hữu bởi VM.
- `ValueChanged<String>? onChanged` — gọi khi text đổi (qua debounce 20ms nội bộ của `AppTextField`).

Pattern trong VM (không phải trong widget) — bắt buộc kèm `_touchedFields` (xem lý do ngay dưới, đừng bỏ qua phần này khi copy pattern):

```dart
final fieldEmail = GlobalKey<FormFieldState>();
final fieldPassword = GlobalKey<FormFieldState>();

final _touchedFields = <GlobalKey<FormFieldState>>{};

bool _isFieldValid(GlobalKey<FormFieldState> field) {
  if (!_touchedFields.contains(field)) return false;
  return field.currentState?.validate() ?? false;
}

bool canSubmit = false; // hoặc isValidated — field mutable, KHÔNG phải getter derive từ controller

void onFieldChanged(GlobalKey<FormFieldState> field, [String? value]) {
  _touchedFields.add(field);
  canSubmit = _isFieldValid(fieldEmail) && _isFieldValid(fieldPassword);
  notifyListeners();
}
```

Wire **cùng một** `onFieldChanged` làm `onChanged` cho MỌI field liên quan (không viết callback riêng từng field) — vì `.validate()` re-run validator mỗi lần gọi, dùng chung 1 callback nghĩa là sửa field A cũng re-check field B (quan trọng cho cặp password/confirm-password: sửa password sẽ tự re-validate confirm-password theo, bắt mismatch sống ngay khi gõ). Mỗi field truyền **đúng key của chính nó** vào callback dùng chung:

```dart
AppTextField(keyField: fieldEmail, onChanged: (v) => onFieldChanged(fieldEmail, v), validator: Validator.email.call),
AppPasswordField(keyField: fieldPassword, onChanged: (v) => onFieldChanged(fieldPassword, v), validator: Validator.password.call),
```

**Vì sao cần `_touchedFields`:** `FormFieldState.validate()` luôn hiển thị lỗi UI ngay khi gọi, bất kể `autovalidateMode` (mode đó chỉ gate auto-trigger nội bộ của Flutter, không gate lời gọi `.validate()` thủ công). Nếu gọi `.validate()` trên MỌI field mỗi lần `onFieldChanged` chạy (không check touched trước), gõ vào field A sẽ ép field B (chưa đụng tới) hiện lỗi "required" ngay lập tức — bug thật đã gặp ở `sign_up_vm.dart`/`sign_in_vm.dart`. Field chưa nằm trong `_touchedFields` phải coi là invalid (giữ `canSubmit`/`isValidated` = false) nhưng KHÔNG được gọi `.validate()` trên nó — tránh vừa đúng logic vừa không hiện lỗi sớm.

- **KHÔNG cần `TextEditingController` riêng** chỉ để đọc giá trị field — `fieldX.currentState?.value` đọc được giá trị hiện tại qua chính `GlobalKey`, kể cả cho validator cross-field (vd `Validator.confirmPassword(value, fieldPassword.currentState?.value ?? '')`). Chỉ thêm `TextEditingController` khi thật sự cần set giá trị lập trình được từ bên ngoài field (prefill, clear nút bấm...) — không thêm mặc định "cho chắc".
- **Validator** — dùng `Validator.*` (`lib/src/utils/validator.dart`, compose từ `MultiValidator`/`RequiredValidator`/`EmailValidator`/`MinLengthValidator`/`MatchValidator` ở `form_field_validator_app.dart`). Check các entry có sẵn (`notEmpty`, `email`, `phone`, `password`, `confirmPassword`, `newPassword`) trước khi viết validator mới; error text luôn qua `S.current.messageErrorXxx` (thêm cả 2 ARB nếu cần key mới — xem `flutter-internationalization`).
- Field không cần `Validator` (không gate submit) thì không cần `GlobalKey<FormFieldState>` — chỉ áp dụng pattern này cho field thực sự ảnh hưởng `canSubmit`/`isValidated`.
- `AppMonoButton.onPressed` đọc trực tiếp `provider.canSubmit ? provider.onSubmitTap : null` (reactive qua `ChangeNotifier`) — không tự tính lại điều kiện ở widget layer.

## File & Class Organization

- **Một class trên một file** — mỗi Dart file chứa chính xác một public class (ngoại lệ nhỏ: `app_bounce_button.dart` có thêm 2 helper class RenderObject nội bộ cho cùng cơ chế đo size, không phải pattern để nhân rộng).
- **Enums trong file riêng** — `lib/src/models/enums/` (tiền lệ thật: `trip_status.dart`, `trip_stop_timeline_icon_kind.dart`, `payment_method_kind.dart`, `ticket_origin.dart`, `upcoming_bus_status.dart`...). Convention hiện tại trong các enum này là **computed getter qua `switch` expression** (icon/màu theo từng case), ví dụ thật từ `TripStopTimelineIconKind`:

```dart
enum TripStopTimelineIconKind {
  start, go, end;

  SvgGenImage get icon => switch (this) {
    start => AppAsset.icons.homeLocateCurrent,
    go => AppAsset.icons.homeLocateCurrent,
    end => AppAsset.icons.homeLocationPinDestination,
  };

  Color get backgroundColor => switch (this) {
    start => AppColor.primary,
    go => AppColor.surfaceTintBrand,
    end => AppColor.white,
  };
}
```

  Khi enum là discriminator field parse từ API (response chuyến/vé), thêm `fromString()` cùng pattern `switch` với `_` wildcard default, đặt cạnh các computed getter trong cùng file enum.
- **Mọi reusable UI section là `StatelessWidget` class riêng**. Không build complex subtrees inline trong `build()`.
- **Constructor parameters nullable theo mặc định** — `this.param` không `required`, type `T?`. Chỉ mark `required` khi widget không render nổi nếu thiếu (tiền lệ: `TripInfoItem({required this.trip, required this.isLast})` — cả 2 đều bắt buộc để layout đúng).
- Feature widgets ở `widgets/` dưới feature folder (`lib/src/pages/main_rider/home/widgets/`, `.../pages/<feature>/widgets/`). Cross-feature widgets ở `lib/src/components/`.
- **Không comments trong widget code.** Names phải tự giải thích.
- **Naming mô tả widget LÀ GÌ** (`QueueActiveBusStatusCard`, `TripInfoItem`), không phải hoạt động thế nào.

## Null Safety Rule

**KHÔNG `!` operator** ở widget/VM/service code — dùng `?.` / `??`. Áp dụng cho code bạn viết mới; một số animation-math nội bộ có sẵn trong `AppBounceButton` (tính `_lastTapLocation!`/`_lastTapTime!` cho tilt effect) predate rule này — không lấy làm tiền lệ để thêm `!` ở chỗ khác, và không cần refactor lại trừ khi đang sửa trực tiếp file đó.

## Cờ đỏ

- `Color(0xFF...)` literal ở bất kỳ đâu trong `lib/src/pages/` hoặc `lib/src/components/`
- `TextStyle(...)` tự khai từ đầu thay vì `AppStyle.*`/`context.appStyle` — kể cả khi chỉ cần override 1-2 field (dùng `.copyWith(...)` trên token gần nhất thay vì viết `TextStyle` mới)
- Màu mới xuất hiện trong widget mà không được thêm vào `AppColor` trước (đặt trong khu vực `CUSTOM COLORS`, kèm doc-comment ngắn giải thích use-case)
- `context.appColor` (số ít) — API thật là `context.appColors` (số nhiều)
- `ListView.builder` không có lý do explicit
- List cuộn ngang bị bọc `Padding`/`Column` tổng bên ngoài `ListView` thay vì đặt padding vào tham số `padding` của chính `ListView`
- `int` literal ở chỗ `double` expected (thiếu `.0`) hoặc ngược lại
- Hai public class trong cùng Dart file (ngoại trừ helper RenderObject nội bộ như `WidgetSizeWrapper`/`WidgetSizeRenderObject` trong `app_bounce_button.dart`)
- Widget build complex subtrees inline
- Logic (`Clipboard`, `ScaffoldMessenger`, `Navigator`) trong widget callback
- Raw `ElevatedButton`/`TextButton`/`OutlinedButton` thay vì `AppMonoButton`/`AppCircleButton`
- Raw `GestureDetector`/`InkWell`/`InkResponse` cho tap action thay vì `AppBounceButton` (trừ tap-outside-unfocus keyboard)
- Hardcoded `height:` trên `AppMonoButton`/`AppCircleButton`
- `CircularProgressIndicator` bare thay vì `AppCircularProgress`
- Debounce tự viết `Timer` tay trong widget/VM thay vì `EasyDebounce`
- `isDark ?` ternary trong widget thay vì `AppColorScheme`
- Constructor param `required` dù có default hợp lý rõ ràng
- `canSubmit`/`isValidated` derive từ `.text.isNotEmpty` thay vì `GlobalKey<FormFieldState>` + `.validate()`
- Field có validate nhưng thiếu `keyField`, hoặc mỗi field tự viết `onChanged` riêng thay vì dùng chung 1 `onFieldChanged`
- `onFieldChanged` gọi `.validate()` trên field mà không check `_touchedFields` trước — gây hiện lỗi UI sớm trên field user chưa động tới
- Thêm `TextEditingController` chỉ để đọc giá trị field khi `fieldX.currentState?.value` đã đủ

## Kiểm chứng

- [ ] Không `Color(0xFF...)` literals trong widget files; tất cả qua `AppColor.*` hoặc `context.appColors`
- [ ] Text style qua `AppStyle.*` (feature widget) hoặc `context.appStyle` (shared component) — không thang size tự chế
- [ ] Không `ListView.builder`; scrollable lists dùng `ListView.separated`; list ngang không bị outer padding thu hẹp viewport
- [ ] Numeric types khớp value nature (`int` counts, `double` measurements)
- [ ] Một public class / file; enums trong `lib/src/models/enums/`
- [ ] Reusable sections extracted thành `StatelessWidget` riêng; đã check `lib/src/components/` trước khi tạo mới
- [ ] Widget callbacks không chứa logic — delegate cho VM
- [ ] Buttons chỉ `AppMonoButton`/`AppCircleButton` (+ named-constructor variants), không raw Material button
- [ ] Tap action qua `AppBounceButton`, không raw `GestureDetector`/`InkWell`/`InkResponse` (trừ tap-outside-unfocus keyboard)
- [ ] Loading spinner qua `AppCircularProgress`, không `CircularProgressIndicator` bare
- [ ] Search debounce qua `EasyDebounce` trong VM, không trong widget
- [ ] Không `!` operator ở code mới viết
- [ ] Field có gate submit dùng `GlobalKey<FormFieldState>` + `Validator.*`, không phải `.text.isNotEmpty`
- [ ] `onFieldChanged` check `_touchedFields` trước khi `.validate()` — field chưa touched không tự hiện lỗi
- [ ] `fvm flutter analyze` exit 0
