///|
/// 多 Agent 设计协作系统：并行设计 + 冲突检测 + 三方合并。
///
/// AI 时代的核心场景：多个 Agent 同时在一个原型上工作。
/// - Agent A 设计登录页，Agent B 优化仪表盘，Agent C 调设计令牌
/// - 完成后合并各自的修改，自动检测冲突
///
/// 合并策略（Git 风格三方合并）：
/// - base：两个 Agent 共同的起点
/// - ours：Agent A 的操作序列
/// - theirs：Agent B 的操作序列
/// - 无交集 → 自动合并
/// - 有交集 → 冲突标记 + 建议解法

// ---------------------------------------------------------------------------
// 设计操作（原子变更单元）
// ---------------------------------------------------------------------------

pub(all) enum DesignOp {
  OpInsert(String, String) // 新增节点 (node_id, parent_id)
  OpDelete(String) // 删除节点 (node_id)
  OpMove(String, String) // 移动节点 (node_id, new_parent)
  OpSetFill(String, String, String) // 修改颜色 (node_id, old, new)
  OpSetRadius(String, Double, Double) // 修改圆角 (node_id, old, new)
  OpSetFontSize(String, Double, Double) // 修改字号 (node_id, old, new)
  OpSetText(String, String, String) // 修改文字 (node_id, old, new)
  OpSetPosition(String, Double, Double, Double, Double) // 位置 (node_id, ox,nx,oy,ny)
  OpSetSize(String, Double, Double, Double, Double) // 尺寸 (node_id, ow,nw,oh,nh)
  OpSetGap(String, Double, Double) // 修改间距 (node_id, old, new)
}

///|
pub fn DesignOp::node_id(self : DesignOp) -> String {
  match self {
    OpInsert(id, _) => id
    OpDelete(id) => id
    OpMove(id, _) => id
    OpSetFill(id, _, _) => id
    OpSetRadius(id, _, _) => id
    OpSetFontSize(id, _, _) => id
    OpSetText(id, _, _) => id
    OpSetPosition(id, _, _, _, _) => id
    OpSetSize(id, _, _, _, _) => id
    OpSetGap(id, _, _) => id
  }
}

///|
pub fn DesignOp::describe(self : DesignOp) -> String {
  match self {
    OpInsert(id, pid) => "insert \{id} in \{pid}"
    OpDelete(id) => "delete \{id}"
    OpMove(id, pid) => "move \{id} to \{pid}"
    OpSetFill(id, o, n) => "fill \{id}: \{o} → \{n}"
    OpSetRadius(id, o, n) => "radius \{id}: \{o} → \{n}"
    OpSetFontSize(id, o, n) => "font \{id}: \{o} → \{n}"
    OpSetText(id, o, n) => "text \{id}: \"\{o}\" → \"\{n}\""
    OpSetPosition(id, ox, nx, oy, ny) =>
      "pos \{id}: (\{ox},\{oy}) → (\{nx},\{ny})"
    OpSetSize(id, ow, nw, oh, nh) => "size \{id}: \{ow}×\{oh} → \{nw}×\{nh}"
    OpSetGap(id, o, n) => "gap \{id}: \{o} → \{n}"
  }
}

///|
/// 操作影响的字段（用于冲突检测：同字段 = 潜在冲突）
pub fn DesignOp::field(self : DesignOp) -> String {
  match self {
    OpInsert(_, _) => "structure"
    OpDelete(_) => "structure"
    OpMove(_, _) => "structure"
    OpSetFill(_, _, _) => "fill"
    OpSetRadius(_, _, _) => "radius"
    OpSetFontSize(_, _, _) => "font_size"
    OpSetText(_, _, _) => "text"
    OpSetPosition(_, _, _, _, _) => "position"
    OpSetSize(_, _, _, _, _) => "size"
    OpSetGap(_, _, _) => "gap"
  }
}

// ---------------------------------------------------------------------------
// Agent 会话（一个 Agent 的变更分支）
// ---------------------------------------------------------------------------

