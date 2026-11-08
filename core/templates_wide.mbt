///|
/// Web / PC 宽屏模板：桌面 Web 与 PC 应用形态的原型（1280×800）。
///
/// 与手机模板的区别不是"画布变大"，而是页面语义变了：
/// - Web：顶部导航 + 居中内容列 + 多栏网格 + footer
/// - PC 应用：标题栏 + 侧边栏 + 工具栏 + 多面板 + 状态栏
///
/// 颜色一律先经 self.tokens.resolve_color(角色) 解析成 hex 再落盘
/// （edit_node 不解析角色名，直接传 "surface" 会原样写进文档）——
/// 宽屏模板随主题明暗翻转，不再有暗色主题下的刺眼白板（审计 R3）。
/// 例外是明确的「反色 chrome」：侧边栏/标题栏的深色底与其上的浅色文字
/// 是刻意的品牌深色，不随主题翻转。
const WIDE_W : Double = 1280.0

///|
const WIDE_H : Double = 800.0

///|
/// 反色 chrome 常量（PC 桌面应用壳）：侧边栏/标题栏的深色底是产品身份色，
/// 与主题无关；其上文字固定浅灰，对比度对深底达标。
const WIDE_INVERSE_BG : String = "#1E2126"

///|
const WIDE_INVERSE_TITLEBAR : String = "#111318"

///|
const WIDE_INVERSE_TEXT : String = "#C8CCD2"

///|
/// 反色深底上的弱调文字：#7C838C 压 #1E2126 仅 4.21 < 4.5，提亮到
/// #868D97（4.82），仍与 WIDE_INVERSE_TEXT #C8CCD2 保持两档层次
const WIDE_INVERSE_MUTED : String = "#868D97"

///|
/// 反色深底上的弱白（标题/文件名）：#FFFFFF 对 #1E2126 约 14:1，这里
/// 收一档到 #E8EAED 保持层次且仍 ≥10:1
const WIDE_INVERSE_BRIGHT : String = "#E8EAED"

///|
/// 模板内联样式辅助：直接落 k=v（fill/text_color/stroke/radius/opacity）。
/// kvs 的值须是已解析的 hex（本文件统一经 resolve_color 预解析）。
fn Project::w_style(
  self : Project,
  ab : String,
  id : String,
  kvs : Array[(String, String)],
) -> Unit {
  let _ = self.edit_node(artboard=ab, node_id=id, kvs~)
}

// ---------------------------------------------------------------------------
// Web 落地页：导航栏 + Hero 双栏 + 三特性卡 + Footer
// ---------------------------------------------------------------------------

