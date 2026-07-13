---
name: flutter-networking-and-data
description: |
  Data layer cho Rual Transpo Rider Mobile: REST qua Dio (ApiClient + ApiInterceptor), Dart model rules (all-nullable, hand-written fromJson/toJson), local persistence (SharedPrefs — secure storage cho token/user, SharedPreferences cho theme/locale), và debounce (EasyDebounce, tag-based static utility). Repo này KHÔNG có Supabase/Postgres — toàn bộ backend đi qua REST/Dio.
  Sử dụng khi: implement model mới, thêm REST API call qua Dio, đọc/ghi token/user/theme/locale, hoặc debounce search/filter.
---

# Flutter Networking and Data — Rual Transpo Rider Mobile

## Tổng quan

Đây là app transportation/rider (France market), backend REST thuần qua Dio —
`pubspec.yaml` không có `supabase_flutter` hay bất kỳ dependency Postgres nào.
Convention cho data layer:

- **REST**: `ApiClient` (`lib/src/services/remote/api_client.dart`) wrap một
  `Dio()` instance duy nhất, đăng ký 1 lần trong `setUpInjector()`, VM truy cập
  qua field `api` (inherited từ `BaseViewModel`).
- **Auth + locale header + error mapping**: `ApiInterceptor`
  (`lib/src/services/remote/utils/api_interceptor.dart`), gắn vào `dio.interceptors`.
- **Models**: mọi field nullable, không `final`, không `required`; hand-written
  `fromJson`/`toJson`. KHÔNG `freezed`, KHÔNG `json_serializable` (package này có
  trong `dev_dependencies` nhưng không được dùng cho model — đừng đề xuất dùng nó).
- **Local storage**: `SharedPrefs` (`lib/src/services/local/share_prefs.dart`) —
  token + user qua `flutter_secure_storage`, theme + locale qua `shared_preferences`
  thường (2 cơ chế khác nhau trong cùng 1 class).
- **Debounce**: `EasyDebounce` (`lib/src/components/easy_debounce.dart`) — static,
  tag-based, KHÔNG phải class instantiate per-VM.
- **Pagination**: repo hiện **chưa có** convention load-more/paginated-list nào cả
  (grep `loadMore` trong `lib/src/pages` ra rỗng) — xem mục cuối bài.

## Khi nào sử dụng

- Implement model mới (request body, response, entity domain: trip, bus, stop, fare, ticket, on-demand route, Google geocode…)
- Thêm REST API call qua `ApiClient`/Dio
- Đọc/ghi token, user, theme, locale qua `SharedPrefs`
- Thêm debounced search / filter
- Bắt đầu implement paginated list đầu tiên của repo (chưa có tiền lệ, xem cảnh báo ở dưới)

## REST — ApiClient (Dio)

`ApiClient` là single `Dio()` instance, config trong constructor
(`lib/src/services/remote/api_client.dart`):

```dart
class ApiClient {
  final dio = Dio();

  GoogleMapServices? googleMapServices;

  ApiClient() {
    dio.options.connectTimeout = const Duration(seconds: 50);
    dio.options.receiveTimeout = const Duration(seconds: 30);
    dio.options.sendTimeout = const Duration(seconds: 30);
    dio.options.headers['Content-Type'] = 'application/json';

    if (kDebugMode) {
      dio.interceptors.add(PrettyDioLogger(...));
    }

    if (!kReleaseMode) {
      // accept self-signed certs ngoài release build
    }

    googleMapServices = GoogleMapServicesImpl(dio, baseUrl: AppConstants.baseMapURL);
    dio.interceptors.add(ApiInterceptor(dio: dio));
  }
}
```

Điểm cần lưu ý khi thêm call mới:

