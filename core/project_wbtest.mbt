///|
/// issue #29：place k=v 在内置组件上此前静默丢弃（text/fill/motion 全无效
/// 却返回 ok:true）——现在 edit 词表键在插入前落到节点，未知键显式拒绝。
test "place k=v：内置组件参数生效，未知键拒绝" {
  let p = Project::new()
  let _ = p.apply_template(template_id="login")
  // 已知键：text/fill 生效（fill 走令牌解析）
  match
    p.place_component(
      artboard="login",
      component_id="chip",
      instance_id="kv_chip",
      x=10.0,
      y=10.0,
      w=80.0,
      h=28.0,
    ) {
    Ok(_) => ()
    Err(e) => {
      println("PLACE_ERR=" + e)
      assert_true(false)
    }
  }
  let _ = p.edit_node(artboard="login", node_id="kv_chip", kvs=[
    ("text", "New"),
    ("fill", "primary"),
  ])
  match p.artboards.get("login") {
    Some(ab) =>
      match ab.doc.get("kv_chip") {
        Some(n) => {
          assert_eq(n.text, "New")
          assert_eq(n.style.fill, p.tokens.resolve_color("primary"))
        }
        None => assert_true(false)
      }
    None => assert_true(false)
  }
  // 未知键：place 阶段显式拒绝（不再静默 ok:true）
  let bad_args : Map[String, String] = Map([])
  bad_args.set("not_a_key", "x")
  match
    p.place_component(
      artboard="login",
      component_id="chip",
      instance_id="bad_kv",
      variant="",
      x=10.0,
      y=50.0,
      w=80.0,
      h=28.0,
      args=bad_args,
    ) {
    Ok(_) => assert_true(false)
    Err(e) => assert_true(e.contains("place_unknown_key"))
  }
}

///|
/// issue #30/#31 链路回归：canonical 的 motion= 在重载后保留（此前
/// generic_node 无 motion 参数导致重载即丢），query 输出 motion 字段。
test "canonical motion 往返：重载保留 + query 可见" {
  let p = Project::new()
  let _ = p.apply_template(template_id="login")
  let _ = p.edit_node(artboard="login", node_id="login_btn", kvs=[
    ("motion", "fade_in"),
  ])
  // style 写面：edit motion= 直写（与 canonical motion= 同源）
  match p.artboards.get("login") {
    Some(ab) =>
      match ab.doc.get("login_btn") {
        Some(n) => assert_eq(n.style.motion, "fade_in")
        None => assert_true(false)
      }
    None => assert_true(false)
  }
  // query 面：motion 字段可见（此前 query_nodes 不输出，宿主读到 undefined）
  match p.query_nodes(artboard="login") {
    Ok(arr) => assert_true(arr.contains("\"motion\":\"fade_in\""))
    Err(_) => assert_true(false)
  }
}
