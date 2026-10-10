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

///|
/// 回归（评审 R1）：norm_fix_pass 的 update 闭包曾无条件写 Fixed(new_w/new_h)，
/// 圆角-only 路径会把 w=fill 的组件静默降级为定宽（报告还显示宽高不变）。
test "norms：圆角-only 修复不把 Fill 宽降级为 Fixed" {
  let p = Project::new()
  let _ = p.create_artboard(name="norms_fill", width=390.0, height=844.0)
  let _ = p.place_component(
    artboard="norms_fill",
    component_id="button",
    instance_id="fill_btn",
    variant="primary",
    x=20.0,
    y=100.0,
    w=350.0,
    h=40.0,
  )
  // h=40：高满足文案底线；radius=24 超 高/2=20 → 只收敛圆角
  let _ = apply_operation(p, "update norms_fill fill_btn w=fill radius=24")
  match p.artboards.get("norms_fill") {
    None => assert_true(false)
    Some(ab) => {
      let layout = solve(ab.doc)
      let fixes = norm_fix_pass(ab.doc, layout)
      assert_eq(fixes.length(), 1)
      match ab.doc.nodes.get("fill_btn") {
        None => assert_true(false)
        Some(n) => {
          match n.width {
            Fill => ()
            _ => assert_true(false)
          }
          match n.height {
            Fixed(h) => assert_eq(h, 40.0)
            _ => assert_true(false)
          }
          assert_eq(n.style.corner_radius, 20.0)
        }
      }
    }
  }
}

///|
/// 回归（评审 R1）：高度-only 路径同样不得覆写未变化的 Fill 宽。
test "norms：高度-only 修复不把 Fill 宽降级为 Fixed" {
  let p = Project::new()
  let _ = p.create_artboard(name="norms_fill2", width=390.0, height=844.0)
  let _ = p.place_component(
    artboard="norms_fill2",
    component_id="button",
    instance_id="short_btn",
    variant="primary",
    x=20.0,
    y=100.0,
    w=200.0,
    h=24.0,
  )
  // 文案 2 字（宽足），h=24 < 34 → 只抬高度；Fill 宽保持
  let _ = apply_operation(p, "update norms_fill2 short_btn text=发送 w=fill")
  match p.artboards.get("norms_fill2") {
    None => assert_true(false)
    Some(ab) => {
      let layout = solve(ab.doc)
      let fixes = norm_fix_pass(ab.doc, layout)
      assert_eq(fixes.length(), 1)
      match ab.doc.nodes.get("short_btn") {
        None => assert_true(false)
        Some(n) => {
          match n.width {
            Fill => ()
            _ => assert_true(false)
          }
          match n.height {
            Fixed(h) => assert_eq(h, 34.0)
            _ => assert_true(false)
          }
        }
      }
    }
  }
}

///|
/// 回归（评审 R3）：chip/tag 有 component_norm 下发的独立高度档
/// （28~32 / 22~26），通用「字号+20」底线曾把档内合规件抬到 34——
/// list_components 刚下发的合规尺寸会被自己的 auto_fix 改坏。
test "norms：chip/tag 档内高度不误报（对齐 component_norm 档位）" {
  let p = Project::new()
  let _ = p.create_artboard(name="norms_band", width=390.0, height=844.0)
  let _ = p.place_component(
    artboard="norms_band",
    component_id="chip",
    instance_id="band_chip",
    x=20.0,
    y=100.0,
    w=120.0,
    h=28.0,
  )
  let _ = apply_operation(p, "update norms_band band_chip text=全部")
  let _ = p.place_component(
    artboard="norms_band",
    component_id="tag",
    instance_id="band_tag",
    x=20.0,
    y=150.0,
    w=100.0,
    h=24.0,
  )
  // radius=8 中和圆角维度（tag 自身 4~6 档与方正圆润 8 档的张力不在本轮范围）
  let _ = apply_operation(p, "update norms_band band_tag text=新 radius=8")
  match p.artboards.get("norms_band") {
    None => assert_true(false)
    Some(ab) => {
      let layout = solve(ab.doc)
      assert_eq(norm_issues(ab.doc, layout).length(), 0)
      assert_eq(norm_fix_pass(ab.doc, layout).length(), 0)
    }
  }
}

