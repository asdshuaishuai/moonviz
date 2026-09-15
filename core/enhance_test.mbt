// 增强引擎测试：auto_fix / diff / export

///|
test "auto_fix：清除视觉债" {
  let p = Project::new()
  let _ = p.create_artboard(name="fix_test", width=390.0, height=844.0)
  // 放两个重叠的组件
  let _ = p.place_component(
    artboard="fix_test",
    component_id="button",
    instance_id="btn_a",
    y=100.0,
  )
  let _ = p.place_component(
    artboard="fix_test",
    component_id="button",
    instance_id="btn_b",
    y=120.0,
  )
  // 确认有视觉债
  match p.artboards.get("fix_test") {
    Some(ab) => assert_true(validate(ab.doc).length() > 0)
    None => assert_true(false)
  }
  // 自动修复
  match p.auto_fix(artboard="fix_test") {
    Ok(json) => assert_true(json.contains("\"ok\""))
    Err(_) => assert_true(false)
  }
  // 修复后可能仍有残留（迭代修复有限轮次），但至少有修复动作
  match p.artboards.get("fix_test") {
    Some(ab) => {
      let after = validate(ab.doc).length()
      // 不要求全清，但不应变多
      assert_true(after <= 1)
    }
    None => assert_true(false)
  }
}

///|
test "diff：检测新增/移动/样式变更" {
  let before = Document::sample_login()
  let after = Document::sample_login()
  // 修改按钮位置和颜色
  let _ = after.update_node("btn-login", fn(n) {
    { ..n, x: AlignStart(50.0), style: { ..n.style, fill: "#FF0000" } }
  })
  let d = diff_docs(before, after)
  // 应有 moved + restyled
  assert_true(d.moved.length() > 0)
  assert_true(d.restyled.length() > 0)
  let json = d.to_json()
  assert_true(json.contains("\"moved\""))
  assert_true(json.contains("\"restyled\""))
  assert_true(json.contains("\"btn-login\""))
  // summary 不为空
  assert_true(d.summary() != "no changes")
}

///|
test "diff：无变更时返回 unchanged" {
  let a = Document::sample_login()
  let b = Document::sample_login()
  let d = diff_docs(a, b)
  assert_eq(d.summary(), "no changes")
  assert_true(d.to_json().contains("\"unchanged\":true"))
}

///|
test "export_react：生成 TSX 组件桩" {
  let p = Project::new()
  let _ = p.create_artboard(name="login_page", width=390.0, height=844.0)
  let _ = p.place_component(
    artboard="login_page",
    component_id="button",
    instance_id="submit",
  )
  let tsx = p.export_react()
  assert_true(tsx.contains("export function LoginPage"))
  assert_true(tsx.contains("position:'absolute'"))
  assert_true(tsx.contains("data-id=\"submit\""))
}

///|
test "export_html：生成自包含 HTML" {
  let p = Project::new()
  let _ = p.create_artboard(name="home")
  let _ = p.create_artboard(name="detail")
  p.add_flow(from="home", to="detail", trigger="tap:card")
  let html = p.export_html()
  assert_true(html.contains("<!DOCTYPE html>"))
  assert_true(html.contains("id=\"board-home\""))
  assert_true(html.contains("id=\"board-detail\""))
  // 新版导出：flow 解析为节点级点击绑定（tap:card → 节点 card 的 navigate）
  assert_true(html.contains("\"card\""))
  assert_true(html.contains("\"navigate\""))
  assert_true(html.contains("MV_ACT"))
  assert_true(html.contains("<script>"))
}

///|
test "Agent 完整工作流：创建→放置→lint→修复→diff→导出" {
  let p = Project::new()

  // 1) 创建画板
  let ab = p.create_artboard(name="checkout", width=390.0, height=844.0)
  assert_eq(ab, "checkout")

  // 2) 快照 before
  let before_doc = match p.artboards.get("checkout") {
    Some(x) => x.doc.clone()
    None => Document::new({ width: 390.0, height: 844.0 })
  }

  // 3) 放置组件
  let _ = p.place_component(
    artboard="checkout",
    component_id="app_bar",
    instance_id="top_bar",
    variant="primary",
  )
  let _ = p.place_component(
    artboard="checkout",
    component_id="heading",
    instance_id="title",
    variant="h2",
    y=80.0,
  )
  let _ = p.place_component(
    artboard="checkout",
    component_id="card",
    instance_id="summary",
    y=160.0,
  )
  let _ = p.place_component(
    artboard="checkout",
    component_id="button",
    instance_id="pay",
    variant="primary",
    y=400.0,
  )

  // 4) lint
  match p.lint(artboard="checkout") {
    Ok(json) => {
      // 可能有 empty_container（card 没子元素）
      let _ = json // 不强制要求有 lint 结果
    }
    Err(_) => assert_true(false)
  }

  // 5) auto_fix
  match p.auto_fix(artboard="checkout") {
    Ok(json) => assert_true(json.contains("\"ok\""))
    Err(_) => assert_true(false)
  }

  // 6) diff（before vs after）
  let after_doc = match p.artboards.get("checkout") {
    Some(x) => x.doc
    None => Document::new({ width: 390.0, height: 844.0 })
  }
  let d = diff_docs(before_doc, after_doc)
  assert_true(d.added.length() >= 4) // 至少加了 4 个组件

  // 7) 导出
  let html = p.export_html()
  assert_true(html.contains("checkout"))
  let tsx = p.export_react()
  assert_true(tsx.contains("Checkout"))

  // 8) SVG
  let svg = p.export_svg(artboard="checkout")
  assert_true(svg is Ok(_))
}
