///|
/// MoonViz WASM 边界：把引擎渲染/校验管线暴露给浏览器与 Node 宿主。
///
/// 所有入口均为 String → String 的 JSON 约定：
///   render_mbt(mbt)   → 引擎 RenderResult JSON（画板 SVG + 交互流）
///   version_info()    → 引擎版本 JSON

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
