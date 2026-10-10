///|
/// 组件规范（1.0 规范性强化）：弱模型最常产出「能用但不精致」的文档，五类根因：
/// 1. 操作组件宽高刚好卡住文案——没有留白概念，框贴着字
/// 2. 圆角体系混乱——按钮族该「方正圆润」（8px 档）却给 0，或全宽条带圆角顶出屏幕边缘
/// 3. 全宽条/全宽列表该直角却带圆角
/// 4. 齐缝列表行没有行间分割线、没有分组——菜单/设置页十几行裸排下去，
///    与成品列表页（行底发丝线、分组卡片）一眼就是两档
/// 5. **撞色**——文字与背景同色系（黑底黑字/白底白字），完全不可读；
///    用户决策 2026-10-11：严禁高保真背景色和文字同色系，对比度 < 2.0
///    零容忍，auto_fix 按背景亮度把文字翻转到黑/白。另：组件必须横平竖直，
///    rotate 非 90° 倍数归零。
///
/// 定位：**指导与规范，不做硬门**。偏差记入 critique 第 9 维（norms，给 Agent
/// 事后反馈），auto_fix 一键修复（审查-修复循环的执行手）——不改双门语义，
/// 存量文档不产生新视觉债。

///|
/// 操作组件族：承载短文案、点击即动作。文案与边缘必须有留白。
pub fn norm_is_action_component(component : String) -> Bool {
  component == "button" ||
  component == "chip" ||
  component == "tag" ||
  component == "fab"
}

///|
/// 方正圆润族：默认 8px 圆角档（avatar 999 正圆、全宽条 0 不在此列）
pub fn norm_is_rounded_component(component : String) -> Bool {
  component == "button" ||
  component == "chip" ||
  component == "tag" ||
  component == "select" ||
  component == "search_bar" ||
  component == "fab"
}

///|
/// 全宽顶边/底边条与全宽行：占满画板宽度时应当直角（圆角会顶出屏幕边缘）
pub fn norm_is_full_bleed_component(component : String) -> Bool {
  component == "app_bar" ||
  component == "tab_bar" ||
  component == "list_item" ||
  component == "divider"
}

///|
/// 横向留白下限（左右各 12）：与 svg.mbt 渲染层 text pad 同值
pub const NORM_TEXT_PAD_X : Double = 12.0

///|
/// 纵向留白下限（上下各 10）
pub const NORM_TEXT_PAD_Y : Double = 10.0

///|
/// 方正圆润圆角档：按钮族默认 8px
pub const NORM_RADIUS_BASE : Double = 8.0

///|
/// 组件规范一句话（list_components 随条目下发——Agent 选组件时即可见规范，
/// 不必等 critique 事后纠正）。返回 None 的组件不下发该字段。
pub fn component_norm(id : String) -> String? {
  match id {
    "button" =>
      Some(
        "宽 ≥ 文案宽+24（左右各留 12），高 36~48，圆角 8；别让框刚好卡住文字",
      )
    "fab" => Some("56×56，圆角 16；单屏只放一个主操作")
    "chip" => Some("高 28~32，左右留白 ≥10，圆角取 高/2（胶囊）或 8")
    "tag" => Some("高 22~26，左右留白 ≥8，圆角 4~6")
    "select" => Some("高 40~44，圆角 8，右侧留 24 放箭头")
    "search_bar" => Some("高 36~44，圆角取 高/2（胶囊）或 10")
    "list_item" =>
      Some("高 56~76；全宽直角（radius 0）；成排堆叠时行间要有 1px divider 或按功能分组")
    "app_bar" => Some("全宽顶边条：高 44~56，圆角 0")
    "tab_bar" => Some("全宽底边条：高 56~64，圆角 0")
    "avatar" => Some("正圆：radius 999，常用 40/48/56")
    "divider" => Some("全宽 1px，圆角 0")
    _ => None
  }
}

