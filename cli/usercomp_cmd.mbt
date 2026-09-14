///|
/// 用户组件命令组（docs/11-user-components.md）。
///
/// 引擎只提供注册功能：compile（验收+注册）/ describe / delete /
/// library 快照协议（物理持久化归宿主）/ export+import（MCF 专有格式）。
/// 声明来源不区分 Agent（自然语言翻译）与人类（Studio 沉淀）。

///|
///|
/// 公共注册管线：解析 → 实例化冒烟 → 注册（compile 与 import 同一验收）
fn compile_and_register(
  p : @core.Project,
  text : String,
) -> Result[@core.UserComponentDef, String] {
  match @decl.parse_user_component(text) {
    Err(error) => Err(error)
    Ok(def) => {
      // 实例化冒烟：代入默认参数在临时画板上放一次，确保可画
      let probe = @core.Document::new({
        width: def.width + 400.0,
        height: def.height + 400.0,
      })
      match
        @core.place_user_component(
          probe,
          def,
          "__compile_probe",
          dx=10.0,
          dy=10.0,
        ) {
        Err(error) => Err("usercomp_probe_failed:" + error)
        Ok(_) => {
          p.user_components.set(def.id, def)
          Ok(def)
        }
      }
    }
  }
}

///|
fn cmd_component_compile(p : @core.Project, parts : Array[String]) -> String {
  if parts.length() < 2 {
    return cli_err("usage: component-compile-b64 <utf8_base64_component_decl>")
  }
  match decode_mbt_b64(parts[1]) {
    Err(error) => cli_err(error)
    Ok(text) =>
      match compile_and_register(p, text) {
        Err(error) => cli_err(error)
        Ok(def) => {
          let ps : Array[String] = []
          for param in def.params.iter() {
            ps.push(
              "{\"name\":\"\{param.name}\",\"kind\":\"\{param.kind}\",\"default\":\"\{@core.json_escape(param.default_value)}\"}",
            )
          }
          let vs : Array[String] = []
          for v in def.variants.keys() {
            vs.push("\"\{v}\"")
          }
          "{\"ok\":true,\"op\":\"component-compile\",\"component\":\"\{def.id}\",\"params\":[\{join_arr(ps)}],\"variants\":[\{join_arr(vs)}],\"source_b64\":\"\{encode_mbt_b64(def.source)}\"}"
        }
      }
  }
}

///|
/// MCF 导出：组件 → 专有格式（对外唯一形态；mbt.md 不出引擎）
fn cmd_component_export(p : @core.Project, parts : Array[String]) -> String {
  if parts.length() < 2 {
    return cli_err("usage: component-export <id>")
  }
  let id = parts[1]
  match p.user_components.get(id) {
    None => cli_err("unknown_component:" + id)
    Some(def) => {
      let ps : Array[String] = []
      for param in def.params.iter() {
        ps.push(
          "{\"name\":\"\{param.name}\",\"kind\":\"\{param.kind}\",\"default\":\"\{@core.json_escape(param.default_value)}\"}",
        )
      }
      let header_json = "{\"id\":\"\{id}\",\"description\":\"\{@core.json_escape(def.description)}\",\"params\":[\{join_arr(ps)}],\"format\":\"mcf-v1\"}"
      let bytes = @core.mcf_pack(header_json, def.source)
      "{\"ok\":true,\"op\":\"component-export\",\"component\":\"\{id}\",\"mcf_b64\":\"\{@base64.encode(bytes)}\"}"
    }
  }
}

///|
/// MCF 导入：严格校验（magic/版本/双 CRC/指纹）→ 解包 → 重跑完整注册管线
fn cmd_component_import(p : @core.Project, parts : Array[String]) -> String {
  if parts.length() < 2 {
    return cli_err("usage: component-import <mcf_base64>")
  }
  let bytes = @base64.decode(parts[1]) catch {
    _ => return cli_err("mcf_transport_invalid_base64")
  }
  match @core.mcf_unpack(bytes) {
    Err(error) => cli_err(error)
    Ok((header_json, source)) =>
      match compile_and_register(p, source) {
        Err(error) => cli_err(error)
        Ok(def) => "{\"ok\":true,\"op\":\"component-import\",\"component\":\"\{def.id}\",\"header\":\{@core.json_escape(header_json)}"
      }
  }
}

