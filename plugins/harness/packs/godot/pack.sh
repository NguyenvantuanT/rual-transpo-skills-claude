# Pack godot — game Godot 4 (GDScript). Hợp đồng: ../README.md
# T1 dùng gdtoolkit (gdlint/gdformat, `pip install gdtoolkit`) và GUT cho test nếu dự án có addons/gut.
godot_markers="project.godot"
godot_files="*.gd"
godot_generated='(^|/)\.godot/|\.import$|\.uid$'
godot_generated_msg="File do editor Godot sinh (.godot/, .import, .uid) → mở/refresh project trong editor hoặc chạy \`godot --headless --import\`."
godot_skills=''

godot_rules() {
  case "$rel" in
    addons/*) ;;  # addon bên thứ 3: không áp convention
    *.gd)
      local tests='(^|/)(tests?)/|(^|/)test_[^/]*\.gd$'
      flag gd_print '^[[:space:]]*print(t|_debug|_rich)?\(' '`print` còn sót → xoá, hoặc `push_warning()` / `push_error()` cho lỗi thật' "$tests"
      flag gd_untyped_var '^[[:space:]]*(@export[^v]*)?var[[:space:]]+[A-Za-z_][A-Za-z0-9_]*[[:space:]]*=[^=]' 'Biến không khai type → `var x: Type = ...` hoặc `var x := ...` (static typing: nhanh hơn, editor bắt lỗi sớm)'
      flag gd_parent_path 'get_node\("\.\./|\$"?\.\./|get_parent\(\)\.get_parent\(\)' 'Path node đi ngược lên cha → `@export var target: Node` gán trong editor, hoặc signal lên cha (call down, signal up)'
      flag gd_find_node 'get_tree\(\)\.root\.(find_child|get_node)\(|find_child\(' 'Tìm node theo tên toàn cây → `@export` reference, unique name `%Name`, hoặc group'
      flag gd_process_alloc 'func _(physics_)?process\(.*\):.*(load|preload)\(' 'load trong _process → `preload` ở đầu file / cache vào biến'
      flag gd_secret "$HARNESS_SECRET_RE" 'Secret trong client game là public → để key ở server, client gọi qua backend'
      ;;
  esac
}

godot_bin() { local b; for b in "$GODOT" godot godot4 /Applications/Godot.app/Contents/MacOS/Godot; do [ -n "$b" ] && command -v "$b" >/dev/null 2>&1 && { echo "$b"; return 0; }; done; return 1; }

godot_verify() {
  local gd bin out
  gd=$(printf '%s\n' "$changed" | grep -E '\.gd$' | grep -v '^addons/' | while read -r f; do [ -f "$f" ] && echo "$f"; done)
  [ -n "$gd" ] || return 0
  if ! off gdlint && bin=$(tool gdlint); then
    out=$("$bin" $gd 2>&1) || msgs+="- [gdlint] Sửa theo gdlint:"$'\n'"$(printf '%s\n' "$out" | head -20)"$'\n'
  fi
  if ! off gdformat && bin=$(tool gdformat); then
    "$bin" --check $gd >/dev/null 2>&1 || msgs+="- [gdformat] Chưa format → \`gdformat <file>\`"$'\n'
  fi
  return 0
}

# T1 test: GUT, chỉ chạy script test liên quan (test_<tên>.gd) + script test đổi.
godot_test() {
  [ -d addons/gut ] || return 0
  local bin f b tests="" out
  bin=$(godot_bin) || return 0
  for f in $(printf '%s\n' "$changed" | grep -E '\.gd$' | grep -v '^addons/'); do
    b=$(basename "$f" .gd)
    case "$b" in test_*) [ -f "$f" ] && tests+="res://$f," ;;
      *) for t in $(find . -path ./addons -prune -o -name "test_$b.gd" -print 2>/dev/null); do tests+="res://${t#./},"; done ;;
    esac
  done
  [ -n "$tests" ] || return 0
  out=$("$bin" --headless --path . -s addons/gut/gut_cmdln.gd -gtest="${tests%,}" -gexit 2>&1) \
    || msgs+="- [test] GUT FAIL → sửa code (không sửa test cho xanh trừ khi test sai, ghi lý do):"$'\n'"$(printf '%s\n' "$out" | grep -E '\[Failed\]|FAILED|Error|SCRIPT ERROR' | head -25)"$'\n'
}