///|
/// 操作组件的高度底线（norm_issues 与 norm_fix_pass 共用，两端不得漂移）：
/// - chip/tag/fab 有 component_norm 下发的独立档位（高 28~32 / 22~26 / 56×56），
///   通用「字号+上下留白」底线会把档内合规件抬出档位——按组件取档下限；
/// - 多行文案按实际行数要高度（文本块高 + 上下留白）——通用档位按单行标签设定。
fn norm_need_h(
  component : String,
  text : String,
  font_size : Double,
  ts : Size,
) -> Double {
  let band = match component {
    "chip" => 28.0
    "tag" => 22.0
    "fab" => 56.0
    _ => font_size + NORM_TEXT_PAD_Y * 2.0
  }
  let mut lines = 1
  for c in text.iter() {
    if c == '\n' {
      lines = lines + 1
    }
  }
  let multi = ts.height + NORM_TEXT_PAD_Y * 2.0
  if lines > 1 && multi > band {
    multi
  } else {
    band
  }
}

///|
/// 检测组件规范偏差，返回人可读问题清单（critique 第 9 维 norms）。
/// 每条自带建议尺寸——Agent 读到就能改，不必自己换算。
/// 顺序即优先级：结构性偏差（列表缺分割线）在前，逐条样式在后；
/// 上限 8 条，控制报告体积（deepDesign 侧检视结果有 12KB 截断）。
pub fn norm_issues(doc : Document, layout : SolvedLayout) -> Array[String] {
  let issues : Array[String] = []
  let root_w = match layout.rect_of(doc.root_id) {
    Some(r) => r.width
    None => 0.0
  }
  // 0) 齐缝列表行连排：整段没有任何分割线/分组（每个 run 报一条）。
  //    结构性问题最影响成品观感，放最前——不被逐条样式问题挤出报告。
  for run in norms_list_runs(doc, layout).iter() {
    if issues.length() >= 8 {
      break
    }
    let first = run.row_ids[0]
    let last = run.row_ids[run.row_ids.length() - 1]
    issues.push(
      "\{json_escape(run.parent_id)} 页 \{run.row_ids.length()} 行列表（\{json_escape(first)}…\{json_escape(last)}）行间无分割线——行间加 1px divider，或用 Frame 按功能分组卡片化（auto_fix 可修）",
    )
  }
  for id in doc.nodes.keys() {
    if issues.length() >= 8 {
      break
    }
    match doc.nodes.get(id) {
      None => ()
      Some(n) =>
        match layout.rect_of(id) {
          None => ()
          Some(r) => {
            // 0) 撞色零容忍（严禁背景色和文字同色系）：文字与有效背景对比度
            //    < 2.0 即同色系不可读（黑底黑字 ≈1.08 / 白底白字 1.0）。
            //    品牌色正常设计（微信绿白字 ≈2.4）不误伤。优先级最高——
            //    不可读比一切样式问题都严重。
            if n.text.length() > 0 {
              match norm_text_collision(doc, id, n.style.fill, n.style.text_color, n.text) {
                Some(cr) => {
                  let bg = norm_effective_bg(doc, id, n.style.fill)
                  issues.push(
                    "\{json_escape(id)}（\{n.component}「\{json_escape(n.text)}」）文字与背景撞色：\{bg} 底 \{n.style.text_color} 字，对比度仅 \{cr}（同色系严禁）→ auto_fix 翻转文字色",
                  )
                  continue
                }
                None => ()
              }
            }
            // 0.5) 横平竖直：rotate 必须是 90° 的倍数，任意角度破坏网格
            if n.style.rotate % 90.0 != 0.0 {
              issues.push(
                "\{json_escape(id)}(\{n.component}) rotate \{n.style.rotate.to_int()}° 非直角倍数 → rotate 0（横平竖直，auto_fix 可修）",
              )
              continue
            }
            // 1) 操作组件：文案必须与边缘留白
            if norm_is_action_component(n.component) && n.text.length() > 0 {
              let ts = text_intrinsic(
                n.text,
                n.style.font_size,
                line_height=n.style.line_height,
              )
              let need_w = ts.width + NORM_TEXT_PAD_X * 2.0
              let need_h = norm_need_h(n.component, n.text, n.style.font_size, ts)
              if r.width < need_w - 0.5 || r.height < need_h - 0.5 {
                // 问题串会进 critique 的 JSON——id/文案过 json_escape（引号、
                // 反斜杠与控制符），结构靠「」与转义共同保证
                issues.push(
                  "\{json_escape(id)}（\{n.component}「\{json_escape(n.text)}」）现 \{r.width.to_int()}×\{r.height.to_int()}，文案需 ≥\{need_w.to_int()}×\{need_h.to_int()}（左右各留 12）",
                )
                continue
              }
            }
            // 2) 方正圆润族：圆角低于 8px 档（或超出 高/2 变畸形）
            if norm_is_rounded_component(n.component) &&
              n.style.corner_radius < 999.0 {
              let r_cap = r.height / 2.0
              let r_now = n.style.corner_radius
              if r_now < NORM_RADIUS_BASE - 0.5 && NORM_RADIUS_BASE <= r_cap {
                issues.push(
                  "\{json_escape(id)}(\{n.component}) 圆角 \{r_now.to_int()} 低于方正圆润档 → radius 8",
                )
                continue
              }
              if r_now > r_cap + 0.5 {
                issues.push(
                  "\{json_escape(id)}(\{n.component}) 圆角 \{r_now.to_int()} 超出 高/2=\{r_cap.to_int()} → radius \{r_cap.to_int()}",
                )
                continue
              }
            }
            // 3) 全宽条/全宽行：占满画板宽度却带圆角
            if norm_is_full_bleed_component(n.component) &&
              n.style.corner_radius > 0.5 &&
              root_w > 0.0 &&
              r.width >= root_w - 0.5 {
              issues.push(
                "\{json_escape(id)}(\{n.component}) 全宽 \{r.width.to_int()} 带圆角 \{n.style.corner_radius.to_int()} 顶出边缘 → radius 0",
              )
              continue
            }
          }
        }
    }
  }
  issues
}

