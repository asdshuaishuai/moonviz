// 组件插槽系统 测试

///|
test "插槽：内置组合式组件清单" {
  let comps = builtin_slotted_components()
  assert_true(comps.contains("card"))
  assert_true(comps.contains("list"))
  assert_true(comps.contains("form_field"))
  assert_true(comps.contains("modal"))
  assert_true(comps.contains("app_bar"))
  assert_true(comps.contains("tab_bar"))
}

///|
test "插槽：Card 组件有 header/content/footer" {
  let comps = builtin_slotted_components()
  match comps.get("card") {
    Some(card) => {
      assert_eq(card.slots.length(), 3)
      assert_eq(card.slots[0].name, "header")
      assert_eq(card.slots[1].name, "content")
      assert_eq(card.slots[2].name, "footer")
    }
    None => assert_true(false)
  }
}

///|
test "插槽：放置组合式组件" {
  let p = Project::new()
  let ab = p.create_artboard(name="slot_test")
  match
    p.place_slotted(artboard=ab, component_id="card", instance_id="my_card") {
    Ok(json) => {
      assert_true(json.contains("\"ok\":true"))
      assert_true(json.contains("\"slots\":3"))
      assert_true(json.contains("my_card_header"))
    }
    Err(_) => assert_true(false)
  }
  // 验证槽位子节点已创建
  match p.artboards.get(ab) {
    Some(x) => {
      assert_true(x.doc.has("my_card"))
      assert_true(x.doc.has("my_card_header"))
      assert_true(x.doc.has("my_card_content"))
      assert_true(x.doc.has("my_card_footer"))
    }
    None => assert_true(false)
  }
}

///|
test "插槽：填充槽位内容" {
  let p = Project::new()
  let ab = p.create_artboard(name="fill_test")
  let _ = p.place_slotted(artboard=ab, component_id="card", instance_id="c1")
  match
    p.fill_slot(
      artboard=ab,
      instance_id="c1",
      slot_name="header",
      content="My Card Title",
    ) {
    Ok(json) => assert_true(json.contains("\"ok\":true"))
    Err(_) => assert_true(false)
  }
  match
    p.fill_slot(
      artboard=ab,
      instance_id="c1",
      slot_name="content",
      content="This is the body",
    ) {
    Ok(_) => ()
    Err(_) => assert_true(false)
  }
  // 验证内容
  match p.get_slot(artboard=ab, instance_id="c1", slot_name="header") {
    Ok(text) => assert_eq(text, "My Card Title")
    Err(_) => assert_true(false)
  }
  match p.get_slot(artboard=ab, instance_id="c1", slot_name="content") {
    Ok(text) => assert_eq(text, "This is the body")
    Err(_) => assert_true(false)
  }
}

///|
test "插槽：默认内容" {
  let p = Project::new()
  let ab = p.create_artboard(name="default_test")
  let _ = p.place_slotted(artboard=ab, component_id="card", instance_id="dc")
  // header 应有默认内容 "Title"
  match p.get_slot(artboard=ab, instance_id="dc", slot_name="header") {
    Ok(text) => assert_eq(text, "Title")
    Err(_) => assert_true(false)
  }
}

///|
test "插槽：列出所有槽位" {
  let p = Project::new()
  let ab = p.create_artboard(name="list_test")
  let _ = p.place_slotted(artboard=ab, component_id="card", instance_id="lc")
  let _ = p.fill_slot(
    artboard=ab,
    instance_id="lc",
    slot_name="header",
    content="Custom",
  )
  match p.list_slots(artboard=ab, instance_id="lc") {
    Ok(json) => {
      assert_true(json.contains("\"header\""))
      assert_true(json.contains("\"content\""))
      assert_true(json.contains("\"footer\""))
      assert_true(json.contains("Custom"))
    }
    Err(_) => assert_true(false)
  }
}

