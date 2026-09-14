///|
/// Web / PC 宽屏模板：桌面 Web 与 PC 应用形态的原型（1280×800）。
///
/// 与手机模板的区别不是"画布变大"，而是页面语义变了：
/// - Web：顶部导航 + 居中内容列 + 多栏网格 + footer
/// - PC 应用：标题栏 + 侧边栏 + 工具栏 + 多面板 + 状态栏
///
/// 模板仍只用设计令牌与组件系统，保证 Agent 后续修改的一致性。
const WIDE_W : Double = 1280.0

///|
const WIDE_H : Double = 800.0

///|
/// 模板内联样式辅助：直接落 k=v（fill/text_color/stroke/radius/opacity）
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
  let ab = self.create_artboard(name~, width=WIDE_W, height=WIDE_H)

  // 顶部导航栏
  let _ = self.place_comp(ab, "rect", "nav_bar", x=0.0, y=0.0)
  self.resize_node(ab, "nav_bar", WIDE_W, 64.0, 0.0)
  self.w_style(ab, "nav_bar", [("fill", "#FFFFFF"), ("stroke", "#E0E0E0")])
  let _ = self.place_comp(
    ab,
    "badge",
    "nav_logo",
    variant="primary",
    x=32.0,
    y=12.0,
  )
  self.resize_node(ab, "nav_logo", 40.0, 40.0, 999.0)
  let nav_items = ["Product", "Features", "Pricing", "Docs"]
  let nav_x = [320.0, 440.0, 560.0, 660.0]
  for i in 0..<4 {
    let id = "nav_i" + i.to_string()
    let _ = self.place_comp(ab, "body_text", id, x=nav_x[i], y=24.0)
    self.set_text(ab, id, nav_items[i])
    self.resize_node(ab, id, 72.0, 20.0, 0.0)
  }
  let _ = self.place_comp(
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
  let _ = self.place_comp(
    ab,
    "heading",
    "hero_title",
    variant="h1",
    x=96.0,
    y=150.0,
  )
  self.set_text(ab, "hero_title", "Prototype at the speed of thought")
  self.resize_node(ab, "hero_title", 560.0, 56.0, 0.0)
  let _ = self.place_comp(ab, "body_text", "hero_sub", x=96.0, y=228.0)
  self.set_text(
    ab, "hero_sub", "Design, critique and iterate — human drags, agent commands.",
  )
  self.resize_node(ab, "hero_sub", 520.0, 24.0, 0.0)
  let _ = self.place_comp(
    ab,
    "button",
    "hero_btn1",
    variant="primary",
    x=96.0,
    y=292.0,
  )
  self.set_text(ab, "hero_btn1", "Start Free")
  self.resize_node(ab, "hero_btn1", 160.0, 48.0, 10.0)
  let _ = self.place_comp(
    ab,
    "button",
    "hero_btn2",
    variant="secondary",
    x=276.0,
    y=292.0,
  )
  self.set_text(ab, "hero_btn2", "Watch Demo")
  self.resize_node(ab, "hero_btn2", 160.0, 48.0, 10.0)
  let _ = self.place_comp(ab, "rect", "hero_art", x=720.0, y=140.0)
  self.resize_node(ab, "hero_art", 464.0, 260.0, 16.0)
  self.w_style(ab, "hero_art", [("fill", "#EDF0FE")])

  // 三列特性卡
  let feats = ["Fast", "Smart", "Open"]
  let descs = ["Instant canvas", "Agent driven", "Plain-text source"]
  let fx = [96.0, 496.0, 896.0]
  for i in 0..<3 {
    let cid = "feat_card" + i.to_string()
    let _ = self.place_comp(
      ab,
      "card",
      cid,
      variant="elevated",
      x=fx[i],
      y=460.0,
    )
    self.resize_node(ab, cid, 288.0, 210.0, 12.0)
    let iid = "feat_icon" + i.to_string()
    let _ = self.place_comp(
      ab,
      "badge",
      iid,
      variant="primary",
      x=fx[i] + 24.0,
      y=484.0,
    )
    self.resize_node(ab, iid, 48.0, 48.0, 999.0)
    let tid = "feat_title" + i.to_string()
    let _ = self.place_comp(
      ab,
      "heading",
      tid,
      variant="h3",
      x=fx[i] + 24.0,
      y=552.0,
    )
    self.set_text(ab, tid, feats[i])
    self.resize_node(ab, tid, 200.0, 28.0, 0.0)
    let bid = "feat_body" + i.to_string()
    let _ = self.place_comp(ab, "body_text", bid, x=fx[i] + 24.0, y=588.0)
    self.set_text(ab, bid, descs[i])
    self.resize_node(ab, bid, 240.0, 20.0, 0.0)
  }

  // Footer
  let _ = self.place_comp(ab, "rect", "footer", x=0.0, y=736.0)
  self.resize_node(ab, "footer", WIDE_W, 64.0, 0.0)
  self.w_style(ab, "footer", [("fill", "#14161A")])
  let _ = self.place_comp(ab, "body_text", "footer_note", x=32.0, y=758.0)
  self.set_text(ab, "footer_note", "© 2026 MoonViz — AI native prototyping")
  self.resize_node(ab, "footer_note", 400.0, 20.0, 0.0)
  self.w_style(ab, "footer_note", [("text_color", "#9AA1AB")])
  let _ = self.place_comp(ab, "body_text", "footer_links", x=980.0, y=758.0)
  self.set_text(ab, "footer_links", "About   Privacy   Contact")
  self.resize_node(ab, "footer_links", 260.0, 20.0, 0.0)
  self.w_style(ab, "footer_links", [("text_color", "#9AA1AB")])

  ab
}

