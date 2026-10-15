// ---------------------------------------------------------------------------
// RENDER-1.0 R4（前半）：主题 × 组件渲染快照基线（golden）。
//
// golden 基线的「唯一渲染管道」：生成脚本（scripts/gen-golden.mbt，CLI
// 同一 op 分发器驱动 create→theme→place→export-svg 落盘）与快照 diff
// 测试（core/golden_wbtest.mbt）共用本文件的同三个函数——基线与比对
// 逐字节同源，任何渲染输出变化都会让快照测试红。
//
// 快照以 SVG 源 diff（非 PNG）：SVG 是文本，diff 可审阅、可定位到具体
// 属性漂移；golden 落盘 test/golden/<theme>-<component>.svg。
// ---------------------------------------------------------------------------

///|
/// 快照覆盖的主题（R4 前半：light/dark；后续主题按需追加并重生成基线）
pub fn golden_themes() -> Array[String] {
  // 全部 6 主题（0.1.9-fix 主题化深化）：light/dark/high_contrast/sepia/nord/sunset
  let names : Array[String] = []
  for t in builtin_themes().iter() {
    names.push(t.name)
  }
  names
}

///|
/// 快照覆盖的组件清单：内置注册表全量（65），按码元字典序——文件名与
/// 遍历顺序稳定，组件增删后重生成基线即自动跟随。
pub fn golden_component_names() -> Array[String] {
  let keys : Array[String] = []
  for k in builtin_components().keys() {
    keys.push(k)
  }
  golden_sort_keys(keys)
  keys
}

///|
/// 码元字典序插入排序：直接复用同包 data_schema_sort_keys/key_lt
/// （同一规则同一实现——修评审发现的 35 行逐行重复）。
fn golden_sort_keys(keys : Array[String]) -> Unit {
  data_schema_sort_keys(keys)
}

///|
/// 单组件标准渲染：全新项目 → create 画板 → theme → place（默认变体、
/// 默认尺寸，锚定 20,20）→ export-svg。任一步失败整体 Err（不静默出
/// 空 SVG 混入基线）。
pub fn golden_render(theme : String, component : String) -> Result[String, String] {
  let p = Project::new()
  match apply_operation(p, "create golden") {
    Err(e) => Err("golden_create: \{e}")
    Ok(_) =>
      match apply_operation(p, "theme \{theme}") {
        Err(e) => Err("golden_theme: \{e}")
        Ok(_) =>
          match
            apply_operation(
              p,
              "place golden \{component} \{component} - 20 20",
            ) {
            Err(e) => Err("golden_place \{component}: \{e}")
            Ok(_) => p.export_svg(artboard="golden")
          }
      }
  }
}

///|
/// golden 快照文件名（<theme>-<component>.svg；组件 id 仅 [a-z0-9_]，
/// 文件名安全）。
pub fn golden_file_name(theme : String, component : String) -> String {
  "\{theme}-\{component}.svg"
}
