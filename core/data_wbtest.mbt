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

///|
test "DataSchema::infer：样例推断——仅 string|number|boolean，词汇外跳过" {
  let s = match parse_data_json(
    "{\"name\":\"林一\",\"age\":28,\"ok\":true,\"tags\":[\"a\"],\"user\":{\"x\":1},\"n\":null}",
  ) {
    Ok(v) => v
    Err(_) => abort("unreachable")
  }
  assert_eq(
    DataSchema::infer(s).to_json(),
    "{\"age\":\"number\",\"name\":\"string\",\"ok\":\"boolean\"}",
  )
  // 非对象样例：空契约（不崩）
  let arr = match parse_data_json("[1,2]") {
    Ok(v) => v
    Err(_) => abort("unreachable")
  }
  assert_eq(DataSchema::infer(arr).to_json(), "{}")
  assert_eq(DataSchema::infer(DNull).to_json(), "{}")
}

///|
test "DataSchema::from_spec：显式声明——非法项整体拒绝" {
  let ok = match parse_data_json("{\"a\":\"string\",\"b\":\"number\",\"c\":\"boolean\"}") {
    Ok(v) => v
    Err(_) => abort("unreachable")
  }
  assert_eq(match DataSchema::from_spec(ok) { Ok(s) => s.to_json(); Err(e) => e },
    "{\"a\":\"string\",\"b\":\"number\",\"c\":\"boolean\"}")
  // 未知类型名
  let bad1 = match parse_data_json("{\"a\":\"int32\"}") {
    Ok(v) => v
    Err(_) => abort("unreachable")
  }
  assert_true(DataSchema::from_spec(bad1) is Err(_))
  // 类型值非字符串
  let bad2 = match parse_data_json("{\"a\":3}") {
    Ok(v) => v
    Err(_) => abort("unreachable")
  }
  assert_true(DataSchema::from_spec(bad2) is Err(_))
  // 非对象根
  let bad3 = match parse_data_json("[1]") {
    Ok(v) => v
    Err(_) => abort("unreachable")
  }
  assert_true(DataSchema::from_spec(bad3) is Err(_))
}

///|
test "Project schema：运行时态——声明/读回/整体拒绝/clone 与 replace_with 随行" {
  let p = Project::new()
  // 未声明：空对象
  assert_eq(p.schema_json(), "{}")
  let n = match p.set_schema_fields([("name", "string"), ("age", "number")]) {
    Ok(n) => n
    Err(_) => abort("unreachable")
  }
  assert_eq(n, 2)
  assert_eq(p.schema_json(), "{\"age\":\"number\",\"name\":\"string\"}")
  // 非法类型整体拒绝：现有 schema 不变、不部分应用
  assert_true(p.set_schema_fields([("x", "array")]) is Err(_))
  assert_eq(p.schema_json(), "{\"age\":\"number\",\"name\":\"string\"}")
  // 合法声明整体替换
  assert_true(p.set_schema_fields([("k", "boolean")]) is Ok(_))
  assert_eq(p.schema_json(), "{\"k\":\"boolean\"}")
  // clone 随行（与 data 同边界：会话 clone→ops→replace_with 不丢契约）
  let c = p.clone()
  assert_eq(c.schema_json(), "{\"k\":\"boolean\"}")
  // replace_with 随行
  let p2 = Project::new()
  p2.replace_with(p)
  assert_eq(p2.schema_json(), "{\"k\":\"boolean\"}")
  // JSON 显式形式（宿主/SDK 侧入口）
  assert_true(p.set_schema_json("{\"a\":\"string\",\"b\":\"number\"}") is Ok(_))
  assert_eq(p.schema_json(), "{\"a\":\"string\",\"b\":\"number\"}")
  assert_true(p.set_schema_json("{bad") is Err(_))
  assert_true(p.set_schema_json("{\"a\":\"int64\"}") is Err(_))
  assert_true(p.set_schema_json("[\"a\"]") is Err(_))
  assert_eq(p.schema_json(), "{\"a\":\"string\",\"b\":\"number\"}")
}

///|
test "schema op：k=v 声明 + 畸形对/未知类型拒绝（分发器路径）" {
  let p = Project::new()
  assert_true(apply_operation(p, "schema name=string age=number") is Ok(_))
  assert_eq(p.schema_json(), "{\"age\":\"number\",\"name\":\"string\"}")
  // 无 "=" 的畸形项：拒绝且 schema 不变
  assert_true(apply_operation(p, "schema badpair") is Err(_))
  assert_eq(p.schema_json(), "{\"age\":\"number\",\"name\":\"string\"}")
  // 未知类型：拒绝
  assert_true(apply_operation(p, "schema x=array") is Err(_))
  assert_eq(p.schema_json(), "{\"age\":\"number\",\"name\":\"string\"}")
}
