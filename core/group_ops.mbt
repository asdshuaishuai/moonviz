/// 结构操作 v2：打组/解组（包围盒换算）、多节点对齐、翻转、节点复制。
/// 语义对齐 Figma：
/// - group：同父（绝对定位容器）下多节点 → Group，坐标换算到组内相对
/// - ungroup：组员坐标还原回父坐标系，组移除
/// - align：多节点向包围盒边缘/中心对齐
/// - flip：水平/垂直镜像（渲染 transform）
/// - copy：子树克隆 + 偏移放置

///|
/// 打组：同父绝对容器下的多个节点 → Group
pub fn Project::group_nodes(
  self : Project,
  artboard~ : String,
  node_ids~ : Array[String],
  group_id~ : String,
) -> Result[String, String] {
  match self.artboards.get(artboard) {
    None => Err("unknown_artboard: \{artboard}")
    Some(ab) => {
      if node_ids.length() < 2 {
        return Err("need_two_nodes")
      }
      if ab.doc.has(group_id) {
        return Err("id_exists: \{group_id}")
      }
      let layout = solve(ab.doc)
      let mut parent = ""
      for nid in node_ids.iter() {
        match ab.doc.get(nid) {
          None => return Err("unknown_node: \{nid}")
          Some(_) => {
            let p = match ab.doc.find_parent(nid) {
              Some(p) => p
              None => return Err("orphan_node: \{nid}")
            }
            if parent == "" {
              parent = p
            } else if parent != p {
              return Err("mixed_parents")
            }
          }
        }
      }
      let pn = match ab.doc.get(parent) {
        Some(p) => p
        None => return Err("orphan_parent")
      }
      match pn.layout {
        Some(_) => return Err("unsupported_parent_layout")
        None => ()
      }
      let parent_rect = match layout.rect_of(parent) {
        Some(r) => r
        None => Rect::new(0.0, 0.0, 0.0, 0.0)
      }
      // 包围盒（画布绝对）
      let mut min_x = 1000000000000000000.0
      let mut min_y = 1000000000000000000.0
      let mut max_x = -1000000000000000000.0
      let mut max_y = -1000000000000000000.0
      for nid in node_ids.iter() {
        match layout.rect_of(nid) {
          Some(r) => {
            if r.x < min_x {
              min_x = r.x
            }
            if r.y < min_y {
              min_y = r.y
            }
            if r.x + r.width > max_x {
              max_x = r.x + r.width
            }
            if r.y + r.height > max_y {
              max_y = r.y + r.height
            }
          }
          None => ()
        }
      }
      if max_x < 0.0 {
        return Err("no_geometry")
      }
      let bw = max_x - min_x
      let bh = max_y - min_y
      let group = {
        ..Node::make(group_id, Group),
        name: group_id,
        width: Fixed(bw),
        height: Fixed(bh),
        x: Fixed(min_x - parent_rect.x),
        y: Fixed(min_y - parent_rect.y),
      }
      let _ = ab.doc.insert_node(group, parent)
      for nid in node_ids.iter() {
        let _ = ab.doc.update_node(nid, fn(x) {
          let nx = pos_offset_v(x.x) - (min_x - parent_rect.x)
          let ny = pos_offset_v(x.y) - (min_y - parent_rect.y)
          { ..x, x: Fixed(nx), y: Fixed(ny) }
        })
        let _ = ab.doc.update_node(parent, fn(p) {
          { ..p, children: p.children.filter(c => c != nid) }
        })
        match ab.doc.get(group_id) {
          Some(g) => g.children.push(nid)
          None => ()
        }
      }
      self.revision = self.revision + 1
      Ok(
        "{\"ok\":true,\"op\":\"group\",\"id\":\"\{group_id}\",\"members\":\{node_ids.length()},\"bounds\":{\"x\":\{min_x},\"y\":\{min_y},\"w\":\{bw},\"h\":\{bh}}}",
      )
    }
  }
}

///|
fn pos_offset_v(p : PosSpec) -> Double {
  match p {
    Fixed(v) => v
    AlignStart(v) => v
    AlignEnd(v) => v
    CenterInParent => 0.0
  }
}

///|
/// 解组：组员坐标还原回父坐标系
pub fn Project::ungroup_node(
  self : Project,
  artboard~ : String,
  group_id~ : String,
) -> Result[String, String] {
  match self.artboards.get(artboard) {
    None => Err("unknown_artboard: \{artboard}")
    Some(ab) => {
      let g = match ab.doc.get(group_id) {
        Some(g) => g
        None => return Err("unknown_node: \{group_id}")
      }
      let is_group = match g.kind {
        Group => true
        _ => false
      }
      if !is_group {
        return Err("not_a_group")
      }
      let parent = match ab.doc.find_parent(group_id) {
        Some(p) => p
        None => return Err("orphan_node")
      }
      let gx = pos_offset_v(g.x)
      let gy = pos_offset_v(g.y)
      let members = g.children.copy()
      for mid in members.iter() {
        let _ = ab.doc.update_node(mid, fn(x) {
          {
            ..x,
            x: Fixed(gx + pos_offset_v(x.x)),
            y: Fixed(gy + pos_offset_v(x.y)),
          }
        })
        match ab.doc.get(parent) {
          Some(pn) => pn.children.push(mid)
          None => ()
        }
      }
      let _ = ab.doc.update_node(parent, fn(p) {
        { ..p, children: p.children.filter(c => c != group_id) }
      })
      ab.doc.nodes.remove(group_id)
      self.revision = self.revision + 1
      Ok(
        "{\"ok\":true,\"op\":\"ungroup\",\"id\":\"\{group_id}\",\"members\":\{members.length()}}",
      )
    }
  }
}

