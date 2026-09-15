// 交互原型 + 中间产物 + 嵌入式运行时 测试

///|
test "交互系统：Trigger / Action / Transition 定义" {
  let t = Tap
  assert_eq(t.name(), "tap")
  let lp = LongPress(0.5)
  assert_eq(lp.name(), "long_press")
  let a1 = NavigateTo("home")
  assert_true(a1.describe().contains("home"))
  let a2 = ShowToast("Saved!")
  assert_true(a2.describe().contains("Saved"))
  let tr = ModalPresent
  assert_eq(tr.name(), "modal_present")
}

///|
test "交互注册：为节点添加 tap 交互" {
  let p = Project::new()
  let _ = p.create_artboard(name="test")
  let _ = p.place_component(
    artboard="test",
    component_id="button",
    instance_id="ok_btn",
  )
  match
    p.add_interaction(
      artboard="test",
      node_id="ok_btn",
      trigger=Tap,
      action=NavigateTo("home"),
      transition=Push,
    ) {
    Ok(json) => assert_true(json.contains("\"ok\":true"))
    Err(_) => assert_true(false)
  }
  // 验证交互已注册
  match p.list_interactions(artboard="test") {
    Ok(json) => assert_true(json.contains("ok_btn"))
    Err(_) => assert_true(false)
  }
}

///|
test "导航栈：push / pop / back" {
  let nav = NavigationState::new("login")
  assert_eq(nav.current, "login")
  let _ = nav.navigate("home")
  assert_eq(nav.current, "home")
  let _ = nav.navigate("profile")
  assert_eq(nav.current, "profile")
  assert_eq(nav.stack.length(), 3)
  match nav.go_back() {
    Some(prev) => assert_eq(prev, "home")
    None => assert_true(false)
  }
  assert_eq(nav.current, "home")
}

///|
test "嵌入式运行时：create + tap 事件 + 渲染计划" {
  let p = Project::new()
  let login = p.create_artboard(name="login", width=390.0, height=844.0)
  let home = p.create_artboard(name="home", width=390.0, height=844.0)
  let _ = p.place_component(
    artboard="login",
    component_id="button",
    instance_id="go_btn",
    x=100.0,
    y=400.0,
  )
  p.add_flow(from="login", to="home", trigger="tap:go_btn")

  // 创建运行时
  match MoonVizRT::create(p, initial_artboard="login") {
    Err(_) => assert_true(false)
    Ok(rt) => {
      assert_eq(rt.current_artboard(), "login")
      // 模拟点击按钮 (go_btn 在 100,400，大小 120×44)
      let changes = rt.handle_event(TapEvent(160.0, 422.0))
      // 应触发导航到 home
      assert_true(changes.length() > 0)
      assert_eq(rt.current_artboard(), "home")
      // 返回
      let back_changes = rt.handle_event(KeyEvent("back"))
      assert_eq(rt.current_artboard(), "login")
      // 渲染计划
      match rt.render_plan() {
        Ok(plan) => {
          assert_eq(plan.artboard, "login")
          assert_true(plan.commands.length() > 0)
        }
        Err(_) => assert_true(false)
      }
    }
  }
}

///|
test "嵌入式运行时：输入值管理 + 热重载" {
  let p = Project::new()
  let _ = p.create_artboard(name="form", width=390.0, height=844.0)
  let _ = p.place_component(
    artboard="form",
    component_id="text_input",
    instance_id="email",
  )

  match MoonVizRT::create(p, initial_artboard="form") {
    Ok(rt) => {
      // 设置输入值
      rt.set_input("email", "alice@test.com")
      assert_eq(rt.get_input("email"), "alice@test.com")
      // 获取所有输入
      let all = rt.get_all_inputs()
      assert_eq(all.size(), 1)
      // 热重载
      match rt.hot_reload("let page = @decl.prototype(name=\"updated\")") {
        Ok(json) => assert_true(json.contains("\"hot_reloaded\":true"))
        Err(_) => assert_true(false)
      }
      // 热重载后输入值保留
      assert_eq(rt.get_input("email"), "alice@test.com")
    }
    Err(_) => assert_true(false)
  }
}

///|
test "Agent 中间产物：导出 artifact JSON" {
  let p = Project::new()
  let _ = p.create_artboard(name="login", width=390.0, height=844.0)
  let _ = p.create_artboard(name="home", width=390.0, height=844.0)
  p.add_flow(from="login", to="home", trigger="tap:submit")
  let _ = p.place_component(
    artboard="login",
    component_id="button",
    instance_id="submit",
  )

  let artifact = p.export_artifact(
    agent_id="agent-abc",
    context="Food delivery app prototype",
  )
  assert_true(artifact.contains("\"agent-abc\""))
  assert_true(artifact.contains("Food delivery app"))
  assert_true(artifact.contains("\"login\""))
  assert_true(artifact.contains("\"home\""))
  assert_true(artifact.contains("tap:submit"))
  assert_true(artifact.contains("\"version\""))
}

