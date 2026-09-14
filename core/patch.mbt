/// 补丁协议（docs/05）：两条路线共用的变更语言。
///
/// 事务语义：先在候选副本上应用全部操作并校验，通过才整体合并——
/// 要么全部生效，要么什么都不改。Agent 路线任何违规都会被拒（硬门槛），
/// 人类路线只有结构性违规被拒。

///|
/// 节点字段补丁：None = 不修改
pub(all) struct NodePatch {
  name : String?
  width : SizeSpec?
  height : SizeSpec?
  x : PosSpec?
  y : PosSpec?
  text : String?
  layout_dir : StackDir?
  layout_gap : Double?
  layout_justify : Justify?
  layout_padding : Padding?
  fill : String?
  stroke : String?
  corner_radius : Double?
  font_size : Double?
  text_color : String?
}

///|
pub fn NodePatch::empty() -> NodePatch {
  {
    name: None,
    width: None,
    height: None,
    x: None,
    y: None,
    text: None,
    layout_dir: None,
    layout_gap: None,
    layout_justify: None,
    layout_padding: None,
    fill: None,
    stroke: None,
    corner_radius: None,
    font_size: None,
    text_color: None,
  }
}

///|
pub(all) enum Op {
  InsertNode(Node, String) // 新节点, 父节点 id（追加到 children 末尾）
  UpdateNode(String, NodePatch) // 目标 id, 字段补丁
  MoveNode(String, String) // 目标 id, 新父 id
  DeleteNode(String) // 删除节点及其子树
}

///|
pub(all) struct Patch {
  base_revision : Int
  message : String
  ops : Array[Op]
}

///|
pub(all) enum PatchError {
  StaleBase(Int) // 携带文档当前 revision：需重新读取后提交
  UnknownNode(String)
  UnknownParent(String)
  DuplicateId(String)
  HierarchyError(String) // 移入自己的子树、删除根节点等
  StructuralBlock(Array[Violation]) // 结构谓词失败（两条路线都拒绝）
  HardBlock(Array[Violation]) // 视觉谓词失败（仅 Agent 路线拒绝）
}

///|
/// Agent 路线入口：硬门槛。成功返回空违规集（永远为空）。
pub fn apply_agent_patch(
  doc : Document,
  patch : Patch,
) -> Result[Array[Violation], PatchError] {
  apply_inner(doc, patch, AgentGate)
}

///|
/// 人类路线入口：结构硬、视觉软。成功时返回携带的视觉债。
pub fn apply_human_op(
  doc : Document,
  patch : Patch,
) -> Result[Array[Violation], PatchError] {
  apply_inner(doc, patch, HumanGate)
}

///|
fn apply_inner(
  doc : Document,
  patch : Patch,
  gate : Gate,
) -> Result[Array[Violation], PatchError] {
  if patch.base_revision != doc.revision {
    return Err(StaleBase(doc.revision))
  }
  // 1) 在候选副本上应用全部操作
  let candidate = doc.clone()
  for op in patch.ops.iter() {
    match apply_op(candidate, op) {
      Err(e) => return Err(e)
      Ok(_) => ()
    }
  }
  // 2) 校验候选状态
  let violations = validate(candidate)
  // 3) 按路线策略决定是否合并
  match decide(gate, violations) {
    Reject(blocking) => {
      let err : PatchError = match gate {
        AgentGate => HardBlock(blocking)
        HumanGate => StructuralBlock(blocking)
      }
      Err(err)
    }
    Allow(debt) => {
      let source : OpSource = match gate {
        AgentGate => AgentOp
        HumanGate => HumanOp
      }
      doc.nodes = candidate.nodes
      doc.root_id = candidate.root_id
      doc.revision = doc.revision + 1
      doc.journal.push({
        revision: doc.revision,
        source,
        message: patch.message,
        violation_count: debt.length(),
      })
      Ok(debt)
    }
  }
}

