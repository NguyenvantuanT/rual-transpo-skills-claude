# Cross-VM communication — EventBus

## Cross-VM Communication — EventBus

Khi VM A cần báo cho VM B (khác page, khác route) — vd customer bấm "Use voucher" ở `HomeQueuedVm` → `MainCustomerVm` (VM cha, giữ trạng thái đơn hàng active) cần cập nhật theo. Dùng **EventBus** (`package:event_bus`). Instance **không tập trung ở 1 file `event_bus.dart` chung** — nó khai ngay cạnh VM sở hữu domain đó:

```dart
// lib/src/pages/main_customer/main_customer_vm.dart
EventBus activeOrderEventBus = EventBus();

class MainCustomerVm extends BaseViewModel {
  ActiveOrderStatus? status;

  @override
  void onInit() {
    status = activeOrderServices.status;
    notifyListeners();
    activeOrderEventBus.on<ActiveOrderStatus>().listen((event) {
      status = event;
      notifyListeners();
    });
  }
}
```

**Publisher** — các VM con dưới `main_customer/home/` (`HomeQueuedVm`, `HomeActiveVm`, `HomeMissedVm`, `QueueActiveVm`, `VoucherConfirmedVm`) fire lên cùng item này mỗi khi order status đổi:

```dart
void onTapUseVoucher() {
  activeOrderServices.setActiveOrderStatus(ActiveOrderStatus.voucherActive);
  activeOrderEventBus.fire(ActiveOrderStatus.voucherActive);
}
```

### Quy tắc

- **1 EventBus cho 1 domain** — không share 1 item cho nhiều event type khác nhau.
- **Type parameter rõ ràng** — `on<ActiveOrderStatus>()`, không `on<dynamic>()`.
- **`fire()` non-blocking**, không chờ result. Không dùng cho critical path.
- **KHÔNG dùng EventBus thay cho `prefs` / VM state**: state persist → `prefs`; local state 1 page → VM field; cross-page ephemeral notification → EventBus.
- Item khai **cạnh VM sở hữu domain** (không phải ở file trung tâm) là pattern của bộ base. Khi số lượng item tăng lên, cân nhắc gom vào 1 file `lib/src/utils/event_bus.dart` để dễ tra cứu — nhưng đây là **đề xuất cải tiến**, chưa phải convention đã áp dụng.

### Cờ đỏ hay gặp — subscribe không cancel

Ví dụ trên subscribe `.listen(...)` nhưng **không lưu `StreamSubscription` và không override `dispose()` để cancel** — leak, không phải pattern mẫu để copy. Khi viết subscriber:

- **Lưu subscription vào field `StreamSubscription<T>?` (nullable), KHÔNG `late final`** — `onInit()` chạy qua `addPostFrameCallback` (deferred). Nếu page bị pop/dispose trước khi frame đầu tiên chạy xong, `dispose()` gọi `.cancel()` trên field `late final` chưa được gán → `LateInitializationError`.
- **Cancel trong `dispose()`** bằng `?.cancel()`:

```dart
class MainCustomerVm extends BaseViewModel {
  StreamSubscription<ActiveOrderStatus>? _statusSub;

  @override
  void onInit() {
    _statusSub = activeOrderEventBus.on<ActiveOrderStatus>().listen((event) {
      status = event;
      notifyListeners();
    });
  }

  @override
  void dispose() {
    _statusSub?.cancel();
    super.dispose();
  }
}
```

### Khi nào KHÔNG dùng

- VM trong cùng widget tree — truyền callback qua constructor hoặc `context.read<VM>()`.
- Persist state — `prefs`.

