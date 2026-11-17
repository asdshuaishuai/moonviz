///|
/// 漂移守卫：list_tools()（core/agent_api.mbt 单一事实源）注册的每个工具
/// 都必须在 mcp execute_tool 有对应分支。此前 ops_registry_wbtest 只锚定
/// op_entries ↔ apply_operation，新增工具漏写 MCP 臂会全绿通过、运行时
/// tools/call 才炸——本测试让漏臂当场红。空参数逐个调用：已注册臂对空参
/// 统一返回各自的 missing/error 信封，唯独漏臂落 _ => unknown_tool。
test "MCP：list_tools 注册表与 execute_tool 分支对齐" {
  for t in @core.list_tools().iter() {
    let line = "{\"jsonrpc\":\"2.0\",\"id\":1,\"method\":\"tools/call\",\"params\":{\"name\":\"" +
      t.name +
      "\",\"arguments\":{}}}"
    let resp = execute_tool(line, t.name)
    assert_true(
      !resp.contains("unknown_tool"),
      msg="工具 \{t.name} 未在 execute_tool 注册分支: \{resp}",
    )
  }
  // 守卫自身有效性：未注册工具名必须落 unknown_tool（否则本测试空转）
  let ghost = execute_tool(
    "{\"jsonrpc\":\"2.0\",\"id\":1,\"method\":\"tools/call\",\"params\":{\"name\":\"definitely_not_a_tool\",\"arguments\":{}}}",
    "definitely_not_a_tool",
  )
  assert_true(ghost.contains("unknown_tool"))
}

///|
/// H5 契约（MCP 通道）：export_html/export_svg 的 preview 内嵌多行文本，
/// 必须过 json_escape——裸插会把真实换行写进信封 JSON 字符串（控制字符
/// 非法），宿主解析 content[0].text 即炸。断言信封单行无裸换行、且换行
/// 以 \n 转义形态在场（守卫转义真的生效而非 preview 恰好无换行）。
test "MCP：export_html/export_svg 信封为合法 JSON（preview 过转义）" {
  let _ = g_project.create_artboard(name="h5a")
  let resp_h = execute_tool(
    "{\"jsonrpc\":\"2.0\",\"id\":1,\"method\":\"tools/call\",\"params\":{\"name\":\"export_html\",\"arguments\":{}}}",
    "export_html",
  )
  assert_true(resp_h.contains("\"ok\":true,\"html_length\":"))
  assert_false(
    resp_h.contains("\n"),
    msg="html 信封含裸换行（非法 JSON）",
  )
  assert_true(resp_h.contains("\\n"), msg="preview 换行应为转义形态")
  let resp_s = execute_tool(
    "{\"jsonrpc\":\"2.0\",\"id\":2,\"method\":\"tools/call\",\"params\":{\"name\":\"export_svg\",\"arguments\":{\"artboard\":\"h5a\"}}}",
    "export_svg",
  )
  assert_true(resp_s.contains("\"ok\":true,\"svg_length\":"))
  // svg preview 前 100 字符可能恰好无换行，核心契约是信封内无裸换行
  //（转义形态在场已由 html 侧断言守卫）
  assert_false(
    resp_s.contains("\n"),
    msg="svg 信封含裸换行（非法 JSON）",
  )
}
