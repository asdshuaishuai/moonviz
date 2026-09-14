///|
/// 设计智能：引擎不仅执行设计——它理解设计。
///
/// - infer_page_type：从节点结构推断页面类型（login/dashboard/list...）
/// - infer_missing_elements：基于页面类型推断缺失的常见元素
/// - suggest_improvements：基于设计原则给出改进建议
/// - design_quality_score：综合评分（层次/一致性/密度/可访问性）
///
/// 这是"AI-native"的核心差异化：引擎有设计常识，能主动告诉 Agent
/// "你做的这个页面缺了什么"和"怎么做会更好"。

// ---------------------------------------------------------------------------
// 页面类型推断
// ---------------------------------------------------------------------------

pub(all) enum PageType {
  AuthPage // 登录/注册
  DashboardPage // 仪表盘
  ListPage // 列表页
  DetailPage // 详情页
  ProfilePage // 个人主页
  SettingsPage // 设置页
  FormPage // 表单页
  NavigationPage // 导航/引导
  EmptyStatePage // 空状态
  UnknownPage // 未识别
}

///|
pub fn PageType::name(self : PageType) -> String {
  match self {
    AuthPage => "auth"
    DashboardPage => "dashboard"
    ListPage => "list"
    DetailPage => "detail"
    ProfilePage => "profile"
    SettingsPage => "settings"
    FormPage => "form"
    NavigationPage => "navigation"
    EmptyStatePage => "empty_state"
    UnknownPage => "unknown"
  }
}

///|
/// 从画板节点结构推断页面类型
/// 信号：输入框数量 + 按钮文字 + 卡片密度 + 布局模式
pub fn Project::infer_page_type(
  self : Project,
  artboard~ : String,
) -> Result[String, String] {
  match self.artboards.get(artboard) {
    None => Err("unknown_artboard")
    Some(ab) => {
      let doc = ab.doc
      let mut input_count = 0
      let mut button_count = 0
      let mut card_count = 0
      let mut text_count = 0
      let mut all_text = ""
      for id in doc.nodes.keys() {
        match doc.nodes.get(id) {
          Some(n) => {
            match n.component {
              "text_input" => input_count = input_count + 1
              "button" => button_count = button_count + 1
              "card" => card_count = card_count + 1
              "heading" | "body_text" => text_count = text_count + 1
              _ => ()
            }
            all_text = all_text + " " + n.text + " " + n.name
          }
          None => ()
        }
      }
      let lower = all_text.to_lower()
      let has_avatar = lower.contains("avatar") || lower.contains("头像")
      let has_chart = lower.contains("chart") ||
        lower.contains("图表") ||
        card_count >= 4
      // 推断逻辑
      let page_type : String = if input_count >= 2 && button_count >= 1 {
        "auth"
      } else if card_count >= 4 && has_chart {
        "dashboard"
      } else if card_count >= 3 && text_count <= 2 {
        "list"
      } else if has_avatar && text_count >= 2 {
        "profile"
      } else if all_text.contains("Settings") || all_text.contains("设置") {
        "settings"
      } else if input_count >= 1 && button_count >= 1 {
        "form"
      } else if text_count >= 3 && card_count == 0 {
        if all_text.to_lower().contains("no ") ||
          all_text.to_lower().contains("empty") {
          "empty_state"
        } else {
          "navigation"
        }
      } else {
        "unknown"
      }
      let _ = has_avatar
      Ok(
        "{\"page_type\":\"\{page_type}\",\"signals\":{\"inputs\":\{input_count},\"buttons\":\{button_count},\"cards\":\{card_count},\"texts\":\{text_count}}}",
      )
    }
  }
}

// ---------------------------------------------------------------------------
// 缺失元素推断
// ---------------------------------------------------------------------------

