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
  // 组合意图（"登录+注册"）：多段走 multi 通道（多画板 + 相邻导航流）；
  // 单段路径保持字节级不变（兼容既有信封消费者）
  let segs = split_intent_segments(intent_text)
  if segs.length() > 1 {
    if segs.length() > GENERATE_MULTI_MAX {
      return Err("generate_multi_too_many:\{GENERATE_MULTI_MAX}")
    }
    return self.generate_multi(segs, name=name)
  }
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
  let summary = "生成" + intent.page_hint + "（" + json_int_field(score_json, "total", 0).to_string() + "分，自愈" + json_int_field(autofix_json, "fixes", 0).to_string() + "处，缺" + json_int_field(missing_json, "missing_count", 0).to_string() + "项）"
  let alts : Array[String] = []
  for a in intent.alternatives.iter() {
    alts.push("\"" + a + "\"")
  }
  let alts_j = alts.join(",")
  Ok(
    "{\"ok\":true,\"op\":\"generate\",\"artboard\":\"\{ab}\",\"template\":\"\{intent.template_id}\",\"width\":\{actual_w},\"height\":\{actual_h},\"replaced\":\{replaced},\"page_hint\":\"\{json_escape(intent.page_hint)}\",\"theme_applied\":\"\{theme_applied}\",\"alternatives\":[\{alts_j}],\"autofix\":\{autofix_json},\"missing\":\{missing_json},\"score\":\{score_json},\"summary\":\"\{json_escape(summary)}\",\"next\":\"autofill \{ab} 一键补缺 → critique 审阅 → ops 精修\"}",
  )
}

///|
/// 组合意图上限：一句话最多展开 4 块画板（防滥用；真实原型一屏意图
/// 极少超过 4 页）。
pub const GENERATE_MULTI_MAX : Int = 4

///|
/// 意图分段：按 "+" / "＋" 切分（保守分隔符——空格是单意图内的正常
/// 组成部分，"登录页 dark" 不受影响），去空白、丢空段。
pub fn split_intent_segments(text : String) -> Array[String] {
  let out : Array[String] = []
  let cur = StringBuilder::new()
  for c in text.iter() {
    if c == '+' || c == '＋' {
      let seg = mbt_seg_trim(cur.to_string())
      if seg != "" {
        out.push(seg)
      }
      cur.reset()
    } else {
      cur.write_char(c)
    }
  }
  let seg = mbt_seg_trim(cur.to_string())
  if seg != "" {
    out.push(seg)
  }
  out
}

///|
fn mbt_seg_trim(s : String) -> String {
  let ws : Array[Char] = [' ', '\t', '\n', '\r']
  let chars : Array[Char] = []
  for c in s.iter() {
    chars.push(c)
  }
  let mut start = 0
  let mut end = chars.length()
  while start < end {
    let c = chars[start]
    if ws.contains(c) {
      start = start + 1
    } else {
      break
    }
  }
  while end > start {
    let c = chars[end - 1]
    if ws.contains(c) {
      end = end - 1
    } else {
      break
    }
  }
  let sb = StringBuilder::new()
  for i in start..<end {
    sb.write_char(chars[i])
  }
  sb.to_string()
}

///|
/// 出口节点语义关键词：目标画板 hint 去尾 "页"（注册页→注册）。
fn egress_keyword(target_hint : String) -> String {
  if target_hint.length() >= 3 &&
    target_hint.substring(start=target_hint.length() - 3) == "页" {
    target_hint.substring(start=0, end=target_hint.length() - 3)
  } else {
    target_hint
  }
}

///|
/// 目标模板的惯用英文出口词（小写）。全部内置模板文案为英文（templates.mbt
/// 83 处 set_text 零 CJK），纯中文关键词对 text/name 做 contains 永远命不中
/// 现成出口——旗舰示例「登录+注册」会在 login 既有的 signup_btn（Create
/// Account）之下再凭空合成第二个注册 CTA。按目标模板给英文同义词，命中
/// 既有出口（节点 text 或 id 名）即就地连线不再合成。web_* 设备形态与其
/// 移动形态同词；无惯用出口的模板（empty_state/落地页）返回空表，退回中文
/// 关键词匹配。不收 "stats" 一类会撞 dashboard 自身 stat_N 节点名的泛词。
fn egress_template_keywords(template_id : String) -> Array[String] {
  if template_id == "signup" {
    ["signup", "sign up", "register"]
  } else if template_id == "login" || template_id == "web_login" {
    ["login", "sign in", "signin"]
  } else if template_id == "settings" {
    ["settings", "preferences"]
  } else if template_id == "dashboard" || template_id == "web_dashboard" {
    ["dashboard", "overview"]
  } else if template_id == "profile" {
    ["profile", "account"]
  } else if template_id == "list_detail" {
    ["list", "detail", "feed"]
  } else if template_id == "onboarding" {
    ["onboarding", "get started"]
  } else {
    []
  }
}

