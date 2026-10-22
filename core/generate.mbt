// 生成式 UI：Agent 声明意图，引擎生成界面。
//
// 理念：Agent 的角色不是逐件工具调用摆放每个节点（纯工具调用 = 慢、贵、
// 易错，且把布局/规范决策压给模型），而是声明"要什么"——页面结构、组件
// 选择、间距规范、视觉一致性由引擎负责：
//   意图解析（本文件，确定性关键词分类，引擎无 LLM）
//   → 模板实例化（templates.mbt：模板理解页面语义）
//   → 规范自愈（auto_fix：norms/谓词一键还债）
//   → 差距报告（intelligence.mbt：缺失元素 + 质量评分）
// generate 是这条管线的一调用入口：一句话进，完整画板 + 报告信封出。
// Agent 拿着报告（missing/score）决定是否精修——从"画笔"退到"导演"。

///|
/// 意图解析结果（确定性：同输入恒同决策；歧义时给候选留一次精修线索）
pub(all) struct GenIntent {
  template_id : String
  artboard_name : String // 缺省 = template_id
  width : Double // 0 = 模板默认
  height : Double // 0 = 模板默认
  theme : String // "" = 不动主题；"dark" / 主题名
  page_hint : String // 识别出的页面语义（人读）
  alternatives : Array[String] // 同分候选 template id
}

///|
fn contains_any(haystack : String, needles : Array[String]) -> Bool {
  for kw in needles.iter() {
    if haystack.contains(kw) {
      return true
    }
  }
  false
}

///|
fn is_ascii_alnum(c : Char) -> Bool {
  let code = c.to_int()
  (code >= 48 && code <= 57) ||
  (code >= 65 && code <= 90) ||
  (code >= 97 && code <= 122)
}

///|
/// 短拉丁词（pc/web）按整词匹配：裸子串会把 "npc" 判成 pc、"webview"
/// 判成 web（实证："npc 仪表盘" 被强改为 pc_app+1280，整句页面语义被
/// 设备映射覆盖）。命中位置的前后邻字符不是字母/数字才算整词；中文
/// 关键词不受此影响，仍走 contains。
fn contains_latin_word(haystack : String, word : String) -> Bool {
  let n = haystack.length()
  let w = word.length()
  let mut i = 0
  while i + w <= n {
    if haystack.substring(start=i, end=i + w) == word {
      let before_ok = i == 0 ||
        {
          match haystack.get_char(i - 1) {
            Some(c) => !is_ascii_alnum(c)
            None => true
          }
        }
      let after_ok = i + w == n ||
        {
          match haystack.get_char(i + w) {
            Some(c) => !is_ascii_alnum(c)
            None => true
          }
        }
      if before_ok && after_ok {
        return true
      }
    }
    i = i + 1
  }
  false
}

///|
/// 意图 → 生成决策。中英关键词、设备暗示（web/平板/PC）与主题暗示
/// （dark/暗色 → dark）一次解析；页面语义按"具体优先"计分，平分时全部
/// 记入 alternatives（信封可见，Agent 可换 template 精修）。
pub fn parse_generate_intent(text : String) -> GenIntent {
  let lower = text.to_lower()
  // 设备暗示（pc/web 是 2-3 字母短词，按整词匹配防 "npc"/"webview" 误判）
  let is_web = contains_latin_word(lower, "web") ||
    contains_any(lower, [
      "网页", "落地页", "landing", "浏览器", "官网",
    ])
  let is_pc = contains_latin_word(lower, "pc") ||
    contains_any(lower, ["桌面应用", "desktop", "工作站"])
  let is_tablet = contains_any(lower, ["tablet", "平板", "ipad"])
  // 主题暗示
  let theme = if contains_any(lower, [
    "dark", "暗色", "深色", "夜间",
  ]) {
    "dark"
  } else if contains_any(lower, ["light", "亮色", "浅色"]) {
    "light"
  } else {
    ""
  }
  // 页面语义计分（关键词 → 候选模板）。顺序即稳定性：先具体后泛化。
  let candidates : Array[(String, String, Array[String])] = [
    (
      "signup",
      "注册页",
      ["signup", "sign up", "注册", "register", "创建账号"],
    ),
    ("onboarding", "引导页", ["onboarding", "引导", "欢迎页", "首次"]),
    ("empty_state", "空状态页", ["empty", "空状态", "无数据", "占位"]),
    ("settings", "设置页", ["settings", "设置", "偏好", "preferences"]),
    (
      "dashboard",
      "仪表盘",
      ["dashboard", "仪表盘", "大盘", "概览", "overview", "统计"],
    ),
    (
      "profile",
      "个人主页",
      ["profile", "个人主页", "个人中心", "资料", "我的"],
    ),
    (
      "list_detail",
      "列表详情",
      ["列表", "详情", "list", "detail", "feed", "信息流"],
    ),
    (
      "login",
      "登录页",
      ["login", "登录", "登陆", "sign in", "signin", "验证码", "手机号"],
    ),
    ("adaptive_landing", "响应式落地页", ["响应式", "adaptive"]),
    ("web_landing", "落地页", ["landing", "落地页", "官网", "marketing"]),
  ]
  let score_of = fn(keywords : Array[String]) -> Int {
    let mut score = 0
    for kw in keywords.iter() {
      if lower.contains(kw) {
        score = score + 1
      }
    }
    score
  }
  // 两遍扫描：先定 best，再收集等分者。一遍扫描的「顺手 push 等分」会
  // 在 best 被后续候选抬高后残留针对旧 best 构建的列表（含实际低分候选），
  // 误导 Agent 换模板精修。
  let mut best_id = ""
  let mut best_hint = ""
  let mut best_score = 0
  for cand in candidates.iter() {
    let (id, hint, keywords) = cand
    let score = score_of(keywords)
    if score > best_score {
      best_score = score
      best_id = id
      best_hint = hint
    }
  }
  let alternatives : Array[String] = []
  if best_score > 0 {
    for cand in candidates.iter() {
      let (id, _, keywords) = cand
      if id != best_id && score_of(keywords) == best_score {
        alternatives.push(id)
      }
    }
  }
  // 无命中：空状态兜底（最安全的生成物；信封标注低置信）
  if best_id == "" {
    best_id = "empty_state"
    best_hint = "未识别（空状态兜底）"
  }
  // 设备映射：web 暗示把 auth/dashboard 换成 web 形态；PC → pc_app
  let final_id = if is_pc {
    "pc_app"
  } else if is_web && best_id == "login" {
    "web_login"
  } else if is_web && best_id == "dashboard" {
    "web_dashboard"
  } else if is_web &&
    (best_id == "web_landing" || best_id == "adaptive_landing") {
    best_id
  } else {
    best_id
  }
  // 尺寸暗示：平板/PC 作为意图宽度传给模板。注意这只是意图——仅少数
  // 宽响应模板（adaptive_landing/login_v2）消费宽度，其余模板保留内建
  // 默认尺寸；画板实际尺寸以信封 width/height 为准（Agent 据此发现
  // 「平板 仪表盘」产出 390 宽画板这类与意图不符的结果）。
  let mut w = 0.0
  let mut h = 0.0
  if is_tablet {
    w = 768.0
    h = 1024.0
  } else if is_pc {
    w = 1280.0
    h = 800.0
  }
  {
    template_id: final_id,
    artboard_name: "",
    width: w,
    height: h,
    theme,
    page_hint: best_hint,
    alternatives,
  }
}

