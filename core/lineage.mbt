/// 组件血缘追踪：改了一个令牌，哪些节点会受影响？
///
/// 这是"设计系统治理"的核心能力：
/// - token_lineage("primary") → 所有使用 primary 色的节点
/// - component_lineage("button") → 所有 button 实例所在的画板
/// - impact_analysis(NodePatch) → 如果应用这个补丁，会改什么
///
/// Agent 在修改前调用 impact_analysis 预览影响范围。

// ---------------------------------------------------------------------------
// 令牌血缘
// ---------------------------------------------------------------------------

///|
/// 查找使用指定颜色令牌的所有节点
pub fn Project::token_lineage(
  self : Project,
  token_name~ : String,
) -> Result[String, String] {
  let hex = self.tokens.resolve_color(token_name)
  let usages : Array[String] = []
  for ab_id in self.artboards.keys() {
    match self.artboards.get(ab_id) {
      Some(ab) =>
        for node_id in ab.doc.nodes.keys() {
          match ab.doc.nodes.get(node_id) {
            Some(n) =>
              if n.style.fill == hex ||
                n.style.text_color == hex ||
                n.style.stroke == hex {
                usages.push(
                  "{\"artboard\":\"\{ab_id}\",\"node\":\"\{node_id}\",\"component\":\"\{n.component}\",\"field\":\"\{style_field(n, hex)}\"}",
                )
              }
            None => ()
          }
        }
      None => ()
    }
  }
  let j = jstr15(usages)
  Ok(
    "{\"token\":\"\{token_name}\",\"hex\":\"\{hex}\",\"usage_count\":\{usages.length()},\"usages\":[\{j}]}",
  )
}

///|
fn style_field(n : Node, hex : String) -> String {
  if n.style.fill == hex {
    "fill"
  } else if n.style.text_color == hex {
    "text_color"
  } else {
    "stroke"
  }
}

// ---------------------------------------------------------------------------
// 组件血缘
// ---------------------------------------------------------------------------

///|
/// 查找指定组件类型的所有实例
pub fn Project::component_lineage(
  self : Project,
  component_id~ : String,
) -> Result[String, String] {
  let instances : Array[String] = []
  for ab_id in self.artboards.keys() {
    match self.artboards.get(ab_id) {
      Some(ab) =>
        for node_id in ab.doc.nodes.keys() {
          match ab.doc.nodes.get(node_id) {
            Some(n) =>
              if n.component == component_id {
                let layout = solve(ab.doc)
                let rect_str = match layout.rect_of(node_id) {
                  Some(r) =>
                    "(\{r.x.to_int()},\{r.y.to_int()}) \{r.width.to_int()}×\{r.height.to_int()}"
                  None => "unsolved"
                }
                instances.push(
                  "{\"artboard\":\"\{ab_id}\",\"node\":\"\{node_id}\",\"name\":\"\{n.name}\",\"rect\":\"\{rect_str}\"}",
                )
              }
            None => ()
          }
        }
      None => ()
    }
  }
  let j = jstr15(instances)
  Ok(
    "{\"component\":\"\{component_id}\",\"instance_count\":\{instances.length()},\"instances\":[\{j}]}",
  )
}

// ---------------------------------------------------------------------------
// 变更影响分析
// ---------------------------------------------------------------------------

///|
/// 预览：如果对某个节点应用补丁，会产生什么影响
pub fn Project::impact_analysis(
  self : Project,
  artboard~ : String,
  node_id~ : String,
  patch~ : NodePatch,
) -> Result[String, String] {
  match self.artboards.get(artboard) {
    None => Err("unknown_artboard")
    Some(ab) =>
      match ab.doc.nodes.get(node_id) {
        None => Err("unknown_node: \{node_id}")
        Some(n) => {
          let impacts : Array[String] = []
          // 颜色变更影响
          match patch.fill {
            Some(new_fill) => {
              let resolved = self.tokens.resolve_color(new_fill)
              if n.style.fill != resolved {
                impacts.push(
                  "{\"type\":\"style\",\"field\":\"fill\",\"before\":\"\{n.style.fill}\",\"after\":\"\{resolved}\"}",
                )
                // 检查子节点文字对比度
                let fg = n.style.text_color
                let ratio = contrast_ratio(fg, resolved)
                if ratio < 4.5 {
                  impacts.push(
                    "{\"type\":\"accessibility\",\"warning\":\"文字对比度将降至 \{ratio.to_string()}（低于 4.5:1）\",\"suggestion\":\"同时更新 text_color\"}",
                  )
                }
              }
            }
            None => ()
          }
          // 尺寸变更影响
          match (patch.width, patch.height) {
            (Some(new_w), Some(new_h)) => {
              let layout = solve(ab.doc)
              match layout.rect_of(node_id) {
                Some(r) => {
                  let new_w_val = spec_val(new_w)
                  let new_h_val = spec_val(new_h)
                  if new_w_val != r.width || new_h_val != r.height {
                    impacts.push(
                      "{\"type\":\"layout\",\"field\":\"size\",\"before\":\"\{r.width.to_int()}×\{r.height.to_int()}\",\"after\":\"...\"}",
                    )
                    // 检查是否会导致溢出
                    match layout.rect_of("root") {
                      Some(root_r) => {
                        let new_right = r.x + new_w_val
                        let new_bottom = r.y + new_h_val
                        if new_right > root_r.right() ||
                          new_bottom > root_r.bottom() {
                          impacts.push(
                            "{\"type\":\"predicate\",\"warning\":\"尺寸变更将导致 contained_in_parent 违规\",\"suggestion\":\"auto_fix 可自动处理\"}",
                          )
                        }
                      }
                      None => ()
                    }
                  }
                }
                None => ()
              }
            }
            _ => ()
          }
          // 位置变更影响
          match (patch.x, patch.y) {
            (Some(_), _) | (_, Some(_)) =>
              impacts.push(
                "{\"type\":\"layout\",\"field\":\"position\",\"note\":\"位置变更可能影响兄弟节点间距和对齐\"}",
              )
            _ => ()
          }
          let j = jstr15(impacts)
          Ok(
            "{\"node\":\"\{node_id}\",\"impact_count\":\{impacts.length()},\"impacts\":[\{j}]}",
          )
        }
      }
  }
}

