///|
/// wasm 导出契约测试（issues #2/#3/#4/#1 回归锚）。
///
/// 每条都源自真实下游问题：
/// - #2 session_apply_agent 必须走 AgentGate（此前逐字复制 human 版本，
///   越界节点 ok:true 落库、Agent 硬门被架空）
/// - #3 export_html 错误信封缺引号 → 非法 JSON
/// - #4A 已关句柄必须报 invalid_session_handle 而非域错误
/// - #4B session_save 输出必须能回灌 session_open_project_json
/// - #4C 只读导出统一 {ok:true,data:...} 信封
/// - #1 session_count 可观测泄漏（open 配对 close）
const SEED : String = "---\nmoonviz:\n  backend: native\nmoonviz:\n  format: visual-document\n  revision: 2\n  title: T\n  entry: w\n  artboards:\n    - w\n---\n\n# T\n\n<!-- moonviz:artboard w -->\n```mbt\n///| @moonviz:visual w\nfn visual_w() -> @decl.Prototype {\n  let page = @decl.prototype(name=\"w\", width=390.0, height=844.0)\n  page.add(@decl.button(id=\"btn\", width=@decl.fixed(120.0), height=@decl.fixed(44.0), x=20.0, y=20.0, label=\"OK\"))\n  page\n}\n```\n"

///|
test "契约：全部导出 × 非法输入 → 合法 JSON（issue #3）" {
  let bad_inputs = [ "not a doc", "", "{\"x\":1" ]
  for bad in bad_inputs {
    for export_fn in [ "render_mbt", "validate_mbt", "apply_agent_op", "apply_human_op", "export_html" ] {
      let out = match export_fn {
        "render_mbt" => render_mbt(bad)
        "validate_mbt" => validate_mbt(bad)
        "apply_agent_op" => apply_agent_op(bad, "create x")
        "apply_human_op" => apply_human_op(bad, "create x")
        "export_html" => export_html(bad)
        _ => "{}"
      }
      // 合法性近似判定：成功信封或 {"ok":false,"error":"..."} 形态
      // （此前 export_html 错误分支输出 error 值缺引号，非法 JSON）
      let ok_shape = out.contains("\"ok\":false,\"error\":\"") || out.contains("\"ok\":true")
      assert_true(ok_shape, msg="export \{export_fn} 非法输入返回非法 JSON: \{out}")
    }
    let h = session_open(bad)
    let _ = assert_true(h < 0, msg="非法文档不应打开会话")
  }
}

///|
test "契约：session_apply_agent 走 AgentGate（issue #2）" {
  let h = session_open(SEED)
  assert_true(h >= 0)
  // 越界节点：x=380 + 宽 120 > 390 → AgentGate 必须整体拒绝
  let op = "place w button huge_b - 380 806"
  let agentless = apply_agent_op(SEED, op)
  assert_false(agentless.contains("\"ok\":true"), msg="无状态 agent 面应拒绝越界")
  let r = session_apply_agent(h, op)
  assert_true(r.contains("mbt_gate_block") || r.contains("\"ok\":false"),
    msg="session_apply_agent 必须拒绝违规（issue #2）: \{r}")
  // 节点不得落库
  let q = session_query_nodes(h, "w")
  assert_false(q.contains("huge_b"), msg="被拒节点不应存在")
  let _ = session_close(h)
}



///|
test "契约：已关句柄报 invalid_session_handle（issue #4A）" {
  let h = session_open(SEED)
  assert_true(session_close(h))
  // 关后再用：统一 invalid_session_handle，而不是空项目上的域错误
  let r = session_lint(h, "w")
  assert_true(r.contains("invalid_session_handle"), msg="已关句柄应报 invalid_session_handle: \{r}")
  let _ = assert_false(session_close(h), msg="重复 close 应返回 false")
}

///|
test "契约：save → open_project_json 回灌（issue #4B）" {
  let h = session_open(SEED)
  let _ = session_apply_human(h, "update w btn text=持久化")
  // 统一信封 {ok:true,data:"<project_json>"}——data 是转义后的 JSON 字符串
  let save = session_save(h)
  let h2 = session_open_project_json(extract_data(save))
  assert_true(h2 >= 0, msg="project_json 应回灌打开会话")
  let nodes = session_query_nodes(h2, "w")
  assert_true(nodes.contains("持久化") || nodes.contains("btn"), msg="快照应还原节点")
}

///|
test "契约：session_count 可观测泄漏（issue #1）" {
  let before = session_count()
  let h1 = session_open(SEED)
  let h2 = session_open(SEED)
  assert_eq(session_count(), before + 2)
  let _ = session_close(h1)
  assert_eq(session_count(), before + 1)
  let _ = session_close(h2)
  assert_eq(session_count(), before)
}

