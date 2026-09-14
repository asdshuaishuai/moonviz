///|
/// Agent 工具 API：LLM Agent 驱动原型设计的标准接口。
///
/// 每个工具是一个纯函数：(Project, 参数) → (Project, 结构化结果)。
/// Agent 通过 `list_tools` 发现工具，通过 `call_tool` 执行。
/// 全部走文本协议（JSON in/out），引擎对 Agent 运行时零依赖。

// ---------------------------------------------------------------------------
// 工具注册
// ---------------------------------------------------------------------------

pub(all) struct AgentTool {
  name : String
  description : String
  params : String // JSON Schema 片段（简化版）
}

///|
/// 引擎内置的 Agent 工具清单
pub fn list_tools() -> Array[AgentTool] {
  let tools : Array[AgentTool] = []
  tools.push({
    name: "list_components",
    description: "列出所有可用的 UI 组件（含变体/描述/分类）。Agent 据此选择要放置的组件。",
    params: "{}",
  })
  tools.push({
    name: "list_tokens",
    description: "列出设计令牌（颜色/间距/圆角/字号）。Agent 据此引用一致的视觉值。",
    params: "{}",
  })
  tools.push({
    name: "create_artboard",
    description: "创建新画板。参数：name, width, height。",
    params: "{\"name\": \"string\", \"width\": \"int\", \"height\": \"int\"}",
  })
  tools.push({
    name: "list_artboards",
    description: "列出项目中的所有画板及其元数据。",
    params: "{}",
  })
  tools.push({
    name: "place_component",
    description: "在画板上放置组件实例。参数：artboard, component_id, instance_id, variant, parent_id(可选), x, y。",
    params: "{\"artboard\": \"string\", \"component_id\": \"string\", \"instance_id\": \"string\", \"variant\": \"string\", \"parent_id\": \"string?\", \"x\": \"double\", \"y\": \"double\"}",
  })
  tools.push({
    name: "query_nodes",
    description: "按条件查询画板中的节点。参数：artboard, kind(可选), component(可选), text_contains(可选)。",
    params: "{\"artboard\": \"string\", \"kind\": \"string?\", \"component\": \"string?\", \"text_contains\": \"string?\"}",
  })
  tools.push({
    name: "lint_design",
    description: "设计质量检查：对比度/触控目标/间距一致性/文字可读性。返回结构化建议。",
    params: "{\"artboard\": \"string\"}",
  })
  tools.push({
    name: "get_violations",
    description: "获取当前不崩谓词违规列表（含建议修复方案）。",
    params: "{\"artboard\": \"string\"}",
  })
  tools.push({
    name: "suggest_fix",
    description: "针对视觉债给出可执行的修复补丁。参数：artboard, node_id。",
    params: "{\"artboard\": \"string\", \"node_id\": \"string\"}",
  })
  tools.push({
    name: "export_svg",
    description: "导出画板为 SVG 字符串。",
    params: "{\"artboard\": \"string\"}",
  })
  tools.push({
    name: "get_flow",
    description: "获取画板间的导航流（页面跳转关系）。",
    params: "{}",
  })
  tools
}

///|
/// 工具清单的 JSON 序列化
pub fn list_tools_json() -> String {
  let tools = list_tools()
  let parts : Array[String] = []
  for t in tools.iter() {
    parts.push(
      "{\"name\":\"\{t.name}\",\"description\":\"\{t.description}\",\"params\":\"\{t.params}\"}",
    )
  }
  let joined = join_str3(parts)
  "[\{joined}]"
}

///|
fn join_str3(parts : Array[String]) -> String {
  let sb = StringBuilder::new()
  for i in 0..<parts.length() {
    if i > 0 {
      sb.write_string(",")
    }
    sb.write_string(parts[i])
  }
  sb.to_string()
}
