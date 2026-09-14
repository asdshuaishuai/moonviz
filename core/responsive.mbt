///|
/// 响应式断点系统：同一设计在手机/平板/桌面三种尺寸下自动适配。
///
/// Agent 创建一个 390px 的手机原型后，调用 `generate_responsive`：
/// - 引擎自动生成 `_tablet`（768px）和 `_desktop`（1200px）变体
/// - 垂直布局 → 平板变 2 列 → 桌面变 3 列（或侧边栏）
/// - 组件尺寸按比例适配（卡片加宽、字号保持可读）
pub(all) struct Breakpoint {
  name : String
  width : Double
  height : Double
  columns : Int
  description : String
}

///|
pub fn default_breakpoints() -> Array[Breakpoint] {
  [
    {
      name: "mobile",
      width: 390.0,
      height: 844.0,
      columns: 4,
      description: "手机",
    },
    {
      name: "tablet",
      width: 768.0,
      height: 1024.0,
      columns: 8,
      description: "平板",
    },
    {
      name: "desktop",
      width: 1200.0,
      height: 800.0,
      columns: 12,
      description: "桌面",
    },
  ]
}

///|
pub fn breakpoints_json() -> String {
  let parts : Array[String] = []
  for bp in default_breakpoints().iter() {
    let w = bp.width.to_int().to_string()
    let h = bp.height.to_int().to_string()
    parts.push(
      "{\"name\":\"\{bp.name}\",\"width\":\{w},\"height\":\{h},\"columns\":\{bp.columns}}",
    )
  }
  let j = jstr17(parts)
  "[\{j}]"
}

///|
/// 为画板生成响应式变体（_tablet / _desktop）
pub fn Project::generate_responsive(
  self : Project,
  artboard~ : String,
) -> Result[String, String] {
  match self.artboards.get(artboard) {
    None => Err("unknown_artboard")
    Some(base_ab) => {
      let created : Array[String] = []
      let bps = default_breakpoints()
      for bp in bps.iter() {
        if bp.name == "mobile" {
          continue
        }
        let vid = artboard + "_" + bp.name
        let _ = self.create_artboard(name=vid, width=bp.width, height=bp.height)
        match self.artboards.get(vid) {
          Some(vab) => {
            for nid in base_ab.doc.nodes.keys() {
              if nid != "root" {
                match base_ab.doc.nodes.get(nid) {
                  Some(n) => {
                    let _ = vab.doc.insert_node({ ..n, children: [] }, "root")
                    let _ = vab.doc.update_node(nid, fn(x) {
                      { ..x, children: n.children.copy() }
                    })
                  }
                  None => ()
                }
              }
            }
            adapt_layout(vab.doc, bp)
            created.push("\"\{vid}\"")
          }
          None => ()
        }
      }
      let j = jstr17(created)
      Ok("{\"ok\":true,\"base\":\"\{artboard}\",\"variants\":[\{j}]}")
    }
  }
}

///|
fn adapt_layout(doc : Document, bp : Breakpoint) -> Unit {
  match bp.name {
    "tablet" => adapt_tablet(doc)
    "desktop" => adapt_desktop(doc)
    _ => ()
  }
}

///|
fn adapt_tablet(doc : Document) -> Unit {
  let scale = 768.0 / 390.0
  for id in doc.nodes.keys() {
    if id != "root" {
      let _ = doc.update_node(id, fn(n) {
        let w = scale_size(n.width, scale * 0.6)
        { ..n, width: w }
      })
    }
  }
  let _ = doc.update_node("root", fn(n) {
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
    {
      ..n,
      layout: Some({ ..base, gap: 16.0, padding: Padding::uniform(32.0) }),
    }
  })
}

///|
fn adapt_desktop(doc : Document) -> Unit {
  let scale = 1200.0 / 390.0
  for id in doc.nodes.keys() {
    if id != "root" {
      let _ = doc.update_node(id, fn(n) {
        let w = scale_size(n.width, scale * 0.4)
        { ..n, width: w }
      })
    }
  }
  let _ = doc.update_node("root", fn(n) {
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
    {
      ..n,
      layout: Some({
        ..base,
        dir: Horizontal,
        gap: 24.0,
        padding: Padding::uniform(48.0),
      }),
    }
  })
}

///|
fn scale_size(s : SizeSpec, factor : Double) -> SizeSpec {
  match s {
    Fixed(v) => {
      let nw = v * factor
      if nw > 700.0 {
        Fixed(700.0)
      } else {
        Fixed(nw)
      }
    }
    Fill => Fill
    Hug => Hug
  }
}

///|
/// 预览指定断点
pub fn Project::preview_breakpoint(
  self : Project,
  artboard~ : String,
  breakpoint~ : String,
) -> Result[String, String] {
  let target = if breakpoint == "mobile" {
    artboard
  } else {
    artboard + "_" + breakpoint
  }
  match self.artboards.get(target) {
    Some(ab) => {
      let svg = render_svg(ab.doc)
      let w = ab.width.to_int().to_string()
      let sl = svg.length().to_string()
      Ok(
        "{\"breakpoint\":\"\{breakpoint}\",\"width\":\{w},\"svg_length\":\{sl}}",
      )
    }
    None => Err("not_generated: \{target}")
  }
}

///|
/// 列出某画板的所有响应式变体
pub fn Project::list_breakpoint_variants(
  self : Project,
  artboard~ : String,
) -> String {
  let variants : Array[String] = []
  for bp in default_breakpoints().iter() {
    let id = if bp.name == "mobile" {
      artboard
    } else {
      artboard + "_" + bp.name
    }
    match self.artboards.get(id) {
      Some(ab) => {
        let w = ab.width.to_int().to_string()
        let n = (ab.doc.nodes.size() - 1).to_string()
        variants.push(
          "{\"breakpoint\":\"\{bp.name}\",\"width\":\{w},\"nodes\":\{n}}",
        )
      }
      None => ()
    }
  }
  let j = jstr17(variants)
  "[\{j}]"
}

///|
fn jstr17(parts : Array[String]) -> String {
  let sb = StringBuilder::new()
  for i in 0..<parts.length() {
    if i > 0 {
      sb.write_string(",")
    }
    sb.write_string(parts[i])
  }
  sb.to_string()
}
