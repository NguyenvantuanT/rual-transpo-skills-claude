# ARCHITECTURE

Bản đồ cấp cao. Mọi đường dẫn trong backtick được `docs-check.sh` kiểm tra tồn tại — đổi tên file thì sửa ở đây.

## Layer (hướng phụ thuộc chỉ đi xuống)

```
<layer trên cùng — vd UI: page/screen + state>   ← được import mọi thứ bên dưới
<layer giữa — vd service/repository>             ← không import UI
<layer dưới — vd model/type>                     ← không import layer nào ở trên
```

Hướng import được harness ép nếu pack của stack có rule layer (Flutter bộ base: `layer_*`; web: dependency-cruiser). Không có → ghi rõ ở đây và review tay.

## Domain

| Domain | UI | Logic / data | Ghi chú |
|---|---|---|---|
| <domain> | `<path>` | `<path>` | <1 dòng> |

## Entry points

- <app/server entry, DI, router — đường dẫn thật trong backtick>