///|
test "插槽：向槽位中放入组件（递归组合）" {
  let p = Project::new()
  let ab = p.create_artboard(name="nested_test")
  let _ = p.place_slotted(artboard=ab, component_id="modal", instance_id="m1")
  // 在 modal 的 actions 槽位放入一个 button
  match
    p.fill_slot_with_component(
      artboard=ab,
      instance_id="m1",
      slot_name="actions",
      child_component="button",
      child_id="confirm_btn",
    ) {
    Ok(json) => {
      assert_true(json.contains("\"ok\":true"))
      assert_true(json.contains("confirm_btn"))
    }
    Err(_) => assert_true(false)
  }
  // 验证 button 在槽位内
  match p.artboards.get(ab) {
    Some(x) => {
      assert_true(x.doc.has("m1_actions"))
      assert_true(x.doc.has("confirm_btn"))
      // confirm_btn 应该是 m1_actions 的子节点
      match x.doc.find_parent("confirm_btn") {
        Some(parent_id) => assert_eq(parent_id, "m1_actions")
        None => assert_true(false)
      }
    }
    None => assert_true(false)
  }
}

///|
test "插槽：组合式组件清单 JSON" {
  let json = list_slotted_json()
  assert_true(json.contains("\"card\""))
  assert_true(json.contains("\"list\""))
  assert_true(json.contains("\"modal\""))
  assert_true(json.contains("\"app_bar\""))
}

///|
test "插槽：App Bar 三栏布局" {
  let p = Project::new()
  let ab = p.create_artboard(name="bar_test")
  match
    p.place_slotted(artboard=ab, component_id="app_bar", instance_id="top_bar") {
    Ok(_) => {
      // 填充三个槽位
      let _ = p.fill_slot(
        artboard=ab,
        instance_id="top_bar",
        slot_name="leading",
        content="← Back",
      )
      let _ = p.fill_slot(
        artboard=ab,
        instance_id="top_bar",
        slot_name="title",
        content="My App",
      )
      let _ = p.fill_slot(
        artboard=ab,
        instance_id="top_bar",
        slot_name="trailing",
        content="⚙",
      )
      match p.list_slots(artboard=ab, instance_id="top_bar") {
        Ok(json) => {
          assert_true(json.contains("← Back"))
          assert_true(json.contains("My App"))
          assert_true(json.contains("⚙"))
        }
        Err(_) => assert_true(false)
      }
    }
    Err(_) => assert_true(false)
  }
}

///|
test "Agent 全流程：组合式组件 + 槽位填充 + 嵌套组件 + 主题 + 导出" {
  let p = Project::new()
  let ab = p.create_artboard(name="full_test")

  // 1) 放置 Modal（组合式组件）
  match
    p.place_slotted(
      artboard=ab,
      component_id="modal",
      instance_id="confirm_dialog",
    ) {
    Ok(_) => ()
    Err(_) => {
      assert_true(false)
      return
    }
  }

  // 2) 填充文字槽位
  let _ = p.fill_slot(
    artboard=ab,
    instance_id="confirm_dialog",
    slot_name="title",
    content="Confirm Delete",
  )
  let _ = p.fill_slot(
    artboard=ab,
    instance_id="confirm_dialog",
    slot_name="content",
    content="Are you sure?",
  )

  // 3) 在 actions 槽位放入按钮（递归组合）
  let _ = p.fill_slot_with_component(
    artboard=ab,
    instance_id="confirm_dialog",
    slot_name="actions",
    child_component="button",
    child_id="delete_btn",
  )

  // 4) 切换主题
  let _ = p.apply_theme("dark")

  // 5) 列出槽位
  match p.list_slots(artboard=ab, instance_id="confirm_dialog") {
    Ok(json) => {
      assert_true(json.contains("Confirm Delete"))
      assert_true(json.contains("Are you sure?"))
    }
    Err(_) => assert_true(false)
  }

  // 6) 导出 SVG
  let svg = p.export_svg(artboard=ab)
  assert_true(svg is Ok(_))
}
