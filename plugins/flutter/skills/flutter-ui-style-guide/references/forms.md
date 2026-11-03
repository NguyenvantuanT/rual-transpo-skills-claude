# Form fields & validation

## Form Fields & Validation

**Mọi field cần validate/gate nút submit dùng `GlobalKey<FormFieldState>` per field — không check `.text.isNotEmpty` tay.** Tiền lệ thật: `sign_in_vm.dart`/`sign_in_page.dart` và `sign_up_vm.dart`/`sign_up_form.dart` (`lib/src/pages/auth_customer/`).

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

