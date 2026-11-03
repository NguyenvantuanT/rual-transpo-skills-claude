# Loading, tap wrapper, buttons, variants

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

Dùng cho: inline spinner trong section (`SuggestedOrdersSection` khi `isLoading`), thay thế content của button khi `isLoading` (`AppMonoButton`, `AppCircleButton` đều dùng `Visibility(replacement: AppCircularProgress(...))`). Truyền `color:` khớp `fontColor`/`iconColor` của button cha để spinner không lệch tone.

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

