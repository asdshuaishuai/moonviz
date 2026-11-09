///|
/// 设计文档 → 设计规范提取（0.2 规范流程的入口）。
///
/// 契约：需求方给出「设计文档」（markdown / 纯文本：配色表、字号表、圆角、
/// 间距、动效、触控要求），引擎用确定性关键词 + 数值扫描把文档提取成
/// JSON 设计规范（spec），并标注提取来源。**引擎不猜**：文档缺关键项
/// （主色/背景/正文色/正文字号/圆角）时返回 gaps，由 Agent 补齐文档或
/// 与需求方确认——generate_from_doc 会以 gaps 拒绝生成。
///
/// 提取规则（确定性）：
/// - 颜色：文档中每个 #RRGGBB 按**同一行**的关键词归类
///   （主色/品牌/primary、背景/background、卡片/surface、正文/text、
///   次要文字/muted、辅助色/secondary、信息/info、警告/warning、
///   错误/危险/danger、次级背景/surfaceVariant）；
/// - 字号：含「字号/font/type」的行内数字按角色词归类
///   （正文/body、标题/h1、说明/caption），未标注角色的数字进字号阶；
/// - 圆角：含「圆角/radius」的行内数字排序后映射 sm/md/lg；
/// - 间距：文档提到 8pt / 4 的倍数 / 间距时落标准四档；
/// - 动效：含「动效/动画/motion/时长」的行内数字按升序映射 fast/base/slow；
/// - 触控：提到「触控/44」时写入 rules。
pub(all) struct DesignDocExtract {
  /// 提取出的 spec JSON（含 "source":"design_doc"）
  spec_json : String
  /// 已提取项清单（信封可见，Agent 可核对）
  extracted : Array[String]
  /// 缺失的关键项（非空时 generate_from_doc 拒绝生成）
  gaps : Array[String]
}

///|
/// 行内是否出现任一关键词（不区分大小写的子串）。
fn dd_has(s : String, kws : Array[String]) -> Bool {
  let lower = s.to_lower()
  for k in kws.iter() {
    if lower.contains(k) {
      return true
    }
  }
  false
}

///|
/// 扫描行内全部 #RRGGBB（hex 归一为小写 #rrggbb）。
fn dd_hexes(line : String) -> Array[String] {
  let out : Array[String] = []
  let chars = line.to_array()
  let mut i = 0
  while i + 7 <= chars.length() {
    if chars[i] == '#' {
      let mut ok = true
      let sb = StringBuilder::new()
      sb.write_char('#')
      let mut j = 1
      while j <= 6 {
        let c = chars[i + j]
        let code = c.to_int()
        let is_hex = (code >= 48 && code <= 57) ||
          (code >= 65 && code <= 70) ||
          (code >= 97 && code <= 102)
        if !is_hex {
          ok = false
          break
        }
        sb.write_char(c)
        j = j + 1
      }
      if ok {
        out.push(sb.to_string().to_lower())
        i = i + 7
        continue
      }
    }
    i = i + 1
  }
  out
}

///|
/// 扫描行内非负整数（忽略小数尾巴；只取 1~3 位，够覆盖字号/圆角/时长）。
fn dd_numbers(line : String) -> Array[Double] {
  let out : Array[Double] = []
  let chars = line.to_array()
  let mut i = 0
  while i < chars.length() {
    let code = chars[i].to_int()
    if code >= 48 && code <= 57 {
      let mut v = 0
      let mut j = i
      let mut digits = 0
      while j < chars.length() && digits < 4 {
        let c2 = chars[j].to_int()
        if c2 >= 48 && c2 <= 57 {
          v = v * 10 + (c2 - 48)
          j = j + 1
          digits = digits + 1
        } else {
          break
        }
      }
      // 跳过小数尾巴（如 1.5 只取 1）
      if j < chars.length() && chars[j] == '.' {
        j = j + 1
        while j < chars.length() {
          let c3 = chars[j].to_int()
          if c3 >= 48 && c3 <= 57 {
            j = j + 1
          } else {
            break
          }
        }
      }
      out.push(v.to_double())
      i = j
      continue
    }
    i = i + 1
  }
  out
}

