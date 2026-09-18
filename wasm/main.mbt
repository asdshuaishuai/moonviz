///|
/// MoonViz WASM 边界：把引擎渲染/校验管线暴露给浏览器与 Node 宿主。
///
/// 所有入口均为 String → String 的 JSON 约定：
///   render_mbt(mbt)        → 引擎 RenderResult JSON（画板 SVG + 交互流）
///   validate_mbt(mbt)      → 校验（不渲染）
///   apply_agent_op(mbt,op) → 应用一条 Agent 操作语法并提交（AgentGate），
///   apply_human_op(mbt,op) → 同一语法经 HumanGate（视觉债放行）——画布
///                            拖拽/属性编辑等人类行为走这里
///                            返回 canonical MBT + 渲染结果——与 CLI/Studio
///                            同一操作语法，playground 由此获得实时编辑能力
///   list_templates()       → 模板清单
///   version_info()         → 引擎版本 JSON

///|
pub fn render_mbt(mbt : String) -> String {
  match @decl.load_mbt_project(mbt) {
    Err(error) => "{\"ok\":false,\"error\":\"\{@core.json_escape(error)}\"}"
    Ok(model) => model.render_json()
  }
}

///|
pub fn validate_mbt(mbt : String) -> String {
  match @decl.load_mbt_project(mbt) {
    Err(error) => "{\"ok\":false,\"error\":\"\{@core.json_escape(error)}\"}"
    Ok(model) => {
      let entry = @core.json_escape(model.entry)
      let block_kinds = model.document.block_kind_counts()
      "{\"ok\":true,\"entry\":\"\{entry}\",\"revision\":\{model.project.revision},\"blockKinds\":\{block_kinds}}"
    }
  }
}

///|
pub fn version_info() -> String {
  "{\"ok\":true,\"engine\":\"moonviz\",\"version\":\"0.1.0\"}"
}

///|
/// 应用一条 Agent 操作语法（与 CLI 的 apply-agent-mbt-op-b64 同一分发器），
/// 经 AgentGate 提交后返回 canonical MBT + 全量渲染结果。
pub fn apply_agent_op(mbt : String, op : String) -> String {
  match @decl.load_mbt_project(mbt) {
    Err(error) => "{\"ok\":false,\"error\":\"\{@core.json_escape(error)}\"}"
    Ok(model) =>
      match @core.apply_operation(model.project, op) {
        Err(error) => "{\"ok\":false,\"error\":\"\{@core.json_escape(error)}\"}"
        Ok(_) =>
          match model.commit_and_render(@core.AgentGate) {
            Err(error) => "{\"ok\":false,\"error\":\"\{@core.json_escape(error)}\"}"
            Ok(rendered) => rendered
          }
      }
  }
}

///|
/// 导出可交互 HTML 原型（单文件自包含）：节点级 flow/⚡ 词汇表绑定、
/// 组件状态 CSS 变体、导航栈与 toast，全部由 .mbt.md 数据驱动。
pub fn export_html(mbt : String) -> String {
  match @decl.load_mbt_project(mbt) {
    Err(error) => "{\"ok\":false,\"error\":\{@core.json_escape(error)}}"
    Ok(model) => {
      let html = model.project.export_html()
      "{\"ok\":true,\"html\":\"\{@core.json_escape(html)}\"}"
    }
  }
}

///|
/// 预设组件库清单（playground 组件面板）：52 组件 × 93 变体。
pub fn list_components() -> String {
  @core.list_components_json(@core.builtin_components())
}

///|
/// 预设主题清单：name/display_name/is_dark（前端主题切换器）。
pub fn list_themes() -> String {
  let parts : Array[String] = []
  for t in @core.builtin_themes().iter() {
    let dark = if t.is_dark { "true" } else { "false" }
    parts.push(
      "{\"name\":\"\{t.name}\",\"display_name\":\"\{t.display_name}\",\"is_dark\":\{dark}}",
    )
  }
  let joined = parts.join(",")
  "[\{joined}]"
}

///|
/// 默认设计令牌清单（颜色/间距/圆角/字号）。
pub fn list_tokens() -> String {
  @core.DesignTokens::default().to_json()
}

///|
/// 机器可读 op 面字典：25 条 mutating op（usage/category/gates），
/// 与 CLI list-ops / MCP list_ops 同源（core/agent_api.mbt）。
pub fn list_ops() -> String {
  @core.list_ops_json()
}

///|
/// 模板清单（playground 模板选择器）。
pub fn list_templates() -> String {
  @core.list_templates_json()
}

///|
/// 人类路线：同一操作语法，经 HumanGate 提交（结构违规拒绝、视觉债放行）。
/// 画布直接操作（拖拽移动、属性面板编辑）属于人类行为，应与 Agent 硬门槛
/// 区分——轻微重叠/越界记为视觉债而非拒绝，对齐 Studio 画布的语义。
pub fn apply_human_op(mbt : String, op : String) -> String {
  match @decl.load_mbt_project(mbt) {
    Err(error) => "{\"ok\":false,\"error\":\"\{@core.json_escape(error)}\"}"
    Ok(model) =>
      match @core.apply_operation(model.project, op) {
        Err(error) => "{\"ok\":false,\"error\":\"\{@core.json_escape(error)}\"}"
        Ok(_) =>
          match model.commit_and_render(@core.HumanGate) {
            Err(error) => "{\"ok\":false,\"error\":\"\{@core.json_escape(error)}\"}"
            Ok(rendered) => rendered
          }
      }
  }
}