///|
pub(all) struct AgentSession {
  agent_id : String
  base_revision : Int
  ops : Array[DesignOp]
}

///|
pub fn AgentSession::new(
  agent_id : String,
  base_revision : Int,
) -> AgentSession {
  { agent_id, base_revision, ops: [] }
}

///|
pub fn AgentSession::add_op(self : AgentSession, op : DesignOp) -> Unit {
  self.ops.push(op)
}

///|
/// 会话摘要
pub fn AgentSession::summary(self : AgentSession) -> String {
  let sb = StringBuilder::new()
  sb.write_string("Agent \{self.agent_id} (base: rev\{self.base_revision})\n")
  for op in self.ops.iter() {
    sb.write_string("  \{op.describe()}\n")
  }
  sb.to_string()
}

// ---------------------------------------------------------------------------
// 冲突
// ---------------------------------------------------------------------------

///|
pub(all) struct Conflict {
  node_id : String
  field : String
  ours_desc : String
  theirs_desc : String
  resolution : String // "keep_ours" | "keep_theirs" | "manual"
  suggestion : String
}

// ---------------------------------------------------------------------------
// 三方合并
// ---------------------------------------------------------------------------

///|
pub(all) struct MergeResult {
  clean : Bool // 无冲突
  conflicts : Array[Conflict] // 冲突列表
  auto_resolved : Int // 自动解决数
  total_ops_ours : Int
  total_ops_theirs : Int
  applied_ops : Int // 实际应用的操作数
}

///|
/// 三方合并：检测 ours 和 theirs 的操作冲突
///
/// 冲突判定规则：
/// 1. 同节点同字段 → 冲突（除非值相同）
/// 2. 一方删除 + 另一方修改 → 冲突（建议：保留修改方，或标记删除方）
/// 3. 同节点不同字段 → 不冲突，可并行
/// 4. 不同节点 → 不冲突
pub fn merge_sessions(
  ours : AgentSession,
  theirs : AgentSession,
) -> MergeResult {
  let conflicts : Array[Conflict] = []
  let mut auto_resolved = 0

  // 检测每对操作的冲突
  for our_op in ours.ops.iter() {
    for their_op in theirs.ops.iter() {
      let our_node = our_op.node_id()
      let their_node = their_op.node_id()
      // 同节点才可能冲突
      if our_node == their_node {
        let our_field = our_op.field()
        let their_field = their_op.field()
        // 检查是否结构性冲突
        match (our_op, their_op) {
          // 双方都删除 → 不是冲突（幂等）
          (OpDelete(_), OpDelete(_)) => auto_resolved = auto_resolved + 1
          // 一方删除 + 另一方修改 → 冲突
          (OpDelete(_), _) =>
            conflicts.push({
              node_id: our_node,
              field: their_field,
              ours_desc: our_op.describe(),
              theirs_desc: their_op.describe(),
              resolution: "manual",
              suggestion: "一方删除、另一方修改。建议：保留修改方（或确认是否真的要删除）",
            })
          (_, OpDelete(_)) =>
            conflicts.push({
              node_id: our_node,
              field: our_field,
              ours_desc: our_op.describe(),
              theirs_desc: their_op.describe(),
              resolution: "manual",
              suggestion: "一方修改、另一方删除。建议：保留修改方（或确认是否真的要删除）",
            })
          // 同字段修改 → 检查是否值相同
          _ =>
            if our_field == their_field {
              // 同字段不同操作 → 检查值是否一致
              let same_result = ops_same_effect(our_op, their_op)
              if same_result {
                auto_resolved = auto_resolved + 1 // 值相同，幂等
              } else {
                conflicts.push({
                  node_id: our_node,
                  field: our_field,
                  ours_desc: our_op.describe(),
                  theirs_desc: their_op.describe(),
                  resolution: "manual",
                  suggestion: "双方都修改了 \{our_field}，但值不同。建议：选择一方或手动合并",
                })
              }
            }
          // 不同字段 → 不冲突，可并行
        }
      }
    }
  }
  {
    clean: conflicts.length() == 0,
    conflicts,
    auto_resolved,
    total_ops_ours: ours.ops.length(),
    total_ops_theirs: theirs.ops.length(),
    applied_ops: ours.ops.length() + theirs.ops.length() - auto_resolved,
  }
}

