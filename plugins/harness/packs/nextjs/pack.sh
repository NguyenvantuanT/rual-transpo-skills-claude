# Pack nextjs — Next.js App Router + React. Chạy cùng pack web_ts (tsc/eslint/test do web_ts lo). Hợp đồng: ../README.md
nextjs_markers="next.config.js next.config.mjs next.config.ts"
nextjs_files="*.ts *.tsx *.js *.jsx"
nextjs_generated='(^|/)\.next/|(^|/)next-env\.d\.ts$|(^|/)out/'
nextjs_generated_msg="Next.js tự sinh file này → sửa source rồi chạy lại \`next build\` / \`next dev\`."
nextjs_skills='^(src/)?app/.*(page|layout|loading|error|not-found|route|template|default)\.(tsx?|jsx?)$=nextjs-app-router
^(src/)?(app/.*actions?|actions?/|lib/(api|fetch|queries))=web-data-fetching
^(src/)?(middleware|auth)\.(ts|js)$|^(src/)?(lib/)?auth/=web-auth-security
^(src/)?components/=react-ui-components
^(src/)?(messages|i18n)/=web-i18n
(^|/)(__tests__|e2e|tests?)/|\.(test|spec)\.(tsx?|jsx?)$=web-testing'

nextjs_rules() {
  case "$rel" in
    node_modules/*|.next/*) ;;
    *.tsx|*.jsx|*.ts|*.js)
      local tests='(^|/)(__tests__|e2e|tests?)/|\.(test|spec)\.'
      flag next_img '<img[[:space:]]' '`<img>` → `import Image from "next/image"` (tự tối ưu, lazy, tránh layout shift; cần width/height hoặc `fill`)' "$tests"
      flag next_internal_a '<a[[:space:]][^>]*href=\{?["'"'"'`]/([^/]|["'"'"'`])' 'Link nội bộ bằng `<a>` → `<Link href="...">` từ `next/link` (prefetch, không reload trang)' "$tests"
      flag next_old_router "from ['\"]next/router['\"]" '`next/router` là Pages Router → App Router dùng `useRouter`/`usePathname`/`useSearchParams` từ `next/navigation`'
      flag next_public_secret 'NEXT_PUBLIC_[A-Z0-9_]*(SECRET|PRIVATE|PASSWORD|SERVICE_ROLE|TOKEN)' 'Biến `NEXT_PUBLIC_*` bị bundle xuống trình duyệt → secret phải bỏ tiền tố, chỉ đọc ở server (Server Component / Route Handler / Server Action)'
      flag react_html 'dangerouslySetInnerHTML' 'HTML thô → XSS. Render bằng JSX; buộc phải dùng thì sanitize (`DOMPurify.sanitize`) và ghi lý do' "$tests"
      flag react_index_key 'key=\{[[:space:]]*(i|idx|index)[[:space:]]*\}' '`key={index}` làm React giữ sai state khi list đổi thứ tự → dùng id ổn định của item'
      # File client không được kéo code server (DB, secret) xuống bundle.
      case "$disabled" in *" next_client_server "*) ;; *)
        if head -5 "$file" | grep -qE "^[[:space:]]*['\"]use client['\"]"; then
          local hits
          hits=$(grep -nE "from ['\"](@prisma/client|server-only|[^'\"]*/(server|db|prisma)(/[^'\"]*)?|node:(fs|child_process))['\"]|process\\.env\\.[A-Z]" "$file" | grep -v 'NEXT_PUBLIC_' | only_added | head -5)
          [ -n "$hits" ] && msgs+="- [next_client_server] File \`'use client'\` import code server / đọc env server → chuyển logic vào Server Component, Server Action hoặc Route Handler rồi truyền data qua props"$'\n'"$hits"$'\n'
        fi ;;
      esac
      ;;
  esac
}