///|
/// 将数值数组升序去重。
fn dd_sorted_unique(vals : Array[Double]) -> Array[Double] {
  let out : Array[Double] = []
  for v in vals.iter() {
    let mut dup = false
    for x in out.iter() {
      if x == v {
        dup = true
      }
    }
    if !dup {
      out.push(v)
    }
  }
  let n = out.length()
  for a in 0..<n {
    for b in 0..<(n - 1 - a) {
      if out[b] > out[b + 1] {
        let tmp = out[b]
        out[b] = out[b + 1]
        out[b + 1] = tmp
      }
    }
  }
  out
}

///|
/// 从设计文档提取设计规范。缺失关键项只进 gaps，不用引擎默认值顶替。
pub fn design_doc_extract(doc : String) -> DesignDocExtract {
  let palette : Map[String, String] = Map::new()
  let extracted : Array[String] = []
  let gaps : Array[String] = []
  let typography : Map[String, Double] = Map::new()
  let scale : Array[Double] = []
  let radii : Array[Double] = []
  let motion_nums : Array[Double] = []
  let mut spacing_ok = false
  let mut touch_ok = false
  // 关键词表（行内匹配，与角色同名 lowercase）
  let role_kws : Array[(String, Array[String])] = [
    ("primary", ["主色", "品牌色", "品牌", "primary", "brand"]),
    ("secondary", ["辅助色", "次要品牌", "secondary"]),
    ("info", ["信息色", "提示色", "info"]),
    ("warning", ["警告", "warning"]),
    ("error", ["错误", "危险", "error", "danger"]),
    ("success", ["成功", "success"]),
    ("background", ["背景", "画布", "background", "canvas"]),
    ("surface", ["卡片", "卡面", "surface"]),
    ("surface_variant", ["次级背景", "输入底", "surfacevariant", "surface variant"]),
    ("text_primary", ["正文", "文字", "text", "foreground"]),
    ("text_secondary", ["次要文字", "辅助文字", "muted", "secondary text"]),
  ]
  // 章节状态：设计文档普遍是「标题 + 条目」结构（## 字号 / - 正文 15），
  // 条目不重复章节词——按标题切换上下文，条目继承；标题外的行内关键词
  // 仍然生效（单行式文档同样可提取）
  let mut sec_type = false
  let mut sec_radius = false
  let mut sec_motion = false
  let mut sec_spacing = false
  let mut sec_touch = false
  for raw in doc.split("\n").iter() {
    let line = raw.trim().to_string()
    if line == "" {
      continue
    }
    if line.has_prefix("#") || line.has_prefix("**") {
      sec_type = dd_has(line, ["字号", "字体", "font", "typography", "type"])
      sec_radius = dd_has(line, ["圆角", "radius"])
      sec_motion = dd_has(line, ["动效", "动画", "motion", "时长", "duration"])
      sec_spacing = dd_has(line, ["间距", "spacing", "grid", "栅格"])
      sec_touch = dd_has(line, ["交互", "触控", "touch"])
      continue
    }
    // 1) 颜色归类
    let hexes = dd_hexes(line)
    if hexes.length() > 0 {
      for h in hexes.iter() {
        let mut assigned = false
        for pair in role_kws.iter() {
          let (role, kws) = pair
          if dd_has(line, kws) {
            if !palette.contains(role) {
              palette.set(role, h)
              extracted.push("color:\{role}=\{h}")
            }
            assigned = true
            break
          }
        }
        if !assigned && !palette.contains("primary") {
          palette.set("primary", h)
          extracted.push("color:primary=\{h}")
        }
      }
    }
    // 2) 字号
    if sec_type || dd_has(line, ["字号", "font", "type scale", "typography"]) {
      let nums = dd_numbers(line)
      for n in nums.iter() {
        if n < 8.0 || n > 72.0 {
          continue
        }
        if dd_has(line, ["正文", "body"]) {
          if !typography.contains("body") {
            typography.set("body", n)
            extracted.push("type:body=\{n.to_int()}")
          }
        } else if dd_has(line, ["标题", "h1", "heading"]) {
          if !typography.contains("h1") {
            typography.set("h1", n)
            extracted.push("type:h1=\{n.to_int()}")
          }
        } else if dd_has(line, ["说明", "caption", "注释"]) {
          if !typography.contains("caption") {
            typography.set("caption", n)
            extracted.push("type:caption=\{n.to_int()}")
          }
        } else {
          if scale.length() < 8 && !scale.contains(n) {
            scale.push(n)
          }
        }
      }
    }
    // 3) 圆角
    if sec_radius || dd_has(line, ["圆角", "radius"]) {
      for n in dd_numbers(line).iter() {
        if n >= 0.0 && n <= 48.0 && !radii.contains(n) {
          radii.push(n)
        }
      }
    }
    // 4) 间距
    if sec_spacing || dd_has(line, ["8pt", "4 的倍数", "4的倍数", "间距", "spacing", "grid"]) {
      spacing_ok = true
    }
    // 5) 动效
    if sec_motion || dd_has(line, ["动效", "动画", "motion", "时长", "duration"]) {
      for n in dd_numbers(line).iter() {
        if n >= 60.0 && n <= 1000.0 && !motion_nums.contains(n) {
          motion_nums.push(n)
        }
      }
    }
    // 6) 触控
    if sec_touch || dd_has(line, ["触控", "44", "touch"]) {
      touch_ok = true
    }
  }
  // 字号阶补齐：显式角色之外的数字按升序兜底
  let sorted_scale = dd_sorted_unique(scale)
  if !typography.contains("body") && sorted_scale.length() > 0 {
    typography.set("body", sorted_scale[0])
    extracted.push("type:body=\{sorted_scale[0].to_int()}")
  }
  // 圆角三档
  let rs = dd_sorted_unique(radii)
  let mut r_sm = 0.0
  let mut r_md = 0.0
  let mut r_lg = 0.0
  let mut has_radius = false
  if rs.length() >= 3 {
    r_sm = rs[0]
    r_md = rs[rs.length() / 2]
    r_lg = rs[rs.length() - 1]
    has_radius = true
    extracted.push("radius:\{r_sm.to_int()}/\{r_md.to_int()}/\{r_lg.to_int()}")
  } else if rs.length() == 1 {
    r_sm = rs[0]
    r_md = rs[0]
    r_lg = rs[0]
    has_radius = true
    extracted.push("radius:\{r_sm.to_int()}")
  }
  // 动效三档
  let ms = dd_sorted_unique(motion_nums)
  let mut has_motion = false
  let mut m_fast = 120.0
  let mut m_base = 240.0
  let mut m_slow = 360.0
  if ms.length() >= 3 {
    m_fast = ms[0]
    m_base = ms[1]
    m_slow = ms[2]
    has_motion = true
    extracted.push("motion:\{m_fast.to_int()}/\{m_base.to_int()}/\{m_slow.to_int()}")
  } else if ms.length() == 1 {
    m_base = ms[0]
    has_motion = true
    extracted.push("motion:base=\{m_base.to_int()}")
  }
  // 关键项缺口（引擎不猜：主色/背景/正文色/正文字号/圆角）
  if !palette.contains("primary") {
    gaps.push("primary（主色/品牌色）")
  }
  if !palette.contains("background") {
    gaps.push("background（背景/画布）")
  }
  if !palette.contains("text_primary") {
    gaps.push("text（正文/文字色）")
  }
  if !typography.contains("body") {
    gaps.push("typography.body（正文字号）")
  }
  if !has_radius {
    gaps.push("radius（圆角档）")
  }
  // 组装 spec JSON
  let sb = StringBuilder::new()
  sb.write_string("{\"v\":1,\"source\":\"design_doc\",\"palette\":{")
  let role_order = [
    "primary", "secondary", "info", "warning", "error", "success",
    "background", "surface", "surface_variant", "text_primary", "text_secondary",
  ]
  let mut first = true
  for role in role_order.iter() {
    match palette.get(role) {
      Some(h) => {
        if !first {
          sb.write_string(",")
        }
        first = false
        sb.write_string("\"" + role + "\":\"" + h + "\"")
      }
      None => ()
    }
  }
  sb.write_string("},\"typography\":{")
  let t_order = ["display", "h1", "h2", "h3", "h4", "body", "caption"]
  let mut t_first = true
  for role in t_order.iter() {
    match typography.get(role) {
      Some(v) => {
        if !t_first {
          sb.write_string(",")
        }
        t_first = false
        sb.write_string("\"" + role + "\":" + v.to_int().to_string())
      }
      None => ()
    }
  }
  // 未标注角色的字号阶数值兜底进 caption/h4 等档（保守：仅当显式缺位）
  if !typography.contains("h1") && sorted_scale.length() >= 2 {
    let second = sorted_scale[sorted_scale.length() - 1]
    sb.write_string(",\"h1\":" + second.to_int().to_string())
    extracted.push("type:h1=\{second.to_int()}")
  }
  sb.write_string("},\"spacing\":[4,8,12,16,24,32]")
  if spacing_ok {
    extracted.push("spacing:8pt")
  }
  if has_radius {
    sb.write_string(
      ",\"radius\":{\"sm\":" +
      r_sm.to_int().to_string() +
      ",\"md\":" +
      r_md.to_int().to_string() +
      ",\"lg\":" +
      r_lg.to_int().to_string() +
      "}",
    )
  }
  if has_motion {
    sb.write_string(
      ",\"motion\":{\"fast\":" +
      m_fast.to_int().to_string() +
      ",\"base\":" +
      m_base.to_int().to_string() +
      ",\"slow\":" +
      m_slow.to_int().to_string() +
      "}",
    )
  }
  sb.write_string(",\"rules\":[")
  let rules : Array[String] = ["按钮不卡文案", "撞色零容忍"]
  if spacing_ok {
    rules.push("间距取 4 的倍数")
  }
  if touch_ok {
    rules.push("触控目标 44")
  }
  let mut r_first = true
  for r in rules.iter() {
    if !r_first {
      sb.write_string(",")
    }
    r_first = false
    sb.write_string("\"" + r + "\"")
  }
  sb.write_string("]}")
  { spec_json: sb.to_string(), extracted, gaps }
}

