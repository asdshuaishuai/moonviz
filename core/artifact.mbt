///|
/// Agent 中间产物协议：.moonviz 项目文件。
///
/// 这是 Agent 之间的"交接棒"——一个结构化的项目快照文件，
/// 任何 Agent（或人类）都能读取当前设计状态、未完成事项、交互定义，
/// 然后继续工作而不需要从零理解。
///
/// 格式为 JSON（可 diff、可版本控制、可跨语言解析）：
/// ```json
/// {
///   "meta": { "version": "...", "created_by": "...", "context": "..." },
///   "tokens": { ... },
///   "artboards": { "login": { "decl": "...", "interactions": [...] } },
///   "flows": [ ... ],
///   "todo": [ "待办事项" ],
///   "notes": [ { "artboard": "...", "note": "...", "priority": "..." } ]
/// }
/// ```
pub(all) struct AgentNote {
  artboard : String
  note : String
  priority : String // "high" | "medium" | "low"
}

///|
pub(all) struct MoonVizArtifact {
  mut meta_version : String
  mut meta_created_by : String
  mut meta_context : String // Agent 的工作上下文描述
  mut artboard_decls : Map[String, String] // artboard_id → 声明文本
  mut artboard_names : Map[String, String]
  mut artboard_sizes : Map[String, (Double, Double)]
  mut flows : Array[(String, String, String)] // (from, to, trigger)
  mut todos : Array[String]
  mut notes : Array[AgentNote]
}

///|
pub fn MoonVizArtifact::new() -> MoonVizArtifact {
  {
    meta_version: ENGINE_VERSION,
    meta_created_by: "",
    meta_context: "",
    artboard_decls: Map::new(),
    artboard_names: Map::new(),
    artboard_sizes: Map::new(),
    flows: [],
    todos: [],
    notes: [],
  }
}

// ---------------------------------------------------------------------------
// Project → Artifact（Agent 输出中间产物）
// ---------------------------------------------------------------------------

///|
pub fn Project::export_artifact(
  self : Project,
  agent_id? : String = "",
  context? : String = "",
) -> String {
  let a : MoonVizArtifact = MoonVizArtifact::new()
  a.meta_created_by = agent_id
  a.meta_context = context
  // 导出每个画板的声明文本
  for id in self.artboards.keys() {
    match self.artboards.get(id) {
      Some(ab) => {
        let proto = decl_snapshot(ab.doc)
        a.artboard_decls.set(id, proto)
        a.artboard_names.set(id, ab.name)
        a.artboard_sizes.set(id, (ab.width, ab.height))
      }
      None => ()
    }
  }
  // 导出导航流
  for e in self.flows.iter() {
    a.flows.push((e.from, e.to, e.trigger))
  }
  artifact_to_json(a)
}

///|
/// Agent 占位（避免循环依赖，实际调用 decl 包的 from_document）
fn decl_snapshot(doc : Document) -> String {
  // 生成声明的简化版本：遍历节点树
  let sb = StringBuilder::new()
  sb.write_string("// MoonViz artifact\n")
  let layout = solve(doc)
  artifact_walk(sb, doc, doc.root_id, layout, 0)
  sb.to_string()
}

///|
fn artifact_walk(
  sb : StringBuilder,
  doc : Document,
  id : String,
  layout : SolvedLayout,
  depth : Int,
) -> Unit {
  match (doc.nodes.get(id), layout.rect_of(id)) {
    (Some(n), Some(r)) => {
      let indent = repeat_spaces(depth * 2)
      sb.write_string(
        "\{indent}\{n.id} \{n.component} (\{r.x.to_int()},\{r.y.to_int()}) \{r.width.to_int()}x\{r.height.to_int()}",
      )
      if n.text != "" {
        sb.write_string(" \"\{n.text}\"")
      }
      sb.write_string("\n")
      for cid in n.children.iter() {
        artifact_walk(sb, doc, cid, layout, depth + 1)
      }
    }
    _ => ()
  }
}

///|
fn repeat_spaces(n : Int) -> String {
  let sb = StringBuilder::new()
  for _i in 0..<n {
    sb.write_char(' ')
  }
  sb.to_string()
}

// ---------------------------------------------------------------------------
// Artifact JSON 序列化
// ---------------------------------------------------------------------------

