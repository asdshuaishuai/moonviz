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
  match p.generate_from_doc(intent_text="登录页", doc~) {
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
  match p.generate_from_doc(intent_text="登录页", doc~) {
    Ok(_) => ()
    Err(_) => assert_true(false)
  }
  // 合规：生成物应零违规（字号阶/圆角档/调色板/动效令牌全来自文档）
  let clean = p.design_spec_compliance(artboard="login")
  assert_true(clean.contains("\"ok\":true"))
  // 制造三类违规：字号 15、圆角 10、字面色 #123456
  let _ = p.edit_node(artboard="login", node_id="welcome_title", kvs=[
    ("font_size", "15"),
  ])
  let _ = p.edit_node(artboard="login", node_id="email_input", kvs=[
    ("radius", "10"),
  ])
  let _ = p.edit_node(artboard="login", node_id="subtitle", kvs=[
    ("text_color", "#123456"),
  ])
  let bad = p.design_spec_compliance(artboard="login")
  assert_true(bad.contains("\"ok\":false"))
  assert_true(bad.contains("type:"))
  assert_true(bad.contains("radius:"))
  assert_true(bad.contains("color:"))
}

///|
/// 提取器修复面：复合角色词优先于宽泛词（次要文字/次级背景/secondary
/// text/surfaceVariant 不再被截走）、同行多 hex 按命中序对位、markdown
/// 加粗条目整行可提取、散装字号键值（正文 15）、文档显式 h2/h3/h4 落档、
/// 两档动效不再静默丢弃、hex 色值数字不污染数值扫描。
test "design_doc：复合角色/多色对位/加粗条目/散装字号/全档字号/两档动效" {
  let ex1 = design_doc_extract("- 次要文字 #8E8E93\n")
  assert_true(ex1.spec_json.contains("\"text_secondary\":\"#8e8e93\""))
  assert_false(ex1.spec_json.contains("\"text_primary\":\"#8e8e93\""))
  let ex2 = design_doc_extract("- 次级背景 #EEEEEE\n")
  assert_true(ex2.spec_json.contains("\"surface_variant\":\"#eeeeee\""))
  assert_false(ex2.spec_json.contains("\"background\":\"#eeeeee\""))
  let ex3 = design_doc_extract("- secondary text #777777\n")
  assert_true(ex3.spec_json.contains("\"text_secondary\":\"#777777\""))
  assert_false(ex3.spec_json.contains("\"secondary\":\"#777777\""))
  let ex4 = design_doc_extract("- surfaceVariant #EEEEEE\n")
  assert_true(ex4.spec_json.contains("\"surface_variant\":\"#eeeeee\""))
  assert_false(ex4.spec_json.contains("\"surface\":\"#eeeeee\""))
  // 同行多 hex 多角色按命中序对位
  let ex5 = design_doc_extract(
    "- 警告 #B45309，错误 #C2410C，成功 #15803D\n",
  )
  assert_true(ex5.spec_json.contains("\"warning\":\"#b45309\""))
  assert_true(ex5.spec_json.contains("\"error\":\"#c2410c\""))
  assert_true(ex5.spec_json.contains("\"success\":\"#15803d\""))
  // 跨序写法按行内关键词首现位置对位（表序对位会把两值互换）：
  // 行「成功…警告…」中 success=第一个 hex、warning=第二个 hex
  let ex5b = design_doc_extract("- 成功 #15803D，警告 #B45309\n")
  assert_true(ex5b.spec_json.contains("\"success\":\"#15803d\""))
  assert_true(ex5b.spec_json.contains("\"warning\":\"#b45309\""))
  assert_false(ex5b.spec_json.contains("\"warning\":\"#15803d\""))
  // markdown 加粗条目不再整行跳过
  let ex6 = design_doc_extract("**主色**: #0F766E\n")
  assert_true(ex6.spec_json.contains("\"primary\":\"#0f766e\""))
  // 散装键值（无标题行）+ hex 色值里的数字不冒充档位
  let ex7 = design_doc_extract(
    "主色 #123456\n背景 #ABCDEF\n正文色 #0B2A26\n正文 15\n圆角 8 12 16\n",
  )
  assert_true(ex7.spec_json.contains("\"body\":15"))
  assert_true(ex7.spec_json.contains("\"sm\":8"))
  // 文档显式 h2/h3/h4 直接落档（此前进 scale 后被丢弃）
  let ex8 = design_doc_extract(
    "主色 #123456\n背景 #ABCDEF\n正文色 #111111\n正文 15\n标题 28\n二级标题 22\n三级标题 18\n四级标题 15\n圆角 8 12 16\n",
  )
  assert_true(ex8.spec_json.contains("\"h1\":28"))
  assert_true(ex8.spec_json.contains("\"h2\":22"))
  assert_true(ex8.spec_json.contains("\"h3\":18"))
  assert_true(ex8.spec_json.contains("\"h4\":15"))
  // 恰好两档动效：短值 fast、长值 base/slow，意图随 extracted 上报
  let ex9 = design_doc_extract(
    "主色 #123456\n背景 #ABCDEF\n正文色 #111111\n正文 15\n圆角 8 12 16\n时长 120 / 220\n",
  )
  assert_true(ex9.spec_json.contains("\"fast\":120"))
  assert_true(ex9.spec_json.contains("\"base\":220"))
  assert_true(ex9.extracted.length() >= 5)
}

