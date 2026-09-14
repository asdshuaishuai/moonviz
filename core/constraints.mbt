/// 约束系统（Figma Constraints）+ Z 序（Reorder）。
///
/// constraint 语义（四字符/词法：水平 _ 垂直，简写如 "lt" "rt" "ct" "cb" "stretch-c" "hscale-m"）：
///   水平：l=左锚定  c=水平居中  r=右锚定  stretch=拉伸  hscale=等比
///   垂直：t=上锚定  m=垂直居中  b=下锚定（stretch/hscale 亦适用）
/// 画板 resize 时按约束重排全部节点——这是 Figma 的灵魂行为：
/// 同一设计稿出一排尺寸，不再需要逐个手调。

///|
/// 解析约束：返回 (水平, 垂直)
/// "lt" → (l,t)；"stretch-c" → (stretch,c)；"hscale_m" → (hscale,m)
fn parse_constraint(c : String) -> (String, String) {
  // 分隔符兼容 '_' 与 '-'
  let parts = split_two_axes(c)
  let h_part = first_char(parts[0])
  let v_part = if parts.length() > 1 {
    first_char(parts[1])
  } else {
    second_char(parts[0], "t")
  }
  let hnorm = normalize_axis(h_part, "l")
  let vnorm = normalize_axis(v_part, "t")
  (hnorm, vnorm)
}

///|
/// 两字符简写的第二个字符（"lt" → "t"）
fn second_char(s : String, fallback : String) -> String {
  if s.length() >= 2 {
    s.substring(start=1, end=2)
  } else {
    fallback
  }
}

///|
/// 按 '_' 或 '-' 拆成两段（无分隔：两字符简写拆开）
fn split_two_axes(c : String) -> Array[String] {
  let out : Array[String] = []
  let cur = StringBuilder::new()
  for ch in c.iter() {
    if ch == '_' || ch == '-' {
      out.push(cur.to_string())
      cur.reset()
    } else {
      cur.write_char(ch)
    }
  }
  out.push(cur.to_string())
  out
}

///|
fn first_char(s : String) -> String {
  if s.length() > 0 {
    s.substring(start=0, end=1)
  } else {
    ""
  }
}

///|
fn normalize_axis(ch : String, fallback : String) -> String {
  match ch {
    "l" | "t" => "l"
    "c" | "m" => "c"
    "r" | "b" => "r"
    "s" => "stretch"
    "h" => "hscale"
    _ => fallback
  }
}

///|
/// 画板尺寸变更：按约束重排所有节点的 PosSpec / SizeSpec。
/// 逐节点处理（父先于子不敏感——PosSpec 均相对父内容盒，dW/dH 逐层传递比例）。
pub fn Project::resize_canvas(
  self : Project,
  artboard~ : String,
  width~ : Double,
  height~ : Double,
) -> Result[String, String] {
  match self.artboards.get(artboard) {
    None => Err("unknown_artboard: \{artboard}")
    Some(ab) => {
      let old_w = ab.width
      let old_h = ab.height
      if old_w <= 0.0 || old_h <= 0.0 {
        return Err("invalid_old_size")
      }
      let d_w = width - old_w
      let d_h = height - old_h
      // 根节点尺寸
      let _ = ab.doc.update_node(ab.doc.root_id, fn(n) {
        { ..n, width: Fixed(width), height: Fixed(height) }
      })
      // 非根节点按 constraint 调整（相对其父内容盒的尺寸变化近似 = 画板变化，
      // 对嵌套栈布局，栈主轴由布局决定不受影响；cross 轴与绝对定位节点按约束适配）
      for id in ab.doc.nodes.keys() {
        if id == ab.doc.root_id {
          continue
        }
        let _ = ab.doc.update_node(id, fn(n) {
          let (h_c, v_c) = parse_constraint(n.constraint)
          let mut out = n
          // 水平
          match h_c {
            "r" => {
              let off = pos_offset(out.x)
              out = { ..out, x: Fixed(off + d_w) }
            }
            "c" => {
              let off = pos_offset(out.x)
              out = { ..out, x: Fixed(off + d_w / 2.0) }
            }
            "stretch" => {
              let off = pos_offset(out.x)
              let w = size_val(out.width)
              if w > 0.0 {
                out = { ..out, x: Fixed(off), width: Fixed(w + d_w) }
              }
            }
            "hscale" => {
              let off = pos_offset(out.x)
              let w = size_val(out.width)
              if w > 0.0 && old_w > 0.0 {
                let k = width / old_w
                out = { ..out, x: Fixed(off * k), width: Fixed(w * k) }
              }
            }
            _ => ()
          }
          // 垂直
          match v_c {
            "r" => {
              let off = pos_offset(out.y)
              out = { ..out, y: Fixed(off + d_h) }
            }
            "c" => {
              let off = pos_offset(out.y)
              out = { ..out, y: Fixed(off + d_h / 2.0) }
            }
            "stretch" => {
              let off = pos_offset(out.y)
              let h = size_val(out.height)
              if h > 0.0 {
                out = { ..out, y: Fixed(off), height: Fixed(h + d_h) }
              }
            }
            "hscale" => {
              let off = pos_offset(out.y)
              let h = size_val(out.height)
              if h > 0.0 && old_h > 0.0 {
                let k = height / old_h
                out = { ..out, y: Fixed(off * k), height: Fixed(h * k) }
              }
            }
            _ => ()
          }
          out
        })
      }
      // 更新画板元数据
      let meta = self.artboards.get(artboard)
      match meta {
        Some(m) => self.artboards.set(artboard, { ..m, width, height })
        None => ()
      }
      self.revision = self.revision + 1
      Ok(
        "{\"ok\":true,\"op\":\"resize_canvas\",\"artboard\":\"\{artboard}\",\"from_w\":\{old_w},\"from_h\":\{old_h},\"to_w\":\{width},\"to_h\":\{height}}",
      )
    }
  }
}