///|
/// 在 from 画板上找出口节点：text/name 含目标语义关键词（中文 hint 词 +
/// 目标模板惯用英文词）者就地连线；找不到则合成 "前往X" 按钮——放置经
/// 画布高度钳制（autofill 同款 `y + node_h > ab.height`），底缘放不下先
/// 自上而下找带区空位，仍无空位则放弃合成返回 ""（调用方跳过该相邻流）
/// ——流必须指向真实存在的节点（mbt_validate_flows 契约），而越界按钮是
/// auto_fix 清偿不动的债（fix_overflow 对负剩余空间保持原尺寸）。
fn Project::find_or_make_egress(
  self : Project,
  from_ab~ : String,
  target_hint~ : String,
  target_id~ : String,
  target_template~ : String,
) -> String {
  let kw = egress_keyword(target_hint)
  let kws : Array[String] = []
  if kw != "" {
    kws.push(kw.to_lower())
  }
  for en in egress_template_keywords(target_template).iter() {
    kws.push(en)
  }
  let ab = match self.artboards.get(from_ab) {
    Some(meta) => meta
    None => return "goto_" + target_id
  }
  let layout = solve(ab.doc)
  for id in ab.doc.nodes.keys() {
    if id == "root" {
      continue
    }
    match ab.doc.nodes.get(id) {
      Some(n) =>
        match layout.rect_of(id) {
          Some(_) => {
            let hay = (n.text + " " + n.name).to_lower()
            if kws.length() > 0 && contains_any(hay, kws) {
              return id
            }
          }
          None => ()
        }
      None => ()
    }
  }
  // 合成导航按钮：底缘之下放置；高内容模板（settings/dashboard 底缘已近
  // 满页）放不下时找带区空位，再放不下则放弃——宁可少一条流也不落出画布
  let node_w = 140.0
  let node_h = 44.0
  let mut bottom = 0.0
  for id in ab.doc.nodes.keys() {
    if id == "root" {
      continue
    }
    match layout.rect_of(id) {
      Some(r) => if r.y + r.height > bottom {
        bottom = r.y + r.height
      }
      None => ()
    }
  }
  let mut y = bottom + 16.0
  if y + node_h > ab.height {
    // 带区空位扫描：候选矩形与既有内容仅贴边不算相交（Rect::intersects）
    y = -1.0
    let mut cy = 8.0
    while y < 0.0 && cy + node_h <= ab.height {
      let cand = Rect::new(24.0, cy, node_w, node_h)
      let mut taken = false
      for id in ab.doc.nodes.keys() {
        if id == "root" {
          continue
        }
        match layout.rect_of(id) {
          Some(r) => if cand.intersects(r) {
            taken = true
          }
          None => ()
        }
      }
      if taken {
        cy = cy + 8.0
      } else {
        y = cy
      }
    }
    if y < 0.0 {
      return ""
    }
  }
  let node_id = "goto_" + target_id
  let _ = self.place_component(
    artboard=from_ab,
    component_id="button",
    instance_id=node_id,
    x=24.0,
    y~,
    w=node_w,
    h=node_h,
  )
  let _ = self.edit_node(
    artboard=from_ab,
    node_id=node_id,
    kvs=[("text", "前往" + kw)],
  )
  node_id
}

///|
/// 从 JSON 串取 `"key":` 之后的非负整数；键缺失或后随非数字时返回 fallback。
/// 仅供 multi 信封摘要解析（autofix fixes/remaining、missing_count、score）。
fn json_int_field(json : String, key : String, fallback : Int) -> Int {
  let pat = "\"" + key + "\":"
  match json.find(pat) {
    None => fallback
    Some(pos) => {
      let rest = json.substring(start=pos + pat.length())
      let mut j = 0
      let mut v = 0
      while j < rest.length() {
        match rest.get_char(j) {
          Some(c) =>
            if c >= '0' && c <= '9' {
              v = v * 10 + (c.to_int() - 48)
              j = j + 1
            } else {
              break
            }
          None => break
        }
      }
      if j == 0 {
        fallback
      } else {
        v
      }
    }
  }
}

