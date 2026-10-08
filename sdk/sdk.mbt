/// MoonViz SDK 门面：MoonBit 宿主一站式接入原型设计引擎。
///
/// 用法（宿主工程执行 `moon add asdshuaishuai/moonviz` 后）：
///
/// ```moonbit
/// let p = @sdk.new()
/// let _ = @sdk.apply(p, "template login t_login 390 844")
/// let svg = @sdk.render_svg(p, artboard="t_login")
/// let mbt = @sdk.canonical(p)   // canonical .mbt.md 唯一事实源
/// ```
///
/// 设计约束：门面只做转发与组装，不改写引擎语义——所有变更仍走
/// `apply`（29 条 mutating op，HumanGate/AgentGate 语义由调用方选路），
/// 与 CLI/MCP/WASM 三面同源。

///|
/// 创建空项目（等价 CLI `create` 之前的初始态）。
pub fn new() -> @core.Project {
  @core.Project::new()
}

///|
/// 应用一条 mutating op（与 CLI/MCP/WASM 四面同源分发，29 条）。
/// 典型：`create` / `template` / `place` / `update` / `flow` / `unflow` /
/// `reorder` / `theme` / `token` / `fix`。
pub fn apply(
  p : @core.Project,
  op : String,
) -> Result[Unit, String] {
  @core.apply_operation(p, op)
}

///|
/// HumanGate 校验：返回结构违规/视觉债清单（不崩谓词 P0–P4）。
pub fn validate(
  p : @core.Project,
  artboard~ : String,
) -> Result[Array[@core.Violation], String] {
  match p.artboards.get(artboard) {
    None => Err("unknown_artboard: \{artboard}")
    Some(ab) => Ok(@core.validate(ab.doc))
  }
}

///|
/// 渲染单画板 SVG（引擎原始输出，非效果图）。
pub fn render_svg(
  p : @core.Project,
  artboard~ : String,
) -> Result[String, String] {
  p.export_svg(artboard~)
}

///|
/// 全项目 canonical `.mbt.md` 文本（唯一事实源的序列化形态）。
/// 变更后取回保存，即完成「源码是唯一事实源」的宿主闭环。
pub fn canonical(p : @core.Project) -> Result[String, String] {
  match @decl.project_to_mbt(p) {
    Ok(m) => Ok(m.to_mbt())
    Err(e) => Err(e)
  }
}

///|
/// 应用模板实例化新画板（14 个内置整页模板）。
pub fn apply_template(
  p : @core.Project,
  template_id~ : String,
  name~ : String,
) -> Result[String, String] {
  p.apply_template(template_id~, name~)
}

///|
/// 组件目录（65 组件 × 115 变体）。
pub fn list_components(p : @core.Project) -> String {
  @core.list_components_json(p.components)
}

///|
/// 自动修复可修复违规（contained_in_parent / no_sibling_overlap）。
pub fn auto_fix(p : @core.Project, artboard~ : String) -> Result[String, String] {
  p.auto_fix(artboard~)
}