///|
/// 圆角全档吸附：模板默认外的 6/14/18/20/24 与胶囊写法 100 全部落到
/// spec 三档/999 豁免档——生成即合规，自家 comply 过得了；spec 缺档时
/// 保留原值（文档没约束的维度不强改）。
test "design_doc：radius 全档吸附与 comply 缺档兜底" {
  let p = Project::new()
  let _ = p.create_artboard(name="r")
  let mut py = 10.0
  for pair in [("a", "6"), ("b", "14"), ("c", "18"), ("d", "100")].iter() {
    let (nid, rv) = pair
    let _ = p.place_component(
      artboard="r",
      component_id="button",
      instance_id=nid,
      x=10.0,
      y=py,
    )
    let _ = p.edit_node(artboard="r", node_id=nid, kvs=[("radius", rv)])
    py = py + 60.0
  }
  let spec = "{\"v\":1,\"palette\":{\"primary\":\"#123456\"},\"radius\":{\"sm\":8,\"md\":12,\"lg\":16}}"
  match p.apply_design_spec(artboard="r", spec~) {
    Ok(_) => ()
    Err(_) => assert_true(false)
  }
  match p.artboards.get("r") {
    None => assert_true(false)
    Some(ab) => {
      let want : Array[(String, Double)] = [
        ("a", 8.0),
        ("b", 12.0),
        ("c", 16.0),
        ("d", 999.0),
      ]
      for pair in want.iter() {
        let (nid, rv) = pair
        match ab.doc.get(nid) {
          Some(n) => assert_eq(n.style.corner_radius, rv, msg="radius \{nid}")
          None => assert_true(false)
        }
      }
    }
  }
  // comply：radius 全档合规；字号缺档（spec 只给 body）时引擎默认档
  // h3/h4 的节点不再被判违规
  let cmp = p.design_spec_compliance(artboard="r")
  assert_true(cmp.contains("\"ok\":true"))
}

///|
/// spec.style 暗色美学预设直通：apple_dark/harmony_dark 是已注册名，
/// 点名暗色预设不得被静默吃掉（返回 "" 不换主题）。
test "design_doc：style 暗色预设直通" {
  assert_eq(ds_style_theme("{\"style\":\"apple_dark\"}"), "apple_dark")
  assert_eq(ds_style_theme("{\"style\":\"harmony_dark\"}"), "harmony_dark")
  assert_eq(ds_style_theme("{\"style\":\"apple\"}"), "apple")
  assert_eq(ds_style_theme("{\"style\":\"vivid\"}"), "vivid")
  assert_eq(ds_style_theme("{\"style\":\"nonsense\"}"), "")
  // 端到端：generate spec 点名 apple_dark 真实切到暗色预设
  let p = Project::new()
  let spec = "{\"v\":1,\"style\":\"apple_dark\",\"palette\":{\"primary\":\"#409CFF\",\"background\":\"#1C1C1E\"},\"typography\":{\"body\":14},\"radius\":{\"sm\":8,\"md\":12,\"lg\":16}}"
  match p.generate(spec~, intent_text="登录页") {
    Ok(_) => assert_eq(p.active_theme, "apple_dark")
    Err(_) => assert_true(false)
  }
}

///|
/// 夹杂回归（7996019 行内位置对位的副作用）：无关角色词「卡片」夹在
/// 两色之间，会把第二个 hex 抢给 surface、background 丢失 → 完整文档
/// generate-doc 被 background gap 拒绝。对位规则改为「每个 hex 与其
/// 前方最近、且在上一 hex 之后出现的关键词配对」后：夹杂词不再影响
/// 归属，跨序/正序/单角色行为保持。
test "design_doc：夹杂角色词不抢对位（generate-doc 不再被拒）" {
  let ex = design_doc_extract(
    "主色 #123456（卡片强调），背景 #FFFFFF\n",
  )
  assert_true(ex.spec_json.contains("\"primary\":\"#123456\""))
  assert_true(ex.spec_json.contains("\"background\":\"#ffffff\""))
  // 单行 variant：无关词不改变归属
  let ex2 = design_doc_extract("卡片背景 #FFFFFF\n")
  assert_true(ex2.spec_json.contains("\"background\":\"#ffffff\""))
  // 端到端：含夹杂词的完整文档不再被 background gap 拒绝
  let p = Project::new()
  let doc = "主色 #123456（卡片强调），背景 #FFFFFF\n正文色 #111111\n正文 15\n圆角 8 12 16\n"
  match p.generate_from_doc(intent_text="登录页", doc~) {
    Ok(j) => {
      assert_true(j.contains("\"spec_source\":\"design_doc\""))
      assert_eq(p.tokens.resolve_color("background"), "#ffffff")
    }
    Err(e) => {
      println("ERR=" + e)
      assert_true(false, msg="夹杂词不应触发 design_doc_spec_gaps")
    }
  }
  // 跨序/正序保持（7996019 语义不回退）
  let ex3 = design_doc_extract("- 成功 #15803D，警告 #B45309\n")
  assert_true(ex3.spec_json.contains("\"success\":\"#15803d\""))
  assert_true(ex3.spec_json.contains("\"warning\":\"#b45309\""))
  let ex4 = design_doc_extract(
    "- 警告 #B45309，错误 #C2410C，成功 #15803D\n",
  )
  assert_true(ex4.spec_json.contains("\"warning\":\"#b45309\""))
  assert_true(ex4.spec_json.contains("\"error\":\"#c2410c\""))
  assert_true(ex4.spec_json.contains("\"success\":\"#15803d\""))
  // 宽泛词被具体词覆盖淘汰：次要文字行不落 text_primary
  let ex5 = design_doc_extract("- 次要文字 #8E8E93\n")
  assert_true(ex5.spec_json.contains("\"text_secondary\":\"#8e8e93\""))
  assert_false(ex5.spec_json.contains("\"text_primary\":\"#8e8e93\""))
}

