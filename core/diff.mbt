///|
/// 语义 Diff：比较两个文档状态，输出人可读 + 机器可解析的变更描述。
///
/// Agent 在执行操作后调用 `diff_docs(before, after)` 获得：
/// - added：新增了哪些节点
/// - removed：删除了哪些节点
/// - moved：位置变化的节点
/// - resized：尺寸变化的节点
/// - restyled：样式变化的节点
/// - relayout：布局参数变化
/// Agent 把这个 diff 作为"我做了什么"的自省报告。
pub(all) struct DocDiff {
  added : Array[String]
  removed : Array[String]
  moved : Array[DiffEntry]
  resized : Array[DiffEntry]
  restyled : Array[DiffEntry]
  relayout : Array[DiffEntry]
}

///|
pub(all) struct DiffEntry {
  node_id : String
  before : String
  after : String
}

///|
/// 比较两个文档（通常 before = 操作前快照，after = 操作后）
pub fn diff_docs(before : Document, after : Document) -> DocDiff {
  let diff : DocDiff = {
    added: [],
    removed: [],
    moved: [],
    resized: [],
    restyled: [],
    relayout: [],
  }
  // 新增
  for id in after.nodes.keys() {
    if !before.has(id) {
      diff.added.push(id)
    }
  }
  // 删除
  for id in before.nodes.keys() {
    if !after.has(id) {
      diff.removed.push(id)
    }
  }
  // 变更
  let la = solve(after)
  let lb = solve(before)
  for id in after.nodes.keys() {
    if before.has(id) {
      match
        (
          before.nodes.get(id),
          after.nodes.get(id),
          lb.rect_of(id),
          la.rect_of(id),
        ) {
        (Some(nb), Some(na), Some(rb), Some(ra)) => {
          // 位置变化
          if rb.x != ra.x || rb.y != ra.y {
            diff.moved.push({
              node_id: id,
              before: "(\{rb.x.to_int()}, \{rb.y.to_int()})",
              after: "(\{ra.x.to_int()}, \{ra.y.to_int()})",
            })
          }
          // 尺寸变化
          if rb.width != ra.width || rb.height != ra.height {
            diff.resized.push({
              node_id: id,
              before: "\{rb.width.to_int()}×\{rb.height.to_int()}",
              after: "\{ra.width.to_int()}×\{ra.height.to_int()}",
            })
          }
          // 样式变化
          let style_changes : Array[String] = []
          if nb.style.fill != na.style.fill {
            style_changes.push("fill: \{nb.style.fill}→\{na.style.fill}")
          }
          if nb.style.corner_radius != na.style.corner_radius {
            style_changes.push(
              "radius: \{nb.style.corner_radius}→\{na.style.corner_radius}",
            )
          }
          if nb.style.font_size != na.style.font_size {
            style_changes.push(
              "font: \{nb.style.font_size}→\{na.style.font_size}",
            )
          }
          if nb.text != na.text {
            style_changes.push("text: \"\{nb.text}\"→\"\{na.text}\"")
          }
          if style_changes.length() > 0 {
            diff.restyled.push({
              node_id: id,
              before: "",
              after: jstr7(style_changes, "; "),
            })
          }
          // 布局变化
          let lb_layout = nb.layout
          let la_layout = na.layout
          let layout_changed = match (lb_layout, la_layout) {
            (None, None) => false
            (Some(b), Some(a)) => dir_neq(b.dir, a.dir) || b.gap != a.gap
            _ => true
          }
          if layout_changed {
            let before_desc = match lb_layout {
              Some(l) => "\{dir_name(l.dir)} gap=\{l.gap}"
              None => "absolute"
            }
            let after_desc = match la_layout {
              Some(l) => "\{dir_name(l.dir)} gap=\{l.gap}"
              None => "absolute"
            }
            diff.relayout.push({
              node_id: id,
              before: before_desc,
              after: after_desc,
            })
          }
        }
        _ => ()
      }
    }
  }
  diff
}

