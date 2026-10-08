// ---------------------------------------------------------------------------
// RENDER-1.0 R4（前半）：golden 快照基线生成器。
//
// 用法（模块根目录）：
//   moon run --target native scripts -- test/golden
//
// CLI 同一 op 分发器驱动（core/apply_operation）：遍历主题 × 内置组件
// 清单，逐个 create→theme→place→export-svg 落盘 test/golden/。
// 渲染管道与 core/golden_wbtest.mbt 的快照比对共用 core/golden.mbt 的
// golden_render——基线与比对逐字节同源。
//
// FS 走 libc FFI（Bytes + 手工 NUL 结尾 = char*；FILE* 64 位 → Int64 句柄；
// fgetc/fputs 返回 C int → Int。探针实测锁定，勿改签名）。
// ---------------------------------------------------------------------------

///|
#borrow(path, mode)
extern "c" fn golden_gen_fopen(path : Bytes, mode : Bytes) -> Int64 = "fopen"

///|
#borrow(s)
extern "c" fn golden_gen_fputs(s : Bytes, f : Int64) -> Int64 = "fputs"

///|
extern "c" fn golden_gen_fclose(f : Int64) -> Int64 = "fclose"

///|
#borrow(path)
extern "c" fn golden_gen_mkdir(path : Bytes, mode : Int) -> Int = "mkdir"

///|
/// String → NUL 结尾 UTF-8 Bytes（C char* 约定）
fn golden_gen_cstr(s : String) -> Bytes {
  let b = @utf8.encode(s)
  let out : Array[Byte] = []
  for i in 0..<b.length() {
    out.push(b[i])
  }
  out.push(0)
  Bytes::from_iter(out.iter())
}

///|
/// 文本落盘（覆盖写）。返回是否成功。
fn golden_gen_write(path : String, content : String) -> Bool {
  let f = golden_gen_fopen(golden_gen_cstr(path), golden_gen_cstr("w"))
  if f == 0 {
    return false
  }
  let n = golden_gen_fputs(golden_gen_cstr(content), f)
  let _ = golden_gen_fclose(f)
  n >= 0
}

///|
/// mkdir -p：逐段创建（mkdir 非递归；EEXIST/-1 一律忽略——目录已存在
/// 同样返回 -1，成功与否以最终 fopen 为准）
fn golden_gen_mkdir_p(dir : String) -> Unit {
  let segs : Array[String] = []
  for seg in dir.split("/") {
    segs.push(seg.to_string())
  }
  let mut acc = if dir.substring(start=0, end=1) == "/" { "" } else { "." }
  for seg in segs.iter() {
    if seg == "" || seg == "." {
      continue
    }
    acc = if acc == "." { seg } else { acc + "/" + seg }
    let _ = golden_gen_mkdir(golden_gen_cstr(acc), 0o755)
  }
}

///|
fn main {
  // 输出目录：argv 尾参（缺省 test/golden）
  let args = @env.args()
  let outdir = if args.length() >= 2 {
    args[args.length() - 1]
  } else {
    "test/golden"
  }
  golden_gen_mkdir_p(outdir)
  let themes = @core.golden_themes()
  let comps = @core.golden_component_names()
  println(
    "[golden-gen] 输出 \{outdir}：\{themes.length()} 主题 × \{comps.length()} 组件",
  )
  let mut written = 0
  let mut failed = 0
  for theme in themes.iter() {
    for comp in comps.iter() {
      let name = @core.golden_file_name(theme, comp)
      match @core.golden_render(theme, comp) {
        Err(e) => {
          println("[golden-gen] FAIL \{name}: \{e}")
          failed = failed + 1
        }
        Ok(svg) =>
          if golden_gen_write(outdir + "/" + name, svg) {
            written = written + 1
          } else {
            println("[golden-gen] FAIL \{name}: 落盘失败")
            failed = failed + 1
          }
      }
    }
  }
  println(
    "[golden-gen] 完成：写入 \{written}，失败 \{failed}（重跑 core/golden_wbtest.mbt 快照比对请用 moon test --target native）",
  )
}