///|
/// 三类回归（797202c 对位算法的副作用，对照父版本行为修复）：
/// ① 色值在前的行与 markdown 表（| #X | 背景 |）→ 关键词在 hex 之后，
///    后向配对区间生效，不再落 primary 兜底；
/// ② 「次级背景 #A，背景 #B」/「次要文字 #A，正文 #B」：宽泛词首次出现
///    被覆盖淘汰的是**那一次出现**而非整个角色，其后单独出现的宽泛词
///    保留 → 第二色各归其位；
/// ③ emoji 紧贴（位置单位统一 code point）→ 关键词不再被错位排除。
/// 既有形态（跨序/正序/夹杂/具体词单行/**加粗**）保持不回退。
test "design_doc：色值在前/覆盖淘汰按次/emoji 紧贴三类回归" {
  // ① 色值在前：后向配对
  let ex1 = design_doc_extract("- #FFFFFF 背景\n")
  assert_true(ex1.spec_json.contains("\"background\":\"#ffffff\""))
  let ex2 = design_doc_extract("| #FFFFFF | 背景 |\n")
  assert_true(ex2.spec_json.contains("\"background\":\"#ffffff\""))
  // ② 覆盖淘汰按次：宽泛词的后续出现保留
  let ex3 = design_doc_extract("- 次级背景 #EEEEEE，背景 #FFFFFF\n")
  assert_true(ex3.spec_json.contains("\"surface_variant\":\"#eeeeee\""))
  assert_true(ex3.spec_json.contains("\"background\":\"#ffffff\""))
  let ex4 = design_doc_extract("- 次要文字 #8E8E93，正文 #111111\n")
  assert_true(ex4.spec_json.contains("\"text_secondary\":\"#8e8e93\""))
  assert_true(ex4.spec_json.contains("\"text_primary\":\"#111111\""))
  // ③ emoji 紧贴：位置单位统一后关键词可配对
  let ex5 = design_doc_extract("🎨🎨背景#FFFFFF\n")
  assert_true(ex5.spec_json.contains("\"background\":\"#ffffff\""))
  // 既有形态保持
  let ex6 = design_doc_extract("- 成功 #15803D，警告 #B45309\n")
  assert_true(ex6.spec_json.contains("\"success\":\"#15803d\""))
  assert_true(ex6.spec_json.contains("\"warning\":\"#b45309\""))
  let ex7 = design_doc_extract(
    "- 警告 #B45309，错误 #C2410C，成功 #15803D\n",
  )
  assert_true(ex7.spec_json.contains("\"error\":\"#c2410c\""))
  let ex8 = design_doc_extract(
    "主色 #123456（卡片强调），背景 #FFFFFF\n",
  )
  assert_true(ex8.spec_json.contains("\"background\":\"#ffffff\""))
  let ex9 = design_doc_extract("**主色**: #0F766E\n")
  assert_true(ex9.spec_json.contains("\"primary\":\"#0f766e\""))
  let ex10 = design_doc_extract("- 次要文字 #8E8E93\n")
  assert_true(ex10.spec_json.contains("\"text_secondary\":\"#8e8e93\""))
  assert_false(ex10.spec_json.contains("\"text_primary\":\"#8e8e93\""))
  // 端到端：色值在前的 markdown 表文档不再被 generate-doc 拒绝
  let p = Project::new()
  let doc = "| 角色 | 色值 |\n| #123456 | 主色 |\n| #FFFFFF | 背景 |\n正文色 #111111\n正文 15\n圆角 8 12 16\n"
  match p.generate_from_doc(intent_text="登录页", doc~) {
    Ok(j) => {
      assert_true(j.contains("\"spec_source\":\"design_doc\""))
      assert_eq(p.tokens.resolve_color("primary"), "#123456")
      assert_eq(p.tokens.resolve_color("background"), "#ffffff")
    }
    Err(e) => {
      println("ERR=" + e)
      assert_true(
        false,
        msg="色值在前的表文档不应被 design_doc_spec_gaps 拒绝",
      )
    }
  }
}
