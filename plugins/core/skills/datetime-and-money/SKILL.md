---
name: datetime-and-money
description: Đúng thời gian, múi giờ và tiền — instant lưu UTC, ngày lịch không có zone, IANA zone, DST, tiền là số nguyên đơn vị nhỏ + mã tiền tệ, làm tròn 1 lần, chia tiền không mất xu. Dùng khi đụng giờ đặt/khởi hành, lịch, "hôm nay", giá, phí, tổng tiền, chia/hoàn tiền.
---

# Datetime, múi giờ & tiền

Phỏng theo `datetime-timezone-and-money-correctness` của BOW Skills (MIT) — xem `THIRD_PARTY_NOTICES.md`. Các lỗi này không crash — chúng lên production rồi thành trừ tiền 2 lần, đặt nhầm ngày, lệch 1 xu trên triệu dòng.

## Luật cốt lõi

1. **Instant lưu UTC.** DB `timestamptz`; wire ISO-8601 có `Z` / offset. Chỉ đổi sang giờ địa phương lúc hiển thị.
2. **Ngày lịch không phải instant.** Ngày sinh, ngày hoá đơn, ngày lễ → kiểu `date`, không `timestamptz`.
3. **Tiền không bao giờ là `double`.** Lưu và tính bằng `int` đơn vị nhỏ (cent) hoặc thư viện decimal.
4. **Tiền luôn đi kèm mã tiền tệ** (ISO-4217); EUR/USD 2 số lẻ, JPY 0, BHD 3.
5. **Không dựa vào zone của máy / server.** `DateTime.now()` không được rò vào logic nghiệp vụ.

## Chọn kiểu

| Là gì | Kiểu |
|---|---|
| Điểm trên dòng thời gian (created_at, giờ khởi hành) | instant UTC |
| Ngày lịch không giờ | `date` (không zone) |
| Giờ lặp lại theo địa phương ("mở cửa 09:00") | giờ địa phương + tên zone IANA |
| Khoảng thời gian (TTL, thời lượng chuyến) | số nguyên đơn vị cố định |
| Tiền | `int` minor units + mã tiền tệ |

## Thời gian

- Lưu **tên zone IANA** (`Europe/Paris`), không lưu offset (`+01:00`) — offset đổi theo DST.
- Tính toán trên instant UTC; áp zone khi hiển thị hoặc khi hỏi "ngày địa phương nào".
- "Hôm nay" phụ thuộc zone của **ai** → truyền zone vào, dùng package `timezone` (zone thiết bị ≠ zone user chọn):
  ```dart
  DateTime localDayStart(DateTime utc, String iana) {
    final loc = tz.getLocation(iana);
    final l = tz.TZDateTime.from(utc, loc);
    return tz.TZDateTime(loc, l.year, l.month, l.day);
  }
  ```
- `DateTime.parse(s)` trên chuỗi không có `Z` trả **giờ địa phương** → khẳng định format của API trước khi parse.
- "Cộng 1 ngày" ≠ "cộng 24 giờ" quanh DST: ý lịch → số học lịch; thời lượng → `Duration`. Lịch lặp: mở rộng theo giờ địa phương rồi mới đổi sang instant.
- SQL: lọc theo ngày địa phương phải `(created_at at time zone '<zone>')::date`, không `created_at::date` (= nửa đêm UTC).
- Hiển thị qua `intl` `DateFormat` theo locale hiện tại (`flutter-internationalization`).

## Tiền

- Input người dùng → parse như chuỗi/decimal → đổi ngay sang minor units.
- Cộng trừ chỉ khi **cùng tiền tệ** — khác thì ném lỗi.
- **Làm tròn 1 lần, ở bước cuối**, chọn chế độ có chủ đích (half-even / half-up). Không `toStringAsFixed(2)` như logic làm tròn.
- **Chia tổng** (vd 1000 cent / 3): phần dư chia cho N người đầu → tổng các phần đúng bằng tổng ban đầu.
  ```dart
  List<int> split(int total, int n) => [for (var i = 0; i < n; i++) total ~/ n + (i < total % n ? 1 : 0)];
  ```
- Quy đổi tỷ giá: nhân minor units với tỷ giá decimal, làm tròn 1 lần theo số lẻ của tiền đích; lưu tỷ giá + thời điểm đã dùng.
- Server: cột `bigint` (minor units) hoặc `numeric` + `char(3)` currency; không `float8` / `real`. Tính tiền nghiệp vụ (giá, giảm giá) ở server — client chỉ hiển thị.
- Hiển thị: `NumberFormat.currency(locale:, name:)` — chỉ đổi ra số thực ở bước hiển thị.

## Test bắt buộc khi đụng phần này

- Qua mốc DST cả 2 chiều; cuối tháng / cuối năm / 29-2.
- 1 test chạy với zone khác UTC xa (vd `TZ=Pacific/Kiritimati`) để lộ giả định zone server/máy.
- Chia rồi cộng lại = đúng tổng, so bằng tuyệt đối (không tolerance); test cả tiền 0 và 3 số lẻ.
