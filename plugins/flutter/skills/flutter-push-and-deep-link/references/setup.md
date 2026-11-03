# Setup chi tiết: FCM/APNs, background handler, local notification, app_links

Phỏng theo `flutter-push-notifications-and-deep-linking` của BOW Skills (MIT) — xem `THIRD_PARTY_NOTICES.md`. Code nguyên bản; phần điều hướng đã thay bằng `appRouter` trong SKILL.md.

## 2. FCM/APNs setup, in order

```dart
Future<void> initMessaging() async {
  // 1. Permission. iOS/web require it; Android 13+ needs POST_NOTIFICATIONS.
  final settings = await FirebaseMessaging.instance.requestPermission(
    alert: true, badge: true, sound: true,
  );
  final status = settings.authorizationStatus;
  // Proceed only when granted; notDetermined/denied must not register a token.
  if (status != AuthorizationStatus.authorized &&
      status != AuthorizationStatus.provisional) {
    return;
  }

  // 2. iOS: ensure the APNs token exists before asking for the FCM token.
  if (Platform.isIOS) {
    final apns = await FirebaseMessaging.instance.getAPNSToken();
    // Simulator or not-yet-provisioned. On a real device it can be null for a
    // short window after the grant — poll getAPNSToken() with backoff, don't drop it.
    if (apns == null) return;
  }

  // 3. Register the device token with your backend, and refresh on rotation.
  final token = await FirebaseMessaging.instance.getToken();
  if (token != null) await registerDeviceToken(token);
  FirebaseMessaging.instance.onTokenRefresh.listen(registerDeviceToken);
}
```

Tokens rotate (reinstall, restore, clearing data). **Always** listen to `onTokenRefresh`; never cache a
token as permanent. De-dupe server-side on token value, not user id.

## 3. The background handler must be top-level

It runs in a separate isolate with no access to your widget tree or in-memory singletons.

```dart
@pragma('vm:entry-point') // keep it after tree-shaking / AOT
Future<void> _firebaseBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp(); // the isolate is fresh — initialize again
  // Do only isolate-safe work: badge counts, local DB writes, logging.
}

void main() {
  FirebaseMessaging.onBackgroundMessage(_firebaseBackgroundHandler);
  runApp(const App());
}
```

Do not navigate here and do not touch a `BuildContext` — there isn't one. Navigation happens only on
*tap*, via `onMessageOpenedApp` / `getInitialMessage`.

## 4. Foreground display with local notifications

FCM does **not** show a system banner while the app is foregrounded — you render it yourself with
`flutter_local_notifications`, which also gives you tap callbacks for notifications you raise locally.

```dart
final _local = FlutterLocalNotificationsPlugin();

Future<void> initLocal() async {
  const channel = AndroidNotificationChannel(
    'high_importance', 'Alerts', importance: Importance.high,
  );
  await _local
      .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
      ?.createNotificationChannel(channel);

  await _local.initialize(
    const InitializationSettings(
      android: AndroidInitializationSettings('@mipmap/ic_launcher'),
      iOS: DarwinInitializationSettings(),
    ),
    onDidReceiveNotificationResponse: (resp) {
      if (resp.payload != null) _routePayload(jsonDecode(resp.payload!));
    },
  );
}

FirebaseMessaging.onMessage.listen((m) {
  final n = m.notification;
  if (n == null) return;
  _local.show(
    n.hashCode, n.title, n.body,
    const NotificationDetails(
      android: AndroidNotificationDetails('high_importance', 'Alerts',
          importance: Importance.high, priority: Priority.high),
    ),
    payload: jsonEncode(m.data), // carry the routing data through the tap
  );
});
```

Put routing info in `message.data` (your own keys), not in the `notification` block — `data` is
delivered intact in every state; the `notification` block is consumed by the OS.

## 6. Capture links with app_links

```dart
final _appLinks = AppLinks();

Future<void> initLinks(PendingIntents pending) async {
  final initial = await _appLinks.getInitialLink(); // cold start
  if (initial != null) pending.seedInitial(initial);
  _appLinks.uriLinkStream.listen(pending.push);     // warm
}
```

Platform config is mandatory and silent when wrong:
- **Android App Links** — `<intent-filter android:autoVerify="true">` plus a hosted
  `/.well-known/assetlinks.json` with your SHA-256 signing fingerprints.
- **iOS Universal Links** — `Associated Domains` capability (`applinks:your.domain`) plus a hosted
  `/.well-known/apple-app-site-association` (JSON, **no** `.json` extension, served as `application/json`).
- **Custom scheme** — declare the scheme in `AndroidManifest.xml` and `Info.plist`. Schemes are
  spoofable; never trust a custom-scheme link for auth or to grant access.