///|
/// 规范修复：与 norm_issues 同一判据，直接改文档并返回修复明细
/// （JSON 片段，格式与 autofix 的 fix_* 家族一致）。
pub fn norm_fix_pass(
  doc : Document,
  layout : SolvedLayout,
) -> Array[String] {
  let fixes : Array[String] = []
  let root_w = match layout.rect_of(doc.root_id) {
    Some(r) => r.width
    None => 0.0
  }
  for id in doc.nodes.keys() {
    match doc.nodes.get(id) {
      None => ()
      Some(n) =>
        match layout.rect_of(id) {
          None => ()
          Some(r) => {
            let mut new_w = r.width
            let mut new_h = r.height
            let mut new_r = n.style.corner_radius
            let mut new_text_color = ""
            let mut new_rot = n.style.rotate
            let mut why = ""
            // 0) 撞色修复（严禁背景色和文字同色系）：对比度 < 2.0 时文字色按
            //    背景亮度翻转到黑/白——不可读比任何设计偏好都优先。
            if n.text.length() > 0 {
              let bg = norm_effective_bg(doc, id, n.style.fill)
              if norm_is_hex6(bg) && norm_is_hex6(n.style.text_color) {
                let cr = norm_contrast_ratio(
                  norm_luminance(bg),
                  norm_luminance(n.style.text_color),
                )
                if cr < NORM_CONTRAST_MIN {
                  new_text_color = norm_readable_text(norm_luminance(bg))
                  why = "撞色修复"
                }
              }
            }
            // 0.5) 横平竖直：rotate 必须是 90° 的倍数，其余归零
            if n.style.rotate % 90.0 != 0.0 {
              new_rot = 0.0
              if why == "" { why = "rotate 归零（横平竖直）" }
            }
            // 1) 操作组件放大到文案 + 留白（Fill 宽不动——它由父容器决定）
            if norm_is_action_component(n.component) && n.text.length() > 0 {
              let ts = text_intrinsic(
                n.text,
                n.style.font_size,
                line_height=n.style.line_height,
              )
              let need_w = ts.width + NORM_TEXT_PAD_X * 2.0
              let need_h = norm_need_h(n.component, n.text, n.style.font_size, ts)
              let w_fixed = match n.width {
                Fixed(_) => true
                _ => false
              }
              if r.width < need_w - 0.5 && w_fixed {
                new_w = need_w
                why = "文案留白"
              }
              if r.height < need_h - 0.5 {
                new_h = need_h
                why = "文案留白"
              }
            }
            // 2) 圆角归档：方正圆润族抬到 8（不超过 高/2）；超 高/2 的收到 高/2
            if norm_is_rounded_component(n.component) &&
              n.style.corner_radius < 999.0 {
              let r_cap = new_h / 2.0
              let r_now = n.style.corner_radius
              if r_now < NORM_RADIUS_BASE - 0.5 && NORM_RADIUS_BASE <= r_cap {
                new_r = NORM_RADIUS_BASE
                if why == "" { why = "圆角归档 8" }
              } else if r_now > r_cap + 0.5 {
                new_r = r_cap
                if why == "" { why = "圆角收敛到 高/2" }
              }
            }
            // 3) 全宽条去圆角
            if norm_is_full_bleed_component(n.component) &&
              n.style.corner_radius > 0.5 &&
              root_w > 0.0 &&
              r.width >= root_w - 0.5 {
              new_r = 0.0
              why = "全宽条直角"
            }
            let changed = (new_w != r.width && new_w > 0.0) ||
              (new_h != r.height && new_h > 0.0) ||
              new_r != n.style.corner_radius ||
              (new_text_color != "" && new_text_color != n.style.text_color) ||
              new_rot != n.style.rotate
            if changed && why != "" {
              // 只覆写真正变化的维度：width 变化必经 w_fixed 守卫（Fixed→Fixed），
              // 其余维度保持 x.width/x.height 原值——Fill/Hug 尺寸策略不得被
              // 圆角-only / 高度-only 路径静默降级为 Fixed
              let _ = doc.update_node(id, fn(x) {
                {
                  ..x,
                  width: if new_w != r.width && new_w > 0.0 {
                    Fixed(new_w)
                  } else {
                    x.width
                  },
                  height: if new_h != r.height && new_h > 0.0 {
                    Fixed(new_h)
                  } else {
                    x.height
                  },
                  style: {
                    ..x.style,
                    corner_radius: new_r,
                    text_color: if new_text_color != "" {
                      new_text_color
                    } else {
                      x.style.text_color
                    },
                    rotate: if new_rot != x.style.rotate { new_rot } else { x.style.rotate },
                  },
                }
              })
              fixes.push(
                "{\"node\":\"\{json_escape(id)}\",\"action\":\"component_norm\",\"why\":\"\{why}\",\"before\":\"\{r.width.to_int()}×\{r.height.to_int()} r\{n.style.corner_radius.to_int()}\",\"after\":\"\{new_w.to_int()}×\{new_h.to_int()} r\{new_r.to_int()}\"}",
              )
            }
          }
        }
    }
  }
  fixes
}

