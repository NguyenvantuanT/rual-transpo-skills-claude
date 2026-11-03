### Unity

- Code ở `Assets/`. File `.meta` giữ GUID tham chiếu asset — không sửa tay, không xoá lẻ.
- Compile + EditMode test ở Stop hook chỉ chạy khi đặt `HARNESS_UNITY=<đường dẫn Unity Editor>` trong `.claude/harness.env` (batchmode chậm).
