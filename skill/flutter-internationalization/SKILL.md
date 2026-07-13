---
name: flutter-internationalization
description: |
  Convention i18n cho rual_transpo_rider_mobile: tool flutter_intl (intl_utils) với 2 locale fr (main) / en, không bao giờ hardcode user-visible text.
  Sử dụng khi: thêm hoặc sửa translations, user-visible strings, hoặc locale handling.
---

# Flutter Internationalization — rual_transpo_rider_mobile

## Tổng quan

App transportation/rider cho thị trường Pháp (trips, bus, arrêts, tickets, tarifs). Setup **2 locale** (`fr` main + `en`) dùng `flutter_intl` / `intl_utils` (KHÔNG `flutter gen-l10n`):

- `.arb` files trong `lib/src/l10n/`: chỉ có **`intl_fr.arb`** (main locale) và **`intl_en.arb`**. Không có locale thứ 3, không có `intl_vi.arb` — repo này không phục vụ end-user tiếng Việt (tiếng Việt chỉ là ngôn ngữ docs/comment nội bộ, không phải app locale).
- Config nằm hoàn toàn trong `pubspec.yaml` dưới key `flutter_intl:` — **KHÔNG có file `l10n.yaml`**.
- Generated: `lib/src/generated/l10n.dart` + `lib/src/generated/intl/messages_*.dart` (export `S`). Khác với setup thường thấy ở project khác: **các file generated này ĐANG được commit vào git** (`git ls-files` xác nhận), không bị gitignore. Nghĩa là sau khi sửa `.arb` và regenerate, phải add/commit luôn phần generated thay đổi.
- **Không bao giờ hardcode user-visible text** trong widget/VM. Mọi label, button text, placeholder, hint, title, message, error string PHẢI đến từ `S.current.xxx`.

## Khi nào sử dụng

- Thêm user-visible string mới
- Wire localization vào screen mới
- Review Flutter code cho i18n compliance
- Thêm locale mới (hiện tại chỉ fr/en)

## File Layout

```
lib/src/l10n/
├── intl_fr.arb           ← French (MAIN locale — nguồn chuẩn)
└── intl_en.arb           ← English

lib/src/generated/
├── l10n.dart              ← export S, ĐƯỢC commit vào git
└── intl/messages_*.dart   ← ĐƯỢC commit vào git
```

`pubspec.yaml` config (đọc trực tiếp từ file, không có `l10n.yaml`):

```yaml
flutter_intl:
  enabled: true
  main_locale: fr
  arb_dir: lib/src/l10n
  output_dir: lib/src/generated
```

## Workflow

1. Thêm key vào **CẢ 2** `.arb` files (`intl_fr.arb` + `intl_en.arb`) với matching JSON structure. `@`-metadata block trong repo này hiện chỉ khai báo `placeholders` (kiểu ICU cho interpolation) — **không có field `description`** ở bất kỳ key nào hiện có, dù `intl_utils` hỗ trợ field đó:
   ```json
   {
     "homeGreetingMorning": "Bonjour, {name}",
     "@homeGreetingMorning": {
       "placeholders": { "name": { "type": "String" } }
     },
     "tripDetailsStopNumber": "Arrêt n°{number}",
     "@tripDetailsStopNumber": {
       "placeholders": { "number": { "type": "String" } }
     }
   }
   ```
2. Chạy `fvm flutter pub run intl_utils:generate` (KHÔNG `flutter gen-l10n`).
3. Đọc trong code qua `S.current.<key>`:
   ```dart
   import 'package:rual_transpo_rider_mobile/src/generated/l10n.dart';

   S.current.homeBusesNearby
   ```
   Trong toàn bộ codebase hiện tại, **100% chỗ dùng i18n là `S.current`** (kể cả trong widget `build()`) — `S.of(context)` tồn tại như API chuẩn của `intl_utils` nhưng chưa có chỗ nào dùng thật. Nếu cần đọc theo `context` (ví dụ test locale override), `S.of(context)` vẫn hoạt động, nhưng đừng bịa ra là convention đang dùng — convention thực tế là `S.current`.