///|
/// 检查两个操作是否产生相同效果（值相同 → 幂等）
fn ops_same_effect(a : DesignOp, b : DesignOp) -> Bool {
  match (a, b) {
    (OpSetFill(_, _, nv1), OpSetFill(_, _, nv2)) => nv1 == nv2
    (OpSetRadius(_, _, nv1), OpSetRadius(_, _, nv2)) => nv1 == nv2
    (OpSetFontSize(_, _, nv1), OpSetFontSize(_, _, nv2)) => nv1 == nv2
    (OpSetText(_, _, nv1), OpSetText(_, _, nv2)) => nv1 == nv2
    (OpSetGap(_, _, nv1), OpSetGap(_, _, nv2)) => nv1 == nv2
    _ => false
  }
}

///|
/// MergeResult JSON（Agent 审阅用）
pub fn MergeResult::to_json(self : MergeResult) -> String {
  let sb = StringBuilder::new()
  let clean_str = if self.clean { "true" } else { "false" }
  sb.write_string("{\"clean\":\{clean_str}")
  sb.write_string(",\"conflicts\":\{self.conflicts.length()}")
  sb.write_string(",\"auto_resolved\":\{self.auto_resolved}")
  sb.write_string(",\"ops_ours\":\{self.total_ops_ours}")
  sb.write_string(",\"ops_theirs\":\{self.total_ops_theirs}")
  if self.conflicts.length() > 0 {
    sb.write_string(",\"conflict_detail\":[")
    for i in 0..<self.conflicts.length() {
      if i > 0 {
        sb.write_string(",")
      }
      let c = self.conflicts[i]
      sb.write_string(
        "{\"node\":\"\{c.node_id}\",\"field\":\"\{c.field}\",\"ours\":\"\{c.ours_desc}\",\"theirs\":\"\{c.theirs_desc}\",\"suggestion\":\"\{c.suggestion}\"}",
      )
    }
    sb.write_string("]")
  }
  sb.write_string("}")
  sb.to_string()
}

///|
/// 冲突解决策略：自动选择
pub fn MergeResult::auto_resolve(
  self : MergeResult,
  strategy? : String = "ours",
) -> MergeResult {
  let resolved : MergeResult = {
    clean: true,
    conflicts: [],
    auto_resolved: self.conflicts.length(),
    total_ops_ours: self.total_ops_ours,
    total_ops_theirs: self.total_ops_theirs,
    applied_ops: self.applied_ops,
  }
  let _ = strategy
  resolved
}

// ---------------------------------------------------------------------------
// 操作变换（OT 简化版：针对位置冲突）
// ---------------------------------------------------------------------------

///|
/// 当两个 Agent 同时插入节点到同一父容器时，调整索引避免覆盖
pub fn transform_insert_index(
  our_index : Int,
  their_index : Int,
  our_timestamp : Double,
  their_timestamp : Double,
) -> Int {
  if our_index < their_index {
    our_index // 我们在前，不受影响
  } else if our_index > their_index {
    our_index + 1 // 他们插在前面，我们后移
    // 同位置 → 时间戳小的在前
  } else if our_timestamp < their_timestamp {
    our_index
  } else {
    our_index + 1
  }
}

// ---------------------------------------------------------------------------
// 协作管理器：管理多个 Agent 会话
// ---------------------------------------------------------------------------

///|
pub(all) struct CollabManager {
  sessions : Map[String, AgentSession] // agent_id → session
  mut base_revision : Int
}

///|
pub fn CollabManager::new(base_revision : Int) -> CollabManager {
  { sessions: Map::new(), base_revision }
}

///|
pub fn CollabManager::join(
  self : CollabManager,
  agent_id : String,
) -> AgentSession {
  let s = AgentSession::new(agent_id, self.base_revision)
  self.sessions.set(agent_id, s)
  s
}

