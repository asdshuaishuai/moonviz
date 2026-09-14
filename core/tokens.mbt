///|
/// 设计令牌系统：Agent 驱动设计的基础语言。
///
/// 统一管理颜色/间距/圆角/字号，组件和节点都引用令牌而非硬编码值。
/// Agent 通过 `apply_token` 引用令牌，引擎在布局/渲染时解析为具体值。
/// 这样 Agent 生成的设计自动获得一致的主题（换主题只需改令牌表）。
pub(all) struct DesignTokens {
  mut colors : Map[String, String] // "primary" → "#4B6BFB"
  mut spacing : Map[String, Double] // "sm" → 4, "md" → 8, "lg" → 16
  mut radii : Map[String, Double] // "sm" → 4, "md" → 8, "round" → 999
  mut typography : Map[String, Double] // "h1" → 32, "h2" → 24, "body" → 14
}

///|
pub fn DesignTokens::default() -> DesignTokens {
  let t : DesignTokens = {
    colors: Map::new(),
    spacing: Map::new(),
    radii: Map::new(),
    typography: Map::new(),
  }
  // 颜色（Material 3 风格）
  t.colors.set("primary", "#4B6BFB")
  t.colors.set("primary_container", "#DEE5FF")
  t.colors.set("on_primary", "#FFFFFF")
  t.colors.set("secondary", "#5C6BC0")
  t.colors.set("secondary_container", "#E8EAF6")
  t.colors.set("surface", "#FFFFFF")
  t.colors.set("surface_variant", "#F2F3F5")
  t.colors.set("background", "#F8F9FB")
  t.colors.set("error", "#BA1A1A")
  t.colors.set("error_container", "#FFDAD6")
  t.colors.set("success", "#2E7D32")
  t.colors.set("warning", "#ED6C02")
  t.colors.set("outline", "#C8CDD6")
  t.colors.set("outline_variant", "#E0E0E0")
  t.colors.set("text_primary", "#1A1C1E")
  t.colors.set("text_secondary", "#42474F")
  t.colors.set("text_hint", "#9098A1")
  // 间距（4px 基准）
  t.spacing.set("xs", 2.0)
  t.spacing.set("sm", 4.0)
  t.spacing.set("md", 8.0)
  t.spacing.set("lg", 16.0)
  t.spacing.set("xl", 24.0)
  t.spacing.set("xxl", 32.0)
  t.spacing.set("xxxl", 48.0)
  // 圆角
  t.radii.set("none", 0.0)
  t.radii.set("sm", 4.0)
  t.radii.set("md", 8.0)
  t.radii.set("lg", 12.0)
  t.radii.set("xl", 16.0)
  t.radii.set("round", 999.0)
  // 字号
  t.typography.set("display", 48.0)
  t.typography.set("h1", 32.0)
  t.typography.set("h2", 24.0)
  t.typography.set("h3", 20.0)
  t.typography.set("h4", 16.0)
  t.typography.set("body", 14.0)
  t.typography.set("caption", 12.0)
  t.typography.set("overline", 10.0)
  t
}

// ---------------------------------------------------------------------------
// 令牌解析
// ---------------------------------------------------------------------------

///|
/// 解析颜色令牌："primary" → "#4B6BFB"；非令牌直接返回
pub fn DesignTokens::resolve_color(
  self : DesignTokens,
  token_or_hex : String,
) -> String {
  match self.colors.get(token_or_hex) {
    Some(hex) => hex
    None => token_or_hex // 已经是 hex 或自定义
  }
}

///|
/// 解析间距令牌："md" → 8.0
pub fn DesignTokens::resolve_spacing(
  self : DesignTokens,
  token : String,
) -> Double? {
  self.spacing.get(token)
}

///|
/// 解析圆角令牌："lg" → 12.0
pub fn DesignTokens::resolve_radius(
  self : DesignTokens,
  token : String,
) -> Double? {
  self.radii.get(token)
}

///|
/// 解析字号令牌："h2" → 24.0
pub fn DesignTokens::resolve_font(
  self : DesignTokens,
  token : String,
) -> Double? {
  self.typography.get(token)
}

// ---------------------------------------------------------------------------
// 令牌应用到节点（覆盖 fill/stroke/radius/font_size）
// ---------------------------------------------------------------------------

///|
/// 将节点样式中的令牌引用解析为具体值（就地修改）
pub fn DesignTokens::apply_to_node(self : DesignTokens, node : Node) -> Node {
  let style = node.style
  let resolved_fill = self.resolve_color(style.fill)
  let resolved_stroke = self.resolve_color(style.stroke)
  let resolved_text_color = self.resolve_color(style.text_color)
  // 圆角：如果值恰好等于某个令牌值，保持数值（不反查令牌）
  {
    ..node,
    style: {
      ..style,
      fill: resolved_fill,
      stroke: resolved_stroke,
      text_color: resolved_text_color,
    },
  }
}

///|
/// 列出所有可用令牌（Agent 发现用）
pub fn DesignTokens::to_json(self : DesignTokens) -> String {
  let parts : Array[String] = []
  // colors
  let cs : Array[String] = []
  for k in self.colors.keys() {
    match self.colors.get(k) {
      Some(v) => cs.push("{\"k\":\"\{k}\",\"v\":\"\{v}\"}")
      None => ()
    }
  }
  parts.push("\"colors\":[" + jstr5(cs) + "]")
  // spacing
  let sp : Array[String] = []
  for k in self.spacing.keys() {
    match self.spacing.get(k) {
      Some(v) => sp.push("{\"k\":\"\{k}\",\"v\":\{v}}")
      None => ()
    }
  }
  parts.push("\"spacing\":[" + jstr5(sp) + "]")
  // radii
  let rd : Array[String] = []
  for k in self.radii.keys() {
    match self.radii.get(k) {
      Some(v) => rd.push("{\"k\":\"\{k}\",\"v\":\{v}}")
      None => ()
    }
  }
  parts.push("\"radii\":[" + jstr5(rd) + "]")
  // typography
  let ty : Array[String] = []
  for k in self.typography.keys() {
    match self.typography.get(k) {
      Some(v) => ty.push("{\"k\":\"\{k}\",\"v\":\{v}}")
      None => ()
    }
  }
  parts.push("\"typography\":[" + jstr5(ty) + "]")
  "{\{jstr5(parts)}}"
}

///|
fn jstr5(parts : Array[String]) -> String {
  let sb = StringBuilder::new()
  for i in 0..<parts.length() {
    if i > 0 {
      sb.write_string(",")
    }
    sb.write_string(parts[i])
  }
  sb.to_string()
}
