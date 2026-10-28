///|
/// list-ops 漂移守卫：注册表 ↔ 分发器逐字对齐。
///
/// 背景：SKILL.md 语法块曾是 op 面唯一完整清单——照字面删块、从 help
/// 推导会静默丢失最新一批 op 的覆盖。本测试让注册表本身成为契约：
/// 1. 计数锚定：新增 op 必须同步分发器 + op_entries() + SKILL.md 三处；
/// 2. 每条注册 op 裸名打一遍分发器，错误必须是该 op 的 usage 串
///    （逐字匹配），而不是 mbt_operation_unsupported——漏注册、拼错、
///    usage 漂移一律红；
/// 3. Agent 可见的 list_ops 工具描述（core/agent_api.mbt）必须内插
///    op_entries().length() 与注册表同源——回退成字面量后，下次加 op
///    即与本守卫同红。
test "list-ops：注册表与分发器对齐" {
  let ops = op_entries()
  assert_eq(ops.length(), 27)
  // 工具面同源：list_ops 描述内插注册表条数，不写死数字
  let want_desc = "all \{ops.length()} mutating ops"
  let mut desc_ok = false
  for t in list_tools().iter() {
    if t.name == "list_ops" {
      assert_true(
        t.description.contains(want_desc),
        msg="list_ops 工具描述与注册表条数脱钩: \{t.description}",
      )
      desc_ok = true
    }
  }
  assert_true(desc_ok, msg="list_tools 未注册 list_ops")
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

///|
/// update 防御对称性（此前漏 "=" 的 token 与未识别 key 都被静默吞掉，
/// Agent 收到 ok:true/fields:0 却什么都没改——与 restyle 的
/// no_kv_pairs 防御不对称）。
test "update：漏 = token 与未识别 key 显式报错" {
  let p = Project::new()
  let _ = p.create_artboard(name="u")
  let _ = p.place_component(artboard="u", component_id="button", instance_id="b")
  // 漏 "="：此前静默跳过
  match apply_operation(p, "update u b text") {
    Err(e) => assert_true(e.contains("mbt_operation_invalid_kv:text"))
    Ok(_) => assert_false(true, msg="漏 = 的 token 应报错而非静默成功")
  }
  // typo key（colr=）：此前 fields:0 仍 ok:true
  match apply_operation(p, "update u b colr=#FF0000") {
    Err(e) => assert_true(e.contains("mbt_operation_unknown_key:colr"))
    Ok(_) => assert_false(true, msg="未识别 key 应报错而非 fields:0 成功")
  }
  // 合法键照常生效（apply_operation 的 Ok 无载荷，断言落到文档状态）
  match apply_operation(p, "update u b text=hi radius=8") {
    Ok(_) => ()
    Err(e) => assert_false(true, msg=e)
  }
  match p.artboards.get("u") {
    Some(ab) =>
      match ab.doc.nodes.get("b") {
        Some(n) => {
          assert_eq(n.text, "hi")
          assert_eq(n.style.corner_radius, 8.0)
        }
        None => assert_true(false)
      }
    None => assert_true(false)
  }
}

///|
/// state 臂同防御：未知 key / 漏 = token 报错，合法键定义成功。
test "state：未知 key 与漏 = token 显式报错" {
  let p = Project::new()
  let _ = p.create_artboard(name="s")
  let _ = p.place_component(artboard="s", component_id="button", instance_id="b")
  match apply_operation(p, "state s b pressed colr=#FF0000") {
    Err(e) => assert_true(e.contains("mbt_operation_unknown_key:colr"))
    Ok(_) => assert_false(true, msg="state 未识别 key 应报错")
  }
  match apply_operation(p, "state s b pressed fill") {
    Err(e) => assert_true(e.contains("mbt_operation_invalid_kv:fill"))
    Ok(_) => assert_false(true, msg="state 漏 = token 应报错")
  }
  match apply_operation(p, "state s b pressed fill=#1E3FA8") {
    Ok(_) => ()
    Err(e) => assert_false(true, msg=e)
  }
  // state 定义真实落表（apply_operation 的 Ok 无载荷，断言落到状态表）
  match p.node_states.get("b") {
    Some(def) => assert_true(def.states.contains("pressed"))
    None => assert_true(false)
  }
}

///|
/// place 参数解析已提为 core 单一实现（cli_exec place 命令与
/// apply_operation place 臂共用 parse_place_args）——「双路线解析
/// 必须一致」由结构性兑现，本测试锚定其行为契约。
test "parse_place_args：w/h 槽 / - 占位 / k=v 反转义 / 非法 token" {
  // 完整形态：variant x y w h k=v...
  let full = parse_place_args([
    "place",
    "ab",
    "button",
    "b1",
    "round",
    "10",
    "20",
    "120",
    "44",
    "label=确 定",
    "gap=8",
  ])
  assert_eq(full.variant, "round")
  assert_eq(full.x, 10.0)
  assert_eq(full.y, 20.0)
  assert_eq(full.w, 120.0)
  assert_eq(full.h, 44.0)
  assert_eq(full.error, "")
  assert_eq(full.args.get("label"), Some("确 定"))
  assert_eq(full.args.get("gap"), Some("8"))
  // "-" 占位：默认 variant 与默认尺寸，k=v 照常收集
  let dash = parse_place_args([
    "place",
    "ab",
    "button",
    "b2",
    "-",
    "0",
    "0",
    "-",
    "tone=dark",
  ])
  assert_eq(dash.variant, "")
  assert_eq(dash.w, 0.0)
  assert_eq(dash.h, 0.0)
  assert_eq(dash.error, "")
  assert_eq(dash.args.get("tone"), Some("dark"))
  // k=v 值反转义（split_cmd 转义协议；k=v 从槽 8 起，前置槽用 - 占位）
  let esc = parse_place_args([
    "place",
    "ab",
    "button",
    "b3",
    "-",
    "0",
    "0",
    "-",
    "text=a\\,b",
  ])
  assert_eq(esc.args.get("text"), Some("a,b"))
  // 无 "=" 非数字 token → place_invalid_arg
  let bad = parse_place_args(["place", "ab", "button", "b4", "-", "0", "0", "xx"])
  assert_eq(bad.error, "place_invalid_arg:xx")
}
