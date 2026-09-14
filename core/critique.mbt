///|
/// AI 设计批评引擎：像资深设计师一样评审原型。
///
/// 不是检查规则（那是 lint），而是基于**设计原则**给出整体评价：
/// 1. 视觉层次 — 有没有清晰的"第一眼看到什么"
/// 2. 亲密性 — 相关元素是否靠近（格式塔原理）
/// 3. 对齐 — 是否有一致的视觉轴线
/// 4. 一致性 — 相似元素是否有相似处理
/// 5. 留白 — 是否有足够的呼吸空间
/// 6. 平衡 — 视觉重量是否分布合理
/// 7. 焦点 — 是否有明确的主动作（CTA）
/// 8. 节奏 — 间距和尺寸是否有韵律感
///
/// 输出：结构化评审报告（每个原则一个评分 + 具体建议）
pub(all) struct CritiqueResult {
  principle : String
  score : Int // 0-10
  verdict : String // "good" | "fair" | "poor"
  observation : String // 观察到什么
  advice : String // 怎么改
}

///|
/// 综合评审：对画板进行 8 项设计原则评审
pub fn Project::critique(
  self : Project,
  artboard~ : String,
) -> Result[String, String] {
  match self.artboards.get(artboard) {
    None => Err("unknown_artboard")
    Some(ab) => {
      let results : Array[String] = []
      let layout = solve(ab.doc)
      let doc = ab.doc

      // ── 1. 视觉层次 ──
      let font_sizes : Map[Double, Int] = Map::new()
      for id in doc.nodes.keys() {
        match doc.nodes.get(id) {
          Some(n) =>
            match font_sizes.get(n.style.font_size) {
              Some(c) => font_sizes.set(n.style.font_size, c + 1)
              None => font_sizes.set(n.style.font_size, 1)
            }
          None => ()
        }
      }
      let distinct_sizes = font_sizes.size()
      let hierarchy_score = if distinct_sizes >= 3 {
        9
      } else if distinct_sizes == 2 {
        6
      } else {
        3
      }
      let hierarchy_verdict = if hierarchy_score >= 7 {
        "good"
      } else if hierarchy_score >= 5 {
        "fair"
      } else {
        "poor"
      }
      let hierarchy_obs = "\{distinct_sizes} 种字号"
      let hierarchy_advice = if distinct_sizes < 3 {
        "增加字号层次：标题用 h2/h3，正文用 body，辅助信息用 caption"
      } else {
        "层次清晰"
      }
      results.push(
        crit_json(
          "visual_hierarchy", hierarchy_score, hierarchy_verdict, hierarchy_obs,
          hierarchy_advice,
        ),
      )

      // ── 2. 亲密性（Gestalt）──
      let mut tight_groups = 0
      let mut total_groups = 0
      for id in doc.nodes.keys() {
        match doc.nodes.get(id) {
          Some(n) =>
            if n.children.length() > 1 {
              total_groups = total_groups + 1
              match n.layout {
                Some(l) => if l.gap < 4.0 { tight_groups = tight_groups + 1 }
                None => ()
              }
            }
          None => ()
        }
      }
      let prox_score = if total_groups == 0 {
        5
      } else if tight_groups == 0 {
        8
      } else if tight_groups <= total_groups / 2 {
        6
      } else {
        3
      }
      let prox_verdict = if prox_score >= 7 {
        "good"
      } else if prox_score >= 5 {
        "fair"
      } else {
        "poor"
      }
      results.push(
        crit_json(
          "proximity",
          prox_score,
          prox_verdict,
          "\{tight_groups}/\{total_groups} 容器间距过紧",
          "确保相关元素间距 ≥ 8px，不相关元素间距 ≥ 24px",
        ),
      )

      // ── 3. 对齐 ──
      let mut aligned_count = 0
      let mut total_check = 0
      for id in doc.nodes.keys() {
        match layout.rect_of(id) {
          Some(r) =>
            if id != "root" {
              total_check = total_check + 1
              // 检查左边缘是否对齐到 8px 网格
              if r.x % 8.0 < 1.0 || r.x % 8.0 > 7.0 {
                aligned_count = aligned_count + 1
              }
            }
          None => ()
        }
      }
      let align_score = if total_check == 0 {
        5
      } else {
        aligned_count * 10 / total_check
      }
      let align_verdict = if align_score >= 7 {
        "good"
      } else if align_score >= 5 {
        "fair"
      } else {
        "poor"
      }
      results.push(
        crit_json(
          "alignment",
          align_score,
          align_verdict,
          "\{aligned_count}/\{total_check} 节点对齐到网格",
          "运行 snap_to_grid(8) 统一对齐",
        ),
      )

      // ── 4. 一致性（颜色）──
      let mut token_count = 0
      let mut color_count = 0
      for id in doc.nodes.keys() {
        match doc.nodes.get(id) {
          Some(n) =>
            if n.style.fill != "none" && n.style.fill != "" {
              color_count = color_count + 1
              if is_token_color3(self.tokens, n.style.fill) {
                token_count = token_count + 1
              }
            }
          None => ()
        }
      }
      let cons_score = if color_count == 0 {
        7
      } else {
        token_count * 10 / color_count
      }
      let cons_verdict = if cons_score >= 7 {
        "good"
      } else if cons_score >= 5 {
        "fair"
      } else {
        "poor"
      }
      results.push(
        crit_json(
          "consistency",
          cons_score,
          cons_verdict,
          "\{token_count}/\{color_count} 颜色使用令牌",
          "运行 audit_design_system 查看硬编码颜色",
        ),
      )

      // ── 5. 留白 ──
      let node_count = doc.nodes.size() - 1
      let area = ab.width * ab.height
      let density = if area > 0.0 {
        node_count.to_double() / (area / 10000.0)
      } else {
        0.0
      }
      let white_score = if density < 2.0 {
        9
      } else if density < 4.0 {
        7
      } else if density < 6.0 {
        5
      } else {
        3
      }
      let white_verdict = if white_score >= 7 {
        "good"
      } else if white_score >= 5 {
        "fair"
      } else {
        "poor"
      }
      results.push(
        crit_json(
          "whitespace",
          white_score,
          white_verdict,
          "密度 \{density.to_string()} 节点/万px²",
          if density > 4.0 {
            "减少元素或增大画板"
          } else {
            "留白充分"
          },
        ),
      )

      // ── 6. 平衡 ──
      let mut left_weight = 0.0
      let mut right_weight = 0.0
      for id in doc.nodes.keys() {
        match layout.rect_of(id) {
          Some(r) =>
            if id != "root" {
              let center_x = r.x + r.width / 2.0
              let weight = r.width * r.height
              if center_x < ab.width / 2.0 {
                left_weight = left_weight + weight
              } else {
                right_weight = right_weight + weight
              }
            }
          None => ()
        }
      }
      let total_w = left_weight + right_weight
      let balance_ratio = if total_w > 0.0 {
        left_weight / total_w
      } else {
        0.5
      }
      let bal_score = if balance_ratio > 0.3 && balance_ratio < 0.7 {
        8
      } else if balance_ratio > 0.2 && balance_ratio < 0.8 {
        6
      } else {
        4
      }
      let bal_verdict = if bal_score >= 7 {
        "good"
      } else if bal_score >= 5 {
        "fair"
      } else {
        "poor"
      }
      let left_pct = (balance_ratio * 100.0).to_int().to_string()
      let right_pct = ((1.0 - balance_ratio) * 100.0).to_int().to_string()
      let bal_obs = "左" + left_pct + "% / 右" + right_pct + "%"
      let bal_advice = if bal_score < 6 {
        "调整元素分布使左右视觉重量更均衡"
      } else {
        "平衡良好"
      }
      results.push(
        crit_json("balance", bal_score, bal_verdict, bal_obs, bal_advice),
      )

      // ── 7. 焦点 ──
      let mut has_primary_cta = false
      let mut button_count = 0
      for id in doc.nodes.keys() {
        match doc.nodes.get(id) {
          Some(n) =>
            if n.component == "button" {
              button_count = button_count + 1
              if n.style.fill == self.tokens.resolve_color("primary") {
                has_primary_cta = true
              }
            }
          None => ()
        }
      }
      let focus_score = if has_primary_cta && button_count <= 3 {
        9
      } else if has_primary_cta {
        6
      } else if button_count > 0 {
        4
      } else {
        5
      }
      let focus_verdict = if focus_score >= 7 {
        "good"
      } else if focus_score >= 5 {
        "fair"
      } else {
        "poor"
      }
      results.push(
        crit_json(
          "focus",
          focus_score,
          focus_verdict,
          "\{button_count} 个按钮, 主CTA: \{has_primary_cta}",
          if !has_primary_cta {
            "为最重要的操作使用 primary 变体按钮"
          } else {
            "焦点明确"
          },
        ),
      )

      // ── 8. 节奏 ──
      let gaps : Map[Double, Int] = Map::new()
      for id in doc.nodes.keys() {
        match doc.nodes.get(id) {
          Some(n) =>
            match n.layout {
              Some(l) =>
                match gaps.get(l.gap) {
                  Some(c) => gaps.set(l.gap, c + 1)
                  None => gaps.set(l.gap, 1)
                }
              None => ()
            }
          None => ()
        }
      }
      let distinct_gaps = gaps.size()
      let rhythm_score = if distinct_gaps <= 3 {
        8
      } else if distinct_gaps <= 5 {
        6
      } else {
        4
      }
      let rhythm_verdict = if rhythm_score >= 7 {
        "good"
      } else if rhythm_score >= 5 {
        "fair"
      } else {
        "poor"
      }
      results.push(
        crit_json(
          "rhythm",
          rhythm_score,
          rhythm_verdict,
          "\{distinct_gaps} 种间距值",
          if distinct_gaps > 3 {
            "统一间距到标准令牌（4/8/12/16/24）"
          } else {
            "节奏统一"
          },
        ),
      )

      let j = jstr19(results)
      Ok("{\"principles\":8,\"results\":[\{j}]}")
    }
  }
}

