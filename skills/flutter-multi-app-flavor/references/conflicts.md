# Conflict thường gặp + lệnh detect

## 4. Conflict thường gặp khi build N app từ 1 codebase

Nhóm lỗi này khác với lỗi build thông thường: code Dart/Kotlin/Swift từng dòng đều "trông đúng", nhưng 2 nhánh (App1, App2) vô tình đụng nhau ở tầng cấu hình hoặc generated code — vì vậy compiler không báo, chỉ lộ ra khi build/cài đúng tổ hợp bị conflict, thường là muộn.

### 4.1 Scheme "mồ côi" — trỏ build configuration không tồn tại

Lỗi hay gặp nhất: tạo scheme cho staging/production bằng cách duplicate scheme dev, Xcode giữ tên `buildConfiguration` bên trong theo đúng convention (`Debug-stgAdmin`) — nhưng không ai thực sự tạo build configuration đó trong `project.pbxproj` (chỉ `Debug-devAdmin` tồn tại thật). Chọn scheme đó sẽ báo lỗi "cannot find configuration" ngay lập tức.

```bash
# 1. Config THẬT SỰ tồn tại trong project.pbxproj
grep -oE '(Debug|Release|Profile)-[A-Za-z0-9]+' ios/Runner.xcodeproj/project.pbxproj \
  | sort -u > /tmp/real_configs.txt

# 2. Config mà TỪNG scheme yêu cầu
for f in ios/Runner.xcodeproj/xcshareddata/xcschemes/*.xcscheme; do
  grep -oE 'buildConfiguration = "[^"]+"' "$f" | sed 's/buildConfiguration = "//;s/"//'
done | sort -u > /tmp/scheme_configs.txt

# 3. Config nào scheme cần nhưng KHÔNG tồn tại thật → scheme mồ côi
comm -23 /tmp/scheme_configs.txt /tmp/real_configs.txt
```

Output không rỗng → có scheme mồ côi. Fix trước khi báo "đã xong multi-app setup", vì đây luôn lộ ra đúng lúc gấp nhất (ai đó chọn scheme release để archive).

### 4.2 Naming drift giữa tên file scheme và buildConfiguration bên trong

