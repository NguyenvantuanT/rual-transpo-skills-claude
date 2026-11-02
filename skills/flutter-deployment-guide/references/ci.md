# CI/CD

# 10. Tích hợp CI/CD (tóm tắt)

Skill này không cover CI/CD chi tiết, nhưng outline để tham khảo:

## 10.1 GitHub Actions (cơ bản)

```yaml
# .github/workflows/release.yml
name: Release
on:
  push:
    tags: ['v*']

jobs:
  android:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - uses: subosito/flutter-action@v2
        with:
          flutter-version: '3.44.0'
          channel: stable
      - run: flutter pub get
      - run: flutter test
      - name: Build AAB
        env:
          GOOGLE_API_KEY_PROD: ${{ secrets.GOOGLE_API_KEY_PROD }}
        run: flutter build appbundle --release --flavor prod -t lib/main_prod.dart
      - uses: r0adkll/upload-google-play@v1
        with:
          serviceAccountJsonPlainText: ${{ secrets.PLAY_SERVICE_ACCOUNT }}
          packageName: com.acme.app
          releaseFiles: build/app/outputs/bundle/prodRelease/app-prod-release.aab
          track: production

  ios:
    runs-on: macos-latest
    steps:
      - uses: actions/checkout@v4
      - uses: subosito/flutter-action@v2
        with:
          flutter-version: '3.44.0'
      - run: flutter pub get
      - run: cd ios && pod install
      - name: Build IPA
        run: flutter build ipa --release --flavor prod -t lib/main_prod.dart
      - uses: apple-actions/upload-testflight-build@v1
        with:
          apple-id: ${{ secrets.APPLE_ID }}
          app-specific-password: ${{ secrets.APP_SPECIFIC_PASSWORD }}
          team-id: ${{ secrets.APPLE_TEAM_ID }}
          ipa-path: build/ios/ipa/prod.ipa
```

## 10.2 Codemagic / Bitrise / Fastlane

Tương tự, dùng environment variables để inject secret. Tham khảo:
- Codemagic: https://docs.codemagic.io/flutter-configuration/flutter-projects/
- Fastlane: https://docs.fastlane.tools/

---

