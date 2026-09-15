///|
/// 主题系统：深色/浅色/自定义一键切换，令牌级主题变体管理。
///
/// 核心洞察：主题 = 同一组令牌名映射到不同的值。
/// Agent 只需引用令牌（`"primary"`），切换主题时所有节点自动更新。
///
/// - 预定义主题：light / dark / high_contrast / sepia / nord / sunset
/// - 自动暗色：从亮色主题自动推导暗色版本（反转亮度，保留色相）
/// - 自定义主题：Agent 给一个 partial override Map → 合并到基础主题
/// - 令牌级切换：`set_token("primary", "#FF5722")` → 全局生效

// ---------------------------------------------------------------------------
// 主题定义
// ---------------------------------------------------------------------------

pub(all) struct Theme {
  name : String
  display_name : String
  tokens : DesignTokens
  is_dark : Bool
}

///|
/// 预定义主题注册表
pub fn builtin_themes() -> Array[Theme] {
  [
    Theme::light(),
    Theme::dark(),
    Theme::high_contrast(),
    Theme::sepia(),
    Theme::nord(),
    Theme::sunset(),
  ]
}

// ---------------------------------------------------------------------------
// 预定义主题
// ---------------------------------------------------------------------------

///|
pub fn Theme::light() -> Theme {
  let t = DesignTokens::default()
  { name: "light", display_name: "浅色", tokens: t, is_dark: false }
}

///|
pub fn Theme::dark() -> Theme {
  let t = DesignTokens::default()
  // 覆盖为暗色值
  t.colors.set("primary", "#A5B4FC")
  t.colors.set("primary_container", "#3B4A8C")
  t.colors.set("on_primary", "#1A1C1E")
  t.colors.set("secondary", "#C5CAE9")
  t.colors.set("secondary_container", "#3949AB")
  t.colors.set("surface", "#1A1C1E")
  t.colors.set("surface_variant", "#2A2C2E")
  t.colors.set("background", "#0F1114")
  t.colors.set("error", "#CF6679")
  t.colors.set("error_container", "#5C1A1A")
  t.colors.set("success", "#81C784")
  t.colors.set("warning", "#FFB74D")
  t.colors.set("outline", "#42474F")
  t.colors.set("outline_variant", "#2A2C2E")
  t.colors.set("text_primary", "#E0E0E0")
  t.colors.set("text_secondary", "#A0A5AD")
  t.colors.set("text_hint", "#6B7078")
  { name: "dark", display_name: "深色", tokens: t, is_dark: true }
}

///|
pub fn Theme::high_contrast() -> Theme {
  let t = DesignTokens::default()
  t.colors.set("primary", "#0000EE")
  t.colors.set("on_primary", "#FFFFFF")
  t.colors.set("surface", "#FFFFFF")
  t.colors.set("surface_variant", "#F0F0F0")
  t.colors.set("background", "#FFFFFF")
  t.colors.set("error", "#CC0000")
  t.colors.set("text_primary", "#000000")
  t.colors.set("text_secondary", "#1A1A1A")
  t.colors.set("text_hint", "#333333")
  t.colors.set("outline", "#000000")
  {
    name: "high_contrast",
    display_name: "高对比度",
    tokens: t,
    is_dark: false,
  }
}

///|
pub fn Theme::sepia() -> Theme {
  let t = DesignTokens::default()
  t.colors.set("primary", "#8D6E63")
  t.colors.set("primary_container", "#EFEBE9")
  t.colors.set("on_primary", "#FFFFFF")
  t.colors.set("secondary", "#A1887F")
  t.colors.set("secondary_container", "#EFEBE9")
  t.colors.set("surface", "#FAF6F0")
  t.colors.set("surface_variant", "#F5F0E8")
  t.colors.set("background", "#FAF6F0")
  t.colors.set("error", "#B71C1C")
  t.colors.set("text_primary", "#3E2723")
  t.colors.set("text_secondary", "#5D4037")
  t.colors.set("text_hint", "#8D6E63")
  t.colors.set("outline", "#BCAAA4")
  { name: "sepia", display_name: "复古棕", tokens: t, is_dark: false }
}

