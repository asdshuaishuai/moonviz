///|
/// 布局推理引擎：Agent 用自然语言说"居中对齐按钮"，引擎推断参数并执行。
///
/// 这不是 NLP——是**结构化的约束语言解析**：
/// 引擎识别设计意图关键词（居中/排列/等宽/间距/缩放），
/// 匹配到对应的布局操作，返回可直接执行的动作。
///
/// 支持 12 种意图：
/// 居中 / 垂直排列 / 水平排列 / 等宽 / 等高 / 等间距 /
/// 网格对齐 / 移到顶部 / 移到底部 / 整体缩放 / 增加边距 / 自动布局
pub(all) enum LayoutIntent {
  CenterNode(String) // "居中 btn" → CenterInParent
  VerticalStack // "垂直排列" → StackLayout(Vertical)
  HorizontalRow // "水平排列" → StackLayout(Horizontal)
  EqualWidth // "等宽" → 所有 width = Fill
  EqualHeight // "等高" → 所有 height = Fill
  EqualSpacing // "等间距" → auto_arrange
  GridAlign(Double) // "网格 8" → snap_to_grid(8)
  MoveTop // "顶部" → y = 0 或容器顶部
  MoveBottom // "底部" → y = 容器底部
  MoveCenter // "垂直居中" → 整体居中
  ScaleAll(Double) // "放大 1.5" → 全部尺寸 × 1.5
  SetPadding(Double) // "边距 16" → 容器 padding = 16
  SetGap(Double) // "间距 12" → StackLayout.gap = 12
  Unknown // 无法识别
}

///|
pub fn LayoutIntent::describe(self : LayoutIntent) -> String {
  match self {
    CenterNode(id) => "center(\{id})"
    VerticalStack => "vertical_stack"
    HorizontalRow => "horizontal_row"
    EqualWidth => "equal_width"
    EqualHeight => "equal_height"
    EqualSpacing => "equal_spacing"
    GridAlign(n) => "grid(\{n})"
    MoveTop => "move_top"
    MoveBottom => "move_bottom"
    MoveCenter => "move_center"
    ScaleAll(f) => "scale(\{f})"
    SetPadding(v) => "padding(\{v})"
    SetGap(v) => "gap(\{v})"
    Unknown => "unknown"
  }
}

// ---------------------------------------------------------------------------
// 约束语言解析
// ---------------------------------------------------------------------------

///|
/// 解析自然语言约束 → LayoutIntent
/// Agent 传入 "居中对齐按钮" / "垂直排列" / "等宽" 等中文或英文
pub fn parse_layout_intent(text : String) -> LayoutIntent {
  let lower = text.to_lower()
  // 居中
  if lower.contains("居中") || lower.contains("center") {
    if lower.contains("垂直") || lower.contains("vertical") {
      return MoveCenter
    }
    return CenterNode("")
  }
  // 排列
  if lower.contains("垂直排列") ||
    lower.contains("vertical") ||
    lower.contains("纵向") {
    return VerticalStack
  }
  if lower.contains("水平排列") ||
    lower.contains("horizontal") ||
    lower.contains("横向") {
    return HorizontalRow
  }
  // 等宽 / 等高
  if lower.contains("等宽") || lower.contains("equal width") {
    return EqualWidth
  }
  if lower.contains("等高") || lower.contains("equal height") {
    return EqualHeight
  }
  // 等间距
  if lower.contains("等间距") ||
    lower.contains("equal spacing") ||
    lower.contains("均匀") {
    return EqualSpacing
  }
  // 网格
  if lower.contains("网格") ||
    lower.contains("grid") ||
    lower.contains("吸附") ||
    lower.contains("snap") {
    let grid = extract_number(lower)
    return GridAlign(if grid > 0.0 { grid } else { 8.0 })
  }
  // 顶部 / 底部
  if lower.contains("顶部") || lower.contains("top") {
    return MoveTop
  }
  if lower.contains("底部") || lower.contains("bottom") {
    return MoveBottom
  }
  // 缩放
  if lower.contains("放大") ||
    lower.contains("scale up") ||
    lower.contains("增大") {
    let f = extract_number(lower)
    return ScaleAll(if f > 0.0 { f } else { 1.25 })
  }
  if lower.contains("缩小") || lower.contains("scale down") {
    let f = extract_number(lower)
    return ScaleAll(if f > 0.0 { 1.0 / f } else { 0.75 })
  }
  // 边距
  if lower.contains("边距") ||
    lower.contains("padding") ||
    lower.contains("内边") {
    let v = extract_number(lower)
    return SetPadding(if v > 0.0 { v } else { 16.0 })
  }
  // 间距
  if lower.contains("间距") ||
    lower.contains("gap") ||
    lower.contains("间隔") {
    let v = extract_number(lower)
    return SetGap(if v > 0.0 { v } else { 8.0 })
  }
  Unknown
}

