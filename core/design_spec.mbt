// ---------------------------------------------------------------------------
// issue #24：规范驱动生成（spec 在场 = 第一权威；spec 缺失 = 显式要求）
//
// spec 契约（JSON 字符串，schema 对齐 DESIGN.md 载荷）：
//   { "v":1,
//     "style": "apple" | "harmony"（美学体系第一要素；缺省 = 保留当前主题）,
//     "palette": { "primary": "#..", "background": "#..", "surface": "#..",
//                  "text": "#..", "muted": "#..", "danger": "#..", "success": "#.." },
//     "motion": { "fast/base/slow/tick/stagger/stagger_max": 毫秒数 },
//     "typography": { "display/h1/h2/h3/h4/body/caption/overline": 数字 },
//     "spacing": [..], "radius": { "sm":.., "md":.., "lg":.. },
//     "components": {..}, "rules": [..] }
// 应用语义：style → 美学主题预设（apple/harmony 令牌族，含 tinted 分层底/
// hairline/胶囊语义）先行应用；palette → token 覆盖 + recolor_with 重着色
// （palette 覆盖 style 的同名角色，二者可叠加——style 给气质、palette 给微调）；
// 字号阶 → 节点 font_size 按默认阶到 spec 阶重映射；圆角档 → 8/10→sm、
// 12→md、16→lg（999 保留正圆语义）。规则数组只随信封上报，不做硬编码裁决。
// ---------------------------------------------------------------------------

///|
/// spec 缺失时的可编辑草案（design_spec_required 随行返回）。
/// 从 intent 抽取推荐强调色；其余取引擎基线，Agent 落盘后重试 generate。
pub fn design_spec_draft_json(intent_text : String) -> String {
  let primary = if intent_text.contains("健身") ||
    intent_text.contains("健康") ||
    intent_text.contains("运动") {
    "#10B981"
  } else if intent_text.contains("电商") ||
    intent_text.contains("商品") ||
    intent_text.contains("购物") {
    "#F97316"
  } else {
    // 默认主色与 tokens.mbt 校准值同步（历史教训：字面量残留即漂移源）
    "#4361EE"
  }
  "{\"v\":1,\"palette\":{\"primary\":\"" +
  primary +
  "\",\"secondary\":\"#5856D6\",\"info\":\"#0060B8\",\"warning\":\"#B85C00\",\"background\":\"#FFFFFF\",\"surface\":\"#F6F7F9\",\"text\":\"#1A1C1E\",\"muted\":\"#6B7280\",\"danger\":\"#DC2626\",\"success\":\"#16A34A\"},\"typography\":{\"display\":48,\"h1\":32,\"h2\":24,\"h3\":20,\"h4\":16,\"body\":14,\"caption\":12},\"spacing\":[4,8,12,16,24,32],\"radius\":{\"sm\":8,\"md\":12,\"lg\":16},\"rules\":[\"按钮不卡文案（宽≥文案+24）\",\"撞色零容忍\",\"齐缝列表行分隔\",\"触控目标 44\"]}"
  // palette 键集（Agent 提取需求时按此契约产出）：基础 7 键 primary/background/
  // surface/text/muted/danger/success + 扩展键 secondary/info/warning/
  // surfaceVariant/primaryContainer/…（容器键缺席时引擎从同名语义色对
  // background 推导 tint，配色决策始终来自 spec 而非引擎预设）
}

///|
fn ds_is_blank(s : String) -> Bool {
  s.trim() == ""
}

///|
/// spec JSON 中 key 的字符串值（首个 "key" 后的 "..."）。
fn ds_string_value(json : String, key : String) -> String? {
  let pat = "\"" + key + "\""
  let pos = match json.find(pat) {
    None => return None
    Some(p) => p
  }
  let rest = json.substring(start=pos + pat.length())
  let colon = match rest.find(":") {
    None => return None
    Some(c) => c
  }
  let after = rest.substring(start=colon + 1)
  let q1 = match after.find("\"") {
    None => return None
    Some(q) => q
  }
  let tail = after.substring(start=q1 + 1)
  let q2 = match tail.find("\"") {
    None => return None
    Some(q) => q
  }
  Some(tail.substring(start=0, end=q2))
}

