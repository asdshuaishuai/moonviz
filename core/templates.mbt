///|
/// 页面模板库：Agent 说"做一个登录页"，引擎直接生成完整画板。
///
/// 每个模板是一个 (Project) → String 的函数：
/// 输入当前项目（共享令牌/组件），输出新画板 ID。
/// 模板内部使用设计令牌保证视觉一致性，组件间距遵循 Material 3 规范。
///
/// 这是"原型设计引擎"区别于"组件放置器"的关键：
/// 模板理解页面语义——登录页有什么、仪表盘有什么、设置页有什么。
pub(all) struct TemplateInfo {
  id : String
  name : String
  description : String
  category : String // "auth" | "dashboard" | "content" | "navigation"
  tags : Array[String]
  device : String // "mobile" | "web" | "pc"
}

///|
/// 可用模板清单（Agent 发现用）
pub fn list_templates() -> Array[TemplateInfo] {
  [
    {
      id: "login",
      name: "登录页",
      description: "Logo + 标题 + 邮箱 + 密码 + 登录按钮 + 注册链接",
      category: "auth",
      tags: ["form", "auth", "centered"],
      device: "mobile",
    },
    {
      id: "signup",
      name: "注册页",
      description: "标题 + 姓名 + 邮箱 + 密码 + 确认密码 + 注册按钮",
      category: "auth",
      tags: ["form", "auth"],
      device: "mobile",
    },
    {
      id: "dashboard",
      name: "仪表盘",
      description: "App Bar + 统计卡片×4 + 图表区域 + 最近活动列表",
      category: "dashboard",
      tags: ["data", "cards", "grid"],
      device: "mobile",
    },
    {
      id: "profile",
      name: "个人主页",
      description: "头像 + 姓名 + 简介 + 统计 + 操作按钮 + 内容列表",
      category: "content",
      tags: ["user", "avatar", "social"],
      device: "mobile",
    },
    {
      id: "settings",
      name: "设置页",
      description: "App Bar + 分组设置项（通知/隐私/关于）+ 退出按钮",
      category: "navigation",
      tags: ["list", "toggle", "grouped"],
      device: "mobile",
    },
    {
      id: "list",
      name: "列表页",
      description: "App Bar + 搜索栏 + 分类标签 + 条目列表（行底分割线）+ 底部导航",
      category: "content",
      tags: ["list", "search", "feed"],
      device: "mobile",
    },
    {
      id: "detail",
      name: "详情页",
      description: "返回栏 + 大图区 + 标题 + 规格参数 + 描述 + 底部主按钮",
      category: "content",
      tags: ["detail", "product", "hero"],
      device: "mobile",
    },
    {
      id: "checkout",
      name: "确认订单",
      description: "返回栏 + 订单摘要 + 表单字段 + 费用明细（行底分割线）+ 提交按钮",
      category: "commerce",
      tags: ["checkout", "order", "form"],
      device: "mobile",
    },
    {
      id: "list_detail",
      name: "聊天列表",
      description: "会话列表（头像 + 消息预览）+ 底部详情占位卡（IM 语义专用）",
      category: "content",
      tags: ["chat", "im", "master-detail"],
      device: "mobile",
    },
    {
      id: "onboarding",
      name: "引导页",
      description: "单页引导：插图占位 + 标题 + 描述 + 分页点 + 主/次操作",
      category: "navigation",
      tags: ["onboarding", "welcome"],
      device: "mobile",
    },
    {
      id: "empty_state",
      name: "空状态页",
      description: "插图占位 + 主文案 + 副文案 + 操作按钮",
      category: "content",
      tags: ["placeholder", "cta"],
      device: "mobile",
    },
    {
      id: "web_landing",
      name: "Web 落地页",
      description: "顶部导航 + Hero 双栏 + 三特性卡 + Footer（1280×800）",
      category: "navigation",
      tags: ["web", "hero", "marketing"],
      device: "web",
    },
    {
      id: "web_login",
      name: "Web 登录",
      description: "左品牌半屏 + 右居中表单卡（1280×800）",
      category: "auth",
      tags: ["web", "split", "brand"],
      device: "web",
    },
    {
      id: "web_dashboard",
      name: "Web 仪表盘",
      description: "侧边栏 + 顶栏 + 统计卡×4 + 柱状图 + 活动面板 + 数据表（1280×800）",
      category: "dashboard",
      tags: ["web", "sidebar", "charts"],
      device: "web",
    },
    {
      id: "pc_app",
      name: "PC 桌面应用",
      description: "标题栏 + 侧边栏 + 工具栏 + 图层/画布/属性三面板 + 状态栏（1280×800）",
      category: "navigation",
      tags: ["pc", "studio", "panels"],
      device: "pc",
    },
    {
      id: "adaptive_landing",
      name: "自适应落地页",
      description: "结构式模板：同一结构自动切换 手机/平板/桌面 布局（可指定宽度）",
      category: "navigation",
      tags: ["adaptive", "structural", "responsive"],
      device: "adaptive",
    },
    {
      id: "login_v2",
      name: "登录页 v2",
      description: "结构式登录：满宽卡(窄)/居中窄卡(宽)，阴影+现代排版",
      category: "auth",
      tags: ["adaptive", "structural"],
      device: "adaptive",
    },
  ]
}

///|
/// 模板清单 JSON
pub fn list_templates_json() -> String {
  let parts : Array[String] = []
  for t in list_templates().iter() {
    let tags : Array[String] = []
    for tag in t.tags.iter() {
      tags.push("\"\{tag}\"")
    }
    let tj = jstr9(tags)
    parts.push(
      "{\"id\":\"\{t.id}\",\"name\":\"\{t.name}\",\"description\":\"\{t.description}\",\"category\":\"\{t.category}\",\"device\":\"\{t.device}\",\"tags\":[\{tj}]}",
    )
  }
  let j = jstr9(parts)
  "[\{j}]"
}

///|
/// 实例化模板 → 完整画板。
/// width/height > 0 时覆盖模板默认尺寸（结构式模板按宽度选择结构分支）
pub fn Project::apply_template(
  self : Project,
  template_id~ : String,
  name? : String = "",
  width? : Double = 0.0,
  height? : Double = 0.0,
) -> Result[String, String] {
  let ab_name = if name == "" { template_id } else { name }
  let result = match template_id {
    "login" => Ok(self.template_login(ab_name))
    "signup" => Ok(self.template_signup(ab_name))
    "dashboard" => Ok(self.template_dashboard(ab_name))
    "profile" => Ok(self.template_profile(ab_name))
    "settings" => Ok(self.template_settings(ab_name))
    "list" => Ok(self.template_list(ab_name))
    "detail" => Ok(self.template_detail(ab_name))
    "checkout" => Ok(self.template_checkout(ab_name))
    "list_detail" => Ok(self.template_list_detail(ab_name))
    "onboarding" => Ok(self.template_onboarding(ab_name))
    "empty_state" => Ok(self.template_empty_state(ab_name))
    "web_landing" => Ok(self.template_web_landing(ab_name))
    "web_login" => Ok(self.template_web_login(ab_name))
    "web_dashboard" => Ok(self.template_web_dashboard(ab_name))
    "pc_app" => Ok(self.template_pc_app(ab_name))
    "adaptive_landing" => {
      let w = if width > 0.0 { width } else { 1280.0 }
      Ok(self.template_adaptive_landing(ab_name, w))
    }
    "login_v2" => {
      let w = if width > 0.0 { width } else { 390.0 }
      Ok(
        self.build_artboard(
          name=ab_name,
          width=w,
          height=if height > 0.0 { height } else { 844.0 },
          tree=login_tree(w, self.tokens),
        ),
      )
    }
    _ => Err("unknown_template: \{template_id}")
  }
  match result {
    Err(e) => Err(e)
    Ok(ab) => {
      // 模板规范化：被兄弟完全包含的节点收编为子节点（坐标转相对）。
      // 宽屏模板以平铺表达视觉嵌套（交通灯在标题栏上、文件项在侧栏内）。
      // 收编保证树结构与查询面正确；过门由几何修正+谓词豁免共同承担
      // （契约测试「14 模板 × AgentGate 零违规」锚定）。
      self.normalize_nesting(ab)
      Ok(ab)
    }
  }
}