///|
fn apply_op(doc : Document, op : Op) -> Result[Unit, PatchError] {
  match op {
    InsertNode(node, parent_id) => {
      if doc.has(node.id) {
        return Err(DuplicateId(node.id))
      }
      if !doc.has(parent_id) {
        return Err(UnknownParent(parent_id))
      }
      if doc.insert_node(node, parent_id) {
        Ok(())
      } else {
        Err(HierarchyError("插入失败"))
      }
    }
    UpdateNode(id, p) =>
      match doc.nodes.get(id) {
        None => Err(UnknownNode(id))
        Some(_) => {
          let _ = doc.update_node(id, fn(n) { apply_node_patch(n, p) })
          Ok(())
        }
      }
    MoveNode(id, new_parent) => {
      if !doc.has(id) {
        return Err(UnknownNode(id))
      }
      if !doc.has(new_parent) {
        return Err(UnknownParent(new_parent))
      }
      if id == doc.root_id {
        return Err(HierarchyError("不能移动根节点"))
      }
      if is_descendant(doc, id, new_parent) {
        return Err(
          HierarchyError("不能把节点移动到它自己的子树内"),
        )
      }
      match doc.find_parent(id) {
        None => Err(HierarchyError("找不到旧父节点"))
        Some(old_parent) => {
          detach_child(doc, old_parent, id)
          append_child(doc, new_parent, id)
          Ok(())
        }
      }
    }
    DeleteNode(id) => {
      if !doc.has(id) {
        return Err(UnknownNode(id))
      }
      if id == doc.root_id {
        return Err(HierarchyError("不能删除根节点"))
      }
      match doc.find_parent(id) {
        None => Err(HierarchyError("找不到父节点"))
        Some(parent_id) => {
          detach_child(doc, parent_id, id)
          delete_subtree(doc, id)
          Ok(())
        }
      }
    }
  }
}

///|
fn apply_node_patch(n : Node, p : NodePatch) -> Node {
  let n = match p.name {
    Some(v) => { ..n, name: v }
    None => n
  }
  let n = match p.width {
    Some(v) => { ..n, width: v }
    None => n
  }
  let n = match p.height {
    Some(v) => { ..n, height: v }
    None => n
  }
  let n = match p.x {
    Some(v) => { ..n, x: v }
    None => n
  }
  let n = match p.y {
    Some(v) => { ..n, y: v }
    None => n
  }
  let n = match p.text {
    Some(v) => { ..n, text: v }
    None => n
  }
  // 布局字段：任一出现即整块重建（无则按缺省布局初始化）
  let layout : StackLayout? = match
    (p.layout_dir, p.layout_gap, p.layout_justify, p.layout_padding) {
    (None, None, None, None) => n.layout
    _ => {
      let base : StackLayout = match n.layout {
        Some(b) => b
        None =>
          {
            dir: Vertical,
            gap: 0.0,
            justify: Start,
            padding: Padding::uniform(0.0),
          }
      }
      let dir : StackDir = match p.layout_dir {
        Some(d) => d
        None => base.dir
      }
      let gap : Double = match p.layout_gap {
        Some(g) => g
        None => base.gap
      }
      let justify : Justify = match p.layout_justify {
        Some(j) => j
        None => base.justify
      }
      let padding : Padding = match p.layout_padding {
        Some(pd) => pd
        None => base.padding
      }
      Some({ dir, gap, justify, padding })
    }
  }
  let n = { ..n, layout, }
  let style = n.style
  let fill : String = match p.fill {
    Some(v) => v
    None => style.fill
  }
  let stroke : String = match p.stroke {
    Some(v) => v
    None => style.stroke
  }
  let corner_radius : Double = match p.corner_radius {
    Some(v) => v
    None => style.corner_radius
  }
  let font_size : Double = match p.font_size {
    Some(v) => v
    None => style.font_size
  }
  let text_color : String = match p.text_color {
    Some(v) => v
    None => style.text_color
  }
  {
    ..n,
    style: { ..style, fill, stroke, corner_radius, font_size, text_color },
  }
}

///|
fn detach_child(doc : Document, parent_id : String, child_id : String) -> Unit {
  match doc.nodes.get(parent_id) {
    Some(p) => {
      let kids : Array[String] = Array::new()
      for c in p.children.iter() {
        if c != child_id {
          kids.push(c)
        }
      }
      doc.nodes.set(parent_id, { ..p, children: kids })
    }
    None => ()
  }
}

///|
fn append_child(doc : Document, parent_id : String, child_id : String) -> Unit {
  match doc.nodes.get(parent_id) {
    Some(p) => {
      let kids = p.children.copy()
      kids.push(child_id)
      doc.nodes.set(parent_id, { ..p, children: kids })
    }
    None => ()
  }
}

///|
fn delete_subtree(doc : Document, id : String) -> Unit {
  match doc.nodes.get(id) {
    Some(n) => {
      for c in n.children.iter() {
        delete_subtree(doc, c)
      }
      let _ = doc.nodes.remove(id)
    }
    None => ()
  }
}

///|
/// candidate 是否位于 ancestor 的子树内
fn is_descendant(doc : Document, ancestor : String, candidate : String) -> Bool {
  match doc.nodes.get(ancestor) {
    None => false
    Some(n) => {
      let mut found = false
      for c in n.children.iter() {
        if c == candidate {
          found = true
        } else if !found && is_descendant(doc, c, candidate) {
          found = true
        }
      }
      found
    }
  }
}