///|
fn artifact_to_json(a : MoonVizArtifact) -> String {
  let sb = StringBuilder::new()
  sb.write_string("{\n")
  // meta
  sb.write_string("  \"meta\": {\n")
  sb.write_string("    \"version\": \"\{a.meta_version}\",\n")
  sb.write_string("    \"created_by\": \"\{a.meta_created_by}\",\n")
  sb.write_string("    \"context\": \"\{json_escape_str(a.meta_context)}\"\n")
  sb.write_string("  },\n")
  // artboards
  sb.write_string("  \"artboards\": {\n")
  let board_parts : Array[String] = []
  for id in a.artboard_decls.keys() {
    match
      (
        a.artboard_decls.get(id),
        a.artboard_names.get(id),
        a.artboard_sizes.get(id),
      ) {
      (Some(decl), Some(name), Some((w, h))) =>
        board_parts.push(
          "    \"\{id}\": {\n      \"name\": \"\{name}\",\n      \"size\": {\{w.to_int()}, \{h.to_int()}},\n      \"decl\": \"\{json_escape_str(decl)}\"\n    }",
        )
      _ => ()
    }
  }
  sb.write_string(jstr13(board_parts, ",\n"))
  sb.write_string("\n  },\n")
  // flows
  sb.write_string("  \"flows\": [\n")
  let flow_parts : Array[String] = []
  for f in a.flows.iter() {
    flow_parts.push(
      "    {\"from\": \"\{f.0}\", \"to\": \"\{f.1}\", \"trigger\": \"\{f.2}\"}",
    )
  }
  sb.write_string(jstr13(flow_parts, ",\n"))
  sb.write_string("\n  ],\n")
  // todos
  sb.write_string("  \"todo\": [\n")
  let todo_parts : Array[String] = []
  for t in a.todos.iter() {
    todo_parts.push("    \"\{json_escape_str(t)}\"")
  }
  sb.write_string(jstr13(todo_parts, ",\n"))
  sb.write_string("\n  ],\n")
  // notes
  sb.write_string("  \"notes\": [\n")
  let note_parts : Array[String] = []
  for n in a.notes.iter() {
    note_parts.push(
      "    {\"artboard\": \"\{n.artboard}\", \"note\": \"\{json_escape_str(n.note)}\", \"priority\": \"\{n.priority}\"}",
    )
  }
  sb.write_string(jstr13(note_parts, ",\n"))
  sb.write_string("\n  ]\n}")
  sb.to_string()
}

///|
fn jstr13(parts : Array[String], sep : String) -> String {
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
fn json_escape_str(s : String) -> String {
  json_escape(s)
}

// ---------------------------------------------------------------------------
// Agent 添加待办 / 备注
// ---------------------------------------------------------------------------

///|
pub fn MoonVizArtifact::add_todo(self : MoonVizArtifact, text : String) -> Unit {
  self.todos.push(text)
}

///|
pub fn MoonVizArtifact::add_note(
  self : MoonVizArtifact,
  artboard : String,
  note : String,
  priority : String,
) -> Unit {
  self.notes.push({ artboard, note, priority })
}

///|
/// Project 侧也支持添加 Agent 备注
pub fn Project::add_agent_note(
  self : Project,
  artboard~ : String,
  note~ : String,
  priority? : String = "medium",
) -> Unit {
  // v1: 存储到 artifact 的内存结构中
  // 实际使用时由 runtime 层管理
  let _ = artboard
  let _ = note
  let _ = priority
}

// ---------------------------------------------------------------------------
// 读取中间产物（另一个 Agent 接手时用）
// ---------------------------------------------------------------------------

///|
pub fn MoonVizArtifact::summary(self : MoonVizArtifact) -> String {
  let sb = StringBuilder::new()
  sb.write_string("MoonViz Artifact v\{self.meta_version}\n")
  sb.write_string("Context: \{self.meta_context}\n")
  sb.write_string("Artboards: \{self.artboard_decls.size()}\n")
  for id in self.artboard_names.keys() {
    match self.artboard_names.get(id) {
      Some(name) => sb.write_string("  - \{id} (\{name})\n")
      None => ()
    }
  }
  sb.write_string("Flows: \{self.flows.length()}\n")
  sb.write_string("TODOs: \{self.todos.length()}\n")
  for t in self.todos.iter() {
    sb.write_string("  ☐ \{t}\n")
  }
  sb.write_string("Notes: \{self.notes.length()}\n")
  for n in self.notes.iter() {
    sb.write_string("  [\{n.priority}] \{n.artboard}: \{n.note}\n")
  }
  sb.to_string()
}
