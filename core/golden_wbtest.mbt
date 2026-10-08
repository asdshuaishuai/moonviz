// ---------------------------------------------------------------------------
// RENDER-1.0 R4（前半）：golden 快照 diff 测试（native-only：读基线文件
// 需要文件系统 FFI）。非 native 目标本文件不参与编译（moon.pkg targets
// 门控）——快照守护在 `moon test --target native` 下生效。
//
// 契约（RENDER-1.0 R4）：
// - 任意组件 SVG 输出变化（含未来改动引入的回归）→ 测试红，并列出
//   不一致的 <theme>-<component>；
// - 新增组件未重生成基线 → 红（列 missing-golden），防静默漏守护；
// - 整个 test/golden/ 缺失 → 跳过并提示跑生成脚本（不 CI 首跑自产
//   自销掩盖回归）。
//
// FS 走 libc FFI（Bytes + 手工 NUL 结尾 = char*；句柄 Int64——FILE* 为
// 64 位，Int 会截断；fgetc 返回 C int → Int。探针 / 实测锁定，勿改签名）。
// ---------------------------------------------------------------------------

///|
#borrow(path, mode)
extern "c" fn golden_fopen(path : Bytes, mode : Bytes) -> Int64 = "fopen"

///|
extern "c" fn golden_fclose(f : Int64) -> Int64 = "fclose"

///|
extern "c" fn golden_fgetc(f : Int64) -> Int = "fgetc"

///|
/// String → NUL 结尾 UTF-8 Bytes（C char* 约定）
fn golden_cstr(s : String) -> Bytes {
  let b = @utf8.encode(s)
  let out : Array[Byte] = []
  for i in 0..<b.length() {
    out.push(b[i])
  }
  out.push(0)
  Bytes::from_iter(out.iter())
}

///|
/// 整读一个文本文件（fgetc 逐字节 → Bytes → UTF-8 解码）；打不开返回 None
fn golden_read_file(path : String) -> String? {
  let f = golden_fopen(golden_cstr(path), golden_cstr("rb"))
  if f == 0 {
    return None
  }
  let buf : Array[Byte] = []
  let mut reading = true
  while reading {
    let c = golden_fgetc(f)
    if c < 0 {
      reading = false
    } else {
      buf.push(c.to_byte())
    }
  }
  let _ = golden_fclose(f)
  // UTF-8 严格解码；坏字节 = 基线文件被外部破坏 → None（按缺失处理）
  Some(@utf8.decode(Bytes::from_iter(buf.iter())) catch {
    _ => return None
  })
}

///|
/// 从 cwd 逐级向上找模块根（moon.mod.json），返回 <root>/test/golden。
/// moon test 的工作目录随调用位置变化，逐级上溯对齐仓库根。
fn golden_find_dir() -> String? {
  let cwd = match @env.current_dir() {
    Some(d) => d
    None => return None
  }
  let mut cut = cwd.length()
  let mut found : String? = None
  let mut searching = true
  while searching {
    let candidate = if cut == 0 { cwd } else { cwd.substring(start=0, end=cut).to_string() }
    match golden_read_file(candidate + "/moon.mod.json") {
      Some(_) => {
        found = Some(candidate + "/test/golden")
        searching = false
      }
      None => {
        // 上一级
        let mut last = -1
        let mut i = 0
        while i < cut {
          if cwd.get_char(i) == Some('/') {
            last = i
          }
          i = i + 1
        }
        if last <= 0 {
          searching = false
        } else {
          cut = last
        }
      }
    }
  }
  found
}

///|
/// 快照比对报告："SKIP" = 基线整体缺失（跳过并提示）；"" = 全部一致；
/// 其余 = 失败详情（列出不一致 / missing 的 <theme>-<component>）。
fn golden_diff_report() -> String {
  let dir = match golden_find_dir() {
    Some(d) => d
    None => return "SKIP"
  }
  // 基线目录整体缺失（探一个必然存在的文件名）→ 跳过
  let first = golden_file_name(golden_themes()[0], golden_component_names()[0])
  match golden_read_file(dir + "/" + first) {
    None => return "SKIP"
    Some(_) => ()
  }
  let themes = golden_themes()
  let comps = golden_component_names()
  let mismatched : Array[String] = []
  let missing : Array[String] = []
  for theme in themes.iter() {
    for comp in comps.iter() {
      let name = golden_file_name(theme, comp)
      match golden_read_file(dir + "/" + name) {
        None => missing.push(name)
        Some(expected) =>
          match golden_render(theme, comp) {
            Err(e) => mismatched.push("\{name}（渲染失败 \{e}）")
            Ok(actual) =>
              if actual != expected {
                mismatched.push(name)
              }
          }
      }
    }
  }
  if missing.length() > 0 {
    return "golden 基线缺文件（新增组件需重生成基线）：\{missing.join(", ")}"
  }
  if mismatched.length() > 0 {
    return "SVG 输出与 golden 基线不一致（渲染回归或需有意重生成）：\{mismatched.join(", ")}"
  }
  ""
}

///|
test "golden 快照：light/dark × 全组件 SVG 与基线比对（缺失→跳过并提示）" {
  let r = golden_diff_report()
  if r == "SKIP" {
    // 红线：不 CI 首跑自产自销——基线缺失只提示，不当作通过基线生成
    println(
      "[golden-skip] 未找到 test/golden 基线——先跑生成脚本：moon run --target native scripts -- test/golden",
    )
    assert_true(true)
  } else {
    assert_true(r == "", msg=r)
  }
}