///|
/// 基于页面类型推断常见缺失元素
/// Agent 得到"你的登录页还差一个忘记密码链接"这种建议
pub fn Project::infer_missing(
  self : Project,
  artboard~ : String,
) -> Result[String, String] {
  match self.infer_page_type(artboard~) {
    Err(e) => Err(e)
    Ok(type_json) => {
      let page_type = extract_field(type_json, "page_type")
      let doc = match self.artboards.get(artboard) {
        Some(ab) => ab.doc
        None => return Err("unknown_artboard")
      }
      // 收集所有文字
      let mut all_text = ""

      for id in doc.nodes.keys() {
        match doc.nodes.get(id) {
          Some(n) => all_text = all_text + " " + n.text + " " + n.name
          None => ()
        }
      }
      let lower = all_text.to_lower()
      let missing : Array[String] = []
      match page_type {
        "auth" => {
          if !lower.contains("forgot") && !lower.contains("忘记") {
            missing.push(
              "{\"type\":\"missing_link\",\"element\":\"forgot_password\",\"suggestion\":\"添加'忘记密码'链接，通常在密码输入框下方\"}",
            )
          }
          if !lower.contains("sign up") &&
            !lower.contains("create account") &&
            !lower.contains("注册") {
            missing.push(
              "{\"type\":\"missing_link\",\"element\":\"signup_link\",\"suggestion\":\"添加'创建账号'链接，通常在登录按钮下方\"}",
            )
          }
          if !lower.contains("remember") && !lower.contains("记住") {
            missing.push(
              "{\"type\":\"missing_checkbox\",\"element\":\"remember_me\",\"suggestion\":\"考虑添加'记住我'复选框\"}",
            )
          }
        }
        "dashboard" =>
          if !lower.contains("refresh") && !lower.contains("刷新") {
            missing.push(
              "{\"type\":\"missing_action\",\"element\":\"refresh\",\"suggestion\":\"考虑添加刷新/更新数据的操作\"}",
            )
          }
        "list" => {
          if !lower.contains("search") && !lower.contains("搜索") {
            missing.push(
              "{\"type\":\"missing_input\",\"element\":\"search_bar\",\"suggestion\":\"列表页通常需要搜索栏\"}",
            )
          }
          if !lower.contains("filter") && !lower.contains("筛选") {
            missing.push(
              "{\"type\":\"missing_action\",\"element\":\"filter\",\"suggestion\":\"考虑添加筛选/排序功能\"}",
            )
          }
        }
        "form" =>
          missing.push(
            "{\"type\":\"missing_validation\",\"element\":\"error_states\",\"suggestion\":\"表单页应为每个输入框添加错误提示状态\"}",
          )
        "profile" =>
          if !lower.contains("edit") && !lower.contains("编辑") {
            missing.push(
              "{\"type\":\"missing_action\",\"element\":\"edit_profile\",\"suggestion\":\"个人主页通常需要'编辑资料'入口\"}",
            )
          }
        "settings" =>
          if !lower.contains("logout") && !lower.contains("退出") {
            missing.push(
              "{\"type\":\"missing_action\",\"element\":\"logout\",\"suggestion\":\"设置页通常需要退出登录按钮\"}",
            )
          }
        _ => ()
      }
      // 通用检查
      if !lower.contains("loading") && !lower.contains("加载") {
        missing.push(
          "{\"type\":\"missing_state\",\"element\":\"loading_state\",\"suggestion\":\"考虑添加加载状态（骨架屏或旋转器）\"}",
        )
      }
      let j = jstr14(missing)
      Ok(
        "{\"page_type\":\"\{page_type}\",\"missing_count\":\{missing.length()},\"missing\":\{j}}",
      )
    }
  }
}

// ---------------------------------------------------------------------------
// 设计改进建议
// ---------------------------------------------------------------------------

///|
pub(all) struct DesignSuggestion {
  category : String // "hierarchy" | "spacing" | "alignment" | "contrast" | "consistency"
  severity : String // "high" | "medium" | "low"
  description : String
  fix_command : String // Agent 可以直接执行的建议命令
}

