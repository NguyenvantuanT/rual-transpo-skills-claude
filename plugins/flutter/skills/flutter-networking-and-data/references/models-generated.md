# Model kiểu `generated` (json_serializable)

Áp dụng khi `.claude/harness.env` có `HARNESS_MODEL_STYLE=generated`. Phỏng theo `flutter-data-model` của BOW Skills (MIT) — xem `THIRD_PARTY_NOTICES.md`.

Nguyên tắc: **có generator thì generate** — `fromMap` viết tay lệch payload sẽ crash lúc runtime, không lộ ra ở analyze.

Cần trong `pubspec.yaml`: `json_annotation` (dependencies), `json_serializable` + `build_runner` (dev_dependencies). Thiếu → hỏi user trước khi thêm.

## Shape chuẩn

```dart
import 'package:json_annotation/json_annotation.dart';

part 'order_model.g.dart';

@JsonSerializable(includeIfNull: false, explicitToJson: true)
class OrderModel {
  @JsonKey(name: 'id') String? id;
  @JsonKey(name: 'status') OrderStatus? status;
  @JsonKey(name: 'created_at', fromJson: JsonConverters.fromJsonDate, toJson: JsonConverters.toJsonDate)
  DateTime? createdAt;
  @JsonKey(name: 'merchant') MerchantModel? merchant;
  @JsonKey(name: 'items') List<OrderItemModel>? items;

  @JsonKey(includeFromJson: false, includeToJson: false)
  bool isSelected = false;

  OrderModel();

  factory OrderModel.fromJson(Map<String, dynamic> json) => _$OrderModelFromJson(json);
  Map<String, dynamic> toJson() => _$OrderModelToJson(this);
}
```

1. `part '<tên file>.g.dart';`
2. `@JsonSerializable(includeIfNull: false, explicitToJson: true)` — `explicitToJson` để nested gọi `toJson()`.
3. `@JsonKey(name: '<key server>')` trên **mọi** field — đổi tên field Dart không làm vỡ payload.
4. Enum là kiểu enum, không `String`.
5. Field chỉ dùng cho UI / tính toán → `@JsonKey(includeFromJson: false, includeToJson: false)`.
6. `fromJson` / `toJson` chỉ delegate sang `_$…` — không có thân viết tay (`check.sh` rule `model_handwritten`).

## Converter dùng chung

Ngày, số, màu, duration… parse qua **1 class converter dùng chung** của dự án (grep `fromJsonDate` trong `lib/src/utils/`), gắn qua `@JsonKey(fromJson:, toJson:)`. Không `DateTime.parse` / `int.tryParse` inline trong model. Thiếu converter → thêm vào class dùng chung, không viết riêng trong model.

## Enum

```dart
enum OrderStatus {
  @JsonValue('pending') pending,
  @JsonValue('paid') paid,
  @JsonValue('cancelled') cancelled,
}
```

Không `switch` trên string để parse — generator lo việc map. Label hiển thị vẫn qua extension `S.current` cạnh enum (`flutter-internationalization`).

## Regenerate

Sau khi thêm/sửa model, field, converter, enum:

```bash
fvm flutter pub run build_runner build --delete-conflicting-outputs
```

- Commit `.g.dart` cùng model; mỗi model có `.g.dart` tương ứng.
- Không sửa tay `.g.dart` (hook `pre_edit` chặn).
- Model `.dart` mới hơn `.g.dart` → hook Stop báo chưa regen.

## Cờ đỏ

- `factory X.fromJson` / `fromMap` có thân viết tay → chuyển sang `@JsonSerializable`.
- Model không có `.g.dart` tương ứng.
- `DateTime.parse` / `int.tryParse` / switch string trong model.
- `map['key']` trong VM/widget → thiếu field trong model, thêm field.
- Model viết tay cũ chạm tới khi làm task → chuyển sang dạng generated (hoặc ghi `docs/tech-debt-tracker.md` nếu ngoài phạm vi).
