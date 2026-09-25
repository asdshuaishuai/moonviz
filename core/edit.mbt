/// 人类视觉编辑（双向同步）：拖拽 / 改尺寸 / 改样式 / 删除。
/// 每个操作都是中间态（场景图）上的一个可序列化补丁，与 Agent 命令
/// 共享同一份表示——编辑器拖拽与 Agent 命令最终都变成这里的调用。
///
/// 拖拽核心语义：栈布局中的节点被拖动 = 脱离自动布局，进入自由层
/// （画布级 Group，主轴 Fixed(0) 不占栈位），与 Figma 拖出 Auto Layout 一致。

///|
/// 自由层节点 id（每个画布一棵）
pub const FREE_LAYER_ID : String = "__free__"

///|
/// 收集子树全部 id（删除用）
fn collect_subtree(doc : Document, id : String, acc : Array[String]) -> Unit {
  acc.push(id)
  match doc.get(id) {
    Some(n) =>
      for c in n.children.iter() {
        collect_subtree(doc, c, acc)
      }
    None => ()
  }
}

///|
/// 解析十进制数（含小数与负号）；非法输入返回 0
pub fn parse_double(s : String) -> Double {
  let mut result = 0.0
  let mut frac = 0.0
  let mut div = 10.0
  let mut seen_dot = false
  let mut neg = false
  let mut started = false
  for c in s.iter() {
    let code = c.to_int()
    if code == 45 && !started {
      neg = true
      started = true
    } else if code >= 48 && code <= 57 {
      if seen_dot {
        frac = frac + (code - 48).to_double() / div
        div = div * 10.0
      } else {
        result = result * 10.0 + (code - 48).to_double()
      }
      started = true
    } else if code == 46 && !seen_dot {
      seen_dot = true
      started = true
    }
  }
  if neg {
    -(result + frac)
  } else {
    result + frac
  }
}

///|
/// 确保画布根部存在自由层 Group（主轴不占位），返回是否新建
fn ensure_free_layer(doc : Document) -> Bool {
  if doc.has(FREE_LAYER_ID) {
    return false
  }
  // 自由层尺寸：按根栈方向，主轴 Fixed(0) 零占位；根无栈则铺满
  let (w, h) : (SizeSpec, SizeSpec) = match doc.get(doc.root_id) {
    Some(rn) =>
      match rn.layout {
        Some(l) =>
          match l.dir {
            Horizontal => (Fixed(0.0), Fill)
            Vertical => (Fill, Fixed(0.0))
          }
        None => (Fill, Fill)
      }
    None => (Fill, Fill)
  }
  let free = { ..Node::make(FREE_LAYER_ID, Group), width: w, height: h }
  doc.insert_node(free, doc.root_id)
}

///|
/// 人类拖拽：把节点放到画布绝对坐标 (x, y)。
/// 父容器无栈布局 → 就地改相对坐标；父容器有栈布局 → reparent 到自由层。
pub fn Project::move_node(
  self : Project,
  artboard~ : String,
  node_id~ : String,
  x~ : Double,
  y~ : Double,
) -> Result[String, String] {
  match self.artboards.get(artboard) {
    None => Err("unknown_artboard: \{artboard}")
    Some(ab) => {
      if node_id == ab.doc.root_id {
        return Err("cannot_move_root")
      }
      if node_id == FREE_LAYER_ID {
        return Err("cannot_move_free_layer")
      }
      match ab.doc.get(node_id) {
        None => Err("unknown_node: \{node_id}")
        Some(_n) => {
          let parent = match ab.doc.find_parent(node_id) {
            Some(p) => p
            None => return Err("orphan_node: \{node_id}")
          }
          // 宿主：父无栈 → 父本身；父有栈 → 自由层
          let host : String = match ab.doc.get(parent) {
            Some(pn) =>
              match pn.layout {
                None => parent
                Some(_) => FREE_LAYER_ID
              }
            None => FREE_LAYER_ID
          }
          let detached = host == FREE_LAYER_ID && parent != FREE_LAYER_ID
          if detached {
            let _ = ensure_free_layer(ab.doc)
            let _ = ab.doc.update_node(parent, pn => {
              ..pn,
              children: pn.children.filter(c => c != node_id),
            })
            // children 是数组引用，直接追加即可
            match ab.doc.get(FREE_LAYER_ID) {
              Some(fl) => fl.children.push(node_id)
              None => ()
            }
          }
          // 自由层新建后需重解一次才能拿到宿主矩形
          let layout = solve(ab.doc)
          let (hx, hy) : (Double, Double) = match layout.rect_of(host) {
            Some(r) => (r.x, r.y)
            None => (0.0, 0.0)
          }
          // 与 place 相同的边界策略：节点完整留在画板内容盒内。
          let nw : Double = match _n.width {
            Fixed(v) => v
            _ => 0.0
          }
          let nh : Double = match _n.height {
            Fixed(v) => v
            _ => 0.0
          }
          let safe_x = clamp_coord(x, 0.0, max_coord(ab.width - nw))
          let safe_y = clamp_coord(y, 0.0, max_coord(ab.height - nh))
          let rel_x = safe_x - hx
          let rel_y = safe_y - hy
          let _ = ab.doc.update_node(node_id, n => {
            ..n,
            x: Fixed(rel_x),
            y: Fixed(rel_y),
          })
          self.revision = self.revision + 1
          Ok(
            "{\"ok\":true,\"op\":\"move\",\"node\":\"\{node_id}\",\"x\":\{safe_x},\"y\":\{safe_y},\"host\":\"\{host}\",\"detached\":\{detached}}",
          )
        }
      }
    }
  }
}