///|
/// 强制规范流程入口：从**设计文档**提取 spec 再生成。
///
/// - 文档缺关键项 → `design_doc_spec_gaps:<明细>`（拒绝生成，引擎不猜）；
/// - 提取成功 → 走 generate（spec 第一权威），信封注入
///   `spec_source:"design_doc"` 与 `spec_extracted` 计数——
///   来源可见，Agent 无法把拍脑袋的 spec 伪装成文档提取。
pub fn Project::generate_from_doc(
  self : Project,
  intent_text~ : String,
  doc~ : String,
  name? : String = "",
) -> Result[String, String] {
  let ex = design_doc_extract(doc)
  if ex.gaps.length() > 0 {
    return Err("design_doc_spec_gaps:" + ex.gaps.join("；"))
  }
  match self.generate(spec=ex.spec_json, intent_text~, name~) {
    Err(e) => Err(e)
    Ok(json) =>
      // 单通道信封恒以 {"ok":true 开头——注入来源字段（同 skipped 前缀手术）
      Ok(
        "{\"spec_source\":\"design_doc\",\"spec_extracted\":\{ex.extracted.length()}," +
        json.substring(start=1),
      )
  }
}

///|
/// 规范遵从校验（UI 与交互一起判）：生成物必须完全遵守设计规范文档。
///
/// 四项机械可判：
/// 1. 颜色：一切用色可追溯到 spec 调色板/语义角色（复用
///    `design_spec_color_violations`）；
/// 2. 字号：节点字号必须落在 spec 的 typography 阶上（±0.5）；
/// 3. 圆角：节点圆角必须落在 spec 的 radius 三档 + 0/999（±0.5）；
/// 4. 交互：spec 给了 motion 时，引擎的动效令牌必须与 spec 一致——
///    交互的节拍/缓动来自设计规范，而不是引擎默认（导出/宿主同源）。
pub fn Project::design_spec_compliance(
  self : Project,
  artboard~ : String,
) -> String {
  let violations : Array[String] = []
  let ab = match self.artboards.get(artboard) {
    None => {
      return "{\"ok\":false,\"error\":\"unknown_artboard:\{artboard}\",\"violations\":[]}"
    }
    Some(a) => a
  }
  // 1) 颜色
  for v in self.design_spec_color_violations(artboard~).iter() {
    violations.push("color: " + v)
  }
  // spec 字号阶 / 圆角档
  let type_allowed : Array[Double] = []
  for role in ["display", "h1", "h2", "h3", "h4", "body", "caption"].iter() {
    match ds_number_value(self.design_spec, role) {
      Some(v) => if v > 0.0 {
        type_allowed.push(v)
      }
      None => ()
    }
  }
  let radius_allowed : Array[Double] = [0.0, 999.0]
  for role in ["sm", "md", "lg"].iter() {
    match ds_number_value(self.design_spec, role) {
      Some(v) => if v > 0.0 {
        radius_allowed.push(v)
      }
      None => ()
    }
  }
  let in_set = fn(v : Double, set : Array[Double]) -> Bool {
    for x in set.iter() {
      let d = if v > x { v - x } else { x - v }
      if d <= 0.5 {
        return true
      }
    }
    false
  }
  for id in ab.doc.nodes.keys() {
    if violations.length() >= 12 {
      break
    }
    match ab.doc.nodes.get(id) {
      None => ()
      Some(n) => {
        let is_text = match n.kind {
          Text => true
          _ => false
        }
        if n.text != "" && is_text && type_allowed.length() > 0 &&
          !in_set(n.style.font_size, type_allowed) {
          violations.push(
            "type: \{json_escape(id)} 字号 \{n.style.font_size} 不在规范字号阶",
          )
        }
        if radius_allowed.length() > 3 &&
          !in_set(n.style.corner_radius, radius_allowed) {
          violations.push(
            "radius: \{json_escape(id)} 圆角 \{n.style.corner_radius} 不在规范圆角档",
          )
        }
      }
    }
  }
  // 4) 交互：spec.motion 与引擎动效令牌一致
  for role in ["fast", "base", "slow"].iter() {
    match ds_number_value(self.design_spec, role) {
      Some(spec_ms) =>
        match self.tokens.motion.get(role) {
          Some(tok_ms) =>
            if (spec_ms - tok_ms) > 0.5 || (tok_ms - spec_ms) > 0.5 {
              violations.push(
                "motion: 规范 \{role}=\{spec_ms.to_int()}ms 与动效令牌 \{tok_ms.to_int()}ms 不一致",
              )
            }
          None => violations.push("motion: 动效令牌缺 \{role} 档")
        }
      None => ()
    }
  }
  let ok = violations.length() == 0
  let parts : Array[String] = []
  for v in violations.iter() {
    parts.push("\"" + json_escape(v) + "\"")
  }
  "{\"ok\":\{ok},\"checked\":[\"color\",\"type\",\"radius\",\"motion\"],\"violations\":[" +
  parts.join(",") +
  "]}"
}
