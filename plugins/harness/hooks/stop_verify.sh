#!/usr/bin/env bash
grep -qE '"stop_hook_active"[[:space:]]*:[[:space:]]*true' && exit 0
here="$(dirname "$0")/../engine"
. "$here/lib.sh"
harness_on || exit 0
git rev-parse --git-dir >/dev/null 2>&1 || exit 0
status=$(git status --porcelain -uall)
[ -n "$status" ] || exit 0

stamp="$(git rev-parse --git-dir)/harness-verified"
sig=$({ printf '%s\n' "$status"; git diff HEAD 2>/dev/null
        git ls-files -o --exclude-standard | xargs -r git hash-object 2>/dev/null; } | git hash-object --stdin)
[ "$(cat "$stamp" 2>/dev/null)" = "$sig" ] && exit 0

changed=$(printf '%s\n' "$status" | cut -c4- | sed 's/.* -> //; s/^"//; s/"$//')
msgs=""

# T1 của từng pack, chạy trong từng root của pack (cwd = root, $changed = path tính từ root):
# _verify (regen, analyze, lint...) rồi _test (test liên quan) — test chỉ chạy khi verify của root đó sạch.
for p in $packs; do
  for d in $(pack_roots "$p"); do
    sub=$(printf '%s\n' "$changed" | while IFS= read -r f; do
            [ -n "$f" ] && [ "$(pack_root "$p" "$f")" = "$d" ] && pack_rel "$d" "$f"
          done)
    [ -n "$sub" ] || continue
    out=$(cd "$d" && changed="$sub" && msgs="" && {
            declare -F "${p}_verify" >/dev/null && "${p}_verify"
            if [ -z "$msgs" ]; then case "$disabled" in (*" test "*) ;; (*)
              declare -F "${p}_test" >/dev/null && "${p}_test" ;; esac; fi
            printf '%s' "$msgs"; })
    [ -n "$out" ] || continue
    if [ "$d" = . ]; then msgs+="$out"$'\n'; else msgs+="[$p · $d]"$'\n'"$out"$'\n'; fi
  done
done

# Gate evaluator (mọi stack): plan đổi trong phiên mà acceptance criteria đã tick hết, hoặc đã chuyển sang completed/
# → phải có dòng "- <YYYY-MM-DD> đạt hết" trong mục "## Evaluator" (kết quả subagent evaluator).
case "$disabled" in *" plan_eval "*) ;; *)
  for plan in $(printf '%s\n' "$changed" | grep -E '^docs/exec-plans/(active|completed)/.*\.md$'); do
    [ -f "$plan" ] || continue
    crit=$(awk '/^## /{s=($0 ~ /^## Mục tiêu/)} s && /^- \[[ xX]\]/' "$plan")
    [ -n "$crit" ] || continue
    case "$plan" in docs/exec-plans/active/*) printf '%s\n' "$crit" | grep -q '^- \[ \]' && continue ;; esac
    awk '/^## /{s=($0 ~ /^## Evaluator/)} s' "$plan" | grep -qE '^-[[:space:]]+[0-9]{4}-[0-9]{2}-[0-9]{2}[[:space:]]+đạt hết' && continue
    msgs+="- [plan_eval] $plan: acceptance criteria đã tick hết nhưng chưa có kết quả evaluator → chạy subagent \`evaluator\`, ghi \`- <YYYY-MM-DD> đạt hết — <bằng chứng>\` vào mục \`## Evaluator\` (chưa đạt → bỏ tick tiêu chí đó, làm tiếp)"$'\n'
  done ;;
esac

code_files=$(printf '%s\n' "$changed" | grep -vE '\.md$' | while read -r f; do [ -f "$f" ] && echo "$f"; done)
[ -n "$code_files" ] && { rules=$(HARNESS_DIFF=HEAD bash "$here/check.sh" $code_files) || msgs+="$rules"$'\n'; }

if printf '%s\n' "$status" | grep -qE '^( ?D|D |R)'; then
  docs=$(bash "$here/docs-check.sh") || msgs+="$docs"$'\n'
else
  md_files=$(printf '%s\n' "$changed" | grep -E '\.md$')
  [ -n "$md_files" ] && { docs=$(bash "$here/docs-check.sh" $md_files) || msgs+="$docs"$'\n'; }
fi

if [ -z "$msgs" ]; then
  printf '%s' "$sig" > "$stamp"
  exit 0
fi
printf 'Chưa xong — harness verify:\n%s' "$msgs" >&2
exit 2