// ---------------------------------------------------------------------------
// 登录页模板
// ---------------------------------------------------------------------------

///|
fn Project::template_login(self : Project, name : String) -> String {
  let ab = self.create_artboard(name~, width=390.0, height=844.0)
  let t = self.tokens

  // Logo 区域（圆形占位）
  let _ = self.place_comp(
    ab,
    "badge",
    "logo",
    variant="primary",
    x=163.0,
    y=120.0,
  )
  self.resize_node(ab, "logo", 64.0, 64.0, 999.0) // 圆形
  // 首字母字形：纯色空圆读作「图片没加载」（审计 web_login:brand_logo 同根）
  self.set_text(ab, "logo", "M")
  let _ = self.edit_node(
    artboard=ab,
    node_id="logo",
    kvs=[("font_size", "26"), ("weight", "600")],
  )

  // 标题
  let _ = self.place_comp(
    ab,
    "heading",
    "welcome_title",
    variant="h2",
    x=95.0,
    y=220.0,
  )
  self.set_text(ab, "welcome_title", "Welcome Back")
  self.resize_node(ab, "welcome_title", 200.0, 36.0, 0.0)
  // 标题/副标题与居中的 logo、按钮同轴：盒心已在画板中线，文字对齐 center
  // （文字比盒窄时左对齐会让视觉中心左偏，审计 login 四主题同现）
  let _ = self.edit_node(
    artboard=ab,
    node_id="welcome_title",
    kvs=[("align", "center"), ("weight", "700")],
  )

  // 副标题
  let _ = self.place_comp(
    ab,
    "body_text",
    "subtitle",
    variant="caption",
    x=95.0,
    y=258.0,
  )
  self.set_text(ab, "subtitle", "Sign in to continue")
  self.resize_node(ab, "subtitle", 200.0, 18.0, 0.0)
  let _ = self.edit_node(
    artboard=ab,
    node_id="subtitle",
    kvs=[("align", "center")],
  )

  // 邮箱输入框
  let _ = self.place_comp(
    ab,
    "text_input",
    "email_input",
    variant="filled",
    x=24.0,
    y=340.0,
  )
  self.set_text(ab, "email_input", "Email address")
  self.resize_node(ab, "email_input", 342.0, 52.0, 12.0)

  // 密码输入框
  let _ = self.place_comp(
    ab,
    "text_input",
    "password_input",
    variant="filled",
    x=24.0,
    y=404.0,
  )
  self.set_text(ab, "password_input", "Password")
  self.resize_node(ab, "password_input", 342.0, 52.0, 12.0)

  // 忘记密码链接（全宽盒 + 右对齐：右缘贴字段右缘，不再悬空 37px）
  let _ = self.place_comp(
    ab,
    "body_text",
    "forgot_link",
    variant="caption",
    x=24.0,
    y=468.0,
  )
  self.set_text(ab, "forgot_link", "Forgot password?")
  self.resize_node(ab, "forgot_link", 342.0, 18.0, 0.0)
  let _ = self.edit_node(
    artboard=ab,
    node_id="forgot_link",
    kvs=[("align", "right")],
  )

  // 登录按钮（主 CTA 文字 17/600，HIG 主按钮档；出厂 14/regular 太轻）
  let _ = self.place_comp(
    ab,
    "button",
    "login_btn",
    variant="primary",
    x=24.0,
    y=520.0,
  )
  self.set_text(ab, "login_btn", "Sign In")
  self.resize_node(ab, "login_btn", 342.0, 52.0, 12.0)
  let _ = self.edit_node(
    artboard=ab,
    node_id="login_btn",
    kvs=[("font_size", "17"), ("weight", "600")],
  )

  // 分隔线
  let _ = self.place_comp(ab, "divider", "divider1", x=24.0, y=600.0)
  self.resize_node(ab, "divider1", 342.0, 1.0, 0.0)

  // 注册按钮
  let _ = self.place_comp(
    ab,
    "button",
    "signup_btn",
    variant="secondary",
    x=24.0,
    y=630.0,
  )
  self.set_text(ab, "signup_btn", "Create Account")
  self.resize_node(ab, "signup_btn", 342.0, 52.0, 12.0)

  // 导航流：只在目标画板已经存在时写入，避免单页模板生成悬空引用。
  if self.artboards.contains("signup") {
    self.add_flow(from=ab, to="signup", trigger="tap:signup_btn")
  }
  if self.artboards.contains("forgot_password") {
    self.add_flow(from=ab, to="forgot_password", trigger="tap:forgot_link")
  }

  let _ = t
  ab
}

// ---------------------------------------------------------------------------
// 注册页模板
// ---------------------------------------------------------------------------

///|
fn Project::template_signup(self : Project, name : String) -> String {
  let ab = self.create_artboard(name~, width=390.0, height=844.0)

  let _ = self.place_comp(ab, "heading", "title", variant="h2", x=24.0, y=60.0)
  self.set_text(ab, "title", "Create Account")
  self.resize_node(ab, "title", 342.0, 36.0, 0.0)
  let _ = self.edit_node(
    artboard=ab,
    node_id="title",
    kvs=[("align", "center"), ("weight", "700")],
  )

  let fields = ["Full Name", "Email", "Password", "Confirm Password"]
  let mut y = 140.0
  for i in 0..<fields.length() {
    let fid = "field_\{i}"
    let _ = self.place_comp(ab, "text_input", fid, variant="filled", x=24.0, y~)
    self.set_text(ab, fid, fields[i])
    self.resize_node(ab, fid, 342.0, 52.0, 12.0)
    y = y + 68.0
  }

  let _ = self.place_comp(
    ab,
    "button",
    "create_btn",
    variant="primary",
    x=24.0,
    y=y + 20.0,
  )
  self.set_text(ab, "create_btn", "Sign Up")
  self.resize_node(ab, "create_btn", 342.0, 52.0, 12.0)
  let _ = self.edit_node(
    artboard=ab,
    node_id="create_btn",
    kvs=[("font_size", "17"), ("weight", "600")],
  )

  // 全宽盒 + 居中：与上方 Sign Up 按钮文字（text-anchor middle）同一中轴，
  // 不再靠手算文字宽把节点摆到「视觉中心偏左 8px」
  let _ = self.place_comp(
    ab,
    "body_text",
    "have_account",
    variant="caption",
    x=24.0,
    y=y + 90.0,
  )
  self.set_text(ab, "have_account", "Already have an account? Sign In")
  self.resize_node(ab, "have_account", 342.0, 18.0, 0.0)
  // 唯一导航出口用主色 + 半粗——整行 caption 灰读不出可点（审计 signup
  // 链接感残留；拆双节点会重新引入手算居中偏移，故整行链接待之）
  let _ = self.edit_node(
    artboard=ab,
    node_id="have_account",
    kvs=[
      ("align", "center"),
      ("text_color", self.tokens.resolve_color("primary")),
      ("weight", "600"),
    ],
  )

  // 导航流：只在目标画板已经存在时写入，避免单页模板生成悬空引用。
  if self.artboards.contains("login") {
    self.add_flow(from=ab, to="login", trigger="tap:have_account")
  }
  ab
}

// ---------------------------------------------------------------------------
// 仪表盘模板
// ---------------------------------------------------------------------------

