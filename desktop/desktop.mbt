// MoonViz 自渲染宿主（dev 线：webview self-rendering）
//
// 引擎直接为客户端提供渲染能力——客户端（Tauri / Electron / 任意原生壳）只需
// 提供一个 webview 来源，渲染本身零客户端代码：
//   第一层 webview：宿主拉起系统 webview（macOS = WKWebView，Tauri 哲学：
//                   不打包浏览器内核），把引擎渲染的自包含交互原型直接载入；
//   第二层 系统：webview 不可用时引擎直接调用系统层渲染并返回结果——
//                   兜底产物写盘（mv_write_file），写盘也不可用时把自包含
//                   HTML 直接打到 stdout（渲染结果即返回值）。
// 两层检测、系统兜底，降低客户端的使用与开发难度。
//
// 引擎核心全程 MoonBit：.mbt.md 唯一事实源 → load_mbt_project → export_html，
// 全链路进程内完成（无 sidecar、无上层框架依赖）。交互（画板切换/导航流/
// toast/状态多态）由导出 HTML 内嵌的运行时承载，webview 只是渲染面。
//
// 不变量：即用即销毁——webview 走非持久 data store（shim 保证），跨运行零
// 残留；webview 层零磁盘写入（第二层兜底产物是渲染结果交付物，只在无
// webview 时产生，由客户端自管生命周期）。核心不变——本包只是渲染宿主，
// 不承载引擎语义。
//
// env 开关（不经命令行参数，同抽象统一层约定）：
//   MOONVIZ_DOC=<path>        渲染源 .mbt.md 路径；缺省依次回退
//                             examples/login-demo.mbt.md → 内置演示画板
//   MOONVIZ_DESKTOP_MODE=card 小程序卡形态（无边框 360×560）；缺省标准窗口
//   MOONVIZ_OUT=<path>        第二层兜底产物路径（缺省 moonviz-render.html）
//   MOONVIZ_SMOKE=1           无头自检（不出窗口：源读取/管线/渲染/兜底写读）

///|
/// FFI 边界：String → NUL 终止 UTF-8 Bytes（官方 C-FFI 约定）
fn c_bytes(s : String) -> Bytes {
  let utf8 = @utf8.encode(s)
  let arr = utf8.to_array()
  arr.push(0)
  Bytes::from_array(arr)
}

///|
#borrow(card, title, html)
extern "c" fn mv_open(
  card : Int,
  title : Bytes,
  html : Bytes,
) -> Int = "mv_open"

///|
extern "c" fn mv_app_pump() -> Unit = "mv_app_pump"

///|
extern "c" fn mv_ios_poll() -> String = "mv_ios_poll"

///|
extern "c" fn mv_app_running() -> Int = "mv_app_running"

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
extern "c" fn usleep(usec : Int) -> Unit = "usleep"

///|
fn getenv_str(name : String) -> String {
  mv_getenv(c_bytes(name))
}

///|
/// 渲染源解析：MOONVIZ_DOC 指向的 .mbt.md（唯一事实源）→ 仓库示例 → ""。
/// 读不到不算失败——宿主还有内置演示画板兜底。
fn load_source() -> String {
  let explicit = getenv_str("MOONVIZ_DOC")
  if explicit != "" {
    let src = mv_read_file(c_bytes(explicit))
    if src != "" {
      return src
    }
    println("[render] MOONVIZ_DOC 不可读: " + explicit + " → 按回退链继续")
  }
  mv_read_file(c_bytes("examples/login-demo.mbt.md"))
}