// ---------------------------------------------------------------------------
// Web 登录页：左品牌半屏 + 右居中表单卡
// ---------------------------------------------------------------------------

///|
fn Project::template_web_login(self : Project, name : String) -> String {
  let ab = self.create_artboard(name~, width=WIDE_W, height=WIDE_H)

  // 左侧品牌区
  let _ = self.place_comp(ab, "rect", "brand_pane", x=0.0, y=0.0)
  self.resize_node(ab, "brand_pane", 560.0, WIDE_H, 0.0)
  self.w_style(ab, "brand_pane", [("fill", "#4B6BFB")])
  let _ = self.place_comp(ab, "badge", "brand_logo", x=96.0, y=120.0)
  self.resize_node(ab, "brand_logo", 64.0, 64.0, 999.0)
  self.w_style(ab, "brand_logo", [("fill", "#FFFFFF")])
  let _ = self.place_comp(
    ab,
    "heading",
    "brand_title",
    variant="h1",
    x=96.0,
    y=320.0,
  )
  self.set_text(ab, "brand_title", "Design together\nwith your agent")
  self.resize_node(ab, "brand_title", 400.0, 112.0, 0.0)
  self.w_style(ab, "brand_title", [("text_color", "#FFFFFF")])
  let _ = self.place_comp(ab, "body_text", "brand_sub", x=96.0, y=452.0)
  self.set_text(
    ab, "brand_sub", "One plain-text source of truth for humans and AI.",
  )
  self.resize_node(ab, "brand_sub", 380.0, 24.0, 0.0)
  self.w_style(ab, "brand_sub", [("text_color", "#DCE3FF")])

  // 右侧表单卡
  let _ = self.place_comp(ab, "rect", "form_card", x=680.0, y=180.0)
  self.resize_node(ab, "form_card", 440.0, 440.0, 16.0)
  self.w_style(ab, "form_card", [("fill", "#FFFFFF"), ("stroke", "#E0E0E0")])
  let _ = self.place_comp(
    ab,
    "heading",
    "wl_title",
    variant="h3",
    x=716.0,
    y=220.0,
  )
  self.set_text(ab, "wl_title", "Welcome back")
  self.resize_node(ab, "wl_title", 300.0, 30.0, 0.0)
  let _ = self.place_comp(ab, "body_text", "wl_sub", x=716.0, y=254.0)
  self.set_text(ab, "wl_sub", "Sign in to continue")
  self.resize_node(ab, "wl_sub", 300.0, 20.0, 0.0)
  let _ = self.place_comp(
    ab,
    "text_input",
    "wl_email",
    variant="filled",
    x=716.0,
    y=304.0,
  )
  self.set_text(ab, "wl_email", "Email address")
  self.resize_node(ab, "wl_email", 368.0, 48.0, 10.0)
  let _ = self.place_comp(
    ab,
    "text_input",
    "wl_pass",
    variant="filled",
    x=716.0,
    y=364.0,
  )
  self.set_text(ab, "wl_pass", "Password")
  self.resize_node(ab, "wl_pass", 368.0, 48.0, 10.0)
  let _ = self.place_comp(
    ab,
    "body_text",
    "wl_forgot",
    variant="caption",
    x=940.0,
    y=424.0,
  )
  self.set_text(ab, "wl_forgot", "Forgot password?")
  self.resize_node(ab, "wl_forgot", 144.0, 18.0, 0.0)
  let _ = self.place_comp(
    ab,
    "button",
    "wl_btn",
    variant="primary",
    x=716.0,
    y=460.0,
  )
  self.set_text(ab, "wl_btn", "Sign In")
  self.resize_node(ab, "wl_btn", 368.0, 48.0, 10.0)
  let _ = self.place_comp(
    ab,
    "body_text",
    "wl_signup",
    variant="caption",
    x=796.0,
    y=540.0,
  )
  self.set_text(ab, "wl_signup", "No account? Create one")
  self.resize_node(ab, "wl_signup", 220.0, 18.0, 0.0)

  ab
}

