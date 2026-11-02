# Lists

## Lists

**LUÔN dùng `ListView.separated`** — không bao giờ `ListView.builder`. Mọi list đều `ListView.separated`, kể cả list ngang.

Vertical, có empty/loading branch riêng (tiền lệ `SuggestedOrdersSection`, `lib/src/pages/main_customer/home/widgets/suggested_orders_section.dart`) — dùng `shrinkWrap: true` + `NeverScrollableScrollPhysics()` khi list nằm lồng trong `Column`/`ScrollView` cha (không phải màn hình full-list riêng):

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
    itemCount: orders?.length ?? 0,
    separatorBuilder: (_, _) => const SizedBox(height: 12.0),
    itemBuilder: (_, index) => SuggestedOrderRow(order: orders?[index], onTap: onTapOrder),
  )
```

Với màn hình **fetch remote data + phân trang thật sự** (list riêng, cuộn toàn màn), áp dụng pattern 3-method + 2-flag (`_fetchItems`/`loadMore`/`_resetAndFetch`, `isLoadingFoo` + `isLoadingMore`) mô tả ở `CLAUDE.md` §8 và chi tiết ở `flutter-networking-and-data` — nhánh loaded LUÔN `physics: const AlwaysScrollableScrollPhysics()` để pull-to-refresh không bị im lặng khi content ngắn hơn 1 màn hình.

### Horizontal scroll

Tiền lệ: `QueueActiveUpcomingItems` (`lib/src/pages/main_customer/home/pages/queue_active/widgets/queue_active_upcoming_items.dart`) — label tiêu đề nằm ngoài trong `Padding` riêng, còn `ListView` ngang full-width với padding đặt ngay trong tham số `padding` của chính nó (không bọc `Padding` tổng bao ngoài `ListView`, tránh thu hẹp viewport):

```dart
SizedBox(
  height: 70.0,
  child: ListView.separated(
    scrollDirection: Axis.horizontal,
    padding: const EdgeInsets.symmetric(horizontal: 16.0),
    itemCount: items.length,
    separatorBuilder: (_, _) => const SizedBox(width: 10.0),
    itemBuilder: (_, index) => QueueActiveItemStatusCard(
      time: items[index].time,
      status: items[index].status,
    ),
  ),
)
```