///|
/// 导航流按 (from,to,trigger) 去重，保留首条。add_flow 无条件 push
/// （project.mbt 越界不可改），模板条件流又随画板 upsert 重建再次追加
/// ——generate_multi 幂等重跑的线性膨胀（实测 2→5→8）在此一次性收口。
fn Project::dedup_flows(self : Project) -> Unit {
  let seen : Map[String, Bool] = Map::new()
  let out : Array[FlowEdge] = []
  for f in self.flows.iter() {
    let key = "\{f.from}>\{f.to}@\{f.trigger}"
    if !seen.contains(key) {
      seen.set(key, true)
      out.push(f)
    }
  }
  if out.length() != self.flows.length() {
    self.flows = out
  }
}

///|
/// 组合意图生成：逐段分类 → 逐板实例化（纯主题段只换主题不生成板，
/// 同模板重名加序号）→ 相邻板自动连线（出口启发）→ 流去重 → 逐板自愈/
/// 评分。信封 mode=multi，逐板带 replaced（覆盖探测，与单通道同构）、
/// autofix（ok/fixes[/remaining] 摘要）、missing_count/score。
pub fn Project::generate_multi(
  self : Project,
  segments : Array[String],
  name? : String = "",
) -> Result[String, String] {
  // 1) 逐段分类；无页面语义的段视为主题修饰（dark 等）不生成板。
  //    页面段原文必须记账：退化单通道时拿页面段重拼——写死 segments[0]
  //    会把主题词在前的组合（"dark+登录"）退化成 "dark dark"，页面段
  //    被丢弃、静默落到空状态兜底板。
  let boards : Array[GenIntent] = []
  let page_segs : Array[String] = []
  let mut theme = ""
  for seg in segments.iter() {
    let gi = parse_generate_intent(seg)
    if gi.page_hint.contains("未识别") {
      if gi.theme != "" && theme == "" {
        theme = gi.theme
      }
      continue
    }
    if gi.theme != "" && theme == "" {
      theme = gi.theme
    }
    boards.push(gi)
    page_segs.push(seg)
  }
  if boards.length() == 0 {
    return Err("generate_multi_no_page_intent")
  }
  if boards.length() == 1 {
    // 退化为单段：走单通道保持信封形状兼容。页面段原文 + 被丢弃的
    // 主题修饰段关键词拼回意图，单通道重新解析即生效（顺序无关：
    // "dark+登录" 与 "登录+dark" 同得 login + dark 主题）
    let only = page_segs[0]
    let with_theme = if theme != "" { "\{only} \{theme}" } else { only }
    return self.generate(intent_text=with_theme, name=name)
  }
  // 2) 主题一次全局生效（先换主题再实例化，模板取色一致）
  let mut theme_applied = ""
  if theme != "" {
    match self.apply_theme(theme) {
      Ok(_) => theme_applied = theme
      Err(_) => theme_applied = ""
    }
  }
  // 3) 逐板实例化：同模板重名追加序号；name 参数归第一板。
  //    查重按 sanitize_id 归一口径：create_artboard 以 sanitize_id(name)
  //    为画板 id 做 Map upsert（大写转小写、非法字符转 _），未归一查重
  //    把 "Signup"/"signup" 当两个名，归一后同 id 的第二板静默覆盖第一板
  //    （信封仍报 count:2，相邻导航流成自环）。
  let ids : Array[String] = []
  let hints : Array[String] = []
  let replaced_flags : Array[Bool] = []
  let used_ids : Map[String, Bool] = Map::new()
  let mut first = true
  for gi in boards.iter() {
    let mut ab_name = if first && name != "" { name } else { gi.template_id }
    let mut ab_id = sanitize_id(ab_name)
    let mut n = 2
    while used_ids.contains(ab_id) {
      ab_name = "\{gi.template_id}_\{n}"
      ab_id = sanitize_id(ab_name)
      n = n + 1
    }
    used_ids.set(ab_id, true)
    // 覆盖探测与单通道同口径：重跑同组合意图经 upsert 静默覆盖旧
    // Document（连同其上的 tier-2 精修），信封逐板 replaced 可见。
    let replaced = self.artboards.contains(ab_id)
    let ab = match
      self.apply_template(
        template_id=gi.template_id,
        name=ab_name,
        width=gi.width,
        height=gi.height,
      ) {
      Err(error) => return Err(error)
      Ok(id) => id
    }
    ids.push(ab)
    hints.push(gi.page_hint)
    replaced_flags.push(replaced)
    first = false
  }
  // 4) 相邻板导航流：出口启发（就地找语义节点，找不到合成前往按钮；
  //    画布放不下放弃合成时跳过该流——流契约要求 trigger 指向真实节点）
  let flows_json : Array[String] = []
  let mut i = 0
  while i + 1 < ids.length() {
    let egress = self.find_or_make_egress(
      from_ab=ids[i],
      target_hint=hints[i + 1],
      target_id=ids[i + 1],
      target_template=boards[i + 1].template_id,
    )
    if egress != "" {
      self.add_flow(from=ids[i], to=ids[i + 1], trigger="tap:\{egress}")
      flows_json.push(
        "{\"from\":\"\{json_escape(ids[i])}\",\"to\":\"\{json_escape(ids[i + 1])}\",\"trigger\":\"tap:\{json_escape(egress)}\"}",
      )
    }
    i = i + 1
  }
  // 5) 流去重：模板条件流（templates.mbt 在目标板已存在时追加内建流，
  //    随 upsert 重建再次追加）与出口流每次重跑各追加一遍，而 add_flow
  //    无条件 push（project.mbt 越界不可改）——幂等重跑线性膨胀，在
  //    构造信封前按 (from,to,trigger) 保留首条一次性收口。
  self.dedup_flows()
  // 6) 逐板自愈 + 摘要（先逐板 auto_fix 清偿合成按钮引入的重叠）
  let arts : Array[String] = []
  let mut k = 0
  while k < ids.length() {
    // autofix 结果透传（不再 `let _ =` 丢弃）：逐板 ok/remaining 摘要
    // 进入信封——清偿不动时调用方可见，生成器不谎报合规。
    let autofix_json = match self.auto_fix(artboard=ids[k]) {
      Ok(j) => j
      Err(_) => "{\"ok\":false,\"remaining\":0,\"fixes\":0}"
    }
    let fixes_n = json_int_field(autofix_json, "fixes", 0)
    let autofix_summary = if autofix_json.contains("\"ok\":true") {
      "{\"ok\":true,\"fixes\":\{fixes_n}}"
    } else {
      "{\"ok\":false,\"remaining\":\{json_int_field(autofix_json, "remaining", 0)},\"fixes\":\{fixes_n}}"
    }
    let missing_json = match self.infer_missing(artboard=ids[k]) {
      Ok(j) => j
      Err(_) => "{\"missing_count\":0}"
    }
    let missing_count = json_int_field(missing_json, "missing_count", 0)
    let score_json = match self.design_quality_score(artboard=ids[k]) {
      Ok(j) => j
      Err(_) => "{}"
    }
    let sv = json_int_field(score_json, "total", -1)
    let score_total = if sv < 0 { "?" } else { sv.to_string() }
    arts.push(
      "{\"id\":\"\{json_escape(ids[k])}\",\"template\":\"\{json_escape(boards[k].template_id)}\",\"page_hint\":\"\{json_escape(hints[k])}\",\"replaced\":\{replaced_flags[k]},\"autofix\":\{autofix_summary},\"missing_count\":\{missing_count},\"score\":\{score_total}}",
    )
    k = k + 1
  }
  let arts_j = arts.join(",")
  let ms = "组合生成 " + ids.length().to_string() + " 板：" + ids.join(" → ")
  let flows_j = flows_json.join(",")
  Ok(
    "{\"ok\":true,\"op\":\"generate\",\"mode\":\"multi\",\"count\":\{ids.length()},\"summary\":\"\{json_escape(ms)}\",\"theme_applied\":\"\{theme_applied}\",\"artboards\":[\{arts_j}],\"flows\":[\{flows_j}],\"next\":\"逐画板 autofill/critique → ops 精修\"}",
  )
}
