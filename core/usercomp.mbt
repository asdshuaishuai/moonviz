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
/// `doc` 是组件画板（相对坐标）；实例化 = 深拷贝 + 参数代入 + 平移。
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
/// 参数表：name -> value（已含默认值合并与变体覆盖）
fn resolve_args(
  def : UserComponentDef,
  variant : String,
  overrides : Map[String, String],
) -> Map[String, String] {
  let out : Map[String, String] = Map::new()
  for p in def.params.iter() {
    out.set(p.name, p.default_value)
  }
  let v = if variant == "" { def.default_variant } else { variant }
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
      Some(value) => out.set(k, value)
      None => ()
    }
  }
  out
}

///|
/// `${name}` 参数代入：未知引用原样保留（compile 阶段已保证闭合）。
fn subst_str(text : String, args : Map[String, String]) -> String {
  if text.contains("${") == false {
    return text
  }
  let mut out = text
  for name in args.keys() {
    match args.get(name) {
      Some(value) => out = out.replace_all(old="${" + name + "}", new=value)
      None => ()
    }
  }
  out
}
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
/// 深拷贝组件树到目标画板：BFS 按依赖序（父先子后）insert。
/// 实例节点 id = `<instance_id>::<原id>`；根级组件节点平移 (dx, dy)。
/// 返回插入的顶层节点 id 列表。
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
  let resolved = resolve_args(def, variant, args)
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
  let mut placed_root_id = ""
  let mut i = 0
  while i < queue.length() {
    let (cid, host_parent) = queue[i]
    i = i + 1
    match def.doc.nodes.get(cid) {
      None => return Err("usercomp_missing_node:" + cid)
      Some(node) => {
        let host_id = instance_id + "::" + cid
        let is_top = host_parent == "root"
        let mut n = subst_node(node, resolved)
        if is_top {
          // 顶层节点：平移（负值夹回 0，与 place_component 边界策略一致）
          let base_x = match node.x {
            AlignStart(v) => v
            _ => 0.0
          }
          let base_y = match node.y {
            AlignStart(v) => v
            _ => 0.0
          }
          let safe_x = if base_x + dx < 0.0 { 0.0 } else { base_x + dx }
          let safe_y = if base_y + dy < 0.0 { 0.0 } else { base_y + dy }
          n = { ..n, x: AlignStart(safe_x), y: AlignStart(safe_y) }
          if placed_root_id == "" {
            placed_root_id = host_id
          }
        }
        // 关键：实例节点 id 必须重写为带实例前缀的 host_id（组件内同名隔离）
        n = { ..n, id: host_id, children: [] } // 子关系在下方按序重建
        if target.insert_node(n, host_parent) == false {
          return Err("usercomp_insert_failed:" + host_id)
        }
        for child in node.children.iter() {
          queue.push((child, host_id))
        }
      }
    }
  }
  if placed_root_id == "" {
    return Err("usercomp_empty:" + def.id)
  }
  Ok(placed_root_id)
}

///|
/// 校验辅助：收集节点属性中出现的 `${name}` 引用（compile 阶段闭合检查）
pub fn collect_param_refs(def : UserComponentDef) -> Array[String] raise {
  let refs : Array[String] = []
  let known : Map[String, Bool] = Map::new()
  for id in def.doc.nodes.keys() {
    match def.doc.nodes.get(id) {
      None => ()
      Some(n) => {
        for text in [n.text, n.style.fill, n.style.text_color, n.style.stroke] {
          let mut rest = text
          let mut rounds = 0
          while rounds < 64 {
            rounds = rounds + 1
            match rest.find("${") {
              None => break
              Some(start) => {
                let after = rest[start + 2:].to_string()
                match after.find("}") {
                  None => break
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
