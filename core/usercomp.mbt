///|
/// 用户自定义组件系统（docs/11-user-components.md）。
///
/// 引擎侧只做「注册功能」：不区分声明来自 Agent（自然语言翻译）还是
/// 人类（Studio 画布沉淀）——落地产物统一是 `.mbt.md` 组件声明。
/// 组件在引擎内部是内存注册表 + 快照协议；物理持久化由宿主负责
/// （Node SDK / Studio / DeepOrca），引擎保持零文件 IO 的既有纪律。
///
/// 组件对外分发的唯一形态是 MCF 专有格式（cli/mcf.mbt）：`.mbt.md`
/// 源码只存在于引擎内部与本地库，不出现在对外流转中。

///|
pub(all) struct UserParam {
  name : String
  kind : String // "text" | "color" | "number"
  default_value : String
}

///|
/// 用户组件：带参数槽的节点树模板。
/// `doc` 是组件画板（相对坐标）；实例化 = 深拷贝 + 参数代入 + 放置。
pub(all) struct UserComponentDef {
  id : String
  description : String
  category : String // "user" | "project"（来源标注，宿主决定）
  params : Array[UserParam]
  /// 变体 = 参数预设覆盖表（variant name -> param -> value）
  variants : Map[String, Map[String, String]]
  default_variant : String
  width : Double
  height : Double
  doc : Document
  /// 声明源码（canonical，引擎内部持有；对外仅经 MCF）
  source : String
}

///|
/// 参数表：name -> value（已含默认值合并与变体覆盖）。
/// 未知 variant 与未知参数名报错（拼写错误不再静默吞掉）。
fn resolve_args(
  def : UserComponentDef,
  variant : String,
  overrides : Map[String, String],
) -> Result[Map[String, String], String] {
  let out : Map[String, String] = Map::new()
  for p in def.params.iter() {
    out.set(p.name, p.default_value)
  }
  let v = if variant == "" { def.default_variant } else { variant }
  // default_variant 本身始终合法（零变体组件的回退）；显式传入的
  // 其他未知变体名才拒绝（拼写错误不再静默吞掉）
  if v != def.default_variant && def.variants.contains(v) == false {
    return Err("unknown_variant:" + v)
  }
  match def.variants.get(v) {
    Some(overrides_v) => {
      for k in overrides_v.keys() {
        match overrides_v.get(k) {
          Some(value) => out.set(k, value)
          None => ()
        }
      }
    }
    None => ()
  }
  for k in overrides.keys() {
    match overrides.get(k) {
      Some(value) => {
        if out.contains(k) == false {
          return Err("unknown_param:" + k)
        }
        out.set(k, value)
      }
      None => ()
    }
  }
  Ok(out)
}

///|
/// 逐字符比较 s[at..at+name.length()] 是否等于 name（避免 failable 切片）
fn str_eq_at(s : String, at : Int, name : String) -> Bool {
  if at < 0 || at + name.length() > s.length() {
    return false
  }
  for j = 0; j < name.length(); j = j + 1 {
    if s[at + j] != name[j] {
      return false
    }
  }
  true
}

///|
/// `${name}` 参数代入（单遍扫描式）：遇到 `${` 时按参数名长度降序做
/// 最长匹配，命中即写出参数值并跳过；替换结果不再参与后续匹配——
/// 替换顺序确定（与 Map 迭代序无关），参数值内嵌 `${other}` 不递归展开。
fn subst_str(text : String, args : Map[String, String]) -> String {
  if text.contains("${") == false {
    return text
  }
  let names : Array[String] = []
  for n in args.keys() {
    names.push(n)
  }
  // 长名优先，避免前缀名吞掉长名（cart 与 cart_icon 并存时）
  names.sort_by(fn(a, b) { b.length() - a.length() })
  let sb = StringBuilder::new()
  let n = text.length()
  let mut i = 0
  let mut matched = true
  while i < n {
    matched = false
    if text[i].to_int() == 36 && i + 2 < n && text[i + 1].to_int() == 123 {
      for name in names.iter() {
        let nl = name.length()
        if i + 2 + nl < n &&
          str_eq_at(text, i + 2, name) &&
          text[i + 2 + nl].to_int() == 125 {
          match args.get(name) {
            Some(v) => {
              sb.write_string(v)
              i = i + 3 + nl
              matched = true
              break
            }
            None => ()
          }
        }
      }
    }
    if matched == false {
      sb.write_char(text[i].to_int().unsafe_to_char())
      i = i + 1
    }
  }
  sb.to_string()
}

///|
fn subst_node(n : Node, args : Map[String, String]) -> Node {
  let mut style = n.style
  style = {
    ..style,
    fill: subst_str(style.fill, args),
    text_color: subst_str(style.text_color, args),
    stroke: subst_str(style.stroke, args),
  }
  { ..n, text: subst_str(n.text, args), style }
}

