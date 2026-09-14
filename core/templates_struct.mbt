/// 结构式自适应模板（通用化的旗舰演示）：
///
/// 与 templates.mbt / templates_wide.mbt 的"手排坐标"不同——这里模板
/// 只声明结构（lt_v / lt_h / 嵌套），没有任何像素坐标。几何全部由
/// 布局求解器算出；同一函数在 1280 宽下生成横排 nav + 双栏 hero，
/// 在 390 宽下自动切换为汉堡 nav + 竖排 hero——这是结构级响应式，
/// 不是缩放级响应式。

///|
/// 画板默认高度（两种设备通用）
const STRUCT_H : Double = 800.0

///|
/// 落地页结构树：按宽度选择结构分支
fn landing_tree(width : Double) -> LT {
  let desktop = width >= 1024.0
  let tablet = width >= 700.0 && width < 1024.0
  if desktop {
    landing_desktop()
  } else if tablet {
    landing_tablet()
  } else {
    landing_mobile()
  }
}

///|
/// 桌面结构：横排导航 + 双栏 Hero + 三列卡 + 横排 Footer
fn landing_desktop() -> LT {
  lt_v(id="page", kids=[
    // 顶部导航
    lt_h(id="nav", pad=24.0, gap=16.0, kids=[
      lt_dot(id="nav_logo", fill="#4B6BFB", d=36.0),
      lt_text(id="nav_name", role="h4", s="MoonViz"),
      lt_flex(id="nav_sp"),
      lt_text(id="nav_i1", role="body", s="Product"),
      lt_text(id="nav_i2", role="body", s="Features"),
      lt_text(id="nav_i3", role="body", s="Pricing"),
      lt_text(id="nav_i4", role="body", s="Docs"),
      lt_btn(id="nav_cta", label="Get Started"),
    ]).h(Fixed(72.0)),
    // Hero：左文案右插图
    lt_h(id="hero", pad=48.0, gap=48.0, kids=[
      lt_v(id="hero_copy", gap=14.0, kids=[
        lt_text(
          id="hero_title",
          role="h1",
          s="Prototype at the speed of thought",
        ),
        lt_text(
          id="hero_sub",
          role="body",
          s="Human drags, agent commands — one plain-text source of truth.",
        ).color("#5A6270"),
        lt_h(id="hero_btns", gap=12.0, kids=[
          lt_btn(id="hero_b1", label="Start Free"),
          lt_btn(id="hero_b2", label="Watch Demo", variant="secondary"),
        ]).h(Fixed(44.0)),
      ]),
      lt_box(
        id="hero_art",
        fill="#EDF1FE",
        w=440.0,
        h=300.0,
        radius=20.0,
        shadow="e3",
        stroke="#D9E0F9",
      ),
    ]).h(Fixed(380.0)),
    // 三列特性卡（Fill 平分）
    lt_h(id="features", pad=48.0, gap=24.0, kids=[
      lt_card(id="feat_c0", gap=10.0, kids=[
        lt_dot(id="feat_d0", fill="#4B6BFB", d=44.0),
        lt_text(id="feat_t0", role="h3", s="Fast"),
        lt_text(
          id="feat_b0",
          role="body",
          s="Instant canvas with a deterministic solver.",
        ).color("#5A6270"),
      ]),
      lt_card(id="feat_c1", gap=10.0, kids=[
        lt_dot(id="feat_d1", fill="#7C5CFC", d=44.0),
        lt_text(id="feat_t1", role="h3", s="Smart"),
        lt_text(
          id="feat_b1",
          role="body",
          s="Critique, lint and auto-fix built in.",
        ).color("#5A6270"),
      ]),
      lt_card(id="feat_c2", gap=10.0, kids=[
        lt_dot(id="feat_d2", fill="#2FB98A", d=44.0),
        lt_text(id="feat_t2", role="h3", s="Open"),
        lt_text(
          id="feat_b2",
          role="body",
          s="Replayable op log as the document.",
        ).color("#5A6270"),
      ]),
    ]).h(Fixed(240.0)),
    // Footer
    lt_h(id="footer", pad=24.0, gap=16.0, kids=[
      lt_text(id="foot_l", role="caption", s="© 2026 MoonViz").color("#9AA1AB"),
      lt_flex(id="foot_sp"),
      lt_text(id="foot_r", role="caption", s="About   Privacy   Contact").color(
        "#9AA1AB",
      ),
    ])
    .h(Fixed(64.0))
    .color("#9AA1AB"),
  ])
}

