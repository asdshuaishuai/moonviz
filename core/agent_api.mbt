///|
/// Agent 工具 API：LLM Agent 驱动原型设计的标准接口。
///
/// 本文件是**工具能力字典的单一事实源**：MCP 的 tools/list、CLI 的
/// `list-tools`、落地项目的 moonviz-tools.json 全部由 list_tools_json()
/// 生成。参数定义与 mcp/main.mbt 的 execute_tool 实际提取逻辑一一对应，
/// 修改 handler 时必须同步这里（反之亦然）。

// ---------------------------------------------------------------------------
// 工具注册
// ---------------------------------------------------------------------------

///|
/// 单个参数：名称 / JSON 类型 / 说明 / 是否必需
pub(all) struct ToolArg {
  name : String
  type_ : String
  desc : String
  required : Bool
}

///|
pub(all) struct AgentTool {
  name : String
  description : String
  args : Array[ToolArg]
}

///|
fn arg(name : String, type_ : String, desc : String, required~ : Bool) -> ToolArg {
  { name, type_, desc, required }
}

///|
fn s(name : String, desc : String) -> ToolArg {
  arg(name, "string", desc, required=true)
}

///|
fn so(name : String, desc : String) -> ToolArg {
  arg(name, "string", desc, required=false)
}

///|
fn n(name : String, desc : String) -> ToolArg {
  arg(name, "number", desc, required=true)
}