// ---------------------------------------------------------------------------
// Web 仪表盘：侧边栏 + 顶栏 + 统计卡 + 图表/侧面板双栏
// ---------------------------------------------------------------------------

///|
fn Project::template_web_dashboard(self : Project, name : String) -> String {
  let ab = self.create_artboard(name~, width=WIDE_W, height=WIDE_H)

  // 侧边栏
  let _ = self.place_comp(ab, "rect", "sb", x=0.0, y=0.0)
  self.resize_node(ab, "sb", 224.0, WIDE_H, 0.0)
  self.w_style(ab, "sb", [("fill", "#1E2126")])
  let _ = self.place_comp(
    ab,
    "badge",
    "sb_logo",
    variant="primary",
    x=24.0,
    y=24.0,
  )
  self.resize_node(ab, "sb_logo", 36.0, 36.0, 999.0)
  let _ = self.place_comp(
    ab,
    "heading",
    "sb_name",
    variant="h4",
    x=72.0,
    y=32.0,
  )
  self.set_text(ab, "sb_name", "MoonViz")
  self.resize_node(ab, "sb_name", 120.0, 22.0, 0.0)
  self.w_style(ab, "sb_name", [("text_color", "#FFFFFF")])
  let items = ["Overview", "Analytics", "Projects", "Team", "Billing"]
  for i in 0..<5 {
    let id = "sb_i" + i.to_string()
    let _ = self.place_comp(
      ab,
      "body_text",
      id,
      x=28.0,
      y=96.0 + i.to_double() * 44.0,
    )
    self.set_text(ab, id, items[i])
    self.resize_node(ab, id, 160.0, 20.0, 0.0)
    let active : Array[(String, String)] = if i == 0 {
      [("text_color", "#FFFFFF")]
    } else {
      [("text_color", "#7C838C")]
    }
    self.w_style(ab, id, active)
    // 选中项背景条
    if i == 0 {
      let _ = self.place_comp(ab, "rect", id + "_bg", x=16.0, y=88.0)
      self.resize_node(ab, id + "_bg", 192.0, 36.0, 8.0)
      self.w_style(ab, id + "_bg", [("fill", "#4B6BFB")])
      let _ = self.place_comp(ab, "body_text", id + "_fg", x=28.0, y=96.0)
      self.set_text(ab, id + "_fg", items[i])
      self.resize_node(ab, id + "_fg", 160.0, 20.0, 0.0)
      self.w_style(ab, id + "_fg", [("text_color", "#FFFFFF")])
    }
  }

  // 顶栏
  let _ = self.place_comp(ab, "rect", "topbar", x=224.0, y=0.0)
  self.resize_node(ab, "topbar", WIDE_W - 224.0, 64.0, 0.0)
  self.w_style(ab, "topbar", [("fill", "#FFFFFF"), ("stroke", "#E0E0E0")])
  let _ = self.place_comp(
    ab,
    "heading",
    "tb_title",
    variant="h4",
    x=252.0,
    y=22.0,
  )
  self.set_text(ab, "tb_title", "Overview")
  self.resize_node(ab, "tb_title", 200.0, 22.0, 0.0)
  let _ = self.place_comp(ab, "badge", "tb_avatar", x=1188.0, y=14.0)
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
    let _ = self.place_comp(
      ab,
      "card",
      cid,
      variant="elevated",
      x=sx[i],
      y=88.0,
    )
    self.resize_node(ab, cid, 236.0, 100.0, 12.0)
    let lid = "wd_sl" + i.to_string()
    let _ = self.place_comp(
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
    let _ = self.place_comp(
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
    let _ = self.place_comp(
      ab,
      "body_text",
      did,
      variant="caption",
      x=sx[i] + 20.0,
      y=160.0,
    )
    self.set_text(ab, did, deltas[i])
    self.resize_node(ab, did, 196.0, 16.0, 0.0)
    self.w_style(ab, did, [
      ("text_color", if i == 3 { "#E57373" } else { "#81C784" }),
    ])
  }

  // 图表区 + 侧面板
  let _ = self.place_comp(ab, "rect", "wd_chart", x=252.0, y=212.0)
  self.resize_node(ab, "wd_chart", 580.0, 360.0, 12.0)
  self.w_style(ab, "wd_chart", [("fill", "#FFFFFF"), ("stroke", "#E0E0E0")])
  let _ = self.place_comp(
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
    let _ = self.place_comp(
      ab,
      "rect",
      id,
      x=300.0 + i.to_double() * 72.0,
      y=536.0 - bars[i],
    )
    self.resize_node(ab, id, 40.0, bars[i], 4.0)
    self.w_style(ab, id, [("fill", "#4B6BFB")])
  }
  let _ = self.place_comp(ab, "rect", "wd_side", x=848.0, y=212.0)
  self.resize_node(ab, "wd_side", 408.0, 360.0, 12.0)
  self.w_style(ab, "wd_side", [("fill", "#FFFFFF"), ("stroke", "#E0E0E0")])
  let _ = self.place_comp(
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
    let _ = self.place_comp(
      ab,
      "rect",
      id,
      x=872.0,
      y=276.0 + i.to_double() * 64.0,
    )
    self.resize_node(ab, id, 360.0, 52.0, 8.0)
    self.w_style(ab, id, [("fill", "#F4F5F7")])
    let tid = "wd_at" + i.to_string()
    let _ = self.place_comp(
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
  let _ = self.place_comp(ab, "rect", "wd_table", x=252.0, y=596.0)
  self.resize_node(ab, "wd_table", 1004.0, 180.0, 12.0)
  self.w_style(ab, "wd_table", [("fill", "#FFFFFF"), ("stroke", "#E0E0E0")])
  let heads = ["User", "Action", "Time"]
  let hx = [276.0, 700.0, 1050.0]
  for i in 0..<3 {
    let id = "wd_th" + i.to_string()
    let _ = self.place_comp(
      ab,
      "body_text",
      id,
      variant="caption",
      x=hx[i],
      y=616.0,
    )
    self.set_text(ab, id, heads[i])
    self.resize_node(ab, id, 120.0, 18.0, 0.0)
    self.w_style(ab, id, [("text_color", "#7C838C")])
  }
  let rows = [
    ["ada", "move hero_art", "2m"],
    ["bob", "update fill", "18m"],
    ["eve", "place button", "1h"],
  ]
  for i in 0..<3 {
    for j in 0..<3 {
      let id = "wd_td" + i.to_string() + "_" + j.to_string()
      let _ = self.place_comp(
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
  let ab = self.create_artboard(name~, width=WIDE_W, height=WIDE_H)

  // 标题栏（红黄绿交通灯）
  let _ = self.place_comp(ab, "rect", "title_bar", x=0.0, y=0.0)
  self.resize_node(ab, "title_bar", WIDE_W, 36.0, 0.0)
  self.w_style(ab, "title_bar", [("fill", "#111318")])
  let dots = ["#FF5F57", "#FEBC2E", "#28C840"]
  for i in 0..<3 {
    let id = "tl_dot" + i.to_string()
    let _ = self.place_comp(
      ab,
      "badge",
      id,
      x=20.0 + i.to_double() * 24.0,
      y=12.0,
    )
    self.resize_node(ab, id, 12.0, 12.0, 999.0)
    self.w_style(ab, id, [("fill", dots[i])])
  }
  let _ = self.place_comp(ab, "body_text", "tl_title", x=600.0, y=9.0)
  self.set_text(ab, "tl_title", "MoonViz Studio — login.mbt.md")
  self.resize_node(ab, "tl_title", 300.0, 18.0, 0.0)
  self.w_style(ab, "tl_title", [("text_color", "#9AA1AB")])

  // 侧边栏
  let _ = self.place_comp(ab, "rect", "pc_sb", x=0.0, y=36.0)
  self.resize_node(ab, "pc_sb", 240.0, 728.0, 0.0)
  self.w_style(ab, "pc_sb", [("fill", "#1E2126")])
  let files = ["login.mbt.md", "dashboard.mbt.md", "tokens.json", "history.log"]
  for i in 0..<4 {
    let id = "pc_f" + i.to_string()
    let _ = self.place_comp(
      ab,
      "body_text",
      id,
      x=36.0,
      y=72.0 + i.to_double() * 36.0,
    )
    self.set_text(ab, id, files[i])
    self.resize_node(ab, id, 180.0, 20.0, 0.0)
    self.w_style(
      ab,
      id,
      if i == 0 {
        [("text_color", "#FFFFFF")]
      } else {
        [("text_color", "#7C838C")]
      },
    )
  }
  let _ = self.place_comp(
    ab,
    "heading",
    "pc_sbh",
    variant="h4",
    x=24.0,
    y=232.0,
  )
  self.set_text(ab, "pc_sbh", "Pages")
  self.resize_node(ab, "pc_sbh", 120.0, 20.0, 0.0)
  self.w_style(ab, "pc_sbh", [("text_color", "#9AA1AB")])
  let pages = ["login", "signup", "dashboard"]
  for i in 0..<3 {
    let id = "pc_p" + i.to_string()
    let _ = self.place_comp(
      ab,
      "body_text",
      id,
      x=36.0,
      y=264.0 + i.to_double() * 32.0,
    )
    self.set_text(ab, id, pages[i])
    self.resize_node(ab, id, 160.0, 20.0, 0.0)
    self.w_style(ab, id, [("text_color", "#C8CCD2")])
  }

  // 工具栏
  let _ = self.place_comp(ab, "rect", "pc_tb", x=240.0, y=36.0)
  self.resize_node(ab, "pc_tb", WIDE_W - 240.0, 52.0, 0.0)
  self.w_style(ab, "pc_tb", [("fill", "#FFFFFF"), ("stroke", "#E0E0E0")])
  let tbtns = ["Select", "Move", "Text"]
  for i in 0..<3 {
    let id = "pc_tbn" + i.to_string()
    let _ = self.place_comp(
      ab,
      "button",
      id,
      variant="secondary",
      x=260.0 + i.to_double() * 96.0,
      y=46.0,
    )
    self.set_text(ab, id, tbtns[i])
    self.resize_node(ab, id, 84.0, 32.0, 6.0)
  }
  let _ = self.place_comp(
    ab,
    "button",
    "pc_run",
    variant="primary",
    x=1156.0,
    y=46.0,
  )
  self.set_text(ab, "pc_run", "Critique")
  self.resize_node(ab, "pc_run", 92.0, 32.0, 6.0)

  // 三面板：图层列表 / 画布 / 属性
  let _ = self.place_comp(ab, "rect", "pc_layers", x=240.0, y=88.0)
  self.resize_node(ab, "pc_layers", 280.0, 684.0, 0.0)
  self.w_style(ab, "pc_layers", [("fill", "#F4F5F7")])
  let _ = self.place_comp(
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
    let _ = self.place_comp(
      ab,
      "body_text",
      id,
      x=276.0,
      y=144.0 + i.to_double() * 30.0,
    )
    self.set_text(ab, id, layers[i])
    self.resize_node(ab, id, 200.0, 20.0, 0.0)
  }
  let _ = self.place_comp(ab, "rect", "pc_canvas", x=520.0, y=88.0)
  self.resize_node(ab, "pc_canvas", 560.0, 684.0, 0.0)
  self.w_style(ab, "pc_canvas", [("fill", "#FFFFFF")])
  // 画布内放一个居中手机画板缩略示意
  let _ = self.place_comp(ab, "rect", "pc_phone", x=640.0, y=150.0)
  self.resize_node(ab, "pc_phone", 180.0, 380.0, 16.0)
  self.w_style(ab, "pc_phone", [("fill", "#EDF0FE"), ("stroke", "#4B6BFB")])
  let _ = self.place_comp(ab, "rect", "pc_phone_hdr", x=656.0, y=174.0)
  self.resize_node(ab, "pc_phone_hdr", 148.0, 28.0, 6.0)
  self.w_style(ab, "pc_phone_hdr", [("fill", "#4B6BFB")])
  let _ = self.place_comp(ab, "rect", "pc_phone_btn", x=672.0, y=452.0)
  self.resize_node(ab, "pc_phone_btn", 116.0, 36.0, 18.0)
  self.w_style(ab, "pc_phone_btn", [("fill", "#4B6BFB")])
  let _ = self.place_comp(ab, "rect", "pc_props", x=1080.0, y=88.0)
  self.resize_node(ab, "pc_props", 200.0, 684.0, 0.0)
  self.w_style(ab, "pc_props", [("fill", "#F4F5F7")])
  let _ = self.place_comp(
    ab,
    "heading",
    "pc_ph",
    variant="h4",
    x=1096.0,
    y=108.0,
  )
  self.set_text(ab, "pc_ph", "Properties")
  self.resize_node(ab, "pc_ph", 150.0, 20.0, 0.0)
  let props = ["x: 96", "y: 150", "w: 560", "fill: none"]
  for i in 0..<4 {
    let id = "pc_pr" + i.to_string()
    let _ = self.place_comp(
      ab,
      "body_text",
      id,
      x=1096.0,
      y=144.0 + i.to_double() * 28.0,
    )
    self.set_text(ab, id, props[i])
    self.resize_node(ab, id, 160.0, 18.0, 0.0)
  }

  // 状态栏
  let _ = self.place_comp(ab, "rect", "pc_status", x=240.0, y=772.0)
  self.resize_node(ab, "pc_status", WIDE_W - 240.0, 28.0, 0.0)
  self.w_style(ab, "pc_status", [("fill", "#EDF0FE")])
  let _ = self.place_comp(
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
