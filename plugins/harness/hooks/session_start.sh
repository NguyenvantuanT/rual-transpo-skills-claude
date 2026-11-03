#!/usr/bin/env bash
# SessionStart: stdout được đưa vào context đầu phiên — chỉ vài dòng: pack đang bật + plan đang dở (giao thức phiên ở docs/PLANS.md).
cat >/dev/null
. "$(dirname "$0")/../engine/lib.sh"
harness_on || exit 0
line="Harness: pack"
for p in $packs; do
  ds=$(pack_roots "$p" | tr '\n' ' '); ds=${ds% }
  if [ "$ds" = . ]; then line+=" $p"; else line+=" $p($ds)"; fi
done
echo "$line. Đọc AGENTS.md trước khi làm."
n=0
for plan in docs/exec-plans/active/*.md; do
  [ -f "$plan" ] || continue
  n=$((n + 1)); [ "$n" -gt 3 ] && { echo "- … còn plan khác trong docs/exec-plans/active/"; break; }
  title=$(grep -m1 '^# ' "$plan" | sed 's/^# //')
  next=$(awk '/^## /{s=($0 ~ /^## Bước/)} s && /^- \[ \]/ {sub(/^- \[ \] /, ""); print; exit}' "$plan")
  echo "- Plan đang dở: $plan ($title) — bước tiếp: ${next:-xem mục Tiến độ}. Làm theo giao thức phiên trong docs/PLANS.md."
done
exit 0
