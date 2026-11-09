///|
/// 设计文档 → 规范提取（0.2 规范流程）：中文文档的配色/字号/圆角/间距/
/// 动效/触控按关键词确定性归类；缺关键项进 gaps，引擎不猜。
test "design_doc：完整设计文档提取出可用的规范" {
  let doc = "# 露营 App 设计文档\n\n## 配色\n- 主色 #0F766E，品牌绿\n- 辅助色 #F97316\n- 背景 #F2FBF8\n- 卡片 #FFFFFF\n- 正文 #0B2A26\n- 次要文字 #3F5D57\n- 警告 #B45309，错误 #C2410C，成功 #15803D\n\n## 字号\n- 标题 28\n- 正文 15\n- 说明 12\n\n## 圆角\n- 圆角 6 / 10 / 14\n\n## 间距\n- 间距取 4 的倍数（8pt 栅格）\n\n## 动效\n- 时长 120 / 220 / 320 ms\n\n## 交互\n- 触控目标 44\n"
  let ex = design_doc_extract(doc)
  assert_eq(ex.gaps.length(), 0)
  assert_true(ex.spec_json.contains("\"source\":\"design_doc\""))
  assert_true(ex.spec_json.contains("\"primary\":\"#0f766e\""))
  assert_true(ex.spec_json.contains("\"background\":\"#f2fbf8\""))
  assert_true(ex.spec_json.contains("\"text_primary\":\"#0b2a26\""))
  assert_true(ex.spec_json.contains("\"body\":15"))
  assert_true(ex.spec_json.contains("\"h1\":28"))
  assert_true(ex.spec_json.contains("\"caption\":12"))
  assert_true(ex.spec_json.contains("\"sm\":6"))
  assert_true(ex.spec_json.contains("\"lg\":14"))
  assert_true(ex.spec_json.contains("\"fast\":120"))
  assert_true(ex.spec_json.contains("\"slow\":320"))
  assert_true(ex.spec_json.contains("触控目标 44"))
  assert_true(ex.extracted.length() >= 8)
}

///|
test "design_doc：缺关键项只报 gaps，不落引擎默认" {
  let doc = "配色：主色 #123456\n背景 #FFFFFF\n"
  let ex = design_doc_extract(doc)
  assert_true(ex.gaps.length() >= 3)
  let g = ex.gaps.join("；")
  assert_true(g.contains("text"))
  assert_true(g.contains("typography.body"))
  assert_true(g.contains("radius"))
}

///|
/// 强制入口：文档不完整时 generate_from_doc 拒绝生成；完整时信封带来源。
test "design_doc：generate_from_doc 强制流程与来源可见" {
  let incomplete = "主色 #123456\n"
  let p = Project::new()
  match p.generate_from_doc(intent_text="登录页", doc=incomplete) {
    Err(e) => assert_true(e.contains("design_doc_spec_gaps"))
    Ok(_) => assert_true(false)
  }
  let doc = "## 配色\n主色 #0F766E\n背景 #F2FBF8\n卡片 #FFFFFF\n正文 #0B2A26\n## 字号\n正文 15\n## 圆角\n圆角 8 / 12 / 16\n"
  match p.generate_from_doc(intent_text="登录页", doc=doc) {
    Ok(j) => {
      assert_true(j.contains("\"spec_source\":\"design_doc\""))
      assert_true(j.contains("\"spec_extracted\":"))
    }
    Err(e) => {
      println("ERR=" + e)
      assert_true(false)
    }
  }
  // 文档主色真实落到输出（spec 第一权威）
  assert_eq(p.tokens.resolve_color("primary"), "#0f766e")
}

///|
/// 遵从校验：规范外的字号/圆角/字面色/动效令牌全部报出；合规文档零违规。
test "design_doc：design_spec_compliance 四检（颜色/字号/圆角/动效）" {
  let p = Project::new()
  let doc = "## 配色\n主色 #0F766E\n背景 #F2FBF8\n卡片 #FFFFFF\n正文 #0B2A26\n## 字号\n标题 24\n正文 14\n说明 12\n## 圆角\n圆角 8 / 12 / 16\n## 动效\n时长 120 / 240 / 360 ms\n"
  match p.generate_from_doc(intent_text="登录页", doc=doc) {
    Ok(_) => ()
    Err(_) => assert_true(false)
  }
  // 合规：生成物应零违规（字号阶/圆角档/调色板/动效令牌全来自文档）
  let clean = p.design_spec_compliance(artboard="login")
  assert_true(clean.contains("\"ok\":true"))
  // 制造三类违规：字号 15、圆角 10、字面色 #123456
  let _ = p.edit_node(
    artboard="login",
    node_id="welcome_title",
    kvs=[("font_size", "15")],
  )
  let _ = p.edit_node(
    artboard="login",
    node_id="email_input",
    kvs=[("radius", "10")],
  )
  let _ = p.edit_node(
    artboard="login",
    node_id="subtitle",
    kvs=[("text_color", "#123456")],
  )
  let bad = p.design_spec_compliance(artboard="login")
  assert_true(bad.contains("\"ok\":false"))
  assert_true(bad.contains("type:"))
  assert_true(bad.contains("radius:"))
  assert_true(bad.contains("color:"))
}
