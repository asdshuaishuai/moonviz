/// 组件自适应预设（1.0 M1.5）：
/// place 时按组件 id 自动落 constraint/尺寸策略——画板与父容器 resize 后
/// 组件按预设自适应（Figma Constraints 语义，重排基座在 resize_canvas）。
///
/// 预设值：
/// - "width-fill"  : 宽度 Fill（按钮/输入框/正文/分割线——横向跟随容器）
/// - "anchor:rb"   : 锚定右下（fab 等 Floating 元素）
/// - "anchor:lt"   : 锚定左上（默认行为，显式列出便于审计）
/// - ""            : 保持现状（Fixed 尺寸，不落约束）
///
/// 单一事实源：本函数是唯一的组件→预设映射，agent 可经
/// `adaptive <ab> <node> <preset>` op 显式覆盖（见 ops 注册表）。
pub fn adaptive_preset(component_id : String) -> String {
  match component_id {
    // 横向自适应：宽度跟随容器（内容盒）
    "button" | "text_input" | "body_text" | "heading" | "divider" | "image" => "width-fill"
    // 浮动元素：锚定右下（画板缩小也保持在可视区内）
    "fab" => "anchor:rb"
    _ => ""
  }
}

///|
/// place 后按预设落自适应约束/尺寸策略。
/// width-fill：宽度 Fill（solve 时动态求宽）；anchor:rb：constraint=rb。
pub fn apply_place_adaptive(
  doc : Document,
  component_id : String,
  instance_id : String,
  w : Double,
  h : Double,
) -> Unit {
  // 显式 w/h 永远优先于预设——place 带尺寸即「我要这个大小」
  if w > 0.0 || h > 0.0 {
    return
  }
  let preset = adaptive_preset(component_id)
  if preset == "width-fill" {
    let _ = doc.update_node(instance_id, fn(x) { { ..x, width: Fill } })
  } else if preset == "anchor:rb" {
    let _ = doc.update_node(instance_id, fn(x) { { ..x, constraint: "rb" } })
  }
}