- **`dio.options.baseUrl` KHÔNG được set** ở `ApiClient`. Muốn gọi API chính
  (`AppConstants.baseURL`, đọc từ `AppConfig.shared.baseUrl` — tức từ `.env*`),
  bạn phải tự nối path đầy đủ, ví dụ `'${AppConstants.baseURL}/reports'` — gọi
  `api.dio.get('/reports')` suông sẽ KHÔNG tự thêm host. Đây là lý do
  `GoogleMapServicesImpl` (bên dưới) tự giữ field `baseUrl` riêng và tự nối string
  ở mỗi call thay vì dựa vào `dio.options.baseUrl`.
- **KHÔNG tự `Dio()` mới** ở feature code — luôn qua `api.dio` (đã có interceptor +
  logger + timeout + cert relax sẵn).
- `PrettyDioLogger` chỉ bật khi `kDebugMode`; cert self-signed chỉ chấp nhận khi
  `!kReleaseMode` (qua `IOHttpClientAdapter.createHttpClient`).

### Ví dụ REST service tách riêng: GoogleMapServices

Repo hiện chưa có service REST nào cho domain nghiệp vụ (trip/bus/fare…) gọi qua
`api.dio` — endpoint duy nhất đã wire thật là Google Maps reverse-geocode, dùng làm
tiền lệ khi bạn cần thêm 1 REST service tập trung, độc lập với domain chính:

```dart
// google_map_services.dart
abstract class GoogleMapServices {
  Future<GoogleGeocodeResponseModel?> reverseGeocode({Position? position});
}

// google_map_services_impl.dart
class GoogleMapServicesImpl implements GoogleMapServices {
  GoogleMapServicesImpl(this._dio, {this.baseUrl});

  final Dio _dio;
  final String? baseUrl;

  @override
  Future<GoogleGeocodeResponseModel?> reverseGeocode({Position? position}) async {
    final response = await _dio.get<dynamic>(
      "$baseUrl${EndPoint.googleMapReverseGeocode}",
      queryParameters: {
        'latlng': '${position?.latitude},${position?.longitude}',
        'key': AppConstants.apiKeyMap,
      },
    );
    final data = response.data;
    if (data is! Map<String, dynamic>) return null;
    return GoogleGeocodeResponseModel.fromJson(data);
  }
}
```

`ApiClient` khởi tạo nó bằng chính `dio` đã config (logger/interceptor dùng chung)
nhưng với `baseUrl` riêng (`AppConstants.baseMapURL`), và expose qua field
`googleMapServices` — VM đọc qua `api.googleMapServices` (tiền lệ thật:
`home_vm.dart` có getter `GoogleMapServices? get googleMapServices => api.googleMapServices;`).

Endpoint path constants tách riêng ở `lib/src/services/remote/utils/end_point.dart`
(`abstract class EndPoint { EndPoint._(); static const String xxx = '/path'; }`) —
theo cùng convention khi thêm domain endpoint mới.

Khi cần 1 service REST mới cho domain khác (trip, ticket, fare…), theo đúng shape
trên: **abstract + impl**, impl nhận `Dio` (hoặc `ApiClient`) qua constructor, tự
nối `AppConstants.baseURL` + path, đăng ký trong `setUpInjector()`
(`lib/src/utils/locator.dart`) rồi VM đọc qua field mới trên `BaseViewModel`
(theo mẫu `api`/`prefs`/`locationService`/`activeTripServices` đã có) — KHÔNG gọi
`locator<T>()` trực tiếp trong VM.

## ApiInterceptor — auth header, locale header, error mapping

`lib/src/services/remote/utils/api_interceptor.dart`, `extends Interceptor`:

```dart
@override
void onRequest(options, RequestInterceptorHandler handler) async {
  final prefs = locator<SharedPrefs>();
  final localeCode = prefs.locale ?? AppProvider.currentLocale;
  final isRefreshRequest = options.path.contains('/auth/refresh');
  if (!isRefreshRequest && (prefs.accessToken?.isNotEmpty ?? false)) {
    options.headers['Authorization'] = 'Bearer ${prefs.accessToken}';
  }
  options.headers['language'] = localeCode;
  handler.next(options);
}
```

- Auth header tự inject, **skip** khi path chứa `/auth/refresh` (tránh gửi token cũ
  khi refresh chính token).
