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

///|
test "门语义：兄弟全包含＝有意分层豁免，部分相交仍违规（issue #15）" {
  let p = Project::new()
  let _ = p.create_artboard(name="m", width=375.0, height=812.0)
  // 顺序 1：先背景（fill 全屏）后内容——内容完整包含于背景
  let _ = p.place_component(artboard="m", component_id="rect", instance_id="bg", y=0.0)
  let _ = p.edit_node(artboard="m", node_id="bg", kvs=[("width", "375"), ("height", "812"), ("fill", "#112233")])
  let _ = p.place_component(artboard="m", component_id="button", instance_id="cta", y=100.0)
  match p.artboards.get("m") {
    Some(ab) => {
      let vs = validate(ab.doc)
      let mut n_overlap = 0
      for v in vs.iter() {
        if v.predicate is NoSiblingOverlap { n_overlap = n_overlap + 1 }
      }
      assert_eq(n_overlap, 0, msg="全包含层叠不应记 no_sibling_overlap")
    }
    None => assert_true(false)
  }
  // 顺序 2：部分相交必须仍然记违规。背景改为非全屏（300×600），
  // 内容放在其右下角外——place 的内容盒钳制不会把它推进背景内
  let _ = p.edit_node(artboard="m", node_id="bg", kvs=[("w", "300"), ("h", "600")])
  let _ = p.place_component(
    artboard="m",
    component_id="button",
    instance_id="cta2",
    x=250.0,
    y=550.0,
  )
  match p.artboards.get("m") {
    Some(ab) => {
      let vs = validate(ab.doc)
      let mut n_overlap = 0
      for v in vs.iter() {
        if v.predicate is NoSiblingOverlap { n_overlap = n_overlap + 1 }
      }
      assert_true(n_overlap > 0, msg="部分相交必须仍记 no_sibling_overlap")
    }
    None => assert_true(false)
  }
}

///|
test "unflow：单条导航边删除（issue #12）" {
  let p = Project::new()
  let _ = p.create_artboard(name="home", width=390.0, height=844.0)
  let _ = p.create_artboard(name="detail", width=390.0, height=844.0)
  let _ = p.create_artboard(name="about", width=390.0, height=844.0)
  p.add_flow(from="home", to="detail", trigger="tap:card")
  p.add_flow(from="home", to="about", trigger="tap:menu")
  assert_eq(p.flow_json().contains("\"to\":\"detail\""), true)
  // 删一条留一条
  match p.remove_flow(from="home", to="detail", trigger="tap:card") {
    Ok(_) => ()
    Err(e) => assert_true(false, msg=e)
  }
  let fj = p.flow_json()
  assert_eq(fj.contains("\"to\":\"detail\""), false, msg="detail 边应已删除")
  assert_eq(fj.contains("\"to\":\"about\""), true, msg="about 边应保留")
  // 不存在的边报 unknown_flow
  match p.remove_flow(from="home", to="detail", trigger="tap:card") {
    Err(e) => assert_true(e.contains("unknown_flow"), msg=e)
    Ok(_) => assert_true(false, msg="重复删除应报错")
  }
}

///|
test "query_nodes：节点条目带 parent 字段（issue #13）" {
  let p = Project::new()
  let _ = p.create_artboard(name="tree", width=390.0, height=844.0)
  let _ = p.place_component(artboard="tree", component_id="card", instance_id="grp1", y=20.0)
  let _ = p.place_component(artboard="tree", component_id="button", instance_id="b1", y=40.0)
  let _ = p.place_component(artboard="tree", component_id="button", instance_id="b2", y=120.0)
  let _ = p.group_nodes(artboard="tree", node_ids=["b1", "b2"], group_id="demo1")
  match p.query_nodes(artboard="tree") {
    Ok(json) => {
      // 顶层节点 parent=root；组员 parent=组节点
      assert_true(json.contains("\"id\":\"grp1\",\"parent\":\"\"" ) || json.contains("\"id\":\"grp1\",\"parent\":\"root\""), msg=json)
      assert_true(json.contains("\"parent\":\"demo1\""), msg="组员应带 parent=demo1: " + json)
      // render 载荷复用 query_nodes，自动获得 parent
      match p.export_svg(artboard="tree") {
        Ok(_) => ()
        Err(e) => assert_true(false, msg=e)
      }
    }
    Err(e) => assert_true(false, msg=e)
  }
}

