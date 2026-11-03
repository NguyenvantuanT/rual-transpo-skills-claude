#!/usr/bin/env bash
input=$(cat)
field() { printf '%s' "$input" | grep -o "\"$1\"[[:space:]]*:[[:space:]]*\"[^\"]*\"" | head -1 | sed -E 's/.*:[[:space:]]*"//; s/"$//; s/\\+/\//g'; }
file=$(field file_path)
[ -n "$file" ] || exit 0
. "$(dirname "$0")/../engine/lib.sh"
rel=$(relpath "$file")

if p=$(generated_by "$rel"); then
  eval "msg=\$${p}_generated_msg"
  echo "BLOCKED: $file là file generated. ${msg:-Sửa nguồn rồi chạy lại bước generate.}" >&2
  exit 2
fi

# Nhắc load skill theo path (<pack>_skills). Mỗi skill nhắc tối đa 1 lần/phiên; đã load (có trong transcript) thì im.
case "$disabled" in *" skill_hint "*) exit 0 ;; esac
git_dir=$(git rev-parse --git-dir 2>/dev/null) || exit 0
need=""
for p in $packs; do
  eval "map=\$${p}_skills"
  while IFS= read -r line; do
    [ -n "$line" ] || continue
    printf '%s' "$rel" | grep -qE "${line%=*}" && { need+="${line##*=} "; break; }
  done <<< "$map"
done
[ -n "$need" ] || exit 0

transcript=$(field transcript_path)
session=$(field session_id)
seen="$git_dir/harness-skill-hints"
missing=""
for s in $need; do
  grep -qE "\"skill\"[[:space:]]*:[[:space:]]*\"([A-Za-z0-9_-]+:)?$s\"" "$transcript" 2>/dev/null && continue
  grep -qxF "$session $s" "$seen" 2>/dev/null && continue
  echo "$session $s" >> "$seen"
  missing+="\`$s\` "
done
[ -n "$missing" ] || exit 0
echo "Harness: $rel thuộc domain có skill ${missing}→ load bằng tool Skill trước khi sửa. Chỉ nhắc 1 lần mỗi phiên; đã nắm convention thì cứ sửa tiếp. (tắt: HARNESS_DISABLE=skill_hint)" >&2
exit 2
