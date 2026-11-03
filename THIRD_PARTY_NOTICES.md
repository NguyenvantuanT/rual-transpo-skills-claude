# Third-party notices

## BOW Skills (`plugins/flutter-supabase`, `plugins/flutter`, `plugins/bow-core`)

Nguồn: https://github.com/Bow-T/bow-skills (commit `3641af3`, 2026-06-22).

Các file sau được phỏng theo (viết lại theo convention vtinter-harness):

| File trong repo này | Phỏng theo |
|---|---|
| `plugins/flutter-supabase/skills/flutter-supabase-queries/SKILL.md` | `plugins/flutter-supabase/skills/flutter-supabase-queries/SKILL.md` |
| `plugins/supabase/skills/supabase-security-review/SKILL.md` | `plugins/flutter-supabase/skills/supabase-security-review/SKILL.md` |
| `plugins/flutter/skills/flutter-networking-and-data/references/models-generated.md` | `plugins/flutter-supabase/skills/flutter-data-model/SKILL.md` |
| `plugins/harness/packs/supabase/pack.sh` (rule `sb_*`) | các rule tự động mô tả trong `supabase-security-review` |
| `plugins/flutter/skills/flutter-testing/SKILL.md` | `plugins/flutter/skills/flutter-testing/SKILL.md` |
| `plugins/flutter/skills/flutter-error-handling/SKILL.md` | `plugins/flutter/skills/flutter-error-handling-and-crash-reporting/SKILL.md` |
| `plugins/flutter/skills/flutter-performance/SKILL.md` | `plugins/flutter/skills/flutter-performance-and-rebuild-optimization/SKILL.md` |
| `plugins/flutter/skills/flutter-push-and-deep-link/` | `plugins/flutter/skills/flutter-push-notifications-and-deep-linking/SKILL.md` |
| `plugins/core/skills/ai-code-review/SKILL.md` | `plugins/bow-core/skills/ai-generated-code-review/SKILL.md` |
| `plugins/core/skills/datetime-and-money/SKILL.md` | `plugins/bow-core/skills/datetime-timezone-and-money-correctness/SKILL.md` |
| `plugins/core/skills/offline-sync/SKILL.md` | `plugins/bow-core/skills/offline-sync-and-conflict-resolution/SKILL.md` |

```
MIT License

Copyright (c) 2026 BOW Skills contributors

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all
copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
SOFTWARE.
```

## UI UX Pro Max (`plugins/core/skills/ui-ux-pro-max`)

Nguồn: https://github.com/nextlevelbuilder/ui-ux-pro-max-skill (commit `3a13158`, v2.15.0, 2026-11-01).

`plugins/core/skills/ui-ux-pro-max/` được chép nguyên từ `.claude/skills/ui-ux-pro-max/` của repo gốc, chỉ khác:

- Đường dẫn script trong `SKILL.md` đổi từ `${CLAUDE_PLUGIN_ROOT}/.claude/skills/ui-ux-pro-max/` thành `${CLAUDE_PLUGIN_ROOT}/skills/ui-ux-pro-max/`.
- Bỏ thư mục `scripts/tests` (test của repo gốc, không cần khi dùng skill).

```
MIT License

Copyright (c) 2024 Next Level Builder

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all
copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
SOFTWARE.
```
