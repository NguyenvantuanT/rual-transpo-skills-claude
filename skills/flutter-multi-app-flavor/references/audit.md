# Audit nhanh project multi-app + script xcodeproj

## 8. Cách detect nhanh khi audit 1 project multi-app có sẵn

```bash
# 1. Đếm build configuration thực có trong project.pbxproj
grep -c "isa = XCBuildConfiguration;" ios/Runner.xcodeproj/project.pbxproj

# 2. Liệt kê build configuration mà từng scheme yêu cầu
for f in ios/Runner.xcodeproj/xcshareddata/xcschemes/*.xcscheme; do
  echo "== $f =="; grep -o 'buildConfiguration = "[^"]*"' "$f" | sort -u
done
# → đối chiếu mỗi config này có thực sự tồn tại trong project.pbxproj không (bước 1)

# 3. Check display name có hardcode không (dấu hiệu: không thấy $(...))
grep -A1 "CFBundleDisplayName" ios/Runner/Info.plist

# 4. Check bundle ID có unique theo cả 2 trục không
grep "PRODUCT_BUNDLE_IDENTIFIER" ios/Runner.xcodeproj/project.pbxproj | sort -u

# 5. Check icon asset catalog có tách riêng theo app không
find ios/Runner -iname "*.xcassets" -maxdepth 1

# 6. Android — check flavorDimensions có đủ 2 trục không
grep -A3 "flavorDimensions" android/app/build.gradle.kts

# 7. Check Android manifest label có thực sự wire vào resValue không (xem §4.4)
grep "android:label" android/app/src/main/AndroidManifest.xml

# 8. Check icon source set Android có tách theo App không, hay chỉ tách theo Env (xem §4.5)
find android/app/src -maxdepth 1 -type d

# 9. Check page/route class trùng tên giữa các router (xem §4.3) — liệt kê tên class @RoutePage
grep -rhoE '^class \w+Page' lib/src/pages lib/router 2>/dev/null | sort | uniq -d

# 10. Check mọi flavor App đều tự khai applicationId riêng, không flavor nào ăn ké defaultConfig (xem §4.8)
grep -A 3 'create("' android/app/build.gradle.kts

# 11. Check không còn file nào import thẳng .gr.dart ngoài chính router.dart (xem §4.9)
grep -rln "app_router.gr.dart'" lib/

# 12. Check scheme nào trỏ config trơn (không mang flavor suffix) ở action khác TestAction (xem §4.10)
for f in ios/Runner.xcodeproj/xcshareddata/xcschemes/*.xcscheme; do
  echo "== $(basename "$f") =="
  grep -E '(Launch|Profile|Analyze|Archive)Action' -A1 "$f" | grep -oE 'buildConfiguration = "[^"]+"'
done
```

Nếu bước 2 phát hiện scheme trỏ config không tồn tại ở bước 1 → nhánh đó **build sẽ lỗi ngay khi chọn scheme**, ưu tiên fix trước khi báo "đã xong multi-app setup". Script gộp đủ cho scheme mồ côi (§4.1) và naming drift (§4.2) nằm ngay trong 2 mục đó — chạy riêng khi audit sâu hơn là đủ, không cần lặp lại ở đây.

### 8.1 Script mẫu — thêm build configuration mới cho 1 flavor bằng gem `xcodeproj` (an toàn hơn sửa `project.pbxproj` tay)

Dùng khi cần thêm flavor mới ở tầng iOS (§2.1, §4.10) — sửa tay file `project.pbxproj` rất dễ hỏng cấu trúc tham chiếu chéo ID. Dùng gem `xcodeproj` qua system Ruby — trên macOS, Ruby cài qua Homebrew thường KHÔNG có gem này, phải dùng `/usr/bin/ruby` hệ thống, nơi CocoaPods đã cài sẵn gem này làm dependency:

```ruby
require 'xcodeproj'

project = Xcodeproj::Project.open('ios/Runner.xcodeproj')
flavor = 'user'          # đổi theo flavor thật đang thêm
bundle_id = 'com.acme.app.user'

def make_xcconfig_ref(project, path, name)
  ref = project.new(Xcodeproj::Project::Object::PBXFileReference)
  ref.include_in_index = '1'
  ref.last_known_file_type = 'text.xcconfig'
  ref.name = name
  ref.path = path
  ref.source_tree = '<group>'
  ref
end

def duplicate_config(project, config, new_name, base_configuration_reference: :same, bundle_id: nil)
  new_config = project.new(Xcodeproj::Project::Object::XCBuildConfiguration)
  new_config.name = new_name
  new_config.build_settings = config.build_settings.dup
  new_config.base_configuration_reference =
    base_configuration_reference == :same ? config.base_configuration_reference : base_configuration_reference
  new_config.build_settings['PRODUCT_BUNDLE_IDENTIFIER'] = bundle_id if bundle_id
  new_config
end

# 2 file .xcconfig mới (Debug-<flavor>.xcconfig / Release-<flavor>.xcconfig phải tự tạo trước ở ios/Flutter/)
flutter_group = project.main_group['Flutter']
debug_ref = make_xcconfig_ref(project, "Flutter/Debug-#{flavor}.xcconfig", "Debug-#{flavor}.xcconfig")
release_ref = make_xcconfig_ref(project, "Flutter/Release-#{flavor}.xcconfig", "Release-#{flavor}.xcconfig")
flutter_group.children << debug_ref
flutter_group.children << release_ref

# Project-level (không baseConfigurationReference)
proj_list = project.root_object.build_configuration_list
%w[Debug Release Profile].each do |base|
  cfg = proj_list.build_configurations.find { |c| c.name == base }
  proj_list.build_configurations << duplicate_config(project, cfg, "#{base}-#{flavor}")
end

# Runner target (baseConfigurationReference → xcconfig mới, set PRODUCT_BUNDLE_IDENTIFIER)
runner = project.targets.find { |t| t.name == 'Runner' }
runner_list = runner.build_configuration_list
{ 'Debug' => debug_ref, 'Release' => release_ref, 'Profile' => release_ref }.each do |base, ref|
  cfg = runner_list.build_configurations.find { |c| c.name == base }
  runner_list.build_configurations << duplicate_config(project, cfg, "#{base}-#{flavor}", base_configuration_reference: ref, bundle_id: bundle_id)
end

project.save
puts 'Done.'
```

Sau khi chạy: (1) tạo nội dung thật cho 2 file `ios/Flutter/Debug-<flavor>.xcconfig`/`Release-<flavor>.xcconfig` (xem §2.3), (2) sửa scheme trỏ đúng config mới (§2.2, §4.10), (3) `pod install` lại (§2.5), (4) verify bằng `xcodebuild -list -project ios/Runner.xcodeproj` — Build Configurations/Schemes phải liệt kê đủ tên mới.

