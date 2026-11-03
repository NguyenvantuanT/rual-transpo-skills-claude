# Model rules, enum discriminator, pagination

## Dart Model Rules

Mọi model (request body, response, entity domain) theo đúng pattern null-safe
này (tiền lệ: `lib/src/models/app_user_model.dart`):

- Tất cả field nullable, **không `final`**, **không `required`**: `String? id;`.
- Constructor no-arg, **không `const`**: `MyModel();` — để field có thể gán lại
  qua cascade.
- `fromJson` là `factory`, dùng cascade `..` để gán field lên instance vừa tạo.
- `toJson()` trả `Map<String, dynamic>` literal.
- Hand-written hoàn toàn — **KHÔNG** `freezed`, **KHÔNG** `json_serializable`
  (có trong `dev_dependencies` nhưng không dùng cho model nào trong repo — đừng
  đề xuất thêm nó vào model mới).

Ví dụ minh hoạ (viết mới, sạch — không lặp lại bug thật bên dưới):

```dart
class OrderModel {
  String? id;
  String? originName;
  String? destinationName;
  DateTime? departureTime;

  OrderModel();

  factory OrderModel.fromJson(Map<String, dynamic> json) {
    return OrderModel()
      ..id = json['id']
      ..originName = json['originName']
      ..destinationName = json['destinationName']
      ..departureTime = json['departureTime'] != null
          ? DateTime.tryParse(json['departureTime'])
          : null;
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'originName': originName,
    'destinationName': destinationName,
    'departureTime': departureTime?.toIso8601String(),
  };
}
```

### Enum discriminator + `fromString()`

Field API kiểu string cố định (type/status/kind/role) luôn là enum riêng ở
`lib/src/models/enums/`, với `static fromString()` bằng switch expression, và
extension label cạnh nó nếu cần hiển thị UI. Tiền lệ thật —
`lib/src/models/enums/order_status.dart`:

```dart
enum OrderStatus {
  onTime,
  pending,
  delayed;

  static OrderStatus fromString(String? value) => switch (value?.toLowerCase()) {
        'pending' => pending,
        'delayed' => delayed,
        _ => onTime,
      };
}

extension OrderStatusLabel on OrderStatus {
  String label({String detail = ''}) => switch (this) {
        OrderStatus.pending => S.current.homeOrderStatusPending,
        OrderStatus.delayed => S.current.homeOrderStatusDelayed(detail),
        OrderStatus.onTime => S.current.homeOrderStatusOnTime(detail),
      };
}
```

Trong `fromJson`, parse thẳng qua enum — không giữ field kiểu `String?` thô:

```dart
status: OrderStatus.fromString(json['status'] as String?),
```

## Pagination / load-more — chưa có convention, đề xuất khi cần

Bộ base chưa chốt convention load-more/pull-to-refresh. Trước khi review hoặc
viết mới, `grep -r loadMore lib/src/pages` — nếu dự án đã có tiền lệ, theo đúng
tiền lệ đó; nếu chưa, đừng khẳng định "đây là cách repo đã làm".

Khi dự án chưa có tiền lệ và bạn implement 1 list fetch remote có phân trang, đề xuất
tối thiểu (điều chỉnh theo nhu cầu thật của trang đó, không phải luật cứng):

- VM giữ `page`, `pageSize`, `hasMore`, và **loading flag riêng** cho initial
  load vs. load-more (không dùng chung 1 `isLoading` cho hai thao tác khác UX).
- Service method nhận `page`/`limit` qua `queryParameters`, VM tự cộng dồn
  `items = [...items, ...next]` khi load more, reset về `page = 1` khi filter
  đổi hoặc pull-to-refresh.
- Dùng `ListView.separated` (không `ListView.builder`) cho phần list đã có data,
  loading indicator là `AppCircularProgress` (không `CircularProgressIndicator`
  mặc định).