// ---------------------------------------------------------------------------
// 设计系统审计
// ---------------------------------------------------------------------------

///|
/// 审计整个项目：找出所有偏离设计系统的硬编码值
pub fn Project::audit_design_system(self : Project) -> String {
  let issues : Array[String] = []
  for ab_id in self.artboards.keys() {
    match self.artboards.get(ab_id) {
      Some(ab) =>
        for node_id in ab.doc.nodes.keys() {
          match ab.doc.nodes.get(node_id) {
            Some(n) => {
              // 检查填充色
              if n.style.fill != "none" && n.style.fill != "" {
                if !is_token_color2(self.tokens, n.style.fill) {
                  match nearest_token2(self.tokens, n.style.fill) {
                    Some((token_name, _)) =>
                      issues.push(
                        "{\"artboard\":\"\{ab_id}\",\"node\":\"\{node_id}\",\"field\":\"fill\",\"current\":\"\{n.style.fill}\",\"suggested_token\":\"\{token_name}\"}",
                      )
                    None =>
                      issues.push(
                        "{\"artboard\":\"\{ab_id}\",\"node\":\"\{node_id}\",\"field\":\"fill\",\"current\":\"\{n.style.fill}\",\"suggested_token\":null}",
                      )
                  }
                }
              }
              // 检查字号
              let standard_sizes = [
                10.0, 12.0, 14.0, 16.0, 20.0, 24.0, 32.0, 48.0,
              ]
              let is_standard = standard_sizes
                .iter()
                .any(fn(s) { s == n.style.font_size })
              if !is_standard && n.style.font_size != 14.0 {
                let nearest_size = nearest_in_list(
                  standard_sizes,
                  n.style.font_size,
                )
                issues.push(
                  "{\"artboard\":\"\{ab_id}\",\"node\":\"\{node_id}\",\"field\":\"font_size\",\"current\":\{n.style.font_size},\"suggested\":\{nearest_size}}",
                )
              }
            }
            None => ()
          }
        }
      None => ()
    }
  }
  let j = jstr15(issues)
  "{\"total_issues\":\{issues.length()},\"issues\":[\{j}]}"
}

///|
fn is_token_color2(tokens : DesignTokens, hex : String) -> Bool {
  for k in tokens.colors.keys() {
    match tokens.colors.get(k) {
      Some(v) => if v == hex { return true }
      None => ()
    }
  }
  false
}

///|
fn nearest_token2(tokens : DesignTokens, hex : String) -> (String, String)? {
  let target = parse_hex_rgb2(hex)
  let mut best : (String, String)? = None
  let mut best_dist = 999999.0
  for k in tokens.colors.keys() {
    match tokens.colors.get(k) {
      Some(v) => {
        let c = parse_hex_rgb2(v)
        let dist = color_dist2(target, c)
        if dist < best_dist {
          best_dist = dist
          best = Some((k, v))
        }
      }
      None => ()
    }
  }
  if best_dist < 60.0 {
    best
  } else {
    None
  }
}

///|
fn parse_hex_rgb2(hex : String) -> (Double, Double, Double) {
  let body = if hex.length() > 0 && hex.get_char(0) == Some('#') {
    hex.substring(start=1)
  } else {
    hex
  }
  (hex_part2(body, 0), hex_part2(body, 2), hex_part2(body, 4))
}

///|
fn hex_part2(s : String, offset : Int) -> Double {
  if s.length() < offset + 2 {
    return 0.0
  }
  let hi = hdv2(s.get_char(offset))
  let lo = hdv2(s.get_char(offset + 1))
  (hi * 16 + lo).to_double()
}

///|
fn hdv2(c : Char?) -> Int {
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
fn color_dist2(
  a : (Double, Double, Double),
  b : (Double, Double, Double),
) -> Double {
  let dr = a.0 - b.0
  let dg = a.1 - b.1
  let db = a.2 - b.2
  Double::sqrt(dr * dr + dg * dg + db * db)
}

///|
fn nearest_in_list(list : Array[Double], target : Double) -> Double {
  let mut best = list[0]
  let mut best_diff = (target - list[0]).abs()
  for v in list.iter() {
    let d = (target - v).abs()
    if d < best_diff {
      best_diff = d
      best = v
    }
  }
  best
}

///|
fn jstr15(parts : Array[String]) -> String {
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
fn spec_val(s : SizeSpec) -> Double {
  match s {
    Fixed(v) => v
    _ => 0.0
  }
}
