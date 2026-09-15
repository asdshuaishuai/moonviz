///|
/// 操作语法与参数解析：CLI（apply-*-mbt-op-b64）、WASM SDK、Studio 共用的
/// 唯一实现。此前只在 cli 包，WASM 目标（只依赖 core/decl）无法触达。
///
/// 声明转义还原也移到这里：操作参数经 split_op_args 保留转义原文，由
/// unescape_value 统一还原，两半必须成对存在。

///|
/// CLI/engine 边界的公共值还原：把 `\" \\ \, \( \) \n \r \t` 还原为字面字符。
pub fn unescape_value(s : String) -> String {
  unescape_decl(s)
}

///|
/// 还原声明转义：\" \\ \, \( \) \n \r \t
fn unescape_decl(s : String) -> String {
  let sb = StringBuilder::new()
  let mut esc = false
  for c in s.iter() {
    match esc {
      true => {
        match c {
          '"' => sb.write_char('"')
          '\\' => sb.write_char('\\')
          ',' => sb.write_char(',')
          '(' => sb.write_char('(')
          ')' => sb.write_char(')')
          'n' => sb.write_char('\n')
          'r' => sb.write_char('\r')
          't' => sb.write_char('\t')
          other => {
            sb.write_char('\\')
            sb.write_char(other)
          }
        }
        esc = false
      }
      false => {
        if c == '\\' {
          esc = true
        } else {
          sb.write_char(c)
        }
      }
    }
  }
  sb.to_string()
}


///|
pub fn split_cmd(line : String) -> Array[String] {
  // 支持双引号包裹带空格的参数：update ab n text="Hello World"
  let out : Array[String] = []
  let buf = StringBuilder::new()
  let mut in_q = false
  let mut esc = false
  for c in line.iter() {
    if esc {
      // 保留转义序列原文（含 \" \, 等），由 k=v 解析端统一还原。
      buf.write_char('\\')
      buf.write_char(c)
      esc = false
      continue
    }
    if c == '\\' && in_q {
      esc = true
    } else if c == '"' {
      in_q = !in_q
    } else if (c == ' ' || c == '\t' || c == '\r') && !in_q {
      if buf.to_string().length() > 0 {
        out.push(buf.to_string())
        buf.reset()
      }
    } else {
      buf.write_char(c)
    }
  }
  if buf.to_string().length() > 0 {
    out.push(buf.to_string())
  }
  out
}

///|
/// 查找子串首次出现位置；未找到返回 -1
pub fn index_of_str(s : String, sub : String) -> Int {
  let sl = s.length()
  let subl = sub.length()
  if subl == 0 || subl > sl {
    return -1
  }
  let mut i = 0
  while i + subl <= sl {
    if s.substring(start=i, end=i + subl) == sub {
      return i
    }
    i = i + 1
  }
  -1
}

///|
pub fn parse_op_double(s : String) -> Double {
  let mut result = 0.0
  let mut frac = 0.0
  let mut div = 10.0
  let mut seen_dot = false
  let mut neg = false
  for c in s.iter() {
    let code = c.to_int()
    if code == 45 {
      neg = true
    } else if code >= 48 && code <= 57 {
      if seen_dot {
        frac = frac + (code - 48).to_double() / div
        div = div * 10.0
      } else {
        result = result * 10.0 + (code - 48).to_double()
      }
    } else if code == 46 {
      seen_dot = true
    }
  }
  if neg {
    -(result + frac)
  } else {
    result + frac
  }
}

