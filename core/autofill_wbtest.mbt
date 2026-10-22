///|
/// missing → autofill 闭环：报告物化为节点、检测归零（幂等）、
/// 状态类缺失跳过、auto_fix 清偿布局。
test "autofill：报告驱动补缺与幂等" {
  let p = Project::new()
  // 受控构造 auth 语义页：heading + 双输入 + 按钮（登录模板自带
  // 忘记/注册链接，检测器不会报它们——补缺测试要从不满足的态出发）
  let _ = p.create_artboard(name="login")
  let _ = p.place_component(
    artboard="login",
    component_id="heading",
    instance_id="title",
    x=95.0,
    y=120.0,
  )
  let _ = p.edit_node(
    artboard="login",
    node_id="title",
    kvs=[("text", "登录")],
  )
  let _ = p.place_component(
    artboard="login",
    component_id="text_input",
    instance_id="email",
    x=24.0,
    y=200.0,
  )
  let _ = p.place_component(
    artboard="login",
    component_id="text_input",
    instance_id="password",
    x=24.0,
    y=270.0,
  )
  let _ = p.place_component(
    artboard="login",
    component_id="button",
    instance_id="submit",
    x=24.0,
    y=340.0,
  )
  let _ = p.edit_node(
    artboard="login",
    node_id="submit",
    kvs=[("text", "登 录")],
  )
  // 补缺前：auth 三缺（忘记/注册/记住）+ 通用加载态
  let before = match p.infer_missing(artboard="login") {
    Ok(j) => j
    Err(_) => "{}"
  }
  assert_true(before.contains("forgot_password"))
  assert_true(before.contains("remember_me"))
  let json = match p.autofill_missing(artboard="login") {
    Ok(j) => j
    Err(_) => ""
  }
  assert_true(json.contains("\"op\":\"autofill\""))
  assert_true(json.contains("\"node\":\"forgot_password\""))
  assert_true(json.contains("\"node\":\"remember_me\""))
  // 补缺物料的文本满足检测器关键词 → after 归零
  match p.artboards.get("login") {
    None => assert_true(false)
    Some(meta) => {
      let after = match p.infer_missing(artboard="login") {
        Ok(j) => j
        Err(_) => "{}"
      }
      assert_true(after.contains("\"missing_count\":0"))
      // 物化的节点真实存在
      assert_true(meta.doc.has("forgot_password"))
      assert_true(meta.doc.has("remember_me"))
      assert_true(meta.doc.has("loading_state"))
    }
  }
  // 幂等：再跑一次不再放置（检测器已满足）
  let second = match p.autofill_missing(artboard="login") {
    Ok(j) => j
    Err(_) => ""
  }
  assert_true(second.contains("\"placed_count\":0"))
  // 生成物合规：谓词零违规（auto_fix 清偿了放置引入的重叠/溢出）
  match p.artboards.get("login") {
    Some(meta) => assert_true(validate(meta.doc).length() == 0)
    None => ()
  }
}

///|
/// 状态类缺失（表单错误态）不物化——走组件状态多态而非节点。
test "autofill：状态语义缺失跳过" {
  let p = Project::new()
  let _ = p.create_artboard(name="form")
  let _ = p.place_component(
    artboard="form",
    component_id="text_input",
    instance_id="email",
    x=24.0,
    y=100.0,
  )
  let _ = p.place_component(
    artboard="form",
    component_id="button",
    instance_id="submit",
    x=24.0,
    y=180.0,
  )
  let json = match p.autofill_missing(artboard="form") {
    Ok(j) => j
    Err(_) => ""
  }
  assert_true(json.contains("error_states"))
  assert_true(json.contains("state_semantics_not_placeable"))
  assert_false(json.contains("\"node\":\"error_states\""))
}