- Header `language` luôn set, ưu tiên `prefs.locale`, fallback `AppProvider.currentLocale`.

`onError` xử lý theo thứ tự:

1. Check `connectivity_plus` (`Connectivity().checkConnectivity()`) — nếu offline,
   reject ngay với 1 `DioException` message riêng cho "no internet", không đi tiếp
   phần parse response.
2. Nếu online, lấy `err.response?.data` — nếu là `Map<String, dynamic>`, đọc
   `rawData['code'] ?? rawData['message']`; giá trị này có thể là `List` (lấy
   `.first.toString()`) hoặc `String` — gán vào `message`.
3. Nếu có `message`, chạy qua extension `.toLang` (`lib/src/components/code_error.dart`
   — map một số code lỗi cố định như `ACCESS_TOKEN_INVALID` sang string hiển thị,
   trả `null` nếu không khớp code nào) rồi reject với message đó.
4. Nếu không parse được gì, reject với message fallback chung.

**Lưu ý (bug đã biết, chưa fix)**: 2 message fallback trong file này —
`'S.current.messageErrorNoInternetConnection'` (case no-internet) và
`'S.current.messageErrorProcessingFailed'` (case fallback cuối) — đang là
**string literal đúng nghĩa đen**, KHÔNG phải nội suy gọi `S.current.*` thật. Tức
là UI đang hiển thị nguyên văn chuỗi `"S.current.messageErrorProcessingFailed"`
thay vì message đã localize. Đây là vấn đề có thật trong code hiện tại, nên biết
để tránh copy y hệt pattern này sang chỗ khác; sửa nó (gọi đúng
`S.current.messageErrorProcessingFailed`) là việc nên làm nhưng nằm ngoài phạm vi
tài liệu này — đừng viết code như thể nó đã được sửa.

## Local Storage — SharedPrefs

`lib/src/services/local/share_prefs.dart`. Một class, **hai cơ chế lưu trữ khác
nhau** cho hai nhóm dữ liệu:

| Dữ liệu | Cơ chế | Field |
|---|---|---|
| `accessToken` (`String?`) | `FlutterSecureStorage` | `_accessToken` |
| `appUser` (`AppUserModel?`) | `FlutterSecureStorage`, JSON qua `jsonEncode(user.toJson())` | `_appUser` |
| `theme` (`ThemeMode`) | `SharedPreferences` thường | key `theme` |
| `locale` (`String?`) | `SharedPreferences` thường | key `locale` |

`initialise()` (phải `await` 1 lần trong mỗi `main_*.dart`, ngay sau
`setUpInjector(...)`) làm thêm 1 việc: **migrate 1 lần** `accessToken`/`appUser`
cũ nếu chúng còn nằm ở `SharedPreferences` (kiểm tra `containsKey`, đọc giá trị,
ghi sang secure storage, rồi `remove` key cũ) — dữ liệu mới từ đây về sau chỉ còn
nằm ở secure storage. `theme`/`locale` không có bước migrate vì chúng vốn đã ở
`SharedPreferences` và ở lại đó.

```dart
bool get isLogin => _accessToken?.isNotEmpty ?? false;

void removeSession() {
  accessToken = null; // setter tự xóa key khỏi secure storage khi gán null
  appUser = null;
}
```

Quy tắc: VM không tự đọc `FlutterSecureStorage`/`SharedPreferences` trực tiếp —
luôn qua `prefs` (field inherited từ `BaseViewModel`, đã `locator<SharedPrefs>()`).

## Debounce — EasyDebounce (tag-based)

Repo dùng `lib/src/components/easy_debounce.dart` — **static, theo tag**, không
phải một class instantiate riêng cho từng VM:

```dart
class EasyDebounce {
  static void debounce(String tag, Duration duration, EasyDebounceCallback onExecute);
  static void fire(String tag);
  static void cancel(String tag);
  static void cancelAll();
  static int count();
}
```