///|
/// 引擎内置工具清单：与 mcp/main.mbt execute_tool 的 46 个分支一一对应。
pub fn list_tools() -> Array[AgentTool] {
  let tools : Array[AgentTool] = []
  let add = fn(name : String, description : String, args : Array[ToolArg]) {
    tools.push({ name, description, args })
  }
  // ---- 组件库 ----
  add("list_templates", "List all available page templates (id/name/size). Pick one, then apply_template.", [])
  add("list_components", "List all UI components (builtin + user) with variants/categories/descriptions.", [])
  add("component_compile", "Compile & register a user component from a .mbt.md declaration.", [s("source_b64", "base64(utf8) user component declaration")])
  add("component_describe", "Describe a user component: params/variants/usage string.", [s("component_id", "user component id")])
  add("component_export", "Export a user component declaration (base64 .mbt.md).", [s("component_id", "user component id")])
  add("component_import", "Import user components from MCF bundle.", [s("mcf_b64", "base64 MCF bundle")])
  add("component_delete", "Delete a user component.", [s("component_id", "user component id")])
  add("library_snapshot", "Snapshot the whole user component library (for persistence).", [])
  add("library_restore", "Restore user components at session start.", [s("source_b64s", "space-separated base64 declarations")])
  // ---- 项目 / 令牌 / 主题 ----
  add("list_tokens", "List design tokens (colors/spacings/radii/typography). Reference these for visual consistency.", [])
  add("list_themes", "List builtin theme names (light/dark/high_contrast/sepia/nord/sunset).", [])
  add("list_artboards", "List all artboards in the project with metadata and node counts.", [])
  add("apply_theme", "Switch global theme: rewrites matching node colors via role recolor (reversible). Frontmatter `theme:` persists it.", [s("theme", "theme name from list_themes")])
  add("set_token", "Override a single design token; recolors old-value literals immediately and persists via frontmatter `tokens:`. Setting the default value back reverts it.", [s("token", "token role, e.g. primary"), s("value", "hex color value, e.g. #FF7A45")])
  // ---- 画板 / 模板 ----
  add("apply_template", "Instantiate a template as a new artboard (id = template_id unless overridden).", [s("template_id", "template id from list_templates"), so("artboard", "artboard id for the new board (default: template_id)"), so("name", "alias of artboard")])
  add("export_artifact", "Export an MBT-derived artifact bundle for this agent session.", [])
  // ---- 节点查询 / 编辑 ----
  add("query_nodes", "Query nodes of an artboard (id/kind/component/rect/style/text).", [s("artboard", "artboard id")])
  add("place_component", "Place a component instance on an artboard.", [s("artboard", "artboard id"), s("component_id", "component id from list_components"), s("instance_id", "unique node id for the instance"), so("variant", "variant name (or '-' for default)"), n("x", "x position"), n("y", "y position"), so("args", "space-separated k=v slots for user component params")])
  add("update_node", "Edit node properties via space-separated k=v pairs.", [s("artboard", "artboard id"), s("node_id", "node id"), s("args", "k=v keys: w h text fill text_color stroke stroke_width radius opacity font_size weight shadow rotate blur blend line_height tracking flip text_align font_style stroke_dash visible constraint. Image src goes in text=<url>")])
  add("move_node", "Move a node to absolute x/y.", [s("artboard", "artboard id"), s("node_id", "node id"), n("x", "new x"), n("y", "new y")])
  add("group_nodes", "Group >=2 nodes into a frame/group.", [s("artboard", "artboard id"), s("new_id", "group id"), s("nodes", "comma-separated node ids")])
  add("ungroup_node", "Ungroup a group; children return to parent.", [s("artboard", "artboard id"), s("node_id", "group id to dissolve")])
  add("align_nodes", "Align >=2 nodes. modes: left right top bottom hcenter vcenter.", [s("artboard", "artboard id"), s("mode", "alignment mode"), s("nodes", "comma-separated node ids")])
  add("resize_canvas", "Resize an artboard canvas.", [s("artboard", "artboard id"), n("width", "new width"), n("height", "new height")])
  add("restyle_component", "Restyle a user component definition (affects instances).", [s("artboard", "artboard id"), s("component_id", "component id"), s("args", "space-separated k=v pairs")])
  // ---- 质量 / 智能建议 ----
  add("lint_design", "Design quality lint: contrast/touch-target/spacing/readability. Returns structured suggestions.", [s("artboard", "artboard id")])
  add("critique", "AI-flavored design critique for an artboard.", [s("artboard", "artboard id")])
  add("benchmark", "Run the engine benchmark suite (render/validate timings).", [])
  add("auto_fix", "Auto-fix fixable violations on an artboard.", [s("artboard", "artboard id")])
  add("generate_spec", "Generate a structured design spec from an artboard.", [s("artboard", "artboard id")])
  add("infer_page_type", "Infer the page type (login/list/detail/dashboard...).", [s("artboard", "artboard id")])
  add("infer_missing", "Infer and suggest missing elements for an artboard.", [s("artboard", "artboard id")])
  add("suggest_alignment", "Suggest alignment fixes for an artboard.", [s("artboard", "artboard id")])
  add("extract_design_system", "Extract the implicit design system (palette/typography/spacing) from an artboard.", [s("artboard", "artboard id")])
  add("generate_responsive", "Generate responsive variants (_tablet/_desktop) for an artboard.", [s("artboard", "artboard id")])
  // ---- 交互 / 状态 ----
  add("interact", "Attach an interaction to a node (writes ⚡trigger→action marker).", [s("artboard", "artboard id"), s("node_id", "node id"), s("trigger", "tap|long_press|swipe_left|swipe_right|swipe_up|swipe_down|scroll_end|keyboard_enter|focus|blur"), s("action_spec", "back|haptic|navigate_to:<board>|show_toast:\"msg\"|play_sound:<name>|toggle_state:<node>|set_state:<node>:<state>|set_text:<node>:\"txt\"")])
  add("uninteract", "Detach all interactions from a node.", [s("artboard", "artboard id"), s("node_id", "node id")])
  add("interactions", "List interactions of an artboard (node/trigger/action).", [s("artboard", "artboard id")])
  add("define_state", "Define a component state variant (patch applied at render).", [s("artboard", "artboard id"), s("node_id", "node id"), s("state_name", "state name, e.g. pressed/disabled"), so("args", "k=v keys: fill text_color stroke text radius font_size")])
  add("set_state", "Set the current state of a node ([cur:<name>] marker persists it).", [s("node_id", "node id"), s("state_name", "state name from define_state"), so("toggle", "\"true\" to toggle between default and the state")])
  add("list_states", "List component states defined on an artboard.", [s("artboard", "artboard id")])
  // ---- 源码 / 导出 ----
  add("read_mbt", "Return canonical .mbt.md source from a base64 document.", [s("source_b64", "base64(utf8) .mbt.md source")])
  add("render_mbt", "Validate + render canonical .mbt.md (full artboards JSON).", [s("source_b64", "base64(utf8) .mbt.md source")])
  add("export_html", "Export the whole project as a self-contained interactive HTML prototype (node-level flows, state CSS, nav stack, toast).", [])
  add("export_svg", "Export one artboard as SVG (themed surface/outline).", [s("artboard", "artboard id")])
  add("ddp_view", "Report DDP codec status (read-only view).", [])
  add("list_ops", "Machine-readable CLI op surface: all 25 mutating ops with usage/category/gates/description (source of the moonviz-ops.json dictionary).", [])
  add("history", "Design version control on the current artboard: time-travel, branch-less commit log, semantic diff. command: init|commit|log|undo|redo|checkout|diff; args: artboard, message, rev, from, to", [arg("command", "string", "init|commit|log|undo|redo|checkout|diff", required=true), arg("artboard", "string", "artboard id (init/commit)", required=false), arg("message", "string", "commit message", required=false), arg("rev", "string", "target revision (checkout)", required=false), arg("from", "string", "diff from revision", required=false), arg("to", "string", "diff to revision", required=false)])
  add("protest", "Run a prototype test script against an artboard (assertion-based: navigation/inputs/render/violations). script: tap:x:y>board; back>board; swipe:left>board; set:node:value; noviol; render", [arg("artboard", "string", "artboard id", required=true), arg("script", "string", "semicolon-separated assertions", required=true)])
  add("animation_presets", "List the 6 builtin animation presets (press/fade_in/slide_in_right/modal_present/shake/pop).", [])
  add("animation_css", "Generate CSS @keyframes + animation for a node with a preset. args: node_id, preset", [arg("node_id", "string", "target node id", required=true), arg("preset", "string", "press|fade_in|slide_in_right|modal_present|shake|pop", required=true)])
  add("collab_merge", "Multi-agent three-way merge: submit N agents' op sequences, get conflicts + auto-resolution. spec: <base_rev> <agent>=<op>[+op...] ... (op grammar: insert/delete/move/fill/radius/font/text/pos/size/gap)", [arg("spec", "string", "<base_rev> <agent>=<op>[+op...] ...", required=true)])
  tools
}

