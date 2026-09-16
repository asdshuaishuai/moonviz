///|
/// list-ops 漂移守卫：注册表 ↔ 分发器逐字对齐。
///
/// 背景：SKILL.md 语法块曾是 op 面唯一完整清单——照字面删块、从 help
/// 推导会静默丢失最新一批 op 的覆盖。本测试让注册表本身成为契约：
/// 1. 计数锚定：新增 op 必须同步分发器 + op_entries() + SKILL.md 三处；
/// 2. 每条注册 op 裸名打一遍分发器，错误必须是该 op 的 usage 串
///    （逐字匹配），而不是 mbt_operation_unsupported——漏注册、拼错、
///    usage 漂移一律红。
test "list-ops：注册表与分发器对齐" {
  let ops = op_entries()
  assert_eq(ops.length(), 25)
  let p = Project::new()
  for e in ops.iter() {
    let want = "mbt_operation_usage:" + e.usage
    match apply_operation(p, e.op) {
      Err(msg) =>
        assert_true(
          msg == want,
          msg="op \{e.op} 分发器 usage 与注册表不一致: \{msg}",
        )
      Ok(_) => assert_false(true, msg="裸 op 名不应成功执行: \{e.op}")
    }
  }
  // 守卫自身有效性：非法 op 必须返回 unsupported
  match apply_operation(p, "definitely_not_an_op") {
    Err(msg) => assert_true(msg.contains("mbt_operation_unsupported"))
    Ok(_) => assert_false(true)
  }
}
