### Unity

- Code ở `Assets/`. File `.meta` giữ GUID tham chiếu asset — không sửa tay, không xoá lẻ.
- Compile + EditMode test ở Stop hook chỉ chạy khi đặt `HARNESS_UNITY=<đường dẫn Unity Editor>` trong `.claude/harness.env` (batchmode chậm).

| Việc | Skill (plugin) |
|---|---|
| MonoBehaviour/DOTS, URP/HDRP, Addressables, Input System | `unity-development` (agent `unity-engineer`) |
| Việc Unity cụ thể: UI Toolkit, sprite atlas, multiplayer, IAP, URP... | skill của plugin `unity-skills` (Unity Technologies) |
| Kiến trúc game: loop, ECS, event bus, state stack | `game-arch-patterns` (plugin `game-architecture`) |