///|
/// spec JSON 中 key 的数字值（首个 "key": 后的数字，直到 , 或 } 或换行）。
fn ds_number_value(json : String, key : String) -> Double? {
  let pat = "\"" + key + "\""
  let pos = match json.find(pat) {
    None => return None
    Some(p) => p
  }
  let rest = json.substring(start=pos + pat.length())
  let colon = match rest.find(":") {
    None => return None
    Some(c) => c
  }
  let after = rest.substring(start=colon + 1)
  let mut digits = ""
  let mut seen = false
  let mut dot_seen = false
  for c in after.iter() {
    if c >= '0' && c <= '9' {
      digits = digits + "\{c}"
      seen = true
    } else if c == '.' && !dot_seen {
      digits = digits + "."
      dot_seen = true
    } else if c == ' ' || c == '\n' || c == '\r' || c == '\t' {
      if seen {
        break
      }
    } else {
      break
    }
  }
  if digits == "" {
    return None
  }
  // 手工十进制解析（整数部分 + 小数部分）
  let mut int_part = 0.0
  let mut frac_part = 0.0
  let mut frac_div = 1.0
  let mut in_frac = false
  for c in digits.iter() {
    if c == '.' {
      in_frac = true
    } else {
      let d = (c.to_int() - 48).to_double()
      if in_frac {
        frac_div = frac_div * 10.0
        frac_part = frac_part + d / frac_div
      } else {
        int_part = int_part * 10.0 + d
      }
    }
  }
  Some(int_part + frac_part)
}

///|
/// spec JSON 中 key 对应对象 `{...}` 的体文本（首个 "key" 后的花括号内）。
/// 只做单层：spec 契约里的对象都是扁平键值（palette/motion/radius…）。
fn ds_object_body(json : String, key : String) -> String? {
  let pat = "\"" + key + "\""
  let pos = match json.find(pat) {
    None => return None
    Some(p) => p
  }
  let rest = json.substring(start=pos + pat.length())
  let colon = match rest.find(":") {
    None => return None
    Some(c) => c
  }
  let after = rest.substring(start=colon + 1)
  let open = match after.find("{") {
    None => return None
    Some(o) => o
  }
  let body = after.substring(start=open + 1)
  let close = match body.find("}") {
    None => return None
    Some(c) => c
  }
  Some(body.substring(start=0, end=close))
}

///|
fn ds_token_copy(src : DesignTokens) -> DesignTokens {
  let t : DesignTokens = {
    colors: Map::new(),
    spacing: Map::new(),
    radii: Map::new(),
    typography: Map::new(),
    motion: Map::new(),
  }
  for k in src.colors.keys() {
    match src.colors.get(k) {
      Some(v) => t.colors.set(k, v)
      None => ()
    }
  }
  for k in src.spacing.keys() {
    match src.spacing.get(k) {
      Some(v) => t.spacing.set(k, v)
      None => ()
    }
  }
  for k in src.radii.keys() {
    match src.radii.get(k) {
      Some(v) => t.radii.set(k, v)
      None => ()
    }
  }
  for k in src.typography.keys() {
    match src.typography.get(k) {
      Some(v) => t.typography.set(k, v)
      None => ()
    }
  }
  for k in src.motion.keys() {
    match src.motion.get(k) {
      Some(v) => t.motion.set(k, v)
      None => ()
    }
  }
  t
}