///|
test "auto_fix：背景层不参与重叠推挤（review 5a5641a）" {
  let p = Project::new()
  let _ = p.create_artboard(name="m", width=375.0, height=812.0)
  let _ = p.place_component(artboard="m", component_id="rect", instance_id="bg", y=0.0)
  let _ = p.edit_node(artboard="m", node_id="bg", kvs=[("w", "375"), ("h", "812")])
  // a 与 b 部分相交（真实视觉债）
  let _ = p.place_component(artboard="m", component_id="button", instance_id="a", x=0.0, y=100.0)
  let _ = p.place_component(artboard="m", component_id="button", instance_id="b", x=60.0, y=120.0)
  match p.auto_fix(artboard="m") {
    Ok(json) => assert_true(json.contains("\"ok\""), msg=json)
    Err(e) => assert_true(false, msg=e)
  }
  // 修复后：真实重叠清零，且没有任何内容被推出画板之外（背景此前会把
  // max_bottom 抬到 812，修复者直接出界）
  match p.artboards.get("m") {
    Some(ab) => {
      let vs = validate(ab.doc)
      let layout = solve(ab.doc)
      let mut n_overlap = 0
      for v in vs.iter() {
        if v.predicate is NoSiblingOverlap { n_overlap = n_overlap + 1 }
      }
      assert_eq(n_overlap, 0, msg="部分相交应被修复")
      for id in ["a", "b"] {
        match layout.rect_of(id) {
          Some(r) =>
            assert_true(
              r.y + r.height <= 812.0,
              msg="\{id} 被推出画板: y=\{r.y} h=\{r.height}",
            )
          None => assert_true(false, msg="\{id} 无解")
        }
      }
    }
    None => assert_true(false)
  }
}

///|
test "history：撤销后新提交截断 redo 分支（review 5a5641a）" {
  let h = DesignHistory::new(Document::new({ width: 390.0, height: 844.0 }))
  let doc1 = Document::sample_login()
  let _ = h.commit("t", "e1", [], doc1)
  assert_eq(h.rev(), 1)
  let _ = h.undo()
  assert_eq(h.rev(), 0)
  // 撤销后编辑再提交：旧 redo 分支（rev1 旧快照）被截断，新提交复用 rev1
  // ——checkout 线性扫描必须命中新快照而非被旧条目遮蔽（review 5a5641a）
  let doc2 = Document::sample_login()
  let marker = { ..Node::make("marker", Rect), name: "added-after-undo" }
  let _ = doc2.insert_node(marker, "root")
  let _ = h.commit("t", "e2", [], doc2)
  assert_eq(h.rev(), 1)
  match h.checkout(1) {
    Ok(d) =>
      match d.nodes.get("marker") {
        Some(_) => ()
        None => assert_true(false, msg="checkout(1) 应命中新提交（含 marker），而非被旧 rev1 快照遮蔽")
      }
    Err(e) => assert_true(false, msg=e)
  }
  match h.redo() {
    Err(e) => assert_true(e.contains("nothing_to_redo"), msg=e)
    Ok(_) => assert_true(false, msg="commit 后 redo 应不可用")
  }
}

///|
test "constrain：cannot_parse 错误自描述语法（issue #17）" {
  let p = Project::new()
  let _ = p.create_artboard(name="a", width=390.0, height=844.0)
  // 自由文本层级诉求不被误解析，且错误就地给出全部可用意图
  match p.apply_constraint("bg 是全屏背景层 允许重叠", artboard="a") {
    Err(e) => {
      assert_true(e.contains("cannot_parse"), msg=e)
      assert_true(e.contains("布局意图"), msg="错误应声明这是布局意图: " + e)
      assert_true(
        e.contains("垂直排列") && e.contains("网格 N"),
        msg="错误应自带语法清单: " + e,
      )
    }
    Ok(json) => assert_true(false, msg="层级自由文本不应被误解析: " + json)
  }
  // 合法意图照常执行
  match p.apply_constraint("等间距", artboard="a") {
    Ok(json) => assert_true(json.contains("\"ok\":true"), msg=json)
    Err(e) => assert_true(false, msg=e)
  }
}
