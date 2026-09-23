// Agent 驱动原型设计引擎的端到端测试
// 覆盖：令牌 → 组件发现 → 多画板 → 放置 → 查询 → lint → 修复建议

///|
test "Agent 工作流：发现组件 → 创建画板 → 放置组件 → 查询 → lint" {
  let p = Project::new()

  // 1) Agent 发现可用组件
  let comps = list_components_json(p.components)
  assert_true(comps.contains("\"button\""))
  assert_true(comps.contains("\"card\""))
  assert_true(comps.contains("\"heading\""))

  // 2) Agent 发现设计令牌
  let tokens = p.tokens.to_json()
  assert_true(tokens.contains("\"primary\""))
  assert_true(tokens.contains("\"md\""))

  // 3) 创建画板
  let ab = p.create_artboard(name="login", width=390.0, height=844.0)
  assert_eq(ab, "login")

  // 4) 放置组件
  let r1 = p.place_component(
    artboard="login",
    component_id="app_bar",
    instance_id="bar",
    variant="primary",
  )
  assert_true(r1 is Ok(_))
  let r2 = p.place_component(
    artboard="login",
    component_id="heading",
    instance_id="title",
    variant="h1",
    y=80.0,
  )
  assert_true(r2 is Ok(_))
  let r3 = p.place_component(
    artboard="login",
    component_id="text_input",
    instance_id="email",
    y=200.0,
  )
  assert_true(r3 is Ok(_))
  let r4 = p.place_component(
    artboard="login",
    component_id="button",
    instance_id="submit",
    variant="primary",
    y=300.0,
  )
  assert_true(r4 is Ok(_))

  // 5) 查询：找所有 rect 类型
  let qr = p.query_nodes(artboard="login", kind="rect")
  assert_true(qr is Ok(_))
  match qr {
    Ok(json) => assert_true(json.contains("\"bar\""))
    Err(_) => assert_true(false)
  }

  // 6) 查询：按组件名
  let qc = p.query_nodes(artboard="login", component="button")
  match qc {
    Ok(json) => assert_true(json.contains("\"submit\""))
    Err(_) => assert_true(false)
  }

  // 7) 画板列表
  let abl = p.list_artboards_json()
  assert_true(abl.contains("\"login\""))
  assert_true(abl.contains("\"nodes\":5"))

  // 8) Agent 工具清单（46 工具全量字典，MCP tools/list 同源）
  let tools = list_tools_json()
  assert_true(tools.contains("list_components"))
  assert_true(tools.contains("place_component"))
  assert_true(tools.contains("lint_design"))
  assert_true(tools.contains("set_token"))
  assert_true(tools.contains("export_html"))
  assert_true(tools.contains("inputSchema"))
}

///|
test "Agent 工作流：导航流 + 导出 SVG" {
  let p = Project::new()
  let _ = p.create_artboard(name="home", width=390.0, height=844.0)
  let _ = p.create_artboard(name="detail", width=390.0, height=844.0)
  p.add_flow(from="home", to="detail", trigger="tap:card")
  let fj = p.flow_json()
  assert_true(fj.contains("\"from\":\"home\""))
  assert_true(fj.contains("\"to\":\"detail\""))
  // SVG 导出
  let svg = p.export_svg(artboard="home")
  assert_true(svg is Ok(_))
}

///|
test "engine catalog contains all 65 predefined component presets" {
  let comps = builtin_components()
  assert_eq(comps.length(), 65)
  for id in comps.keys() {
    match comps.get(id) {
      Some(def) => {
        assert_true(def.id == id)
        assert_true(def.variants.length() > 0)
      }
      None => assert_true(false)
    }
  }
}

///|
test "设计令牌解析：颜色/间距/圆角" {
  let t = DesignTokens::default()
  assert_eq(t.resolve_color("primary"), "#4B6BFB")
  assert_eq(t.resolve_color("#FF0000"), "#FF0000") // 非→原样返回
  assert_true(t.resolve_spacing("md") == Some(8.0))
  assert_true(t.resolve_radius("lg") == Some(12.0))
  assert_true(t.resolve_font("h1") == Some(32.0))
}

///|
test "组件实例化：variant 样式正确应用" {
  let comps = builtin_components()
  let tokens = DesignTokens::default()
  match comps.get("button") {
    Some(btn) => {
      let node = instantiate_component(btn, "my_btn", variant="danger", tokens~)
      assert_eq(node.style.fill, "#BA1A1A") // error → #BA1A1A
      assert_eq(node.style.text_color, "#FFFFFF") // on_primary → #FFFFFF
      assert_eq(node.style.corner_radius, 8.0)
      assert_eq(node.component, "button")
    }
    None => assert_true(false)
  }
}

///|
test "对比度计算：WCAG 规范值" {
  // 黑白对比度 ≈ 21:1
  let bw = contrast_ratio("#000000", "#FFFFFF")
  assert_true(bw > 20.0 && bw < 22.0)
  // 白白 = 1:1
  let ww = contrast_ratio("#FFFFFF", "#FFFFFF")
  assert_true(ww > 0.9 && ww < 1.1)
}

///|
test "设计 lint：触控目标 + 空容器检测" {
  let p = Project::new()
  let _ = p.create_artboard(name="test", width=390.0, height=844.0)
  // 放一个很小的按钮（触控目标违规）
  let _ = p.place_component(
    artboard="test",
    component_id="card",
    instance_id="empty_card",
  )
  match p.lint(artboard="test") {
    Ok(json) =>
      assert_true(
        json.contains("touch_target") || json.contains("empty_container"),
      )
    Err(_) => assert_true(false)
  }
}

///|
test "engine catalog: 65 组件 × 全变体放置渲染冒烟（组件目录回归锚）" {
  let comps = builtin_components()
  let p = Project::new()
  let _ = p.create_artboard(name="all", width=1200.0, height=9600.0)
  let mut placed = 0
  let mut y = 20.0
  for id in comps.keys() {
    match comps.get(id) {
      Some(def) => {
        // 全变体逐个放置：任何非法 kind/未注册令牌/坏 patch 都会在此暴露
        for vname in def.variants.keys() {
          match p.place_component(
            artboard="all",
            component_id=id,
            instance_id="\{id}_\{vname}",
            variant=vname,
            y=y,
          ) {
            Ok(_) => placed = placed + 1
            Err(e) => assert_true(false, msg="\{id}.\{vname}: \{e}")
          }
          y = y + 80.0
        }
      }
      None => assert_true(false)
    }
  }
  assert_eq(placed, 115)
  // 整画板可渲染且内容非空
  match p.export_svg(artboard="all") {
    Ok(svg) => assert_true(svg.contains("<svg") && svg.length() > 1000)
    Err(e) => assert_true(false, msg=e)
  }
}