///|
fn cmd_component_describe(p : @core.Project, parts : Array[String]) -> String {
  if parts.length() < 2 {
    return cli_err("usage: component-describe <id>")
  }
  let id = parts[1]
  match p.user_components.get(id) {
    None => cli_err("unknown_component:" + id)
    Some(def) => {
      let ps : Array[String] = []
      for param in def.params.iter() {
        ps.push(
          "{\"name\":\"\{param.name}\",\"kind\":\"\{param.kind}\",\"default\":\"\{@core.json_escape(param.default_value)}\"}",
        )
      }
      let vs : Array[String] = []
      for v in def.variants.keys() {
        vs.push("\"\{v}\"")
      }
      // usage 示例：place <ab> <id> <inst> [variant] [x] [y] k=<kind> ...
      let kvs : Array[String] = []
      for param in def.params.iter() {
        kvs.push("\{param.name}=<\{param.kind}>")
      }
      let kv_j = if kvs.length() > 0 { " " + join_arr(kvs).replace_all(old="\", \"", new=" ") } else { "" }
      let usage = "place <artboard> \{id} <instance_id> [variant] [x] [y]\{kv_j}"
      "{\"ok\":true,\"id\":\"\{id}\",\"description\":\"\{@core.json_escape(def.description)}\",\"source\":\"user\",\"size\":\"\{def.width}x\{def.height}\",\"params\":[\{join_arr(ps)}],\"variants\":[\{join_arr(vs)}],\"usage\":\"\{@core.json_escape(usage)}\"}"
    }
  }
}

///|
fn cmd_component_delete(p : @core.Project, parts : Array[String]) -> String {
  if parts.length() < 2 {
    return cli_err("usage: component-delete <id>")
  }
  let id = parts[1]
  if p.user_components.contains(id) == false {
    return cli_err("unknown_component:" + id)
  }
  p.user_components.remove(id)
  "{\"ok\":true,\"op\":\"component-delete\",\"component\":\"\{id}\"}"
}

///|
/// 库快照：宿主把输出逐项落盘（<id>.mbt.md + 索引）即完成持久化。
fn cmd_library_snapshot(p : @core.Project) -> String {
  let items : Array[String] = []
  for id in p.user_components.keys() {
    match p.user_components.get(id) {
      Some(def) => {
        items.push(
          "{\"id\":\"\{id}\",\"source_b64\":\"\{encode_mbt_b64(def.source)}\"}",
        )
      }
      None => ()
    }
  }
  "{\"ok\":true,\"op\":\"library-snapshot\",\"count\":\{items.length()},\"components\":[\{join_arr(items)}]}"
}

///|
/// 库恢复：宿主会话开始时把本地库逐项灌回（每个参数一个组件声明 b64）。
fn cmd_library_restore(
  p : @core.Project,
  parts : Array[String],
) -> String {
  if parts.length() < 2 {
    return cli_err("usage: library-restore-b64 <b64> [<b64> ...]")
  }
  let mut ok_count = 0
  let mut first_error = ""
  for i = 1; i < parts.length(); i = i + 1 {
    match decode_mbt_b64(parts[i]) {
      Err(error) => {
        if first_error == "" {
          first_error = error
        }
      }
      Ok(text) =>
        match @decl.parse_user_component(text) {
          Err(error) => {
            if first_error == "" {
              first_error = error
            }
          }
          Ok(def) => {
            p.user_components.set(def.id, def)
            ok_count = ok_count + 1
          }
        }
    }
  }
  if first_error != "" {
    return cli_err("library_restore_partial:\{ok_count}:" + first_error)
  }
  "{\"ok\":true,\"op\":\"library-restore\",\"count\":\{ok_count}}"
}