///|
fn Project::template_dashboard(self : Project, name : String) -> String {
  let ab = self.create_artboard(name~, width=390.0, height=844.0)

  // App Bar（标题提到页级：17/600，不再比分区标题还小）
  let _ = self.place_comp(
    ab,
    "app_bar",
    "top_bar",
    variant="primary",
    x=0.0,
    y=0.0,
  )
  self.resize_node(ab, "top_bar", 390.0, 56.0, 0.0)
  self.set_text(ab, "top_bar", "Dashboard")
  // 标题居中：与 detail/checkout 同形态；左锚形状标签 pad 12 会让标题
  // 左缘与 24px 内容线错开 12px（审计残留）
  let _ = self.edit_node(
    artboard=ab,
    node_id="top_bar",
    kvs=[("font_size", "17"), ("weight", "600"), ("align", "center")],
  )

  // 统计卡片 2×2 网格：卡内「大数值 + 小标签」两级层级（数值 h3 20px，
  // 标签 caption 12px），收编进栈卡后按栈序竖排；子节点宽取卡内容宽
  // （163-2×16=131）+ 文字 align center——交叉轴视觉居中，且不给
  // x_mode 留「先居中后收编」的错位空间。槽距统一 16。
  let stats = [
    ("Revenue", "$12.4K"),
    ("Users", "8,421"),
    ("Orders", "1,203"),
    ("Growth", "+18%"),
  ]
  let mut i = 0
  for row in 0..<2 {
    for col in 0..<2 {
      let cid = "stat_\{i}"
      let x = 24.0 + col.to_double() * 179.0
      let y = 80.0 + row.to_double() * 112.0
      let _ = self.place_comp(ab, "card", cid, variant="elevated", x~, y~)
      self.resize_node(ab, cid, 163.0, 96.0, 12.0)
      // 数值（主层级）
      let vid = "stat_v\{i}"
      let _ = self.place_comp(
        ab,
        "heading",
        vid,
        variant="h3",
        x~,
        y=y + 20.0,
      )
      self.set_text(ab, vid, stats[i].1)
      self.resize_node(ab, vid, 131.0, 28.0, 0.0)
      let _ = self.edit_node(artboard=ab, node_id=vid, kvs=[("align", "center")])
      // 标签（次层级）
      let lid = "stat_l\{i}"
      let _ = self.place_comp(
        ab,
        "body_text",
        lid,
        variant="caption",
        x~,
        y=y + 52.0,
      )
      self.set_text(ab, lid, stats[i].0)
      self.resize_node(ab, lid, 131.0, 16.0, 0.0)
      let _ = self.edit_node(artboard=ab, node_id=lid, kvs=[("align", "center")])
      i = i + 1
    }
  }

  // 图表：白底面板（rect 组件——无栈布局，normalize 收编柱子后保持相对
  // 坐标不重排；栈卡 card 会把子节点竖排溢出）+ 标题 + 7 根圆角主色柱。
  // 面板实心覆盖整个图表区：不留可被合成导航按钮钻入的内容空洞。
  let _ = self.place_component(
    artboard=ab,
    component_id="rect",
    instance_id="chart_area",
    variant="default",
    x=24.0,
    y=310.0,
    w=342.0,
    h=200.0,
  )
  let _ = self.edit_node(
    artboard=ab,
    node_id="chart_area",
    kvs=[
      ("fill", self.tokens.resolve_color("surface")),
      ("radius", "12"),
      ("shadow", "e1"),
    ],
  )
  let _ = self.place_component(
    artboard=ab,
    component_id="body_text",
    instance_id="chart_title",
    variant="caption",
    // 左缘与统计卡/活动行文字同一参考线：面板 24 + 形状标签 pad 12 = 36
    x=36.0,
    y=326.0,
    w=200.0,
    h=16.0,
  )
  self.set_text(ab, "chart_title", "Weekly Revenue")
  let bars = [42.0, 58.0, 50.0, 74.0, 66.0, 92.0, 84.0]
  let days = ["M", "T", "W", "T", "F", "S", "S"]
  let bar_fill = self.tokens.resolve_color("primary")
  // 柱组左右留白对称：柱组 50..340，面板 24..366 → 各 26
  for b in 0..<7 {
    let bh = bars[b]
    let bx = 50.0 + b.to_double() * 44.0
    let _ = self.place_component(
      artboard=ab,
      component_id="rect",
      instance_id="bar_\{b}",
      variant="default",
      x=bx,
      y=486.0 - bh,
      w=26.0,
      h=bh,
    )
    let _ = self.edit_node(
      artboard=ab,
      node_id="bar_\{b}",
      kvs=[("fill", bar_fill), ("radius", "6")],
    )
  }
  // 基线 + 星期标签：让「Weekly Revenue」可读出数据节奏（审计图表信息缺失）
  let _ = self.place_component(
    artboard=ab,
    component_id="divider",
    instance_id="chart_baseline",
    x=50.0,
    y=487.0,
    w=290.0,
    h=1.0,
  )
  for b in 0..<7 {
    let did = "chart_day\{b}"
    let _ = self.place_component(
      artboard=ab,
      component_id="body_text",
      instance_id=did,
      variant="caption",
      x=50.0 + b.to_double() * 44.0,
      y=492.0,
      w=26.0,
      h=12.0,
    )
    self.set_text(ab, did, days[b])
    let _ = self.edit_node(artboard=ab, node_id=did, kvs=[("align", "center")])
  }

  // 最近活动列表
  let _ = self.place_comp(
    ab,
    "heading",
    "activity_title",
    variant="h4",
    x=24.0,
    y=540.0,
  )
  self.set_text(ab, "activity_title", "Recent Activity")
  self.resize_node(ab, "activity_title", 200.0, 24.0, 0.0)

  let activities = [
    "New order #1042",
    "User signup — alice@corp.dev",
    "Payment received",
    "Refund processed",
  ]
  for j in 0..<4 {
    let aid = "activity_\{j}"
    let _ = self.place_comp(
      ab,
      "card",
      aid,
      variant="elevated",
      x=24.0,
      y=576.0 + j.to_double() * 62.0,
    )
    self.resize_node(ab, aid, 342.0, 52.0, 8.0)
    self.set_text(ab, aid, activities[j])
  }

  // 底部不再放孤立 1px 分隔线（旧 bottom_div 像被截断的 Tab Bar，
  // 末行阴影直接压线）：底部留白即 Home 指示条安全区。

  ab
}

// ---------------------------------------------------------------------------
// 个人主页模板
// ---------------------------------------------------------------------------

