///|
/// 漂移守卫：list_tools()（core/agent_api.mbt 单一事实源）注册的每个工具
/// 都必须在 mcp execute_tool 有对应分支。此前 ops_registry_wbtest 只锚定
/// op_entries ↔ apply_operation，新增工具漏写 MCP 臂会全绿通过、运行时
/// tools/call 才炸——本测试让漏臂当场红。空参数逐个调用：已注册臂对空参
/// 统一返回各自的 missing/error 信封，唯独漏臂落 _ => unknown_tool。
test "MCP：list_tools 注册表与 execute_tool 分支对齐" {
  for t in @core.list_tools().iter() {
    let line = "{\"jsonrpc\":\"2.0\",\"id\":1,\"method\":\"tools/call\",\"params\":{\"name\":\"" + t.name + "\",\"arguments\":{}}}"
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