///|
fn ds_apply_font_scale(doc : Document, spec : String) -> Unit {
  // 默认阶 → spec 阶：按默认 typography 的值反查档位，再取 spec 同档值。
  let base = DesignTokens::default()
  let pairs : Array[(Double, Double)] = []
  for key in base.typography.keys() {
    let old = match base.typography.get(key) {
      Some(v) => v
      None => -1.0
    }
    match ds_number_value(spec, key) {
      Some(nv) =>
        if old > 0.0 && nv > 0.0 && nv != old {
          pairs.push((old, nv))
        }
      None => ()
    }
  }
  if pairs.length() == 0 {
    return
  }
  for id in doc.nodes.keys() {
    match doc.nodes.get(id) {
      None => ()
      Some(n) => {
        let fs = n.style.font_size
        for pair in pairs.iter() {
          let (old, nv) = pair
          if fs > old - 0.5 && fs < old + 0.5 {
            let _ = doc.update_node(id, fn(x) {
              { ..x, style: { ..x.style, font_size: nv, } }
            })
            break
          }
        }
      }
    }
  }
}

///|
fn ds_apply_radius(doc : Document, spec : String) -> Unit {
  let sm = ds_number_value(spec, "sm")
  let md = ds_number_value(spec, "md")
  let lg = ds_number_value(spec, "lg")
  for id in doc.nodes.keys() {
    match doc.nodes.get(id) {
      None => ()
      Some(n) => {
        let r = n.style.corner_radius
        // 模板全量圆角档吸附到 spec 三档（目标档缺席时保留原值）：
        // - 直角 0 豁免（comply 同款口径）；胶囊/正圆写法 100、999 归一
        //   到 999 豁免档——视觉等价（渲染半径上限即半宽/半高）
        // - 小控件 2/4/6/8/10 → sm；中面 12/14 → md；大容器 16/18/20/24 → lg
        //   此前只重映射 8/10/12/16，模板的 6/14/18/20/24 生成即违规、
        //   自家 comply 过不了
        let nr : Double? = if r > -0.5 && r < 0.5 {
          None
        } else if r > 99.5 {
          Some(999.0)
        } else if r > 1.5 && r < 10.5 {
          sm
        } else if r > 11.5 && r < 14.5 {
          md
        } else if r > 15.5 && r < 24.5 {
          lg
        } else {
          None
        }
        match nr {
          Some(v) =>
            if v != r {
              let _ = doc.update_node(id, fn(x) {
                { ..x, style: { ..x.style, corner_radius: v, } }
              })
            }
          None => ()
        }
      }
    }
  }
}

///|
/// spec.style 值 → 可注册主题名（仅美学体系有效；"" = 不换主题）。
/// 暗色美学预设（apple_dark/harmony_dark）是已注册名，同样直通——Agent
/// 点名暗色预设不得被静默吃掉。未知值返回 ""（不报错——spec 是数据契约，
/// 非法 style 由 palette/组件白名单通道各自兜底，不在这里静默改道）。
pub fn ds_style_theme(spec : String) -> String {
  match ds_string_value(spec, "style") {
    Some(v) => {
      let a = theme_alias(v)
      if a == "apple" ||
        a == "apple_dark" ||
        a == "harmony" ||
        a == "harmony_dark" ||
        a == "vivid" ||
        a == "editorial" ||
        a == "playful" {
        a
      } else {
        ""
      }
    }
    None => ""
  }
}

///|
/// 当前激活主题是否暗色（美学 style 换装时保留明暗意图：暗色项目 +
/// style:apple → apple_dark 而不是静默跳回浅色）。
fn Project::active_theme_is_dark(self : Project) -> Bool {
  for t in builtin_themes().iter() {
    if t.name == self.active_theme {
      return t.is_dark
    }
  }
  false
}

