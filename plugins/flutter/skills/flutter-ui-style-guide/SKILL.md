---
name: flutter-ui-style-guide
description: Convention UI bộ base Flutter — AppColor/AppStyle + ThemeExtension (context.appColors/appStyle), AppMonoButton, AppBounceButton, AppCircularProgress, ListView.separated, named-constructor variants, form validation GlobalKey<FormFieldState> + Validator. Dùng khi viết/sửa/review widget, page UI, component, form.
---

# Flutter UI Style Guide

Đọc file này trước; mở `references/` khi cần chi tiết hoặc API đầy đủ của component. Domain component có sẵn của dự án → `CLAUDE.md` / `ARCHITECTURE.md`; luôn check `lib/src/components/` trước khi tạo widget mới.

## Rule máy đã ép (`check.sh`) — chỉ cần nhớ thay thế

| Đừng | Dùng |
|---|---|
| `Color(0x…)` | `AppColor.<token>` (thiếu → thêm token vào `app_color.dart` trước, đặt tên theo nghĩa) |
| `ElevatedButton` / `TextButton` / `OutlinedButton` | `AppMonoButton` / `.small` / `.smallOutline`, icon-only: `AppCircleButton` |
| `GestureDetector` / `InkWell` cho action | `AppBounceButton(onTap:, child:)` (ngoại lệ: tap-outside unfocus keyboard) |
| `CircularProgressIndicator` | `AppCircularProgress(size:, color:)` |
| `ListView.builder` | `ListView.separated` + `separatorBuilder` |
| `Text('literal')` | `S.current.<key>` |

## Rule máy không bắt được — tự giữ

- **Typography**: feature widget dùng `AppStyle.displayXxBold/Regular.copyWith(...)`; shared component cần theme-aware dùng `context.appStyle.*`. Không tự khai `TextStyle(...)` mới; không tự chế thang size. Font qua `FontFamily.*`.
- **Theme**: chỉ dùng `context.appColors` (số nhiều) khi thật sự cần theo theme; không `isDark ? … : …` trong widget.
- **Kiểu số**: `int` cho đếm/index/`maxLines`/flex; `double` cho kích thước/padding/radius (`8.0`, không `8`).
- **Variant** = named constructor (`AppSnackBar.error(...)`, `AppMonoButton.small(...)`), không cờ boolean / `variant: 'x'`.
- **Button**: không truyền `height` cứng cho `AppMonoButton`/`AppCircleButton`; trạng thái loading qua `isLoading`, disabled qua `onPressed: null`.
- **List**: lồng trong `Column`/scroll cha → `shrinkWrap: true` + `NeverScrollableScrollPhysics()`; list ngang đặt padding vào tham số `padding` của `ListView`, không bọc `Padding` ngoài; list remote full màn có pull-to-refresh → `AlwaysScrollableScrollPhysics()`.
- **Tách widget**: mỗi section tái sử dụng là 1 `StatelessWidget` riêng; 1 public class / file; feature widget ở `pages/<app>/<feature>/widgets/`, dùng chung ở `components/<feature>/`; file > 500 dòng bị `check.sh` chặn.
- **Constructor**: param nullable mặc định (`this.x`, kiểu `T?`); `required` chỉ khi không render nổi nếu thiếu.
- **Callback không chứa logic** (`Clipboard`, `Navigator`, snack-bar…) — widget gọi method VM.
- **Enum hiển thị**: file riêng ở `lib/src/models/enums/`, icon/màu qua getter `switch` expression ngay trong enum.
- **Search**: debounce trong VM (`EasyDebounce`), widget chỉ forward text — xem `flutter-networking-and-data`.

## Form có validate / gate nút submit

Mỗi field 1 `GlobalKey<FormFieldState>` khai trong VM, truyền qua `keyField:`; validator từ `Validator.*`. Mọi field dùng chung 1 `onFieldChanged(field, value)`; chỉ `.validate()` field đã nằm trong `_touchedFields` (nếu không, field chưa đụng tới sẽ hiện lỗi sớm). Đọc giá trị qua `fieldX.currentState?.value` — không thêm `TextEditingController` chỉ để đọc. Nút: `onPressed: provider.canSubmit ? provider.onSubmit : null`. Code mẫu đầy đủ → `references/forms.md`.

## references/ — mở khi cần

| File | Khi nào |
|---|---|
| `references/tokens.md` | Danh sách token `AppColor`/`AppColorScheme`, thang `AppStyle`/`AppStyleScheme`, ví dụ int vs double |
| `references/components.md` | API `AppCircularProgress`, `AppLoading` overlay, `AppBounceButton` (params), `AppMonoButton`/`AppCircleButton`, ví dụ named constructor |
| `references/lists.md` | Code mẫu list dọc có loading branch, list ngang |
| `references/forms.md` | Pattern form đầy đủ: `_touchedFields`, cross-field validator, `Validator.*` có sẵn |