///|
/// 评审摘要（一行）
pub fn Project::critique_summary(
  self : Project,
  artboard~ : String,
) -> Result[String, String] {
  match self.critique(artboard~) {
    Err(e) => Err(e)
    Ok(json) => {
      // 计算平均分
      let scores = extract_scores(json)
      let total = sum_scores(scores)
      let avg = if scores.length() > 0 { total / scores.length() } else { 0 }
      let grade = if avg >= 8 {
        "A"
      } else if avg >= 6 {
        "B"
      } else if avg >= 4 {
        "C"
      } else {
        "D"
      }
      Ok("Design Critique: \{grade} (\{avg}/10)")
    }
  }
}

///|
fn crit_json(
  principle : String,
  score : Int,
  verdict : String,
  obs : String,
  advice : String,
) -> String {
  "{\"principle\":\"\{principle}\",\"score\":\{score},\"verdict\":\"\{verdict}\",\"observation\":\"\{obs}\",\"advice\":\"\{advice}\"}"
}

///|
fn is_token_color3(tokens : DesignTokens, hex : String) -> Bool {
  for k in tokens.colors.keys() {
    match tokens.colors.get(k) {
      Some(v) => if v == hex { return true }
      None => ()
    }
  }
  false
}

///|
fn extract_scores(json : String) -> Array[Int] {
  let scores : Array[Int] = []
  let parts = json.split(",\"score\":")
  for p0 in parts.iter() {
    let p = p0.to_string()
    let num = extract_leading_int(p)
    if num >= 0 {
      scores.push(num)
    }
  }
  scores
}

///|
fn extract_leading_int(s : String) -> Int {
  let mut result = 0
  let mut found = false
  for c in s.iter() {
    let code = c.to_int()
    if code >= 48 && code <= 57 {
      result = result * 10 + (code - 48)
      found = true
    } else if found {
      break
    }
  }
  if found {
    result
  } else {
    -1
  }
}

///|
fn sum_scores(scores : Array[Int]) -> Int {
  let mut total = 0
  for s in scores.iter() {
    total = total + s
  }
  total
}

///|
fn jstr19(parts : Array[String]) -> String {
  let sb = StringBuilder::new()
  for i in 0..<parts.length() {
    if i > 0 {
      sb.write_string(",")
    }
    sb.write_string(parts[i])
  }
  sb.to_string()
}