///|
/// 从文本中提取数字（支持 "8px"、"1.5倍"、"间距 16"）
fn extract_number(text : String) -> Double {
  let mut result = 0.0
  let mut has_dot = false
  let mut frac = 0.1
  let mut found = false
  for c in text.iter() {
    let code = c.to_int()
    if code >= 48 && code <= 57 { // 数字
      let d = (code - 48).to_double()
      if has_dot {
        result = result + d * frac
        frac = frac * 0.1
      } else {
        result = result * 10.0 + d
      }
      found = true
    } else if code == 46 && found { // 小数点（且前面已有数字）
      has_dot = true
    } else if found {
      break // 遇到非数字且已有数字 → 停止
    }
  }
  if found {
    result
  } else {
    0.0
  }
}

// ---------------------------------------------------------------------------
// 意图执行
// ---------------------------------------------------------------------------

///|
/// 执行解析后的布局意图
pub fn Project::apply_intent(
  self : Project,
  intent : LayoutIntent,
  artboard~ : String,
  parent_id? : String = "root",
) -> Result[String, String] {
  match self.artboards.get(artboard) {
    None => Err("unknown_artboard")
    Some(ab) =>
      match intent {
        CenterNode(node_id) => {
          let target = if node_id == "" {
            find_first_child(ab.doc, parent_id)
          } else {
            node_id
          }
          match target {
            "" => Err("no_node_to_center")
            id => self.center_in_parent(artboard~, node_id=id)
          }
        }
        VerticalStack => {
          // 设置父容器为垂直栈布局
          let _ = ab.doc.update_node(parent_id, fn(n) {
            {
              ..n,
              layout: Some({
                dir: Vertical,
                gap: 8.0,
                justify: Start,
                padding: Padding::uniform(16.0),
              }),
            }
          })
          Ok(
            "{\"intent\":\"vertical_stack\",\"applied\":true,\"parent\":\"\{parent_id}\"}",
          )
        }
        HorizontalRow => {
          let _ = ab.doc.update_node(parent_id, fn(n) {
            {
              ..n,
              layout: Some({
                dir: Horizontal,
                gap: 8.0,
                justify: Start,
                padding: Padding::uniform(16.0),
              }),
            }
          })
          Ok(
            "{\"intent\":\"horizontal_row\",\"applied\":true,\"parent\":\"\{parent_id}\"}",
          )
        }
        EqualWidth => {
          // 所有子节点 width = Fill
          let count = equalize_width(ab.doc, parent_id)
          Ok("{\"intent\":\"equal_width\",\"applied\":\{count} nodes}")
        }
        EqualHeight => {
          let count = equalize_height(ab.doc, parent_id)
          Ok("{\"intent\":\"equal_height\",\"applied\":\{count} nodes}")
        }
        EqualSpacing => self.auto_arrange(artboard~, parent_id~)
        GridAlign(grid) => self.snap_to_grid(artboard~, grid~)
        MoveTop => {
          let count = move_to_edge(ab.doc, parent_id, true)
          Ok("{\"intent\":\"move_top\",\"moved\":\{count}}")
        }
        MoveBottom => {
          let count = move_to_edge(ab.doc, parent_id, false)
          Ok("{\"intent\":\"move_bottom\",\"moved\":\{count}}")
        }
        MoveCenter => {
          // 垂直居中所有子节点
          let layout = solve(ab.doc)
          let count = center_all(ab.doc, parent_id, layout)
          Ok("{\"intent\":\"move_center\",\"centered\":\{count}}")
        }
        ScaleAll(factor) => {
          let count = scale_all(ab.doc, factor)
          Ok("{\"intent\":\"scale\",\"factor\":\{factor},\"scaled\":\{count}}")
        }
        SetPadding(v) => {
          let _ = ab.doc.update_node(parent_id, fn(n) {
            let base = match n.layout {
              Some(l) => l
              None =>
                {
                  dir: Vertical,
                  gap: 8.0,
                  justify: Start,
                  padding: Padding::uniform(0.0),
                }
            }
            { ..n, layout: Some({ ..base, padding: Padding::uniform(v) }) }
          })
          Ok("{\"intent\":\"set_padding\",\"value\":\{v}}")
        }
        SetGap(v) => {
          let _ = ab.doc.update_node(parent_id, fn(n) {
            let base = match n.layout {
              Some(l) => l
              None =>
                {
                  dir: Vertical,
                  gap: 0.0,
                  justify: Start,
                  padding: Padding::uniform(0.0),
                }
            }
            { ..n, layout: Some({ ..base, gap: v }) }
          })
          Ok("{\"intent\":\"set_gap\",\"value\":\{v}}")
        }
        Unknown => Err("cannot_parse_intent（支持：居中 | 垂直居中 | 垂直排列 | 水平排列 | 等宽 | 等高 | 等间距 | 网格 N | 顶部 | 底部 | 放大 N | 缩小 N | 边距 N | 间距 N）")
      }
  }
}

