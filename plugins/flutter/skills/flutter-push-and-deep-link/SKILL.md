---
name: flutter-push-and-deep-link
description: Push notification (FCM/APNs, local notification) + deep link (app_links, universal/app link) cho bộ base Flutter — đủ 6 điểm vào (cold/warm/foreground), hàng đợi pending intent, replay qua appRouter sau Splash, validate link. Dùng khi wire push, deep link, hoặc sửa bug "bấm thông báo không mở đúng màn".
---

# Push notification & deep link

Phỏng theo `flutter-push-notifications-and-deep-linking` của BOW Skills (MIT) — xem `THIRD_PARTY_NOTICES.md`. Thêm `firebase_messaging` / `flutter_local_notifications` / `app_links` = thêm dependency → hỏi user.

Sự thật cốt lõi: **app có thể được khởi động lạnh bởi sự kiện bên ngoài**, và dữ liệu đó phải sống tới khi router sẵn sàng. Coi payload (tap thông báo / link) là *pending intent*: bắt → giữ → replay khi điều hướng đã sẵn.

## 6 điểm vào — xử lý đủ

| Sự kiện | Trạng thái app | Nghe ở |
|---|---|---|
| Nhận push | foreground | `FirebaseMessaging.onMessage` → tự hiện bằng local notification |
| Tap push | background | `FirebaseMessaging.onMessageOpenedApp` |
| Tap push | **terminated** | `FirebaseMessaging.instance.getInitialMessage()` |
| Nhận push | background/terminated | handler top-level `onBackgroundMessage` (isolate riêng, không điều hướng) |
| Mở link | warm | `appLinks.uriLinkStream` |
| Mở link | **cold** | `appLinks.getInitialLink()` |

Hai case cold start là case hay bị quên — gọi trước khi router tồn tại sẽ mất đích đến.

## Kiến trúc trong bộ base

- `PendingIntents` (service ở `lib/src/services/<group>/`) đăng ký trong `setUpInjector()`: `seedInitial(Uri)`, `takeInitial()`, `Stream<Uri> stream`. Mọi điểm vào đẩy về **cùng 1 dạng `Uri`** — push `{"route": "/orders/42"}` → `Uri.parse('myapp:///orders/42')` (3 dấu `/` để `uri.path == '/orders/42'`).
- Routing info đặt trong `message.data` (key của mình), không trong block `notification` (OS tiêu thụ).
- Init messaging / app_links trong `main_*.dart` (sau DI) → `seedInitial` cho cold start.
- **Replay ở Splash VM**: sau khi quyết định session (`appRouter.replaceAll([...])`), `takeInitial()` → điều hướng; sau đó VM main subscribe `stream` (lưu `StreamSubscription?`, cancel trong `dispose()`).
- Map `Uri` → route qua **allow-list** (switch trên `uri.pathSegments` → `FooRoute(id: …)`); không khớp → bỏ qua về màn mặc định. Điều hướng qua `appRouter`, cold start dùng `replaceAll` / `navigate` thay vì `push` (back stack rỗng).
- Multi-app: mỗi app chỉ map route của router app đó.

## Link là input không tin cậy

- Allow-list path; không có open redirect.
- Đích cần đăng nhập mà chưa có session → về login, xong thì quay lại đích.
- Custom scheme giả mạo được — không dùng để cấp quyền / auth.
- Khử trùng lặp theo message/link id (`getInitialMessage` và tap có thể bắn cùng sự kiện).

## Token

Luôn nghe `onTokenRefresh` và gửi lại backend; không cache token như vĩnh viễn. iOS: có APNs token rồi mới lấy FCM token. Android 13+ cần `POST_NOTIFICATIONS`.

## Kiểm chứng (từng nền tảng, máy thật cho iOS)

1. Tap push khi **terminated** → mở đúng màn sau cold start.
2. Tap push khi background · 3. Push khi foreground → banner local, tap đúng màn.
4. Link cold + warm: `adb shell am start -W -a android.intent.action.VIEW -d "https://<domain>/orders/42"`, `xcrun simctl openurl booted "myapp:///orders/42"`.
5. Link tới màn cần đăng nhập khi đã logout → login rồi quay lại.

Chạy và chụp màn hình theo `flutter-run-and-verify`.

## references/

| File | Khi nào |
|---|---|
| `references/setup.md` | Code `requestPermission` + token, background handler `@pragma('vm:entry-point')`, `flutter_local_notifications` channel + foreground display, `app_links` + cấu hình Android App Links / iOS Universal Links / custom scheme |
