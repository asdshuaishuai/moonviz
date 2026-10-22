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

///|
/// 同 id 冲突预检：画板已有同 id 节点时跳过（id_taken），绝不改写既有
/// 内容——place_component 根路径会吞掉 insert_node 的重复 id 失败，
/// 不预检就会静默改写用户节点还谎报放置成功（CORE-1）。
test "autofill：同 id 冲突跳过不改写既有节点" {
  let p = Project::new()
  // 4 卡 → dashboard；其中一张 instance_id 恰为 "refresh"（显示名改开，
  // 否则节点名会满足检测器关键词、refresh 不进缺失清单）
  let _ = p.create_artboard(name="dash")
  let _ = p.place_component(
    artboard="dash",
    component_id="card",
    instance_id="refresh",
    x=24.0,
    y=24.0,
    h=100.0,
  )
  let _ = p.edit_node(
    artboard="dash",
    node_id="refresh",
    kvs=[("text", "Reload"), ("name", "数据卡")],
  )
  let _ = p.place_component(
    artboard="dash",
    component_id="card",
    instance_id="kpi2",
    x=24.0,
    y=140.0,
    h=100.0,
  )
  let _ = p.place_component(
    artboard="dash",
    component_id="card",
    instance_id="kpi3",
    x=24.0,
    y=256.0,
    h=100.0,
  )
  let _ = p.place_component(
    artboard="dash",
    component_id="card",
    instance_id="kpi4",
    x=24.0,
    y=372.0,
    h=100.0,
  )
  let before = match p.infer_missing(artboard="dash") {
    Ok(j) => j
    Err(_) => ""
  }
  assert_true(before.contains("\"element\":\"refresh\""))
  let json = match p.autofill_missing(artboard="dash") {
    Ok(j) => j
    Err(_) => ""
  }
  assert_true(json.contains("\"element\":\"refresh\",\"reason\":\"id_taken\""))
  assert_false(json.contains("\"node\":\"refresh\""))
  // 既有节点原样：文本与尺寸未被配方改写（配方是 刷新/120×44）
  match p.artboards.get("dash") {
    None => assert_true(false)
    Some(meta) =>
      match meta.doc.get("refresh") {
        None => assert_true(false)
        Some(n) => {
          assert_true(n.text == "Reload")
          assert_true(n.name == "数据卡")
          match n.width {
            Fixed(v) => assert_true(v == 320.0)
            _ => assert_true(false)
          }
          match n.height {
            Fixed(v) => assert_true(v == 100.0)
            _ => assert_true(false)
          }
        }
      }
  }
}

///|
/// search_bar 锚定退让：app_bar 之下的带区已被内容占用时回退底缘光标，
/// 且锚定放置不推进光标——既有卡片位置分毫不动，画板零违规（CORE-2）。
test "autofill：锚定带区占用回退底缘光标" {
  let p = Project::new()
  let _ = p.create_artboard(name="list")
  let _ = p.place_component(
    artboard="list",
    component_id="app_bar",
    instance_id="topbar",
    x=0.0,
    y=0.0,
  )
  // 3 卡 → list 页；卡片紧贴 app_bar 之下，锚定候选带（56+12）与 c1 相交
  let _ = p.place_component(
    artboard="list",
    component_id="card",
    instance_id="c1",
    x=24.0,
    y=72.0,
  )
  let _ = p.place_component(
    artboard="list",
    component_id="card",
    instance_id="c2",
    x=24.0,
    y=292.0,
  )
  let _ = p.place_component(
    artboard="list",
    component_id="card",
    instance_id="c3",
    x=24.0,
    y=512.0,
  )
  let json = match p.autofill_missing(artboard="list") {
    Ok(j) => j
    Err(_) => ""
  }
  assert_true(json.contains("\"ok\":true"))
  assert_true(json.contains("\"node\":\"search_bar\""))
  match p.artboards.get("list") {
    None => assert_true(false)
    Some(meta) => {
      // 零违规：旧路径会靠精确包含豁免漏报同矩形塌缩
      assert_true(validate(meta.doc).length() == 0)
      // 既有卡片位置分毫不动（旧路径 auto_fix 会把卡片下移改写）
      for (id, expect_y) in
        [("c1", 72.0), ("c2", 292.0), ("c3", 512.0)] {
        match meta.doc.get(id) {
          None => assert_true(false)
          Some(n) =>
            match n.y {
              AlignStart(v) => assert_true(v == expect_y)
              _ => assert_true(false)
            }
        }
      }
      // search_bar 退回底缘光标（728），没有塞进 app_bar 带区（68）
      match meta.doc.get("search_bar") {
        None => assert_true(false)
        Some(n) =>
          match n.y {
            AlignStart(v) => assert_true(v == 728.0)
            _ => assert_true(false)
          }
      }
    }
  }
}

