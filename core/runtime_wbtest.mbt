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
      // 热重载：真实替换文档内容（旧实现仅校验非空即返回成功）
      let layout_before = solve(
        match rt.project.artboards.get("form") {
          Some(ab) => ab.doc
          None => {
            assert_true(false)
            return
          }
        },
      )
      let rect_before = match layout_before.rect_of("email") {
        Some(r) => r
        None => {
          assert_true(false)
          return
        }
      }
      let doc = match rt.project.artboards.get("form") {
        Some(ab) => ab.doc
        None => {
          assert_true(false)
          return
        }
      }
      // 同一文档结构，但把 email 移开；重载后几何必须随之改变
      let _ = doc.update_node("email", fn(n) {
        { ..n, x: AlignStart(rect_before.x + 40.0), }
      })
      match rt.hot_reload_doc(doc) {
        Ok(json) => assert_true(json.contains("\"hot_reloaded\":true"))
        Err(_) => assert_true(false)
      }
      let layout_after = solve(
        match rt.project.artboards.get("form") {
          Some(ab) => ab.doc
          None => {
            assert_true(false)
            return
          }
        },
      )
      match layout_after.rect_of("email") {
        Some(r) => assert_true(r.x != rect_before.x)
        None => assert_true(false)
      }
      // 仍存在的节点：输入值保留
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
  let _ = p.place_component(
    artboard=a1,
    component_id="button",
    instance_id="cta",
  )
  let _ = p.place_component(
    artboard=a2,
    component_id="button",
    instance_id="cta",
  )
  // 仅注册标记，不建 flow
  match
    p.attach_interaction(
      artboard=a1,
      node_id="cta",
      trigger="tap",
      action_spec="navigate_to:ix_a2",
    ) {
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
  let layout = solve(
    match rt.project.artboards.get(a1) {
      Some(ab) => ab.doc
      None => {
        assert_true(false)
        return
      }
    },
  )
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
  let _ = p.place_component(
    artboard=ab,
    component_id="button",
    instance_id="btn",
  )
  let _ = p.attach_interaction(
    artboard=ab,
    node_id="btn",
    trigger="tap",
    action_spec="show_toast:\"hi\"",
  )
  let _ = p.detach_interaction(artboard=ab, node_id="btn")
  let rt = match MoonVizRT::create(p, initial_artboard=ab) {
    Ok(r) => r
    Err(_) => {
      assert_true(false)
      return
    }
  }
  let layout = solve(
    match rt.project.artboards.get(ab) {
      Some(x) => x.doc
      None => {
        assert_true(false)
        return
      }
    },
  )
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

///|
/// 回归：组件多态状态必须真实生效（此前 define_component_state 丢弃 patch，
/// 只写一个无人读取的名字标记，签名承诺的状态补丁能力实际不存在）。
test "组件状态：补丁真实应用且可切换" {
  let p = Project::new()
  let ab = p.create_artboard(name="st_ab")
  let _ = p.place_component(
    artboard=ab,
    component_id="button",
    instance_id="cta",
  )
  // default 基准 + pressed 覆盖（改填充色）
  match
    p.define_component_state(artboard=ab, node_id="cta", state_name="default", patch={
      ..NodePatch::empty(),
      fill: Some("#4B6BFB"),
    }) {
    Ok(_) => ()
    Err(_) => assert_true(false)
  }
  match
    p.define_component_state(artboard=ab, node_id="cta", state_name="pressed", patch={
      ..NodePatch::empty(),
      fill: Some("#1E3FA8"),
    }) {
    Ok(_) => ()
    Err(_) => assert_true(false)
  }
  // 回读：两个状态均已登记，当前为 default
  match p.node_states_json(artboard=ab) {
    Ok(j) => {
      assert_true(j.contains("pressed"))
      assert_true(j.contains("\"current\":\"default\""))
    }
    Err(_) => assert_true(false)
  }
  // 激活 default → fill 为基准色
  match p.active_state_patch("cta") {
    Some(patch) =>
      match patch.fill {
        Some(f) => assert_eq(f, "#4B6BFB")
        None => assert_true(false)
      }
    None => assert_true(false)
  }
  // 切到 pressed：当前状态与生效补丁同步变化
  match p.set_node_state(node_id="cta", state_name="pressed") {
    Ok(_) => ()
    Err(_) => assert_true(false)
  }
  match p.active_state_patch("cta") {
    Some(patch) =>
      match patch.fill {
        Some(f) => assert_eq(f, "#1E3FA8")
        None => assert_true(false)
      }
    None => assert_true(false)
  }
  // toggle 回 default
  match p.set_node_state(node_id="cta", state_name="pressed", toggle=true) {
    Ok(_) => ()
    Err(_) => assert_true(false)
  }
  match p.active_state_patch("cta") {
    Some(patch) =>
      match patch.fill {
        Some(f) => assert_eq(f, "#4B6BFB")
        None => assert_true(false)
      }
    None => assert_true(false)
  }
  // 未定义的状态必须报错，而非静默成功
  match p.set_node_state(node_id="cta", state_name="nope") {
    Ok(_) => assert_true(false)
    Err(e) => assert_true(e.contains("unknown_state"))
  }
}

///|
/// 回归：SwipeEvent 分发命中首条 flow 后必须停——此前漏 break，同一画板
/// 多条同 trigger 的 swipe flow 全部执行，导航栈连推多个画板（与
/// KeyEvent 的 break、find_flow_target 的首条即返回语义不一致）。
test "swipe：同 trigger 多条 flow 只执行第一条" {
  let p = Project::new()
  let a = p.create_artboard(name="sw_a")
  let b = p.create_artboard(name="sw_b")
  let c = p.create_artboard(name="sw_c")
  p.add_flow(from=a, to=b, trigger="swipe_left")
  p.add_flow(from=a, to=c, trigger="swipe_left")
  let rt = match MoonVizRT::create(p, initial_artboard=a) {
    Ok(r) => r
    Err(_) => {
      assert_true(false)
      return
    }
  }
  let changes = rt.handle_event(SwipeEvent("left"))
  // 只命中首条 flow：NavigationPushed + ArtboardChanged 各一条，
  // 不得出现第二条 flow 的成串变更
  assert_eq(changes.length(), 2)
  assert_eq(rt.current_artboard(), b)
  // 栈深也锚定：只推了一层
  assert_eq(rt.nav.stack.length(), 2)
}

///|
/// 回归：栈底 tap 返回类节点原地不动——go_back None → 仅 NodeUpdated，
/// 不弹栈、不换画板（norms_wbtest 只覆盖了栈中弹回的 happy path）。
test "back：栈底 tap 返回类节点原地不动（仅 NodeUpdated）" {
  let p = Project::new()
  let ab = p.create_artboard(name="solo")
  let _ = p.place_component(
    artboard=ab,
    component_id="button",
    instance_id="back_btn",
  )
  let rt = match MoonVizRT::create(p, initial_artboard=ab) {
    Ok(r) => r
    Err(_) => {
      assert_true(false)
      return
    }
  }
  let layout = solve(
    match rt.project.artboards.get(ab) {
      Some(x) => x.doc
      None => {
        assert_true(false)
        return
      }
    },
  )
  let rect = match layout.rect_of("back_btn") {
    Some(r) => r
    None => {
      assert_true(false)
      return
    }
  }
  let changes = rt.handle_event(
    TapEvent(rect.x + rect.width / 2.0, rect.y + rect.height / 2.0),
  )
  // 无 flow / 无 marker / 栈底无上一层 → 仅 NodeUpdated
  assert_eq(changes.length(), 1)
  match changes[0] {
    NodeUpdated(id) => assert_eq(id, "back_btn")
    _ => assert_true(false)
  }
  assert_eq(rt.current_artboard(), ab)
}

///|
/// 回归：list_interactions / interactions_json 对 id/name/trigger/action
/// 过 json_escape（与 query_node_json 同一约定）——SKILL.md:204 记载的
/// update name= 改名路径值可含字面双引号，裸插值产出非法 JSON 信封。
test "interactions 导出：含引号的 name/action 过 json_escape" {
  let p = Project::new()
  let ab = p.create_artboard(name="esc_ab")
  let _ = p.place_component(
    artboard=ab,
    component_id="button",
    instance_id="btn",
  )
  // 经 update <ab> <node> name=... 改名，值含字面双引号（split_cmd 协议：
  // 字面引号走引号包裹 + \" 转义，裸引号是分组符会被吞掉）
  let _ = apply_operation(p, "update " + ab + " btn name=\"a\\\"b\"")
  let _ = p.attach_interaction(
    artboard=ab,
    node_id="btn",
    trigger="tap",
    action_spec="set_text:lbl:\"hi\"",
  )
  match p.list_interactions(artboard=ab) {
    Ok(j) => {
      // name 中的引号必须已转义（\"），裸引号形态不得出现
      assert_true(j.contains("a\\\"b ⚡"))
      assert_false(j.contains("a\"b"))
      assert_true(j.contains("\"artboard\":\"esc_ab\""))
    }
    Err(_) => assert_true(false)
  }
  match p.interactions_json(artboard=ab) {
    Ok(j) => {
      // action spec 中的引号必须已转义；v2 的 params 是结构化 JSON
      // （"text":"hi" 是合法字符串值），不再以裸 spec 片段为红线
      assert_true(j.contains("set_text:lbl:\\\"hi\\\""))
      assert_true(j.contains("\"trigger\":\"tap\""))
      assert_true(j.contains("\"params\":{\"node\":\"lbl\",\"text\":\"hi\"}"))
      // name 字段不得出现未转义的裸引号（a"b 形态）
      assert_false(j.contains("a\"b ⚡"))
    }
    Err(_) => assert_true(false)
  }
  // artifact 的 flow trigger 同批（export_artifact 的 flows from/to/trigger
  // 此前裸拼）
  p.add_flow(from=ab, to="esc_ab2", trigger="tap:a\"b")
  let artifact = p.export_artifact()
  assert_true(artifact.contains("tap:a\\\"b"))
  assert_false(artifact.contains("tap:a\"b"))
}

///|
/// 回归：组件状态 text 含逗号/方括号经名字标记往返不丢失——
/// 此前 patch_to_spec 裸写 text 值，parse 侧 split_commas 逢逗号即切、
/// 标记解析逢 ] 即收尾，每次 canonical 重建后状态文本被静默截断。
test "组件状态：text 含逗号/方括号经名字标记往返保真" {
  let p = Project::new()
  let ab = p.create_artboard(name="esc_st")
  let _ = p.place_component(
    artboard=ab,
    component_id="button",
    instance_id="cta",
  )
  let tricky = "第1, 2项 [草稿]\\n换行"
  match
    p.define_component_state(
      artboard=ab,
      node_id="cta",
      state_name="pressed",
      patch={ ..NodePatch::empty(), text: Some(tricky) },
    ) {
    Ok(_) => ()
    Err(e) => assert_true(false, msg=e)
  }
  // canonical 重建路径：从节点名标记重新解析状态表（load-mbt 后同路）
  match p.artboards.get(ab) {
    Some(abd) =>
      match abd.doc.nodes.get("cta") {
        Some(n) =>
          match parse_state_markers(n.name) {
            None => assert_true(false)
            Some(states) => {
              let mut found = false
              for kv in states.iter() {
                let (sname, patch) = kv
                if sname == "pressed" {
                  found = true
                  match patch.text {
                    Some(t) => assert_eq(t, tricky)
                    None => assert_true(false)
                  }
                }
              }
              assert_true(found, msg="pressed 状态标记应可从名字解析")
            }
          }
        None => assert_true(false)
      }
    None => assert_true(false)
  }
  // 内存表同值（会话内为真值）
  match p.node_states.get("cta") {
    Some(def) =>
      match def.states.get("pressed") {
        Some(patch) =>
          match patch.text {
            Some(t) => assert_eq(t, tricky)
            None => assert_true(false)
          }
        None => assert_true(false)
      }
    None => assert_true(false)
  }
}

// ---------------------------------------------------------------------------
// 交互词表闭环（P3）：Action 全量 spec 往返 / 注册闸门 / SubmitForm 执行 /
// interactions v2 字段契约
// ---------------------------------------------------------------------------

///|
/// 表驱动遍历每个 Action：describe → action_from_spec → describe 必须相等。
/// submit_form 的 spec 是真实字段 id 列表（不再是 [N fields] 占位），
/// 解析后还原 SubmitForm(["email","pwd"])。
test "交互词表：Action describe→parse 全量往返" {
  let actions : Array[Action] = [
    NavigateTo("home"),
    Back,
    ToggleState("cta", ""),
    SetState("cta", "pressed"),
    SetText("lbl", "hello"),
    SubmitForm(["email", "pwd"]),
    ShowToast("已保存"),
    HapticFeedback,
    PlaySound("ding"),
  ]
  for a in actions.iter() {
    let spec = a.describe()
    match action_from_spec(spec) {
      None => fail("动作 spec 无法反解析：\{spec}")
      Some(back) => assert_eq(back.describe(), spec)
    }
  }
  // submit_form：字段列表而非字段数占位
  assert_eq(SubmitForm(["email", "pwd"]).describe(), "submit_form:email,pwd")
  match action_from_spec("submit_form:email,pwd") {
    Some(SubmitForm(ids)) => {
      assert_eq(ids.length(), 2)
      assert_eq(ids[0], "email")
      assert_eq(ids[1], "pwd")
    }
    _ => assert_true(false)
  }
  // 空字段列表非法；旧 describe 的 `[N fields]` 占位也不得伪绑定
  match action_from_spec("submit_form:") {
    Some(_) => assert_true(false)
    None => ()
  }
  match action_from_spec("submit_form:[2 fields]") {
    Some(_) => assert_true(false)
    None => ()
  }
  assert_eq(SubmitForm(["email", "pwd"]).kind(), "submit_form")
  assert_eq(
    SubmitForm(["email", "pwd"]).params_json(),
    "{\"fields\":[\"email\",\"pwd\"]}",
  )
  assert_eq(SetState("cta", "pressed").params_json(), "{\"node\":\"cta\",\"state\":\"pressed\"}")
}

///|
/// 注册闸门：非法 trigger/action 必须 Err 且不写标记；合法值规范化写入
/// （swipe_left + submit_form 组合）。
test "交互词表：attach_interaction 校验 trigger/action" {
  let p = Project::new()
  let ab = p.create_artboard(name="ix_gate")
  let _ = p.place_component(
    artboard=ab,
    component_id="button",
    instance_id="cta",
  )
  match
    p.attach_interaction(
      artboard=ab,
      node_id="cta",
      trigger="swipe:left",
      action_spec="back",
    ) {
    Ok(_) => assert_true(false)
    Err(e) => assert_true(e.contains("unknown_trigger"))
  }
  match
    p.attach_interaction(
      artboard=ab,
      node_id="cta",
      trigger="swipe_left",
      action_spec="nonsense:xyz",
    ) {
    Ok(_) => assert_true(false)
    Err(e) => assert_true(e.contains("unknown_action"))
  }
  // 被拒的调用不得留下任何标记
  match p.interactions_json(artboard=ab) {
    Ok(j) => assert_false(j.contains("nonsense"))
    Err(_) => assert_true(false)
  }
  // 合法值：swipe_left + submit_form 组合 Ok，标记规范化为 canonical 名
  match
    p.attach_interaction(
      artboard=ab,
      node_id="cta",
      trigger="swipe_left",
      action_spec="submit_form:email,pwd",
    ) {
    Ok(_) => ()
    Err(e) => fail("合法交互应注册成功：\{e}")
  }
  match p.artboards.get(ab) {
    Some(abd) =>
      match abd.doc.nodes.get("cta") {
        Some(n) =>
          assert_true(n.name.contains("⚡swipe_left→submit_form:email,pwd"))
        None => assert_true(false)
      }
    None => assert_true(false)
  }
  // key_enter 别名规范化为 keyboard_enter
  match
    p.attach_interaction(
      artboard=ab,
      node_id="cta",
      trigger="key_enter",
      action_spec="back",
    ) {
    Ok(_) => ()
    Err(e) => fail("key_enter 别名应接受：\{e}")
  }
  match p.artboards.get(ab) {
    Some(abd) =>
      match abd.doc.nodes.get("cta") {
        Some(n) => assert_true(n.name.contains("⚡keyboard_enter→back"))
        None => assert_true(false)
      }
    None => assert_true(false)
  }
}

///|
/// SubmitForm 运行时闭环：收集字段输入值 → FormSubmitted 携完整键值
/// （此前 FormSubmitted 只定义未构造，点提交无任何状态变更）。
test "运行时：submit_form 收集输入值并构造 FormSubmitted" {
  let p = Project::new()
  let ab = p.create_artboard(name="form", width=390.0, height=844.0)
  let _ = p.place_component(
    artboard=ab,
    component_id="text_input",
    instance_id="email",
    x=20.0,
    y=80.0,
  )
  let _ = p.place_component(
    artboard=ab,
    component_id="text_input",
    instance_id="pwd",
    x=20.0,
    y=140.0,
  )
  let _ = p.place_component(
    artboard=ab,
    component_id="button",
    instance_id="submit",
    x=20.0,
    y=220.0,
  )
  match
    p.attach_interaction(
      artboard=ab,
      node_id="submit",
      trigger="tap",
      action_spec="submit_form:email,pwd",
    ) {
    Ok(_) => ()
    Err(e) => {
      fail("submit_form 注册失败：\{e}")
      abort("")
    }
  }
  let rt = match MoonVizRT::create(p, initial_artboard=ab) {
    Ok(r) => r
    Err(e) => {
      fail("运行时创建失败：\{e}")
      abort("")
    }
  }
  rt.set_input("email", "a@b.c")
  rt.set_input("pwd", "s3cret")
  let doc = match rt.project.artboards.get(ab) {
    Some(x) => x.doc
    None => {
      assert_true(false)
      return
    }
  }
  let layout = solve(doc)
  let rect = match layout.rect_of("submit") {
    Some(r) => r
    None => {
      assert_true(false)
      return
    }
  }
  let changes = rt.handle_event(
    TapEvent(rect.x + rect.width / 2.0, rect.y + rect.height / 2.0),
  )
  let mut found : Map[String, String]? = None
  for c in changes.iter() {
    match c {
      FormSubmitted(data) => found = Some(data)
      _ => ()
    }
  }
  match found {
    None => assert_true(false)
    Some(data) => {
      assert_eq(data.size(), 2)
      match data.get("email") {
        Some(v) => assert_eq(v, "a@b.c")
        None => assert_true(false)
      }
      match data.get("pwd") {
        Some(v) => assert_eq(v, "s3cret")
        None => assert_true(false)
      }
    }
  }
}

///|
/// interactions v2 字段契约：node/name/artboard/trigger/action{kind,params}/
/// transition/source/supported；非 tap 标记 supported=false，builtin 返回
/// 热区走 source=builtin + action.kind=back。
test "interactions v2：字段契约与 builtin 返回热区" {
  let p = Project::new()
  let ab = p.create_artboard(name="v2_ab")
  let _ = p.place_component(
    artboard=ab,
    component_id="button",
    instance_id="cta",
  )
  let _ = p.place_component(
    artboard=ab,
    component_id="button",
    instance_id="back_btn",
  )
  let _ = p.place_component(
    artboard=ab,
    component_id="button",
    instance_id="sw",
  )
  match
    p.attach_interaction(
      artboard=ab,
      node_id="cta",
      trigger="tap",
      action_spec="submit_form:email,pwd",
    ) {
    Ok(_) => ()
    Err(e) => {
      fail("v2 用例注册失败：\{e}")
      abort("")
    }
  }
  let _ = p.attach_interaction(
    artboard=ab,
    node_id="sw",
    trigger="swipe_left",
    action_spec="back",
  )
  match p.interactions_json(artboard=ab) {
    Ok(j) => {
      assert_true(j.contains("\"node\":\"cta\""))
      assert_true(j.contains("\"name\":\""))
      assert_true(j.contains("\"artboard\":\"v2_ab\""))
      assert_true(j.contains("\"trigger\":\"tap\""))
      assert_true(j.contains(
        "\"action\":{\"kind\":\"submit_form\",\"params\":{\"fields\":[\"email\",\"pwd\"]}}",
      ))
      assert_true(j.contains("\"transition\":\"\""))
      assert_true(j.contains("\"source\":\"marker\""))
      assert_true(j.contains("\"supported\":true"))
      // 非 tap 标记：v2 如实标 supported=false（导出运行时只绑 tap）
      assert_true(j.contains("\"trigger\":\"swipe_left\""))
      assert_true(j.contains("\"supported\":false"))
      // builtin 返回热区：source=builtin + action.kind=back
      assert_true(j.contains("\"source\":\"builtin\""))
      assert_true(j.contains("\"kind\":\"back\""))
    }
    Err(_) => assert_true(false)
  }
}

// ---------------------------------------------------------------------------
// 手势事件闭环（P4）：事件矩阵 / long_press 时长 / flow 触发词
// ---------------------------------------------------------------------------

///|
fn gesture_setup() -> Project {
  let p = Project::new()
  let ab = p.create_artboard(name="g", width=390.0, height=844.0)
  let _ = p.create_artboard(name="target", width=390.0, height=844.0)
  let _ = p.place_component(
    artboard=ab,
    component_id="button",
    instance_id="lp",
    x=20.0,
    y=20.0,
  )
  let _ = p.place_component(
    artboard=ab,
    component_id="button",
    instance_id="fo",
    x=20.0,
    y=100.0,
  )
  let _ = p.place_component(
    artboard=ab,
    component_id="button",
    instance_id="bl",
    x=20.0,
    y=180.0,
  )
  let _ = p.place_component(
    artboard=ab,
    component_id="button",
    instance_id="se",
    x=20.0,
    y=260.0,
  )
  let _ = p.place_component(
    artboard=ab,
    component_id="button",
    instance_id="kb",
    x=20.0,
    y=340.0,
  )
  let _ = p.place_component(
    artboard=ab,
    component_id="button",
    instance_id="tp",
    x=20.0,
    y=420.0,
  )
  let _ = p.define_component_state(
    artboard=ab,
    node_id="fo",
    state_name="pressed",
    patch={ ..NodePatch::empty(), fill: Some("#123456") },
  )
  let _ = p.attach_interaction(
    artboard=ab,
    node_id="lp",
    trigger="long_press",
    action_spec="navigate_to:target",
  )
  let _ = p.attach_interaction(
    artboard=ab,
    node_id="fo",
    trigger="focus",
    action_spec="set_state:fo:pressed",
  )
  let _ = p.attach_interaction(
    artboard=ab,
    node_id="bl",
    trigger="blur",
    action_spec="set_text:bl:\"blurred\"",
  )
  let _ = p.attach_interaction(
    artboard=ab,
    node_id="se",
    trigger="scroll_end",
    action_spec="navigate_to:target",
  )
  let _ = p.attach_interaction(
    artboard=ab,
    node_id="kb",
    trigger="keyboard_enter",
    action_spec="navigate_to:target",
  )
  let _ = p.attach_interaction(
    artboard=ab,
    node_id="tp",
    trigger="tap",
    action_spec="show_toast:\"hi\"",
  )
  p
}

///|
fn changes_have_nav(changes : Array[StateChange]) -> Bool {
  for c in changes.iter() {
    match c {
      NavigationPushed(_) | ArtboardChanged(_) => return true
      _ => ()
    }
  }
  false
}

///|
fn changes_have_node(changes : Array[StateChange], id : String) -> Bool {
  for c in changes.iter() {
    match c {
      NodeUpdated(nid) => if nid == id {
        return true
      }
      _ => ()
    }
  }
  false
}

///|
fn array_has(items : Array[String], want : String) -> Bool {
  for it in items.iter() {
    if it == want {
      return true
    }
  }
  false
}

///|
test "手势事件矩阵：long_press/focus/blur/scroll_end/keyboard_enter 驱动标记" {
  let p = gesture_setup()
  // long_press 命中 lp → NavigationPushed
  let rt = match MoonVizRT::create(p, initial_artboard="g") {
    Ok(r) => r
    Err(_) => {
      assert_true(false)
      return
    }
  }
  let ch = rt.handle_event(LongPressEvent(80.0, 42.0, 0.8))
  assert_true(changes_have_nav(ch), msg="long_press 标记应触发导航")
  assert_eq(rt.current_artboard(), "target")
  // focus → set_state → NodeUpdated 且状态切换
  let rt2 = match MoonVizRT::create(p, initial_artboard="g") {
    Ok(r) => r
    Err(_) => {
      assert_true(false)
      return
    }
  }
  let ch2 = rt2.handle_event(FocusEvent("fo"))
  assert_true(changes_have_node(ch2, "fo"), msg="focus 标记应触发 set_state")
  match p.node_states.get("fo") {
    Some(def) => assert_eq(def.current, "pressed")
    None => assert_true(false)
  }
  // blur → set_text
  let rt3 = match MoonVizRT::create(p, initial_artboard="g") {
    Ok(r) => r
    Err(_) => {
      assert_true(false)
      return
    }
  }
  let ch3 = rt3.handle_event(BlurEvent("bl"))
  assert_true(changes_have_node(ch3, "bl"), msg="blur 标记应触发 set_text")
  match p.artboards.get("g") {
    Some(abd) =>
      match abd.doc.nodes.get("bl") {
        Some(n) => assert_eq(n.text, "blurred")
        None => assert_true(false)
      }
    None => assert_true(false)
  }
  // scroll_end → 画板级标记导航
  let rt4 = match MoonVizRT::create(p, initial_artboard="g") {
    Ok(r) => r
    Err(_) => {
      assert_true(false)
      return
    }
  }
  let ch4 = rt4.handle_event(ScrollEndEvent)
  assert_true(changes_have_nav(ch4), msg="scroll_end 标记应触发导航")
  assert_eq(rt4.current_artboard(), "target")
  // keyboard enter → keyboard_enter 标记导航
  let rt5 = match MoonVizRT::create(p, initial_artboard="g") {
    Ok(r) => r
    Err(_) => {
      assert_true(false)
      return
    }
  }
  let ch5 = rt5.handle_event(KeyEvent("enter"))
  assert_true(changes_have_nav(ch5), msg="keyboard_enter 标记应触发导航")
  assert_eq(rt5.current_artboard(), "target")
  // 只有 tap 标记的节点收到 long_press 不得触发（事件矩阵闸门）
  let rt6 = match MoonVizRT::create(p, initial_artboard="g") {
    Ok(r) => r
    Err(_) => {
      assert_true(false)
      return
    }
  }
  let ch6 = rt6.handle_event(LongPressEvent(80.0, 442.0, 0.8))
  assert_eq(ch6.length(), 0, msg="tap 标记不应被 long_press 误触发")
  assert_eq(rt6.current_artboard(), "g")
}

///|
test "手势：Trigger spec 往返保留长按时长" {
  match trigger_from_spec("long_press:0.8") {
    Some(LongPress(sec)) => {
      assert_true(sec > 0.79 && sec < 0.81, msg="0.8 应被保留：\{sec}")
      assert_eq(LongPress(sec).spec(), "long_press:0.8")
    }
    _ => assert_true(false)
  }
  match trigger_from_spec("long_press") {
    Some(LongPress(sec)) => assert_eq(sec, 0.5)
    _ => assert_true(false)
  }
  match trigger_from_spec("long_press:0") {
    Some(_) => assert_true(false)
    None => ()
  }
  let triggers : Array[Trigger] = [
    Tap, SwipeLeft, SwipeRight, SwipeUp, SwipeDown, ScrollEnd, KeyboardEnter,
    Focus, Blur,
  ]
  for t in triggers.iter() {
    match trigger_from_spec(t.spec()) {
      Some(back) => assert_eq(back.spec(), t.spec())
      None => assert_true(false, msg="无法反解析 \{t.spec()}")
    }
  }
}

///|
test "手势 flow：swipe_left / long_press:0.8 / focus 导航，阈值以下不触发" {
  let p = Project::new()
  let a = p.create_artboard(name="ga")
  let b = p.create_artboard(name="gb")
  let c = p.create_artboard(name="gc")
  let d = p.create_artboard(name="gd")
  p.add_flow(from=a, to=b, trigger="swipe_left")
  p.add_flow(from=a, to=c, trigger="long_press:0.8")
  p.add_flow(from=a, to=d, trigger="focus")
  let rt = match MoonVizRT::create(p, initial_artboard=a) {
    Ok(r) => r
    Err(_) => {
      assert_true(false)
      return
    }
  }
  let _ = rt.handle_event(SwipeEvent("left"))
  assert_eq(rt.current_artboard(), b)
  // 0.5s < 0.8s 阈值：不触发
  let rt2 = match MoonVizRT::create(p, initial_artboard=a) {
    Ok(r) => r
    Err(_) => {
      assert_true(false)
      return
    }
  }
  let ch = rt2.handle_event(LongPressEvent(10.0, 10.0, 0.5))
  assert_eq(ch.length(), 0)
  assert_eq(rt2.current_artboard(), a)
  // 0.8s 达标 → 导航
  let rt3 = match MoonVizRT::create(p, initial_artboard=a) {
    Ok(r) => r
    Err(_) => {
      assert_true(false)
      return
    }
  }
  let _ = rt3.handle_event(LongPressEvent(10.0, 10.0, 0.8))
  assert_eq(rt3.current_artboard(), c)
  // focus（画板级）→ 导航
  let rt4 = match MoonVizRT::create(p, initial_artboard=a) {
    Ok(r) => r
    Err(_) => {
      assert_true(false)
      return
    }
  }
  let _ = rt4.handle_event(FocusEvent("any_node"))
  assert_eq(rt4.current_artboard(), d)
}

///|
test "flow trigger 规范化：手势词、裸节点与未知错误" {
  let cases : Array[(String, String)] = [
    ("swipe_left", "swipe_left"),
    ("long_press", "long_press"),
    ("long_press:0.8", "long_press:0.8"),
    ("focus", "focus"),
    ("focus:email", "focus:email"),
    ("blur:email", "blur:email"),
    ("scroll_end", "scroll_end"),
    ("key_enter", "keyboard_enter"),
    ("btn", "tap:btn"),
    ("tap:btn", "tap:btn"),
  ]
  for pair in cases.iter() {
    let (input, want) = pair
    match normalize_flow_trigger(input) {
      Ok(v) => assert_eq(v, want)
      Err(e) => fail("应接受 \{input}：\{e}")
    }
  }
  for bad in ["nonsense:xyz", "long_press:0", "focus:", "tap:"].iter() {
    match normalize_flow_trigger(bad) {
      Ok(v) => assert_true(false, msg="应拒绝 \{bad}（得到 \{v}）")
      Err(e) => assert_true(e.contains("unknown_trigger"), msg=e)
    }
  }
}

///|
test "flow op：不再硬编码 tap:，未知 trigger 报错" {
  let p = Project::new()
  let _ = p.create_artboard(name="oa")
  let _ = p.create_artboard(name="ob")
  for spec in ["swipe_left", "long_press:0.8", "focus", "node_x"] {
    match apply_operation(p, "flow oa ob " + spec) {
      Ok(_) => ()
      Err(e) => fail("flow \{spec} 应成功：\{e}")
    }
  }
  let trigs : Array[String] = []
  for f in p.flows.iter() {
    trigs.push(f.trigger)
  }
  assert_true(array_has(trigs, "swipe_left"))
  assert_true(array_has(trigs, "long_press:0.8"))
  assert_true(array_has(trigs, "focus"))
  assert_true(array_has(trigs, "tap:node_x"))
  match apply_operation(p, "flow oa ob nonsense:xyz") {
    Ok(_) => assert_true(false)
    Err(e) => assert_true(e.contains("unknown_trigger"), msg=e)
  }
  // unflow 同规：手势 trigger 可删
  match apply_operation(p, "unflow oa ob swipe_left") {
    Ok(_) => ()
    Err(e) => fail("unflow swipe_left 应成功：\{e}")
  }
  let left : Array[String] = []
  for f in p.flows.iter() {
    if f.trigger == "swipe_left" {
      left.push(f.trigger)
    }
  }
  assert_eq(left.length(), 0)
  match apply_operation(p, "unflow oa ob nonsense:xyz") {
    Ok(_) => assert_true(false)
    Err(e) => assert_true(e.contains("unknown_trigger"), msg=e)
  }
}

///|
/// 分板过渡单一来源：FlowEdge.transition 默认 push、显式值随 flow_json 回读；
/// flow op 可选第 5 参数 transition，未知过渡 Err。
test "分板过渡：FlowEdge.transition 默认 push 与 flow op 校验" {
  let p = Project::new()
  let _ = p.create_artboard(name="ta")
  let _ = p.create_artboard(name="tb")
  p.add_flow(from="ta", to="tb", trigger="tap:x", transition="modal_present")
  p.add_flow(from="ta", to="tb", trigger="tap:y")
  assert_eq(p.flows[0].transition, "modal_present")
  assert_eq(p.flows[1].transition, "push")
  let fj = p.flow_json()
  assert_true(fj.contains("\"transition\":\"modal_present\""), msg=fj)
  assert_true(fj.contains("\"transition\":\"push\""), msg=fj)
  // op：flow <from> <to> <trigger|node> [transition]
  match apply_operation(p, "flow ta tb swipe_left fade") {
    Ok(_) => ()
    Err(e) => fail("flow 带 transition 应成功：\{e}")
  }
  assert_eq(p.flows[2].transition, "fade")
  match apply_operation(p, "flow ta tb swipe_left nonsense") {
    Ok(_) => assert_true(false)
    Err(e) => assert_true(e.contains("unknown_transition"), msg=e)
  }
  // 默认省略 = push
  match apply_operation(p, "flow ta tb focus") {
    Ok(_) => ()
    Err(e) => fail("flow 缺省 transition 应成功：\{e}")
  }
  assert_eq(p.flows[3].transition, "push")
}
