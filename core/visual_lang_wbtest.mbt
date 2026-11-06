// 视觉语言升级（Apple HIG / HarmonyOS 第一要素）测试锚点：
// 美学预设色板可读性、别名归一、意图/spec 双通道、组件 elevation、
// critique 第 10 维 visual、导出 chrome 主题化与 Hover Lift。

///|
/// 美学预设逐档 WCAG 校准：按钮主面白字/深字 ≥4.5、正文与辅助文字在
/// 画布/卡面/输入底三层上 ≥4.5——这是从官方色板「翻译」而非照抄的依据。
test "visual：美学预设色板逐档达可读性标准" {
  let presets = [
    Theme::apple(),
    Theme::apple_dark(),
    Theme::harmony(),
    Theme::harmony_dark(),
  ]
  for th in presets.iter() {
    let t = th.tokens
    let cr = fn(fg : String, bg : String) -> Double {
      norm_contrast_ratio(
        norm_luminance(t.resolve_color(fg)),
        norm_luminance(t.resolve_color(bg)),
      )
    }
    // 主按钮文字（on_primary 叠 primary）
    assert_true(cr("on_primary", "primary") >= 4.5)
    // 三级文字 × 三层底
    for fg in ["text_primary", "text_secondary", "text_hint"].iter() {
      for bg in ["surface", "background"].iter() {
        assert_true(cr(fg, bg) >= 4.5)
      }
    }
    assert_true(cr("text_primary", "surface_variant") >= 4.5)
    assert_true(cr("text_secondary", "surface_variant") >= 4.5)
    // 次级按钮（secondary_container 底 + text_primary 字）
    assert_true(cr("text_primary", "secondary_container") >= 4.5)
  }
}

///|
/// 暗色预设不踩自家纯黑禁令：iOS/鸿蒙原生的 OLED 纯黑底改用 elevated 层。
test "visual：暗色美学预设不落纯黑/近黑灰底" {
  for th in [Theme::apple_dark(), Theme::harmony_dark()].iter() {
    assert_true(th.is_dark)
    for role in ["background", "surface", "surface_variant"].iter() {
      assert_false(norm_is_pure_dark(th.tokens.resolve_color(role)))
    }
  }
}

///|
test "visual：美学别名归一（整词匹配 + 注册名直通 + 暗色合流）" {
  assert_eq(theme_alias("iOS"), "apple")
  assert_eq(theme_alias("Apple"), "apple")
  assert_eq(theme_alias("苹果风格"), "apple")
  assert_eq(theme_alias("鸿蒙"), "harmony")
  assert_eq(theme_alias("HarmonyOS"), "harmony")
  assert_eq(theme_alias("华为"), "harmony")
  // 注册名直通：apple_dark 不能被 contains("apple") 折回浅色
  assert_eq(theme_alias("apple_dark"), "apple_dark")
  assert_eq(theme_alias("harmony_dark"), "harmony_dark")
  // 同名带暗色词 → 暗色预设
  assert_eq(theme_alias("苹果暗色"), "apple_dark")
  assert_eq(theme_alias("harmony dark"), "harmony_dark")
  // 整词匹配：ios 不误中 scenarios / studios
  assert_eq(theme_alias("scenarios"), "scenarios")
  assert_eq(theme_alias("studios"), "studios")
  // 既有主题与未知名原样
  assert_eq(theme_alias("nord"), "nord")
  assert_eq(theme_alias("unknown_x"), "unknown_x")
  assert_eq(resolve_aesthetic_theme("apple", true), "apple_dark")
  assert_eq(resolve_aesthetic_theme("鸿蒙", true), "harmony_dark")
  assert_eq(resolve_aesthetic_theme("harmony", false), "harmony")
}

///|
test "visual：apply_theme 接受美学别名" {
  let p = Project::new()
  match p.apply_theme("iOS") {
    Ok(j) => assert_true(j.contains("\"theme\":\"apple\""))
    Err(_) => assert_true(false)
  }
  assert_eq(p.tokens.resolve_color("primary"), "#0068D6")
  match p.apply_theme("鸿蒙") {
    Ok(j) => assert_true(j.contains("\"theme\":\"harmony\""))
    Err(_) => assert_true(false)
  }
  assert_eq(p.tokens.resolve_color("primary"), "#0A59F7")
}

