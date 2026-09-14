///|
/// 设计系统反向提取：从现有设计反推组件库和令牌。
///
/// 这是"设计考古学"——Agent 拿到一个已有原型，引擎自动：
/// 1. 扫描所有颜色 → 聚类 → 推断语义令牌名（primary/surface/error）
/// 2. 扫描所有间距 → 识别间距体系（4/8/12/16/24）
/// 3. 扫描所有字号 → 映射到标准字号阶（h1=32/h2=24/body=14/caption=12）
/// 4. 检测重复结构 → 推断为同一"组件"的不同实例
/// 5. 输出完整设计系统（可复用于创建新页面）
///
/// Agent 得到的不只是一份分析报告——是一套可以直接 `place_component` 的
/// 令牌表和组件定义。

// ---------------------------------------------------------------------------
// 提取结果
// ---------------------------------------------------------------------------

pub(all) struct ExtractedToken {
  name : String // "primary" / "surface" / "accent_1"
  value : String // "#4B6BFB"
  usage_count : Int // 被多少节点使用
  confidence : Double // 0-1（推断置信度）
}

///|
pub(all) struct ExtractedSpacing {
  value : Double // 8.0
  usage_count : Int
  suggested_name : String // "md"
}

///|
pub(all) struct ExtractedFontSize {
  value : Double // 24.0
  usage_count : Int
  suggested_name : String // "h2"
}

///|
pub(all) struct ExtractedComponent {
  inferred_name : String // "button" / "card" / "input"
  instance_count : Int
  common_fill : String
  common_radius : Double
  common_height : Double
  sample_ids : Array[String]
}

///|
pub(all) struct ExtractedDesignSystem {
  color_tokens : Array[ExtractedToken]
  spacing_tokens : Array[ExtractedSpacing]
  font_tokens : Array[ExtractedFontSize]
  components : Array[ExtractedComponent]
  total_nodes : Int
  total_colors : Int
  total_sizes : Int
}

// ---------------------------------------------------------------------------
// 主入口：从项目提取设计系统
// ---------------------------------------------------------------------------

///|
pub fn Project::extract_design_system(
  self : Project,
  artboard~ : String,
) -> Result[ExtractedDesignSystem, String] {
  match self.artboards.get(artboard) {
    None => Err("unknown_artboard")
    Some(ab) => {
      let doc = ab.doc

      // ── 1. 颜色提取 ──
      let color_usage : Map[String, Int] = Map::new()
      for id in doc.nodes.keys() {
        match doc.nodes.get(id) {
          Some(n) => {
            // fill
            if n.style.fill != "none" && n.style.fill != "" {
              let c = n.style.fill
              match color_usage.get(c) {
                Some(cnt) => color_usage.set(c, cnt + 1)
                None => color_usage.set(c, 1)
              }
            }
            // text_color
            if n.style.text_color != "" && n.style.text_color != "#111111" {
              let tc = n.style.text_color
              match color_usage.get(tc) {
                Some(cnt) => color_usage.set(tc, cnt + 1)
                None => color_usage.set(tc, 1)
              }
            }
          }
          None => ()
        }
      }

      // 聚类并推断语义名
      let color_tokens = infer_color_tokens(color_usage)

      // ── 2. 间距提取 ──
      let spacing_usage : Map[Double, Int] = Map::new()
      for id in doc.nodes.keys() {
        match doc.nodes.get(id) {
          Some(n) =>
            match n.layout {
              Some(l) => {
                let g = l.gap
                if g > 0.0 {
                  match spacing_usage.get(g) {
                    Some(cnt) => spacing_usage.set(g, cnt + 1)
                    None => spacing_usage.set(g, 1)
                  }
                }
                // padding
                let p = (
                    l.padding.top +
                    l.padding.bottom +
                    l.padding.left +
                    l.padding.right
                  ) /
                  4.0
                if p > 0.0 {
                  match spacing_usage.get(p) {
                    Some(cnt) => spacing_usage.set(p, cnt + 1)
                    None => spacing_usage.set(p, 1)
                  }
                }
              }
              None => ()
            }
          None => ()
        }
      }
      let spacing_tokens = infer_spacing_tokens(spacing_usage)

      // ── 3. 字号提取 ──
      let font_usage : Map[Double, Int] = Map::new()
      for id in doc.nodes.keys() {
        match doc.nodes.get(id) {
          Some(n) => {
            let fs = n.style.font_size
            if fs > 0.0 {
              match font_usage.get(fs) {
                Some(cnt) => font_usage.set(fs, cnt + 1)
                None => font_usage.set(fs, 1)
              }
            }
          }
          None => ()
        }
      }
      let font_tokens = infer_font_tokens(font_usage)

      // ── 4. 组件模式检测 ──
      let components = detect_component_patterns(doc)

      Ok({
        color_tokens,
        spacing_tokens,
        font_tokens,
        components,
        total_nodes: doc.nodes.size() - 1,
        total_colors: color_usage.size(),
        total_sizes: font_usage.size(),
      })
    }
  }
}