///|
/// 齐缝列表行连排：同一父节点下 ≥3 个 list_item，宽度一致（±2）、高度一致
/// （±4）、纵向齐缝或近齐缝（行距 -1~6）——「裸列表」形态，是分割线规范的
/// 检测对象。检测与修复（norm_list_divider_fix）共用本结构。
pub(all) struct NormListRun {
  parent_id : String
  row_ids : Array[String]
}

///|
/// 按 solved y 插入排序（run 规模小，平行数组位移，不依赖排序 API 形态）
fn norms_sort_by_y(ids : Array[String], layout : SolvedLayout) -> Array[String] {
  let out : Array[String] = []
  let ys : Array[Double] = []
  for id in ids.iter() {
    let y = match layout.rect_of(id) {
      Some(r) => r.y
      None => 0.0
    }
    let mut pos = out.length()
    while pos > 0 && ys[pos - 1] > y {
      pos = pos - 1
    }
    out.push(id)
    ys.push(y)
    let mut i = out.length() - 1
    while i > pos {
      out[i] = out[i - 1]
      ys[i] = ys[i - 1]
      i = i - 1
    }
    out[pos] = id
    ys[pos] = y
  }
  out
}

///|
/// 两行是否齐缝相连（纵向贴住或近贴，宽高一致）
fn norms_flush(
  a : String,
  b : String,
  layout : SolvedLayout,
) -> Bool {
  match (layout.rect_of(a), layout.rect_of(b)) {
    (Some(ra), Some(rb)) => {
      let gap = rb.y - (ra.y + ra.height)
      gap <= 6.0 && gap >= -1.0 && (rb.width - ra.width).abs() <= 2.0 &&
      (rb.height - ra.height).abs() <= 4.0
    }
    _ => false
  }
}

