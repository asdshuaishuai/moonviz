///|
/// 生成式 UI：意图解析确定性 + 一调用生成管线（模板 → 自愈 → 报告）
test "generate：意图解析与生成信封" {
  // 意图解析：中英关键词 + 主题/设备暗示（确定性，同输入恒同决策）
  let i1 = parse_generate_intent("登录页 dark")
  assert_true(i1.template_id == "login")
  assert_true(i1.theme == "dark")
  let i2 = parse_generate_intent("web 落地页")
  assert_true(i2.template_id == "web_landing")
  let i3 = parse_generate_intent("平板 仪表盘")
  assert_true(i3.template_id == "dashboard")
  assert_true(i3.width == 768.0)
  // 无命中 → 空状态兜底（最安全的生成物，低置信可见）
  let i4 = parse_generate_intent("随便说说")
  assert_true(i4.template_id == "empty_state")
  // 一调用生成：模板 → auto_fix → missing/score 报告
  let p = Project::new()
  let json = match p.generate(intent_text="登录页") {
    Ok(j) => j
    Err(_) => ""
  }
  assert_true(json.contains("\"template\":\"login\""))
  assert_true(json.contains("\"artboard\":\"login\""))
  assert_true(json.contains("\"autofix\""))
  assert_true(json.contains("\"missing\""))
  assert_true(json.contains("\"score\""))
  // 生成即合规：生成物零谓词违规
  match p.artboards.get("login") {
    Some(ab) => assert_true(validate(ab.doc).length() == 0)
    None => assert_true(false)
  }
  // 自定义画板名 + 第二次生成（设置语义 → settings 模板）
  let _ = p.generate(intent_text="设置页", name="my_settings")
  assert_true(p.artboards.contains("my_settings"))
}

///|
/// 执行策略第二级：批量执行——一次提交、遇错即停、断点索引、上限护栏
test "ops_batch：一次提交与断点即停" {
  // 断点即停：index 0 成功，index 1 节点不存在报错且停
  let p = Project::new()
  match apply_operations(p, ["create home 390 844", "update home ghost text=x"]) {
    Ok(_) => assert_true(false)
    Err((index, _)) => assert_true(index == 1)
  }
  // 全合法序列：一次提交全部生效
  let p2 = Project::new()
  match apply_operations(p2, ["create a 390 844", "create b 390 844"]) {
    Ok(applied) => assert_true(applied == 2)
    Err(_) => assert_true(false)
  }
  // 上限护栏：超 OPS_BATCH_LIMIT 拒绝（index = -1）
  let many : Array[String] = []
  let mut i = 0
  while i <= OPS_BATCH_LIMIT {
    many.push("create x\{i} 100 100")
    i = i + 1
  }
  match apply_operations(p2, many) {
    Ok(_) => assert_true(false)
    Err((index, error)) => {
      assert_true(index == -1)
      assert_true(error.contains("too_many"))
    }
  }
}

///|
/// 工具字典：生成式两工具在单一事实源（MCP tools/list 同源自动可见）
test "agent_api：generate/batch_apply 注册" {
  assert_true(list_tools().length() == 55)
  let json = list_tools_json()
  assert_true(json.contains("\"name\":\"generate\""))
  assert_true(json.contains("\"name\":\"batch_apply\""))
}