///|
/// 基于设计原则给出改进建议
pub fn Project::suggest_improvements(
  self : Project,
  artboard~ : String,
) -> Result[String, String] {
  match self.artboards.get(artboard) {
    None => Err("unknown_artboard")
    Some(ab) => {
      let suggestions : Array[String] = []
      let layout = solve(ab.doc)
      let tokens = self.tokens

      // 1. 层次检查：是否有清晰的视觉层次（至少 2 种字号）
      let font_sizes : Map[Double, Int] = Map::new()
      for id in ab.doc.nodes.keys() {
        match ab.doc.nodes.get(id) {
          Some(n) =>
            match font_sizes.get(n.style.font_size) {
              Some(c) => font_sizes.set(n.style.font_size, c + 1)
              None => font_sizes.set(n.style.font_size, 1)
            }
          None => ()
        }
      }
      if font_sizes.size() < 2 {
        suggestions.push(
          "{\"category\":\"hierarchy\",\"severity\":\"high\",\"description\":\"所有文字字号相同，缺少视觉层次\",\"fix_command\":\"为标题使用 heading h2，正文使用 body_text\"}",
        )
      }

      // 2. 间距一致性：检查子元素间距是否统一
      for id in ab.doc.nodes.keys() {
        match ab.doc.nodes.get(id) {
          Some(n) =>
            if n.children.length() > 2 {
              match n.layout {
                Some(l) => {
                  let is_std = l.gap == 4.0 ||
                    l.gap == 8.0 ||
                    l.gap == 12.0 ||
                    l.gap == 16.0 ||
                    l.gap == 24.0
                  if !is_std {
                    suggestions.push(
                      "{\"category\":\"consistency\",\"severity\":\"medium\",\"description\":\"间距 \{l.gap} 不是标准令牌值\",\"fix_command\":\"snap_to_grid(grid=8)\"}",
                    )
                  }
                }
                None => ()
              }
            }
          None => ()
        }
      }

      // 3. 颜色一致性：检查是否有非令牌的硬编码颜色
      for id in ab.doc.nodes.keys() {
        match ab.doc.nodes.get(id) {
          Some(n) =>
            if n.style.fill != "none" &&
              n.style.fill != "" &&
              !is_token_color(tokens, n.style.fill) {
              match find_nearest_token_color(tokens, n.style.fill) {
                Some((token_name, _hex)) =>
                  suggestions.push(
                    "{\"category\":\"consistency\",\"severity\":\"low\",\"description\":\"硬编码颜色接近令牌\",\"fix_command\":\"替换为令牌 \{token_name}\"}",
                  )
                None => ()
              }
            }
          None => ()
        }
      }

      // 4. 密度检查：元素是否过于密集或稀疏
      let node_count = ab.doc.nodes.size() - 1
      let area = ab.width * ab.height
      let density = node_count.to_double() / (area / 10000.0) // 节点/万px²
      if density > 8.0 {
        suggestions.push(
          "{\"category\":\"density\",\"severity\":\"medium\",\"description\":\"画板元素密度过高（\{density.to_string()} 节点/万px²），考虑分组或精简\",\"fix_command\":\"auto_arrange\"}",
        )
      } else if density < 0.5 && node_count > 3 {
        suggestions.push(
          "{\"category\":\"density\",\"severity\":\"low\",\"description\":\"画板元素较少，可能内容不够丰富\",\"fix_command\":\"infer_missing\"}",
        )
      }

      let j = jstr14(suggestions)
      Ok("{\"suggestions\":\{suggestions.length()},\"detail\":\{j}}")
    }
  }
}

// ---------------------------------------------------------------------------
// 设计质量综合评分
// ---------------------------------------------------------------------------