///|
/// 行内是否已带 divider 子节点（norm_fix 修复后的形态）
fn norms_row_has_divider_child(
  doc : Document,
  row_id : String,
) -> Bool {
  match doc.nodes.get(row_id) {
    Some(r) =>
      for cid in r.children.iter() {
        match doc.nodes.get(cid) {
          Some(c) => if c.component == "divider" { return true }
          None => ()
        }
      }
    None => ()
  }
  false
}

///|
/// 同级 divider 是否落在两行交界处（行底发丝线的页级画法）
fn norms_boundary_has_divider(
  doc : Document,
  layout : SolvedLayout,
  parent_id : String,
  top : Double,
  bottom : Double,
  min_w : Double,
) -> Bool {
  for id in doc.nodes.keys() {
    match doc.nodes.get(id) {
      None => ()
      Some(n) =>
        if n.component == "divider" {
          match doc.find_parent(id) {
            Some(p) =>
              if p == parent_id {
                match layout.rect_of(id) {
                  Some(r) =>
                    if r.y >= top - 2.0 && r.y <= bottom + 2.0 && r.width >= min_w * 0.5 {
                      return true
                    }
                  None => ()
                }
              }
            None => ()
          }
        }
      _ => ()
    }
  }
  false
}

///|
/// run 的任一行间是否存在分隔（行内 divider 子节点 / 交界处页级 divider）
fn norms_run_has_separators(
  doc : Document,
  layout : SolvedLayout,
  parent_id : String,
  rows : Array[String],
  start : Int,
  end : Int,
) -> Bool {
  for k in start..<end {
    let cur = rows[k]
    let nxt = rows[k + 1]
    if norms_row_has_divider_child(doc, cur) {
      return true
    }
    match (layout.rect_of(cur), layout.rect_of(nxt)) {
      (Some(rc), Some(rn)) =>
        if norms_boundary_has_divider(
          doc,
          layout,
          parent_id,
          rc.bottom(),
          rn.y,
          rc.width,
        ) {
          return true
        }
      _ => ()
    }
  }
  false
}

///|
/// 扫描齐缝列表行连排（NormListRun）。每个 run 是一个「裸列表」：
/// 检测（norm_issues）与修复（autofix 的 norm_list_divider_fix）都消费它。
pub fn norms_list_runs(
  doc : Document,
  layout : SolvedLayout,
) -> Array[NormListRun] {
  let runs : Array[NormListRun] = []
  let by_parent : Map[String, Array[String]] = Map::new()
  for id in doc.nodes.keys() {
    match doc.nodes.get(id) {
      None => ()
      Some(n) =>
        if n.component == "list_item" {
          match doc.find_parent(id) {
            Some(pid) =>
              match by_parent.get(pid) {
                Some(arr) => arr.push(id)
                None => by_parent.set(pid, [id])
              }
            None => ()
          }
        }
      _ => ()
    }
  }
  for pid in by_parent.keys() {
    match by_parent.get(pid) {
      None => ()
      Some(group) => {
        let rows = norms_sort_by_y(group, layout)
        let mut i = 0
        while i < rows.length() {
          let mut j = i
          while j + 1 < rows.length() && norms_flush(rows[j], rows[j + 1], layout) {
            j = j + 1
          }
          if j - i + 1 >= 3 &&
            !norms_run_has_separators(doc, layout, pid, rows, i, j) {
            let run_ids : Array[String] = []
            for k in i..=j {
              run_ids.push(rows[k])
            }
            runs.push({ parent_id: pid, row_ids: run_ids })
          }
          i = j + 1
        }
      }
    }
  }
  runs
}


