///|
/// MoonViz WASM 边界：把引擎渲染/校验管线暴露给浏览器与 Node 宿主。
///
/// 所有入口均为 String → String 的 JSON 约定：
///   render_mbt(mbt)        → 引擎 RenderResult JSON（画板 SVG + 交互流）
///   validate_mbt(mbt)      → 校验（不渲染）
///   apply_agent_op(mbt,op) → 应用一条 Agent 操作语法并提交（AgentGate），
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
/// 模板清单（playground 模板选择器）。
pub fn list_templates() -> String {
  @core.list_templates_json()
}
