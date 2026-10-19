// MoonViz 自渲染服务（dev 线：webview self-rendering）——客户端引导模型
//
// 定位（强制）：引擎【无 UI、无窗口、不自行获取渲染面】。自渲染能力必须由
// 客户端引导使用——客户端（Tauri / Electron / 任意原生壳）拉起引擎、指定
// 渲染源（.mbt.md 唯一事实源）、承接渲染结果。渲染面永远是客户端的：
//   表面一（客户端 webview）：客户端有自己的 webview → 把引擎渲染产物载入
//     其中即获得活原型（交互运行时内嵌：画板切换/导航流/toast/状态多态），
//     Tauri/Electron 零渲染代码；
//   表面二（系统兜底）：原生环境没有 webview → 引擎直接调用系统层渲染并
//     返回结果——产物写盘（MOONVIZ_OUT），写盘也不可用再退 stdout
//     （渲染结果即返回值）。
//
// 引擎全程不拉起 webview、不建窗口；无 MOONVIZ_DOC 引导时只回 usage 信封，
// 不做任何渲染、不写任何文件。渲染链路 .mbt.md → load_mbt_project →
// export_html 全程进程内、纯 MoonBit——无 sidecar、无上层框架依赖。
//
// env 开关（客户端引导入口，不经命令行参数）：
//   MOONVIZ_DOC=<path>  渲染源 .mbt.md 路径（必需；无它引擎保持惰性）
//   MOONVIZ_OUT=<path>  渲染产物路径（缺省 moonviz-render.html；
//                       客户端 webview 加载该文件即是活原型）
//   MOONVIZ_SMOKE=1     无头自检（不出任何界面：源读取/管线/渲染/兜底写读）

///|
/// FFI 边界：String → NUL 终止 UTF-8 Bytes（官方 C-FFI 约定）
fn c_bytes(s : String) -> Bytes {
  let utf8 = @utf8.encode(s)
  let arr = utf8.to_array()
  arr.push(0)
  Bytes::from_array(arr)
}

///|
#borrow(name)
extern "c" fn mv_getenv(name : Bytes) -> String = "mv_getenv"

///|
#borrow(path)
extern "c" fn mv_read_file(path : Bytes) -> String = "mv_read_file"

///|
#borrow(path, data)
extern "c" fn mv_write_file(path : Bytes, data : Bytes) -> Int = "mv_write_file"

///|
fn getenv_str(name : String) -> String {
  mv_getenv(c_bytes(name))
}

///|
/// 无引导不渲染：引擎不自行取用自渲染能力——只告知客户端如何引导。
fn usage_envelope() -> String {
  "{\"ok\":false,\"error\":\"not_guided\",\"note\":\"self-rendering is client-guided: set MOONVIZ_DOC=<path.mbt.md> (render source) and optionally MOONVIZ_OUT=<path> (artifact for your webview to load); MOONVIZ_SMOKE=1 runs the headless self-check\",\"version\":\"" +
  @core.ENGINE_VERSION +
  "\"}"
}

///|
/// 客户端引导渲染：MOONVIZ_DOC → 引擎管线 → 自包含交互 HTML。
/// 返回 Result：Err = 已打印错误信封（源不可读 / 解析失败），引擎保持惰性——
/// 不回退内置演示、不渲染未引导的内容。
fn guided_render() -> Result[String, Unit] {
  let doc = getenv_str("MOONVIZ_DOC")
  if doc == "" {
    println(usage_envelope())
    return Err(())
  }
  let src = mv_read_file(c_bytes(doc))
  if src == "" {
    println(
      "{\"ok\":false,\"error\":\"doc_unreadable\",\"doc\":\"" +
      @core.json_escape(doc) +
      "\"}",
    )
    return Err(())
  }
  match @decl.load_mbt_project(src) {
    Err(error) => {
      println(
        "{\"ok\":false,\"error\":\"doc_parse_failed\",\"detail\":\"" +
        @core.json_escape(error) +
        "\"}",
      )
      Err(())
    }
    Ok(mp) => Ok(mp.project.export_html())
  }
}

///|
/// 渲染结果交付（表面由客户端承接）：产物写盘 → 客户端 webview 加载该文件
/// （表面一）；写盘不可用 → 自包含 HTML 打到 stdout（表面二兜底：渲染结果
/// 即返回值，可管道给任意 webview/浏览器）。
fn deliver(html : String) -> Unit {
  let out = getenv_str("MOONVIZ_OUT")
  let path = if out == "" { "moonviz-render.html" } else { out }
  if mv_write_file(c_bytes(path), c_bytes(html)) == 0 {
    println(
      "{\"ok\":true,\"surface\":\"client-webview\",\"artifact\":\"" +
      @core.json_escape(path) +
      "\",\"note\":\"load this file in the client webview — 活原型，零客户端渲染代码\"}",
    )
  } else {
    println(html)
  }
}

///|
/// 无头自检（不出任何界面，CI 可跑）：源读取 → 引擎管线 → 自包含交互渲染 →
/// 兜底产物写读一致。渲染面（客户端 webview 承载）由客户端集成实测。
fn run_smoke() -> Bool {
  let doc = getenv_str("MOONVIZ_DOC")
  let src = if doc != "" {
    let s = mv_read_file(c_bytes(doc))
    if s == "" {
      println("[smoke] FAIL — MOONVIZ_DOC 不可读: " + doc)
      return false
    }
    s
  } else {
    let s = mv_read_file(c_bytes("examples/login-demo.mbt.md"))
    if s == "" {
      println("[smoke] FAIL — 无渲染源（设 MOONVIZ_DOC 或在仓库根运行）")
      return false
    }
    s
  }
  println("[smoke] 源读取 OK（\{src.length()} 字符）")
  let html = match @decl.load_mbt_project(src) {
    Ok(mp) => mp.project.export_html()
    Err(error) => {
      println("[smoke] FAIL — load_mbt_project: " + error)
      return false
    }
  }
  if !html.contains("<svg") || !html.contains("MV_ACT") {
    println("[smoke] FAIL — export_html 缺交互运行时")
    return false
  }
  println("[smoke] 引擎渲染 OK（HTML \{html.length()} 字符，含交互运行时）")
  let mut probe = "_build/moonviz-smoke-render.html"
  let written = if mv_write_file(c_bytes(probe), c_bytes(html)) == 0 {
    true
  } else {
    probe = "moonviz-smoke-render.html"
    mv_write_file(c_bytes(probe), c_bytes(html)) == 0
  }
  if !written {
    println("[smoke] FAIL — 兜底产物写盘失败")
    return false
  }
  let back = mv_read_file(c_bytes(probe))
  if back != html {
    println("[smoke] FAIL — 兜底产物读回不一致")
    return false
  }
  println("[smoke] PASS — 源/管线/渲染/兜底写读 全通（\{probe}）")
  true
}

///|
fn main {
  if getenv_str("MOONVIZ_SMOKE") == "1" {
    let _ = run_smoke()
    return
  }
  // 客户端引导渲染：无引导引擎保持惰性（无窗口、无渲染、无文件写入）
  match guided_render() {
    Err(_) => ()
    Ok(html) => deliver(html)
  }
}