///|
/// 对由 MBT 重新构建的临时 Project 执行一个人类或 Agent 操作。
///
/// 这个函数不负责持久化。调用方随后必须经 commit_and_render() 把变更写成
/// canonical MBT，再从 MBT 重建画布，避免 Project/命令日志成为第二事实源。
pub fn apply_operation(
  project : Project,
  operation : String,
) -> Result[Unit, String] {
  let parts = split_cmd(operation)
  if parts.length() == 0 {
    return Err("mbt_operation_empty")
  }
  match parts[0] {
    "move" =>
      if parts.length() < 5 {
        Err("mbt_operation_usage:move <artboard> <node> <x> <y>")
      } else {
        match
          project.move_node(
            artboard=parts[1],
            node_id=parts[2],
            x=parse_op_double(parts[3]),
            y=parse_op_double(parts[4]),
          ) {
          Ok(_) => Ok(())
          Err(error) => Err(error)
        }
      }
    "update" =>
      if parts.length() < 4 {
        Err("mbt_operation_usage:update <artboard> <node> k=v")
      } else {
        let kvs : Array[(String, String)] = []
        let mut i = 3
        while i < parts.length() {
          let kv = parts[i]
          let eq = index_of_str(kv, "=")
          if eq > 0 {
            kvs.push(
              (
                kv.substring(start=0, end=eq),
                unescape_value(kv.substring(start=eq + 1)),
              ),
            )
          }
          i = i + 1
        }
        match project.edit_node(artboard=parts[1], node_id=parts[2], kvs~) {
          Ok(_) => Ok(())
          Err(error) => Err(error)
        }
      }
    "delete" =>
      if parts.length() < 3 {
        Err("mbt_operation_usage:delete <artboard> <node>")
      } else {
        match project.delete_node(artboard=parts[1], node_id=parts[2]) {
          Ok(_) => Ok(())
          Err(error) => Err(error)
        }
      }
    "copy" =>
      if parts.length() < 4 {
        Err("mbt_operation_usage:copy <artboard> <node> <new_id> [dx] [dy]")
      } else {
        let dx = if parts.length() >= 5 { parse_op_double(parts[4]) } else { 24.0 }
        let dy = if parts.length() >= 6 { parse_op_double(parts[5]) } else { 24.0 }
        match
          project.copy_node(
            artboard=parts[1],
            node_id=parts[2],
            new_id=parts[3],
            dx~,
            dy~,
          ) {
          Ok(_) => Ok(())
          Err(error) => Err(error)
          }
      }
    "duplicate" =>
      if parts.length() < 3 {
        Err("mbt_operation_usage:duplicate <artboard> <new_name>")
      } else {
        match project.duplicate_artboard(src=parts[1], new_name=parts[2]) {
          Ok(_) => Ok(())
          Err(error) => Err(error)
        }
      }
    "delete-artboard" =>
      if parts.length() < 2 {
        Err("mbt_operation_usage:delete-artboard <artboard>")
      } else {
        match project.delete_artboard(id=parts[1]) {
          Ok(_) => Ok(())
          Err(error) => Err(error)
        }
      }
    "reorder" =>
      if parts.length() < 4 {
        Err("mbt_operation_usage:reorder <artboard> <node> front|back|up|down")
      } else {
        match
          project.reorder_node(
            artboard=parts[1],
            node_id=parts[2],
            order=parts[3],
          ) {
          Ok(_) => Ok(())
          Err(error) => Err(error)
        }
      }
    "flip" =>
      if parts.length() < 4 {
        Err("mbt_operation_usage:flip <artboard> <node> h|v|both|none")
      } else {
        match
          project.flip_node(artboard=parts[1], node_id=parts[2], axis=parts[3]) {
          Ok(_) => Ok(())
          Err(error) => Err(error)
        }
      }
    "create" =>
      if parts.length() < 2 {
        Err("mbt_operation_usage:create <name> [width] [height]")
      } else {
        let width = if parts.length() >= 3 { parse_op_double(parts[2]) } else { 390.0 }
        let height = if parts.length() >= 4 { parse_op_double(parts[3]) } else { 844.0 }
        let _ = project.create_artboard(name=parts[1], width~, height~)
        Ok(())
      }
    "template" =>
      if parts.length() < 3 {
        Err("mbt_operation_usage:template <template> <name> [width] [height]")
      } else {
        let width = if parts.length() >= 4 { parse_op_double(parts[3]) } else { 0.0 }
        let height = if parts.length() >= 5 { parse_op_double(parts[4]) } else { 0.0 }
        match
          project.apply_template(
            template_id=parts[1],
            name=parts[2],
            width~,
            height~,
          ) {
          Ok(_) => Ok(())
          Err(error) => Err(error)
        }
      }
    "place" =>
      if parts.length() < 4 {
        Err(
          "mbt_operation_usage:place <artboard> <component> <id> [variant] [x] [y]",
        )
      } else {
        let variant = if parts.length() >= 5 && parts[4] != "-" {
          parts[4]
        } else {
          ""
        }
        let x = if parts.length() >= 6 { parse_op_double(parts[5]) } else { 0.0 }
        let y = if parts.length() >= 7 { parse_op_double(parts[6]) } else { 0.0 }
        // 与 cli_exec 的 place 保持一致：尾部 k=v 对为用户组件参数槽
        let kv : Map[String, String] = Map::new()
        let mut kv_error = ""
        for i = 7; i < parts.length(); i = i + 1 {
          match parts[i].find("=") {
            None =>
              if kv_error == "" {
                kv_error = "place_invalid_arg:" + parts[i]
              }
            Some(pos) => {
              let k = parts[i].substring(start=0, end=pos)
              // k=v 值反转义（与 update 路径一致，兑现 split_cmd 注释协议）
              let v = unescape_value(parts[i].substring(start=pos + 1))
              if k != "" {
                kv.set(k, v)
              }
            }
          }
        }
        if kv_error != "" {
          Err(kv_error)
        } else {
          match
            project.place_component(
              artboard=parts[1],
              component_id=parts[2],
              instance_id=parts[3],
              variant~,
              x~,
              y~,
              args=kv,
            ) {
            Ok(_) => Ok(())
            Err(error) => Err(error)
          }
        }
      }
    "group" =>
      if parts.length() < 5 {
        Err("mbt_operation_usage:group <artboard> <group_id> <n1> <n2> [n3 ...]")
      } else {
        let ids : Array[String] = []
        let mut i = 3
        while i < parts.length() {
          ids.push(parts[i])
          i = i + 1
        }
        match project.group_nodes(artboard=parts[1], node_ids=ids, group_id=parts[2]) {
          Ok(_) => Ok(())
          Err(error) => Err(error)
        }
      }
    "ungroup" =>
      if parts.length() < 3 {
        Err("mbt_operation_usage:ungroup <artboard> <group_id>")
      } else {
        match project.ungroup_node(artboard=parts[1], group_id=parts[2]) {
          Ok(_) => Ok(())
          Err(error) => Err(error)
        }
      }
    "align" =>
      if parts.length() < 5 {
        Err("mbt_operation_usage:align <artboard> <mode> <n1> <n2> [n3 ...]")
      } else {
        let ids : Array[String] = []
        let mut i = 3
        while i < parts.length() {
          ids.push(parts[i])
          i = i + 1
        }
        match project.align_nodes(artboard=parts[1], mode=parts[2], node_ids=ids) {
          Ok(_) => Ok(())
          Err(error) => Err(error)
        }
      }
    "resize-canvas" =>
      if parts.length() < 4 {
        Err("mbt_operation_usage:resize-canvas <artboard> <width> <height>")
      } else {
        match project.resize_canvas(
          artboard=parts[1], width=parse_op_double(parts[2]), height=parse_op_double(parts[3]),
        ) {
          Ok(_) => Ok(())
          Err(error) => Err(error)
        }
      }
    "responsive" =>
      if parts.length() < 2 {
        Err("mbt_operation_usage:responsive <artboard>")
      } else {
        match project.generate_responsive(artboard=parts[1]) {
          Ok(_) => Ok(())
          Err(error) => Err(error)
        }
      }
    "restyle" =>
      if parts.length() < 4 {
        Err("mbt_operation_usage:restyle <artboard> <component_id> k=v [k=v ...]")
      } else {
        let kvs : Array[(String, String)] = []
        let mut i = 3
        while i < parts.length() {
          let eq = index_of_str(parts[i], "=")
          if eq > 0 {
            kvs.push((
              parts[i].substring(start=0, end=eq),
              unescape_value(parts[i].substring(start=eq + 1)),
            ))
          }
          i = i + 1
        }
        if kvs.length() == 0 {
          Err("mbt_operation_no_kv_pairs")
        } else {
          match project.restyle_component(artboard=parts[1], component_id=parts[2], kvs~) {
            Ok(_) => Ok(())
            Err(error) => Err(error)
          }
        }
      }
    "interact" =>
      if parts.length() < 5 {
        Err(
          "mbt_operation_usage:interact <artboard> <node> <trigger> <action_spec>",
        )
      } else {
        match
          project.attach_interaction(
            artboard=parts[1],
            node_id=parts[2],
            trigger=parts[3],
            action_spec=parts[4],
          ) {
          Ok(_) => Ok(())
          Err(error) => Err(error)
        }
      }
    "uninteract" =>
      if parts.length() < 3 {
        Err("mbt_operation_usage:uninteract <artboard> <node>")
      } else {
        match project.detach_interaction(artboard=parts[1], node_id=parts[2]) {
          Ok(_) => Ok(())
          Err(error) => Err(error)
        }
      }
    "state" =>
      if parts.length() < 5 {
        Err(
          "mbt_operation_usage:state <artboard> <node> <state_name> k=v [k=v ...]",
        )
      } else {
        let mut fill : String? = None
        let mut text_color : String? = None
        let mut stroke : String? = None
        let mut text : String? = None
        let mut radius : Double? = None
        let mut font_size : Double? = None
        let mut i = 4
        while i < parts.length() {
          let eq = index_of_str(parts[i], "=")
          if eq > 0 {
            let k = parts[i].substring(start=0, end=eq)
            let v = unescape_value(parts[i].substring(start=eq + 1))
            let d = parse_op_double(v)
            match k {
              "fill" => fill = Some(v)
              "text_color" => text_color = Some(v)
              "stroke" => stroke = Some(v)
              "text" => text = Some(v)
              "radius" => radius = Some(d)
              "font_size" => font_size = Some(d)
              _ => ()
            }
          }
          i = i + 1
        }
        let patch : NodePatch = {
          ..NodePatch::empty(),
          fill,
          text_color,
          stroke,
          text,
          corner_radius: radius,
          font_size,
        }
        match
          project.define_component_state(
            artboard=parts[1],
            node_id=parts[2],
            state_name=parts[3],
            patch~,
          ) {
          Ok(_) => Ok(())
          Err(error) => Err(error)
        }
      }
    "set-state" =>
      if parts.length() < 3 {
        Err("mbt_operation_usage:set-state <node> <state_name> [toggle]")
      } else {
        let toggle = parts.length() >= 4 && parts[3] == "toggle"
        match project.set_node_state(node_id=parts[1], state_name=parts[2], toggle~) {
          Ok(_) => Ok(())
          Err(error) => Err(error)
        }
      }
    "flow" =>
      if parts.length() < 4 {
        Err("mbt_operation_usage:flow <from> <to> <node>")
      } else {
        project.add_flow(from=parts[1], to=parts[2], trigger="tap:" + parts[3])
        project.revision = project.revision + 1
        Ok(())
      }
    "theme" =>
      if parts.length() < 2 {
        Err("mbt_operation_usage:theme <name>")
      } else {
        match project.apply_theme(parts[1]) {
          Ok(_) => Ok(())
          Err(error) => Err(error)
        }
      }
    "fix" =>
      if parts.length() < 2 {
        Err("mbt_operation_usage:fix <artboard>")
      } else {
        match project.auto_fix(artboard=parts[1]) {
          Ok(_) => Ok(())
          Err(error) => Err(error)
        }
      }
    _ => Err("mbt_operation_unsupported:" + parts[0])
  }
}