Lỗi tinh vi hơn §4.1: file scheme đặt tên đúng convention (`stgUser.xcscheme`) nhưng bên trong lại trỏ `Debug-stgAdmin` (copy-paste từ scheme khác, quên sửa) — hoặc trỏ tên cũ còn sót lại từ lần đổi tên app trước đó (`Debug-stgMerchant` dù mọi tầng khác đã đổi `Merchant` → `User`, đúng case ở Nguyên tắc cốt lõi #2). Đây là case thật cần detect thủ công vì cả 2 tên đều "hợp lệ về mặt cú pháp":

```bash
for f in ios/Runner.xcodeproj/xcshareddata/xcschemes/*.xcscheme; do
  scheme_name=$(basename "$f" .xcscheme)
  cfg=$(grep -oE 'buildConfiguration = "[^"]+"' "$f" | head -1)
  echo "$scheme_name  →  $cfg"
done
```

Đọc kết quả bằng mắt: phần `<App>` rút ra từ tên scheme (`stgUser` → `User`) phải xuất hiện y hệt trong `buildConfiguration` (`Debug-stgUser`) — KHÔNG phải tên app khác (`Debug-stgAdmin`) hay tên app cũ (`Debug-stgMerchant`).

### 4.3 auto_route — page/route class trùng tên giữa 2 router (CHỈ khi cố tình gộp chung 1 file)

Rủi ro này chỉ tồn tại nếu chọn gộp mọi `@AutoRouterConfig` vào CHUNG 1 file `part` (xem §1.3 — đây là lựa chọn, không phải bắt buộc: **đã verify thật** `build_runner`/`auto_route` generate `part` độc lập theo từng file, tách router theo app thành file riêng loại bỏ hẳn rủi ro này). Nếu vẫn chọn gộp chung 1 file: `build_runner` sinh tên route class dựa theo tên class page (`HomePage` → `HomeRoute`). Nếu Admin và User đều có 1 page tên `HomePage` (2 file khác nhau, tình cờ trùng tên class) → sinh ra 2 route cùng tên `HomeRoute` trong CÙNG 1 file generated → build_runner conflict thật — hoặc nếu qua được, route của app này có thể trỏ nhầm sang page của app kia. Rule khi gộp chung file: prefix tên class page theo app ngay từ đầu (`HomeAdminPage` / `HomeUserPage`), không dựa vào việc "để ở thư mục khác nhau là đủ" — auto_route không quan tâm thư mục, chỉ quan tâm tên class trong CÙNG 1 file generated.

### 4.4 `resValue` / biến khai báo nhưng không wire vào nơi tiêu thụ thật

`build.gradle.kts` khai báo `resValue("string", "app_name", "Admin")` cho từng flavor — nhưng nếu `AndroidManifest.xml` vẫn hardcode `android:label="my_app"` thay vì `android:label="@string/app_name"`, khai báo trên coi như vô nghĩa: mọi flavor build ra vẫn hiện chung 1 tên. Đây là lỗi **âm thầm nhất** trong nhóm này — Gradle build pass, APK cài được, chỉ sai ở chỗ ít ai để ý kiểm tra (tên hiển thị trên home screen).

```bash
grep "android:label" android/app/src/main/AndroidManifest.xml
# Kỳ vọng: android:label="@string/app_name"     (biến — đổi theo flavor)
# Dấu hiệu lỗi: android:label="<chuỗi cứng>"    (không đổi theo flavor dù build.gradle.kts đã resValue)
```

Tương tự phía iOS: xem lại §2.3 — `CFBundleDisplayName` phải là `$(APP_DISPLAY_NAME)`, không hardcode.

### 4.5 Icon/asset chỉ tách theo Env, quên tách theo App

Source set Android hay bị tổ chức theo Env trước (`android/app/src/dev/res/mipmap-*`, `.../stg/...`, `.../prod/...`) vì đó là bước tự nhiên khi mới thêm multi-env — nhưng khi thêm trục App phải tách theo App nữa (icon thường khác App nhiều hơn khác Env). Nếu source set vẫn chỉ có `dev/`, `stg/`, `prod/` mà không có `admin/`, `user/` (hoặc `adminDev/`, `userDev/`, ...) thì 2 app đang share chung icon — vi phạm Nguyên tắc cốt lõi #5. Không có build error nào báo lỗi này, chỉ lộ ra khi cài cả 2 app lên máy thật và thấy icon giống hệt nhau.

```bash
find android/app/src -maxdepth 1 -type d
# Kỳ vọng thấy thư mục đặt tên theo App (admin/, user/) — riêng hoặc kết hợp với env
# Dấu hiệu thiếu: chỉ thấy dev/, stg/, prod/ — không thư mục nào mang tên app
```

### 4.6 CocoaPods — quên `pod install` lại sau khi thêm build configuration mới

Đã cover chi tiết ở §2.5 — không lặp lại ở đây. Chỉ nhắc: build configuration mới (`Debug-user`) thêm vào `project.pbxproj` KHÔNG tự động có `Pods-Runner.debug-user.xcconfig` tương ứng — phải chạy `pod install` lại để CocoaPods generate. Nếu build iOS lỗi linker "file not found" ở 1 pod nào đó khi build config có tên flavor mới thêm nhưng chạy OK ở config gốc → quay lại §2.5 kiểm tra đã `pod install` lại chưa, KHÔNG áp patch `PODS_CONFIGURATION_BUILD_DIR` (đã kiểm chứng là không cần thiết trong Podfile template hiện đại).

### 4.7 Bundle ID không phân biệt theo Env — chỉ chấp nhận nếu là quyết định có chủ đích

Nguyên tắc cốt lõi #4 yêu cầu bundle ID unique theo cả (App, Env). Có 1 ngoại lệ hợp lệ: nếu team **cố ý** không cần dev/stg/prod cài song song trên cùng máy (mỗi lúc chỉ cài 1 bản, phân biệt qua display name + debug banner), dùng chung bundle ID cho mọi Env của 1 App là chấp nhận được — đổi lại đơn giản hoá quản lý provisioning profile / Play Console listing. Khác biệt giữa "quyết định có chủ đích" và "thiếu sót": quyết định có chủ đích phải ghi rõ lý do trong README/CHANGELOG; thiếu sót là im lặng, không ai note lại, và thường đi kèm với các dấu hiệu ở §4.1 (scheme mồ côi) — nếu thấy cả 2 dấu hiệu cùng lúc, nhiều khả năng là thiếu sót chứ không phải chủ đích.

### 4.8 `applicationId` khai báo bất đối xứng giữa các flavor App

Lỗi thường gặp trong thực tế: `productFlavors` khai 2 flavor App nhưng chỉ 1 flavor dùng `applicationIdSuffix`, flavor còn lại không khai gì cả — rơi về đúng `defaultConfig.applicationId` gốc:

```kotlin
// SAI — bất đối xứng, "user" không có identity riêng, chỉ là "cái còn lại sau khi trừ admin"
productFlavors {
    create("user") {
        dimension = "app"
        resValue("string", "app_name", "User")
        // không có applicationId / applicationIdSuffix → applicationId = defaultConfig gốc
    }
    create("admin") {
        dimension = "app"
        applicationIdSuffix = ".admin"
        resValue("string", "app_name", "Admin")
    }
}
```

Build vẫn pass, 2 APK vẫn cài song song được (2 applicationId cuối cùng vẫn khác nhau) — nên lỗi này **không lộ ra qua build error**, chỉ lộ ra khi đọc kỹ hoặc khi thêm trục Env: lúc đó flavor "user" không có gì để cộng dồn suffix vào cho rõ ràng, dễ nhầm lẫn với "chưa áp dụng flavor nào". Rule: mọi flavor ở dimension `app` phải tự khai `applicationId` đầy đủ, tường minh, đối xứng với nhau — không để 1 flavor "ăn ké" giá trị gốc của `defaultConfig`:

```kotlin
// ĐÚNG — đối xứng, mỗi app có applicationId riêng tường minh
productFlavors {
    create("user") {
        dimension = "app"
        applicationId = "com.acme.app.user"
        resValue("string", "app_name", "User")
    }
    create("admin") {
        dimension = "app"
        applicationId = "com.acme.app.admin"
        resValue("string", "app_name", "Admin")
    }
}
```

`namespace` (dùng cho R class / package Kotlin) và `defaultConfig.applicationId` gốc không cần đổi — chỉ cần đảm bảo MỌI flavor ở dimension `app` đều tự khai `applicationId` của riêng nó, không flavor nào im lặng dùng ké giá trị `defaultConfig`.

```bash
grep -A 3 'create("' android/app/build.gradle.kts
# Kỳ vọng: mọi flavor dimension "app" đều có dòng applicationId = "..." riêng
# Dấu hiệu lỗi: có flavor không xuất hiện applicationId lẫn applicationIdSuffix nào cả
```

### 4.9 Import trực tiếp file `.gr.dart` — vỡ khi router đổi cấu trúc file

Nhiều page/VM quen import thẳng `app_router.gr.dart` (file generated, `part of` router.dart) thay vì import `app_router.dart` (file khai báo `part` + export mọi route class ra ngoài). Việc này thường vẫn chạy được lúc đầu (Dart cho phép import 1 file `part` trực tiếp trong nhiều trường hợp), nhưng dễ vỡ khi cấu trúc router đổi — vd đổi tên file, gộp/tách router theo App (§1.3), hoặc build_runner regenerate với cấu trúc khác — vì các file đã import thẳng `.gr.dart` giờ trỏ tới nội dung khác hoặc file không còn tồn tại đúng chỗ cũ. Fix: luôn import `app_router.dart` (file khai `part`, là entry point ổn định), không import `*.gr.dart` trực tiếp ở bất kỳ đâu ngoài chính file khai `part` nó.

```bash
grep -rln "app_router.gr.dart'" lib/
# Kỳ vọng: không có kết quả nào ngoài chính app_router.dart
# Dấu hiệu lỗi: page/VM khác import thẳng .gr.dart — phải sửa lại thành import app_router.dart
```

### 4.10 Scheme trỏ config CÓ THẬT nhưng thiếu flavor suffix — khác hẳn scheme mồ côi (§4.1)

Là lỗi nguy hiểm nhất trong nhóm iOS vì KHÔNG giống 2 case đã biết: không phải config không tồn tại (§4.1), không phải trỏ nhầm config app khác (§4.2) — mà là scheme trỏ tới config **có thật, hợp lệ, Xcode build được qua IDE** (`Debug`/`Release`/`Profile` trơn, chưa từng gắn flavor nào), nhưng tên config đó không mang flavor suffix.

Chuỗi sự kiện điển hình khi gặp case này: tạo `<App2>.xcscheme` (copy cấu trúc từ `Runner.xcscheme` mặc định) → scheme trỏ `Debug`/`Release`/`Profile` → build qua Xcode UI vẫn chạy bình thường (vì đây là config thật) → nhưng `flutter run --flavor <app2>` báo lỗi:

```
Error: You must specify a --flavor option to select one of the available schemes.
```

Sau khi sửa để scheme trỏ đúng `Debug-<app2>` (nhưng lúc đó config `Debug-<app2>` **chưa tồn tại** trong `project.pbxproj`), lỗi đổi thành:

```
Flutter expects a build configuration named Debug-<App2> or similar.
```

Root cause: Flutter CLI xác định flavor bằng cách tự parse TÊN của build configuration mà scheme's LaunchAction đang dùng — tìm chuỗi khớp pattern `<Debug|Release|Profile>-<flavor>`. Config `Debug` trơn không match pattern này dù nó tồn tại thật và hợp lệ với Xcode. Fix đầy đủ, đúng thứ tự — sai thứ tự sẽ chỉ đổi từ lỗi này sang lỗi khác chứ không hết lỗi:

1. Tạo đủ `Debug-<flavor>`/`Release-<flavor>`/`Profile-<flavor>` ở CẢ 3 tầng XCConfigurationList (project, Runner target, RunnerTests target) — xem §2.1.
2. Tạo `.xcconfig` riêng cho flavor (`ios/Flutter/Debug-<flavor>.xcconfig`, …) set `FLUTTER_TARGET`/`APP_DISPLAY_NAME` — xem §2.3.
3. Sửa scheme để LaunchAction/ProfileAction/AnalyzeAction/ArchiveAction trỏ đúng `Debug-<flavor>`/`Release-<flavor>`/`Profile-<flavor>` (KHÔNG để lại config trơn — chỉ `TestAction` được phép giữ `Debug` trơn, đây là convention chung, không ảnh hưởng flavor detection vì Flutter không đọc TestAction).
4. `pod install` lại để CocoaPods generate xcconfig tương ứng — xem §2.5.

Sửa project.pbxproj tay rất dễ hỏng cấu trúc tham chiếu chéo (ID) — dùng gem `xcodeproj` (Ruby) để thao tác an toàn thay vì sửa text thô, xem ví dụ script ở cuối §8.

```bash
# Detect: liệt kê scheme nào đang trỏ config KHÔNG mang flavor suffix (trơn Debug/Release/Profile)
# ở các action ngoài TestAction — dấu hiệu chắc chắn sẽ lỗi khi build bằng --flavor
for f in ios/Runner.xcodeproj/xcshareddata/xcschemes/*.xcscheme; do
  echo "== $(basename "$f") =="
  grep -E '(Launch|Profile|Analyze|Archive)Action' -A1 "$f" | grep -oE 'buildConfiguration = "[^"]+"'
done
# Kỳ vọng: mọi giá trị đều dạng "Debug-<flavor>"/"Release-<flavor>"/"Profile-<flavor>"
# Dấu hiệu lỗi: thấy "Debug"/"Release"/"Profile" trơn ở scheme KHÔNG phải Runner mặc định
```