///|
/// 人类编辑：key=value 批量更新节点属性。
/// 支持键：w h text fill text_color stroke radius opacity font_size weight
pub fn Project::edit_node(
  self : Project,
  artboard~ : String,
  node_id~ : String,
  kvs~ : Array[(String, String)],
) -> Result[String, String] {
  match self.artboards.get(artboard) {
    None => Err("unknown_artboard: \{artboard}")
    Some(ab) => {
      if !ab.doc.has(node_id) {
        return Err("unknown_node: \{node_id}")
      }
      let applied : Array[String] = []
      let _ = ab.doc.update_node(node_id, n => {
        let mut cur = n
        for kv in kvs.iter() {
          let (k, v) = kv
          let d = parse_double(v)
          match k {
            // w/h 接受数字（Fixed）或 "fill"/"hug" 简写（与 @decl.fill/@decl.hug 同义）
            "w" => {
              cur = { ..cur, width: match v {
                "fill" => Fill
                "hug" => Hug
                _ => Fixed(d)
              } }
              applied.push("w")
            }
            "h" => {
              cur = { ..cur, height: match v {
                "fill" => Fill
                "hug" => Hug
                _ => Fixed(d)
              } }
              applied.push("h")
            }
            "text" => {
              cur = { ..cur, text: v }
              applied.push("text")
            }
            "fill" => {
              cur = { ..cur, style: { ..cur.style, fill: v } }
              applied.push("fill")
            }
            "text_color" => {
              cur = { ..cur, style: { ..cur.style, text_color: v } }
              applied.push("text_color")
            }
            "stroke" => {
              cur = { ..cur, style: { ..cur.style, stroke: v } }
              applied.push("stroke")
            }
            "radius" => {
              cur = { ..cur, style: { ..cur.style, corner_radius: d } }
              applied.push("radius")
            }
            "opacity" => {
              let o = if d < 0.0 { 0.0 } else if d > 1.0 { 1.0 } else { d }
              cur = { ..cur, style: { ..cur.style, opacity: o } }
              applied.push("opacity")
            }
            "font_size" => {
              cur = { ..cur, style: { ..cur.style, font_size: d } }
              applied.push("font_size")
            }
            "weight" => {
              cur = { ..cur, style: { ..cur.style, font_weight: v } }
              applied.push("weight")
            }
            "shadow" => {
              cur = { ..cur, style: { ..cur.style, shadow: v } }
              applied.push("shadow")
            }
            "rotate" => {
              cur = { ..cur, style: { ..cur.style, rotate: d } }
              applied.push("rotate")
            }
            "blur" => {
              let b = if d < 0.0 { 0.0 } else { d }
              cur = { ..cur, style: { ..cur.style, blur: b } }
              applied.push("blur")
            }
            "blend" => {
              cur = { ..cur, style: { ..cur.style, blend: v } }
              applied.push("blend")
            }
            "line" => {
              let lh = if d < 1.0 { 1.0 } else { d }
              cur = { ..cur, style: { ..cur.style, line_height: lh } }
              applied.push("line")
            }
            "tracking" => {
              cur = { ..cur, style: { ..cur.style, tracking: d } }
              applied.push("tracking")
            }
            "constraint" => {
              cur = { ..cur, constraint: v }
              applied.push("constraint")
            }
            // 节点显示名（交互标记的载体；仅当偏离 id 时写入 canonical MBT）
            "name" => {
              cur = { ..cur, name: v }
              applied.push("name")
            }
            "stroke_width" => {
              let sw = if d < 0.0 { 0.0 } else { d }
              cur = { ..cur, style: { ..cur.style, stroke_width: sw } }
              applied.push("stroke_width")
            }
            "align" => {
              let a = if v == "center" || v == "right" { v } else { "left" }
              cur = { ..cur, style: { ..cur.style, text_align: a } }
              applied.push("align")
            }
            "italic" => {
              let f = if v == "true" || v == "1" || v == "italic" { "italic" } else { "normal" }
              cur = { ..cur, style: { ..cur.style, font_style: f } }
              applied.push("italic")
            }
            "dash" => {
              let ds = if v == "dashed" || v == "dotted" { v } else { "solid" }
              cur = { ..cur, style: { ..cur.style, stroke_dash: ds } }
              applied.push("dash")
            }
            "overlay" => {
              cur = { ..cur, style: { ..cur.style, overlay: v == "true" } }
              applied.push("overlay")
            }
            "visible" => {
              let vis = !(v == "false" || v == "0" || v == "off" || v == "hidden")
              cur = { ..cur, style: { ..cur.style, visible: vis } }
              applied.push("visible")
            }
            // 尺寸模式：hug（包裹内容）/ fill（撑满父容器）——布局引擎早已支持，
            // 此前只能通过 w/h 写死 Fixed。
            "width_mode" => {
              match v {
                "hug" => cur = { ..cur, width: Hug }
                "fill" => cur = { ..cur, width: Fill }
                _ => ()
              }
              applied.push("width_mode")
            }
            "height_mode" => {
              match v {
                "hug" => cur = { ..cur, height: Hug }
                "fill" => cur = { ..cur, height: Fill }
                _ => ()
              }
              applied.push("height_mode")
            }
            // 位置模式：center（父容器居中）/ end（贴 end 边，offset 由 dx/dy 语义另给）
            "x_mode" => {
              if v == "center" {
                cur = { ..cur, x: CenterInParent }
                applied.push("x_mode")
              } else if v == "start" {
                cur = { ..cur, x: AlignStart(pos_offset_x(cur.x)) }
                applied.push("x_mode")
              }
            }
            "y_mode" => {
              if v == "center" {
                cur = { ..cur, y: CenterInParent }
                applied.push("y_mode")
              } else if v == "start" {
                cur = { ..cur, y: AlignStart(pos_offset_y(cur.y)) }
                applied.push("y_mode")
              }
            }
            // 容器栈布局：layout=vertical|horizontal 启用/切换；none 还原为绝对定位。
            // 此前 StackLayout 只能由模板或 place 产生，update 完全无法设置。
            "layout" => {
              match v {
                "none" => {
                  cur = { ..cur, layout: None }
                  applied.push("layout")
                }
                "vertical" | "horizontal" => {
                  let base = match cur.layout {
                    Some(l) => l
                    None =>
                      {
                        dir: Vertical,
                        gap: 0.0,
                        justify: Start,
                        padding: Padding::uniform(0.0),
                      }
                  }
                  let dir = if v == "horizontal" { Horizontal } else { Vertical }
                  cur = { ..cur, layout: Some({ ..base, dir }) }
                  applied.push("layout")
                }
                _ => ()
              }
            }
            "gap" => {
              match cur.layout {
                Some(l) => {
                  let g = if d < 0.0 { 0.0 } else { d }
                  cur = { ..cur, layout: Some({ ..l, gap: g }) }
                  applied.push("gap")
                }
                None => ()
              }
            }
            "justify" => {
              match cur.layout {
                Some(l) => {
                  let j = match v {
                    "center" => Center
                    "end" => End
                    _ => Start
                  }
                  cur = { ..cur, layout: Some({ ..l, justify: j }) }
                  applied.push("justify")
                }
                None => ()
              }
            }
            // 统一内边距（四边同值）；细分方向由模板/组件承担
            "padding" => {
              match cur.layout {
                Some(l) => {
                  let p = if d < 0.0 { 0.0 } else { d }
                  cur = { ..cur, layout: Some({ ..l, padding: Padding::uniform(p) }) }
                  applied.push("padding")
                }
                None => ()
              }
            }
            _ => ()
          }
        }
        cur
      })
      self.revision = self.revision + 1
      Ok(
        "{\"ok\":true,\"op\":\"update\",\"node\":\"\{node_id}\",\"fields\":\{applied.length()}}",
      )
    }
  }
}

