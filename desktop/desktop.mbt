// MoonViz Desktop Shell — Smart UX 桌面级渲染（系统 webview + MoonBit 薄壳）
// 形态：MOONVIZ_DESKTOP_MODE=card（小程序卡级别：无边框浮动）/ 缺省标准窗口
// 模式：MOONVIZ_SMOKE=1（无头自检：引擎桥 + 结构 diff + 节点片段，不出窗口）

///|
/// FFI 边界：String → NUL 终止 UTF-8 Bytes（官方 C-FFI 约定）
fn c_bytes(s : String) -> Bytes {
  let utf8 = @utf8.encode(s)
  let arr = utf8.to_array()
  arr.push(0)
  Bytes::from_array(arr)
}

///|
#borrow(path)
extern "c" fn mv_engine_spawn(path : Bytes) -> Int = "mv_engine_spawn"

///|
#borrow(line)
extern "c" fn mv_engine_send(line : Bytes) -> Int = "mv_engine_send"

///|
extern "c" fn mv_engine_recv() -> String = "mv_engine_recv"

///|
#borrow(card, title, html)
extern "c" fn mv_open(
  card : Int,
  title : Bytes,
  html : Bytes,
) -> Int = "mv_open"

///|
#borrow(js)
extern "c" fn mv_eval(js : Bytes) -> Unit = "mv_eval"

///|
extern "c" fn mv_app_pump() -> Unit = "mv_app_pump"

///|
extern "c" fn mv_ios_poll() -> String = "mv_ios_poll"

///|
#borrow(name)
extern "c" fn mv_getenv(name : Bytes) -> String = "mv_getenv"

///|
extern "c" fn usleep(usec : Int) -> Unit = "usleep"

///|
fn getenv_str(name : String) -> String {
  mv_getenv(c_bytes(name))
}

///|
fn cli_path() -> String {
  let p = getenv_str("MOONVIZ_CLI_BIN")
  if p != "" {
    p
  } else {
    "_build/native/release/build/cli/cli.exe"
  }
}

///|
/// 引擎一条命令 → 回执 JSON。启动横幅不走 flush，会与首条回执一起
/// 到达——读行直到 '{' 开头（回执恒为 JSON 对象），噪声自然跳过。
fn engine_cmd(line : String) -> String {
  let _ = mv_engine_send(c_bytes(line))
  let mut noise = 0
  while noise < 64 {
    let raw = mv_engine_recv()
    // 启动横幅也是 JSON（{"moonviz":"cli",…}）——按指纹跳过
    if raw.contains("\"moonviz\":\"cli\"") {
      noise = noise + 1
    } else {
      return raw
    }
  }
  "{\"error\":\"engine_no_reply\"}"
}

///|
/// Smart UX host 页面：空容器 + 底版注入 + 局部 patch 运行时 + 点击上报
fn host_html() -> String {
  "<!DOCTYPE html><html><head><meta charset=\"utf-8\"><style>" +
  "body{margin:0;background:#F6F7F9;font-family:-apple-system,'PingFang SC',sans-serif}" +
  "#mv{width:100%;height:100vh}" +
  "</style></head><body><div id=\"mv\"></div><script>" +
  "window.__mv_base=function(svg){document.getElementById('mv').innerHTML=svg};" +
  "window.__mv_patch=function(id,frag){var old=document.getElementById('n_'+id);" +
  "if(!old)return;var t=document.createElement('template');t.innerHTML=frag.trim();" +
  "var node=t.content.firstChild;old.replaceWith(node)};" +
  "document.addEventListener('click',function(ev){var g=ev.target.closest('g[id]');" +
  "if(g&&window.webkit&&window.webkit.messageHandlers.mv){" +
  "window.webkit.messageHandlers.mv.postMessage(JSON.stringify({t:'tap',id:g.id.slice(2)}))}});" +
  "</script></body></html>"
}

///|
/// 演示数据树（轮转值；生产：personal agent / 宿主注入）
fn demo_data(round : Int) -> String {
  let grades = ["A", "A", "B+", "A", "B", "A+", "A"]
  let grade = grades[round % grades.length()]
  let score = 88 + (round * 3) % 12
  "{\"app\":{\"title\":\"MoonViz 卡片\",\"score\":\{score},\"grade\":\"\{grade}\",\"stamp\":\"刷新 #\{round + 1}\"}}"
}