///|
/// spec 应用（issue #24）：style → 美学主题预设先行；palette → token 覆盖
/// + 重着色；字号阶/圆角档按 spec 规范化。spec 空白 → design_spec_required
/// （不静默兜底）。
pub fn Project::apply_design_spec(
  self : Project,
  artboard~ : String,
  spec~ : String,
) -> Result[Unit, String] {
  if ds_is_blank(spec) {
    return Err("design_spec_required")
  }
  match self.artboards.get(artboard) {
    None => return Err("unknown_artboard: " + artboard)
    Some(_) => ()
  }
  // 0) 美学体系第一要素：style: apple/harmony 先落整套令牌气质（tinted
  //    分层底/胶囊/hairline 语义族）；当前项目处于暗色主题时换装保留暗色
  //    （apple + dark 意图 → apple_dark）。palette 随后覆盖同名角色（微调优先）。
  let style_theme = ds_style_theme(spec)
  if style_theme != "" {
    let resolved = resolve_aesthetic_theme(style_theme, self.active_theme_is_dark())
    match self.apply_theme(resolved) {
      Ok(_) => ()
      Err(_) => ()
    }
  }
  // 1) 调色板 → token 覆盖（含扩展角色与容器推导，spec 是第一权威：
  //    引擎预设只在 spec 未定义该角色时兜底）
  let _ = self.apply_spec_tokens(spec)
  // 2) 字号阶与圆角档
  match self.artboards.get(artboard) {
    None => ()
    Some(ab) => {
      ds_apply_font_scale(ab.doc, spec)
      ds_apply_radius(ab.doc, spec)
    }
  }
  // 3) 记录生效 spec：norms 档位判定以 spec 为准（issue #24 第 2 条）
  self.design_spec = spec
  Ok(())
}

///|
/// spec palette → 令牌的全量应用（spec 是第一权威，引擎默认只是缺省兜底）。
///
/// 三层语义：
/// 1. 显式键直派：基础 7 键 + 扩展键（secondary/info/warning +
///    primaryContainer/secondaryContainer/successContainer/warningContainer/
///    infoContainer/surfaceVariant）逐角色 set_token；
/// 2. 容器推导：spec 给了某语义色但没给它的容器键时，容器 =
///    `hex_mix(语义色, background, 0.14)`——多彩层次从 spec 的色相派生，
///    而不是落回引擎预设值（配色决策归 spec 文档，引擎只补层次）；
/// 3. 返回生效角色数（信封/测试用）。
///
/// 独立于 apply_design_spec：generate 在**模板实例化之前**调用本函数，
/// 组件补丁即以 spec 令牌取色，消除 theme→template 顺序依赖。
pub fn Project::apply_spec_tokens(self : Project, spec : String) -> Int {
  // 显式键：spec key → 令牌角色
  let keys : Array[(String, String)] = [
    ("primary", "primary"),
    ("secondary", "secondary"),
    ("accent", "secondary"),
    ("info", "info"),
    ("warning", "warning"),
    ("background", "background"),
    ("surface", "surface"),
    ("surfaceVariant", "surface_variant"),
    ("text", "text_primary"),
    ("muted", "text_secondary"),
    ("danger", "error"),
    ("error", "error"),
    ("success", "success"),
    ("primaryContainer", "primary_container"),
    ("secondaryContainer", "secondary_container"),
    ("successContainer", "success_container"),
    ("warningContainer", "warning_container"),
    ("infoContainer", "info_container"),
  ]
  let present : Map[String, String] = Map::new() // 令牌角色 → hex
  let mut applied = 0
  for pair in keys.iter() {
    let (spec_key, token_role) = pair
    match ds_string_value(spec, spec_key) {
      Some(v) =>
        if v != "" && norm_is_hex6(v) {
          match self.set_token(token_role, v) {
            Ok(_) => {
              present.set(token_role, v)
              applied = applied + 1
            }
            Err(_) => ()
          }
        }
      None => ()
    }
  }
  // inverse chrome 派生：spec 给了 text/surface → 反相层（宽屏侧栏一类）
  // 从 spec 色相派生：亮主题得深侧栏、暗主题得亮侧栏，颜色仍可追溯到 spec
  match present.get("text_primary") {
    Some(tx) => {
      let _ = self.set_token("inverse_surface", tx)
      let _ = self.set_token("inverse_surface_variant", hex_mix(tx, "#000000", 0.30))
    }
    None => ()
  }
  match present.get("surface") {
    Some(sf) => {
      let _ = self.set_token("inverse_text", sf)
    }
    None => ()
  }
  match (present.get("text_primary"), present.get("surface")) {
    (Some(tx), Some(sf)) => {
      let _ = self.set_token("inverse_muted", hex_mix(tx, sf, 0.62))
    }
    _ => ()
  }
  // 容器推导：语义色在场而容器键缺席 → 从 spec 色相派生（背景取当前令牌值，
  // 暗/亮主题各自得到同深度层次的 tint）
  let bg = self.tokens.resolve_color("background")
  let pairs : Array[(String, String)] = [
    ("primary", "primary_container"),
    ("secondary", "secondary_container"),
    ("success", "success_container"),
    ("warning", "warning_container"),
    ("info", "info_container"),
  ]
  for pair in pairs.iter() {
    let (base_role, container_role) = pair
    if !present.contains(container_role) {
      match present.get(base_role) {
        Some(base_hex) => {
          // tint = 背景 78% + 语义色 22%：贴近背景亮度（暗主题得暗 tint、
          // 亮主题得亮 tint）且对背景对比 ≥1.10（容器可辨性检测线），
          // 色相来自 spec 语义色
          let tint = hex_mix(bg, base_hex, 0.22)
          match self.set_token(container_role, tint) {
            Ok(_) => applied = applied + 1
            Err(_) => ()
          }
        }
        None => ()
      }
    }
  }
  // motion：spec.motion 对象（毫秒）→ 动效令牌——与 palette 同级权威。
  // 导出面/wasm 快照从令牌表取值，因此 spec 的节拍不需要在导出层再写一遍。
  match ds_object_body(spec, "motion") {
    Some(body) => {
      for key in [
        "fast", "base", "slow", "tick", "stagger", "stagger_max",
      ].iter() {
        match ds_number_value(body, key) {
          Some(v) =>
            if v > 0.0 {
              match self.set_token("motion." + key, v.to_int().to_string()) {
                Ok(_) => applied = applied + 1
                Err(_) => ()
              }
            }
          None => ()
        }
      }
    }
    None => ()
  }
  applied
}