///|
/// 颜色搭配标准（用户决策 2026-10-11：严禁高保真背景色和文字同色系）：
/// 文字与**有效背景**（自身实底，透明则向上找最近实底祖先，兜底白底）的
/// WCAG 对比度 < 2.0 即撞色——黑底黑字（≈1.08）、白底白字（1.0）一类，
/// 完全不可读。品牌色正常设计（微信绿白字 ≈2.4）不受影响。
/// 判不了的形态（非 #RRGGBB）一律不判，绝不误报。

///|
pub const NORM_CONTRAST_MIN : Double = 2.0

///|
fn norm_is_hex6(color : String) -> Bool {
  if color.length() != 7 {
    return false
  }
  if color.get_char(0) != Some('#') {
    return false
  }
  for i in 1..<7 {
    match color.get_char(i) {
      Some(ch) => {
        let code = ch.to_int()
        let ok = (code >= 48 && code <= 57) || (code >= 97 && code <= 102) || (code >= 65 && code <= 70)
        if not(ok) {
          return false
        }
      }
      None => return false
    }
  }
  true
}

///|
/// sRGB 通道 → 线性亮度分量
fn norm_srgb_lin(c : Double) -> Double {
  let v = c / 255.0
  if v <= 0.03928 {
    v / 12.92
  } else {
    Double::pow((v + 0.055) / 1.055, 2.4)
  }
}

///|
/// WCAG 相对亮度（仅接受 #RRGGBB；调用方先用 norm_is_hex6 把关）
fn norm_luminance(color : String) -> Double {
  let (r, g, b) = parse_hex_rgb(color)
  0.2126 * norm_srgb_lin(r) + 0.7152 * norm_srgb_lin(g) + 0.0722 * norm_srgb_lin(b)
}

///|
/// WCAG 对比度比
fn norm_contrast_ratio(a : Double, b : Double) -> Double {
  let hi = if a > b { a } else { b }
  let lo = if a > b { b } else { a }
  (hi + 0.05) / (lo + 0.05)
}

///|
/// 有效背景色：自身实底优先；透明（none）向上找最近的实底祖先；
/// 全透明按白底收尾。
fn norm_effective_bg(
  doc : Document,
  node_id : String,
  own_fill : String,
) -> String {
  if own_fill != "none" && norm_is_hex6(own_fill) {
    return own_fill
  }
  let mut cur = node_id
  let mut walking = true
  while walking {
    match doc.find_parent(cur) {
      None => walking = false
      Some(p) => {
        cur = p
        match doc.nodes.get(p) {
          None => walking = false
          Some(pn) =>
            if pn.style.fill != "none" && norm_is_hex6(pn.style.fill) {
              walking = false
              return pn.style.fill
            }
        }
      }
    }
  }
  "#FFFFFF"
}

///|
/// 撞色判定：文字与有效背景对比度 < NORM_CONTRAST_MIN。
/// 返回 Some(对比度) 表示撞色。
fn norm_text_collision(
  doc : Document,
  node_id : String,
  fill : String,
  text_color : String,
  text : String,
) -> Double? {
  if text.length() == 0 {
    return None
  }
  if !norm_is_hex6(text_color) || !norm_is_hex6(fill) {
    let bg = norm_effective_bg(doc, node_id, fill)
    if !norm_is_hex6(text_color) || !norm_is_hex6(bg) {
      return None
    }
  }
  let bg = norm_effective_bg(doc, node_id, fill)
  if !norm_is_hex6(bg) || !norm_is_hex6(text_color) {
    return None
  }
  let cr = norm_contrast_ratio(norm_luminance(bg), norm_luminance(text_color))
  if cr < NORM_CONTRAST_MIN {
    Some(cr)
  } else {
    None
  }
}

///|
/// 撞色修复的文字色：按背景亮度翻转到黑/白
fn norm_readable_text(bg_luminance : Double) -> String {
  if bg_luminance > 0.35 {
    "#1A1C1E"
  } else {
    "#FFFFFF"
  }
}
