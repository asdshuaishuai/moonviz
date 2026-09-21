///|
/// protest 边界入口：脚本 DSL → 断言结果。
test "protest：脚本 DSL 全断言通过" {
  let p = Project::new()
  let _ = p.create_artboard(name="login", width=390.0, height=844.0)
  let _ = p.create_artboard(name="home", width=390.0, height=844.0)
  p.add_flow(from="login", to="home", trigger="tap:go")
  let _ = p.place_component(artboard="login", component_id="button", instance_id="go", x=160.0, y=420.0)
  let json = run_protest_script(p, "login", "tap:170:430>home; back>login; noviol; render")
  assert_true(json.contains("\"ok\":true"))
  assert_true(json.contains("\"status\":\"PASS\""))
  assert_true(json.contains("\"script_lines\":4"))
}

///|
test "protest：失败断言如实记 FAIL" {
  let p = Project::new()
  let _ = p.create_artboard(name="only", width=390.0, height=844.0)
  let json = run_protest_script(p, "only", "tap:10:10>nowhere")
  assert_true(json.contains("\"status\":\"FAIL\""))
  assert_true(json.contains("expected nowhere"))
}