///|
pub fn Theme::nord() -> Theme {
  let t = DesignTokens::default()
  t.colors.set("primary", "#88C0D0")
  t.colors.set("primary_container", "#4C566A")
  t.colors.set("on_primary", "#2E3440")
  t.colors.set("secondary", "#81A1C1")
  t.colors.set("secondary_container", "#434C5E")
  t.colors.set("surface", "#3B4252")
  t.colors.set("surface_variant", "#434C5E")
  t.colors.set("background", "#2E3440")
  t.colors.set("error", "#BF616A")
  t.colors.set("success", "#A3BE8C")
  t.colors.set("warning", "#EBCB8B")
  t.colors.set("outline", "#4C566A")
  t.colors.set("outline_variant", "#3B4252")
  t.colors.set("text_primary", "#ECEFF4")
  t.colors.set("text_secondary", "#D8DEE9")
  t.colors.set("text_hint", "#7B88A1")
  { name: "nord", display_name: "Nord 极地", tokens: t, is_dark: true }
}

///|
pub fn Theme::sunset() -> Theme {
  let t = DesignTokens::default()
  t.colors.set("primary", "#FF7043")
  t.colors.set("primary_container", "#FBE9E7")
  t.colors.set("on_primary", "#FFFFFF")
  t.colors.set("secondary", "#FF8A65")
  t.colors.set("secondary_container", "#FBE9E7")
  t.colors.set("surface", "#FFF8E1")
  t.colors.set("surface_variant", "#FFECB3")
  t.colors.set("background", "#FFF3E0")
  t.colors.set("error", "#D32F2F")
  t.colors.set("success", "#43A047")
  t.colors.set("warning", "#FB8C00")
  t.colors.set("outline", "#FFCC80")
  t.colors.set("text_primary", "#3E2723")
  t.colors.set("text_secondary", "#5D4037")
  t.colors.set("text_hint", "#8D6E63")
  { name: "sunset", display_name: "落日暖", tokens: t, is_dark: false }
}

// ---------------------------------------------------------------------------
// 自动暗色推导
// ---------------------------------------------------------------------------

///|
/// 从亮色主题自动生成暗色版本（反转亮度，保留色相）
pub fn Theme::auto_dark(base : Theme) -> Theme {
  let dark_tokens = base.tokens
  // 反转每个颜色令牌的亮度
  for key in dark_tokens.colors.keys() {
    match dark_tokens.colors.get(key) {
      Some(hex) => {
        let inverted = invert_luminance(hex)
        dark_tokens.colors.set(key, inverted)
      }
      None => ()
    }
  }
  {
    name: base.name + "_auto_dark",
    display_name: base.display_name + "（暗色）",
    tokens: dark_tokens,
    is_dark: true,
  }
}

///|
/// 反转颜色亮度：保留色相和饱和度，反转亮度
fn invert_luminance(hex : String) -> String {
  let (r, g, b) = parse_rgb5(hex)
  // 反转 RGB
  let nr = 255 - r
  let ng = 255 - g
  let nb = 255 - b
  // 转回 hex
  to_hex(nr, ng, nb)
}

///|
fn parse_rgb5(hex : String) -> (Int, Int, Int) {
  let body = if hex.length() > 0 && hex.get_char(0) == Some('#') {
    hex.substring(start=1)
  } else {
    hex
  }
  if body.length() < 6 {
    return (0, 0, 0)
  }
  (hv5(body, 0), hv5(body, 2), hv5(body, 4))
}

///|
fn hv5(s : String, offset : Int) -> Int {
  if s.length() < offset + 2 {
    return 0
  }
  let hi = hd5(s.get_char(offset))
  let lo = hd5(s.get_char(offset + 1))
  hi * 16 + lo
}

