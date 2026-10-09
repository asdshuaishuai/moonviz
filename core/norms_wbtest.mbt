///|
/// 组件规范（norms）测试：检测、修复、critique 第 9 维三端同一判据。
/// 场景取自真实弱模型产出（demo.ddp 类）：按钮刚好卡住文案、圆角混乱、
/// 全宽条带圆角顶出屏幕边缘。

///|
/// 构造规范偏差画板：紧按钮 + 方硬圆角 + 全宽 tab_bar 带圆角
fn norms_make_dirty_project() -> Project {
  let p = Project::new()
  let _ = p.create_artboard(name="norms_test", width=390.0, height=844.0)
  // 卡文案的按钮：文案 2 个汉字 ≈ 28px + 24 留白 = 52，故意给 40×24
  let _ = p.place_component(
    artboard="norms_test",
    component_id="button",
    instance_id="tight_btn",
    variant="primary",
    x=20.0,
    y=100.0,
    w=40.0,
    h=24.0,
  )
  let _ = apply_operation(p, "update norms_test tight_btn text=发送")
  // 方硬圆角的 select（radius 0 < 8 档）
  let _ = p.place_component(
    artboard="norms_test",
    component_id="select",
    instance_id="hard_select",
    x=20.0,
    y=160.0,
    w=200.0,
    h=40.0,
  )
  let _ = apply_operation(p, "update norms_test hard_select radius=0")
  // 全宽 tab_bar 带圆角
  let _ = p.place_component(
    artboard="norms_test",
    component_id="tab_bar",
    instance_id="round_tabbar",
    y=788.0,
    w=390.0,
    h=56.0,
  )
  let _ = apply_operation(p, "update norms_test round_tabbar radius=10")
  p
}

///|
test "norms：检测按钮卡文案 / 方硬圆角 / 全宽条圆角" {
  let p = norms_make_dirty_project()
  match p.artboards.get("norms_test") {
    None => assert_true(false)
    Some(ab) => {
      let layout = solve(ab.doc)
      let issues = norm_issues(ab.doc, layout)
      assert_true(issues.length() >= 3)
      // 每条建议都带具体尺寸（Agent 读到即可改）
      let mut has_size_advice = false
      let mut has_radius_advice = false
      let mut has_fullbleed_advice = false
      for s in issues.iter() {
        if s.contains("文案需 ≥") {
          has_size_advice = true
        }
        if s.contains("radius 8") {
          has_radius_advice = true
        }
        if s.contains("radius 0") {
          has_fullbleed_advice = true
        }
      }
      assert_true(has_size_advice)
      assert_true(has_radius_advice)
      assert_true(has_fullbleed_advice)
    }
  }
}

///|
test "norms：auto_fix 一键修复组件规范" {
  let p = norms_make_dirty_project()
  match p.auto_fix(artboard="norms_test") {
    Ok(json) => {
      assert_true(json.contains("component_norm"))
      assert_true(json.contains("文案留白") || json.contains("圆角") || json.contains("全宽条"))
    }
    Err(_) => assert_true(false)
  }
  // 修复后：规范清零（norm_issues 无偏差），且不引入新的硬视觉债
  match p.artboards.get("norms_test") {
    None => assert_true(false)
    Some(ab) => {
      let layout = solve(ab.doc)
      assert_eq(norm_issues(ab.doc, layout).length(), 0)
      // 按钮文案不再卡边：宽 ≥ 文案宽 + 24
      match ab.doc.nodes.get("tight_btn") {
        None => assert_true(false)
        Some(n) =>
          match layout.rect_of("tight_btn") {
            None => assert_true(false)
            Some(r) => {
              let ts = text_intrinsic(n.text, n.style.font_size)
              assert_true(r.width >= ts.width + 24.0 - 0.5)
              assert_true(r.height >= n.style.font_size + 20.0 - 0.5)
            }
          }
      }
      // 方正圆润：select 圆角归档 8
      match ab.doc.nodes.get("hard_select") {
        None => assert_true(false)
        Some(n) => assert_true(n.style.corner_radius >= 8.0)
      }
      // 全宽条直角
      match ab.doc.nodes.get("round_tabbar") {
        None => assert_true(false)
        Some(n) => assert_eq(n.style.corner_radius, 0.0)
      }
    }
  }
}

///|
test "norms：critique 第 9 维 norms 在场且计分" {
  let p = norms_make_dirty_project()
  match p.critique(artboard="norms_test") {
    Ok(json) => {
      assert_true(json.contains("\"principles\":9"))
      assert_true(json.contains("\"principle\":\"norms\""))
      // 脏画板的 norms 维度必须给出偏差数
      assert_true(json.contains(" 处规范偏差"))
    }
    Err(_) => assert_true(false)
  }
  // 修复后 norms 维度走满分路径：advice 为「组件规范良好」
  let _ = p.auto_fix(artboard="norms_test")
  match p.critique(artboard="norms_test") {
    Ok(json) => assert_true(json.contains("组件规范良好"))
    Err(_) => assert_true(false)
  }
}

///|
test "norms：合规文档零偏差（模板不产生新债）" {
  let p = Project::new()
  let _ = p.apply_template(template_id="login")
  match p.artboards.get("login") {
    None => assert_true(false)
    Some(ab) => {
      let layout = solve(ab.doc)
      // 内置模板是规范基线：不允许被新规范判出偏差（否则发版即债）
      assert_eq(norm_issues(ab.doc, layout).length(), 0)
    }
  }
}

///|
test "norms：list_components 下发 norm 字段" {
  let j = list_components_json(builtin_components())
  assert_true(j.contains("\"norm\":\"宽 ≥ 文案宽+24"))
  assert_true(j.contains("全宽顶边条"))
}