4. **Giữ keys đồng bộ giữa CẢ 2 `.arb` files.** Key thiếu trong `intl_en.arb` sẽ fallback về main locale (`fr`) — đó là dấu hiệu quên dịch, không phải feature.

## Quy tắc

- **KHÔNG BAO GIỜ hardcode user-visible text** trong widget/VM files. Thêm key vào cả 2 ARB rồi regenerate.
- `S.current` trả về **non-nullable**. Không bao giờ dùng `?.` trên nó.
- Sau bất kỳ thay đổi nào trên `.arb`, regenerate với `fvm flutter pub run intl_utils:generate`, rồi commit luôn diff trong `lib/src/generated/` (không gitignore ở repo này).
- Key đặt theo camelCase, nhóm theo prefix feature — match key sẵn có trước khi đặt tên mới. Ví dụ thật trong repo: `homeGreetingMorning`, `homeBusesNearbyCount`, `tripOptionsFilterBest`, `tripDetailsArrivingAt`, `ticketConfirmedSubtitle`, `queueActiveStopBadge`, `driverHomeDriverIdLabel`, `messageErrorLostConnect`.

## Ví dụ dùng trong ViewModel (`lib/src/base/base_vm.dart`)

```dart
void showErrorConnection() {
  hideLoading();
  (Connectivity().checkConnectivity()).then((result) {
    if (result.contains(ConnectivityResult.none)) {
      showError(S.current.messageErrorLostConnect);
      return;
    }
    showError(S.current.messageErrorProcessFailed);
  });
}
```

`BaseViewModel` không nhận `BuildContext`, nên VM luôn dùng `S.current` — không có cách nào khác để lấy chuỗi đã dịch từ tầng VM.

## Enum + i18n (label theo locale)

Pattern chuẩn khi một enum domain cần hiển thị label đã dịch: đặt extension `S.current`-backed ngay cạnh enum, KHÔNG nhét switch-case dịch string trong widget. Ví dụ thật — `lib/src/models/enums/trip_status.dart`:

```dart
enum TripStatus {
  onTime,
  pending,
  delayed;

  static TripStatus fromString(String? value) => switch (value?.toLowerCase()) {
        'pending' => pending,
        'delayed' => delayed,
        _ => onTime,
      };
}

extension TripStatusLabel on TripStatus {
  String label({String detail = ''}) => switch (this) {
        TripStatus.pending => S.current.homeTripStatusPending,
        TripStatus.delayed => S.current.homeTripStatusDelayed(detail),
        TripStatus.onTime => S.current.homeTripStatusOnTime(detail),
      };
}
```

Widget chỉ gọi `trip.status.label()` — không bao giờ switch trực tiếp trên enum để chọn string trong page/VM.

## Pluralization

`intl_utils` hỗ trợ cú pháp ICU plural (`{count, plural, =0{...} =1{...} other{...}}`), nhưng **hiện tại không có key nào trong `intl_fr.arb`/`intl_en.arb` dùng plural** — mọi số nhiều/số ít trong app đang xử lý bằng câu cố định + placeholder số (`homeBusesNearbyCount`: `"{count} bus à moins de {distance}km"`). Nếu cần plural thật (ví dụ số vé, số trạm dừng), thêm theo cú pháp ICU chuẩn vào **cả 2** file và document lại ở đây — đừng tự chế cú pháp riêng.

## Locale runtime & networking

- `AppProvider.setLocale([String? languageCode])` (`lib/src/utils/app_provider.dart`) — static, không cần context. Không truyền argument thì fallback về `AppConstants.defaultLang`. Persist qua `SharedPrefs.locale` (dùng `shared_preferences` thuần, KHÔNG qua `flutter_secure_storage`). `AppProvider.currentLocale` là static getter trả `Locale?`, đọc lại state hiện tại không cần context.
- Root `MaterialApp.router` (`lib/rual_transpo_rider_app.dart`) khai báo `localizationsDelegates: [S.delegate, ...]` và `supportedLocales: S.delegate.supportedLocales`; locale ban đầu truyền vào `AppProvider` cũng là `Locale(AppConstants.defaultLang)`.
- Locale còn chảy sang tầng network: `ApiInterceptor.onRequest` (`lib/src/services/remote/utils/api_interceptor.dart`) đọc `prefs.locale ?? AppProvider.currentLocale` rồi set header `language:` cho MỌI request ra ngoài — xem thêm skill `flutter-networking-and-data` để biết chi tiết interceptor.