///|
/// 回滚本次放置已插入的节点（账本逆序：子先父后），恢复父 children。
fn rollback_inserted(
  target : Document,
  inserted : Array[(String, String)],
) -> Unit {
  let mut j = inserted.length() - 1
  while j >= 0 {
    let (host_id, host_parent) = inserted[j]
    match target.nodes.get(host_parent) {
      Some(parent) => {
        let kids : Array[String] = []
        for k in parent.children.iter() {
          if k != host_id {
            kids.push(k)
          }
        }
        target.nodes.set(host_parent, { ..parent, children: kids })
      }
      None => ()
    }
    target.nodes.remove(host_id)
    j = j - 1
  }
}

///|
/// 深拷贝组件树到目标画板：BFS 按依赖序（父先子后）insert。
/// 实例节点 id = `<instance_id>::<原id>`；顶层节点以 (dx, dy) 为组件
/// 包围盒原点做绝对放置（首个顶层节点落在 (dx,dy)，其余保持相对结构，
/// 与内置组件的绝对落点语义一致）。
/// 任一步失败时回滚已插入节点，目标画板保持调用前状态。
/// 返回插入的顶层根节点 id。
pub fn place_user_component(
  target : Document,
  def : UserComponentDef,
  instance_id : String,
  variant~ : String = "",
  args~ : Map[String, String] = Map::new(),
  dx~ : Double = 0.0,
  dy~ : Double = 0.0,
) -> Result[String, String] {
  if target.has(instance_id) {
    return Err("duplicate_node:" + instance_id)
  }
  let resolved = match resolve_args(def, variant, args) {
    Ok(m) => m
    Err(e) => return Err(e)
  }
  // BFS：组件画板 root 的直接子节点为顶层；逐层展开
  let queue : Array[(String, String)] = [] // (组件内节点id, 宿主父id)
  match def.doc.nodes.get("root") {
    None => return Err("usercomp_missing_root")
    Some(root) => {
      for cid in root.children.iter() {
        queue.push((cid, "root"))
      }
    }
  }
  // 组件包围盒原点：首个顶层节点的组件内坐标
  let mut origin_x = 0.0
  let mut origin_y = 0.0
  let mut origin_set = false
  // 回滚账本：(host_id, host_parent) 逆序删除
  let inserted : Array[(String, String)] = []
  let mut placed_root_id = ""
  let mut i = 0
  while i < queue.length() {
    let (cid, host_parent) = queue[i]
    i = i + 1
    match def.doc.nodes.get(cid) {
      None => {
        rollback_inserted(target, inserted)
        return Err("usercomp_missing_node:" + cid)
      }
      Some(node) => {
        let host_id = instance_id + "::" + cid
        let is_top = host_parent == "root"
        let mut n = subst_node(node, resolved)
        if is_top {
          let base_x = match node.x {
            AlignStart(v) => v
            _ => 0.0
          }
          let base_y = match node.y {
            AlignStart(v) => v
            _ => 0.0
          }
          if origin_set == false {
            origin_x = base_x
            origin_y = base_y
            origin_set = true
          }
          // 绝对放置：组件原点对齐 (dx, dy)，顶层节点保持相对结构。
          // 负坐标夹回 0（与内置 place_component 边界策略一致），
          // 越界由 contained_in_parent 谓词显式报告为视觉债。
          let abs_x = dx + (base_x - origin_x)
          let abs_y = dy + (base_y - origin_y)
          let safe_x = if abs_x < 0.0 { 0.0 } else { abs_x }
          let safe_y = if abs_y < 0.0 { 0.0 } else { abs_y }
          n = { ..n, x: AlignStart(safe_x), y: AlignStart(safe_y) }
          if placed_root_id == "" {
            placed_root_id = host_id
          }
        }
        // 关键：实例节点 id 必须重写为带实例前缀的 host_id（组件内同名隔离）
        n = { ..n, id: host_id, children: [] } // 子关系在下方按序重建
        if target.insert_node(n, host_parent) == false {
          rollback_inserted(target, inserted)
          return Err("usercomp_insert_failed:" + host_id)
        }
        inserted.push((host_id, host_parent))
        for child in node.children.iter() {
          queue.push((child, host_id))
        }
      }
    }
  }
  if placed_root_id == "" {
    rollback_inserted(target, inserted)
    return Err("usercomp_empty:" + def.id)
  }
  Ok(placed_root_id)
}

///|
/// 校验辅助：收集节点属性中出现的 `${name}` 引用（compile 阶段闭合检查）。
/// 单遍扫描（每轮 rest 严格前进），无轮数上限。
pub fn collect_param_refs(def : UserComponentDef) -> Array[String] raise {
  let refs : Array[String] = []
  let known : Map[String, Bool] = Map::new()
  for id in def.doc.nodes.keys() {
    match def.doc.nodes.get(id) {
      None => ()
      Some(n) => {
        for text in [n.text, n.style.fill, n.style.text_color, n.style.stroke] {
          let mut rest = text
          let mut scanning = true
          while scanning {
            match rest.find("${") {
              None => scanning = false
              Some(start) => {
                let after = rest[start + 2:].to_string()
                match after.find("}") {
                  None => scanning = false
                  Some(end) => {
                    let name = after[:end].to_string()
                    if name != "" && known.contains(name) == false {
                      known.set(name, true)
                      refs.push(name)
                    }
                    rest = after[end + 1:].to_string()
                  }
                }
              }
            }
          }
        }
      }
    }
  }
  refs
}