///|
/// 从 session_save 统一信封 {ok,data:"..."} 剥出 data 值（测试辅助）。
fn extract_data(envelope : String) -> String {
  let marker = "\"data\":\""
  let i = match envelope.find(marker) {
    Some(x) => x + marker.length()
    None => return ""
  }
  let rest = envelope.substring(start=i)
  // json_escape 后的值：扫描到未转义的 " 为止
  let sb = StringBuilder()
  let chars : Array[Char] = []
  for c in rest.iter() {
    chars.push(c)
  }
  let mut j = 0
  while j < chars.length() {
    let c = chars[j]
    if c == '\\' {
      // 反斜杠：跳过转义符，取下一字符原样
      if j + 1 < chars.length() {
        sb.write_char(chars[j + 1])
      }
      j = j + 2
      continue
    }
    if c == '"' {
      break
    }
    sb.write_char(c)
    j = j + 1
  }
  sb.to_string()
}


///|
/// 写路径（issue：P0-2）：分块字符串槽 → *_in 变体与对应无状态导出等价。
/// 槽是全公开 API 的 UTF-8 分块压入（GC 分配原语不可达）。
test "契约：字符串槽写路径与无状态导出等价" {
  let seed = "---\nmoonviz:\n  backend: native\nmoonviz:\n  format: visual-document\n  revision: 2\n  title: T\n  entry: w\n  artboards:\n    - w\n---\n\n# T\n\n<!-- moonviz:artboard w -->\n```mbt\n///| @moonviz:visual w\nfn visual_w() -> @decl.Prototype {\n  let page = @decl.prototype(name=\"w\", width=390.0, height=844.0)\n  page.add(@decl.button(id=\"btn\", width=@decl.fixed(120.0), height=@decl.fixed(44.0), x=20.0, y=20.0, label=\"OK\"))\n  page\n}\n```\n"
  // 分块压入（4 字节小端一块）
  in_reset()
  let chars = seed.to_array()
  let mut i = 0
  while i < chars.length() {
    // 简化：逐字符 charcode 压入，n=4 时一次塞 4 字节
    let c = chars[i].to_int()
    in_push(c, 1)
    i = i + 1
  }
  assert_true(in_len() > 0)
  let v = render_mbt_in()
  assert_true(v.contains("\"ok\":true"), msg="render_mbt_in 应成功: \{v}")
  assert_true(v.contains("\"w\""), msg="render_mbt_in 应含画板 w")
  // apply_agent_op_in：主槽 MBT + 辅槽 op
  in_reset()
  for c in seed.to_array() {
    in_push(c.to_int(), 1)
  }
  arg_reset()
  // ASCII op：逐字节压入（n=1），与宿主 4 字节分块等价但更简单
  let op = "update w btn text=slot-protocol"
  for c in op.to_array() {
    arg_push(c.to_int(), 1)
  }
  let r = apply_agent_op_in()
  assert_true(r.contains("\"ok\":true"), msg="apply_agent_op_in 应成功: \{r}")
  assert_true(r.contains("slot-protocol"), msg="apply_agent_op_in 应含新文字: \{r}")
  // session_open_in + session_apply_human_in
  in_reset()
  for c in seed.to_array() {
    in_push(c.to_int(), 1)
  }
  let h = session_open_in()
  assert_true(h >= 0, msg="session_open_in 应成功")
  arg_reset()
  let fill_op = "update w btn fill=#123456"
  for c in fill_op.to_array() {
    arg_push(c.to_int(), 1)
  }
  let sr = session_apply_human_in(h)
  assert_true(sr.contains("\"ok\":true"), msg="session_apply_human_in 应成功")
  assert_true(sr.contains("#123456"))
  // validate_mbt_in / export_html_in
  in_reset()
  for c in seed.to_array() {
    in_push(c.to_int(), 1)
  }
  assert_true(validate_mbt_in().contains("\"ok\":true"))
  assert_true(export_html_in().contains("\"ok\":true"))
}

///|
test "契约：session_count 观测泄漏（issue #1）" {
  let before = session_count()
  let h1 = session_open(SEED)
  let h2 = session_open(SEED)
  assert_eq(session_count(), before + 2)
  let _ = session_close(h1)
  assert_eq(session_count(), before + 1)
  let _ = session_close(h2)
  assert_eq(session_count(), before)
}

///|
test "契约：已关句柄报 invalid_session_handle（issue #4A）" {
  let h = session_open(SEED)
  let _ = session_close(h)
  let r = session_lint(h, "w")
  assert_true(r.contains("invalid_session_handle"), msg="已关句柄应报 invalid_session_handle: \{r}")
  let _ = assert_false(session_close(h), msg="重复 close 应返回 false")
}
///|
test "契约：protest 畸形断言计 FAIL 不假 PASS" {
  let seed = "---\nmoonviz:\n  backend: native\nmoonviz:\n  format: visual-document\n  revision: 2\n  title: T\n  entry: w\n  artboards:\n    - w\n---\n\n# T\n\n<!-- moonviz:artboard w -->\n```mbt\n///| @moonviz:visual w\nfn visual_w() -> @decl.Prototype {\n  let page = @decl.prototype(name=\"w\", width=390.0, height=844.0)\n  page\n}\n```\n"
  let r = @core.run_protest_script(session_get_project_for_test(), "w", "nvoiol; tap:1:2")
  assert_true(r.contains("\"failed\":2"), msg="畸形断言应计 failed: \{r}")
  assert_true(r.contains("\"status\":\"FAIL\""))
}