///|
fn pos_offset(p : PosSpec) -> Double {
  match p {
    Fixed(v) => v
    AlignStart(v) => v
    AlignEnd(v) => v
    CenterInParent => 0.0
  }
}

///|
fn size_val(s : SizeSpec) -> Double {
  match s {
    Fixed(v) => v
    _ => 0.0
  }
}

///|
/// Z 序：reorder <ab> <node> front|back|up|down
pub fn Project::reorder_node(
  self : Project,
  artboard~ : String,
  node_id~ : String,
  order~ : String,
) -> Result[String, String] {
  match self.artboards.get(artboard) {
    None => Err("unknown_artboard: \{artboard}")
    Some(ab) => {
      let parent = match ab.doc.find_parent(node_id) {
        Some(p) => p
        None => return Err("orphan_node: \{node_id}")
      }
      let mut moved = false
      let _ = ab.doc.update_node(parent, fn(pn) {
        let kids = pn.children.copy()
        let mut idx = -1
        for i in 0..<kids.length() {
          if kids[i] == node_id {
            idx = i
          }
        }
        if idx < 0 {
          return pn
        }
        let item = kids[idx]
        let rest : Array[String] = []
        for i in 0..<kids.length() {
          if i != idx {
            rest.push(kids[i])
          }
        }
        let out : Array[String] = []
        match order {
          "front" => {
            for c in rest.iter() {
              out.push(c)
            }
            out.push(item)
            moved = true
            { ..pn, children: out }
          }
          "back" => {
            out.push(item)
            for c in rest.iter() {
              out.push(c)
            }
            moved = true
            { ..pn, children: out }
          }
          "up" =>
            if idx < kids.length() - 1 {
              // 与后一个交换
              for i in 0..<kids.length() {
                if i == idx {
                  out.push(kids[i + 1])
                  out.push(item)
                } else if i == idx + 1 {
                  continue
                } else {
                  out.push(kids[i])
                }
              }
              moved = true
              { ..pn, children: out }
            } else {
              pn
            }
          "down" =>
            if idx > 0 {
              for i in 0..<kids.length() {
                if i == idx - 1 {
                  out.push(item)
                  out.push(kids[i])
                } else if i == idx {
                  continue
                } else {
                  out.push(kids[i])
                }
              }
              moved = true
              { ..pn, children: out }
            } else {
              pn
            }
          _ => pn
        }
      })
      if !moved {
        return Ok("{\"ok\":false,\"reason\":\"no_change\"}")
      }
      self.revision = self.revision + 1
      Ok(
        "{\"ok\":true,\"op\":\"reorder\",\"node\":\"\{node_id}\",\"order\":\"\{order}\"}",
      )
    }
  }
}

///|
/// 主组件样式传播（Figma Component Override 的批量简化语义）：
/// restyle <ab> <component_id> k=v ... → 该画板所有 component 匹配的节点统一重样式。
/// 引擎职责仍是确定性批量命令，不含任何 NL。
pub fn Project::restyle_component(
  self : Project,
  artboard~ : String,
  component_id~ : String,
  kvs~ : Array[(String, String)],
) -> Result[String, String] {
  match self.artboards.get(artboard) {
    None => Err("unknown_artboard: \{artboard}")
    Some(ab) => {
      let targets : Array[String] = []
      for id in ab.doc.nodes.keys() {
        match ab.doc.get(id) {
          Some(n) => if n.component == component_id { targets.push(id) }
          None => ()
        }
      }
      let mut applied = 0
      for tid in targets.iter() {
        match self.edit_node(artboard~, node_id=tid, kvs~) {
          Ok(_) => applied = applied + 1
          Err(_) => ()
        }
      }
      self.revision = self.revision + 1
      Ok(
        "{\"ok\":true,\"op\":\"restyle\",\"component\":\"\{component_id}\",\"instances\":\{applied}}",
      )
    }
  }
}