///|
/// MCP tools/list 兼容的工具字典：
/// [{"name","description","inputSchema":{"type":"object","properties":{...},"required":[...]}}]
///
/// CLI `list-tools`、落地项目（Studio/playground）的 moonviz-tools.json
/// 均以本函数输出为准。
pub fn list_tools_json() -> String {
  let tools = list_tools()
  let parts : Array[String] = []
  for t in tools.iter() {
    let props : Array[String] = []
    let required : Array[String] = []
    for a in t.args.iter() {
      props.push(
        "\"\{a.name}\":{\"type\":\"\{a.type_}\",\"description\":\"\{json_escape(a.desc)}\"}",
      )
      if a.required {
        required.push("\"\{a.name}\"")
      }
    }
    let props_j = props.join(",")
    let required_j = required.join(",")
    parts.push(
      "{\"name\":\"\{t.name}\",\"description\":\"\{json_escape(t.description)}\",\"inputSchema\":{\"type\":\"object\",\"properties\":{\{props_j}},\"required\":[\{required_j}]}}",
    )
  }
  let joined = parts.join(",")
  "[\{joined}]"
}

// ---------------------------------------------------------------------------
// CLI op 面字典（list-ops）
// ---------------------------------------------------------------------------

///|
/// 单条 mutating op：名称 / 用法（与 ops.mbt 分发器的
/// `mbt_operation_usage:` 逐字一致）/ 分类 / 说明。
pub(all) struct OpEntry {
  op : String
  usage : String
  category : String
  description : String
}