///|
/// 回归（评审 R5）：need_h 曾只用 font_size+20，双行文案按行数要高度。
test "norms：多行文案按行数要高度" {
  let p = Project::new()
  let _ = p.create_artboard(name="norms_multi", width=390.0, height=844.0)
  let _ = p.place_component(
    artboard="norms_multi",
    component_id="button",
    instance_id="multi_btn",
    variant="primary",
    x=20.0,
    y=100.0,
    w=300.0,
    h=36.0,
  )
  // op 层把 \n 还原为真实换行（split_cmd 保留原文，unescape_value 统一还原）
  let _ = apply_operation(p, "update norms_multi multi_btn text=确认提交\\n并返回")
  match p.artboards.get("norms_multi") {
    None => assert_true(false)
    Some(ab) => {
      let layout = solve(ab.doc)
      let issues = norm_issues(ab.doc, layout)
      assert_eq(issues.length(), 1)
      // 2 行 × 14 × 1.5 = 42，+ 上下留白 20 → 62（36 高曾误判合规）
      assert_true(issues[0].contains("×62"))
      let _ = norm_fix_pass(ab.doc, layout)
      let layout2 = solve(ab.doc)
      match layout2.rect_of("multi_btn") {
        None => assert_true(false)
        Some(r) => assert_eq(r.height, 62.0)
      }
    }
  }
}

///|
/// 回归（评审 R2）：norm_issues 裸嵌 id/文案曾把反斜杠/引号原样带进
/// critique JSON——响应行 JSON.parse 失败，损坏直达传输信封。
test "norms：问题串与 critique JSON 对 id/文案转义" {
  let p = Project::new()
  let _ = p.create_artboard(name="norms_esc", width=390.0, height=844.0)
  let _ = p.place_component(
    artboard="norms_esc",
    component_id="button",
    instance_id="esc_btn",
    variant="primary",
    x=20.0,
    y=100.0,
    w=80.0,
    h=40.0,
  )
  // op 层 \\ → 单个反斜杠：文案 = C:\Users\note（\\n 不会变成换行）
  let _ = apply_operation(p, "update norms_esc esc_btn text=C:\\\\Users\\\\note")
  match p.artboards.get("norms_esc") {
    None => assert_true(false)
    Some(ab) => {
      // 直改文档补引号（op 解析器会剥引号）：文案 = 他说"hi"C:\Users\note
      let _ = ab.doc.update_node("esc_btn", fn(n) {
        { ..n, text: "他说\"hi\"C:\\Users\\note" }
      })
      let layout = solve(ab.doc)
      let issues = norm_issues(ab.doc, layout)
      assert_eq(issues.length(), 1)
      // 问题串内引号必须是转义形状 \"（裸引号会破坏下游 JSON 拼接）
      assert_true(issues[0].contains("\\\""))
      match p.critique(artboard="norms_esc") {
        Ok(json) => {
          // 转义后形状：\" 与 \\
          assert_true(json.contains("他说\\\"hi\\\"C:\\\\Users\\\\note"))
        }
        Err(_) => assert_true(false)
      }
      // 引擎自己的 JSON 消费端（extract_scores）也必须能吃下
      match p.critique_summary(artboard="norms_esc") {
        Ok(_) => ()
        Err(_) => assert_true(false)
      }
    }
  }
}

