// ---------------------------------------------------------------------------
// issue #24：规范驱动生成（spec 在场 = 第一权威；spec 缺失 = 显式要求）
//
// spec 契约（JSON 字符串，schema 对齐 DESIGN.md 载荷）：
//   { "v":1,
//     "palette": { "primary": "#..", "background": "#..", "surface": "#..",
//                  "text": "#..", "muted": "#..", "danger": "#..", "success": "#.." },
//     "typography": { "display/h1/h2/h3/h4/body/caption/overline": 数字 },
//     "spacing": [..], "radius": { "sm":.., "md":.., "lg":.. },
//     "components": {..}, "rules": [..] }
// 应用语义：调色板 → token 覆盖 + recolor_with 重着色；字号阶 → 节点
// font_size 按默认阶到 spec 阶重映射；圆角档 → 8/10→sm、12→md、16→lg
// （999 保留正圆语义）。规则数组只随信封上报，不做硬编码裁决。
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
    "#4B6BFB"
  }
  "{\"v\":1,\"palette\":{\"primary\":\"" +
  primary +
  "\",\"background\":\"#FFFFFF\",\"surface\":\"#F6F7F9\",\"text\":\"#1A1C1E\",\"muted\":\"#6B7280\",\"danger\":\"#DC2626\",\"success\":\"#16A34A\"},\"typography\":{\"display\":48,\"h1\":32,\"h2\":24,\"h3\":20,\"h4\":16,\"body\":14,\"caption\":12},\"spacing\":[4,8,12,16,24,32],\"radius\":{\"sm\":8,\"md\":12,\"lg\":16},\"rules\":[\"按钮不卡文案（宽≥文案+24）\",\"撞色零容忍\",\"齐缝列表行分隔\",\"触控目标 44\"]}"
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
  for c in after.iter() {
    if c >= '0' && c <= '9' {
      digits = digits + "\{c}"
      seen = true
    } else if c == '.' && seen {
      digits = digits + "."
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
fn ds_token_copy(src : DesignTokens) -> DesignTokens {
  let t : DesignTokens = {
    colors: Map::new(),
    spacing: Map::new(),
    radii: Map::new(),
    typography: Map::new(),
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
        let nr = if r > 7.5 && r < 8.5 {
          sm
        } else if r > 9.5 && r < 10.5 {
          sm
        } else if r > 11.5 && r < 12.5 {
          md
        } else if r > 15.5 && r < 16.5 {
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
/// spec 应用（issue #24）：调色板 → token 覆盖 + 重着色；字号阶/圆角档按
/// spec 规范化。spec 空白 → design_spec_required（不静默兜底）。
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
  // 1) 调色板 → token 覆盖 + 重着色（prior 为当前 tokens 快照）
  let prior = ds_token_copy(self.tokens)
  let mut touched = false
  let roles : Array[(String, String)] = [
    ("primary", "primary"),
    ("background", "background"),
    ("surface", "surface"),
    ("text", "text_primary"),
    ("muted", "text_secondary"),
    ("danger", "error"),
    ("success", "success"),
  ]
  for pair in roles.iter() {
    let (spec_key, token_role) = pair
    match ds_string_value(spec, spec_key) {
      Some(v) =>
        if v != "" && norm_is_hex6(v) {
          match self.set_token(token_role, v) {
            Ok(_) => touched = true
            Err(_) => ()
          }
        }
      None => ()
    }
  }
  if touched {
    let _ = self.recolor_with(self.tokens, prior=Some(prior))
  }
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