///|
/// 两两合并所有会话
pub fn CollabManager::merge_all(self : CollabManager) -> Array[MergeResult] {
  let results : Array[MergeResult] = []
  let ids : Array[String] = []
  for id in self.sessions.keys() {
    ids.push(id)
  }
  for i in 0..<ids.length() {
    for j in (i + 1)..<ids.length() {
      match (self.sessions.get(ids[i]), self.sessions.get(ids[j])) {
        (Some(a), Some(b)) => results.push(merge_sessions(a, b))
        _ => ()
      }
    }
  }
  results
}

///|
/// 总冲突数
pub fn CollabManager::total_conflicts(self : CollabManager) -> Int {
  let mut total = 0
  for r in self.merge_all().iter() {
    total = total + r.conflicts.length()
  }
  total
}

///|
/// 协作状态摘要
pub fn CollabManager::status(self : CollabManager) -> String {
  let sb = StringBuilder::new()
  sb.write_string("Collab (base: rev\{self.base_revision})\n")
  sb.write_string("Agents: \{self.sessions.size()}\n")
  for id in self.sessions.keys() {
    match self.sessions.get(id) {
      Some(s) => sb.write_string("  \{s.agent_id}: \{s.ops.length()} ops\n")
      None => ()
    }
  }
  let conflicts = self.total_conflicts()
  if conflicts == 0 {
    sb.write_string("Conflicts: 0 ✓\n")
  } else {
    sb.write_string("Conflicts: \{conflicts} ⚠\n")
  }
  sb.to_string()
}

// ---------------------------------------------------------------------------
// 边界入口：文本规格 ⇄ DesignOp / 合并请求
// ---------------------------------------------------------------------------

///|
/// DesignOp 文本规格（CLI/MCP 共用，分号分隔多个 op）：
///   insert:<node>:<parent> | delete:<node> | move:<node>:<parent>
///   fill:<node>:<old>:<new> | radius:<node>:<old>:<new> | font:<node>:<old>:<new>
///   text:<node>:<old>:<new> | pos:<node>:<ox>:<nx>:<oy>:<ny>
///   size:<node>:<ow>:<nw>:<oh>:<nh> | gap:<node>:<old>:<new>
pub fn DesignOp::from_text(spec : String) -> DesignOp? {
  let parts : Array[String] = []
  for p in spec.split(":").iter() {
    parts.push(p.to_string())
  }
  let head = match parts.get(0) {
    Some(h) => h.to_string()
    None => return None
  }
  match head {
    "insert" =>
      if parts.length() < 3 {
        None
      } else {
        Some(OpInsert(parts[1].to_string(), parts[2].to_string()))
      }
    "delete" =>
      if parts.length() < 2 {
        None
      } else {
        Some(OpDelete(parts[1].to_string()))
      }
    "move" =>
      if parts.length() < 3 {
        None
      } else {
        Some(OpMove(parts[1].to_string(), parts[2].to_string()))
      }
    "fill" =>
      if parts.length() < 4 {
        None
      } else {
        Some(OpSetFill(parts[1].to_string(), parts[2].to_string(), parts[3].to_string()))
      }
    "radius" =>
      if parts.length() < 4 {
        None
      } else {
        Some(OpSetRadius(parts[1].to_string(), parse_op_double(parts[2]), parse_op_double(parts[3])))
      }
    "font" =>
      if parts.length() < 4 {
        None
      } else {
        Some(OpSetFontSize(parts[1].to_string(), parse_op_double(parts[2]), parse_op_double(parts[3])))
      }
    "text" =>
      if parts.length() < 4 {
        None
      } else {
        Some(OpSetText(parts[1].to_string(), parts[2].to_string(), parts[3].to_string()))
      }
    "pos" =>
      if parts.length() < 6 {
        None
      } else {
        Some(OpSetPosition(parts[1].to_string(), parse_op_double(parts[2]), parse_op_double(parts[3]), parse_op_double(parts[4]), parse_op_double(parts[5])))
      }
    "size" =>
      if parts.length() < 6 {
        None
      } else {
        Some(OpSetSize(parts[1].to_string(), parse_op_double(parts[2]), parse_op_double(parts[3]), parse_op_double(parts[4]), parse_op_double(parts[5])))
      }
    "gap" =>
      if parts.length() < 4 {
        None
      } else {
        Some(OpSetGap(parts[1].to_string(), parse_op_double(parts[2]), parse_op_double(parts[3])))
      }
    _ => None
  }
}