> **Lệch với `.claude/CLAUDE.md`**: file convention của repo mô tả một class
> `AppDebounce` ở `lib/components/app_debouncer.dart`, instantiate per-VM
> (`final AppDebounce _debounce = AppDebounce(milliseconds: 500);`). Class/file đó
> **không tồn tại** trong repo này — `AppDebounce` chỉ xuất hiện trong tài liệu,
> chưa từng được viết. API thật đang được dùng là `EasyDebounce` ở trên; dùng đúng
> cái này, đừng tạo `AppDebounce` mới trừ khi có quyết định đổi convention rõ ràng.

Ví dụ thật đang chạy trong repo (`lib/src/components/input/app_text_field.dart`) —
debounce forward `onChanged` ở tầng widget dùng chung:

```dart
void _onChanged(String value) {
  EasyDebounce.debounce(
    'onChanged',
    const Duration(milliseconds: 20),
    () => widget.onChanged?.call(value),
  );
}

@override
void dispose() {
  EasyDebounce.cancel('onChanged');
  super.dispose();
}
```

Khi debounce một search/filter gọi API, đặt logic ở **VM**, chọn tag riêng cho
mỗi thao tác (tránh 2 debounce khác nhau vô tình dùng chung tag rồi cancel lẫn
nhau), và nhớ `EasyDebounce.cancel(tag)` trong `dispose()` của VM:

```dart
void onSearchChanged(String query) {
  _query = query;
  EasyDebounce.debounce('searchTrips', const Duration(milliseconds: 500), () {
    fetchTrips();
  });
}

@override
void dispose() {
  EasyDebounce.cancel('searchTrips');
  super.dispose();
}
```

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
class TripModel {
  String? id;
  String? originName;
  String? destinationName;
  DateTime? departureTime;

  TripModel();