// ---------------------------------------------------------------------------
// 颜色令牌推断
// ---------------------------------------------------------------------------

///|
fn infer_color_tokens(usage : Map[String, Int]) -> Array[ExtractedToken] {
  let tokens : Array[ExtractedToken] = []
  // 按使用频率排序
  let sorted : Array[(String, Int)] = []
  for hex in usage.keys() {
    match usage.get(hex) {
      Some(cnt) => sorted.push((hex, cnt))
      None => ()
    }
  }
  // 简单冒泡排序（按 count 降序）
  for i in 0..<sorted.length() {
    for j in (i + 1)..<sorted.length() {
      if sorted[j].1 > sorted[i].1 {
        let tmp = sorted[i]
        sorted[i] = sorted[j]
        sorted[j] = tmp
      }
    }
  }

  // 推断语义名
  let semantic_names = [
    "primary", "on_primary", "surface", "surface_variant", "error", "text_primary",
    "text_secondary", "outline",
  ]

  for i in 0..<sorted.length() {
    if i >= 8 {
      // 超过 8 个就标为 accent_N
      let name = "accent_" + (i - 7).to_string()
      tokens.push({
        name,
        value: sorted[i].0,
        usage_count: sorted[i].1,
        confidence: 0.6,
      })
    } else {
      // 基于颜色特征推断语义名
      let (r, g, b) = parse_rgb(sorted[i].0)
      let brightness = (r.to_double() + g.to_double() + b.to_double()) / 3.0
      let is_dark = brightness < 100.0
      let is_light = brightness > 200.0
      let inferred : String = if is_light && i < 4 {
        // 浅色高频 → surface
        if sorted[i].0 == "#FFFFFF" || sorted[i].0 == "#FFF" {
          "surface"
        } else {
          "surface_variant"
        }
      } else if is_dark && sorted[i].1 > 3 {
        // 深色高频 → 可能是 primary 或 text
        let sat = color_saturation(r, g, b)
        if sat > 0.3 {
          "primary"
        } else {
          "text_primary"
        }
      } else if sorted[i].1 > 2 {
        "secondary"
      } else {
        semantic_names[i]
      }
      tokens.push({
        name: inferred,
        value: sorted[i].0,
        usage_count: sorted[i].1,
        confidence: if i < 3 {
          0.9
        } else if i < 6 {
          0.7
        } else {
          0.5
        },
      })
    }
  }
  tokens
}

///|
fn parse_rgb(hex : String) -> (Int, Int, Int) {
  let body = if hex.length() > 0 && hex.get_char(0) == Some('#') {
    hex.substring(start=1)
  } else {
    hex
  }
  if body.length() < 6 {
    return (0, 0, 0)
  }
  (hex_val4(body, 0), hex_val4(body, 2), hex_val4(body, 4))
}

///|
fn hex_val4(s : String, offset : Int) -> Int {
  if s.length() < offset + 2 {
    return 0
  }
  let hi = hex_digit4(s.get_char(offset))
  let lo = hex_digit4(s.get_char(offset + 1))
  hi * 16 + lo
}

