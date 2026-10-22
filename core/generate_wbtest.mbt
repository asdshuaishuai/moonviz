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
  assert_true(list_tools().length() == 54)
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