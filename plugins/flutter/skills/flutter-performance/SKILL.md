---
name: flutter-performance
description: Tối ưu hiệu năng bộ base Flutter — đo bằng DevTools profile mode, thu hẹp rebuild của Provider/MixinBasePage (Selector, tách widget const), RepaintBoundary, list rẻ, build thuần, isolate cho việc nặng, jank raster. Dùng khi UI giật, rebuild quá nhiều, scroll lag, hoặc trước khi tối ưu.
---

# Flutter performance

Phỏng theo `flutter-performance-and-rebuild-optimization` của BOW Skills (MIT) — xem `THIRD_PARTY_NOTICES.md`. Ngân sách ~16 ms/frame (60 Hz). **Đo trước, sửa đúng chỗ đã chứng minh, đo lại.** Sửa không thấy được trên timeline → revert.

## Đo

- `fvm flutter run --profile --flavor <f> -t <entry>` (debug chậm 2–10×, số liệu sai).
- DevTools → Performance: thanh đỏ = frame quá ngân sách. UI track cao → build/layout/paint Dart; Raster track cao → GPU.
- Bật **Track Widget Builds** để thấy widget nào rebuild bao nhiêu lần; **CPU Profiler** tìm hàm nóng.
- Viết giả thuyết trước khi sửa ("cả trang rebuild mỗi lần gõ phím vì …"), rồi chứng minh bằng timeline.

## Rebuild trong bộ base — chỗ nhìn đầu tiên

`MixinBasePage.builder()` bọc **cả trang** trong `Consumer<VM>` → mỗi `notifyListeners()` rebuild toàn bộ cây trang.

- Phần chỉ phụ thuộc 1 giá trị VM thay đổi thường xuyên (đồng hồ đếm, progress, text đang gõ) → tách thành widget con đọc qua `Selector<VM, T>` / `context.select((VM vm) => vm.x)` để chỉ nó rebuild.
- VM: không `notifyListeners()` trong vòng lặp hoặc mỗi tick nếu UI không cần; gộp thay đổi rồi notify 1 lần.
- Phần tĩnh → widget `const`; bật lint `prefer_const_constructors`, `prefer_const_literals_to_create_immutables`.
- Tách subtree thành `StatelessWidget` class (đã là rule của `flutter-ui-style-guide`) — method `_buildX()` luôn chạy lại theo cha, class `const` thì được bỏ qua.
- Builder có tham số `child` (`AnimatedBuilder`, `ValueListenableBuilder`, `Consumer`, `Selector`) → truyền phần nặng không đổi qua `child`, chỉ phần trong `builder` rebuild.

## Repaint

Vùng nhỏ animate liên tục (`AppCircularProgress`, progress bar, map marker) → bọc `RepaintBoundary`. Xác nhận bằng DevTools **Highlight Repaints**: vùng tĩnh nhấp nháy theo animation thì thêm boundary. Không rải khắp nơi — mỗi boundary tốn 1 layer.

## List

- `ListView.separated` đã lazy — không dùng `ListView(children: [...])` / `Column` cho list dài.
- Item có `ValueKey(model.id)` khi list bị chèn / xoá / sắp xếp lại.
- `itemBuilder` rẻ: không sort, không `DateFormat`, không decode mỗi lần build — tính sẵn trong VM/model.
- Ảnh remote: đúng kích thước hiển thị (`cacheWidth` / ảnh thumbnail), không decode ảnh gốc 4K cho avatar 40px.

## `build` thuần và rẻ

- Không I/O, không side-effect, không tạo controller / `Paint` / regex mới mỗi lần build.
- `MediaQuery.sizeOf(context)` / `paddingOf` thay vì `MediaQuery.of(context)` (tránh rebuild khi bàn phím / xoay).
- Việc nặng đồng bộ (parse JSON lớn, sort hàng nghìn phần tử) → `await Isolate.run(() => …)` / `compute()` trong VM; dữ liệu truyền qua phải sendable.

## Jank raster (Raster track cao)

- `Opacity` / `ClipRRect` quanh cây lớn đang animate → `FadeTransition` / `AnimatedOpacity`, clip nhỏ lại.
- `BackdropFilter` (blur) trên vùng lớn hoặc đổi liên tục → bỏ hoặc thu nhỏ.
- Jank lần đầu xuất hiện hiệu ứng: kiểm tra Impeller đang bật (mặc định iOS/Android); không theo hướng SkSL warm-up cũ.

## Kiểm chứng

Ghi lại đúng tương tác đó ở profile mode: ít / hết frame đỏ, thanh UI/Raster thấp hơn, số build giảm trong Track Widget Builds. Report kèm số trước / sau.
