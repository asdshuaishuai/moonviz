///|
test "parse_data_json：对象/数组/嵌套/转义" {
  let r = parse_data_json("{\"user\":{\"name\":\"林一\",\"age\":28},\"items\":[\"a\",\"b\"],\"ok\":true,\"pi\":3.5}")
  assert_true(r is Ok(_))
  let v = match r { Ok(v) => v; Err(_) => abort("unreachable") }
  let nm = match data_lookup(v, "user.name") { Some(x) => x; None => DNull }
  let ag = match data_lookup(v, "user.age") { Some(x) => x; None => DNull }
  let it = match data_lookup(v, "items.1") { Some(x) => x; None => DNull }
  let ok = match data_lookup(v, "ok") { Some(x) => x; None => DNull }
  let pi = match data_lookup(v, "pi") { Some(x) => x; None => DNull }
  assert_eq(data_to_display(nm), "林一")
  assert_eq(data_to_display(ag), "28")
  assert_eq(data_to_display(it), "b")
  assert_eq(data_to_display(ok), "true")
  assert_eq(data_to_display(pi), "3.5")
  assert_false(data_lookup(v, "user.missing") is Some(_))
}

///|
test "parse_data_json：非法输入全 Err 不崩" {
  assert_true(parse_data_json("") is Err(_))
  assert_true(parse_data_json("{") is Err(_))
  assert_true(parse_data_json("{\"a\":}") is Err(_))
  assert_true(parse_data_json("[1,") is Err(_))
  assert_true(parse_data_json("{}x") is Err(_))
  assert_true(parse_data_json("nul") is Err(_))
  assert_true(parse_data_json("\"unclosed") is Err(_))
  assert_true(parse_data_json("{\"a\" 1}") is Err(_))
}

///|
test "resolve_bindings：命中替换/未命中保字面/无数据原样" {
  let data = match parse_data_json("{\"user\":{\"name\":\"林一\"}}") {
    Ok(v) => v
    Err(_) => abort("unreachable")
  }
  assert_eq(resolve_bindings("你好，{{user.name}}！", data), "你好，林一！")
  // 未命中保留字面（诚实占位）
  assert_eq(resolve_bindings("{{nope.path}}", data), "{{nope.path}}")
  // 未注入数据（DNull）：模板原样
  assert_eq(resolve_bindings("{{user.name}}", DNull), "{{user.name}}")
  // 非绑定花括号不受影响
  assert_eq(resolve_bindings("JSON: {\"a\":1}", data), "JSON: {\"a\":1}")
  // 未闭合 {{ 不吞内容
  assert_eq(resolve_bindings("{{open", data), "{{open")
  // 多绑定 + 数组显示
  let d2 = match parse_data_json("{\"list\":[\"x\",\"y\"]}") {
    Ok(v) => v
    Err(_) => abort("unreachable")
  }
  assert_eq(resolve_bindings("{{list}} ×2", d2), "x, y ×2")
}