///|
pub fn Project::design_quality_score(
  self : Project,
  artboard~ : String,
) -> Result[String, String] {
  match self.artboards.get(artboard) {
    None => Err("unknown_artboard")
    Some(ab) => {
      let doc = ab.doc
      let layout = solve(doc)

      // 维度 1：层次分（字号种类越多越好，上限 5 种）
      let font_set : Map[Double, Bool] = Map::new()
      for id in doc.nodes.keys() {
        match doc.nodes.get(id) {
          Some(n) => font_set.set(n.style.font_size, true)
          None => ()
        }
      }
      let hierarchy_score = if font_set.size() >= 3 {
        25
      } else if font_set.size() == 2 {
        18
      } else {
        8
      }

      // 维度 2：一致性分（颜色是否使用令牌）
      let mut token_colors = 0
      let mut total_colors = 0
      for id in doc.nodes.keys() {
        match doc.nodes.get(id) {
          Some(n) =>
            if n.style.fill != "none" && n.style.fill != "" {
              total_colors = total_colors + 1
              if is_token_color(self.tokens, n.style.fill) {
                token_colors = token_colors + 1
              }
            }
          None => ()
        }
      }
      let consistency_score = if total_colors == 0 {
        15
      } else {
        token_colors * 25 / total_colors
      }

      // 维度 3：稳定性分（无违规 = 满分）
      let violations = validate(doc).length()
      let stability_score = if violations == 0 {
        25
      } else if violations <= 2 {
        15
      } else {
        5
      }

      // 维度 4：丰富度分（节点数量，考虑层次）
      let node_count = doc.nodes.size() - 1
      let richness_score = if node_count >= 10 {
        25
      } else if node_count >= 5 {
        18
      } else if node_count >= 3 {
        10
      } else {
        3
      }

      let total = hierarchy_score +
        consistency_score +
        stability_score +
        richness_score
      let grade = if total >= 85 {
        "A"
      } else if total >= 70 {
        "B"
      } else if total >= 50 {
        "C"
      } else {
        "D"
      }

      Ok(
        "{\"total\":\{total},\"grade\":\"\{grade}\",\"hierarchy\":\{hierarchy_score},\"consistency\":\{consistency_score},\"stability\":\{stability_score},\"richness\":\{richness_score},\"violations\":\{violations},\"nodes\":\{node_count}}",
      )
    }
  }
}

// ---------------------------------------------------------------------------
// 辅助函数
// ---------------------------------------------------------------------------

///|
fn is_token_color(tokens : DesignTokens, hex : String) -> Bool {
  for k in tokens.colors.keys() {
    match tokens.colors.get(k) {
      Some(v) => if v == hex { return true }
      None => ()
    }
  }
  false
}

///|
fn find_nearest_token_color(
  tokens : DesignTokens,
  hex : String,
) -> (String, String)? {
  let target = parse_hex_rgb(hex)
  let mut best : (String, String)? = None
  let mut best_dist = 999999.0
  for k in tokens.colors.keys() {
    match tokens.colors.get(k) {
      Some(v) => {
        let c = parse_hex_rgb(v)
        let dist = color_distance(target, c)
        if dist < best_dist {
          best_dist = dist
          best = Some((k, v))
        }
      }
      None => ()
    }
  }
  // 只有距离足够近才建议替换
  if best_dist < 50.0 {
    best
  } else {
    None
  }
}

///|
fn parse_hex_rgb(hex : String) -> (Double, Double, Double) {
  let body = if hex.length() > 0 && hex.get_char(0) == Some('#') {
    hex.substring(start=1)
  } else {
    hex
  }
  let r = hex_part(body, 0)
  let g = hex_part(body, 2)
  let b = hex_part(body, 4)
  (r, g, b)
}

///|
fn hex_part(s : String, offset : Int) -> Double {
  if s.length() < offset + 2 {
    return 0.0
  }
  let hi = hex_digit_val2(s.get_char(offset))
  let lo = hex_digit_val2(s.get_char(offset + 1))
  (hi * 16 + lo).to_double()
}

///|
fn hex_digit_val2(c : Char?) -> Int {
  match c {
    Some(ch) => {
      let code = ch.to_int()
      if code >= 48 && code <= 57 {
        code - 48
      } else if code >= 97 && code <= 102 {
        code - 87
      } else if code >= 65 && code <= 70 {
        code - 55
      } else {
        0
      }
    }
    None => 0
  }
}

///|
fn color_distance(
  a : (Double, Double, Double),
  b : (Double, Double, Double),
) -> Double {
  let dr = a.0 - b.0
  let dg = a.1 - b.1
  let db = a.2 - b.2
  Double::sqrt(dr * dr + dg * dg + db * db)
}

///|
fn extract_field(json : String, field : String) -> String {
  let key = "\"\{field}\":\""
  match json.find(key) {
    Some(idx) => {
      let start = idx + key.length()
      let rest = json.substring(start~)
      match rest.find("\"") {
        Some(end) => rest.substring(start=0, end~)
        None => ""
      }
    }
    None => ""
  }
}

///|
fn jstr14(parts : Array[String]) -> String {
  let sb = StringBuilder::new()
  for i in 0..<parts.length() {
    if i > 0 {
      sb.write_string(",")
    }
    sb.write_string(parts[i])
  }
  sb.to_string()
}