///|
fn dir_name(d : StackDir) -> String {
  match d {
    Vertical => "vertical"
    Horizontal => "horizontal"
  }
}

///|
fn jstr7(parts : Array[String], sep : String) -> String {
  let sb = StringBuilder::new()
  for i in 0..<parts.length() {
    if i > 0 {
      sb.write_string(sep)
    }
    sb.write_string(parts[i])
  }
  sb.to_string()
}

///|
/// Diff 的 JSON 序列化（Agent 审阅用）
pub fn DocDiff::to_json(self : DocDiff) -> String {
  let parts : Array[String] = []
  // added
  if self.added.length() > 0 {
    let adds : Array[String] = []
    for id in self.added.iter() {
      adds.push("\"\{json_escape(id)}\"")
    }
    parts.push("\"added\":[" + jstr7(adds, ",") + "]")
  }
  // removed
  if self.removed.length() > 0 {
    let rems : Array[String] = []
    for id in self.removed.iter() {
      rems.push("\"\{json_escape(id)}\"")
    }
    parts.push("\"removed\":[" + jstr7(rems, ",") + "]")
  }
  // moved
  if self.moved.length() > 0 {
    let ms : Array[String] = []
    for e in self.moved.iter() {
      ms.push(
        "{\"id\":\"\{e.node_id}\",\"from\":\"\{e.before}\",\"to\":\"\{e.after}\"}",
      )
    }
    parts.push("\"moved\":[" + jstr7(ms, ",") + "]")
  }
  // resized
  if self.resized.length() > 0 {
    let rs : Array[String] = []
    for e in self.resized.iter() {
      rs.push(
        "{\"id\":\"\{e.node_id}\",\"from\":\"\{e.before}\",\"to\":\"\{e.after}\"}",
      )
    }
    parts.push("\"resized\":[" + jstr7(rs, ",") + "]")
  }
  // restyled
  if self.restyled.length() > 0 {
    let ss : Array[String] = []
    for e in self.restyled.iter() {
      ss.push(
        "{\"id\":\"\{json_escape(e.node_id)}\",\"changes\":\"\{json_escape(e.after)}\"}",
      )
    }
    parts.push("\"restyled\":[" + jstr7(ss, ",") + "]")
  }
  // relayout
  if self.relayout.length() > 0 {
    let ls : Array[String] = []
    for e in self.relayout.iter() {
      ls.push(
        "{\"id\":\"\{json_escape(e.node_id)}\",\"from\":\"\{json_escape(e.before)}\",\"to\":\"\{json_escape(e.after)}\"}",
      )
    }
    parts.push("\"relayout\":[" + jstr7(ls, ",") + "]")
  }
  if parts.length() == 0 {
    return "{\"unchanged\":true}"
  }
  let j = jstr7(parts, ",")
  "{\{j}}"
}

///|
/// 人可读摘要（一行）
pub fn DocDiff::summary(self : DocDiff) -> String {
  let parts : Array[String] = []
  if self.added.length() > 0 {
    parts.push("+\{self.added.length()}")
  }
  if self.removed.length() > 0 {
    parts.push("-\{self.removed.length()}")
  }
  if self.moved.length() > 0 {
    parts.push("↕\{self.moved.length()}")
  }
  if self.resized.length() > 0 {
    parts.push("⇲\{self.resized.length()}")
  }
  if self.restyled.length() > 0 {
    parts.push("◐\{self.restyled.length()}")
  }
  if self.relayout.length() > 0 {
    parts.push("☰\{self.relayout.length()}")
  }
  if parts.length() == 0 {
    "no changes"
  } else {
    jstr7(parts, " ")
  }
}

///|
fn dir_neq(a : StackDir, b : StackDir) -> Bool {
  match (a, b) {
    (Vertical, Horizontal) => true
    (Horizontal, Vertical) => true
    _ => false
  }
}