///|
fn Project::template_profile(self : Project, name : String) -> String {
  let ab = self.create_artboard(name~, width=390.0, height=844.0)

  // App Bar（标题提到页级：17/600，不再是最小标题）
  let _ = self.place_comp(
    ab,
    "app_bar",
    "top_bar",
    variant="surface",
    x=0.0,
    y=0.0,
  )
  self.resize_node(ab, "top_bar", 390.0, 56.0, 0.0)
  self.set_text(ab, "top_bar", "Profile")
  let _ = self.edit_node(
    artboard=ab,
    node_id="top_bar",
    kvs=[("font_size", "17"), ("weight", "600"), ("align", "center")],
  )

  // 头像（圆形，首字母按直径档放大——出厂 14px 在 104 圆里显得空）
  let _ = self.place_comp(
    ab,
    "badge",
    "avatar",
    variant="primary",
    x=143.0,
    y=90.0,
  )
  self.resize_node(ab, "avatar", 104.0, 104.0, 999.0)
  self.set_text(ab, "avatar", "AB")
  let _ = self.edit_node(
    artboard=ab,
    node_id="avatar",
    kvs=[("font_size", "36"), ("weight", "600")],
  )

  // 姓名 + 简介（盒心在画板中线，文字对齐 center——与头像同轴，
  // 不再「名字落在头像左下方」）
  let _ = self.place_comp(
    ab,
    "heading",
    "user_name",
    variant="h3",
    x=95.0,
    y=214.0,
  )
  self.set_text(ab, "user_name", "Alice Baker")
  self.resize_node(ab, "user_name", 200.0, 28.0, 0.0)
  let _ = self.edit_node(
    artboard=ab,
    node_id="user_name",
    kvs=[("align", "center"), ("weight", "700")],
  )

  let _ = self.place_comp(
    ab,
    "body_text",
    "user_bio",
    variant="caption",
    x=95.0,
    y=246.0,
  )
  self.set_text(ab, "user_bio", "Product Designer @ TechCorp")
  self.resize_node(ab, "user_bio", 200.0, 18.0, 0.0)
  let _ = self.edit_node(
    artboard=ab,
    node_id="user_bio",
    kvs=[("align", "center")],
  )

  // 统计行：「大数值 + 小标签、居中」，卡片加宽对齐 24px 内容栏。
  // 子节点宽取卡内容宽（106-2×16=74）+ align center 交叉轴居中
  // （旧 90 宽卡放 "Followers: 4.2K" 单行溢出 19px，norms 未报）。
  let stats = [("Posts", "128"), ("Followers", "4.2K"), ("Following", "389")]
  for i in 0..<3 {
    let sid = "stat_\{i}"
    let x = 24.0 + i.to_double() * 118.0
    let _ = self.place_comp(ab, "card", sid, variant="elevated", x~, y=290.0)
    // 高 80：contained_in_parent 按卡内容盒（pad 16 内缩）判 contained——
    // 栈内容 22+8+14=44 必须 ≤ 80-32=48，64 高会底边越出内容盒
    self.resize_node(ab, sid, 106.0, 80.0, 8.0)
    let vid = "stat_v\{i}"
    let _ = self.place_comp(
      ab,
      "heading",
      vid,
      variant="h4",
      x~,
      y=302.0,
    )
    self.set_text(ab, vid, stats[i].1)
    self.resize_node(ab, vid, 74.0, 22.0, 0.0)
    let _ = self.edit_node(artboard=ab, node_id=vid, kvs=[("align", "center")])
    let lid = "stat_l\{i}"
    let _ = self.place_comp(
      ab,
      "body_text",
      lid,
      variant="caption",
      x~,
      y=326.0,
    )
    self.set_text(ab, lid, stats[i].0)
    self.resize_node(ab, lid, 74.0, 14.0, 0.0)
    let _ = self.edit_node(artboard=ab, node_id=lid, kvs=[("align", "center")])
  }

  // 操作按钮
  let _ = self.place_comp(
    ab,
    "button",
    "follow_btn",
    variant="primary",
    x=24.0,
    y=380.0,
  )
  self.set_text(ab, "follow_btn", "Follow")
  self.resize_node(ab, "follow_btn", 163.0, 44.0, 10.0)

  let _ = self.place_comp(
    ab,
    "button",
    "message_btn",
    variant="secondary",
    x=203.0,
    y=380.0,
  )
  self.set_text(ab, "message_btn", "Message")
  self.resize_node(ab, "message_btn", 163.0, 44.0, 10.0)

  // 内容列表
  let _ = self.place_comp(
    ab,
    "heading",
    "posts_title",
    variant="h4",
    x=24.0,
    y=450.0,
  )
  self.set_text(ab, "posts_title", "Posts")
  self.resize_node(ab, "posts_title", 100.0, 24.0, 0.0)

  for j in 0..<3 {
    let pid = "post_\{j}"
    let py = 486.0 + j.to_double() * 110.0
    let _ = self.place_comp(ab, "card", pid, variant="elevated", x=24.0, y=py)
    self.resize_node(ab, pid, 342.0, 96.0, 12.0)
    // 帖子卡两级内容：标题 h4 + 预览 caption（不再八成面积的空壳骨架）
    let tid = "post_t\{j}"
    let _ = self.place_comp(
      ab,
      "heading",
      tid,
      variant="h4",
      x=40.0,
      y=py + 20.0,
    )
    self.set_text(ab, tid, "Post \{j + 1}")
    self.resize_node(ab, tid, 200.0, 22.0, 0.0)
    let bid = "post_b\{j}"
    let _ = self.place_comp(
      ab,
      "body_text",
      bid,
      variant="body",
      x=40.0,
      y=py + 48.0,
    )
    self.set_text(ab, bid, "Short preview line for this post entry.")
    self.resize_node(ab, bid, 280.0, 20.0, 0.0)
  }

  ab
}

// ---------------------------------------------------------------------------
// 设置页模板
// ---------------------------------------------------------------------------

///|
fn Project::template_settings(self : Project, name : String) -> String {
  let ab = self.create_artboard(name~, width=390.0, height=844.0)

  let _ = self.place_comp(
    ab,
    "app_bar",
    "top_bar",
    variant="surface",
    x=0.0,
    y=0.0,
  )
  self.resize_node(ab, "top_bar", 390.0, 56.0, 0.0)
  self.set_text(ab, "top_bar", "Settings")
  // 页级标题提到 17/600 并居中（出厂 14/regular 比区块标题 h4 还小；
  // 左锚 pad 12 与 24px 内容线错开，审计残留）
  let _ = self.edit_node(
    artboard=ab,
    node_id="top_bar",
    kvs=[("font_size", "17"), ("weight", "600"), ("align", "center")],
  )

  let sections = [
    ("Notifications", ["Push Notifications", "Email Alerts", "SMS Updates"]),
    ("Privacy", ["Location Access", "Camera Permission", "Data Sharing"]),
    ("Appearance", ["Dark Mode", "Font Size", "Language"]),
    ("About", ["Version", "Terms of Service", "Privacy Policy"]),
  ]

  // 布局：4 组（标题 22 + 标题下间距 8 + 3 项 × 46 + 组距 10 = 176/组）
  // 从 72 起步共 704，退出按钮落在 782..826，严格包含在 844 画板内。
  // 标题与首行卡之间 8px、组与组之间 10px——分组从属关系靠留白可读。
  let mut y = 72.0
  for si in 0..<sections.length() {
    let (section_name, items) = sections[si]
    // 分组标题
    let hid = "section_\{si}"
    let _ = self.place_comp(ab, "heading", hid, variant="h4", x=24.0, y~)
    self.set_text(ab, hid, section_name)
    self.resize_node(ab, hid, 200.0, 22.0, 0.0)
    y = y + 30.0

    // 分组项：rect 行（绝对容器）+ 行尾 chevron——纯「卡+裸文案」读不出
    // 可操作性（审计 settings 尾部控件残留）；card 的竖向栈会把子节点
    // 叠到文案下方，故换 rect 保绝对定位
    for ii in 0..<items.length() {
      let iid = "item_\{si}_\{ii}"
      self.place_required(ab, "rect", iid, x=24.0, y~, w=342.0, h=40.0)
      let _ = self.edit_node(
        artboard=ab,
        node_id=iid,
        kvs=[
          ("fill", self.tokens.resolve_color("surface")),
          ("shadow", "e1"),
          ("radius", "8"),
          ("text_color", self.tokens.resolve_color("text_primary")),
        ],
      )
      self.set_text(ab, iid, items[ii])
      // About/Version 行尾显示真实版本值（ENGINE_VERSION 单一事实源），
      // 其余行尾 chevron 表可点——「Version ›」读不出任何版本信息（审计残留）
      let cid = "item_c\{si}_\{ii}"
      if si == 3 && ii == 0 {
        self.place_required(
          ab, "body_text", cid, x=244.0, y=y + 10.0, w=100.0, h=20.0,
        )
        self.set_text(ab, cid, "v" + ENGINE_VERSION)
        let _ = self.edit_node(
          artboard=ab,
          node_id=cid,
          kvs=[
            ("align", "right"),
            ("text_color", self.tokens.resolve_color("text_hint")),
          ],
        )
      } else {
        self.place_required(
          ab, "body_text", cid, x=336.0, y=y + 10.0, w=20.0, h=20.0,
        )
        self.set_text(ab, cid, "›")
        let _ = self.edit_node(
          artboard=ab,
          node_id=cid,
          kvs=[
            ("align", "center"),
            ("text_color", self.tokens.resolve_color("text_hint")),
          ],
        )
      }
      y = y + 46.0
    }
    y = y + 10.0 // 分组间距
  }

  // 退出按钮（圆角归按钮族 8 档，与同页列表卡同语言）
  let _ = self.place_comp(
    ab,
    "button",
    "logout_btn",
    variant="danger",
    x=24.0,
    y=y + 6.0,
  )
  self.set_text(ab, "logout_btn", "Log Out")
  self.resize_node(ab, "logout_btn", 342.0, 44.0, 8.0)

  ab
}