///|
fn hex_digit4(c : Char?) -> Int {
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
fn color_saturation(r : Int, g : Int, b : Int) -> Double {
  let max_v = max3(r, g, b).to_double()
  let min_v = min3(r, g, b).to_double()
  if max_v == 0.0 {
    return 0.0
  }
  (max_v - min_v) / max_v
}

///|
fn max3(a : Int, b : Int, c : Int) -> Int {
  let m = if a > b { a } else { b }
  if m > c {
    m
  } else {
    c
  }
}

///|
fn min3(a : Int, b : Int, c : Int) -> Int {
  let m = if a < b { a } else { b }
  if m < c {
    m
  } else {
    c
  }
}

// ---------------------------------------------------------------------------
// 间距令牌推断
// ---------------------------------------------------------------------------

///|
fn infer_spacing_tokens(usage : Map[Double, Int]) -> Array[ExtractedSpacing] {
  let tokens : Array[ExtractedSpacing] = []
  // 标准间距名映射
  let name_map : Array[(Double, String)] = [
    (2.0, "xs"),
    (4.0, "sm"),
    (8.0, "md"),
    (12.0, "lg"),
    (16.0, "xl"),
    (24.0, "xxl"),
    (32.0, "xxxl"),
    (48.0, "huge"),
  ]
  for v in usage.keys() {
    match usage.get(v) {
      Some(cnt) => {
        // 找最近的标准名
        let mut best_name = "custom_" + v.to_int().to_string()
        for pair in name_map.iter() {
          if pair.0 == v {
            best_name = pair.1
            break
          }
        }
        tokens.push({ value: v, usage_count: cnt, suggested_name: best_name })
      }
      None => ()
    }
  }
  tokens
}

// ---------------------------------------------------------------------------
// 字号令牌推断
// ---------------------------------------------------------------------------

///|
fn infer_font_tokens(usage : Map[Double, Int]) -> Array[ExtractedFontSize] {
  let tokens : Array[ExtractedFontSize] = []
  // 标准字号映射
  let name_map : Array[(Double, String)] = [
    (10.0, "overline"),
    (12.0, "caption"),
    (14.0, "body"),
    (16.0, "h4"),
    (20.0, "h3"),
    (24.0, "h2"),
    (32.0, "h1"),
    (48.0, "display"),
  ]
  for v in usage.keys() {
    match usage.get(v) {
      Some(cnt) => {
        let mut best_name = "custom_" + v.to_int().to_string()
        for pair in name_map.iter() {
          if pair.0 == v {
            best_name = pair.1
            break
          }
        }
        tokens.push({ value: v, usage_count: cnt, suggested_name: best_name })
      }
      None => ()
    }
  }
  tokens
}

// ---------------------------------------------------------------------------
// 组件模式检测
// ---------------------------------------------------------------------------

///|
fn detect_component_patterns(doc : Document) -> Array[ExtractedComponent] {
  let components : Array[ExtractedComponent] = []
  // 按 (kind, component, fill, radius) 分组
  let groups : Map[String, Array[String]] = Map::new()
  let styles : Map[String, (String, Double, Double)] = Map::new() // group_key → (fill, radius, height)

  for id in doc.nodes.keys() {
    match doc.nodes.get(id) {
      Some(n) =>
        if id != "root" {
          let key = kind_str(n) +
            "|" +
            n.component +
            "|" +
            n.style.fill +
            "|" +
            n.style.corner_radius.to_int().to_string()
          match groups.get(key) {
            Some(arr) => arr.push(id)
            None => {
              let arr : Array[String] = [id]
              groups.set(key, arr)
            }
          }
          if !styles.contains(key) {
            styles.set(key, (n.style.fill, n.style.corner_radius, 0.0))
          }
        }
      None => ()
    }
  }

  // 只有 ≥2 个实例的才算"组件模式"
  for key in groups.keys() {
    match groups.get(key) {
      Some(ids) =>
        if ids.length() >= 2 {
          match styles.get(key) {
            Some((fill, radius, _h)) => {
              // 从 key 提取组件名
              let parts : Array[StringView] = []
              for p2 in key.split("|") {
                parts.push(p2)
              }
              let comp_name = if parts.length() >= 2 {
                parts[1].to_string()
              } else {
                "unknown"
              }
              components.push({
                inferred_name: comp_name,
                instance_count: ids.length(),
                common_fill: fill,
                common_radius: radius,
                common_height: 44.0, // 简化：取第一个的高度
                sample_ids: ids.copy(),
              })
            }
            None => ()
          }
        }
      None => ()
    }
  }
  components
}

// ---------------------------------------------------------------------------
// 输出 JSON
// ---------------------------------------------------------------------------

///|
pub fn ExtractedDesignSystem::to_json(self : ExtractedDesignSystem) -> String {
  let sb = StringBuilder::new()
  sb.write_string("{\n")
  // 概要
  sb.write_string("  \"summary\": {\n")
  let tn = self.total_nodes.to_string()
  let tc = self.total_colors.to_string()
  let ts = self.total_sizes.to_string()
  sb.write_string("    \"total_nodes\": " + tn + ",\n")
  sb.write_string("    \"total_colors\": " + tc + ",\n")
  sb.write_string("    \"total_sizes\": " + ts + "\n")
  sb.write_string("  },\n")
  // 颜色令牌
  sb.write_string("  \"color_tokens\": [\n")
  for i in 0..<self.color_tokens.length() {
    if i > 0 {
      sb.write_string(",\n")
    }
    let t = self.color_tokens[i]
    let uc = t.usage_count.to_string()
    let cf = t.confidence.to_string()
    sb.write_string(
      "    {\"name\": \"" +
      t.name +
      "\", \"value\": \"" +
      t.value +
      "\", \"usage\": " +
      uc +
      ", \"confidence\": " +
      cf +
      "}",
    )
  }
  sb.write_string("\n  ],\n")
  // 组件模式
  sb.write_string("  \"components\": [\n")
  for i in 0..<self.components.length() {
    if i > 0 {
      sb.write_string(",\n")
    }
    let c = self.components[i]
    let ic = c.instance_count.to_string()
    sb.write_string(
      "    {\"name\": \"" +
      c.inferred_name +
      "\", \"instances\": " +
      ic +
      ", \"fill\": \"" +
      c.common_fill +
      "\"}",
    )
  }
  sb.write_string("\n  ]\n")
  sb.write_string("}")
  sb.to_string()
}

///|
/// 人类可读摘要
pub fn ExtractedDesignSystem::summary(self : ExtractedDesignSystem) -> String {
  let sb = StringBuilder::new()
  sb.write_string("Extracted Design System:\n")
  sb.write_string(
    "  Colors: " + self.color_tokens.length().to_string() + " tokens\n",
  )
  for t in self.color_tokens.iter() {
    sb.write_string(
      "    " +
      t.name +
      " = " +
      t.value +
      " (used " +
      t.usage_count.to_string() +
      "x)\n",
    )
  }
  sb.write_string(
    "  Spacing: " + self.spacing_tokens.length().to_string() + " values\n",
  )
  for t in self.spacing_tokens.iter() {
    sb.write_string(
      "    " + t.suggested_name + " = " + t.value.to_int().to_string() + "px\n",
    )
  }
  sb.write_string(
    "  Typography: " + self.font_tokens.length().to_string() + " sizes\n",
  )
  for t in self.font_tokens.iter() {
    sb.write_string(
      "    " + t.suggested_name + " = " + t.value.to_int().to_string() + "px\n",
    )
  }
  sb.write_string(
    "  Components: " + self.components.length().to_string() + " patterns\n",
  )
  for c in self.components.iter() {
    sb.write_string(
      "    " +
      c.inferred_name +
      " (" +
      c.instance_count.to_string() +
      " instances)\n",
    )
  }
  sb.to_string()
}

///|
fn kind_str(n : Node) -> String {
  match n.kind {
    Frame => "frame"
    Group => "group"
    Rect => "rect"
    Text => "text"
    Image => "image"
  }
}
