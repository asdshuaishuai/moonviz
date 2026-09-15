///|
/// 交互原型导出：flows(tap:node) 与 ⚡ 词汇表合并为节点级绑定表；
/// 组件状态导出为 CSS 变体；导航栈/toast/set_text 均为数据驱动。
test "export_html：节点级交互与状态变体导出" {
  let p = Project::new()
  let _ = p.create_artboard(name="home")
  let _ = p.create_artboard(name="detail")
  let _ = p.place_component(artboard="home", component_id="button", instance_id="card", x=10.0, y=10.0)
  let _ = p.place_component(artboard="home", component_id="button", instance_id="btn", x=10.0, y=60.0)
  p.add_flow(from="home", to="detail", trigger="tap:card")
  let _ = p.attach_interaction(artboard="home", node_id="btn", trigger="tap", action_spec="show_toast:\"已保存\"")
  let _ = p.define_component_state(artboard="home", node_id="btn", state_name="pressed", patch={
    ..NodePatch::empty(),
    fill: Some("#0F1114"),
  })
  let html = p.export_html()
  let nav = "[\"home\",\"card\",\"navigate\",\"detail\"]"
  assert_true(html.contains(nav))
  assert_true(html.contains("\"toast\""))
  assert_true(html.contains("st-pressed"))
  assert_true(html.contains("MV_STACK"))
  assert_true(html.contains("#0F1114"))
}