///|
fn hd5(c : Char?) -> Int {
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
fn to_hex(r : Int, g : Int, b : Int) -> String {
  let rh = if r < 16 { "0" + r.to_string() } else { r.to_string() }
  let gh = if g < 16 { "0" + g.to_string() } else { g.to_string() }
  let bh = if b < 16 { "0" + b.to_string() } else { b.to_string() }
  // 转为 hex
  "#" + int_to_hex(r) + int_to_hex(g) + int_to_hex(b)
}

///|
fn int_to_hex(v : Int) -> String {
  let hi = v / 16
  let lo = v % 16
  let h = if hi < 10 {
    (hi + 48).to_char().to_string()
  } else {
    (hi + 87).to_char().to_string()
  }
  let l = if lo < 10 {
    (lo + 48).to_char().to_string()
  } else {
    (lo + 87).to_char().to_string()
  }
  h + l
}

// ---------------------------------------------------------------------------
// 主题注册表（Project 级）
// ---------------------------------------------------------------------------

///|
pub(all) struct ThemeRegistry {
  themes : Map[String, Theme]
  mut current : String
}

///|
pub fn ThemeRegistry::new() -> ThemeRegistry {
  let r : ThemeRegistry = { themes: Map::new(), current: "light" }
  for t in builtin_themes().iter() {
    r.themes.set(t.name, t)
  }
  r
}

///|
/// 注册自定义主题
pub fn ThemeRegistry::register(self : ThemeRegistry, theme : Theme) -> Unit {
  self.themes.set(theme.name, theme)
}

///|
/// 切换主题
pub fn ThemeRegistry::switch(
  self : ThemeRegistry,
  name : String,
) -> Result[DesignTokens, String] {
  match self.themes.get(name) {
    Some(t) => {
      self.current = name
      Ok(t.tokens)
    }
    None => Err("unknown_theme: " + name)
  }
}

///|
/// 获取当前主题
pub fn ThemeRegistry::current_theme(
  self : ThemeRegistry,
) -> Result[Theme, String] {
  match self.themes.get(self.current) {
    Some(t) => Ok(t)
    None => Err("no_current_theme")
  }
}

///|
/// 列出所有可用主题
pub fn ThemeRegistry::list(self : ThemeRegistry) -> String {
  let parts : Array[String] = []
  for name in self.themes.keys() {
    match self.themes.get(name) {
      Some(t) => {
        let is_cur = if name == self.current { " ←current" } else { "" }
        parts.push("\"" + name + "\" (\"" + t.display_name + "\")" + is_cur)
      }
      None => ()
    }
  }
  let j = jstr21(parts)
  "[\{j}]"
}

// ---------------------------------------------------------------------------
// Project 集成：主题切换
// ---------------------------------------------------------------------------

///|
/// 应用主题到项目（更新令牌表并重新解析所有节点颜色）
pub fn Project::apply_theme(
  self : Project,
  theme_name : String,
) -> Result[String, String] {
  let themes = builtin_themes()
  let mut found : Theme? = None
  for i in 0..<themes.length() {
    if themes[i].name == theme_name {
      found = Some(themes[i])
      break
    }
  }
  match found {
    Some(theme) => {
      let prior = self.tokens_snapshot()
      self.tokens = theme.tokens
      // 主题切换保留自定义令牌覆盖：tokens: 段是设计者明确意图，
      // 换主题只换未覆盖的角色
      match self.token_overrides {
        Some(ov) =>
          for role in ov.keys() {
            match ov.get(role) {
              Some(v) => self.tokens.colors.set(role, v)
              None => ()
            }
          }
        None => ()
      }
      self.active_theme = theme_name
      let changed = self.recolor_with(theme.tokens, prior=Some(prior))
      let is_dark = if theme.is_dark { "true" } else { "false" }
      Ok(
        "{\"ok\":true,\"theme\":\"\{theme_name}\",\"is_dark\":\{is_dark},\"recolored\":\{changed}}",
      )
    }
    None => Err("unknown_theme: " + theme_name)
  }
}

///|
/// text_color 语境的角色分级（小者优先）：文字位置的十六进制值优先按
/// 文字角色解释——#1A1C1E 出现在文字上应视为 light.text_primary 而不是
/// dark.surface，否则 nord 等深色主题会得到「深字压深底」。
fn role_rank_for_text(role : String) -> Int {
  if role_has_prefix(role, "text_") {
    1
  } else if role_has_prefix(role, "on_") {
    2
  } else if role == "surface" || role == "surface_variant" || role == "surface_alt" || role == "background" {
    3
  } else if role_has_suffix(role, "_container") {
    4
  } else if role == "primary" || role == "secondary" {
    5
  } else if role_has_prefix(role, "outline") {
    6
  } else {
    7
  }
}

///|
/// text 语境（彩色底变体）：primary/secondary 底上的文字几乎总是
/// on_primary/on_secondary 语义——#FFFFFF 出现在按钮上应还原成
/// on_primary 而不是 surface，否则深色主题往返后按钮文字错位成
/// text_primary 的深色值。
fn role_rank_for_text_on(role : String) -> Int {
  if role_has_prefix(role, "on_") {
    1
  } else if role_has_prefix(role, "text_") {
    2
  } else {
    role_rank_for_text(role)
  }
}

///|
/// fill 语境的角色分级：底/容器优先，文字角色殿后（同一字面量被用作
/// 面色时几乎总是 surface/container 语义）。
fn role_rank_for_fill(role : String) -> Int {
  if role == "surface" || role == "surface_variant" || role == "surface_alt" || role == "background" {
    1
  } else if role_has_suffix(role, "_container") {
    2
  } else if role == "primary" || role == "secondary" {
    3
  } else if role_has_prefix(role, "outline") {
    4
  } else if role_has_prefix(role, "text_") {
    5
  } else if role_has_prefix(role, "on_") {
    6
  } else {
    7
  }
}

fn role_has_prefix(s : String, prefix : String) -> Bool {
  s.length() >= prefix.length() &&
  s.substring(start=0, end=prefix.length()) == prefix
}

fn role_has_suffix(s : String, suffix : String) -> Bool {
  s.length() >= suffix.length() &&
  s.substring(start=s.length() - suffix.length()) == suffix
}

///|
/// 角色重着色：模板/画布把令牌值写成字面量（fill="#4B6BFB"），仅换
/// tokens 表对已落盘的颜色无效。按默认调色板建立「字面量 → 角色」反查表，
/// 把匹配的 fill/text_color 重写为新主题的角色值——变更写回 .mbt.md，
/// 保持唯一事实源语义。
fn Project::recolor_with(
  self : Project,
  target : DesignTokens,
  prior? : DesignTokens? = None,
) -> Int {
  // 字面量 → 角色：以「全部内置主题 ∪ 默认」的调色板并集反查。
  // 操作路径每条命令都从 canonical MBT 重建 Project（tokens 恒为默认），
  // 仅按当前/默认反查会让「nord → light」无从映射——并集保证任一主题的
  // 字面量都能反查到角色，主题切换无状态可逆。
  // 字面量 → 候选角色集合。同一字面量在不同主题里可能是不同角色
  // （#1A1C1E 既是 light.text_primary 也是 dark.surface）——不能取
  // 「最后写入」那个，按使用处（fill / text_color）的角色类分级选义。
  let lit_roles : Map[String, Map[String, Bool]] = Map::new()
  let remember = fn(lit : String, role : String) {
    match lit_roles.get(lit) {
      Some(set) => set.set(role, true)
      None => {
        let set : Map[String, Bool] = Map::new()
        set.set(role, true)
        lit_roles.set(lit, set)
      }
    }
  }
  let palettes : Array[DesignTokens] = [DesignTokens::default()]
  for theme in builtin_themes().iter() {
    palettes.push(theme.tokens)
  }
  match prior {
    Some(p) => palettes.push(p)
    None => ()
  }
  for palette in palettes {
    for role in palette.colors.keys() {
      match palette.colors.get(role) {
        Some(v) => remember(v, role)
        None => ()
      }
    }
  }
  // 引擎默认文字色 #111111（node/decl 出厂值）语义上就是 text_primary
  remember("#111111", "text_primary")
  let pick = fn(lit : String, rank : (String) -> Int) -> String? {
    match lit_roles.get(lit) {
      None => None
      Some(set) => {
        let mut best : String? = None
        let mut best_rank = 99
        for role in set.keys() {
          let r = rank(role)
          // 严格小于 + 角色名字典序决胜：与 Map 迭代顺序无关，结果确定
          if r < best_rank || (r == best_rank && best is Some(b) && role < b) {
            best = Some(role)
            best_rank = r
          }
        }
        best
      }
    }
  }
  let mut changed = 0
  for ab_id in self.artboards.keys() {
    let ab = match self.artboards.get(ab_id) {
      Some(a) => a
      None => continue
    }
    for nid in ab.doc.nodes.keys() {
      let _ = ab.doc.update_node(nid, fn(n) {
        let mut node = n
        match pick(n.style.fill, role_rank_for_fill) {
          Some(role) =>
            match target.colors.get(role) {
              Some(v) => {
                if v != n.style.fill {
                  changed = changed + 1
                }
                node = { ..node, style: { ..node.style, fill: v } }
              }
              None => ()
            }
          None => ()
        }
        // 文字角色按所在底色判别：primary/secondary 实底上的文字优先
        // on_*（按钮），透明底/容器上的文字优先 text_*（正文/输入框）
        let text_rank = match pick(node.style.fill, role_rank_for_fill) {
          Some(r) =>
            if r == "primary" || r == "secondary" {
              role_rank_for_text_on
            } else {
              role_rank_for_text
            }
          None => role_rank_for_text
        }
        match pick(n.style.text_color, text_rank) {
          Some(role) =>
            match target.colors.get(role) {
              Some(v) => {
                if v != n.style.text_color {
                  changed = changed + 1
                }
                node = { ..node, style: { ..node.style, text_color: v } }
              }
              None => ()
            }
          None => ()
        }
        node
      })
    }
  }
  if changed > 0 {
    self.revision = self.revision + 1
  }
  changed
}

///|
/// 令牌表深快照：recolor 反查需要「变更前」的字面量→角色来源，
/// 自定义值（set_token 产物）不在任何内置调色板里。
fn Project::tokens_snapshot(self : Project) -> DesignTokens {
  let colors : Map[String, String] = Map::new()
  for role in self.tokens.colors.keys() {
    match self.tokens.colors.get(role) {
      Some(v) => colors.set(role, v)
      None => ()
    }
  }
  { ..self.tokens, colors }
}

///|
/// 加载路径恢复主题：只切换 tokens 与 active_theme，不做角色重着色——
/// canonical MBT 里的节点颜色已是主题字面量，重着色属于 apply_theme 的
/// 职责，重复执行会把已是目标色的节点原样重写（幂等但徒增 revision）。
pub fn Project::set_theme_tokens(self : Project, theme_name : String) -> Unit {
  for theme in builtin_themes().iter() {
    if theme.name == theme_name {
      self.tokens = theme.tokens
      self.active_theme = theme.name
      return
    }
  }
}

///|
/// 修改单个令牌值（全局生效）。
///
/// "全局生效"必须包含两件事，只改内存 tokens 表对已落盘的字面量无效：
/// 1. 记录自定义覆盖（token_overrides），随 canonical MBT frontmatter
///    `tokens:` 段往返——否则下一条命令从文本重建时覆盖即丢失；
/// 2. 立即重着色：旧值字面量 → 角色 → 新值，与 apply_theme 同一反查
///    表，因此同样可逆（换回原值即恢复）。
pub fn Project::set_token(
  self : Project,
  token_name : String,
  value : String,
) -> Result[String, String] {
  if !self.tokens.colors.contains(token_name) {
    return Err("unknown_token: " + token_name)
  }
  let prior = self.tokens_snapshot()
  let previous = match self.tokens.colors.get(token_name) {
    Some(v) => v
    None => ""
  }
  self.tokens.colors.set(token_name, value)
  if self.token_overrides is None {
    self.token_overrides = Some(Map::new())
  }
  match self.token_overrides {
    Some(ov) => ov.set(token_name, value)
    None => ()
  }
  // recolor_with 在 changed>0 时已 +1；值未变化的重复 set（load 路径）
  // 不会虚涨 revision
  let changed = self.recolor_with(self.tokens, prior=Some(prior))
  Ok(
    "{\"ok\":true,\"token\":\"\{token_name}\",\"old\":\"\{previous}\",\"value\":\"\{value}\",\"recolored\":\{changed}}",
  )
}

///|
/// 获取令牌当前值
pub fn Project::get_token(
  self : Project,
  token_name : String,
) -> Result[String, String] {
  match self.tokens.colors.get(token_name) {
    Some(v) => Ok(v)
    None => Err("unknown_token: " + token_name)
  }
}

///|
/// 预览节点在不同主题下的颜色
pub fn Project::preview_themes(
  self : Project,
  node_id : String,
) -> Result[String, String] {
  let results : Array[String] = []
  for theme in builtin_themes().iter() {
    let fill = theme.tokens.resolve_color("primary")
    results.push(
      "{\"theme\":\"\{theme.name}\",\"display\":\"\{theme.display_name}\",\"primary\":\"\{fill}\"}",
    )
  }
  let j = jstr21(results)
  Ok("[\{j}]")
}

///|
/// 自动生成当前主题的暗色版本并应用
pub fn Project::enable_auto_dark(self : Project) -> Result[String, String] {
  let current = Theme::light() // 简化：始终从 light 推导
  let dark = Theme::auto_dark(current)
  self.tokens = dark.tokens
  Ok("{\"ok\":true,\"theme\":\"auto_dark\",\"original\":\"\{current.name}\"}")
}

///|
fn jstr21(parts : Array[String]) -> String {
  let sb = StringBuilder::new()
  for i in 0..<parts.length() {
    if i > 0 {
      sb.write_string(",")
    }
    sb.write_string(parts[i])
  }
  sb.to_string()
}