// ---------------------------------------------------------------------------
// 通用列表页（电商/内容/信息流等「一列条目」场景）
//
// 与 list_detail 的区别：后者是**聊天**模板（会话头像 + 消息预览 + 详情占位卡），
// 只适合 IM 语义。裸「列表」意图此前被它吞掉，产出的是聊天界面——这里补一个
// 真正的通用列表：搜索栏 + 分类横向标签 + 带分割线的条目列表。
// ---------------------------------------------------------------------------
fn Project::template_list(self : Project, name : String) -> String {
  let ab = self.create_artboard(name~, width=390.0, height=844.0)
  self.place_required(ab, "app_bar", "top_bar", x=0.0, y=0.0, w=390.0, h=56.0)
  self.set_text(ab, "top_bar", "Discover")

  // 搜索栏（锚在 app_bar 下方；autofill 的配方会认这个位置）
  // 高 44 触控下限（40 会被 lint 报 touch_target）
  self.place_required(ab, "search_bar", "search_bar", x=16.0, y=68.0, w=358.0, h=44.0)
  self.set_text(ab, "search_bar", "Search")

  // 分类横向标签（chip 档：高度按 NORM 的 chip 28）
  // chip 宽度必须**按规范预留**：norm 要求宽 ≥ 文案宽 + 24（左右各 12）。
  // 宽度用 text_intrinsic 估算（CJK 1.0 / ASCII 0.6 字号，与渲染/布局同一
  // 口径）——出厂即合规，不再靠 auto_fix 事后撑宽（旧 length*8 对
  // 「All」欠 1px、「Outdoor」欠 2px，critique norms 直接报 poor）。
  // 间距用 12：auto_fix 会把不达标的 chip 撑到合规宽度，如果排布时贴得太紧
  // （曾用 72 宽 + 80 间距），撑宽后就会与右侧邻居重叠，整页被
  // no_sibling_overlap 判债——生成完的页面再也不能接受任何新 flow。
  let cats = ["All", "Outdoor", "Camping", "Gear"]
  let mut cx = 16.0
  for ci in 0..<cats.length() {
    let cid = "cat_\{ci}"
    let label = cats[ci]
    let w = text_intrinsic(label, 14.0).width + 24.0
    self.place_required(ab, "chip", cid, x=cx, y=118.0, w~, h=28.0)
    self.set_text(ab, cid, label)
    cx = cx + w + 12.0
  }

  // 条目列表：卡片 + 行间分割线（≥3 行齐缝必须有 divider，norms 会查；
  // 末行之后不再追加孤立 divider——它后面没有内容，像渲染残留）
  let mut y = 162.0
  for i in 0..<5 {
    let rid = "item_\{i}"
    self.place_required(ab, "list_item", rid, x=16.0, y~, w=358.0, h=72.0)
    self.set_text(ab, rid, "Item \{i + 1} — short description of this entry")
    y = y + 72.0
    if i < 4 {
      let did = "divider_\{i}"
      self.place_required(ab, "divider", did, x=16.0, y~, w=358.0, h=1.0)
      y = y + 1.0
    }
  }

  // 底部导航（tab_bar 全宽直角；入口文字均分四槽、各自居中——
  // 单行左对齐字符串只占条宽左半，不合移动端 tab 均分惯例）
  // y=780 + 64 = 844 正好顶到画板下边界，contained_in_parent 要求严格包含，
  // 差 0 也会被拒——上移到 776 留 4px 余量（视觉上仍贴底）
  // y=779 + 64 = 843，距画板底 1px（contained_in_parent 要求严格包含，
  // 顶满 844 会被拒）——底缝从 4px 收到 1px，视觉上贴底
  self.place_required(ab, "tab_bar", "tab_bar", x=0.0, y=779.0, w=390.0, h=64.0)
  let tabs = ["Home", "Discover", "Cart", "Me"]
  for ti in 0..<tabs.length() {
    let tid = "tab_\{ti}"
    let slot = 390.0 / 4.0
    self.place_required(
      ab,
      "body_text",
      tid,
      x=ti.to_double() * slot,
      y=797.0,
      w=slot,
      h=24.0,
    )
    self.set_text(ab, tid, tabs[ti])
    let _ = self.edit_node(
      artboard=ab,
      node_id=tid,
      kvs=[("align", "center")],
    )
  }
  ab
}

// ---------------------------------------------------------------------------
// 通用详情页（商品/内容/条目详情）
//
// 结构：返回 + 标题栏 / 大图区 / 标题与价格 / 规格参数表 / 描述 / 底部主 CTA。
// 这条是「详情」意图的落点——此前这类意图被 list_detail 当聊天页处理。
// ---------------------------------------------------------------------------
fn Project::template_detail(self : Project, name : String) -> String {
  let ab = self.create_artboard(name~, width=390.0, height=844.0)
  // 顶栏：标题居中语义 + 独立返回钮（id/文案双命中引擎内置返回兜底，
  // 无需 flow；不再用「Back」独占顶栏、页面标题无处安放）
  self.place_required(ab, "app_bar", "top_bar", x=0.0, y=0.0, w=390.0, h=56.0)
  self.set_text(ab, "top_bar", "Product Detail")
  let _ = self.edit_node(
    artboard=ab,
    node_id="top_bar",
    kvs=[("font_size", "17"), ("weight", "600"), ("align", "center")],
  )
  self.place_required(ab, "button", "back_btn", variant="secondary", x=8.0, y=10.0)
  self.resize_node(ab, "back_btn", 64.0, 36.0, 8.0)
  self.set_text(ab, "back_btn", "‹ Back")
  // 大图区（占位 rect，Agent 可换成 image / 改 fill）：品牌容器色 tint——
  // surface_variant 压画布仅 1.03~1.05，无符号时 260px 视觉区像一片空白
  self.place_required(ab, "rect", "hero", x=0.0, y=56.0)
  self.resize_node(ab, "hero", 390.0, 260.0, 0.0)
  let _ = self.edit_node(
    artboard=ab,
    node_id="hero",
    kvs=[("fill", self.tokens.resolve_color("primary_container"))],
  )

  // 标题 + 副标题
  self.place_required(ab, "heading", "title", x=24.0, y=332.0)
  self.resize_node(ab, "title", 342.0, 32.0, 0.0)
  self.set_text(ab, "title", "Product Name")
  let _ = self.edit_node(artboard=ab, node_id="title", kvs=[("weight", "700")])
  self.place_required(ab, "body_text", "subtitle", x=24.0, y=370.0)
  self.resize_node(ab, "subtitle", 342.0, 20.0, 0.0)
  self.set_text(ab, "subtitle", "Short supporting line")

  // 规格参数：键、值拆成两个节点，值右对齐到 366 右缘——不再靠 4 个空格
  // 拼「键    值」（SVG 折叠空白后键值糊成一串）；行盒垂直居中由渲染层
  // 统一处理（文字不再顶在行首、分割线像上划线）
  let specs = [("Spec", "Value"), ("Size", "Standard"), ("Stock", "Available")]
  let mut y = 402.0
  for i in 0..<specs.length() {
    let (k, v) = specs[i]
    let sid = "spec_k\{i}"
    self.place_required(ab, "body_text", sid, x=24.0, y~, w=170.0, h=36.0)
    self.set_text(ab, sid, k)
    let vid = "spec_v\{i}"
    self.place_required(ab, "body_text", vid, x=194.0, y~, w=172.0, h=36.0)
    self.set_text(ab, vid, v)
    let _ = self.edit_node(artboard=ab, node_id=vid, kvs=[("align", "right")])
    y = y + 36.0
    let did = "divider_\{i}"
    self.place_required(ab, "divider", did, x=24.0, y~)
    self.resize_node(ab, did, 342.0, 1.0, 0.0)
    y = y + 1.0
  }

  // 描述段（渲染层按盒宽折行，不再单行溢出画板被裁切）
  self.place_required(ab, "body_text", "desc", x=24.0, y=y + 16.0)
  self.resize_node(ab, "desc", 342.0, 60.0, 0.0)
  self.set_text(
    ab,
    "desc",
    "A short paragraph describing this item in two or three lines of real copy.",
  )

  // 底部主 CTA（全宽，避开 iPhone 底部安全区；主 CTA 文字 17/600）
  self.place_required(ab, "button", "primary_btn", x=24.0, y=760.0, w=342.0, h=52.0)
  self.set_text(ab, "primary_btn", "Continue")
  let _ = self.edit_node(
    artboard=ab,
    node_id="primary_btn",
    kvs=[("font_size", "17"), ("weight", "600")],
  )
  ab
}

