# Pack unity — game Unity (C#). Hợp đồng: ../README.md
# Compile/test bằng Unity Editor ở batchmode rất chậm → chỉ chạy khi đặt HARNESS_UNITY=<đường dẫn Unity Editor> trong harness.env.
unity_markers="ProjectSettings/ProjectVersion.txt"
unity_files="Assets/*.cs"
unity_generated='^(Library|Temp|Obj|obj|Logs|Build|Builds|UserSettings)/|\.(csproj|sln)$|\.meta$'
unity_generated_msg="Unity tự sinh file này (.meta giữ GUID tham chiếu asset — sửa tay làm vỡ reference). Tạo/đổi tên asset rồi để Editor sinh lại."
unity_skills='^Assets/.*\.cs$=unity-development'
unity_editor=$(cfg HARNESS_UNITY)

unity_rules() {
  case "$rel" in
    Assets/Plugins/*|Assets/ThirdParty/*|Packages/*) ;;
    Assets/*.cs)
      local skip='(^|/)(Editor|Tests?)/'
      flag unity_find '\bGameObject\.Find(WithTag|GameObjectsWithTag)?\(|\bFind(First|Any)?Objects?(Of|By)Type' 'Find lúc runtime: chậm + gãy khi đổi tên → `[SerializeField] private T ref;` gán trong Inspector, hoặc inject' "$skip"
      flag unity_debug_log '\bDebug\.Log\(' '`Debug.Log` còn sót → xoá, hoặc dùng logger có `[Conditional("UNITY_EDITOR")]`; lỗi thật → `Debug.LogError`' "$skip"
      flag unity_public_field '^[[:space:]]*public[[:space:]]+[A-Za-z_][A-Za-z0-9_<>,.]*(\[\])?[[:space:]]+[A-Za-z_][A-Za-z0-9_]*[[:space:]]*(=[^>]|;)' 'Field public → `[SerializeField] private T name;` (+ property chỉ đọc nếu class khác cần)' "$skip"
      flag unity_string_coroutine 'StartCoroutine\("|Invoke(Repeating)?\("' 'Gọi theo tên string → `StartCoroutine(MyRoutine())`; Invoke → coroutine / timer'
      flag unity_camera_main 'Camera\.main' '`Camera.main` mỗi lần gọi là một lần tìm → cache vào field trong Awake'
      flag unity_secret "$HARNESS_SECRET_RE" 'Secret trong client game là public → để key ở server, client gọi qua backend'
      ;;
  esac
}

unity_verify() {
  [ -n "$unity_editor" ] && [ -x "$unity_editor" ] || return 0
  off unity_compile && return 0
  printf '%s\n' "$changed" | grep -qE '\.cs$' || return 0
  local log=Logs/harness-compile.log out
  "$unity_editor" -batchmode -nographics -quit -projectPath . -logFile "$log" >/dev/null 2>&1
  out=$(grep -E 'error CS[0-9]+' "$log" 2>/dev/null | sort -u | head -20)
  [ -n "$out" ] && msgs+="- [unity_compile] Lỗi compile C# → sửa:"$'\n'"$out"$'\n'
  return 0
}

unity_test() {
  [ -n "$unity_editor" ] && [ -x "$unity_editor" ] || return 0
  local res=Logs/harness-editmode.xml failed
  "$unity_editor" -batchmode -nographics -projectPath . -runTests -testPlatform EditMode -testResults "$res" >/dev/null 2>&1 && return 0
  failed=$(grep -oE '<test-case [^>]*result="Failed"[^>]*' "$res" 2>/dev/null | grep -oE 'fullname="[^"]*"' | head -15)
  msgs+="- [test] EditMode test FAIL → sửa code (không sửa test cho xanh trừ khi test sai):"$'\n'"${failed:-xem $res}"$'\n'
}