///|
/// 信封可见性 + 意图词边界：信封必须暴露画板实际宽高与覆盖标记——
/// 多数模板保留内建默认尺寸（意图宽度不被消费），同名画板被静默覆盖
/// （旧 Document 连同 tier-2 精修丢失），Agent 只有从信封才能发现。
test "generate：信封宽高/覆盖标记与 pc/web 整词、平分-反超清理" {
  // 平板意图：dashboard 模板不消费 768 宽，实际产出 390×844——信封可见
  let p = Project::new()
  let tablet = match p.generate(intent_text="平板 仪表盘") {
    Ok(j) => j
    Err(_) => ""
  }
  assert_true(tablet.contains("\"template\":\"dashboard\""))
  assert_true(tablet.contains("\"width\":390"))
  assert_true(tablet.contains("\"height\":844"))
  assert_true(tablet.contains("\"replaced\":false"))
  // 重跑同意图：同名画板被覆盖 → replaced:true（覆盖必须可见）
  let rerun = match p.generate(intent_text="平板 仪表盘") {
    Ok(j) => j
    Err(_) => ""
  }
  assert_true(rerun.contains("\"replaced\":true"))
  // pc 整词匹配："npc" 不再触发设备映射（否则被强改为 pc_app+1280）
  let npc = parse_generate_intent("npc 仪表盘")
  assert_true(npc.template_id == "dashboard")
  assert_true(npc.width == 0.0)
  // web 整词匹配："webview" 不再判成 web 设备暗示
  let webview = parse_generate_intent("webview 仪表盘")
  assert_true(webview.template_id == "dashboard")
  // 整词不误伤："pc 仪表盘" / "web 落地页" 照常命中
  assert_true(parse_generate_intent("pc 仪表盘").template_id == "pc_app")
  assert_true(parse_generate_intent("web 落地页").template_id == "web_landing")
  // 平分-反超：alternatives 只保留与终局 best 等分者（onboarding 实得
  // 1 分 < settings 的 2 分，不得残留旧 best 的等分列表）
  let tie = parse_generate_intent("注册 引导 设置 偏好 概览 统计")
  assert_true(tie.template_id == "settings")
  assert_true(tie.alternatives.length() == 1)
  assert_true(tie.alternatives[0] == "dashboard")
}
///|
/// 组合意图：一句话出多画板 + 相邻自动导航流（出口启发：A 板上找目标
/// 语义节点，找不到合成前往按钮）；纯主题段不生成板只换主题。
test "generate multi：组合意图与自动导航流" {
  let p = Project::new()
  let json = match p.generate(intent_text="登录+注册") {
    Ok(j) => j
    Err(_) => ""
  }
  assert_true(json.contains("\"mode\":\"multi\""))
  assert_true(json.contains("\"count\":2"))
  assert_true(json.contains("\"template\":\"login\""))
  assert_true(json.contains("\"template\":\"signup\""))
  // 双画板真实入库
  assert_true(p.artboards.contains("login"))
  assert_true(p.artboards.contains("signup"))
  // 英文出口词命中 login 既有 signup_btn（Create Account）：就地连线，
  // 不再在既有按钮之下凭空合成第二个注册 CTA
  match p.artboards.get("login") {
    Some(meta) => assert_false(meta.doc.has("goto_signup"))
    None => assert_true(false)
  }
  // 相邻流存在且 trigger 指向 login 上的真实出口节点（validate_flows 契约）
  let mut flow_ok = false
  for e in p.flows.iter() {
    if e.from == "login" && e.to == "signup" && e.trigger == "tap:signup_btn" {
      match p.artboards.get("login") {
        Some(meta) => flow_ok = meta.doc.has("signup_btn")
        None => ()
      }
    }
  }
  assert_true(flow_ok, msg="login→signup 流必须就地连线既有 signup_btn 出口")
  // 流不重复：出口流 + 模板内建流（signup→login tap:have_account）共 2 条
  assert_true(p.flows.length() == 2)
  // 首跑逐板 replaced:false（覆盖探测与单通道信封同构）
  assert_true(json.contains("\"replaced\":false"))
  assert_false(json.contains("\"replaced\":true"))
  // 双板零违规
  for ab_id in ["login", "signup"] {
    match p.artboards.get(ab_id) {
      Some(meta) => assert_true(validate(meta.doc).length() == 0)
      None => ()
    }
  }
  // 幂等重跑：手工 tier-2 精修随 upsert 覆盖丢失——信封逐板 replaced:true
  // 必须可见；模板条件流 + 出口流不再线性膨胀（按 (from,to,trigger) 去重）
  let _ = p.place_component(
    artboard="login",
    component_id="badge",
    instance_id="t2_probe",
    x=300.0,
    y=10.0,
  )
  let flows_before = p.flows.length()
  let rerun = match p.generate(intent_text="登录+注册") {
    Ok(j) => j
    Err(_) => ""
  }
  assert_true(rerun.contains("\"mode\":\"multi\""))
  assert_true(rerun.contains("\"replaced\":true"))
  assert_false(rerun.contains("\"replaced\":false"))
  match p.artboards.get("login") {
    Some(meta) => assert_false(meta.doc.has("t2_probe"))
    None => assert_true(false)
  }
  assert_true(p.flows.length() == flows_before, msg="重跑 flows 数不得膨胀")
  // 再跑一次仍不膨胀（去重覆盖模板内建流与出口流两个来源）
  let _ = p.generate(intent_text="登录+注册")
  assert_true(p.flows.length() == flows_before)
}

///|
/// 主题段在前的退化组合（"dark+登录"）：退化单通道必须拿页面段原文
/// 重拼——写死 segments[0] 会拿 "dark" 重拼成 "dark dark"，页面段被
/// 丢弃、静默落到空状态兜底板（SKILL/docs 承诺主题段全局生效、不限顺序）。
test "generate multi：主题段在前的退化取页面段原文" {
  let p = Project::new()
  let j1 = match p.generate(intent_text="dark+登录") {
    Ok(j) => j
    Err(_) => ""
  }
  assert_true(j1.contains("\"artboard\":\"login\""))
  assert_true(j1.contains("\"template\":\"login\""))
  assert_true(j1.contains("\"theme_applied\":\"dark\""))
  assert_false(j1.contains("未识别"))
  assert_true(p.artboards.contains("login"))
  // 带空格的中文主题段同样退化到页面段
  let p2 = Project::new()
  let j2 = match p2.generate(intent_text="暗色 + 注册页") {
    Ok(j) => j
    Err(_) => ""
  }
  assert_true(j2.contains("\"artboard\":\"signup\""))
  assert_true(j2.contains("\"template\":\"signup\""))
  assert_true(j2.contains("\"theme_applied\":\"dark\""))
  assert_false(j2.contains("未识别"))
  assert_true(p2.artboards.contains("signup"))
}