// ---------------------------------------------------------------------------
// 结算/确认订单页（电商下单流程的收口页）
//
// 语义：用户已选好商品，正在确认信息并提交。结构与详情页的区别在于
// 「摘要 + 表单字段 + 费用明细 + 提交」而不是「大图 + 描述」。
// ---------------------------------------------------------------------------
fn Project::template_checkout(self : Project, name : String) -> String {
  let ab = self.create_artboard(name~, width=390.0, height=844.0)
  // 顶栏：标题 + 独立返回钮（与详情页同一形态，页面语义不再是纯「Back」）
  self.place_required(ab, "app_bar", "top_bar", x=0.0, y=0.0, w=390.0, h=56.0)
  self.set_text(ab, "top_bar", "Confirm Order")
  let _ = self.edit_node(
    artboard=ab,
    node_id="top_bar",
    kvs=[("font_size", "17"), ("weight", "600"), ("align", "center")],
  )
  self.place_required(ab, "button", "back_btn", variant="secondary", x=8.0, y=10.0)
  self.resize_node(ab, "back_btn", 64.0, 36.0, 8.0)
  self.set_text(ab, "back_btn", "‹ Back")

  // 内容列统一 24px 边距（旧卡/字段 16、按钮 24 两档边线参差）
  // 订单摘要卡（两级内容：标题 + 条目说明，不再一行空壳）
  self.place_required(ab, "card", "summary", x=24.0, y=72.0)
  self.resize_node(ab, "summary", 342.0, 96.0, 12.0)
  self.set_text(ab, "summary", "")
  let _ = self.place_comp(
    ab,
    "heading",
    "summary_t",
    variant="h4",
    x=40.0,
    y=90.0,
  )
  self.set_text(ab, "summary_t", "Order summary")
  self.resize_node(ab, "summary_t", 200.0, 22.0, 0.0)
  let _ = self.place_comp(
    ab,
    "body_text",
    "summary_b",
    variant="caption",
    x=40.0,
    y=118.0,
  )
  self.set_text(ab, "summary_b", "2 items")
  self.resize_node(ab, "summary_b", 200.0, 16.0, 0.0)

  // 表单字段（确认订单的真实形态：联系人/时间/地点）；
  // time/place 是选择器字段，行尾 chevron 表达可点（审计 checkout 选择器指示残留）
  let fields = [
    ("field_contact", "Contact"),
    ("field_time", "Pickup time"),
    ("field_place", "Pickup location"),
  ]
  let mut y = 184.0
  for f in fields {
    let (fid, label) = f
    self.place_required(ab, "text_input", fid, x=24.0, y~)
    self.resize_node(ab, fid, 342.0, 52.0, 12.0)
    self.set_text(ab, fid, label)
    if fid != "field_contact" {
      let cid = fid + "_c"
      self.place_required(
        ab,
        "body_text",
        cid,
        x=336.0,
        y=y + 16.0,
        w=20.0,
        h=20.0,
      )
      self.set_text(ab, cid, "›")
      let _ = self.edit_node(
        artboard=ab,
        node_id=cid,
        kvs=[
          ("align", "center"),
          ("text_color", self.tokens.resolve_color("text_hint")),
        ],
      )
    }
    y = y + 60.0
  }

  // 费用明细：键、值拆两节点，值右对齐；Total 行加粗主色——应付合计
  // 不再与小计同灰同重（一眼扫不到要付多少）。行盒垂直居中由渲染层统一。
  let rows = [("Subtotal", "¥ 320"), ("Deposit", "¥ 200"), ("Total", "¥ 520")]
  y = y + 8.0
  for i in 0..<rows.length() {
    let (k, v) = rows[i]
    let is_total = i == rows.length() - 1
    let kid = "fee_k\{i}"
    self.place_required(ab, "body_text", kid, x=24.0, y~, w=170.0, h=40.0)
    self.set_text(ab, kid, k)
    let vid = "fee_v\{i}"
    self.place_required(ab, "body_text", vid, x=194.0, y~, w=172.0, h=40.0)
    self.set_text(ab, vid, v)
    let _ = self.edit_node(artboard=ab, node_id=vid, kvs=[("align", "right")])
    if is_total {
      let _ = self.edit_node(
        artboard=ab,
        node_id=kid,
        kvs=[("weight", "700"), ("font_size", "16")],
      )
      let _ = self.edit_node(
        artboard=ab,
        node_id=vid,
        kvs=[
          ("weight", "700"),
          ("font_size", "16"),
          ("text_color", self.tokens.resolve_color("primary")),
        ],
      )
    }
    y = y + 40.0
    if i < rows.length() - 1 {
      let did = "fee_div_\{i}"
      self.place_required(ab, "divider", did, x=24.0, y~)
      self.resize_node(ab, did, 342.0, 1.0, 0.0)
      y = y + 1.0
    }
  }

  // 提交按钮（主 CTA 文字 17/600）
  self.place_required(ab, "button", "submit_btn", x=24.0, y=752.0, w=342.0, h=52.0)
  self.set_text(ab, "submit_btn", "Place Order")
  let _ = self.edit_node(
    artboard=ab,
    node_id="submit_btn",
    kvs=[("font_size", "17"), ("weight", "600")],
  )
  ab
}

// ---------------------------------------------------------------------------
// 列表-详情模板（微信/IM 类社交应用的核心结构）
// ---------------------------------------------------------------------------