///|
/// 调色板遵从检测（spec 强制约束的可见面）：节点 fill/text_color 为字面
/// hex 且不等于任何当前令牌值（即不是从 spec/主题角色解析出来的颜色）时
/// 计入违规——模板/Agent 的一切用色都必须能追溯到 spec 调色板或语义角色。
/// 渐变（含 ':'）与 "none" 不判；上限 8 条与 norms 各检测一致。
pub fn Project::design_spec_color_violations(self : Project, artboard~ : String) -> Array[String] {
  let out : Array[String] = []
  let ab = match self.artboards.get(artboard) {
    Some(a) => a
    None => return out
  }
  // 当前令牌值全集（spec 应用后的生效调色板）
  let allowed : Map[String, Bool] = Map::new()
  for role in self.tokens.colors.keys() {
    match self.tokens.colors.get(role) {
      Some(v) => allowed.set(v.to_lower(), true)
      None => ()
    }
  }
  for id in ab.doc.nodes.keys() {
    if out.length() >= 8 {
      break
    }
    if id == ab.doc.root_id {
      continue
    }
    match ab.doc.nodes.get(id) {
      None => ()
      Some(n) => {
        let fill = n.style.fill
        if norm_is_hex6(fill) && !allowed.contains(fill.to_lower()) {
          out.push(
            "\{json_escape(id)}（\{n.component}）填充 \{fill} 不在设计规范调色板内（palette/语义角色之外的字面色）",
          )
          continue
        }
        // 无文字的节点不渲染文字色——text_color 停留出厂默认是惰性值，
        // 判它只会把 divider/rect/spacer 的默认 #111111 当违规（误报源）
        let tc = n.style.text_color
        if out.length() < 8 &&
          n.text != "" &&
          norm_is_hex6(tc) &&
          !allowed.contains(tc.to_lower()) {
          out.push(
            "\{json_escape(id)}（\{n.component}）文字色 \{tc} 不在设计规范调色板内",
          )
        }
      }
    }
  }
  out
}

///|
/// 按钮族圆角基准（norms 用）：spec.radius.sm 在场取 spec，否则内置 8。
pub fn Project::design_spec_radius_base(self : Project) -> Double {
  if self.design_spec.trim() == "" {
    return NORM_RADIUS_BASE
  }
  match ds_number_value(self.design_spec, "sm") {
    Some(v) => if v > 0.0 { v } else { NORM_RADIUS_BASE }
    None => NORM_RADIUS_BASE
  }
}