### Discrepancy cần biết (đừng tự ý chọn cái nào "đúng")

`pubspec.yaml` khai `flutter_intl.main_locale: fr`, nhưng `lib/src/constants/app_constants.dart` lại có:

```dart
static const defaultLang = 'en';
```

Đây là hằng số dùng làm fallback runtime locale ở cả `AppProvider.setLocale()` lẫn `Locale` khởi tạo trong root `MaterialApp`. Hai giá trị (`fr` ở pubspec vs `en` ở `AppConstants`) hiện KHÔNG khớp nhau — đây là inconsistency có thật trong repo, chưa được fix. Khi động vào locale logic, đừng ngầm định bên nào là "nguồn chuẩn" — flag lại với người review thay vì tự sửa một chiều.

## Gotcha: error-code → message chưa route qua S.current

`StringCodeExt.toLang` (`lib/src/components/code_error.dart`) là chỗ dự định map API error code (`ACCESS_TOKEN_INVALID`, ...) sang message hiển thị, được `ApiInterceptor.onError` gọi qua `message.toLang`. Hiện tại implementation là stub (`return "ád";`, không gọi `S.current` gì cả) — nếu cần hoàn thiện luồng này, phải route qua `S.current.<key>` giống mọi chỗ khác, không hardcode string.

## Cái cớ thường gặp

| Cái cớ | Phản bác |
|---|---|
| "Chỉ là TODO, không bao giờ translate" | TODO trở thành production. Dùng `S.current.<key>` từ đầu |
| "Hardcoded text cho demo" | Demo cũng thành production. Localize từ ngày một |
| "Chỉ user Pháp, skip en" | Key lệch giữa 2 file → khó trace khi cần thật. Sync cả 2 luôn |
| "Tôi sẽ generate l10n sau" | "Sau" = analyze fail cho cả team, và generated diff không commit theo kịp | 

## Cờ đỏ

- User-visible text string trong `Text(...)`, `label:`, `hintText:` không từ `S.current.<key>`
- File `l10n.yaml` tồn tại (sai tool — project dùng `flutter_intl` trong `pubspec.yaml`)
- `flutter gen-l10n` trong bất kỳ build script nào
- Thêm key nhưng thiếu 1 trong 2 file ARB (`intl_fr.arb` / `intl_en.arb`)
- Sửa `.arb` nhưng không regenerate + không commit lại `lib/src/generated/`
- String interpolation bằng `'$var'` thay vì ICU placeholders trong `.arb`
- `main_locale` trong pubspec khác `fr`
- Switch-case chọn label dịch trực tiếp trong widget/VM thay vì extension cạnh enum (xem mục Enum + i18n)
- Dùng `!` trên bất kỳ giá trị nào liên quan tới `S.current`/locale — never null-assert, dùng `?.`/`??`

## Kiểm chứng

- [ ] Không literal strings trong widget / VM code cho user-visible text
- [ ] Keys thêm vào CẢ 2 ARB (`intl_fr` + `intl_en`) với matching `@` placeholders (nếu có interpolation)
- [ ] Số key 2 file bằng nhau: `for f in lib/src/l10n/intl_*.arb; do echo "$f: $(grep -cE '^\s*"[^@]' $f)"; done`
- [ ] Sau `.arb` change, `fvm flutter pub run intl_utils:generate` thành công và `lib/src/generated/` diff được commit
- [ ] Enum có label hiển thị dùng extension `S.current`-backed cạnh enum, không switch rải rác trong UI
- [ ] `fvm flutter analyze` exit 0

## Skill liên quan

`flutter-mvvm-provider-architecture` (BaseViewModel không nhận context nên luôn `S.current`), `flutter-networking-and-data` (header `language:` trong `ApiInterceptor`), `flutter-ui-style-guide`, `flutter-multi-app-flavor`, `flutter-deployment-guide`, `frontend-design`.