///|
/// 归一撞名查重：multi 通道按 sanitize_id 归一记录/查重——name="Signup"
/// （首板 login 模板）与第二板模板名 "signup" 归一同 id，第二板加序号成
/// signup_2，不再经 create_artboard 的 Map upsert 静默覆盖第一板。
test "generate multi：归一撞名加序号不静默覆盖" {
  let p = Project::new()
  let json = match p.generate(intent_text="登录+注册", name="Signup") {
    Ok(j) => j
    Err(_) => ""
  }
  assert_true(json.contains("\"count\":2"))
  // 两板 id 不同：signup（login 模板）+ signup_2（signup 模板）
  assert_true(json.contains("\"id\":\"signup\""))
  assert_true(json.contains("\"id\":\"signup_2\""))
  assert_true(p.artboards.contains("signup"))
  assert_true(p.artboards.contains("signup_2"))
  assert_true(p.artboards.length() == 2)
  // 两板内容各自完好（旧实现第二板 upsert 覆盖第一板，login 的 email_input 丢失）
  match p.artboards.get("signup") {
    Some(meta) => assert_true(meta.doc.has("email_input"))
    None => assert_true(false)
  }
  match p.artboards.get("signup_2") {
    Some(meta) => assert_true(meta.doc.has("field_0"))
    None => assert_true(false)
  }
  // 出口流指向第二板（而非覆盖后的同 id 自环）
  let mut cross = false
  for e in p.flows.iter() {
    if e.from == "signup" && e.to == "signup_2" {
      cross = true
    }
  }
  assert_true(cross, msg="signup→signup_2 相邻流必须存在")
}

///|
/// 合成出口画布钳制 + autofix 摘要透传：settings 高内容模板底缘放不下
/// 合成按钮时找带区空位、仍无空位则放弃合成——不再产生 auto_fix 清偿
/// 不动的越界债（contained_in_parent 对负剩余空间保持原尺寸）；逐板
/// autofix ok/fixes 摘要进入信封，不再 `let _ =` 丢弃后硬编码 ok:true。
test "generate multi：合成出口画布钳制与 autofix 摘要" {
  let p = Project::new()
  let json = match p.generate(intent_text="设置+仪表盘") {
    Ok(j) => j
    Err(_) => ""
  }
  assert_true(json.contains("\"mode\":\"multi\""))
  assert_true(json.contains("\"count\":2"))
  // 逐板 autofix 摘要可见且清偿干净
  assert_true(json.contains("\"autofix\":{\"ok\":true"))
  assert_false(json.contains("\"autofix\":{\"ok\":false"))
  // settings 底缘无 44px 带区空位：放弃合成，相邻流诚实跳过而非落出画布
  assert_true(json.contains("\"flows\":[]"))
  for ab_id in ["settings", "dashboard"] {
    match p.artboards.get(ab_id) {
      Some(meta) => {
        assert_false(meta.doc.has("goto_dashboard"))
        assert_true(validate(meta.doc).length() == 0)
        // 全部节点严格包含在画板内（越界按钮曾是清偿不动的永久债）
        let layout = solve(meta.doc)
        for id in meta.doc.nodes.keys() {
          if id != "root" {
            match layout.rect_of(id) {
              Some(r) => assert_true(r.y + r.height <= meta.height + 0.5)
              None => ()
            }
          }
        }
      }
      None => assert_true(false)
    }
  }
}

///|
/// 主题修饰段（"dark"）不生成板；纯修饰组合报 no_page_intent；超上限拒绝。
test "generate multi：主题段/空组合/上限" {
  let p = Project::new()
  // "登录+dark"：dark 只是主题修饰 → 单板 + dark 主题生效
  let j1 = match p.generate(intent_text="登录+dark") {
    Ok(j) => j
    Err(_) => ""
  }
  assert_true(j1.contains("\"theme_applied\":\"dark\""))
  assert_false(j1.contains("\"mode\":\"multi\""))
  // 纯修饰组合 → no_page_intent
  match p.generate(intent_text="dark+light") {
    Err(e) => assert_true(e.contains("no_page_intent"))
    Ok(_) => assert_true(false)
  }
  // 5 段超上限
  match p.generate(intent_text="登录+注册+设置+仪表盘+个人主页") {
    Err(e) => assert_true(e.contains("too_many"))
    Ok(_) => assert_true(false)
  }
}

///|
/// 交流模式：generate 信封带人话 summary（单通道与组合通道）。
test "generate：信封 summary 摘要" {
  let p = Project::new()
  let j1 = match p.generate(intent_text="登录页") {
    Ok(j) => j
    Err(_) => ""
  }
  assert_true(j1.contains("\"summary\":\"生成登录页（93分，自愈"))
  let j2 = match p.generate(intent_text="登录+注册") {
    Ok(j) => j
    Err(_) => ""
  }
  assert_true(j2.contains("\"summary\":\"组合生成 2 板：login → signup\""))
}