///|
/// 抽取一段以 '[' 开头的数组文本里的引号 token。
fn ds_tokens_in_brackets(s : String) -> Array[String] {
  let out : Array[String] = []
  let open = match s.find("[") {
    None => return out
    Some(o) => o
  }
  let body = s.substring(start=open + 1)
  let close = match body.find("]") {
    None => body
    Some(c) => body.substring(start=0, end=c)
  }
  let mut cur = ""
  let mut in_q = false
  for c in close.iter() {
    if c == '"' {
      if in_q {
        if cur != "" {
          out.push(cur)
        }
        cur = ""
      }
      in_q = !in_q
    } else if in_q {
      cur = cur + "\{c}"
    }
  }
  out
}

///|
/// 从 key 后的首个 '[' … ']' 抽取引号内 token（components/rules 列表解析用）。
fn ds_quoted_list(spec : String, key : String) -> Array[String] {
  let out : Array[String] = []
  let pat = "\"" + key + "\""
  let pos = match spec.find(pat) {
    None => return out
    Some(p) => p
  }
  let rest = spec.substring(start=pos + pat.length())
  let open = match rest.find("[") {
    None => return out
    Some(o) => o
  }
  let body = rest.substring(start=open + 1)
  let close = match body.find("]") {
    None => return out
    Some(c) => c
  }
  let span = body.substring(start=0, end=close)
  let mut cur = ""
  let mut in_q = false
  for c in span.iter() {
    if c == '"' {
      if in_q {
        if cur != "" {
          out.push(cur)
        }
        cur = ""
      }
      in_q = !in_q
    } else if in_q {
      cur = cur + "\{c}"
    }
  }
  out
}

///|
/// spec.components 策略：数组 = 白名单；对象支持 allow/deny 数组。
pub fn ds_components_policy(spec : String) -> (Array[String], Array[String]) {
  let allow : Array[String] = []
  let deny : Array[String] = []
  if spec.trim() == "" {
    return (allow, deny)
  }
  let pat = "\"components\""
  let pos = match spec.find(pat) {
    None => return (allow, deny)
    Some(p) => p
  }
  let rest = spec.substring(start=pos + pat.length())
  let colon = match rest.find(":") {
    None => return (allow, deny)
    Some(c) => c
  }
  let after = rest.substring(start=colon + 1).trim().to_string()
  if after.has_prefix("[") {
    // 数组形态 = 白名单：直接抽取方括号内的引号 token
    for v in ds_tokens_in_brackets(after).iter() {
      allow.push(v)
    }
    return (allow, deny)
  }
  for v in ds_quoted_list(spec, "allow").iter() {
    allow.push(v)
  }
  for v in ds_quoted_list(spec, "deny").iter() {
    deny.push(v)
  }
  (allow, deny)
}

///|
/// spec 组件白名单/禁用项校验（issue #24 要求 2：规范是生成的第一权威）。
/// 结构组件（root/frame）不参与判定。
pub fn Project::design_spec_component_violations(
  self : Project,
  artboard~ : String,
) -> Array[String] {
  let out : Array[String] = []
  if self.design_spec.trim() == "" {
    return out
  }
  let (allow, deny) = ds_components_policy(self.design_spec)
  if allow.length() == 0 && deny.length() == 0 {
    return out
  }
  match self.artboards.get(artboard) {
    None => ()
    Some(ab) =>
      for id in ab.doc.nodes.keys() {
        if id == ab.doc.root_id {
          continue
        }
        match ab.doc.nodes.get(id) {
          None => ()
          Some(n) => {
            if n.component == "frame" || n.component == "" {
              continue
            }
            let mut banned = false
            for d in deny.iter() {
              if d == n.component {
                banned = true
              }
            }
            if banned {
              out.push("\{json_escape(id)} 组件「\{n.component}」命中 spec 禁用项")
              continue
            }
            if allow.length() > 0 {
              let mut ok = false
              for a in allow.iter() {
                if a == n.component {
                  ok = true
                }
              }
              if !ok {
                out.push("\{json_escape(id)} 组件「\{n.component}」不在 spec 白名单")
              }
            }
          }
        }
      }
  }
  out
}