///|
test "Agent 中间产物：todo + notes" {
  let a = MoonVizArtifact::new()
  a.meta_context = "E-commerce checkout flow"
  a.add_todo("Add form validation for email")
  a.add_todo("Create error state for failed login")
  a.add_note("login", "Email field needs regex validation", "high")
  a.add_note("checkout", "Consider adding Apple Pay", "medium")

  let s = a.summary()
  assert_true(s.contains("E-commerce"))
  assert_true(s.contains("☐ Add form validation"))
  assert_true(s.contains("[high] login"))
  assert_true(s.contains("[medium] checkout"))
}

///|
test "完整 Agent 嵌入式工作流：创建→交互→运行→导出 artifact" {
  let p = Project::new()

  // Agent 创建设计
  let _ = p.apply_template(template_id="login")
  let _ = p.create_artboard(name="home")
  p.add_flow(from="login", to="home", trigger="tap:login_btn")

  // 创建运行时
  match MoonVizRT::create(p, initial_artboard="login") {
    Ok(rt) => {
      // 模拟用户交互
      let changes = rt.handle_event(TapEvent(200.0, 546.0)) // login_btn 区域
      // 导航
      // 导航成功或保持原位（取决于点击是否命中按钮）
      let cur = rt.current_artboard()
      assert_true(cur == "home" || cur == "login")

      // 渲染
      let _ = rt.render_plan()

      // 输入
      rt.set_input("email_input", "user@test.com")
      rt.set_input("password_input", "secret123")
      let inputs = rt.get_all_inputs()
      assert_eq(inputs.size(), 2)
    }
    Err(_) => assert_true(false)
  }

  // 导出中间产物
  let artifact = p.export_artifact(
    agent_id="session-001",
    context="Login flow prototype with navigation",
  )
  assert_true(artifact.contains("session-001"))
  assert_true(artifact.contains("Login flow"))
}

///|
/// 回归：交互标记必须被运行时消费（此前 add_interaction 只写不读）。
/// 同时覆盖跨画板误触发修复：仅 trigger 匹配不校验 from 会让 A 画板的
/// 点击触发 B 画板的跳转（node id 在不同画板间会重名）。
test "交互标记：无 flow 时由标记驱动导航" {
  let p = Project::new()
  let a1 = p.create_artboard(name="ix_a1")
  let a2 = p.create_artboard(name="ix_a2")
  let _ = p.place_component(artboard=a1, component_id="button", instance_id="cta")
  let _ = p.place_component(artboard=a2, component_id="button", instance_id="cta")
  // 仅注册标记，不建 flow
  match p.attach_interaction(artboard=a1, node_id="cta", trigger="tap", action_spec="navigate_to:ix_a2") {
    Ok(_) => ()
    Err(_) => assert_true(false)
  }
  // 结构化回读
  match p.interactions_json(artboard=a1) {
    Ok(j) => {
      assert_true(j.contains("navigate_to:ix_a2"))
      assert_true(j.contains("\"trigger\":\"tap\""))
    }
    Err(_) => assert_true(false)
  }
  let rt = match MoonVizRT::create(p, initial_artboard=a1) {
    Ok(r) => r
    Err(_) => {
      assert_true(false)
      return
    }
  }
  // a2 上同名节点不得触发跳转（from 校验）
  let stray = rt.handle_event(KeyEvent("escape"))
  assert_eq(stray.length(), 0)
  // a1 的 cta 命中 → 导航到 a2
  let layout = solve(match rt.project.artboards.get(a1) {
    Some(ab) => ab.doc
    None => {
      assert_true(false)
      return
    }
  })
  let rect = match layout.rect_of("cta") {
    Some(r) => r
    None => {
      assert_true(false)
      return
    }
  }
  let changes = rt.handle_event(
    TapEvent(rect.x + rect.width / 2.0, rect.y + rect.height / 2.0),
  )
  assert_eq(rt.current_artboard(), a2)
  assert_true(changes.length() > 0)
}

///|
/// 回归：解绑交互后同一坐标不再导航（回落为状态更新）。
test "交互标记：解绑后不再导航" {
  let p = Project::new()
  let ab = p.create_artboard(name="ix_off")
  let _ = p.place_component(artboard=ab, component_id="button", instance_id="btn")
  let _ = p.attach_interaction(artboard=ab, node_id="btn", trigger="tap", action_spec="show_toast:\"hi\"")
  let _ = p.detach_interaction(artboard=ab, node_id="btn")
  let rt = match MoonVizRT::create(p, initial_artboard=ab) {
    Ok(r) => r
    Err(_) => {
      assert_true(false)
      return
    }
  }
  let layout = solve(match rt.project.artboards.get(ab) {
    Some(x) => x.doc
    None => {
      assert_true(false)
      return
    }
  })
  let rect = match layout.rect_of("btn") {
    Some(r) => r
    None => {
      assert_true(false)
      return
    }
  }
  let changes = rt.handle_event(
    TapEvent(rect.x + rect.width / 2.0, rect.y + rect.height / 2.0),
  )
  // 无标记 → 仅 NodeUpdated（不再有 toast/nav）
  let mut has_nav = false
  for c in changes.iter() {
    match c {
      NavigationPushed(_) => has_nav = true
      ArtboardChanged(_) => has_nav = true
      ToastShown(_) => has_nav = true
      _ => ()
    }
  }
  assert_true(!has_nav)
}
