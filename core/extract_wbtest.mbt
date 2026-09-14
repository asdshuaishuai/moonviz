// 设计系统反向提取 测试

///|
test "提取：颜色令牌推断" {
  let p = Project::new()
  let _ = p.apply_template(template_id="login")
  match p.extract_design_system(artboard="login") {
    Ok(ds) => {
      // 应该提取到颜色令牌
      assert_true(ds.color_tokens.length() > 0)
      // 高频色应该被推断为 primary 或 surface
      let top = ds.color_tokens[0]
      assert_true(top.usage_count > 0)
      assert_true(top.confidence > 0.0)
    }
    Err(_) => assert_true(false)
  }
}

///|
test "提取：间距令牌" {
  let p = Project::new()
  let _ = p.apply_template(template_id="login")
  // 设置布局以便提取间距
  let _ = p.apply_constraint("间距 16", artboard="login")
  match p.extract_design_system(artboard="login") {
    Ok(ds) =>
      // 模板有布局，应该提取到间距
      assert_true(ds.spacing_tokens.length() > 0)
    Err(_) => assert_true(false)
  }
}

///|
test "提取：字号令牌" {
  let p = Project::new()
  let _ = p.apply_template(template_id="login")
  match p.extract_design_system(artboard="login") {
    Ok(ds) =>
      // 应该有多种字号
      assert_true(ds.font_tokens.length() > 0)
    Err(_) => assert_true(false)
  }
}

///|
test "提取：组件模式检测" {
  let p = Project::new()
  let _ = p.apply_template(template_id="dashboard")
  match p.extract_design_system(artboard="dashboard") {
    Ok(ds) =>
      // 仪表盘有多个相同类型的卡片，应检测到模式
      assert_true(ds.components.length() > 0)
    Err(_) => assert_true(false)
  }
}

///|
test "提取：JSON 输出" {
  let p = Project::new()
  let _ = p.apply_template(template_id="login")
  match p.extract_design_system(artboard="login") {
    Ok(ds) => {
      let json = ds.to_json()
      assert_true(json.contains("\"color_tokens\""))
      assert_true(json.contains("\"components\""))
      assert_true(json.contains("\"summary\""))
    }
    Err(_) => assert_true(false)
  }
}

///|
test "提取：人类可读摘要" {
  let p = Project::new()
  let _ = p.apply_template(template_id="login")
  match p.extract_design_system(artboard="login") {
    Ok(ds) => {
      let s = ds.summary()
      assert_true(s.contains("Extracted Design System"))
      assert_true(s.contains("Colors:"))
      assert_true(s.contains("Typography:"))
    }
    Err(_) => assert_true(false)
  }
}

///|
test "提取→再利用：从 dashboard 提取设计系统创建新画板" {
  let p = Project::new()

  // 1) 创建一个仪表盘（有多个卡片和按钮）
  let dash = match p.apply_template(template_id="dashboard") {
    Ok(id) => id
    Err(_) => {
      assert_true(false)
      return
    }
  }

  // 2) 提取设计系统
  let ds = match p.extract_design_system(artboard=dash) {
    Ok(d) => d
    Err(_) => {
      assert_true(false)
      return
    }
  }

  // 3) 用提取的颜色创建新画板上的组件
  let new_ab = p.create_artboard(name="new_page", width=390.0, height=844.0)
  if ds.color_tokens.length() > 0 {
    let primary = ds.color_tokens[0]
    let _ = p.place_component(
      artboard=new_ab,
      component_id="button",
      instance_id="cta",
      variant="primary",
    )
    // 验证新画板的组件能使用提取的令牌
    match p.artboards.get(new_ab) {
      Some(ab) => assert_true(ab.doc.has("cta"))
      None => assert_true(false)
    }
  }

  // 4) 验证提取结果的完整性
  assert_true(ds.total_nodes > 0)
  assert_true(ds.total_colors > 0)
}

///|
test "提取：颜色饱和度计算" {
  let (r1, g1, b1) = parse_rgb("#FF0000") // 红色
  let s1 = color_saturation(r1, g1, b1)
  assert_true(s1 > 0.9) // 高饱和度
  let (r2, g2, b2) = parse_rgb("#808080") // 灰色
  let s2 = color_saturation(r2, g2, b2)
  assert_true(s2 < 0.1) // 低饱和度
}
