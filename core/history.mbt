///|
/// 设计版本控制：时间旅行 / 分支 / 变更回放。
///
/// 每次对项目的修改都产生一个"commit"（快照 + 操作记录）。
/// Agent 可以：
/// - 查看完整历史（谁在什么时候做了什么）
/// - 时间旅行到任意版本（预览旧状态）
/// - 从任意版本分叉新分支（探索不同方向）
/// - 回放两个版本之间的变更（逐步看每步做了什么）
/// - 撤销 / 重做
pub(all) struct HistoryEntry {
  revision : Int
  timestamp : String
  agent_id : String
  message : String
  ops : Array[DesignOp]
  snapshot : Document
}

///|
pub(all) struct DesignHistory {
  entries : Array[HistoryEntry]
  mut current_revision : Int
  mut branch_name : String
  mut undo_stack : Array[Int]
  mut redo_stack : Array[Int]
}

///|
pub fn DesignHistory::new(initial_doc : Document) -> DesignHistory {
  let h : DesignHistory = {
    entries: [],
    current_revision: 0,
    branch_name: "main",
    undo_stack: [],
    redo_stack: [],
  }
  h.entries.push({
    revision: 0,
    timestamp: "init",
    agent_id: "system",
    message: "初始版本",
    ops: [],
    snapshot: initial_doc,
  })
  h
}

///|
pub fn DesignHistory::commit(
  self : DesignHistory,
  agent_id : String,
  message : String,
  ops : Array[DesignOp],
  doc : Document,
) -> Int {
  let rev = self.current_revision + 1
  self.entries.push({
    revision: rev,
    timestamp: "t" + rev.to_string(),
    agent_id,
    message,
    ops,
    snapshot: doc,
  })
  self.undo_stack.push(self.current_revision)
  self.current_revision = rev
  rev
}

///|
pub fn DesignHistory::rev(self : DesignHistory) -> Int {
  self.current_revision
}

///|
pub fn DesignHistory::checkout(
  self : DesignHistory,
  revision : Int,
) -> Result[Document, String] {
  for e in self.entries.iter() {
    if e.revision == revision {
      return Ok(e.snapshot)
    }
  }
  Err("revision_not_found: " + revision.to_string())
}

///|
pub fn DesignHistory::undo(self : DesignHistory) -> Result[Document, String] {
  if self.undo_stack.length() == 0 {
    return Err("nothing_to_undo")
  }
  let prev = self.undo_stack[self.undo_stack.length() - 1]
  let _ = self.undo_stack.pop()
  self.redo_stack.push(self.current_revision)
  self.current_revision = prev
  self.checkout(prev)
}

///|
pub fn DesignHistory::redo(self : DesignHistory) -> Result[Document, String] {
  if self.redo_stack.length() == 0 {
    return Err("nothing_to_redo")
  }
  let next = self.redo_stack[self.redo_stack.length() - 1]
  let _ = self.redo_stack.pop()
  self.undo_stack.push(self.current_revision)
  self.current_revision = next
  self.checkout(next)
}

///|
pub fn DesignHistory::log(self : DesignHistory) -> String {
  let sb = StringBuilder::new()
  let total = self.entries.length().to_string()
  sb.write_string("History (" + self.branch_name + ", " + total + " commits)\n")
  for i in 0..<self.entries.length() {
    let e = self.entries[self.entries.length() - 1 - i]
    let marker = if e.revision == self.current_revision { "→" } else { " " }
    let rev_str = e.revision.to_string()
    sb.write_string(
      marker + " rev" + rev_str + " [" + e.agent_id + "] " + e.message + "\n",
    )
    if e.ops.length() > 0 {
      let ops_count = e.ops.length().to_string()
      sb.write_string("   ops: " + ops_count + "\n")
    }
  }
  sb.to_string()
}

///|
pub fn DesignHistory::replay(
  self : DesignHistory,
  from_rev : Int,
  to_rev : Int,
) -> Result[String, String] {
  let ops_found : Array[String] = []
  let mut found = false
  for e in self.entries.iter() {
    if e.revision > from_rev && e.revision <= to_rev {
      found = true
      for op in e.ops.iter() {
        let desc = op.describe()
        ops_found.push("[rev" + e.revision.to_string() + "] " + desc)
      }
    }
  }
  if !found {
    return Err("invalid_range")
  }
  let j = jstr18(ops_found)
  let count = ops_found.length().to_string()
  let fr = from_rev.to_string()
  let tr = to_rev.to_string()
  Ok(
    "{\"from\":" +
    fr +
    ",\"to\":" +
    tr +
    ",\"total_ops\":" +
    count +
    ",\"replay\":[" +
    j +
    "]}",
  )
}

///|
pub fn DesignHistory::branch(
  self : DesignHistory,
  from_rev : Int,
  branch_name : String,
) -> Result[Document, String] {
  let doc = match self.checkout(from_rev) {
    Ok(d) => d
    Err(e) => return Err(e)
  }
  self.branch_name = branch_name
  Ok(doc)
}

///|
pub fn DesignHistory::diff(
  self : DesignHistory,
  from_rev : Int,
  to_rev : Int,
) -> Result[String, String] {
  match (self.checkout(from_rev), self.checkout(to_rev)) {
    (Ok(from_doc), Ok(to_doc)) => {
      let d = diff_docs(from_doc, to_doc)
      Ok(d.to_json())
    }
    _ => Err("revision_not_found")
  }
}

///|
fn jstr18(parts : Array[String]) -> String {
  let sb = StringBuilder::new()
  for i in 0..<parts.length() {
    if i > 0 {
      sb.write_string(",")
    }
    sb.write_string("\"" + parts[i] + "\"")
  }
  sb.to_string()
}

///|
/// 把 Document 写回指定画板（history 时间旅行的落地原语）。
/// 边界层（CLI/MCP）持有 DesignHistory，checkout/undo/redo 的结果经此
/// 落回 Project——「源码是唯一事实源」不变：写回后仍走 canonical 序列化。
pub fn Project::set_artboard_doc(
  self : Project,
  artboard~ : String,
  doc : Document,
) -> Result[Unit, String] {
  match self.artboards.get(artboard) {
    None => Err("unknown_artboard: \{artboard}")
    Some(ab) => {
      ab.doc = doc
      Ok(())
    }
  }
}
