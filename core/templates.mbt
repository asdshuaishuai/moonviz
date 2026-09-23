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
      id: "list_detail",
      name: "列表-详情",
      description: "列表页（卡片流）+ 详情页（大图 + 信息 + 操作）",
      category: "content",
      tags: ["master-detail", "cards"],
      device: "mobile",
    },
    {
      id: "onboarding",
      name: "引导页",
      description: "三页滑动引导：插图 + 标题 + 描述 + 跳过/下一步",
      category: "navigation",
      tags: ["wizard", "carousel"],
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
          tree=login_tree(w),
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

  // 忘记密码链接
  let _ = self.place_comp(
    ab,
    "body_text",
    "forgot_link",
    variant="caption",
    x=230.0,
    y=468.0,
  )
  self.set_text(ab, "forgot_link", "Forgot password?")
  self.resize_node(ab, "forgot_link", 140.0, 18.0, 0.0)

  // 登录按钮
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

  let _ = self.place_comp(
    ab,
    "body_text",
    "have_account",
    variant="caption",
    x=95.0,
    y=y + 90.0,
  )
  self.set_text(ab, "have_account", "Already have an account? Sign In")
  self.resize_node(ab, "have_account", 200.0, 18.0, 0.0)

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

  // App Bar
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

  // 统计卡片 2×2 网格
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
      let y = 80.0 + row.to_double() * 110.0
      let _ = self.place_comp(ab, "card", cid, variant="elevated", x~, y~)
      self.resize_node(ab, cid, 163.0, 96.0, 12.0)
      self.set_text(ab, cid, "\{stats[i].0}: \{stats[i].1}")
      i = i + 1
    }
  }

  // 图表区域
  let _ = self.place_comp(
    ab,
    "card",
    "chart_area",
    variant="elevated",
    x=24.0,
    y=310.0,
  )
  self.resize_node(ab, "chart_area", 342.0, 200.0, 12.0)
  self.set_text(ab, "chart_area", "Weekly Revenue")

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
    "New order #1042", "User signup: alice@", "Payment received", "Refund processed",
  ]
  for j in 0..<4 {
    let aid = "activity_\{j}"
    let _ = self.place_comp(
      ab,
      "card",
      aid,
      variant="outlined",
      x=24.0,
      y=576.0 + j.to_double() * 62.0,
    )
    self.resize_node(ab, aid, 342.0, 52.0, 8.0)
    self.set_text(ab, aid, activities[j])
  }

  // 底部导航
  let _ = self.place_comp(ab, "divider", "bottom_div", x=0.0, y=820.0)
  self.resize_node(ab, "bottom_div", 390.0, 1.0, 0.0)

  ab
}

// ---------------------------------------------------------------------------
// 个人主页模板
// ---------------------------------------------------------------------------