///|
/// 多节点对齐：left|right|top|bottom|hcenter|vcenter（相对节点集合包围盒）
pub fn Project::align_nodes(
  self : Project,
  artboard~ : String,
  mode~ : String,
  node_ids~ : Array[String],
) -> Result[String, String] {
  match self.artboards.get(artboard) {
    None => Err("unknown_artboard: \{artboard}")
    Some(ab) => {
      if node_ids.length() < 2 {
        return Err("need_two_nodes")
      }
      let layout = solve(ab.doc)
      let mut min_x = 1000000000000000000.0
      let mut min_y = 1000000000000000000.0
      let mut max_r = -1000000000000000000.0
      let mut max_b = -1000000000000000000.0
      for nid in node_ids.iter() {
        match layout.rect_of(nid) {
          Some(r) => {
            if r.x < min_x {
              min_x = r.x
            }
            if r.y < min_y {
              min_y = r.y
            }
            if r.x + r.width > max_r {
              max_r = r.x + r.width
            }
            if r.y + r.height > max_b {
              max_b = r.y + r.height
            }
          }
          None => ()
        }
      }
      if max_r < 0.0 {
        return Err("no_geometry")
      }
      let mut moved = 0
      for nid in node_ids.iter() {
        let r = match layout.rect_of(nid) {
          Some(r) => r
          None => continue
        }
        let (tx, ty) : (Double, Double) = match mode {
          "left" => (min_x, r.y)
          "right" => (max_r - r.width, r.y)
          "top" => (r.x, min_y)
          "bottom" => (r.x, max_b - r.height)
          "hcenter" => ((min_x + max_r - r.width) / 2.0, r.y)
          "vcenter" => (r.x, (min_y + max_b - r.height) / 2.0)
          _ => return Err("unknown_mode: \{mode}")
        }
        let dx = tx - r.x
        let dy = ty - r.y
        if dx * dx + dy * dy < 0.0001 {
          continue
        }
        let _ = ab.doc.update_node(nid, fn(x) {
          {
            ..x,
            x: Fixed(pos_offset_v(x.x) + dx),
            y: Fixed(pos_offset_v(x.y) + dy),
          }
        })
        moved = moved + 1
      }
      self.revision = self.revision + 1
      Ok(
        "{\"ok\":true,\"op\":\"align\",\"mode\":\"\{mode}\",\"moved\":\{moved}}",
      )
    }
  }
}

///|
/// 翻转：flip h|v|both|none
pub fn Project::flip_node(
  self : Project,
  artboard~ : String,
  node_id~ : String,
  axis~ : String,
) -> Result[String, String] {
  match self.artboards.get(artboard) {
    None => Err("unknown_artboard: \{artboard}")
    Some(ab) => {
      if !ab.doc.has(node_id) {
        return Err("unknown_node: \{node_id}")
      }
      let _ = ab.doc.update_node(node_id, fn(n) {
        { ..n, style: { ..n.style, flip: axis } }
      })
      self.revision = self.revision + 1
      Ok(
        "{\"ok\":true,\"op\":\"flip\",\"node\":\"\{node_id}\",\"axis\":\"\{axis}\"}",
      )
    }
  }
}

///|
/// 复制节点：子树克隆 + 偏移
pub fn Project::copy_node(
  self : Project,
  artboard~ : String,
  node_id~ : String,
  new_id~ : String,
  dx~ : Double,
  dy~ : Double,
) -> Result[String, String] {
  match self.artboards.get(artboard) {
    None => Err("unknown_artboard: \{artboard}")
    Some(ab) => {
      if ab.doc.has(new_id) {
        return Err("id_exists: \{new_id}")
      }
      let src = match ab.doc.get(node_id) {
        Some(n) => n
        None => return Err("unknown_node: \{node_id}")
      }
      let parent = match ab.doc.find_parent(node_id) {
        Some(p) => p
        None => return Err("orphan_node")
      }
      let copied = clone_recursive(ab.doc, src, new_id, new_id, dx, dy)
      match copied {
        None => Err("clone_failed")
        Some(root) => {
          let ok = ab.doc.insert_node(root, parent)
          if !ok {
            return Err("insert_failed")
          }
          let count = count_subtree(ab.doc, new_id)
          Ok(
            "{\"ok\":true,\"op\":\"copy\",\"node\":\"\{new_id}\",\"from\":\"\{node_id}\",\"nodes\":\{count}}",
          )
        }
      }
    }
  }
}

///|
/// 深克隆：根用 root_id，子孙 id = prefix + 原id；根偏移 (dx,dy)
fn clone_recursive(
  doc : Document,
  n : Node,
  root_id : String,
  prefix : String,
  dx : Double,
  dy : Double,
) -> Node? {
  let new_id = root_id
  if doc.has(new_id) {
    return None
  }
  let shift_x = match n.x {
    Fixed(v) => v + dx
    AlignStart(v) => v + dx
    _ => dx
  }
  let shift_y = match n.y {
    Fixed(v) => v + dy
    AlignStart(v) => v + dy
    _ => dy
  }
  let out = {
    ..n,
    id: new_id,
    children: [],
    x: Fixed(shift_x),
    y: Fixed(shift_y),
  }
  for cid in n.children.iter() {
    match doc.get(cid) {
      None => ()
      Some(child) =>
        match clone_recursive(doc, child, prefix + cid, prefix, 0.0, 0.0) {
          None => ()
          Some(cc) => {
            let _ = doc.register(cc)
            out.children.push(cc.id)
          }
        }
    }
  }
  Some(out)
}

///|
fn count_subtree(doc : Document, id : String) -> Int {
  match doc.get(id) {
    None => 0
    Some(n) => {
      let mut c = 1
      for cid in n.children.iter() {
        c = c + count_subtree(doc, cid)
      }
      c
    }
  }
}