///|
/// 构造齐缝菜单列表（无分割线）：app_bar + n×56 list_item 齐缝堆叠 + tab_bar
fn norms_make_menu_project(row_count : Int) -> Project {
  let p = Project::new()
  let _ = p.create_artboard(name="norms_menu", width=390.0, height=844.0)
  let _ = p.place_component(
    artboard="norms_menu",
    component_id="app_bar",
    instance_id="bar",
    y=0.0,
    h=44.0,
  )
  for i in 0..<row_count {
    let _ = p.place_component(
      artboard="norms_menu",
      component_id="list_item",
      instance_id="row_" + i.to_string(),
      y=44.0 + i.to_double() * 56.0,
      w=390.0,
      h=56.0,
    )
    let _ = apply_operation(
      p,
      "update norms_menu row_" + i.to_string() + " text=菜单项" + i.to_string(),
    )
  }
  let _ = p.place_component(
    artboard="norms_menu",
    component_id="tab_bar",
    instance_id="tabs",
    y=788.0,
    h=56.0,
  )
  p
}

///|
test "norms：齐缝列表无分割线被判偏差" {
  let p = norms_make_menu_project(4)
  match p.artboards.get("norms_menu") {
    None => assert_true(false)
    Some(ab) => {
      let issues = norm_issues(ab.doc, solve(ab.doc))
      let mut flagged = false
      for s in issues.iter() {
        if s.contains("行间无分割线") {
          flagged = true
        }
      }
      assert_true(flagged)
      // 建议里给出修复路径（divider / 分组 / auto_fix）
      let mut actionable = false
      for s in issues.iter() {
        if s.contains("1px divider") && s.contains("auto_fix") {
          actionable = true
        }
      }
      assert_true(actionable)
    }
  }
}

///|
test "norms：auto_fix 为列表行插入行底分割线" {
  let p = norms_make_menu_project(4)
  let before_debt = match p.artboards.get("norms_menu") {
    Some(ab) => validate(ab.doc).length()
    None => 0
  }
  match p.auto_fix(artboard="norms_menu") {
    Ok(json) => assert_true(json.contains("list_divider"))
    Err(_) => assert_true(false)
  }
  match p.artboards.get("norms_menu") {
    None => assert_true(false)
    Some(ab) => {
      // 前 3 行行底各有一条 divider 子节点；最后一行没有
      for i in 0..<3 {
        match ab.doc.nodes.get("row_" + i.to_string()) {
          None => assert_true(false)
          Some(row) => {
            let mut has = false
            for cid in row.children.iter() {
              match ab.doc.nodes.get(cid) {
                Some(c) => if c.component == "divider" { has = true }
                None => ()
              }
            }
            assert_true(has)
          }
        }
      }
      match ab.doc.nodes.get("row_3") {
        None => assert_true(false)
        Some(row) => {
          let mut has = false
          for cid in row.children.iter() {
            match ab.doc.nodes.get(cid) {
              Some(c) => if c.component == "divider" { has = true }
              None => ()
            }
          }
          assert_false(has)
        }
      }
      // 修复后不再判偏差
      let issues = norm_issues(ab.doc, solve(ab.doc))
      for s in issues.iter() {
        assert_false(s.contains("行间无分割线"))
      }
      // 不引入新视觉债
      assert_eq(validate(ab.doc).length(), before_debt)
    }
  }
}

///|
test "norms：已有分割线的列表不误报" {
  let p = norms_make_menu_project(4)
  // 每行行底放 divider 子节点（上一轮修复后的形态）
  for i in 0..<3 {
    let _ = p.place_component(
      artboard="norms_menu",
      component_id="divider",
      instance_id="row_" + i.to_string() + "_sep",
      parent_id="row_" + i.to_string(),
      x=16.0,
      y=55.0,
      w=358.0,
      h=1.0,
    )
  }
  match p.artboards.get("norms_menu") {
    None => assert_true(false)
    Some(ab) => {
      let issues = norm_issues(ab.doc, solve(ab.doc))
      for s in issues.iter() {
        assert_false(s.contains("行间无分割线"))
      }
    }
  }
}

///|
test "norms：两行列表不误报（run 下限 3）" {
  let p = norms_make_menu_project(2)
  match p.artboards.get("norms_menu") {
    None => assert_true(false)
    Some(ab) => {
      let issues = norm_issues(ab.doc, solve(ab.doc))
      for s in issues.iter() {
        assert_false(s.contains("行间无分割线"))
      }
    }
  }
}
