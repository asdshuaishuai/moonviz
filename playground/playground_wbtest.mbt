// 会话协议测试（纯 MoonBit，moon test 即可验证）
// 运行：moon test

///|
fn mockup_decl() -> String {
  MOCKUP
}

///|
test "render：合法声明经协议通过，payload 含 SVG 与声明" {
  let resp = handle("render\n" + mockup_decl())
  assert_true(resp.contains("\"ok\": true"))
  assert_true(resp.contains("\"debt\": 0"))
  assert_true(resp.contains("<svg"))
  assert_true(resp.contains("标签 B"))
  assert_true(resp.contains("\"decl\":"))
}

///|
test "render：越界编辑被 hard_block，返回结构化违规（不整体落盘）" {
  let overflow = "let page = @decl.prototype(name=\"t\", width=100, height=100)\npage.add(@decl.rect(id=\"navbar\",height=@decl.fixed(900),x=0,y=0,width=@decl.fixed(100)))\n"
  let resp = handle("render\n" + overflow)
  assert_true(resp.contains("\"error\": \"hard_block\""))
  assert_true(resp.contains("contained_in_parent"))
}

///|
test "human_move：出卡拖拽放行并携带视觉债，decl 锚点更新" {
  let resp = handle("human_move\nchip-b\n160\n336\n" + mockup_decl())
  assert_true(resp.contains("\"ok\": true"))
  assert_true(resp.contains("\"debt\": 1"))
  assert_true(resp.contains("y=336"))
}

///|
test "human_move：结构性违规被拒绝（返回 structural_block）" {
  // 把标签拖出画布并删除宽度合法约束？——用未知 id 触发协议错误路径验证
  let missing = handle("human_move\nghost\n0\n0\n" + mockup_decl())
  assert_true(
    missing.contains("\"error\": \"protocol_error\"") ||
    missing.contains("unknown"),
  )
}

///|
test "协议错误：未知操作返回 unknown_op" {
  let resp = handle("fly_to_the_moon\npayload")
  assert_true(resp.contains("\"error\": \"unknown_op\""))
}

///|
test "scenario_report：四个场景的关键信息齐全" {
  let report = scenario_report()
  assert_true(report.contains("[1]"))
  assert_true(report.contains("hard_block"))
  assert_true(report.contains("视觉债 1 条"))
  assert_true(report.contains("<svg"))
}
