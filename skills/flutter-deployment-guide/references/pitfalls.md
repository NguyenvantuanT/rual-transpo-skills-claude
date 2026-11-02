# Anti-patterns + bug thường gặp

# 8. Anti-patterns — tuyệt đối tránh

## 8.1 Bảo mật

| ❌ Anti-pattern | ✅ Cách đúng |
|---|---|
| Hard-code API key trong Dart code | Qua `.env.<env>` + AppConfig |
| Hard-code secret trong AppDelegate.swift | Qua `Info.plist` + `$(GOOGLE_MAPS_API_KEY)` |
| Commit `.env.prod` chứa key thật vào git | `.gitignore` + inject qua CI secret |
| Để `NSAllowsArbitraryLoads=true` cho prod | Bật chỉ cho dev (qua flavor config) |
| Để `usesCleartextTraffic=true` cho prod | Qua `network_security_config.xml` chỉ allow internal |

## 8.2 Signing

| ❌ Anti-pattern | ✅ Cách đúng |
|---|---|
| Release Android ký bằng debug keystore | Tạo keystore riêng, lưu key.properties ngoài git |
| iOS archive dùng `iPhone Developer` identity | Phải là `iPhone Distribution` |
| Không backup keystore → mất → không update được | Backup ở 2+ nơi (vault + local encrypted) |
| Hard-code keystore password trong `build.gradle.kts` | Qua `key.properties` (gitignored) |

## 8.3 Bundle / Application ID

| ❌ Anti-pattern | ✅ Cách đúng |
|---|---|
| 3 flavor dùng chung bundle/application ID | Mỗi flavor suffix riêng (`.dev` / `.stg` / `.prod`) |
| Production có suffix (vd `.prod`) | Production KHÔNG suffix (giữ ID gốc cho store) |
| Copy-paste AndroidManifest từ project khác không review | Đọc từng dòng, đảm bảo `android:label` reference `@string/app_name` |

## 8.4 Env handling

| ❌ Anti-pattern | ✅ Cách đúng |
|---|---|
| Hard-code `.env.dev` trong `build.gradle.kts` | Đọc qua `System.getenv()` hoặc `local.properties` |
| `dotenv.env['KEY']` rải rác trong code | Qua `AppConfig.KEY` (singleton, mock được) |
| Bundle `.env.prod` vào app assets | Inject qua `--dart-define` lúc build |
| Để tên file `.env.dev` / `.env.stg` cứng trong main_*.dart | OK (đây là convention, mỗi entry 1 file) |

## 8.5 Permissions

| ❌ Anti-pattern | ✅ Cách đúng |
|---|---|
| `INTERNET` chỉ trong `debug/AndroidManifest.xml` | Phải ở `main/AndroidManifest.xml` |
| Khai báo permission không dùng → App Store reject | Chỉ khai báo cái code thực sự gọi |
| Privacy key message trống / chung chung | Message cụ thể, giải thích rõ tại sao cần |

## 8.6 Build / release

| ❌ Anti-pattern | ✅ Cách đúng |
|---|---|
| Upload APK lên Play Store | Phải upload AAB |
| Quên bump versionCode → Play Store reject | `versionCode++` mỗi release |
| Bật Proguard nhưng thiếu rules → crash khi chạy release | Test kỹ trên release APK trước khi submit |
| Inherit `Debug*` build config cho `Profile*` | Tạo Profile config riêng (cho Flutter profiling) |

---

# 9. Bug thường gặp — từ review thực tế

Danh sách bug phát hiện khi review 1 Flutter multi-flavor project thật. Mỗi bug đều có file path + cách fix.

| # | Bug | File | Mức độ | Fix |
|---|---|---|---|---|
| 1 | Release APK mất `INTERNET` permission | `android/app/src/main/AndroidManifest.xml` | 🔴 Critical | Move INTERNET từ `debug/` lên `main/` |
| 2 | 3 Android flavor dùng chung `applicationId` | `android/app/build.gradle.kts` | 🟡 Medium | Thêm `applicationIdSuffix` cho dev/stg |
| 3 | `android:label` literal không pick `@string/app_name` | `android/app/src/main/AndroidManifest.xml` | 🟡 Medium | Đổi `android:label="<package_name>"` → `android:label="@string/app_name"` |
| 4 | Gradle hard-code `../.env.dev` | `android/app/build.gradle.kts:11` | 🔴 Critical | Đổi sang `System.getenv("GOOGLE_API_KEY_...")` |
| 5 | iOS staging/production scheme thiếu `XCBuildConfiguration` | `ios/Runner.xcodeproj/project.pbxproj` | 🔴 Critical | Tạo config cho `Debug-stg` / `Release-stg` / `Debug-prod` / `Release-prod` |
| 6 | Release Android ký bằng debug keystore | `android/app/build.gradle.kts:88-93` | 🔴 Critical | Tạo keystore riêng + signing config |
| 7 | iOS `APP_DISPLAY_NAME` copy-paste sai (app thứ 2 vẫn ghi tên app thứ nhất) | `project.pbxproj:781,888,995` | 🟢 Minor | Sửa label cho từng config |
| 8 | `flutter_launcher_icons` install nhưng không config | `pubspec.yaml` | 🟢 Minor | Thêm `flutter_icons:` block |
| 9 | `key.properties` 0 byte (placeholder) | `android/key.properties` | 🟡 Medium | Thêm credential thật (gitignored) |
| 10 | Podfile có hack lớn cho `PODS_CONFIGURATION_BUILD_DIR` | `ios/Podfile` | 🟡 Medium | Khi nào AGP / CocoaPods đổi template, hack này có thể vỡ. Có comment TODO trong file |
| 11 | iOS Maps API key hard-code trong AppDelegate.swift | `ios/Runner/AppDelegate.swift` | 🟡 Medium | Đọc từ `Bundle.main` (qua `Info.plist` + xcconfig) |
| 12 | Không có proguard rules | `android/app/proguard-rules.pro` | 🟡 Medium | Tạo file với rules Flutter + SDK |
| 13 | iOS `NSLocationWhenInUseUsageDescription` OK nhưng thiếu privacy key khác | `ios/Runner/Info.plist` | 🟡 Medium | Kiểm tra từng permission plugin dùng |
| 14 | Android dev/stg/prod cùng share launcher icon base | `android/app/src/main/res/mipmap-*/` | 🟢 Cosmetic | Override qua `app/src/<flavor>/res/mipmap-*/` |
| 15 | Không có gitignore cho `.env.*` | `.gitignore` | 🔴 Critical | Thêm `.env.dev`, `.env.stg`, `.env.prod` + `!.env.example` |

## 9.1 Cách detect nhanh khi review project khác

```bash
# 1. Check INTERNET permission có ở main không
grep -A1 "INTERNET" android/app/src/*/AndroidManifest.xml

# 2. Check applicationId có unique không
grep "applicationId" android/app/build.gradle.kts

# 3. Check signing config có dùng debug keystore không
grep -A3 "release {" android/app/build.gradle.kts

# 4. Check .env có bị commit không
git ls-files | grep -E "\.env\.(dev|stg|prod)$"

# 5. Check Info.plist có đầy đủ privacy key không
grep -E "UsageDescription" ios/Runner/Info.plist | wc -l
# (số này phải ≥ số permission plugin thực sự dùng)

# 6. Check Podfile có hack lạ không
grep -c "PODS_CONFIGURATION_BUILD_DIR\|post_install" ios/Podfile

# 7. Check Flutter đã pin version chưa
cat .fvmrc
```

---