///|
/// 提取 set_data diff 中的 changed 节点 id 清单（{"keys":N,"changed":[{"id":"x",…}]}）
fn parse_changed_ids(diff_json : String) -> Array[String] {
  let ids : Array[String] = []
  let key = "\"id\":\""
  let n = diff_json.length()
  let key_len = key.length()
  let mut from = 0
  while from + key_len <= n {
    match diff_json.find(key) {
      None => break
      Some(i) => {
        if i < from {
          from = from + 1
          continue
        }
        let s = i + key_len
        let mut j = s
        while j < n && diff_json.get_char(j) != Some('"') {
          j = j + 1
        }
        if j > s {
          ids.push(diff_json.substring(start=s, end=j).to_string())
        }
        from = j
      }
    }
  }
  ids
}

///|
/// 增量刷新：data（changed）→ 逐节点 render-node-svg → mv_eval 局部 patch
fn incremental_refresh(ab : String, round : Int) -> Bool {
  let diff = engine_cmd("data " + demo_data(round))
  if diff.contains("\"error\"") {
    println("[desktop] set_data 失败: " + diff)
    return false
  }
  for id in parse_changed_ids(diff).iter() {
    let frag = engine_cmd("render-node-svg " + ab + " " + id)
    let js = "window.__mv_patch('" + id + "'," + frag + ")"
    mv_eval(c_bytes(js))
  }
  true
}

///|
/// 无头自检（不出窗口）：引擎桥 / 结构 diff / 节点片段 三件套
fn run_smoke() -> Bool {
  let boards = engine_cmd("list")
  if !boards.contains("[") {
    println("[smoke] FAIL — 引擎桥 list: " + boards)
    return false
  }
  println("[smoke] 引擎桥 OK: " + boards)
  for op in [
    "create home 400 200",
    "place home body_text title - 20 16 360 30",
    "update home title text={{app.title}}",
    "place home body_text score - 20 60 360 24",
    "update home score text={{app.score}} 分（{{app.grade}}）",
  ].iter() {
    let r = engine_cmd(op)
    if r.contains("\"error\"") {
      println("[smoke] FAIL — boot op「" + op + "」: " + r)
      return false
    }
  }
  let d1 = engine_cmd("data {\"app\":{\"title\":\"T1\",\"score\":90,\"grade\":\"A\"}}")
  if !d1.contains("\"changed\"") {
    println("[smoke] FAIL — set_data 无 changed 清单: " + d1)
    return false
  }
  let f = engine_cmd("render-node-svg home title")
  if !f.contains("T1") || !f.contains("n_title") {
    println("[smoke] FAIL — 节点片段: " + f)
    return false
  }
  println("[smoke] PASS — 引擎桥/diff/节点片段全通")
  true
}

///|
fn boot_ops() -> Array[String] {
  [
    "create home 400 200",
    "place home body_text title - 20 16 360 30",
    "update home title text={{app.title}}",
    "place home body_text score - 20 60 360 24",
    "update home score text={{app.score}} 分（{{app.grade}}）",
    "place home body_text stamp - 20 96 360 20",
    "update home stamp text={{app.stamp}}",
  ]
}

///|
fn main {
  let mode_card = getenv_str("MOONVIZ_DESKTOP_MODE") == "card"
  let smoke = getenv_str("MOONVIZ_SMOKE") == "1"
  let cli = cli_path()
  if mv_engine_spawn(c_bytes(cli)) != 0 {
    println("[desktop] FAIL — 无法启动引擎 sidecar: " + cli + "（可设 MOONVIZ_CLI_BIN）")
    return
  }
  if smoke {
    let _ = run_smoke()
    return
  }
  // 引导演示文档 + 初始数据
  for op in boot_ops().iter() {
    let _ = engine_cmd(op)
  }
  let _ = engine_cmd("data " + demo_data(0))
  let base = engine_cmd("export-svg home")
  // 窗口/卡片 + 宿主页（底版随后经 eval 注入）
  let card = if mode_card { 1 } else { 0 }
  if mv_open(card, c_bytes("MoonViz Smart UX"), c_bytes(host_html())) != 0 {
    println("[desktop] FAIL — webview 创建失败")
    return
  }
  mv_eval(c_bytes("window.__mv_base(" + base + ")"))
  // 主循环：手动事件泵 + 点击事件消费 + 周期增量刷新（演示：数据轮转；
  // 生产：personal agent / 宿主经 data 命令推送）
  let mut round = 0
  let mut tick = 0
  let mut running = true
  while running {
    mv_app_pump()
    let ev = mv_ios_poll()
    if ev.contains("\"tap\"") {
      println("[desktop] tap 事件（交互执行列入 M-S3）")
    }
    tick = tick + 1
    if tick % 60 == 0 {
      round = round + 1
      let _ = incremental_refresh("home", round)
    }
    usleep(16_000)
    if tick > 3600 * 60 {
      running = false
    }
  }
}