///|
/// 意图通道：一句话里的美学词直达预设（与暗色词同句落暗色预设）。
test "visual：意图美学词解析（apple / 暗色鸿蒙）" {
  let a = parse_generate_intent("apple 风格登录页")
  assert_eq(a.theme, "apple")
  assert_eq(a.template_id, "login")
  let h = parse_generate_intent("暗色 鸿蒙 设置页")
  assert_eq(h.theme, "harmony_dark")
  assert_eq(h.template_id, "settings")
  let i = parse_generate_intent("ios dashboard")
  assert_eq(i.theme, "apple")
  // ios 整词：scenarios 不触发美学主题
  let s = parse_generate_intent("scenarios 列表")
  assert_eq(s.theme, "")
}

///|
test "visual：generate 意图美学词生效到令牌" {
  let p = Project::new()
  match p.generate(spec=VL_SPEC, intent_text="鸿蒙 登录页") {
    Ok(j) => assert_true(j.contains("\"theme_applied\":\"harmony\""))
    Err(_) => assert_true(false)
  }
  assert_eq(p.active_theme, "harmony")
  assert_eq(p.tokens.resolve_color("background"), "#F1F3F5")
}

///|
/// spec 通道：style 键先落美学预设，palette 随后覆盖同名角色（微调优先）。
test "visual：spec style 键应用美学预设且 palette 可覆盖" {
  let p = Project::new()
  let spec = "{\"v\":1,\"style\":\"apple\",\"palette\":{\"success\":\"#1E7B34\"}}"
  match p.generate(spec~, intent_text="登录页") {
    Ok(_) => ()
    Err(_) => assert_true(false)
  }
  assert_eq(p.active_theme, "apple")
  assert_eq(p.tokens.resolve_color("primary"), "#0068D6")
  assert_eq(p.tokens.resolve_color("background"), "#F2F2F7")
  // palette 覆盖 style 的同名角色
  assert_eq(p.tokens.resolve_color("success"), "#1E7B34")
}

///|
/// 暗色意图 + spec style 合流：暗色项目换装美学体系时保留暗色。
test "visual：暗色意图与 spec style 合流为暗色美学预设" {
  let p = Project::new()
  let spec = "{\"v\":1,\"style\":\"harmony\"}"
  match p.generate(spec~, intent_text="暗色 登录页") {
    Ok(_) => ()
    Err(_) => assert_true(false)
  }
  assert_eq(p.active_theme, "harmony_dark")
  assert_eq(p.tokens.resolve_color("primary"), "#5291FF")
  // 未知 style 不改道（不报错、不换主题）
  assert_eq(ds_style_theme("{\"style\":\"brutalist\"}"), "")
  assert_eq(ds_style_theme("{\"style\":\"ios\"}"), "apple")
}

///|
/// 组件默认 elevation：内容层 e1、临时浮层 e2、模态层 e3，其余贴面。
test "visual：组件默认 elevation 三档" {
  let defs = builtin_components()
  let shadow_of = fn(cid : String) -> String {
    match defs.get(cid) {
      Some(d) => instantiate_component(d, "x").style.shadow
      None => "missing"
    }
  }
  assert_eq(shadow_of("card"), "e1")
  assert_eq(shadow_of("stat"), "e1")
  assert_eq(shadow_of("fab"), "e2")
  assert_eq(shadow_of("popover"), "e2")
  assert_eq(shadow_of("toast"), "e2")
  assert_eq(shadow_of("dialog"), "e3")
  assert_eq(shadow_of("command_palette"), "e3")
  assert_eq(shadow_of("button"), "none")
  assert_eq(shadow_of("heading"), "none")
  assert_eq(shadow_of("list_item"), "none")
}

///|
fn vl_node(
  id : String,
  kind : NodeKind,
  component : String,
  fill : String,
  radius : Double,
  h : Double,
) -> Node {
  let n = Node::make(id, kind)
  {
    ..n,
    width: Fixed(100.0),
    height: Fixed(h),
    x: AlignStart(0.0),
    y: AlignStart(0.0),
    component,
    style: { ..n.style, fill, corner_radius: radius },
  }
}

