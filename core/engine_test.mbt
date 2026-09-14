// 模板 + 对齐 + 变体测试

///|
test "模板：登录页生成完整画板" {
  let p = Project::new()
  match p.apply_template(template_id="login") {
    Ok(ab_id) => {
      // 验证画板有节点
      match p.artboards.get(ab_id) {
        Some(ab) => {
          let count = ab.doc.nodes.size()
          assert_true(count >= 8) // root + logo + title + email + password + button + divider + signup
        }
        None => assert_true(false)
      }
      // 单画板模板不会写入悬空跨画板流；创建 signup/forgot_password 画板后
      // 再由项目操作显式建立流程。
      assert_eq(p.flows.length(), 0)
    }
    Err(_) => assert_true(false)
  }
}

///|
test "模板：仪表盘生成" {
  let p = Project::new()
  match p.apply_template(template_id="dashboard") {
    Ok(ab) =>
      match p.artboards.get(ab) {
        Some(a) => assert_true(a.doc.nodes.size() >= 10) // bar + 4 stats + chart + title + 4 activities + divider
        None => assert_true(false)
      }
    Err(_) => assert_true(false)
  }
}

///|
test "模板：设置页生成" {
  let p = Project::new()
  match p.apply_template(template_id="settings") {
    Ok(ab) =>
      match p.artboards.get(ab) {
        Some(a) => assert_true(a.doc.nodes.size() >= 15) // bar + 4 sections + 12 items + logout
        None => assert_true(false)
      }
    Err(_) => assert_true(false)
  }
}

///|
test "模板清单 JSON" {
  let json = list_templates_json()
  assert_true(json.contains("\"login\""))
  assert_true(json.contains("\"dashboard\""))
  assert_true(json.contains("\"settings\""))
  assert_true(json.contains("\"auth\""))
}

///|
test "智能对齐：网格吸附" {
  let p = Project::new()
  let _ = p.create_artboard(name="grid_test")
  // 放一个位置不是 8 的倍数的组件
  let _ = p.place_component(
    artboard="grid_test",
    component_id="button",
    instance_id="b1",
    x=13.0,
    y=27.0,
  )
  match p.snap_to_grid(artboard="grid_test", grid=8.0) {
    Ok(json) => {
      assert_true(json.contains("\"ok\":true"))
      assert_true(json.contains("\"snapped\":1"))
    }
    Err(_) => assert_true(false)
  }
  // 验证位置已被吸附
  match p.artboards.get("grid_test") {
    Some(ab) => {
      let layout = solve(ab.doc)
      match layout.rect_of("b1") {
        Some(r) => {
          assert_eq(r.x, 8.0) // 13 → 8
          assert_eq(r.y, 24.0) // 27 → 24
        }
        None => assert_true(false)
      }
    }
    None => assert_true(false)
  }
}

///|
test "智能对齐：居中" {
  let p = Project::new()
  let _ = p.create_artboard(name="center_test", width=390.0)
  let _ = p.place_component(
    artboard="center_test",
    component_id="button",
    instance_id="btn",
    x=0.0,
  )
  match p.center_in_parent(artboard="center_test", node_id="btn") {
    Ok(json) => assert_true(json.contains("\"ok\":true"))
    Err(_) => assert_true(false)
  }
}

///|
test "变体：fork + 评分 + 合并" {
  let p = Project::new()
  let base = p.create_artboard(name="design_a")
  let _ = p.place_component(
    artboard="design_a",
    component_id="button",
    instance_id="ok_btn",
  )
  // fork
  match p.fork_variants(base="design_a", names=["v1", "v2"]) {
    Ok(json) => {
      assert_true(json.contains("\"v1\""))
      assert_true(json.contains("\"v2\""))
    }
    Err(_) => assert_true(false)
  }
  // 评分
  let scores = p.score_variants()
  assert_true(scores.contains("\"design_a\""))
  assert_true(scores.contains("\"v1\""))
  assert_true(scores.contains("\"score\""))
  // 合并
  match p.merge_variant(source="v1", target="design_a") {
    Ok(json) => assert_true(json.contains("\"ok\":true"))
    Err(_) => assert_true(false)
  }
}

///|
test "Agent 全流程：模板 → 变体 → 评分 → lint → 对齐 → 导出" {
  let p = Project::new()

  // 1) 用模板创建基础设计
  let base = match p.apply_template(template_id="login") {
    Ok(id) => id
    Err(_) => {
      assert_true(false)
      return
    }
  }

  // 2) fork 变体
  match p.fork_variants(base~, names=["variant_compact", "variant_spacious"]) {
    Ok(_) => ()
    Err(_) => assert_true(false)
  }

  // 3) 评分
  let scores = p.score_variants()
  assert_true(scores.contains("variant_compact"))

  // 4) lint 原始设计
  match p.lint(artboard=base) {
    Ok(_) => ()
    Err(_) => assert_true(false)
  }

  // 5) 网格对齐
  match p.snap_to_grid(artboard=base) {
    Ok(_) => ()
    Err(_) => assert_true(false)
  }

  // 6) 对齐建议
  match p.suggest_alignment(artboard=base) {
    Ok(_) => ()
    Err(_) => assert_true(false)
  }

  // 7) auto_fix
  match p.auto_fix(artboard=base) {
    Ok(_) => ()
    Err(_) => assert_true(false)
  }

  // 8) 导出 HTML
  let html = p.export_html()
  assert_true(html.contains(base))

  // 9) 导出 React
  let tsx = p.export_react()
  assert_true(tsx.contains("Login"))

  // 10) SVG
  let svg = p.export_svg(artboard=base)
  assert_true(svg is Ok(_))
}