///|
fn Project::template_web_landing(self : Project, name : String) -> String {
  let t = self.tokens
  let c = fn(role : String) -> String { t.resolve_color(role) }
  let ab = self.create_artboard(name~, width=WIDE_W, height=WIDE_H)

  // 顶部导航栏
  self.place_required(ab, "rect", "nav_bar", x=0.0, y=0.0)
  self.resize_node(ab, "nav_bar", WIDE_W, 64.0, 0.0)
  self.w_style(
    ab,
    "nav_bar",
    [("fill", c("surface")), ("stroke", c("outline_variant"))],
  )
  self.place_required(
    ab,
    "badge",
    "nav_logo",
    variant="primary",
    x=32.0,
    y=12.0,
  )
  self.resize_node(ab, "nav_logo", 40.0, 40.0, 999.0)
  let nav_items = ["Product", "Features", "Pricing", "Docs"]
  // 等距 120 且整组居中：墨迹 445..836 中心 ≈640（旧组 321..711 偏左 124）
  let nav_x = [445.0, 565.0, 685.0, 805.0]
  for i in 0..<4 {
    let id = "nav_i" + i.to_string()
    self.place_required(ab, "body_text", id, x=nav_x[i], y=24.0)
    self.set_text(ab, id, nav_items[i])
    self.resize_node(ab, id, 72.0, 20.0, 0.0)
  }
  self.place_required(
    ab,
    "button",
    "nav_cta",
    variant="primary",
    x=1120.0,
    y=14.0,
  )
  self.set_text(ab, "nav_cta", "Get Started")
  self.resize_node(ab, "nav_cta", 128.0, 36.0, 8.0)

  // Hero：左文案右插图
  self.place_required(
    ab,
    "heading",
    "hero_title",
    variant="h1",
    x=96.0,
    y=175.0,
  )
  self.set_text(ab, "hero_title", "Prototype at the speed of thought")
  self.resize_node(ab, "hero_title", 560.0, 56.0, 0.0)
  let _ = self.edit_node(
    artboard=ab,
    node_id="hero_title",
    kvs=[("weight", "700")],
  )
  self.place_required(ab, "body_text", "hero_sub", x=96.0, y=253.0)
  self.set_text(
    ab, "hero_sub", "Design, critique and iterate — human drags, agent commands.",
  )
  self.resize_node(ab, "hero_sub", 520.0, 24.0, 0.0)
  self.place_required(
    ab,
    "button",
    "hero_btn1",
    variant="primary",
    x=96.0,
    y=317.0,
  )
  self.set_text(ab, "hero_btn1", "Start Free")
  self.resize_node(ab, "hero_btn1", 160.0, 48.0, 10.0)
  self.place_required(
    ab,
    "button",
    "hero_btn2",
    variant="secondary",
    x=276.0,
    y=317.0,
  )
  self.set_text(ab, "hero_btn2", "Watch Demo")
  self.resize_node(ab, "hero_btn2", 160.0, 48.0, 10.0)
  self.place_required(ab, "rect", "hero_art", x=720.0, y=140.0)
  self.resize_node(ab, "hero_art", 464.0, 260.0, 16.0)
  // 插图占位 = 品牌容器色（primary_container 随主题翻转，亮暗都可辨）
  self.w_style(ab, "hero_art", [("fill", c("primary_container"))])

  // 三列特性卡
  let feats = ["Fast", "Smart", "Open"]
  let descs = ["Instant canvas", "Agent driven", "Plain-text source"]
  let fx = [96.0, 496.0, 896.0]
  for i in 0..<3 {
    let cid = "feat_card" + i.to_string()
    // 模板是确定性构造：place_required 让变体拼错当场炸掉，不再静默丢
    // 图标引发后续子节点整体上浮（第 2 轮 feat_icon2 回归的放大器）
    self.place_required(
      ab,
      "card",
      cid,
      variant="elevated",
      x=fx[i],
      y=460.0,
      w=288.0,
      h=210.0,
    )
    let iid = "feat_icon" + i.to_string()
    // 三卡图标区分语义色（原三枚同色主色圆读作占位，且首屏高饱和主色过多）
    let icon_variant = ["primary", "success", "warning"][i]
    self.place_required(
      ab,
      "badge",
      iid,
      variant=icon_variant,
      // x=8：栈内容盒已内缩 pad 16，resolve_pos 再叠加——8+16=24 才是
      // 视觉左距 24（旧 24 落成 40，内容挤在左上）
      x=fx[i] + 8.0,
      y=484.0,
      w=48.0,
      h=48.0,
    )
    let tid = "feat_title" + i.to_string()
    self.place_required(
      ab,
      "heading",
      tid,
      variant="h3",
      x=fx[i] + 8.0,
      y=552.0,
      w=200.0,
      h=28.0,
    )
    self.set_text(ab, tid, feats[i])
    let _ = self.edit_node(artboard=ab, node_id=tid, kvs=[("weight", "700")])
    let bid = "feat_body" + i.to_string()
    self.place_required(
      ab,
      "body_text",
      bid,
      x=fx[i] + 8.0,
      y=588.0,
      w=200.0,
      h=20.0,
    )
    self.set_text(ab, bid, descs[i])
    let _ = self.edit_node(
      artboard=ab,
      node_id=cid,
      kvs=[("justify", "center")],
    )
    // 200 而非 240：收编进卡片后由栈布局接管排布，240 会溢出卡片内容盒
    // （issue #14：web_landing feat_bodyN contained_in_parent）
  }

  // Footer：surface_variant 深一档的面板带 + text_secondary（随主题翻转，
  // 不再硬编码近黑底触发纯黑禁令、亮字压暗底读不清）
  self.place_required(ab, "rect", "footer", x=0.0, y=736.0)
  self.resize_node(ab, "footer", WIDE_W, 64.0, 0.0)
  self.w_style(ab, "footer", [("fill", c("surface_variant"))])
  self.place_required(ab, "body_text", "footer_note", x=32.0, y=758.0)
  self.set_text(ab, "footer_note", "© 2026 MoonViz — AI native prototyping")
  self.resize_node(ab, "footer_note", 400.0, 20.0, 0.0)
  self.w_style(ab, "footer_note", [("text_color", c("text_secondary"))])
  self.place_required(ab, "body_text", "footer_links", x=980.0, y=758.0)
  self.set_text(ab, "footer_links", "About   Privacy   Contact")
  // 盒右缘 980+268=1248 = nav_cta 右缘，右对齐——左锚曾让墨迹止于 ~1143
  self.resize_node(ab, "footer_links", 268.0, 20.0, 0.0)
  self.w_style(ab, "footer_links", [("text_color", c("text_secondary"))])
  let _ = self.edit_node(
    artboard=ab,
    node_id="footer_links",
    kvs=[("align", "right")],
  )

  ab
}