///|
test "visual：第 10 维检测——文字阴影 / 卡片融底 / 同心圆角" {
  let doc = Document::new({ width: 390.0, height: 844.0 })
  // 画布底 #FFFFFF 的容器
  let page = vl_node("page", Frame, "", "#FFFFFF", 0.0, 400.0)
  let _ = doc.insert_node(page, "root")
  // 1) 文字带阴影
  let t = vl_node("title", Text, "heading", "none", 0.0, 24.0)
  let _ = doc.insert_node({ ..t, style: { ..t.style, shadow: "e2" } }, "page")
  // 2) 卡片与画布同色、无阴影无描边
  let c = vl_node("flat_card", Frame, "card", "#FFFFFF", 12.0, 120.0)
  let _ = doc.insert_node(c, "page")
  // 3) 同心圆角违例：子 20 > 父 12
  let outer = vl_node("outer", Frame, "card", "#F2F2F7", 12.0, 200.0)
  let _ = doc.insert_node({ ..outer, style: { ..outer.style, shadow: "e1" } }, "page")
  let inner = vl_node("inner", Rect, "image", "#DDDDDD", 20.0, 120.0)
  let _ = doc.insert_node(inner, "outer")
  // 胶囊豁免：高 40 圆角 20（= 高/2）不算违例
  let pill = vl_node("pill", Rect, "chip", "#EEEEEE", 20.0, 40.0)
  let _ = doc.insert_node(pill, "outer")
  let issues = norm_visual_issues(doc)
  let all = issues.join("\n")
  assert_true(all.contains("title"))
  assert_true(all.contains("文字带阴影"))
  assert_true(all.contains("flat_card"))
  assert_true(all.contains("层次不可辨"))
  assert_true(all.contains("inner"))
  assert_true(all.contains("同心"))
  assert_false(all.contains("pill"))
  assert_eq(issues.length(), 3)
}

///|
test "visual：有阴影或描边的卡片不报融底" {
  let doc = Document::new({ width: 390.0, height: 844.0 })
  let page = vl_node("page", Frame, "", "#FFFFFF", 0.0, 400.0)
  let _ = doc.insert_node(page, "root")
  let c1 = vl_node("lifted", Frame, "card", "#FFFFFF", 12.0, 120.0)
  let _ = doc.insert_node({ ..c1, style: { ..c1.style, shadow: "e1" } }, "page")
  let c2 = vl_node("outlined", Frame, "card", "#FFFFFF", 12.0, 120.0)
  let _ = doc.insert_node(
    { ..c2, style: { ..c2.style, stroke: "#E5E5EA", stroke_width: 1.0 } },
    "page",
  )
  assert_eq(norm_visual_issues(doc).length(), 0)
}

///|
test "visual：critique 含第 10 维 visual" {
  let p = Project::new()
  let _ = p.apply_template(template_id="dashboard")
  match p.critique(artboard="dashboard") {
    Ok(j) => {
      assert_true(j.contains("\"principles\":10"))
      assert_true(j.contains("\"principle\":\"visual\""))
    }
    Err(_) => assert_true(false)
  }
}

///|
/// 导出 chrome 主题化：CSS 变量来自令牌，明暗随主题，theme-color/安全区/
/// 设备感画板/Hover Lift 与键盘可达全部在场。
test "visual：export_html 主题化 chrome 与 Hover Lift" {
  let p = Project::new()
  let _ = p.apply_theme("apple")
  let _ = p.apply_template(template_id="login")
  let html = p.export_html()
  assert_true(html.contains("--mv-primary:#0068D6"))
  assert_true(html.contains("--mv-bg:#F2F2F7"))
  assert_true(html.contains("<meta name=\"color-scheme\" content=\"light\">"))
  assert_true(html.contains("<meta name=\"theme-color\" content=\"#F2F2F7\">"))
  assert_true(html.contains("viewport-fit=cover"))
  assert_true(html.contains("env(safe-area-inset-top)"))
  assert_true(html.contains("backdrop-filter:saturate(180%) blur(20px)"))
  assert_true(html.contains(".board>svg{display:block;max-width:100%;height:auto}"))
  assert_true(html.contains("@media (hover:hover){g.mv-live:hover"))
  assert_true(html.contains("el.classList.add('mv-live')"))
  assert_true(html.contains("el.setAttribute('role','button')"))
  // 非交互节点不伪装可点：pointer 只挂 mv-live
  assert_false(html.contains("g[id^=n_]{cursor:pointer"))
  // 不再硬编码旧深底
  assert_false(html.contains("background:#1a1c1e"))
  // 暗色美学主题 → color-scheme dark
  let q = Project::new()
  let _ = q.apply_theme("apple_dark")
  let _ = q.apply_template(template_id="login")
  let h2 = q.export_html()
  assert_true(h2.contains("<meta name=\"color-scheme\" content=\"dark\">"))
  assert_true(h2.contains("--mv-bg:#1C1C1E"))
}

///|
const VL_SPEC : String = "{\"v\":1,\"typography\":{\"body\":14},\"radius\":{\"sm\":8,\"md\":12,\"lg\":16}}"