///|
/// CLI op 面注册表：Agent 与 Human 双路线共享的全部 mutating 操作。
///
/// ⚠️ 与 core/ops.mbt 的 apply_operation 分发器一一对应——新增 op 时
/// 三处同步：分发器分支、本注册表、SKILL.md 语法块。drift-guard 测试
/// （ops_registry_wbtest.mbt）会对每条注册 op 实际打一遍分发器，usage
/// 不一致或漏注册都会红。
pub fn op_entries() -> Array[OpEntry] {
  let ops : Array[OpEntry] = []
  let add = fn(
    op : String,
    usage : String,
    category : String,
    description : String,
  ) {
    ops.push({ op, usage, category, description })
  }
  // ---- 结构 ----
  add(
    "create",
    "create <name> [width] [height]",
    "structural",
    "Create a blank artboard.",
  )
  add(
    "template",
    "template <template> <name> [width] [height]",
    "structural",
    "Instantiate a page template as a new artboard (id = template_id).",
  )
  add(
    "place",
    "place <artboard> <component> <id> [variant] [x] [y]",
    "structural",
    "Place a component instance (user-component params as trailing k=v).",
  )
  add(
    "duplicate",
    "duplicate <artboard> <new_name>",
    "structural",
    "Duplicate an artboard.",
  )
  add(
    "delete-artboard",
    "delete-artboard <artboard>",
    "structural",
    "Delete an artboard and its flows.",
  )
  add(
    "update",
    "update <artboard> <node> k=v",
    "structural",
    "Edit node properties via k=v pairs (w h text fill text_color stroke radius opacity font_size ...). Image src lives in text=<url>.",
  )
  add(
    "move",
    "move <artboard> <node> <x> <y>",
    "structural",
    "Move a node to absolute x/y.",
  )
  add(
    "copy",
    "copy <artboard> <node> <new_id> [dx] [dy]",
    "structural",
    "Copy a node to a new id with optional offset.",
  )
  add(
    "delete",
    "delete <artboard> <node>",
    "structural",
    "Delete a node.",
  )
  add(
    "reorder",
    "reorder <artboard> <node> front|back|up|down",
    "structural",
    "Change z-order of a node.",
  )
  add(
    "flip",
    "flip <artboard> <node> h|v|both|none",
    "structural",
    "Flip a node horizontally/vertically.",
  )
  add(
    "group",
    "group <artboard> <group_id> <n1> <n2> [n3 ...]",
    "structural",
    "Group nodes into a frame/group.",
  )
  add(
    "ungroup",
    "ungroup <artboard> <group_id>",
    "structural",
    "Dissolve a group; children return to the parent.",
  )
  add(
    "align",
    "align <artboard> <mode> <n1> <n2> [n3 ...]",
    "structural",
    "Align >=2 nodes (left/right/top/bottom/hcenter/vcenter).",
  )
  add(
    "resize-canvas",
    "resize-canvas <artboard> <width> <height>",
    "structural",
    "Resize an artboard canvas.",
  )
  add(
    "responsive",
    "responsive <artboard>",
    "structural",
    "Generate responsive variants (_tablet/_desktop) of an artboard.",
  )
  add(
    "restyle",
    "restyle <artboard> <component_id> k=v [k=v ...]",
    "structural",
    "Restyle a component definition (affects its instances).",
  )
  // ---- 交互 ----
  add(
    "interact",
    "interact <artboard> <node> <trigger> <action_spec>",
    "interaction",
    "Attach an interaction (writes the ⚡trigger→action name marker).",
  )
  add(
    "uninteract",
    "uninteract <artboard> <node>",
    "interaction",
    "Detach all interactions from a node.",
  )
  // ---- 组件状态 ----
  add(
    "state",
    "state <artboard> <node> <state_name> k=v [k=v ...]",
    "state",
    "Define a state patch (fill/text_color/stroke/text/radius/font_size).",
  )
  add(
    "set-state",
    "set-state <node> <state_name> [toggle]",
    "state",
    "Set the current state; [cur:<name>] marker persists it in the document.",
  )
  // ---- 导航 / 主题 / 令牌 / 债 ----
  add(
    "flow",
    "flow <from> <to> <node>",
    "navigation",
    "Add a tap navigation edge between artboards.",
  )
  add(
    "theme",
    "theme <name>",
    "theme",
    "Switch global theme: role-recolors matching literals (reversible) and persists via frontmatter `theme:`.",
  )
  add(
    "token",
    "token <name> <value>",
    "tokens",
    "Override a COLOR design token: recolors old-value literals, persists via frontmatter `tokens:`; setting the default value back reverts.",
  )
  add(
    "fix",
    "fix <artboard>",
    "debt",
    "Debt-repayment auto-fix: commits only when total violations strictly decrease; the remainder is accepted as visual debt (HumanGate fallback).",
  )
  ops
}

///|
/// CLI op 面字典（list-ops / list_ops 输出）：
/// [{"op","usage","category","description","gates":{"agent":true,"human":true}}]
///
/// 全部 25 条 op 在双路线共享（差别在提交门禁的校验强度：AgentGate 硬拦
/// 结构违规，HumanGate 放行视觉债）；fix 的还债特例写进 description。
pub fn list_ops_json() -> String {
  let gates = "{\"agent\":true,\"human\":true}"
  let parts : Array[String] = []
  for e in op_entries().iter() {
    parts.push(
      "{\"op\":\"\{e.op}\",\"usage\":\"\{json_escape(e.usage)}\",\"category\":\"\{e.category}\",\"description\":\"\{json_escape(e.description)}\",\"gates\":\{gates}}",
    )
  }
  let joined = parts.join(",")
  "[\{joined}]"
}
