# Pack nestjs — BE NestJS (+ Prisma). Chạy cùng pack web_ts (tsc/eslint/test do web_ts lo). Hợp đồng: ../README.md
nestjs_markers="nest-cli.json"
nestjs_files="src/*.ts prisma/schema.prisma"
nestjs_generated='(^|/)dist/|(^|/)prisma/migrations/[^/]+/migration\.sql$|(^|/)generated/'
nestjs_generated_msg="Migration đã sinh không sửa tay (DB thật đã chạy bản cũ) → sửa \`prisma/schema.prisma\` rồi \`npx prisma migrate dev --name <việc>\` để tạo migration mới."
nestjs_skills='\.controller\.ts$|\.dto\.ts$=nestjs-api-design
\.module\.ts$|\.service\.ts$=nestjs-architecture
prisma/|\.repository\.ts$=nestjs-prisma
\.(guard|strategy)\.ts$|(^|/)auth/=nestjs-auth-security
\.(processor|consumer|cron)\.ts$|(^|/)(jobs|queues)/=nestjs-jobs-queues
\.(spec|e2e-spec)\.ts$|^test/=nestjs-testing
\.(filter|interceptor|middleware)\.ts$|(^|/)(logger|health)/=nestjs-observability'

nestjs_rules() {
  case "$rel" in
    src/*.ts)
      local tests='\.(spec|e2e-spec)\.ts$'
      flag nest_any_input '@(Body|Query|Param)\([^)]*\)[[:space:]]+[A-Za-z_]+[[:space:]]*:[[:space:]]*(any|object|Record<)' 'Input không có DTO → class DTO với `class-validator` (`@IsString()`, `@IsInt()`...) + `ValidationPipe({ whitelist: true })`'
      flag nest_new_injectable '\bnew[[:space:]]+[A-Z][A-Za-z0-9]*(Service|Repository|Client|Gateway)\(' 'Tự `new` service → khai báo trong `providers` của module và inject qua constructor (test mới mock được)' "$tests"
      flag nest_raw_sql '\$(queryRawUnsafe|executeRawUnsafe)\(|\.query\([[:space:]]*`[^`]*\$\{' 'SQL ghép chuỗi → SQL injection. Prisma: `$queryRaw` dạng tagged template (`prisma.$queryRaw\`... ${id}\``) hoặc `Prisma.sql`'
      flag nest_process_env 'process\.env\.' 'Đọc `process.env` rải rác → khai báo trong config module (validate bằng zod/Joi lúc khởi động), inject `ConfigService`' '(^|/)(config/|main\.ts$)|'"$tests"
      flag nest_plain_error 'throw[[:space:]]+new[[:space:]]+Error\(' '`throw new Error` thành 500 mù → ném lỗi domain hoặc `NotFoundException`/`BadRequestException`/`ConflictException`... để exception filter map ra mã HTTP đúng' "$tests"
      flag nest_secret "$HARNESS_SECRET_RE" 'Secret hard-code → env + ConfigService, không commit key'
      ;;
  esac
}

# T1: schema Prisma đổi mà chưa có migration mới → DB lệch code.
nestjs_verify() {
  off prisma_migration && return 0
  local bin out
  printf '%s\n' "$changed" | grep -qE '^prisma/schema\.prisma$' || return 0
  if bin=$(tool prisma); then out=$("$bin" validate 2>&1) || { msgs+="- [prisma_migration] schema không hợp lệ:"$'\n'"$(printf '%s\n' "$out" | tail -10)"$'\n'; return 0; }; fi
  printf '%s\n' "$changed" | grep -qE '^prisma/migrations/[^/]+/migration\.sql$' && return 0
  msgs+="- [prisma_migration] \`prisma/schema.prisma\` đổi nhưng chưa có migration mới → \`npx prisma migrate dev --name <việc>\` (chỉ đổi comment/format thì HARNESS_DISABLE=prisma_migration)"$'\n'
}