  factory TripModel.fromJson(Map<String, dynamic> json) {
    return TripModel()
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

**Lưu ý (bug đã biết, chưa fix)**: `AppUserModel.fromJson` thật trong repo có lỗi
copy-paste — `..id = json['email']` (gán nhầm `email` vào `id` thay vì
`json['id']`). Biết để không copy nguyên si file này làm mẫu; viết model mới theo
đúng field-tương-ứng-key, đừng tái tạo bug này.

### Domain models có sẵn

`lib/src/models/` chứa model của domain transportation thật (trip, bus stop,
fare, ticket, on-demand route, các response Google geocode…), cộng thư mục con
`enums/` (discriminator enums), `driver/` (model riêng cho app driver), và
`delete_late/` — thư mục này là **nợ kỹ thuật rõ ràng** (các model placeholder cũ
bị thay thế, chờ dọn), KHÔNG phải một convention để noi theo — đừng thêm model
mới vào đó.

### Enum discriminator + `fromString()`

Field API kiểu string cố định (type/status/kind/role) luôn là enum riêng ở
`lib/src/models/enums/`, với `static fromString()` bằng switch expression, và
extension label cạnh nó nếu cần hiển thị UI. Tiền lệ thật —
`lib/src/models/enums/trip_status.dart`:

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

Trong `fromJson`, parse thẳng qua enum — không giữ field kiểu `String?` thô:

```dart
status: TripStatus.fromString(json['status'] as String?),
```

## Pagination / load-more — chưa có convention, đề xuất khi cần

Repo hiện **không có bất kỳ trang list nào** implement load-more/pull-to-refresh
phân trang (`grep -r loadMore lib/src/pages` ra rỗng). Đừng khẳng định "đây là
cách repo đã làm" khi review code — chưa có tiền lệ thật để đối chiếu.

Khi bạn là người đầu tiên implement 1 list fetch remote có phân trang, đề xuất
tối thiểu (điều chỉnh theo nhu cầu thật của trang đó, không phải luật cứng):

- VM giữ `page`, `pageSize`, `hasMore`, và **loading flag riêng** cho initial
  load vs. load-more (không dùng chung 1 `isLoading` cho hai thao tác khác UX).
- Service method nhận `page`/`limit` qua `queryParameters`, VM tự cộng dồn
  `items = [...items, ...next]` khi load more, reset về `page = 1` khi filter
  đổi hoặc pull-to-refresh.
- Dùng `ListView.separated` (không `ListView.builder`) cho phần list đã có data,
  loading indicator là `AppCircularProgress` (không `CircularProgressIndicator`
  mặc định).

## Cái cớ thường gặp

| Cái cớ | Phản bác |
|---|---|
| "Tự new Dio() ở đây cho nhanh" | `ApiClient` đã có interceptor + logger + timeout + cert relax. Dùng `api.dio` |
| "Gọi `api.dio.get('/reports')` là ra đúng host" | `dio.options.baseUrl` không được set — phải tự nối `AppConstants.baseURL` vào path |
| "Tạo `AppDebounce` class mới theo CLAUDE.md" | Class đó không tồn tại trong repo; dùng `EasyDebounce` (tag-based) đang có sẵn |
| "Model dùng `json_serializable` cho đỡ viết tay" | Có trong `dev_dependencies` nhưng repo không dùng nó cho model nào — giữ hand-written |
| "Copy `AppUserModel.fromJson` làm mẫu" | File đó có bug copy-paste (`id = json['email']`) — viết field-đúng-key, đừng lặp lại |
| "Trang list này thiếu load-more chắc do lười" | Không phải quy tắc bị vi phạm — repo chưa có tiền lệ pagination nào cả, đây là lần đầu |
| "`!` một lần cho chỗ này không sao" | Convention repo cấm `!` viết tay trong code — dùng `?.`/`??`/local non-null binding |

## Cờ đỏ

- `Dio()` instantiation mới ngoài `ApiClient`
- Gọi `api.dio.<method>('/path')` mà không tự nối `AppConstants.baseURL` (baseUrl không set sẵn)
- Model field khai báo non-nullable, `final`, hoặc `required`
- Model dùng `freezed`/`json_serializable`/codegen thay vì hand-written `fromJson`/`toJson`
- Discriminator field (type/status/kind/role) giữ nguyên `String?` thay vì enum + `fromString()`
- Tạo mới `AppDebounce` class theo mô tả cũ trong CLAUDE.md — dùng `EasyDebounce` thật đang có
- Hai debounce khác nhau dùng chung 1 tag `EasyDebounce` (cancel lẫn nhau)
- VM tự gọi `locator<SharedPrefs>()`/`locator<ApiClient>()` thay vì dùng field `prefs`/`api` sẵn có
- Token pass thủ công per-call thay vì để `ApiInterceptor` tự inject
- `!` (null assertion) ở bất kỳ đâu trong data layer viết tay
- Thêm model mới vào `lib/src/models/delete_late/`

## Kiểm chứng

- [ ] REST call qua `api.dio` hoặc service abstract+impl — không raw `Dio()` mới
- [ ] Path gọi API chính có tự nối `AppConstants.baseURL` (vì `dio.options.baseUrl` không set)
- [ ] Auth header để `ApiInterceptor` tự lo — không set `Authorization` thủ công per-call
- [ ] Model: mọi field nullable, không `final`/`required`, `fromJson`/`toJson` hand-written, khớp đúng key JSON (không copy bug kiểu `AppUserModel`)
- [ ] Discriminator field dùng enum ở `lib/src/models/enums/` với `fromString()`
- [ ] Debounce dùng `EasyDebounce.debounce(tag, ...)` với tag riêng biệt, có `cancel(tag)` khi dispose
- [ ] Không tạo `AppDebounce` class mới (không tồn tại trong repo)
- [ ] Persist token/user qua `prefs.accessToken`/`prefs.appUser` — không tự đụng `FlutterSecureStorage`/`SharedPreferences` trực tiếp trong VM
- [ ] Trang list phân trang mới (nếu có) tự khai báo rõ đây là pattern mới, không viện dẫn "theo convention có sẵn"
- [ ] KHÔNG `!` trong toàn bộ data layer viết tay
- [ ] `fvm flutter analyze` exit 0