// ---------------------------------------------------------------------------
// Web 登录页：左品牌半屏 + 右居中表单卡
// ---------------------------------------------------------------------------

///|
fn Project::template_web_login(self : Project, name : String) -> String {
  let t = self.tokens
  let c = fn(role : String) -> String { t.resolve_color(role) }
  let ab = self.create_artboard(name~, width=WIDE_W, height=WIDE_H)

  // 左侧品牌区：主色实底 + on_primary 文字（随主题翻转，不再一屏两套蓝）
  self.place_required(ab, "rect", "brand_pane", x=0.0, y=0.0)
  self.resize_node(ab, "brand_pane", 560.0, WIDE_H, 0.0)
  self.w_style(ab, "brand_pane", [("fill", c("primary"))])
  self.place_required(ab, "badge", "brand_logo", x=96.0, y=120.0)
  self.resize_node(ab, "brand_logo", 64.0, 64.0, 999.0)
  self.w_style(ab, "brand_logo", [("fill", c("on_primary"))])
  // 首字母字形：空圆读作图片未加载（审计 brand_logo 残留）；圆底已置
  // on_primary，字形用 primary（品牌色字压白盘）——沿 badge 变体默认的
  // on_primary 字色会同色相撞
  self.set_text(ab, "brand_logo", "M")
  let _ = self.edit_node(
    artboard=ab,
    node_id="brand_logo",
    kvs=[
      ("font_size", "26"),
      ("weight", "600"),
      ("text_color", c("primary")),
    ],
  )
  self.place_required(
    ab,
    "heading",
    "brand_title",
    variant="h1",
    x=96.0,
    y=320.0,
  )
  self.set_text(ab, "brand_title", "Design together\nwith your agent")
  self.resize_node(ab, "brand_title", 400.0, 112.0, 0.0)
  self.w_style(ab, "brand_title", [("text_color", c("on_primary"))])
  let _ = self.edit_node(
    artboard=ab,
    node_id="brand_title",
    kvs=[("weight", "700")],
  )
  self.place_required(ab, "body_text", "brand_sub", x=96.0, y=452.0)
  self.set_text(
    ab, "brand_sub", "One plain-text source of truth for humans and AI.",
  )
  self.resize_node(ab, "brand_sub", 380.0, 24.0, 0.0)
  self.w_style(ab, "brand_sub", [("text_color", c("on_primary"))])

  // 右侧表单卡
  // 卡心对齐右栏中线（右栏 560..1280 中心 920，原 900 偏左 20）；
  // 内容整体下移 12px 平衡上下留白（原顶 45 / 底 68）
  self.place_required(ab, "rect", "form_card", x=700.0, y=180.0)
  self.resize_node(ab, "form_card", 440.0, 440.0, 16.0)
  self.w_style(
    ab,
    "form_card",
    [("fill", c("surface")), ("stroke", c("outline_variant"))],
  )
  self.place_required(
    ab,
    "heading",
    "wl_title",
    variant="h3",
    x=736.0,
    y=232.0,
  )
  self.set_text(ab, "wl_title", "Welcome back")
  self.resize_node(ab, "wl_title", 300.0, 30.0, 0.0)
  let _ = self.edit_node(artboard=ab, node_id="wl_title", kvs=[("weight", "700")])
  self.place_required(ab, "body_text", "wl_sub", x=736.0, y=266.0)
  self.set_text(ab, "wl_sub", "Sign in to continue")
  self.resize_node(ab, "wl_sub", 300.0, 20.0, 0.0)
  self.place_required(
    ab,
    "text_input",
    "wl_email",
    variant="filled",
    x=736.0,
    y=316.0,
  )
  self.set_text(ab, "wl_email", "Email address")
  self.resize_node(ab, "wl_email", 368.0, 48.0, 10.0)
  self.place_required(
    ab,
    "text_input",
    "wl_pass",
    variant="filled",
    x=736.0,
    y=376.0,
  )
  self.set_text(ab, "wl_pass", "Password")
  self.resize_node(ab, "wl_pass", 368.0, 48.0, 10.0)
  // forgot 链接：盒横跨输入栏全宽 + 右对齐，右缘贴输入框右缘
  // （start 锚 + 手算盒宽让墨迹悬空 ~50px，三桌面主题残留）
  self.place_required(
    ab,
    "body_text",
    "wl_forgot",
    variant="caption",
    x=736.0,
    y=436.0,
  )
  self.set_text(ab, "wl_forgot", "Forgot password?")
  self.resize_node(ab, "wl_forgot", 368.0, 18.0, 0.0)
  self.w_style(ab, "wl_forgot", [("text_color", c("primary"))])
  let _ = self.edit_node(artboard=ab, node_id="wl_forgot", kvs=[("align", "right")])
  self.place_required(
    ab,
    "button",
    "wl_btn",
    variant="primary",
    x=736.0,
    y=472.0,
  )
  self.set_text(ab, "wl_btn", "Sign In")
  self.resize_node(ab, "wl_btn", 368.0, 48.0, 10.0)
  // signup 链接：盒横跨输入栏全宽 + 居中——与居中的 Sign In 按钮同一
  // 中轴 920（start 锚 + 手算盒宽曾左偏 ~38px）
  self.place_required(
    ab,
    "body_text",
    "wl_signup",
    variant="caption",
    x=736.0,
    y=552.0,
  )
  self.set_text(ab, "wl_signup", "No account? Create one")
  self.resize_node(ab, "wl_signup", 368.0, 18.0, 0.0)
  // 整行链接色（forgot 已是 primary）——拆节点会破坏居中，注册入口
  // 整行可点是常见 UI 惯例
  self.w_style(ab, "wl_signup", [("text_color", c("primary"))])
  let _ = self.edit_node(artboard=ab, node_id="wl_signup", kvs=[("align", "center")])

  ab
}

