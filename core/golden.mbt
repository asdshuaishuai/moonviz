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
  ["light", "dark"]
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
/// 码元字典序插入排序（与 data_schema_sort_keys 同规则——绕开工具链
/// String::compare 长度序缺陷，保证清单与文件遍历逐字节确定）。
fn golden_sort_keys(keys : Array[String]) -> Unit {
  for i in 1..<keys.length() {
    let k = keys[i]
    let mut j = i - 1
    while j >= 0 && golden_key_lt(k, keys[j]) {
      keys[j + 1] = keys[j]
      j = j - 1
    }
    keys[j + 1] = k
  }
}

///|
fn golden_key_lt(a : String, b : String) -> Bool {
  let la = a.length()
  let lb = b.length()
  let n = if la < lb { la } else { lb }
  let mut i = 0
  while i < n {
    let ca = match a.get_char(i) {
      Some(c) => c.to_int()
      None => 0
    }
    let cb = match b.get_char(i) {
      Some(c) => c.to_int()
      None => 0
    }
    if ca != cb {
      return ca < cb
    }
    i = i + 1
  }
  la < lb
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