///|
fn Project::template_list_detail(self : Project, name : String) -> String {
  let ab = self.create_artboard(name~, width=390.0, height=844.0)
  let _ = self.place_comp(
    ab,
    "app_bar",
    "top_bar",
    variant="surface",
    x=0.0,
    y=0.0,
  )
  self.resize_node(ab, "top_bar", 390.0, 56.0, 0.0)
  self.set_text(ab, "top_bar", "Chats")
  let _ = self.edit_node(
    artboard=ab,
    node_id="top_bar",
    kvs=[("font_size", "17"), ("weight", "600")],
  )
  // 会话列表：list_item 行 + 头像（首字母）+ 两行内容（姓名 / 消息预览）
  // ——兑现「聊天模板」的语义，不再是一行 "Alice — See you tomorrow!"
  // 连排单行文字卡；行间 1px divider（齐缝列表 norms）
  let chats = [
    ("Alice", "See you tomorrow!"),
    ("Bob", "The prototype looks great"),
    ("Carol", "Design sync at 3pm"),
    ("Dave", "Sent the files over"),
    ("Eve", "Let me check and reply"),
  ]
  let mut y = 68.0
  for ci in 0..<chats.length() {
    let (who, msg) = chats[ci]
    self.place_required(ab, "list_item", "chat_\{ci}", x=12.0, y~, w=366.0, h=64.0)
    // 头像（list_item 无栈布局，子节点保持绝对定位；坐标为收编后相对值）
    self.place_required(
      ab,
      "badge",
      "chat_av\{ci}",
      variant="primary",
      x=24.0,
      y=y + 12.0,
    )
    self.resize_node(ab, "chat_av\{ci}", 40.0, 40.0, 999.0)
    self.set_text(ab, "chat_av\{ci}", who.substring(start=0, end=1))
    // 姓名 + 预览
    self.place_required(
      ab,
      "body_text",
      "chat_nm\{ci}",
      x=76.0,
      y=y + 12.0,
      w=280.0,
      h=20.0,
    )
    self.set_text(ab, "chat_nm\{ci}", who)
    let _ = self.edit_node(
      artboard=ab,
      node_id="chat_nm\{ci}",
      kvs=[("weight", "600")],
    )
    self.place_required(
      ab,
      "body_text",
      "chat_ms\{ci}",
      x=76.0,
      y=y + 36.0,
      w=280.0,
      h=16.0,
    )
    self.set_text(ab, "chat_ms\{ci}", msg)
    y = y + 64.0
    if ci < chats.length() - 1 {
      self.place_required(
        ab,
        "divider",
        "chat_div\{ci}",
        x=12.0,
        y~,
        w=366.0,
        h=1.0,
      )
      y = y + 1.0
    }
  }
  // 底部详情卡（占位内容区）
  let _ = self.place_comp(
    ab,
    "card",
    "detail_card",
    variant="elevated",
    x=12.0,
    y=y + 8.0,
  )
  self.resize_node(ab, "detail_card", 366.0, 120.0, 12.0)
  self.set_text(ab, "detail_card", "Select a chat to view details")
  ab
}

// ---------------------------------------------------------------------------
// 引导页模板（onboarding 轮播页）
// ---------------------------------------------------------------------------

///|
fn Project::template_onboarding(self : Project, name : String) -> String {
  let ab = self.create_artboard(name~, width=390.0, height=844.0)
  let _ = self.place_comp(
    ab,
    "heading",
    "ob_title",
    variant="h2",
    x=24.0,
    y=180.0,
  )
  self.set_text(ab, "ob_title", "Welcome aboard")
  self.resize_node(ab, "ob_title", 342.0, 40.0, 0.0)
  let _ = self.edit_node(
    artboard=ab,
    node_id="ob_title",
    kvs=[("align", "center"), ("weight", "700")],
  )
  let _ = self.place_comp(
    ab,
    "body_text",
    "ob_sub",
    variant="body",
    x=24.0,
    y=236.0,
  )
  self.set_text(
    ab, "ob_sub", "Design together with your agent — one plain-text source of truth for humans and AI.",
  )
  self.resize_node(ab, "ob_sub", 342.0, 72.0, 0.0)
  let _ = self.edit_node(artboard=ab, node_id="ob_sub", kvs=[("align", "center")])

  // 插图占位：目录写了插图但模板此前没有，画板中部约四成板面全空
  // （审计 onboarding:artboard 残留）——品牌容器色圆角块，亮暗都可辨
  self.place_required(ab, "rect", "ob_art", x=48.0, y=372.0, w=294.0, h=240.0)
  let _ = self.edit_node(
    artboard=ab,
    node_id="ob_art",
    kvs=[
      ("fill", self.tokens.resolve_color("primary_container")),
      ("stroke", self.tokens.resolve_color("outline")),
      ("radius", "24"),
    ],
  )

  let dot_inactive = self.tokens.resolve_color("surface_variant")
  for di in 0..<3 {
    let did = "ob_dot\{di}"
    if di == 0 {
      self.place_required(
        ab,
        "badge",
        did,
        variant="primary",
        x=171.0 + di.to_double() * 20.0,
        y=646.0,
      )
    } else {
      self.place_required(
        ab,
        "rect",
        did,
        x=171.0 + di.to_double() * 20.0,
        y=646.0,
      )
      let _ = self.edit_node(artboard=ab, node_id=did, kvs=[("fill", dot_inactive)])
    }
    self.resize_node(ab, did, 8.0, 8.0, 999.0)
  }

  // 主 CTA 文字 17/600；Skip 抬到 44 触控下限、圆角与主按钮同档 12，
  // 底边 820 落在安全区之上，两个出口不再一高一矮
  let _ = self.place_comp(
    ab,
    "button",
    "ob_next",
    variant="primary",
    x=24.0,
    y=720.0,
  )
  self.set_text(ab, "ob_next", "Get Started")
  self.resize_node(ab, "ob_next", 342.0, 48.0, 12.0)
  let _ = self.edit_node(
    artboard=ab,
    node_id="ob_next",
    kvs=[("font_size", "17"), ("weight", "600")],
  )
  let _ = self.place_comp(
    ab,
    "button",
    "ob_skip",
    variant="secondary",
    x=24.0,
    y=776.0,
  )
  self.set_text(ab, "ob_skip", "Skip")
  self.resize_node(ab, "ob_skip", 342.0, 44.0, 12.0)
  ab
}

// ---------------------------------------------------------------------------
// 空状态页模板
// ---------------------------------------------------------------------------

///|
fn Project::template_empty_state(self : Project, name : String) -> String {
  let ab = self.create_artboard(name~, width=390.0, height=844.0)

  // 插图占位（正圆盘，rx=高/2；阴影交给 card 组件的 e1 档）
  let _ = self.place_comp(
    ab,
    "card",
    "illustration",
    variant="elevated",
    x=95.0,
    y=250.0,
  )
  self.resize_node(ab, "illustration", 200.0, 200.0, 100.0)
  // 纯色空圆读作未填的头像位：放 ＋ 字形占位（水平垂直都居中——
  // start 锚曾让字形贴盘左缘偏 ~64px）
  self.set_text(ab, "illustration", "＋")
  let _ = self.edit_node(
    artboard=ab,
    node_id="illustration",
    kvs=[("font_size", "48"), ("align", "center")],
  )

  // 主文案（与插图/按钮同一中轴：盒心 195 + align center，
  // 不再两行文字各偏一条轴线）
  let _ = self.place_comp(
    ab,
    "heading",
    "main_text",
    variant="h3",
    x=95.0,
    y=480.0,
  )
  self.set_text(ab, "main_text", "No Items Yet")
  self.resize_node(ab, "main_text", 200.0, 28.0, 0.0)
  let _ = self.edit_node(
    artboard=ab,
    node_id="main_text",
    kvs=[("align", "center"), ("weight", "700")],
  )

  // 副文案
  let _ = self.place_comp(
    ab,
    "body_text",
    "sub_text",
    variant="body",
    x=75.0,
    y=516.0,
  )
  self.set_text(ab, "sub_text", "Items you add will appear here")
  self.resize_node(ab, "sub_text", 240.0, 20.0, 0.0)
  let _ = self.edit_node(artboard=ab, node_id="sub_text", kvs=[("align", "center")])

  // 操作按钮
  let _ = self.place_comp(
    ab,
    "button",
    "cta_btn",
    variant="primary",
    x=95.0,
    y=570.0,
  )
  self.set_text(ab, "cta_btn", "Add Item")
  self.resize_node(ab, "cta_btn", 200.0, 48.0, 12.0)

  ab
}