///|
/// 内置演示画板（无任何源文件时的双击自证）：登录页 + 点击 toast 交互。
/// 交互注册走引擎同一套 ⚡trigger→action 词汇表，导出 HTML 内嵌运行时承载。
fn builtin_demo() -> @core.Project {
  let p = @core.Project::new()
  let ab = p.create_artboard(name="登录", width=390.0, height=844.0)
  let page = @decl.prototype(name="登录", width=390.0, height=844.0)
  page.add(
    @decl.generic_node(
      id="welcome_title",
      component="heading",
      kind="text",
      width=@decl.fixed(280.0),
      height=@decl.fixed(36.0),
      x=55.0,
      y=150.0,
      text="MoonViz 自渲染演示",
      font_size=22.0,
      text_color="#1A1C1E",
    ),
  )
  page.add(
    @decl.generic_node(
      id="subtitle",
      component="body_text",
      kind="text",
      width=@decl.fixed(320.0),
      height=@decl.fixed(18.0),
      x=55.0,
      y=192.0,
      text="系统 webview 直接渲染 · 引擎核心全程 MoonBit",
      font_size=12.0,
      text_color="#9098A1",
    ),
  )
  page.add(
    @decl.generic_node(
      id="email_input",
      component="text_input",
      kind="rect",
      width=@decl.fixed(342.0),
      height=@decl.fixed(52.0),
      x=24.0,
      y=300.0,
      text="邮箱地址",
      fill="#F2F3F5",
      radius=12.0,
      font_size=14.0,
      text_color="#9CA3AF",
    ),
  )
  page.add(
    @decl.generic_node(
      id="password_input",
      component="text_input",
      kind="rect",
      width=@decl.fixed(342.0),
      height=@decl.fixed(52.0),
      x=24.0,
      y=364.0,
      text="密码",
      fill="#F2F3F5",
      radius=12.0,
      font_size=14.0,
      text_color="#9CA3AF",
    ),
  )
  page.add(
    @decl.generic_node(
      id="login_btn",
      component="button",
      kind="rect",
      width=@decl.fixed(342.0),
      height=@decl.fixed(52.0),
      x=24.0,
      y=440.0,
      text="登 录",
      fill="#4B6BFB",
      radius=12.0,
      font_size=16.0,
      text_color="#FFFFFF",
      font_weight="bold",
    ),
  )
  let built = page.build()
  match p.artboards.get(ab) {
    Some(meta) => meta.doc = built
    None => ()
  }
  let _ = p.add_interaction(
    artboard=ab,
    node_id="login_btn",
    trigger=@core.Tap,
    action=@core.ShowToast("引擎自渲染 · 交互运行时随 HTML 内嵌"),
  )
  p
}

///|
/// 渲染源 → 引擎 Project：显式源解析失败不致命（回退内置演示），保证
/// 宿主"总能渲染出点什么"——两层检测之外的最后一级兜底。
fn resolve_project() -> Result[@core.Project, String] {
  let src = load_source()
  if src != "" {
    match @decl.load_mbt_project(src) {
      Ok(mp) => return Ok(mp.project)
      Err(error) =>
        println("[render] 源解析失败（\{error}）→ 内置演示画板")
    }
  }
  Ok(builtin_demo())
}

///|
/// 第二层（系统兜底）：引擎直接渲染并返回结果。产物写盘 → 客户端 webview
/// 直接加载该文件（Tauri/Electron 只需提供 webview 来源，零渲染代码）；
/// 写盘也不可用 → 自包含 HTML 直接打到 stdout（渲染结果即返回值，可管道
/// 给任意浏览器/webview）。
fn fallback_render(html : String) -> Unit {
  let out = getenv_str("MOONVIZ_OUT")
  let path = if out == "" { "moonviz-render.html" } else { out }
  if mv_write_file(c_bytes(path), c_bytes(html)) == 0 {
    println(
      "{\"ok\":true,\"surface\":\"system\",\"artifact\":\"" +
      @core.json_escape(path) +
      "\",\"note\":\"any webview loads this file — 客户端只需提供 webview\"}",
    )
  } else {
    println(html)
  }
}

///|
/// 无头自检（不出窗口，CI 可跑）：源读取 → 引擎管线 → 自包含交互渲染 →
/// 兜底产物写读一致。webview 层（第一层）在窗口形态下人工/矩阵实测。
fn run_smoke() -> Bool {
  let src = load_source()
  if src == "" {
    println("[smoke] FAIL — 无可用渲染源")
    return false
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
  // 渲染源 → 引擎 Project（进程内自渲染：无 sidecar、无上层框架依赖）
  let html = match resolve_project() {
    Err(error) => {
      println("[render] FAIL — " + error)
      return
    }
    Ok(project) => project.export_html()
  }
  // —— 第一层：系统 webview（客户端只需提供 webview 来源；这里由宿主
  //    主动拉起，客户端嵌入场景等价于把同一份 HTML 交给它自己的 webview）——
  let card = if getenv_str("MOONVIZ_DESKTOP_MODE") == "card" { 1 } else { 0 }
  if mv_open(card, c_bytes("MoonViz 原型"), c_bytes(html)) == 0 {
    // 主循环：手动事件泵（控制权在 MoonBit）；交互由 HTML 内嵌运行时执行，
    // 事件通道为本契约预留的平台扩展口（tap/input/custom 统一 JSON schema）
    let mut ticks = 0
    let mut running = true
    while running {
      if mv_app_running() == 0 {
        running = false
        break
      }
      mv_app_pump()
      let ev = mv_ios_poll()
      if ev != "" {
        println("[render] 事件 " + ev)
      }
      usleep(16_000)
      ticks = ticks + 1
      if ticks > 3600 * 60 {
        running = false
      }
    }
    println(
      "{\"ok\":true,\"surface\":\"webview\",\"mode\":\"" +
      (if card == 1 { "card" } else { "window" }) +
      "\"}",
    )
    return
  }
  // —— 第二层：系统兜底——引擎直接渲染并返回结果 ——
  println("[render] webview 不可用 → 系统层兜底渲染")
  fallback_render(html)
}