///|
/// 取位置规格的数值分量（x_mode/y_mode 降级为 AlignStart 时保留原偏移）
pub fn pos_offset_x(p : PosSpec) -> Double {
  match p {
    Fixed(v) => v
    AlignStart(v) => v
    AlignEnd(v) => v
    CenterInParent => 0.0
  }
}

///|
pub fn pos_offset_y(p : PosSpec) -> Double {
  match p {
    Fixed(v) => v
    AlignStart(v) => v
    AlignEnd(v) => v
    CenterInParent => 0.0
  }
}

///|
/// 人类删除：摘除整个子树
pub fn Project::delete_node(
  self : Project,
  artboard~ : String,
  node_id~ : String,
) -> Result[String, String] {
  match self.artboards.get(artboard) {
    None => Err("unknown_artboard: \{artboard}")
    Some(ab) => {
      if node_id == ab.doc.root_id {
        return Err("cannot_delete_root")
      }
      match ab.doc.find_parent(node_id) {
        None => Err("unknown_node: \{node_id}")
        Some(parent) => {
          let ids : Array[String] = []
          collect_subtree(ab.doc, node_id, ids)
          let _ = ab.doc.update_node(parent, pn => {
            ..pn,
            children: pn.children.filter(c => c != node_id),
          })
          for i in ids.iter() {
            ab.doc.nodes.remove(i)
          }
          self.revision = self.revision + 1
          Ok(
            "{\"ok\":true,\"op\":\"delete\",\"node\":\"\{node_id}\",\"removed\":\{ids.length()}}",
          )
        }
      }
    }
  }
}