// ---------------------------------------------------------------------------
// 辅助方法
// ---------------------------------------------------------------------------

///|
fn Project::place_comp(
  self : Project,
  ab : String,
  comp : String,
  id : String,
  variant? : String = "",
  x? : Double = 0.0,
  y? : Double = 0.0,
) -> Result[String, String] {
  self.place_component(
    artboard=ab,
    component_id=comp,
    instance_id=id,
    variant~,
    x~,
    y~,
  )
}

///|
/// place_comp 的**强制版本**：放置失败即 panic。
///
/// 为什么需要它：模板里到处写 `let _ = self.place_comp(...)`，一旦组件名或
/// variant 写错（2026-10-26 真实事故：新模板用了不存在的 variant="surface"，
/// 5 个节点全被拒绝却静默通过），产出画板只剩少量节点却没有任何报错，
/// 直到用户看到"空页面"才发现。模板是确定性构造，失败必然是实现错误——
/// 让它在这里炸掉，而不是把半成品交出去。
fn Project::place_required(
  self : Project,
  ab : String,
  comp : String,
  id : String,
  variant? : String = "",
  x? : Double = 0.0,
  y? : Double = 0.0,
  w? : Double = 0.0,
  h? : Double = 0.0,
) -> Unit {
  // w/h 在**放置时**传入（不是放完再 resize）：门评估的是 place 那一刻的 bbox，
  // 组件默认尺寸往往大于目标槽位，先放后缩会让默认尺寸与邻居重叠而被拒
  // （2026-10-26 真实事故：新模板全部 place 失败，节点静默丢失）。
  match
    self.place_component(
      artboard=ab,
      component_id=comp,
      instance_id=id,
      variant~,
      x~,
      y~,
      w~,
      h~,
    ) {
    Ok(_) => ()
    Err(e) => abort("template_place_failed: \{comp} in \{ab}: \{e}")
  }
}

///|
fn Project::resize_node(
  self : Project,
  ab : String,
  id : String,
  w : Double,
  h : Double,
  radius : Double,
) -> Unit {
  match self.artboards.get(ab) {
    Some(art) => {
      let _ = art.doc.update_node(id, fn(n) {
        {
          ..n,
          width: Fixed(w),
          height: Fixed(h),
          style: { ..n.style, corner_radius: radius, },
        }
      })
    }
    None => ()
  }
}

///|
fn Project::set_text(
  self : Project,
  ab : String,
  id : String,
  text : String,
) -> Unit {
  match self.artboards.get(ab) {
    Some(art) => {
      let _ = art.doc.update_node(id, fn(n) { { ..n, text, } })
    }
    None => ()
  }
}

///|
fn jstr9(parts : Array[String]) -> String {
  let sb = StringBuilder::new()
  for i in 0..<parts.length() {
    if i > 0 {
      sb.write_string(",")
    }
    sb.write_string(parts[i])
  }
  sb.to_string()
}

///|
/// 模板结构规范化：把「被兄弟完全包含」的节点收编为该兄弟的子节点。
///
/// 设计意图：宽屏模板用平铺节点表达视觉嵌套（标题栏上的交通灯、侧栏里的
/// 文件项、卡片上的文字）。收编让树结构表达真实包含（#13 parent 读面、
/// ContainedInParent 检查都依赖它），坐标转为父相对、视觉不变。
/// 注：NoSiblingOverlap 自 5a5641a 起豁免「兄弟全包含」对，纯为过门而
/// 收编的必要性下降——但收编仍承载树语义与查询面，不可移除；
/// 模板债回归锚见 wasm/contract_test「14 模板 × AgentGate」。
///
/// 选择「最小的完全包含者」作为新父（最紧拟和）；仅收编 rect 严格被包含
/// 且包含者非纯装饰尺寸过小者（宽高 ≥ 包含节点）的节点。单趟扫描即可，
/// 模板层级至多两层嵌套。
pub fn Project::normalize_nesting(self : Project, artboard_id : String) -> Unit {
  let ab = match self.artboards.get(artboard_id) {
    Some(a) => a
    None => return
  }
  let doc = ab.doc
  let layout = solve(doc)
  // 收集 (child, new_parent) 决策；先全部决定再执行，避免中途改树影响判定
  let moves : Array[String] = [] // child_id
  let new_parents : Array[String] = [] // 与 moves 平行
  for pid in doc.nodes.keys() {
    let kids = match doc.nodes.get(pid) {
      Some(p) => p.children.copy()
      None => continue
    }
    if kids.length() < 2 {
      continue
    }
    // 每个孩子找「最小的完全包含它的兄弟」
    for k in kids.iter() {
      let rk = match layout.rect_of(k) {
        Some(r) => r
        None => continue
      }
      let mut best : String? = None
      let mut best_area = 1.0e18
      for other in kids.iter() {
        if other == k {
          continue
        }
        let ro = match layout.rect_of(other) {
          Some(r) => r
          None => continue
        }
        // 严格包含：other 的矩形完全覆盖 k
        if ro.x <= rk.x &&
          ro.y <= rk.y &&
          ro.x + ro.width >= rk.x + rk.width &&
          ro.y + ro.height >= rk.y + rk.height {
          let area = ro.width * ro.height
          if area < best_area && area > 0.0 {
            best_area = area
            best = Some(other)
          }
        }
      }
      match best {
        Some(b) => {
          moves.push(k)
          new_parents.push(b)
        }
        None => ()
      }
    }
  }
  // 执行收编：坐标转为新父相对
  for i = 0; i < moves.length(); i = i + 1 {
    let child_id = moves[i]
    let parent_id = new_parents[i]
    match doc.nodes.get(child_id) {
      None => continue
      Some(_) => ()
    }
    let old_parent = match doc.find_parent(child_id) {
      Some(p) => p
      None => continue
    }
    if old_parent == parent_id {
      continue
    }
    match doc.nodes.get(parent_id) {
      None => continue
      Some(_) => ()
    }
    // 跳过会成环的情况（parent 在 child 子树内）
    if in_subtree(doc, child_id, parent_id) {
      continue
    }
    let layout2 = solve(doc)
    let rc = match layout2.rect_of(child_id) {
      Some(r) => r
      None => continue
    }
    let rp = match layout2.rect_of(parent_id) {
      Some(r) => r
      None => continue
    }
    // 从旧父摘除
    let _ = doc.update_node(old_parent, fn(p) {
      { ..p, children: p.children.filter(c => c != child_id), }
    })
    // 相对坐标 + 挂到新父
    let nx = rc.x - rp.x
    let ny = rc.y - rp.y
    let _ = doc.update_node(child_id, fn(c) {
      { ..c, x: Fixed(nx), y: Fixed(ny), }
    })
    let _ = doc.update_node(parent_id, fn(p) {
      let cs = p.children.copy()
      cs.push(child_id)
      { ..p, children: cs, }
    })
  }
  if moves.length() > 0 {
    self.revision = self.revision + 1
  }
}

///|
/// id 是否在 root 的子树内（含 root 自身）
fn in_subtree(doc : Document, root : String, id : String) -> Bool {
  if root == id {
    return true
  }
  match doc.nodes.get(root) {
    None => false
    Some(n) => {
      let mut found = false
      for c in n.children.iter() {
        if in_subtree(doc, c, id) {
          found = true
          break
        }
      }
      found
    }
  }
}