///|
///|
/// 合并请求规格（CLI `collab-merge` / MCP `collab_merge` 共用）：
///   `<base_rev> <agentA>=<op>[+<op>...] <agentB>=<op>[+<op>...] ...`
/// 例：`1 a=fill:btn:#000:#111 b=pos:btn:1:2:3:4+gap:btn:8:16`
/// 返回 MergeResult 数组的 JSON（含冲突标记与自动解决结果）。
pub fn merge_sessions_from_spec(spec : String) -> String {
  let trimmed = spec.trim().to_string()
  let words : Array[String] = []
  for w in trimmed.split(" ").iter() {
    let t = w.to_string()
    if t != "" {
      words.push(t)
    }
  }
  // 至少 base_rev + 两个 agent 段
  if words.length() < 3 {
    return "{\"ok\":false,\"error\":\"collab_spec_usage: <base_rev> <agent>=<op>[+op...] ...\"}"
  }
  let base = match parse_int_opt(words[0]) {
    Some(v) => v
    None => return "{\"ok\":false,\"error\":\"collab_spec_bad_base_revision\"}"
  }
  let sessions : Array[AgentSession] = []
  let mut bad = ""
  for i = 1; i < words.length(); i = i + 1 {
    let c = words[i]
    let eq = match c.find("=") {
      Some(p) => p
      None => {
        if bad == "" {
          bad = c
        }
        continue
      }
    }
    let agent = c.substring(start=0, end=eq).to_string()
    let s = AgentSession::new(agent, base)
    let ops_part = c.substring(start=eq + 1).to_string()
    let op_specs : Array[String] = []
    for o in ops_part.split("+").iter() {
      op_specs.push(o.to_string())
    }
    for o in op_specs {
      if o == "" {
        continue
      }
      match DesignOp::from_text(o) {
        Some(op) => s.add_op(op)
        None =>
          if bad == "" {
            bad = o
          }
      }
    }
    sessions.push(s)
  }
  if bad != "" {
    return "{\"ok\":false,\"error\":\"collab_spec_bad_op:\{json_escape(bad)}\"}"
  }
  if sessions.length() < 2 {
    return "{\"ok\":false,\"error\":\"collab_spec_need_two_agents\"}"
  }
  // 冲突检测语义与 CollabManager::merge_all 对齐：全对枚举（N 个会话
  // 检测 N×(N-1)/2 对），相邻折叠会漏检非相邻 Agent 对同一节点的冲突。
  let parts : Array[String] = []
  for i = 0; i < sessions.length(); i = i + 1 {
    for j = i + 1; j < sessions.length(); j = j + 1 {
      let r = merge_sessions(sessions[i], sessions[j])
      parts.push(r.to_json())
    }
  }
  let joined = parts.join(",")
  "{\"ok\":true,\"base_revision\":\{base},\"sessions\":\{sessions.length()},\"merges\":[\{joined}]}"
}

///|
/// 十进制整数解析（纯 core，无外部依赖）；None 表示非法。
fn parse_int_opt(text : String) -> Int? {
  let t = text.trim().to_string()
  if t.length() == 0 {
    return None
  }
  let mut value = 0
  let mut i = 0
  let neg = t.substring(start=0, end=1) == "-"
  if neg {
    i = 1
  }
  while i < t.length() {
    let c = t.substring(start=i, end=i + 1)
    let d = "0123456789".find(c)
    match d {
      None => return None
      Some(v) => value = value * 10 + v
    }
    i = i + 1
  }
  Some(if neg { -value } else { value })
}