// ---------------------------------------------------------------------------
// Web 仪表盘：侧边栏 + 顶栏 + 统计卡 + 图表/侧面板双栏
// ---------------------------------------------------------------------------

///|
fn Project::template_web_dashboard(self : Project, name : String) -> String {
  let t = self.tokens
  let c = fn(role : String) -> String { t.resolve_color(role) }
  let ab = self.create_artboard(name~, width=WIDE_W, height=WIDE_H)

  // 侧边栏：反色 chrome（品牌深底），文字固定浅色
  self.place_required(ab, "rect", "sb", x=0.0, y=0.0)
  self.resize_node(ab, "sb", 224.0, WIDE_H, 0.0)
  self.w_style(ab, "sb", [("fill", c("inverse_surface"))])
  self.place_required(
    ab,
    "badge",
    "sb_logo",
    variant="primary",
    x=24.0,
    y=24.0,
  )
  self.resize_node(ab, "sb_logo", 36.0, 36.0, 999.0)
  self.place_required(
    ab,
    "heading",
    "sb_name",
    variant="h4",
    x=72.0,
    y=32.0,
  )
  self.set_text(ab, "sb_name", "MoonViz")
  self.resize_node(ab, "sb_name", 120.0, 22.0, 0.0)
  self.w_style(ab, "sb_name", [("text_color", c("inverse_text"))])
  let items = ["Overview", "Analytics", "Projects", "Team", "Billing"]
  for i in 0..<5 {
    let id = "sb_i" + i.to_string()
    // 选中项背景条先放（画在文字底下），不再重复绘制第二份文字
    // （旧实现 sb_i0 与 sb_i0_fg 同坐标同文案叠两层，渲染发虚）
    if i == 0 {
      self.place_required(ab, "rect", id + "_bg", x=16.0, y=88.0)
      self.resize_node(ab, id + "_bg", 192.0, 36.0, 8.0)
      self.w_style(ab, id + "_bg", [("fill", c("primary"))])
    }
    self.place_required(
      ab,
      "body_text",
      id,
      x=28.0,
      y=96.0 + i.to_double() * 44.0,
    )
    self.set_text(ab, id, items[i])
    self.resize_node(ab, id, 160.0, 20.0, 0.0)
    // 选中项文字随高亮条走令牌：constant 亮字压暗色主题的浅 primary 仅
    // 1.65:1，on_primary 全主题达标（dark 8.57 / nord 6.24 / apple 5.31）
    let active : Array[(String, String)] = if i == 0 {
      [("text_color", c("on_primary"))]
    } else {
      [("text_color", c("inverse_muted"))]
    }
    self.w_style(ab, id, active)
  }

  // 顶栏
  self.place_required(ab, "rect", "topbar", x=224.0, y=0.0)
  self.resize_node(ab, "topbar", WIDE_W - 224.0, 64.0, 0.0)
  self.w_style(
    ab,
    "topbar",
    [("fill", c("surface")), ("stroke", c("outline_variant"))],
  )
  self.place_required(
    ab,
    "heading",
    "tb_title",
    variant="h4",
    x=252.0,
    y=22.0,
  )
  self.set_text(ab, "tb_title", "Overview")
  self.resize_node(ab, "tb_title", 200.0, 22.0, 0.0)
  self.place_required(ab, "badge", "tb_avatar", x=1188.0, y=14.0)
  self.resize_node(ab, "tb_avatar", 36.0, 36.0, 999.0)

  // 统计卡 ×4
  let stats = ["Visitors", "Signups", "Revenue", "Churn"]
  let vals = ["24.5k", "1,204", "$38.2k", "2.1%"]
  let deltas = [
    "▲ 12% vs last week", "▲ 8% vs last week", "▲ 21% vs last week", "▼ 0.4 pts",
  ]
  let sx = [252.0, 508.0, 764.0, 1020.0]
  for i in 0..<4 {
    let cid = "wd_stat" + i.to_string()
    self.place_required(
      ab,
      "card",
      cid,
      variant="elevated",
      x=sx[i],
      y=88.0,
    )
    // 116 而非 100：栈内容 16+18+8+30+8+16=96 + 底 pad 16 = 112 才装得下
    // 三行（issue #14：wd_sdN contained_in_parent）
    self.resize_node(ab, cid, 236.0, 116.0, 12.0)
    let lid = "wd_sl" + i.to_string()
    self.place_required(
      ab,
      "body_text",
      lid,
      variant="caption",
      x=sx[i] + 20.0,
      y=102.0,
    )
    self.set_text(ab, lid, stats[i])
    self.resize_node(ab, lid, 160.0, 18.0, 0.0)
    let vid = "wd_sv" + i.to_string()
    self.place_required(
      ab,
      "heading",
      vid,
      variant="h3",
      x=sx[i] + 20.0,
      y=124.0,
    )
    self.set_text(ab, vid, vals[i])
    self.resize_node(ab, vid, 180.0, 30.0, 0.0)
    let did = "wd_sd" + i.to_string()
    self.place_required(
      ab,
      "body_text",
      did,
      variant="caption",
      x=sx[i] + 20.0,
      y=160.0,
    )
    self.set_text(ab, did, deltas[i])
    // 164 而非 196：卡内容宽 204（236-2×16），交叉轴居中下 196 会溢出
    self.resize_node(ab, did, 164.0, 16.0, 0.0)
    // 涨跌色走语义令牌（success/error 随主题校准，不再硬编码固定绿红）
    self.w_style(ab, did, [
      ("text_color", if i == 3 { c("error") } else { c("success") }),
    ])
  }

  // 图表区 + 侧面板
  self.place_required(ab, "rect", "wd_chart", x=252.0, y=212.0)
  self.resize_node(ab, "wd_chart", 580.0, 360.0, 12.0)
  self.w_style(
    ab,
    "wd_chart",
    [("fill", c("surface")), ("stroke", c("outline_variant"))],
  )
  self.place_required(
    ab,
    "heading",
    "wd_ct",
    variant="h4",
    x=276.0,
    y=236.0,
  )
  self.set_text(ab, "wd_ct", "Weekly traffic")
  self.resize_node(ab, "wd_ct", 200.0, 22.0, 0.0)
  // 简易柱状图：7 根柱
  let bars = [120.0, 180.0, 150.0, 220.0, 260.0, 200.0, 280.0]
  for i in 0..<7 {
    let id = "wd_bar" + i.to_string()
    self.place_required(
      ab,
      "rect",
      id,
      x=300.0 + i.to_double() * 72.0,
      y=536.0 - bars[i],
    )
    self.resize_node(ab, id, 40.0, bars[i], 4.0)
    self.w_style(ab, id, [("fill", c("primary"))])
  }
  self.place_required(ab, "rect", "wd_side", x=848.0, y=212.0)
  self.resize_node(ab, "wd_side", 408.0, 360.0, 12.0)
  self.w_style(
    ab,
    "wd_side",
    [("fill", c("surface")), ("stroke", c("outline_variant"))],
  )
  self.place_required(
    ab,
    "heading",
    "wd_st",
    variant="h4",
    x=872.0,
    y=236.0,
  )
  self.set_text(ab, "wd_st", "Recent activity")
  self.resize_node(ab, "wd_st", 200.0, 22.0, 0.0)
  let acts = [
    "Ada merged layout patch", "Bob moved hero_art", "Agent applied theme dark",
  ]
  for i in 0..<3 {
    let id = "wd_act" + i.to_string()
    self.place_required(
      ab,
      "rect",
      id,
      x=872.0,
      y=276.0 + i.to_double() * 64.0,
    )
    self.resize_node(ab, id, 360.0, 52.0, 8.0)
    self.w_style(ab, id, [("fill", c("surface_variant"))])
    let tid = "wd_at" + i.to_string()
    self.place_required(
      ab,
      "body_text",
      tid,
      x=888.0,
      y=292.0 + i.to_double() * 64.0,
    )
    self.set_text(ab, tid, acts[i])
    self.resize_node(ab, tid, 330.0, 20.0, 0.0)
  }

  // 底部表格区
  self.place_required(ab, "rect", "wd_table", x=252.0, y=596.0)
  self.resize_node(ab, "wd_table", 1004.0, 180.0, 12.0)
  self.w_style(
    ab,
    "wd_table",
    [("fill", c("surface")), ("stroke", c("outline_variant"))],
  )
  let heads = ["User", "Action", "Time"]
  let hx = [276.0, 700.0, 1050.0]
  for i in 0..<3 {
    let id = "wd_th" + i.to_string()
    self.place_required(
      ab,
      "body_text",
      id,
      variant="caption",
      x=hx[i],
      y=616.0,
    )
    self.set_text(ab, id, heads[i])
    self.resize_node(ab, id, 120.0, 18.0, 0.0)
    self.w_style(ab, id, [("text_color", c("text_hint"))])
  }
  let rows = [
    ["ada", "move hero_art", "2m"],
    ["bob", "update fill", "18m"],
    ["eve", "place button", "1h"],
  ]
  for i in 0..<3 {
    for j in 0..<3 {
      let id = "wd_td" + i.to_string() + "_" + j.to_string()
      self.place_required(
        ab,
        "body_text",
        id,
        x=hx[j],
        y=648.0 + i.to_double() * 32.0,
      )
      self.set_text(ab, id, rows[i][j])
      self.resize_node(ab, id, 200.0, 20.0, 0.0)
    }
  }

  ab
}

