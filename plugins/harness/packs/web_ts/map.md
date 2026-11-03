### TypeScript (web / Node)

- Lệnh: `scripts` trong `package.json` (dev, build, test, lint). Typecheck: `npx tsc --noEmit`.
- Hook Stop chạy `tsc`, `eslint`, `dependency-cruiser` (nếu có) và test liên quan (`vitest related` / `jest --findRelatedTests`).
