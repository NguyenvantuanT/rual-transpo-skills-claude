# Android configuration

# 5. Android configuration

## 5.1 AndroidManifest.xml template

```xml
<?xml version="1.0" encoding="utf-8"?>
<manifest xmlns:android="http://schemas.android.com/apk/res/android">

    <!-- Network — PHẢI ở main, không chỉ debug -->
    <uses-permission android:name="android.permission.INTERNET"/>

    <!-- Location -->
    <uses-permission android:name="android.permission.ACCESS_FINE_LOCATION"/>
    <uses-permission android:name="android.permission.ACCESS_COARSE_LOCATION"/>

    <!-- Camera -->
    <uses-permission android:name="android.permission.CAMERA"/>

    <!-- Photos / Storage -->
    <uses-permission android:name="android.permission.READ_EXTERNAL_STORAGE"
        android:maxSdkVersion="32"/>
    <uses-permission android:name="android.permission.READ_MEDIA_IMAGES"/>

    <!-- Notifications (Android 13+) -->
    <uses-permission android:name="android.permission.POST_NOTIFICATIONS"/>

    <application
        android:label="@string/app_name"
        android:name="${applicationName}"
        android:icon="@mipmap/ic_launcher"
        android:requestLegacyExternalStorage="false">

        <activity
            android:name=".MainActivity"
            android:exported="true"
            android:launchMode="singleTop"
            android:theme="@style/LaunchTheme"
            android:configChanges="orientation|keyboardHidden|keyboard|screenSize|smallestScreenSize|locale|layoutDirection|fontScale|screenLayout|density|uiMode"
            android:hardwareAccelerated="true"
            android:windowSoftInputMode="adjustResize">

            <meta-data
                android:name="io.flutter.embedding.android.NormalTheme"
                android:resource="@style/NormalTheme" />

            <intent-filter>
                <action android:name="android.intent.action.MAIN"/>
                <category android:name="android.intent.category.LAUNCHER"/>
            </intent-filter>
        </activity>

        <!-- Google Maps API key -->
        <meta-data
            android:name="com.google.android.geo.API_KEY"
            android:value="${GOOGLE_API_KEY}" />

        <!-- Disable Crashlytics tự động collect (set qua Firebase init) -->
        <meta-data
            android:name="firebase_crashlytics_collection_enabled"
            android:value="false" />
    </application>

    <queries>
        <intent>
            <action android:name="android.intent.action.PROCESS_TEXT"/>
            <data android:mimeType="text/plain"/>
        </intent>
    </queries>
</manifest>
```

> **Bug nghiêm trọng** (từ dự án thật): `INTERNET` permission chỉ trong `debug/` + `profile/` AndroidManifest → APK **release** không có quyền mạng, mọi Dio call đều fail. Luôn đặt INTERNET ở `main/`.

## 5.2 build.gradle.kts — signing

### key.properties (gitignored)

```properties
# android/key.properties — KHÔNG commit vào git
storeFile=/Users/<user>/keys/acme-release.jks
storePassword=your_store_password
keyAlias=acme
keyPassword=your_key_password
```

### build.gradle.kts

```kotlin
// android/app/build.gradle.kts
import java.util.Properties
import java.io.FileInputStream

val keystoreProperties = Properties().apply {
    val f = rootProject.file("key.properties")
    if (f.exists()) {
        load(FileInputStream(f))
    }
}

android {
    signingConfigs {
        create("release") {
            keyAlias = keystoreProperties["keyAlias"] as String?
            keyPassword = keystoreProperties["keyPassword"] as String?
            storeFile = (keystoreProperties["storeFile"] as String?)?.let { file(it) }
            storePassword = keystoreProperties["storePassword"] as String?
        }
    }

    buildTypes {
        release {
            signingConfig = signingConfigs.getByName("release")
            isMinifyEnabled = true
            isShrinkResources = true
            proguardFiles(
                getDefaultProguardFile("proguard-android-optimize.txt"),
                "proguard-rules.pro"
            )
        }
    }
}
```

### Tạo keystore

```bash
keytool -genkey -v \
  -keystore ~/keys/acme-release.jks \
  -keyalg RSA -keysize 2048 -validity 10000 \
  -alias acme
```

> ⚠️ **Mất keystore = mất app** (không thể update trên Play Store). Backup keystore ở 2 nơi (local + cloud encrypted vault).

## 5.3 Proguard / R8 rules

```pro
# android/app/proguard-rules.pro

# Flutter
-keep class io.flutter.app.** { *; }
-keep class io.flutter.plugin.** { *; }
-keep class io.flutter.util.** { *; }
-keep class io.flutter.view.** { *; }
-keep class io.flutter.** { *; }
-keep class io.flutter.plugins.** { *; }

# Firebase / backend SDK
-keep class com.google.firebase.** { *; }
-dontwarn com.google.firebase.**

# json_serializable
-keepattributes Signature
-keepattributes *Annotation*
-keep class com.google.gson.** { *; }

# App models (giữ tất cả class trong package models)
-keep class com.acme.app.models.** { *; }
```

## 5.4 Gradle / AGP version

```kotlin
// android/settings.gradle.kts
plugins {
    id("dev.flutter.flutter-plugin-loader") version "1.0.0"
    id("com.android.application") version "8.11.1" apply false
    id("org.jetbrains.kotlin.android") version "2.2.20" apply false
    id("com.google.devtools.ksp") version "2.2.20-2.0.4" apply false
}
```

```properties
# android/gradle.properties
android.useAndroidX=true
android.enableJetifier=false
org.gradle.jvmargs=-Xmx4g -XX:MaxMetaspaceSize=512m -Dfile.encoding=UTF-8
org.gradle.parallel=true
org.gradle.caching=true
```

---