///|
/// 生成式入口：意图一句话 → 完整画板 + 报告信封。
/// 管线：模板实例化 → auto_fix（规范/谓词自愈，生成物即合规）→
/// infer_missing（还差什么）→ design_quality_score（质量分）。
/// name 缺省 = template_id；theme 非 "" 时对整个项目应用主题（生成前，
/// 重着色项目内所有画板）。画板名经 sanitize_id 归一后与既有画板同名
/// 时会静默覆盖旧 Document（连同其上的 tier-2 精修）——信封以
/// replaced:true 提示；width/height 暴露画板实际尺寸（模板可能不消费
/// 意图宽度，见 apply_template）。
pub fn Project::generate(
  self : Project,
  intent_text~ : String,
  name? : String = "",
) -> Result[String, String] {
  let intent = parse_generate_intent(intent_text)
  let ab_name = if name == "" { intent.template_id } else { name }
  // 覆盖探测：create_artboard 经 sanitize_id 归一后 upsert，重跑同意图
  // 必得同 id——先探测归一名，覆盖发生时信封可见（replaced:true）。
  let replaced = self.artboards.contains(sanitize_id(ab_name))
  // 主题先生效（模板用令牌取色——先换主题再实例化，视觉一致）
  let mut theme_applied = ""
  if intent.theme != "" {
    match self.apply_theme(intent.theme) {
      Ok(_) => theme_applied = intent.theme
      Err(_) => theme_applied = ""
    }
  }
  let ab = match
    self.apply_template(
      template_id=intent.template_id,
      name=ab_name,
      width=intent.width,
      height=intent.height,
    ) {
    Err(error) => return Err(error)
    Ok(id) => id
  }
  // 信封暴露实际宽高：模板可能不消费意图宽度（多数模板保留内建
  // 390×844），Agent 无从发现与意图不符，除非信封可见。
  let (actual_w, actual_h) = match self.artboards.get(ab) {
    Some(meta) => (meta.width, meta.height)
    None => (0.0, 0.0)
  }
  // 生成即合规：规范/谓词自愈（生成物不允许带着可见债交付）
  let autofix_json = match self.auto_fix(artboard=ab) {
    Ok(json) => json
    Err(_) => "{\"fixed\":0}"
  }
  let missing_json = match self.infer_missing(artboard=ab) {
    Ok(json) => json
    Err(_) => "{\"missing\":[]}"
  }
  let score_json = match self.design_quality_score(artboard=ab) {
    Ok(json) => json
    Err(_) => "{}"
  }
  let alts : Array[String] = []
  for a in intent.alternatives.iter() {
    alts.push("\"" + a + "\"")
  }
  let alts_j = alts.join(",")
  Ok(
    "{\"ok\":true,\"op\":\"generate\",\"artboard\":\"\{ab}\",\"template\":\"\{intent.template_id}\",\"width\":\{actual_w},\"height\":\{actual_h},\"replaced\":\{replaced},\"page_hint\":\"\{json_escape(intent.page_hint)}\",\"theme_applied\":\"\{theme_applied}\",\"alternatives\":[\{alts_j}],\"autofix\":\{autofix_json},\"missing\":\{missing_json},\"score\":\{score_json},\"next\":\"critique \{ab} 审阅 → ops 精修（engine 已自愈规范）\"}",
  )
}