///|
fn Project::template_profile(self : Project, name : String) -> String {
  let ab = self.create_artboard(name~, width=390.0, height=844.0)

  // App Bar
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

  // 头像（圆形）
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

  // 姓名 + 简介
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

  // 统计行
  let stats = [("Posts", "128"), ("Followers", "4.2K"), ("Following", "389")]
  for i in 0..<3 {
    let sid = "stat_\{i}"
    let x = 44.0 + i.to_double() * 110.0
    let _ = self.place_comp(ab, "card", sid, variant="outlined", x~, y=290.0)
    self.resize_node(ab, sid, 90.0, 60.0, 8.0)
    self.set_text(ab, sid, "\{stats[i].0}: \{stats[i].1}")
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
    variant="outlined",
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
    let _ = self.place_comp(
      ab,
      "card",
      pid,
      variant="elevated",
      x=24.0,
      y=486.0 + j.to_double() * 110.0,
    )
    self.resize_node(ab, pid, 342.0, 96.0, 12.0)
    self.set_text(ab, pid, "Post \{j + 1}")
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

  let sections = [
    ("Notifications", ["Push Notifications", "Email Alerts", "SMS Updates"]),
    ("Privacy", ["Location Access", "Camera Permission", "Data Sharing"]),
    ("Appearance", ["Dark Mode", "Font Size", "Language"]),
    ("About", ["Version", "Terms of Service", "Privacy Policy"]),
  ]

  // 紧凑布局：4 组（标题 26 + 3 项 × 46 间距 + 组距 6 = 170/组）
  // 从 72 起步共 680，退出按钮落在 758..798，严格包含在 844 画板内。
  let mut y = 72.0
  for si in 0..<sections.length() {
    let (section_name, items) = sections[si]
    // 分组标题
    let hid = "section_\{si}"
    let _ = self.place_comp(ab, "heading", hid, variant="h4", x=24.0, y~)
    self.set_text(ab, hid, section_name)
    self.resize_node(ab, hid, 200.0, 22.0, 0.0)
    y = y + 26.0

    // 分组项
    for ii in 0..<items.length() {
      let iid = "item_\{si}_\{ii}"
      let _ = self.place_comp(ab, "card", iid, variant="outlined", x=24.0, y~)
      self.resize_node(ab, iid, 342.0, 40.0, 8.0)
      self.set_text(ab, iid, items[ii])
      y = y + 46.0
    }
    y = y + 6.0 // 分组间距
  }

  // 退出按钮
  let _ = self.place_comp(
    ab,
    "button",
    "logout_btn",
    variant="danger",
    x=24.0,
    y=y + 6.0,
  )
  self.set_text(ab, "logout_btn", "Log Out")
  self.resize_node(ab, "logout_btn", 342.0, 44.0, 10.0)

  ab
}


// ---------------------------------------------------------------------------
// 列表-详情模板（微信/IM 类社交应用的核心结构）
// ---------------------------------------------------------------------------
fn Project::template_list_detail(self : Project, name : String) -> String {
  let ab = self.create_artboard(name~, width=390.0, height=844.0)
  let _ = self.place_comp(ab, "app_bar", "top_bar", variant="surface", x=0.0, y=0.0)
  self.resize_node(ab, "top_bar", 390.0, 56.0, 0.0)
  self.set_text(ab, "top_bar", "Chats")
  // 会话列表（头像 + 标题 + 预览）
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
    let _ = self.place_comp(ab, "card", "chat_\{ci}", variant="default", x=12.0, y~)
    self.resize_node(ab, "chat_\{ci}", 366.0, 64.0, 10.0)
    self.set_text(ab, "chat_\{ci}", who + " — " + msg)
    y = y + 72.0
  }
  // 底部详情卡（占位内容区）
  let _ = self.place_comp(ab, "card", "detail_card", variant="outlined", x=12.0, y=y + 8.0)
  self.resize_node(ab, "detail_card", 366.0, 120.0, 12.0)
  self.set_text(ab, "detail_card", "Select a chat to view details")
  ab
}

// ---------------------------------------------------------------------------
// 引导页模板（onboarding 轮播页）
// ---------------------------------------------------------------------------
fn Project::template_onboarding(self : Project, name : String) -> String {
  let ab = self.create_artboard(name~, width=390.0, height=844.0)
  let _ = self.place_comp(ab, "heading", "ob_title", variant="h2", x=24.0, y=180.0)
  self.set_text(ab, "ob_title", "Welcome aboard")
  self.resize_node(ab, "ob_title", 342.0, 40.0, 0.0)
  let _ = self.place_comp(ab, "body_text", "ob_sub", variant="default", x=24.0, y=236.0)
  self.set_text(ab, "ob_sub", "Design together with your agent — one plain-text source of truth for humans and AI.")
  self.resize_node(ab, "ob_sub", 342.0, 72.0, 0.0)
  let _ = self.place_comp(ab, "button", "ob_next", variant="primary", x=24.0, y=720.0)
  self.set_text(ab, "ob_next", "Get Started")
  self.resize_node(ab, "ob_next", 342.0, 48.0, 12.0)
  let _ = self.place_comp(ab, "button", "ob_skip", variant="secondary", x=24.0, y=780.0)
  self.set_text(ab, "ob_skip", "Skip")
  self.resize_node(ab, "ob_skip", 342.0, 40.0, 8.0)
  ab
}

// ---------------------------------------------------------------------------
// 空状态页模板
// ---------------------------------------------------------------------------

///|
fn Project::template_empty_state(self : Project, name : String) -> String {
  let ab = self.create_artboard(name~, width=390.0, height=844.0)

  // 插图占位（大圆角矩形）
  let _ = self.place_comp(
    ab,
    "card",
    "illustration",
    variant="filled",
    x=95.0,
    y=250.0,
  )
  self.resize_node(ab, "illustration", 200.0, 200.0, 100.0)
  self.set_text(ab, "illustration", "")

  // 主文案
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
          style: { ..n.style, corner_radius: radius },
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
      { ..p, children: p.children.filter(c => c != child_id) }
    })
    // 相对坐标 + 挂到新父
    let nx = rc.x - rp.x
    let ny = rc.y - rp.y
    let _ = doc.update_node(child_id, fn(c) {
      { ..c, x: Fixed(nx), y: Fixed(ny) }
    })
    let _ = doc.update_node(parent_id, fn(p) {
      let cs = p.children.copy()
      cs.push(child_id)
      { ..p, children: cs }
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
