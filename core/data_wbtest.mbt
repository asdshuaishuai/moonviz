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

///|
test "data_set_path：拒绝面——空路径/末段数组段/标量中途/越界/非数字段/显式 null" {
  let root = match parse_data_json(
    "{\"user\":\"Bob\",\"items\":[{\"title\":\"t1\"}],\"n\":null}",
  ) {
    Ok(v) => v
    Err(_) => abort("unreachable")
  }
  // 拒绝面表驱动（评审 Finding 2）：含末段数组段——修复前静默 Ok 但
  // 不写值（假成功信封，Finding 1），现整体拒绝
  let cases : Array[(String, String)] = [
    ("", "data_path_empty"),
    ("items.0", "data_path_conflict"),
    ("user.name", "data_path_conflict"),
    ("items.5.title", "data_path_conflict"),
    ("items.abc.title", "data_path_conflict"),
    ("n.x", "data_path_conflict"),
  ]
  for c in cases.iter() {
    let (path, frag) = c
    match data_set_path(root, path, "V") {
      Err(e) => assert_true(e.contains(frag), msg="path=\{path} → \{e}")
      Ok(_) => abort("data_set_path 应拒绝: \{path}")
    }
  }
  // 整体拒绝不部分应用：root 逐点核对，无新键、无值变动
  assert_eq(
    data_to_json(root),
    "{\"items\":[{\"title\":\"t1\"}],\"n\":null,\"user\":\"Bob\"}",
  )
}

///|
test "data_set_path：写穿播种/数组内键/覆盖/DNull 起根" {
  let root = match parse_data_json("{\"items\":[{\"title\":\"t1\"}],\"user\":{\"name\":\"Bob\"}}") {
    Ok(v) => v
    Err(_) => abort("unreachable")
  }
  // 缺失中间对象逐段创建
  match data_set_path(root, "profile.city", "杭州") {
    Ok(_) => ()
    Err(e) => abort(e)
  }
  assert_eq(
    match data_lookup(root, "profile.city") {
      Some(v) => data_to_display(v)
      None => abort("写穿应落值")
    },
    "杭州",
  )
  // 数组导航后写既有元素内的键
  match data_set_path(root, "items.0.title", "t2") {
    Ok(_) => ()
    Err(e) => abort(e)
  }
  assert_eq(
    match data_lookup(root, "items.0.title") {
      Some(v) => data_to_display(v)
      None => abort("数组内键应可写")
    },
    "t2",
  )
  // 覆盖既有标量
  match data_set_path(root, "user.name", "Alice") {
    Ok(_) => ()
    Err(e) => abort(e)
  }
  assert_eq(
    match data_lookup(root, "user.name") {
      Some(v) => data_to_display(v)
      None => abort("覆盖应生效")
    },
    "Alice",
  )
  // DNull 根：以空对象起根并返回新根
  match data_set_path(DNull, "a.b", "v") {
    Ok(nr) => assert_eq(data_to_json(nr), "{\"a\":{\"b\":\"v\"}}")
    Err(e) => abort(e)
  }
}

///|
test "binding_path：单一绑定提取/混合与畸形按字面量" {
  assert_eq(binding_path("{{user.name}}"), Some("user.name"))
  assert_eq(binding_path("{{a}}"), Some("a"))
  // 混合文本：不是单一绑定，走字面量回写
  assert_true(binding_path("hello {{name}}") is None)
  assert_true(binding_path("{{name}}!") is None)
  // 过短 / 未闭合 / 内嵌花括号
  assert_true(binding_path("{{}}") is None)
  assert_true(binding_path("{{open") is None)
  assert_true(binding_path("{{a}}{{b}}") is None)
  assert_true(binding_path("plain") is None)
}

///|
test "data_to_json：键码元字典序逐字节确定 + 转义" {
  let v = match parse_data_json(
    "{\"b\":1,\"aaaa\":\"x\",\"pi\":3.5,\"list\":[true,null,\"q\\\"z\"]}",
  ) {
    Ok(v) => v
    Err(_) => abort("unreachable")
  }
  // "aaaa" 排在 "b" 前（真内容序；工具链 String::compare 长度序会排反）
  assert_eq(
    data_to_json(v),
    "{\"aaaa\":\"x\",\"b\":1,\"list\":[true,null,\"q\\\"z\"],\"pi\":3.5}",
  )
}

///|
test "Project dispatch_event：核心门卫——输入型判定/字面量 revision/数据写穿随 clone" {
  let p = Project::new()
  assert_true(apply_operation(p, "create w") is Ok(_))
  assert_true(apply_operation(p, "place w text_input t - 20 20 280 44") is Ok(_))
  assert_true(apply_operation(p, "place w button b - 20 100 120 44") is Ok(_))
  // 非输入型组件拒绝
  match p.dispatch_event(artboard="w", node_id="b", event="commit", value="x") {
    Err(e) => assert_true(e.contains("data_dispatch_not_input"), msg=e)
    Ok(_) => abort("非输入型应拒绝")
  }
  // 未知事件拒绝
  match p.dispatch_event(artboard="w", node_id="t", event="tap", value="x") {
    Err(e) => assert_true(e.contains("data_dispatch_unknown_event"), msg=e)
    Ok(_) => abort("未知事件应拒绝")
  }
  // 无绑定：字面量回写，revision 前进（文档变更）
  let rev0 = p.revision
  match p.dispatch_event(artboard="w", node_id="t", event="input", value="hi") {
    Ok(json) => assert_true(json.contains("\"target\":\"text\""), msg=json)
    Err(e) => abort(e)
  }
  assert_true(p.revision == rev0 + 1)
  // 绑定：写穿数据树，revision 不前进（运行时态）
  assert_true(apply_operation(p, "update w t text={{form.name}}") is Ok(_))
  let rev1 = p.revision
  match p.dispatch_event(artboard="w", node_id="t", event="commit", value="张三") {
    Ok(json) => assert_true(json.contains("\"target\":\"data\""), msg=json)
    Err(e) => abort(e)
  }
  assert_true(p.revision == rev1)
  assert_true(p.collect_data_json().contains("张三"), msg=p.collect_data_json())
  // clone 随行（data 引用随行语义）
  let c = p.clone()
  assert_true(c.collect_data_json().contains("张三"))
}