// ---------------------------------------------------------------------------
// PC 桌面应用：标题栏 + 侧边栏 + 工具栏 + 三面板 + 状态栏
// ---------------------------------------------------------------------------

///|
fn Project::template_pc_app(self : Project, name : String) -> String {
  let t = self.tokens
  let c = fn(role : String) -> String { t.resolve_color(role) }
  let ab = self.create_artboard(name~, width=WIDE_W, height=WIDE_H)

  // 标题栏（红黄绿交通灯）：反色 chrome
  self.place_required(ab, "rect", "title_bar", x=0.0, y=0.0)
  self.resize_node(ab, "title_bar", WIDE_W, 36.0, 0.0)
  self.w_style(ab, "title_bar", [("fill", c("inverse_surface_variant"))])
  let dots = [c("error"), c("warning"), c("success")]
  for i in 0..<3 {
    let id = "tl_dot" + i.to_string()
    self.place_required(
      ab,
      "badge",
      id,
      x=20.0 + i.to_double() * 24.0,
      y=12.0,
    )
    self.resize_node(ab, id, 12.0, 12.0, 999.0)
    self.w_style(ab, id, [("fill", dots[i])])
  }
  // 标题居中窗口轴线（macOS 惯例）：盒 490..790 中心 640，文字 align center
  self.place_required(ab, "body_text", "tl_title", x=490.0, y=9.0)
  self.set_text(ab, "tl_title", "MoonViz Studio — login.mbt.md")
  self.resize_node(ab, "tl_title", 300.0, 18.0, 0.0)
  self.w_style(
    ab,
    "tl_title",
    [("text_color", c("inverse_muted")), ("align", "center")],
  )

  // 侧边栏：反色 chrome
  self.place_required(ab, "rect", "pc_sb", x=0.0, y=36.0)
  // 高 764：36+764=800 顶满画板底——旧 736（底 772 对齐状态栏）会在
  // 左下角留 240×28 画布色缺口，状态栏本就从 x=240 起
  self.resize_node(ab, "pc_sb", 240.0, 764.0, 0.0)
  self.w_style(ab, "pc_sb", [("fill", c("inverse_surface"))])
  let files = ["login.mbt.md", "dashboard.mbt.md", "tokens.json", "history.log"]
  for i in 0..<4 {
    let id = "pc_f" + i.to_string()
    self.place_required(
      ab,
      "body_text",
      id,
      x=36.0,
      y=72.0 + i.to_double() * 32.0,
    )
    self.set_text(ab, id, files[i])
    self.resize_node(ab, id, 180.0, 20.0, 0.0)
    self.w_style(
      ab,
      id,
      if i == 0 {
        [("text_color", c("inverse_text"))]
      } else {
        [("text_color", c("inverse_muted"))]
      },
    )
  }
  self.place_required(
    ab,
    "heading",
    "pc_sbh",
    variant="h4",
    x=24.0,
    y=232.0,
  )
  self.set_text(ab, "pc_sbh", "Pages")
  self.resize_node(ab, "pc_sbh", 120.0, 20.0, 0.0)
  self.w_style(ab, "pc_sbh", [("text_color", c("inverse_muted"))])
  let pages = ["login", "signup", "dashboard"]
  for i in 0..<3 {
    let id = "pc_p" + i.to_string()
    self.place_required(
      ab,
      "body_text",
      id,
      x=36.0,
      y=264.0 + i.to_double() * 32.0,
    )
    self.set_text(ab, id, pages[i])
    self.resize_node(ab, id, 160.0, 20.0, 0.0)
    self.w_style(ab, id, [("text_color", c("inverse_text"))])
  }

  // 工具栏：随主题（暗色下不再白底压深灰按钮）；按钮归按钮族规范档
  // （高 36 / 圆角 8——32 高的密集工具栏档会吃 norms 偏差）
  self.place_required(ab, "rect", "pc_tb", x=240.0, y=36.0)
  self.resize_node(ab, "pc_tb", WIDE_W - 240.0, 52.0, 0.0)
  self.w_style(
    ab,
    "pc_tb",
    [("fill", c("surface")), ("stroke", c("outline_variant"))],
  )
  let tbtns = ["Select", "Move", "Text"]
  for i in 0..<3 {
    let id = "pc_tbn" + i.to_string()
    self.place_required(
      ab,
      "button",
      id,
      variant="secondary",
      x=272.0 + i.to_double() * 96.0,
      y=44.0,
    )
    self.set_text(ab, id, tbtns[i])
    self.resize_node(ab, id, 84.0, 36.0, 8.0)
  }
  self.place_required(
    ab,
    "button",
    "pc_run",
    variant="primary",
    x=1156.0,
    y=44.0,
  )
  self.set_text(ab, "pc_run", "Critique")
  self.resize_node(ab, "pc_run", 92.0, 36.0, 8.0)

  // 三面板：图层列表 / 画布 / 属性（随主题，标题与列表文字走令牌）
  self.place_required(ab, "rect", "pc_layers", x=240.0, y=88.0)
  self.resize_node(ab, "pc_layers", 280.0, 684.0, 0.0)
  self.w_style(ab, "pc_layers", [("fill", c("surface_variant"))])
  self.place_required(
    ab,
    "heading",
    "pc_lh",
    variant="h4",
    x=260.0,
    y=108.0,
  )
  self.set_text(ab, "pc_lh", "Layers")
  self.resize_node(ab, "pc_lh", 120.0, 20.0, 0.0)
  let layers = ["root", "hero_title", "hero_btn1", "feat_card0"]
  for i in 0..<4 {
    let id = "pc_l" + i.to_string()
    // 层级缩进：root 顶层，其余为其子级——平铺同 x 读作平级列表（审计残留）
    let lx = if i == 0 { 276.0 } else { 292.0 }
    self.place_required(
      ab,
      "body_text",
      id,
      x=lx,
      y=144.0 + i.to_double() * 32.0,
    )
    self.set_text(ab, id, layers[i])
    self.resize_node(ab, id, 200.0, 20.0, 0.0)
  }
  self.place_required(ab, "rect", "pc_canvas", x=520.0, y=88.0)
  self.resize_node(ab, "pc_canvas", 560.0, 684.0, 0.0)
  self.w_style(ab, "pc_canvas", [("fill", c("surface"))])
  // 画布内放一个手机画板缩略示意（品牌容器色，随主题翻转）；
  // 缩略图在画布内居中：x=520+(560-180)/2=710，y=88+(684-380)/2=240
  self.place_required(ab, "rect", "pc_phone", x=710.0, y=240.0)
  self.resize_node(ab, "pc_phone", 180.0, 380.0, 16.0)
  self.w_style(
    ab,
    "pc_phone",
    [("fill", c("primary_container")), ("stroke", c("primary"))],
  )
  self.place_required(ab, "rect", "pc_phone_hdr", x=726.0, y=264.0)
  self.resize_node(ab, "pc_phone_hdr", 148.0, 28.0, 6.0)
  self.w_style(ab, "pc_phone_hdr", [("fill", c("primary"))])
  self.place_required(ab, "rect", "pc_phone_btn", x=742.0, y=542.0)
  self.resize_node(ab, "pc_phone_btn", 116.0, 36.0, 18.0)
  self.w_style(ab, "pc_phone_btn", [("fill", c("primary"))])
  self.place_required(ab, "rect", "pc_props", x=1080.0, y=88.0)
  self.resize_node(ab, "pc_props", 200.0, 684.0, 0.0)
  self.w_style(ab, "pc_props", [("fill", c("surface_variant"))])
  self.place_required(
    ab,
    "heading",
    "pc_ph",
    variant="h4",
    x=1096.0,
    y=108.0,
  )
  self.set_text(ab, "pc_ph", "Properties")
  self.resize_node(ab, "pc_ph", 150.0, 20.0, 0.0)
  // 属性值对齐画布内唯一选中对象（手机缩略图 x=640/y=150/w=180，
  // fill=primary_container）——此前的 x:96/w:560 与任何元素都对不上
  // 属性值与缩略图实际位置同步（第 2 轮移位 640/150→710/240 后面板文案未跟上）
  let props = ["x: 710", "y: 240", "w: 180", "fill: primary_container"]
  for i in 0..<4 {
    let id = "pc_pr" + i.to_string()
    self.place_required(
      ab,
      "body_text",
      id,
      x=1096.0,
      y=144.0 + i.to_double() * 32.0,
    )
    self.set_text(ab, id, props[i])
    self.resize_node(ab, id, 160.0, 18.0, 0.0)
  }

  // 状态栏：surface_variant 面板带 + text_hint 说明字（全部主题 ≥4.5）
  self.place_required(ab, "rect", "pc_status", x=240.0, y=772.0)
  self.resize_node(ab, "pc_status", WIDE_W - 240.0, 28.0, 0.0)
  self.w_style(ab, "pc_status", [("fill", c("surface_variant"))])
  self.place_required(
    ab,
    "body_text",
    "pc_st",
    variant="caption",
    x=256.0,
    y=778.0,
  )
  self.set_text(ab, "pc_st", "ops: 3   revision: 12   gate: AGENT ✓")
  self.resize_node(ab, "pc_st", 400.0, 18.0, 0.0)

  ab
}
