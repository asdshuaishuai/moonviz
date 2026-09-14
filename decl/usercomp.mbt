///|
/// 用户组件声明解析（docs/11-user-components.md）。
///
/// 组件声明 = 一段单画板的 `.mbt.md`：frontmatter 增加 `component:` 元段
/// （id/description/params/variants），画板块即组件体（相对坐标）。
/// 解析复用 load_mbt_project 全管线（文法校验 + 谓词验收同源），
/// 参数引用 `${name}` 由 core::collect_param_refs 做闭合检查。

///|
/// 安全切片（非 failable；upto = -1 表示到串尾）
fn safe_slice(s : String, from : Int, upto : Int) -> String {
  let n = s.length()
  let a = if from < 0 { 0 } else { from }
  let b = if upto < 0 || upto > n { n } else { upto }
  if a >= b {
    return ""
  }
  let sb = StringBuilder::new()
  for i = a; i < b; i = i + 1 {
    sb.write_char(s[i].to_int().unsafe_to_char())
  }
  sb.to_string()
}

///|
/// 解析 frontmatter 的 component 元段（行扫描，模式同 mbt_parse_flows）
fn parse_component_meta(
  front : String,
) -> Result[
    (
      String,
      String,
      Array[@core.UserParam],
      Map[String, Map[String, String]],
      String,
    ),
    String,
  ] {
  let mut id = ""
  let mut description = ""
  let params : Array[@core.UserParam] = []
  let variants : Map[String, Map[String, String]] = Map::new()
  // 0=顶层 1=params 列表 2=variants 列表 3=component 内键
  let mut section = 0
  let mut cur_param_name = ""
  let mut cur_variant = ""
  let mut first_variant = "" // 首个声明的变体即默认（实现注释承诺）
  for raw in mbt_lines(front).iter() {
    let line = mbt_trim(raw)
    if line == "" {
      continue
    }
    if mbt_has_prefix(line, "component:") {
      section = 3
      continue
    }
    if section == 0 {
      continue
    }
    // 退出条件：遇到文档级已知键
    if mbt_has_prefix(line, "artboards:") ||
      mbt_has_prefix(line, "flows:") ||
      mbt_has_prefix(line, "entry:") ||
      mbt_has_prefix(line, "title:") ||
      mbt_has_prefix(line, "revision:") ||
      mbt_has_prefix(line, "moonviz:") ||
      mbt_has_prefix(line, "moonbit:") ||
      mbt_has_prefix(line, "format:") {
      section = 0
      continue
    }
    // 子段切换在 component 域内任何位置生效（params ↔ variants ↔ 键值区）
    if mbt_has_prefix(line, "params:") {
      section = 1
      continue
    }
    if mbt_has_prefix(line, "variants:") {
      section = 2
      continue
    }
    if section == 3 {
      if mbt_has_prefix(line, "id:") {
        id = strip_quotes(mbt_trim(safe_slice(line, 3, -1)))
        continue
      }
      if mbt_has_prefix(line, "description:") {
        description = strip_quotes(mbt_trim(safe_slice(line, 12, -1)))
        continue
      }
      continue
    }
    if section == 1 {
      if mbt_has_prefix(line, "- name:") {
        cur_param_name = strip_quotes(mbt_trim(safe_slice(line, 7, -1)))
        params.push({
          name: cur_param_name,
          kind: "text",
          default_value: "",
        })
        continue
      }
      if mbt_has_prefix(line, "kind:") && params.length() > 0 {
        let last = params.length() - 1
        let kind = strip_quotes(mbt_trim(safe_slice(line, 5, -1)))
        if kind != "text" && kind != "color" && kind != "number" {
          return Err("usercomp_param_kind:" + kind)
        }
        params[last] = { ..params[last], kind }
        continue
      }
      if mbt_has_prefix(line, "default:") && params.length() > 0 {
        let last = params.length() - 1
        params[last] = {
          ..params[last],
          default_value: strip_quotes(mbt_trim(safe_slice(line, 8, -1))),
        }
        continue
      }
      continue
    }
    if section == 2 {
      if mbt_has_prefix(line, "- name:") {
        cur_variant = strip_quotes(mbt_trim(safe_slice(line, 7, -1)))
        variants.set(cur_variant, Map::new())
        if first_variant == "" {
          first_variant = cur_variant // 首个变体即默认
        }
        continue
      }
      // 变体内的 k: v = 参数覆盖
      if cur_variant != "" {
        match line.find(":") {
          None => ()
          Some(pos) => {
            let k = mbt_trim(safe_slice(line, 0, pos))
            let v = strip_quotes(mbt_trim(safe_slice(line, pos + 1, -1)))
            if k != "" && v != "" {
              match variants.get(cur_variant) {
                Some(m) => {
                  m.set(k, v)
                  ()
                }
                None => ()
              }
            }
          }
        }
      }
    }
  }
  if id == "" {
    return Err("usercomp_missing_id")
  }
  if variants.length() == 0 {
    variants.set("default", Map::new())
  }
  Ok((id, description, params, variants, first_variant))
}

///|
fn strip_quotes(s : String) -> String {
  if s.length() >= 2 && s[0].to_int() == 34 && s[s.length() - 1].to_int() == 34 {
    safe_slice(s, 1, s.length() - 1)
  } else {
    s
  }
}

///|
/// 解析用户组件声明：单画板 `.mbt.md` + component 元段。
/// 校验链：文法（复用 load_mbt_project）→ 单画板 → id 一致 → 参数闭合。
pub fn parse_user_component(
  text : String,
) -> Result[@core.UserComponentDef, String] {
  match scan_mbt(text) {
    Err(error) => Err(error)
    Ok(document) => {
      let (cid, description, params, variants, default_variant) = match parse_component_meta(
          document.front_matter,
        ) {
        Err(error) => return Err(error)
        Ok(meta) => meta
      }
      if document.visual_blocks.length() != 1 {
        return Err("usercomp_single_artboard_required")
      }
      match load_mbt_project(text) {
        Err(error) => Err(error)
        Ok(project) => {
          let ab = project.project.artboards.get(cid)
          match ab {
            None => Err("usercomp_id_mismatch:" + cid)
            Some(meta) => {
              let def : @core.UserComponentDef = {
                id: cid,
                description,
                category: "user",
                params,
                variants,
                default_variant,
                width: meta.width,
                height: meta.height,
                doc: meta.doc,
                source: text,
              }
              // 参数闭合：所有 ${name} 引用必须已声明
              let refs = match(try? @core.collect_param_refs(def)) {
                Ok(rs) => rs
                Err(_) => return Err("usercomp_ref_scan_failed")
              }
              let declared : Map[String, Bool] = Map::new()
              for p in params.iter() {
                declared.set(p.name, true)
              }
              for r in refs.iter() {
                if declared.contains(r) == false {
                  return Err("usercomp_undeclared_ref:" + r)
                }
              }
              // 实例化冒烟（内置验收）：代入默认参数在临时画板放置一次，
              // 确保组件可画——CLI compile/import 与 MCP 共用本函数，
              // 不再各自维护 probe 拷贝。
              let probe = @core.Document::new({
                width: def.width + 400.0,
                height: def.height + 400.0,
              })
              match(try? @core.place_user_component(probe, def, "__probe", dx=10.0, dy=10.0)) {
                Ok(r) =>
                  if r.is_ok() == false {
                    return Err("usercomp_probe_failed")
                  }
                Err(_) => return Err("usercomp_probe_failed")
              }
              Ok(def)
            }
          }
        }
      }
    }
  }
}
