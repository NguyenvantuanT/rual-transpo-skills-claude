# ARCHITECTURE

Bản đồ cấp cao. Mọi đường dẫn trong backtick được `docs-check.sh` kiểm tra tồn tại — đổi tên file thì sửa ở đây.

## Layer (hướng phụ thuộc chỉ đi xuống)

```
pages/<app>/<feature>/   Page + VM + widgets/      ← được import mọi thứ bên dưới
components/<feature>/    widget dùng chung         ← không import pages/
services/<group>/        remote / local / ...      ← không import pages/, components/
models/  + models/enums/ data class + enum         ← không import pages/, components/, services/, base/
resources/ theme/ utils/ constants/ gen/ generated/
```

Hướng import được `check.sh` ép (rule `layer_*`).

## Domain

| Domain | Pages | Models | Services |
|---|---|---|---|
| <domain> | `lib/src/pages/<app>/<feature>/` | `lib/src/models/<x>_model.dart` | `lib/src/services/<group>/` |

## Entry points & DI

- Entry: `lib/app/main_<app>_<env>.dart`
- DI: `lib/src/utils/locator.dart`
- Router: `lib/router/app_router.dart`
