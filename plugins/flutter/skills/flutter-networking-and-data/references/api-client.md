# ApiClient (Dio) + ApiInterceptor

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

Ví dụ (Google Maps reverse-geocode) — shape chuẩn khi cần
thêm 1 REST service tập trung, độc lập với domain chính:

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

Khi cần 1 service REST mới cho domain khác (order, voucher, price…), theo đúng shape
trên: **abstract + impl**, impl nhận `Dio` (hoặc `ApiClient`) qua constructor, tự
nối `AppConstants.baseURL` + path, đăng ký trong `setUpInjector()`
(`lib/src/utils/locator.dart`) rồi VM đọc qua field mới trên `BaseViewModel`
(theo mẫu `api`/`prefs`/`locationService`/`activeOrderServices` đã có) — KHÔNG gọi
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