///|
/// 近满页钳制：底缘光标越过画布高度时节点不再物化（no_room），信封
/// ok 如实采纳 autofix 结果——画板带着 auto_fix 清偿不动的溢出债时，
/// 顶层不再恒报 ok:true（CORE-3）。
test "autofill：近满页钳制与信封如实透传 autofix 失败" {
  let p = Project::new()
  let _ = p.create_artboard(name="nearfull")
  // 4 卡 → dashboard；末卡 y+200=900 越过画布底缘（844）——fix_overflow
  // 对负剩余空间保持原尺寸，属清偿不动的既有债
  let _ = p.place_component(
    artboard="nearfull",
    component_id="card",
    instance_id="d1",
    x=24.0,
    y=24.0,
  )
  let _ = p.place_component(
    artboard="nearfull",
    component_id="card",
    instance_id="d2",
    x=24.0,
    y=224.0,
  )
  let _ = p.place_component(
    artboard="nearfull",
    component_id="card",
    instance_id="d3",
    x=24.0,
    y=424.0,
  )
  let _ = p.place_component(
    artboard="nearfull",
    component_id="card",
    instance_id="d4",
    x=24.0,
    y=700.0,
  )
  let json = match p.autofill_missing(artboard="nearfull") {
    Ok(j) => j
    Err(_) => ""
  }
  // 底缘 900 → 光标 916，refresh/loading_state 都放不下：如实跳过不放置
  assert_true(json.contains("\"reason\":\"no_room\""))
  assert_true(json.contains("\"placed_count\":0"))
  // 顶层信封以 autofix 结果开场（旧信封恒 ok:true）
  assert_true(json.has_prefix("{\"ok\":false,"))
  match p.artboards.get("nearfull") {
    None => assert_true(false)
    Some(meta) => {
      assert_false(meta.doc.has("refresh"))
      assert_false(meta.doc.has("loading_state"))
    }
  }
}

///|
/// 缺失清单解析只认 "missing":[ … ] 数组片段：信封其他字段里的
/// element 键不再被误收集（CORE-4，白盒直测信封解析路径）。
test "autofill：缺失清单解析限定 missing 数组作用域" {
  // 构造信封：missing 数组外带两个诱饵 element 键
  let envelope = "{\"page_type\":\"auth\",\"signals\":{\"element\":\"signup_link\"},\"missing_count\":1,\"missing\":[{\"type\":\"missing_link\",\"element\":\"forgot_password\",\"suggestion\":\"x\"}],\"tail\":{\"element\":\"remember_me\"}}"
  let els = parse_missing_envelope(envelope)
  assert_true(els.length() == 1)
  assert_true(els[0] == "forgot_password")
}

///|
/// 导出去重按组隔离（CORE-5）：CSS 变量名自带 --ds-{group}- 前缀，跨组
/// 同 slug 本不冲突——非标准共同值（18px 同为间距与字号）不再被强行
/// -2 改名。随本批修复锚定于此（文件集约束下导出侧用例落本文件）。
test "export_design_system：跨组同 slug 不再加 -2 后缀" {
  let p = Project::new()
  let _ = p.create_artboard(name="tokens")
  // 容器 gap=18 → spacing custom_18；文本 font_size=18 → font custom_18
  let _ = p.place_component(
    artboard="tokens",
    component_id="card",
    instance_id="box",
    x=24.0,
    y=24.0,
  )
  let _ = p.edit_node(artboard="tokens", node_id="box", kvs=[("gap", "18")])
  let _ = p.place_component(
    artboard="tokens",
    component_id="body_text",
    instance_id="t1",
    x=24.0,
    y=260.0,
  )
  let _ = p.edit_node(
    artboard="tokens",
    node_id="t1",
    kvs=[("font_size", "18"), ("text", "Token")],
  )
  let json = match p.export_design_system(artboard="tokens") {
    Ok(j) => j
    Err(_) => ""
  }
  // 带冒号断言完整变量名：custom-18 是 custom-18-2 的前缀，裸 contains 区分不开
  assert_true(json.contains("--ds-spacing-custom-18:"))
  assert_true(json.contains("--ds-font-custom-18:"))
  assert_false(json.contains("custom-18-2"))
}