///|
/// marker 后首个数字（rules[] 结构化阈值解析用：对比度≥N / 触控 N）。
fn ds_number_after_marker(text : String, marker : String) -> Double? {
  let pos = match text.find(marker) {
    None => return None
    Some(p) => p
  }
  let rest = text.substring(start=pos + marker.length())
  let mut digits = ""
  let mut started = false
  for c in rest.iter() {
    if c >= '0' && c <= '9' {
      digits = digits + "\{c}"
      started = true
    } else if c == '.' && started {
      digits = digits + "."
    } else if started {
      break
    } else if c == '>' || c == '=' || c == '≥' || c == ' ' || c == ':' || c == '：' {
      continue
    } else {
      continue
    }
  }
  if digits == "" {
    return None
  }
  match ds_number_value("{\"n\":" + digits + "}", "n") {
    Some(v) => Some(v)
    None => None
  }
}

///|
/// issue #24：norms 阈值画像——一次解析 design_spec 得到三档，供
/// critique/auto_fix/norms 各检测与修复通道共享（消除链上重复解析）。
pub(all) struct NormsProfile {
  radius_base : Double
  contrast_min : Double
  touch_min : Double
}

///|
pub fn Project::norms_profile(self : Project) -> NormsProfile {
  let base = DesignTokens::default()
  let radius_base = match ds_number_value(self.design_spec, "sm") {
    Some(v) => if v > 0.0 { v } else { NORM_RADIUS_BASE }
    None => NORM_RADIUS_BASE
  }
  // 角色标记优先：正文对比度 → 泛化对比度 → 内置
  let contrast_min = match ds_number_after_marker(self.design_spec, "正文对比度") {
    Some(v) => v
    None =>
      match ds_number_after_marker(self.design_spec, "对比度") {
        Some(v) => v
        None => NORM_TEXT_CONTRAST_MIN
      }
  }
  let contrast_min = if contrast_min >= 1.0 && contrast_min <= 21.0 {
    contrast_min
  } else {
    NORM_TEXT_CONTRAST_MIN
  }
  let touch_min = match ds_number_after_marker(self.design_spec, "触控") {
    Some(v) => if v >= 20.0 && v <= 96.0 { v } else { NORM_TOUCH_MIN }
    None => NORM_TOUCH_MIN
  }
  let _ = base.typography
  { radius_base, contrast_min, touch_min, }
}

///|
/// rules[] 中的可读性对比度阈值（issue #24 要求 2：norms 以 spec 为准）。
pub fn Project::design_spec_text_contrast(self : Project) -> Double {
  if self.design_spec.trim() == "" {
    return NORM_TEXT_CONTRAST_MIN
  }
  // 角色标记优先（"正文对比度 4.5" 先于泛化 "对比度 3.0"）——rules 多条
  // 阈值并存时首标记不再覆盖正文档
  match ds_number_after_marker(self.design_spec, "正文对比度") {
    Some(v) => return if v >= 1.0 && v <= 21.0 { v } else { NORM_TEXT_CONTRAST_MIN }
    None => ()
  }
  match ds_number_after_marker(self.design_spec, "对比度") {
    Some(v) => if v >= 1.0 && v <= 21.0 { v } else { NORM_TEXT_CONTRAST_MIN }
    None => NORM_TEXT_CONTRAST_MIN
  }
}

///|
/// rules[] 中的触控目标下限（默认 44）。
pub fn Project::design_spec_touch_min(self : Project) -> Double {
  if self.design_spec.trim() == "" {
    return NORM_TOUCH_MIN
  }
  match ds_number_after_marker(self.design_spec, "触控") {
    Some(v) => if v >= 20.0 && v <= 96.0 { v } else { NORM_TOUCH_MIN }
    None => NORM_TOUCH_MIN
  }
}