///|
/// 一步到位：解析文本 → 执行意图
pub fn Project::apply_constraint(
  self : Project,
  text : String,
  artboard~ : String,
  parent_id? : String = "root",
) -> Result[String, String] {
  let intent = parse_layout_intent(text)
  match intent {
    // 错误即文档：宿主（和 LLM）看到 cannot_parse 时就地拿到可用的全部
    // 意图词表——issue #17 的「语法无文档」由此闭环，无需翻 SKILL
    Unknown =>
      Err(
        "cannot_parse: \"\{text}\"。constrain 是布局意图（非层级/z-order）：居中 | 垂直居中 | 垂直排列 | 水平排列 | 等宽 | 等高 | 等间距 | 网格 N | 顶部 | 底部 | 放大 N | 缩小 N | 边距 N | 间距 N",
      )
    _ => self.apply_intent(intent, artboard~, parent_id~)
  }
}

// ---------------------------------------------------------------------------
// 辅助操作
// ---------------------------------------------------------------------------

///|
fn find_first_child(doc : Document, parent_id : String) -> String {
  match doc.nodes.get(parent_id) {
    Some(p) => if p.children.length() > 0 { p.children[0] } else { "" }
    None => ""
  }
}

///|
fn equalize_width(doc : Document, parent_id : String) -> Int {
  let mut count = 0
  match doc.nodes.get(parent_id) {
    Some(parent) =>
      for cid in parent.children.iter() {
        let _ = doc.update_node(cid, fn(n) { { ..n, width: Fill } })
        count = count + 1
      }
    None => ()
  }
  count
}

///|
fn equalize_height(doc : Document, parent_id : String) -> Int {
  let mut count = 0
  match doc.nodes.get(parent_id) {
    Some(parent) =>
      for cid in parent.children.iter() {
        let _ = doc.update_node(cid, fn(n) { { ..n, height: Fill } })
        count = count + 1
      }
    None => ()
  }
  count
}

///|
fn move_to_edge(doc : Document, parent_id : String, top : Bool) -> Int {
  let mut count = 0
  match doc.nodes.get(parent_id) {
    Some(parent) =>
      for cid in parent.children.iter() {
        let _ = doc.update_node(cid, fn(n) {
          let y = if top { 0.0 } else { 700.0 } // 简化：底边距 700
          { ..n, y: AlignStart(y) }
        })
        count = count + 1
      }
    None => ()
  }
  count
}

///|
fn center_all(doc : Document, parent_id : String, layout : SolvedLayout) -> Int {
  let mut count = 0
  match (doc.nodes.get(parent_id), layout.rect_of(parent_id)) {
    (Some(parent), Some(pr)) => {
      // 计算总高度
      let mut total_h = 0.0
      for cid in parent.children.iter() {
        match layout.rect_of(cid) {
          Some(r) => total_h = total_h + r.height
          None => ()
        }
      }
      let gap = 8.0
      let n = parent.children.length()
      let total_with_gap = total_h + gap * (n - 1).to_double()
      let start_y = (pr.height - total_with_gap) / 2.0
      let mut y = if start_y > 0.0 { start_y } else { 0.0 }
      for cid in parent.children.iter() {
        let _ = doc.update_node(cid, fn(c) { { ..c, y: AlignStart(y) } })
        match layout.rect_of(cid) {
          Some(r) => y = y + r.height + gap
          None => ()
        }
        count = count + 1
      }
    }
    _ => ()
  }
  count
}

///|
fn scale_all(doc : Document, factor : Double) -> Int {
  let mut count = 0
  for id in doc.nodes.keys() {
    if id != "root" {
      let _ = doc.update_node(id, fn(n) {
        let w = scale_spec(n.width, factor)
        let h = scale_spec(n.height, factor)
        { ..n, width: w, height: h }
      })
      count = count + 1
    }
  }
  count
}

///|
fn scale_spec(s : SizeSpec, factor : Double) -> SizeSpec {
  match s {
    Fixed(v) => Fixed(v * factor)
    Fill => Fill
    Hug => Hug
  }
}