///|
/// 平板结构：双栏 Hero 变竖排，两列卡
fn landing_tablet() -> LT {
  lt_v(id="page", kids=[
    lt_h(id="nav", pad=20.0, gap=12.0, kids=[
      lt_dot(id="nav_logo", fill="#4B6BFB", d=32.0),
      lt_text(id="nav_name", role="h4", s="MoonViz"),
      lt_flex(id="nav_sp"),
      lt_box(id="nav_burger", fill="#EEF0F4", w=40.0, h=40.0, radius=10.0),
    ]).h(Fixed(64.0)),
    lt_v(id="hero", pad=32.0, gap=20.0, kids=[
      lt_text(id="hero_title", role="h2", s="Prototype at the speed of thought"),
      lt_text(
        id="hero_sub",
        role="body",
        s="Human drags, agent commands — one plain-text source of truth.",
      ).color("#5A6270"),
      lt_h(id="hero_btns", gap=12.0, kids=[
        lt_btn(id="hero_b1", label="Start Free"),
        lt_btn(id="hero_b2", label="Watch Demo", variant="secondary"),
      ]).h(Fixed(44.0)),
      lt_box(
        id="hero_art",
        fill="#EDF1FE",
        w=600.0,
        h=240.0,
        radius=20.0,
        shadow="e2",
        stroke="#D9E0F9",
      ),
    ]).h(Fixed(420.0)),
    lt_h(id="features", pad=32.0, gap=20.0, kids=[
      lt_card(id="feat_c0", gap=8.0, kids=[
        lt_dot(id="feat_d0", fill="#4B6BFB", d=40.0),
        lt_text(id="feat_t0", role="h3", s="Fast"),
        lt_text(id="feat_b0", role="body", s="Instant canvas.").color("#5A6270"),
      ]),
      lt_card(id="feat_c1", gap=8.0, kids=[
        lt_dot(id="feat_d1", fill="#7C5CFC", d=40.0),
        lt_text(id="feat_t1", role="h3", s="Smart"),
        lt_text(id="feat_b1", role="body", s="Built-in critique.").color(
          "#5A6270",
        ),
      ]),
    ]).h(Fixed(220.0)),
    lt_h(id="footer", pad=20.0, kids=[
      lt_text(id="foot_l", role="caption", s="© 2026 MoonViz").color("#9AA1AB"),
      lt_flex(id="foot_sp"),
    ]).h(Fixed(60.0)),
  ])
}

///|
/// 手机结构：汉堡导航 + 竖排 Hero + 单列卡
fn landing_mobile() -> LT {
  lt_v(id="page", kids=[
    lt_h(id="nav", pad=16.0, gap=10.0, kids=[
      lt_dot(id="nav_logo", fill="#4B6BFB", d=30.0),
      lt_text(id="nav_name", role="h4", s="MoonViz"),
      lt_flex(id="nav_sp"),
      lt_box(id="nav_burger", fill="#EEF0F4", w=38.0, h=38.0, radius=10.0),
    ]).h(Fixed(56.0)),
    lt_v(id="hero", pad=24.0, gap=14.0, kids=[
      lt_text(
        id="hero_title",
        role="h2",
        s="Prototype at the\nspeed of thought",
      ),
      lt_text(id="hero_sub", role="body", s="Human drags, agent commands.").color(
        "#5A6270",
      ),
      lt_h(id="hero_btns", gap=10.0, kids=[
        lt_btn(id="hero_b1", label="Start Free"),
        lt_btn(id="hero_b2", label="Demo", variant="secondary"),
      ]).h(Fixed(44.0)),
      lt_box(
        id="hero_art",
        fill="#EDF1FE",
        w=340.0,
        h=200.0,
        radius=16.0,
        shadow="e2",
        stroke="#D9E0F9",
      ),
    ]).h(Fixed(440.0)),
    lt_v(id="features", pad=24.0, gap=14.0, kids=[
      lt_card(id="feat_c0", gap=6.0, kids=[
        lt_h(id="feat_r0", gap=10.0, kids=[
          lt_dot(id="feat_d0", fill="#4B6BFB", d=36.0),
          lt_text(id="feat_t0", role="h3", s="Fast"),
        ]).h(Fixed(36.0)),
        lt_text(
          id="feat_b0",
          role="body",
          s="Instant canvas with a deterministic solver.",
        ).color("#5A6270"),
      ]),
      lt_card(id="feat_c1", gap=6.0, kids=[
        lt_h(id="feat_r1", gap=10.0, kids=[
          lt_dot(id="feat_d1", fill="#7C5CFC", d=36.0),
          lt_text(id="feat_t1", role="h3", s="Smart"),
        ]).h(Fixed(36.0)),
        lt_text(
          id="feat_b1",
          role="body",
          s="Critique, lint and auto-fix built in.",
        ).color("#5A6270"),
      ]),
    ]).h(Fixed(260.0)),
    lt_h(id="footer", pad=16.0, kids=[
      lt_text(id="foot_l", role="caption", s="© 2026 MoonViz").color("#9AA1AB"),
      lt_flex(id="foot_sp"),
    ]).h(Fixed(56.0)),
  ])
}

///|
/// 自适应落地页：结构树 + 指定宽度（引擎按宽度选结构分支）
fn Project::template_adaptive_landing(
  self : Project,
  name : String,
  width : Double,
) -> String {
  let h = if width >= 1024.0 { 800.0 } else { 844.0 }
  self.build_artboard(name~, width~, height=h, tree=landing_tree(width))
}

///|
/// 结构式登录页：手机满宽卡 / 桌面居中窄卡（同一结构，宽度自适应）
fn login_tree(width : Double) -> LT {
  let desktop = width >= 900.0
  lt_v(id="page", pad=24.0, kids=[
    lt_flex(id="top_sp"),
    lt_card(id="login_card", gap=12.0, pad=28.0, kids=[
      lt_dot(id="logo", fill="#4B6BFB", d=56.0).cx(),
      lt_text(id="title", role="h2", s="Welcome back").cx(),
      lt_text(id="sub", role="body", s="Sign in to continue")
      .color("#5A6270")
      .cx(),
      lt_input(id="email", ph="Email address"),
      lt_input(id="pass", ph="Password"),
      lt_text(id="forgot", role="caption", s="Forgot password?").color(
        "#4B6BFB",
      ),
      lt_btn(id="login_btn", label="Sign In"),
      lt_text(id="signup", role="caption", s="No account? Create one")
      .color("#5A6270")
      .cx(),
    ])
    .w(if desktop { Fixed(420.0) } else { Fill })
    .h(Fixed(430.0)),
    lt_flex(id="bot_sp"),
  ])
}
