# Android: flavor dimension, source set, build command

## 3. Android — 2 flavor dimension

Khác biệt quan trọng với iOS: Android hỗ trợ **flavor dimension gốc** (native), không cần build-configuration-matrix thủ công.

```kotlin
// android/app/build.gradle.kts
android {
    namespace = "com.acme.app"

    flavorDimensions += listOf("app", "env")

    productFlavors {
        // Trục App — đổi tên "admin"/"user" theo tên thật của dự án
        create("admin") {
            dimension = "app"
            applicationId = "com.acme.admin"
            resValue("string", "app_name", "Admin")
        }
        create("user") {
            dimension = "app"
            applicationId = "com.acme.user"
            resValue("string", "app_name", "User")
        }

        // Trục Env — applicationIdSuffix cộng dồn với app ở trên
        create("dev") {
            dimension = "env"
            applicationIdSuffix = ".dev"
            versionNameSuffix = "-dev"
        }
        create("stg") {
            dimension = "env"
            applicationIdSuffix = ".stg"
            versionNameSuffix = "-stg"
        }
        create("prod") {
            dimension = "env"
            // prod không suffix
        }
    }
}
```

Gradle tự sinh **6 build variant**: `adminDevDebug`, `adminStgDebug`, `adminProdRelease`, `userDevDebug`, … applicationId tự ghép đúng cả 2 trục (`com.acme.admin.dev`, `com.acme.user.stg`, …) — không cần tự tay ghép chuỗi.

### 3.1 Icon + tên riêng theo App (source set)

```
android/app/src/
├── admin/
│   ├── res/mipmap-*/ic_launcher.png     ← icon app1 (vd Admin)
│   └── res/values/strings.xml           ← app_name="Admin" (nếu không dùng resValue ở trên)
└── user/
    ├── res/mipmap-*/ic_launcher.png     ← icon app2 (vd User)
    └── res/values/strings.xml
```

AGP tự nhận source set trùng tên flavor — không cần khai báo gì thêm trong `build.gradle.kts`.

### 3.2 Build command

```bash
flutter build apk --release --flavor adminProd -t lib/main_admin.dart
flutter build apk --release --flavor userProd -t lib/main_user.dart

# Run local
flutter run --flavor adminDev -t lib/main_admin.dart
```

> Flutter CLI ghép tên flavor 2 dimension thành 1 chuỗi camelCase (`adminDev`, không phải `admin-dev` hay `admin,dev`) — đây là quy tắc cứng của Flutter tooling, không tự đặt tên khác được.

### 3.3 Lựa chọn thay thế — gộp App+Env vào 1 dimension duy nhất

Cách ở mục 3 (2 dimension `app` × `env`) là mặc định nên dùng. Có 1 cách khác vẫn gặp trong thực tế: gộp cả 2 trục vào CHUNG 1 dimension, đặt tên flavor là chuỗi ghép sẵn:

```kotlin
android {
    flavorDimensions += listOf("default")

    productFlavors {
        create("adminDev") { dimension = "default"; applicationId = "com.acme.admin.dev" }
        create("adminStg") { dimension = "default"; applicationId = "com.acme.admin.stg" }
        create("adminProd") { dimension = "default"; applicationId = "com.acme.admin" }
        create("userDev") { dimension = "default"; applicationId = "com.acme.user.dev" }
        create("userStg") { dimension = "default"; applicationId = "com.acme.user.stg" }
        create("userProd") { dimension = "default"; applicationId = "com.acme.user" }
    }
}
```

| | 2 dimension (`app` × `env`) | 1 dimension gộp sẵn |
|---|---|---|
| `applicationId` | Gradle tự ghép 2 trục | Phải tự gõ đủ cho từng flavor — dễ gõ sai hoặc bỏ sót 1 nhánh |
| Thêm 1 App mới | Thêm 1 `create()` ở dimension `app`, Gradle tự nhân với mọi env có sẵn | Phải tự thêm M flavor mới (1 cho mỗi env) — dễ quên 1 nhánh, không có gì nhắc |
| Thêm 1 Env mới | Thêm 1 `create()` ở dimension `env`, tự nhân với mọi app | Phải tự thêm N flavor mới (1 cho mỗi app) — dễ quên 1 nhánh |
| Khi nào chọn | Mặc định — Gradle tự enforce đủ tổ hợp, không thể "quên" 1 ô trong ma trận | Chỉ khi có tổ hợp (App,Env) cần setting đặc thù không fit gọn vào 2 dimension |

> Cách gộp 1 dimension không có cơ chế nào cảnh báo "bạn đang thiếu `userStg`" — thiếu là thiếu im lặng, chỉ lộ ra khi ai đó chọn đúng flavor đó. Ưu tiên 2 dimension trừ khi có lý do cụ thể; nếu buộc phải dùng 1 dimension gộp, sau khi tạo phải tự đếm lại N×M flavor đã đủ chưa (đừng tin vào cảm giác "chắc đủ rồi").

