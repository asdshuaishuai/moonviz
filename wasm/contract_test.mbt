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
  let save = session_save(h)
  assert_true(save.contains("project_json"))
  let h2 = session_open_project_json(extract_project_json(save))
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
/// 从 session_save 的信封里剥出 project_json 字段值（测试辅助）。
fn extract_project_json(envelope : String) -> String {
  let marker = "\"project_json\":\""
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
