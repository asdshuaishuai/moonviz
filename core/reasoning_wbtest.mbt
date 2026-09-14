// 布局推理 + 响应式断点 测试

///|
test "布局推理：解析中文约束" {
  assert_true(parse_layout_intent("居中对齐") is CenterNode(_))
  assert_true(parse_layout_intent("垂直排列") is VerticalStack)
  assert_true(parse_layout_intent("水平排列") is HorizontalRow)
  assert_true(parse_layout_intent("等宽") is EqualWidth)
  assert_true(parse_layout_intent("等间距") is EqualSpacing)
  assert_true(parse_layout_intent("网格 8") is GridAlign(_))
  assert_true(parse_layout_intent("放大 1.5") is ScaleAll(_))
  assert_true(parse_layout_intent("边距 16") is SetPadding(_))
  assert_true(parse_layout_intent("间距 12") is SetGap(_))
  assert_true(parse_layout_intent("hello world") is Unknown)
}

///|
test "布局推理：解析英文约束" {
  assert_true(parse_layout_intent("center the button") is CenterNode(_))
  assert_true(parse_layout_intent("vertical stack") is VerticalStack)
  assert_true(parse_layout_intent("equal width") is EqualWidth)
  assert_true(parse_layout_intent("snap to grid") is GridAlign(_))
}

///|
test "布局推理：数字提取" {
  let g = parse_layout_intent("网格 16")
  match g {
    GridAlign(v) => assert_eq(v, 16.0)
    _ => assert_true(false)
  }
  let s = parse_layout_intent("放大 2")
  match s {
    ScaleAll(f) => assert_eq(f, 2.0)
    _ => assert_true(false)
  }
}

///|
test "布局推理：执行约束" {
  let p = Project::new()
  let ab = p.create_artboard(name="reason_test")
  let _ = p.place_component(
    artboard=ab,
    component_id="button",
    instance_id="b1",
    x=10.0,
    y=10.0,
  )
  // 执行"居中"
  match p.apply_constraint("居中对齐", artboard=ab) {
    Ok(json) => assert_true(json.contains("\"ok\":true") || json.contains("x"))
    Err(_) => assert_true(false)
  }
  // 执行"垂直排列"
  match p.apply_constraint("垂直排列", artboard=ab) {
    Ok(json) => assert_true(json.contains("vertical_stack"))
    Err(_) => assert_true(false)
  }
  // 执行"等宽"
  match p.apply_constraint("等宽", artboard=ab) {
    Ok(json) => assert_true(json.contains("equal_width"))
    Err(_) => assert_true(false)
  }
}

///|
test "响应式断点：默认断点" {
  let bps = default_breakpoints()
  assert_eq(bps.length(), 3)
  assert_eq(bps[0].name, "mobile")
  assert_eq(bps[1].name, "tablet")
  assert_eq(bps[2].name, "desktop")
  let json = breakpoints_json()
  assert_true(json.contains("\"mobile\""))
  assert_true(json.contains("\"tablet\""))
  assert_true(json.contains("\"desktop\""))
}

///|
test "响应式：生成变体" {
  let p = Project::new()
  let ab = p.create_artboard(name="resp_test", width=390.0, height=844.0)
  let _ = p.place_component(
    artboard=ab,
    component_id="button",
    instance_id="btn1",
  )
  let _ = p.place_component(
    artboard=ab,
    component_id="card",
    instance_id="card1",
  )
  match p.generate_responsive(artboard=ab) {
    Ok(json) => {
      assert_true(json.contains("\"ok\":true"))
      assert_true(json.contains("resp_test_tablet"))
      assert_true(json.contains("resp_test_desktop"))
    }
    Err(_) => assert_true(false)
  }
  // 验证变体存在且尺寸不同
  let variants = p.list_breakpoint_variants(artboard=ab)
  assert_true(variants.contains("\"mobile\""))
  assert_true(variants.contains("\"tablet\""))
  assert_true(variants.contains("\"desktop\""))
  // 平板应该比手机宽
  match p.artboards.get("resp_test_tablet") {
    Some(tab) => assert_eq(tab.width, 768.0)
    None => assert_true(false)
  }
  match p.artboards.get("resp_test_desktop") {
    Some(dsk) => assert_eq(dsk.width, 1200.0)
    None => assert_true(false)
  }
}

///|
test "响应式：预览断点" {
  let p = Project::new()
  let ab = p.create_artboard(name="pv_test")
  let _ = p.place_component(
    artboard=ab,
    component_id="button",
    instance_id="btn",
  )
  let _ = p.generate_responsive(artboard=ab)
  match p.preview_breakpoint(artboard=ab, breakpoint="mobile") {
    Ok(json) => assert_true(json.contains("\"mobile\""))
    Err(_) => assert_true(false)
  }
  match p.preview_breakpoint(artboard=ab, breakpoint="tablet") {
    Ok(json) => assert_true(json.contains("\"tablet\""))
    Err(_) => assert_true(false)
  }
}

///|
test "Agent 超级工作流：模板→布局推理→响应式→全链路" {
  let p = Project::new()

  // 1) 模板创建
  let login = match p.apply_template(template_id="login") {
    Ok(id) => id
    Err(_) => {
      assert_true(false)
      return
    }
  }

  // 2) 布局推理：自动优化
  match p.apply_constraint("垂直排列", artboard=login) {
    Ok(_) => ()
    Err(_) => assert_true(false)
  }
  match p.apply_constraint("等宽", artboard=login) {
    Ok(_) => ()
    Err(_) => assert_true(false)
  }

  // 3) 响应式变体
  match p.generate_responsive(artboard=login) {
    Ok(json) => assert_true(json.contains("\"ok\":true"))
    Err(_) => assert_true(false)
  }

  // 4) 预览各断点
  let _ = p.preview_breakpoint(artboard=login, breakpoint="mobile")
  let _ = p.preview_breakpoint(artboard=login, breakpoint="tablet")
  let _ = p.preview_breakpoint(artboard=login, breakpoint="desktop")

  // 5) 列出变体
  let variants = p.list_breakpoint_variants(artboard=login)
  assert_true(variants.contains("\"tablet\""))
  assert_true(variants.contains("\"desktop\""))

  // 6) 导出（含所有变体）
  let html = p.export_html()
  assert_true(html.contains(login))
}
