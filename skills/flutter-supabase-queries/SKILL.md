---
name: flutter-supabase-queries
description: Data layer Supabase cho bộ base Flutter — query class theo domain đăng ký qua locator, select cột tường minh + range, model typed vào/ra, RPC cho thao tác nguyên tử, optimistic update có revert, realtime stream. Dùng khi thêm query/RPC/realtime hoặc nối VM với dữ liệu Supabase.
---

# Flutter + Supabase — query layer

Chỉ áp dụng cho dự án có backend Supabase (`supabase_flutter` trong `pubspec.yaml`; `CLAUDE.md` ghi Backend). Model theo `HARNESS_MODEL_STYLE` của dự án — xem `flutter-networking-and-data`. Thay đổi SQL/policy/edge function → skill `supabase-security-review`.

Phỏng theo `flutter-supabase` của BOW Skills (MIT) — xem `THIRD_PARTY_NOTICES.md`.

## Chỗ đặt code

- Query class theo domain ở `lib/src/services/remote/<domain>_queries.dart`, nhận `SupabaseClient` qua constructor, đăng ký trong `setUpInjector()`, VM đọc qua field (không `locator<T>()` trong VM).
- **VM gọi query; widget/page/component không bao giờ gọi `Supabase.instance` / `.from(...)`** — `check.sh` rule `supa_in_ui`.
- Query nhận và trả **model typed**, không `Map<String, dynamic>`; VM/widget không index `row['key']`.

```dart
class OrderQueries {
  OrderQueries(this._db);
  final SupabaseClient _db;

  Future<List<OrderModel>> listForCustomer(String customerId, {int from = 0, int to = 19}) async {
    final rows = await _db
        .from('orders')
        .select('id, status, total, created_at, merchant:merchants(id, name)')
        .eq('customer_id', customerId)
        .order('created_at', ascending: false)
        .range(from, to);
    return rows.map(OrderModel.fromJson).toList();
  }
}
```

## Đọc

- Select **cột tường minh**, không `'*'`; quan hệ lồng qua `alias:table(cols)` để model parse được.
- Đọc danh sách **luôn có `.range(from, to)`** — không đọc cả bảng.
- 1 dòng: `.maybeSingle()` (có thể không có) hoặc `.single()` (bắt buộc có) — chọn có chủ đích.

## Ghi

- `insert` / `update` / `upsert` + `.select(...)` → map thẳng về model.
- Thao tác nhiều bước / cần nguyên tử → **RPC** (`_db.rpc('claim_order', params: {...})`), không chuỗi nhiều request từ client.
- Không tin giá trị tiền / giảm giá / role do client gửi — ép ở server (RLS, `CHECK`, RPC).

## Lỗi

Mọi lời gọi từ VM bọc lỗi: dùng helper guard của `BaseViewModel` nếu dự án có (grep `base_vm.dart`), không thì `try/catch` → `showError(...)` + `changeState(ChangeState.serverError)` khi load trang thất bại.

```dart
Future<void> load() async {
  changeState(ChangeState.loading);
  try {
    orders = await orderQueries.listForCustomer(customerId);
    changeState(ChangeState.page);
  } catch (e) {
    changeState(ChangeState.serverError);
  }
  notifyListeners();
}
```

## Optimistic update

Snapshot → cập nhật UI ngay → gọi server → lỗi thì trả lại snapshot:

```dart
Future<void> cancel(OrderModel order) async {
  final snapshot = orders;
  orders = orders.where((o) => o.id != order.id).toList();
  notifyListeners();
  try {
    await orderQueries.cancel(order.id);
  } catch (e) {
    orders = snapshot;
    notifyListeners();
    showError(S.current.messageErrorProcessFailed);
  }
}
```

## Realtime (chỉ khi cần)

Query expose `Stream<List<XxxModel>>`; VM lưu `StreamSubscription<…>?` và `?.cancel()` trong `dispose()`. Không mở channel trong widget.

## Cờ đỏ ngoài `check.sh`

- `.select('*')` hoặc đọc list không `.range(...)`
- Query trả `Map` / `List<dynamic>` thay vì model
- Mutation đổi UI nhưng không revert được khi lỗi
- Ghi tiền / role từ client mà không có ràng buộc server-side
