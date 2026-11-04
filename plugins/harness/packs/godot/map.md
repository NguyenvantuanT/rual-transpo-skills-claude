### Godot 4

- Chạy: `godot --path .` · headless: `godot --headless --path .`. Hook Stop chạy `gdlint`/`gdformat` (gdtoolkit) và GUT cho test liên quan nếu có `addons/gut`.
- File `.godot/`, `.import`, `.uid` do editor sinh — không sửa tay.

| Việc | Skill (plugin) |
|---|---|
| Scene/node, signal, resource, GDScript typed, GUT | `godot-development` (agent `godot-engineer`) |
| Kiến trúc game: loop, ECS, event bus, state stack | `game-arch-patterns` (plugin `game-architecture`) |
| Chạy project, đọc lỗi runtime qua MCP | plugin `godot-mcp` |