///|
/// 测试辅助：取共享 seed 的会话 Project（run_protest_script 需要 Project）。
fn session_get_project_for_test() -> @core.Project {
  let p = @core.Project::new()
  let seed = "---\nmoonviz:\n  backend: native\nmoonviz:\n  format: visual-document\n  revision: 2\n  title: T\n  entry: w\n  artboards:\n    - w\n---\n\n# T\n\n<!-- moonviz:artboard w -->\n```mbt\n///| @moonviz:visual w\nfn visual_w() -> @decl.Prototype {\n  let page = @decl.prototype(name=\"w\", width=390.0, height=844.0)\n  page\n}\n```\n"
  match @decl.load_mbt_project(seed) {
    Ok(m) => {
      p.replace_with(m.project)
      p
    }
    Err(_) => p
  }
}

///|
test "契约：session_auto_fix 无违规 → detail 为合法空数组（issue #10）" {
  let h = session_open(SEED)
  let out = session_auto_fix(h, "w")
  // 此前 fixes=0 时输出 "detail":}}（空 join 无括号）——宿主 JSON.parse 直接抛异常
  assert_true(out.contains("\"fixes\":0,\"detail\":[]"), msg=out)
  assert_true(out.contains("\"ok\":true"), msg=out)
  let _ = session_close(h)
}

///|
test "契约：session_history init/commit/undo/redo/checkout（issue #11）" {
  let h = session_open(SEED)
  // init
  let r0 = session_history(h, "init w")
  assert_true(r0.contains("\"op\":\"history-init\""), msg=r0)
  // commit 一版
  let r1 = session_apply_agent(h, "update w btn text=V2")
  assert_true(r1.contains("\"ok\":true"), msg="agent op 应过门: " + r1)
  let rc = session_history(h, "commit agent-edit")
  assert_true(rc.contains("\"op\":\"history-commit\"") && rc.contains("\"rev\":1"), msg=rc)
  // undo → 应回到初版（btn 文案还原）
  let ru = session_history(h, "undo")
  assert_true(ru.contains("\"op\":\"history-undo\""), msg=ru)
  // 宿主持久化契约：undo/redo/checkout 必须回传 canonical mbt
  // （与 session_apply_* 同形），否则按 apply 契约存盘的宿主会丢时间旅行
  assert_true(ru.contains("\"mbt\":\""), msg="undo 应回传 mbt: " + ru)
  let q1 = session_query_nodes(h, "w")
  assert_true(q1.contains("OK"), msg="undo 后 btn 应回到初始文案 OK: " + q1)
  // redo
  let rr = session_history(h, "redo")
  assert_true(rr.contains("\"op\":\"history-redo\""), msg=rr)
  let q2 = session_query_nodes(h, "w")
  assert_true(q2.contains("V2"), msg="redo 后 btn 应为 V2: " + q2)
  // checkout rev0
  let rk = session_history(h, "checkout 0")
  assert_true(rk.contains("\"op\":\"history-checkout\""), msg=rk)
  let q3 = session_query_nodes(h, "w")
  assert_true(q3.contains("OK"), msg="checkout 0 应回初版: " + q3)
  // log / diff
  let rl = session_history(h, "log")
  assert_true(rl.contains("\"op\":\"history-log\""), msg=rl)
  let rd = session_history(h, "diff 0 1")
  assert_true(rd.contains("\"op\":\"history-diff\""), msg=rd)
  let _ = session_close(h)
}

///|
test "契约：session_history 已关句柄拒绝（issue #11 × #4A）" {
  let h = session_open(SEED)
  let _ = session_history(h, "init w")
  let _ = session_close(h)
  let r = session_history(h, "undo")
  assert_true(r.contains("invalid_session_handle"), msg=r)
}

///|
test "契约：unflow 经 agent 门可达（issue #12）" {
  let h = session_open(SEED)
  let _ = session_apply_agent(h, "create detail")
  let r1 = session_apply_agent(h, "flow w detail btn")
  assert_true(r1.contains("\"ok\":true"), msg="flow 应过门: " + r1)
  let r2 = session_apply_agent(h, "unflow w detail btn")
  assert_true(r2.contains("\"ok\":true"), msg="unflow 应过门: " + r2)
  let f = session_flows(h)
  assert_true(f.contains("detail") == false, msg="边应已删: " + f)
  let _ = session_close(h)
}

///|
test "契约：全部内置模板 × AgentGate 零债（issue #14 回归锚）" {
  let tpl = ["login", "signup", "dashboard", "profile", "settings", "list_detail", "onboarding", "empty_state", "web_landing", "web_login", "web_dashboard", "pc_app", "adaptive_landing", "login_v2"]
  let seed_mbt = SEED
  for t in tpl {
    let out = apply_agent_op(seed_mbt, "template \{t} __t_\{t}")
    assert_true(
      out.contains("\"ok\":true"),
      msg="模板 \{t} 被 AgentGate 拒绝: \{out}",
    )
  }
}

